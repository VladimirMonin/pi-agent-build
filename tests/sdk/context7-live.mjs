// Explicit public, keyless Context7 check through Pi's installed adapter tool.
// No LLM request. Maximum one caller-controlled network retry, not an internal loop.
import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {ensureContext7} from '../../scripts/ensure-context7.mjs';
import {assertSyntheticPaths} from './fixtures/synthetic-paths.mjs';
const [sdkRoot,adapterRoot,root]=process.argv.slice(2);assert(sdkRoot&&adapterRoot&&root);
assertSyntheticPaths(sdkRoot,root,adapterRoot);fs.mkdirSync(root,{recursive:true});
const profile=path.join(root,'profile'),cwd=path.join(root,'project');fs.mkdirSync(profile);fs.mkdirSync(cwd);
process.env.PI_CODING_AGENT_DIR=profile;delete process.env.CONTEXT7_API_KEY;process.env.PI_MCP_CONFIG_MODE='exclusive'; // fixture only, never shipped launcher/default
await ensureContext7({profileDir:profile,adapterRoot,sdkRoot,cwd});
const sdk=await import(pathToFileURL(path.join(sdkRoot,'dist/index.js')));
const settings=sdk.SettingsManager.inMemory({packages:[],extensions:['-builtin:mcp','-builtin:llama.cpp','-builtin:codemode','-builtin:tool-search'],retry:{enabled:false},compaction:{enabled:false}});
const loader=new sdk.DefaultResourceLoader({cwd,agentDir:profile,settingsManager:settings,additionalExtensionPaths:[path.join(adapterRoot,'index.ts')],noSkills:true,noPromptTemplates:true,noThemes:true,noContextFiles:true});
let session;const report={status:'STARTED',scope:'LIVE_PUBLIC_CONTEXT7_VIA_PI_1_4_ADAPTER_5_3_2_NO_LLM',steps:[]};
const text=result=>result.content.filter(x=>x.type==='text').map(x=>x.text).join('\n');
try{
 await loader.reload();assert.deepEqual(loader.getExtensions().errors,[]);
 ({session}=await sdk.createAgentSession({cwd,agentDir:profile,settingsManager:settings,resourceLoader:loader,noTools:'builtin',sessionManager:sdk.SessionManager.inMemory(cwd)}));await session.bindExtensions({mode:'rpc'});
 const tools=session.extensionRunner.getAllRegisteredTools();assert.equal(tools.filter(t=>t.definition.name==='mcp').length,1);assert(!tools.some(t=>t.definition.name==='mcpScript'));
 assert(!loader.getExtensions().extensions.some(e=>/builtin[/\\]mcp/.test(e.path)));
 async function call(args){
  const result=await session.extensionRunner.getToolDefinition('mcp').execute('public-context7-'+report.steps.length,args,AbortSignal.timeout(35000),undefined,session.extensionRunner.createContext());
  const content=text(result);const code=result.details?.error;
  report.steps.push({operation:args.connect?'connect':args.search?'search':args.describe?'describe':'call',tool:args.tool??args.describe??null,isError:result.isError===true,error:code??null,chars:content.length});
  fs.writeFileSync(path.join(root,'step-'+report.steps.length+'.json'),JSON.stringify(result,null,2));
  if(result.isError||code||/Unauthorized|rate.limit|Too Many Requests|timed out|failed to connect|connection failed/i.test(content))throw Error(content.slice(0,500));
  return result;
 }
 await call({connect:'context7'});
 const discovered=await call({search:'context7',server:'context7',includeSchemas:true});
 fs.writeFileSync(path.join(root,'discovery.json'),JSON.stringify(discovered,null,2));
 const matches=discovered.details?.matches??[];
 const resolve=matches.find(m=>/resolve.library.id/i.test(m.tool));const query=matches.find(m=>/query.docs/i.test(m.tool));assert(resolve&&query,'public tools not present');
 const resolveDescriptor=await call({describe:resolve.tool,server:'context7'});const queryDescriptor=await call({describe:query.tool,server:'context7'});
 for(const [descriptor,required] of [[resolveDescriptor,['libraryName','query']],[queryDescriptor,['libraryId','query']]]){
  const schema=descriptor.details?.tool?.inputSchema;assert(schema?.properties,'actual MCP input schema missing');for(const key of required)assert(schema.properties[key],`required public schema property absent: ${key}`);
 }
 const resolved=await call({tool:resolve.tool,server:'context7',args:{libraryName:'React',query:'Find the official React useState documentation'}});
 const resolvedText=text(resolved);const libraryId=resolvedText.match(/\/websites\/react_dev\b/)?.[0]??resolvedText.match(/Context7-compatible library ID:\s*(\/[^\s]+)/i)?.[1]??resolvedText.match(/Library ID:\s*(\/[^\s]+)/i)?.[1];assert(libraryId,'resolve response did not provide a library ID');
 const docs=await call({tool:query.tool,server:'context7',args:{libraryId,query:'Show the useState signature and a minimal counter example'}});
 assert(text(docs).length>100&&/useState/i.test(text(docs)),'documentation response is empty/unrelated');
 report.status='PASS';report.libraryId=libraryId;report.owner='pi-mcp-adapter@5.3.2';report.scriptMode=false;report.llmRequests=0;console.log(JSON.stringify(report));
}catch(error){report.status='FAIL';const msg=String(error.message);report.classification=/429|rate.limit|Too Many Requests/i.test(msg)?'RATE_LIMIT':/401|403|Unauthorized|auth/i.test(msg)?'AUTH':/fetch|network|connect|timeout|timed out|ECONN|ENOTFOUND|TLS/i.test(msg)?'NETWORK':'MCP_ERROR';report.error=msg;console.error(JSON.stringify(report));process.exitCode=2;}
finally{if(session){await session.extensionRunner.emit({type:'session_shutdown',reason:'exit'});session.dispose();}fs.writeFileSync(path.join(root,'report.json'),JSON.stringify(report,null,2));}
