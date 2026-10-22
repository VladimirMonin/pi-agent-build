// Real Pi + SQLite + automatic switch consolidation, synthetic HTTP only.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import http from 'node:http';
import {randomUUID} from 'node:crypto';
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
import {assertSyntheticPaths} from './fixtures/synthetic-paths.mjs';
const [sdkRoot,root,pkg]=process.argv.slice(2);
assert(sdkRoot&&root&&pkg,'memory-project-scope.mjs <sdk-root> <fresh-root> <patched-memory-package>');
assertSyntheticPaths(sdkRoot,root,pkg);fs.mkdirSync(root,{recursive:true});
const require=createRequire(path.join(sdkRoot,'package.json'));
const sdk=await import(pathToFileURL(path.join(sdkRoot,'dist/index.js')));
function packageEntry(name,leaf){for(let dir=sdkRoot;;dir=path.dirname(dir)){const entry=path.join(dir,'node_modules',name,leaf);if(fs.existsSync(entry))return entry;if(path.dirname(dir)===dir)throw Error('Missing '+name);}}
const ai=await import(pathToFileURL(packageEntry('@earendil-works/pi-ai','dist/index.js')));
const {createJiti}=await import(pathToFileURL(require.resolve('jiti')));
const jiti=createJiti(import.meta.url,{alias:{typebox:require.resolve('typebox')}});
const {MemoryStore}=await jiti.import(path.join(pkg,'dist/index.js'),{default:false});
const dbDir=path.join(root,'database'),profile=path.join(root,'profile');fs.mkdirSync(profile);
process.env.PI_CODING_AGENT_DIR=profile;
const marker='CONSOLIDATED_CANARY_'+randomUUID();
let consolidationCalls=0,instructionSeen=false;
const server=http.createServer((req,res)=>{let body='';req.on('data',chunk=>body+=chunk);req.on('end',()=>{
 const request=JSON.parse(body);assert.equal(request.model,'synthetic-consolidation');
 const text=JSON.stringify(request.messages);instructionSeen=text.includes('Allowed project fact prefix: project.foo-bar.');
 consolidationCalls++;
 const content=JSON.stringify({semantic:[{key:'project.foo-bar.new_fact',value:marker,confidence:0.95},{key:'project.foo_bar.rejected',value:'SYNTHETIC_FOREIGN',confidence:0.95}],lessons:[]});
 if(request.stream){res.writeHead(200,{'content-type':'text/event-stream'});for(const chunk of [{choices:[{index:0,delta:{role:'assistant',content},finish_reason:null}]},{choices:[{index:0,delta:{},finish_reason:'stop'}],usage:{prompt_tokens:12,completion_tokens:12,total_tokens:24}}])res.write('data: '+JSON.stringify({id:'synthetic',object:'chat.completion.chunk',created:1,model:request.model,...chunk})+'\n\n');res.end('data: [DONE]\n\n');}
 else{res.writeHead(200,{'content-type':'application/json'});res.end(JSON.stringify({id:'synthetic',object:'chat.completion',created:1,model:request.model,choices:[{index:0,message:{role:'assistant',content},finish_reason:'stop'}],usage:{prompt_tokens:12,completion_tokens:12,total_tokens:24}}));}
});});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const settingsData={packages:[],extensions:['-builtin:mcp','-builtin:llama.cpp','-builtin:codemode','-builtin:tool-search'],memory:{consolidationModel:'synthetic-consolidation/synthetic-consolidation',factProjectAliases:[{path:path.join(root,'alias-tree').replaceAll('\\','/'),scope:'foo-bar'}]},retry:{enabled:false},compaction:{enabled:false}};
fs.writeFileSync(path.join(profile,'settings.json'),JSON.stringify(settingsData));
fs.writeFileSync(path.join(profile,'models.json'),JSON.stringify({providers:{'synthetic-consolidation':{api:'openai-completions',baseUrl:`http://127.0.0.1:${server.address().port}/v1`,apiKey:'EXAMPLE_synthetic-fixture',models:[{id:'synthetic-consolidation',name:'synthetic',reasoning:false,input:['text'],contextWindow:32768,maxTokens:512,cost:{input:0,output:0,cacheRead:0,cacheWrite:0}}]}}}));
let session,runtime,command;const seen=[],errors=[];
async function start(leaf){
 const cwd=path.join(root,leaf);fs.mkdirSync(path.join(cwd,'.pi'),{recursive:true});
 fs.writeFileSync(path.join(cwd,'.pi/settings.json'),JSON.stringify({'pi-memory':{localPath:dbDir}}));
 runtime=await sdk.ModelRuntime.create({authPath:path.join(profile,'auth.json'),modelsPath:null,modelsStorePath:path.join(profile,'models-store.json'),allowModelNetwork:false,refreshOnCreate:false});
 runtime.registerProvider('scope-fixture',{api:'openai-completions',baseUrl:'https://fixture.invalid',apiKey:'EXAMPLE_synthetic-fixture',models:[{id:'mock',name:'mock',input:['text'],reasoning:false,contextWindow:32768,maxTokens:128,cost:{input:0,output:0,cacheRead:0,cacheWrite:0}}],streamSimple(model,context){
  seen.push(context);const stream=ai.createAssistantMessageEventStream();const tool=command&&context.messages.at(-1)?.role!=='toolResult';
  const message={role:'assistant',api:model.api,provider:model.provider,model:model.id,timestamp:Date.now(),stopReason:tool?'toolUse':'stop',content:tool?[{type:'toolCall',id:randomUUID(),name:'memory_remember',arguments:command}]:[{type:'text',text:'SYNTHETIC_REPLY'}],usage:{input:1,output:1,cacheRead:0,cacheWrite:0,totalTokens:2,cost:{input:0,output:0,cacheRead:0,cacheWrite:0,total:0}}};
  queueMicrotask(()=>{stream.push({type:'start',partial:message});stream.push({type:'done',reason:message.stopReason,message});stream.end();});return stream;
 }});
 const settings=sdk.SettingsManager.inMemory(settingsData);
 const loader=new sdk.DefaultResourceLoader({cwd,agentDir:profile,settingsManager:settings,additionalExtensionPaths:[path.join(pkg,'dist/index.js')],noSkills:true,noPromptTemplates:true,noThemes:true,noContextFiles:true});await loader.reload();assert.deepEqual(loader.getExtensions().errors,[]);
 ({session}=await sdk.createAgentSession({cwd,agentDir:profile,modelRuntime:runtime,model:runtime.getModel('scope-fixture','mock'),resourceLoader:loader,settingsManager:settings,noTools:'builtin',sessionManager:sdk.SessionManager.inMemory(cwd)}));await session.bindExtensions({mode:'rpc',onError:e=>errors.push(String(e.error))});
}
async function stop(){if(session){await session.extensionRunner.emit({type:'session_shutdown',reason:'exit'});session.dispose();session=null;}runtime?.unregisterProvider('scope-fixture');runtime=null;}
try{
 await start('foo-bar');
 const initialStore=new MemoryStore(path.join(dbDir,'memory.db'));assert.equal(initialStore.getSemantic('project.foo-bar.new_fact'),undefined);initialStore.close();
 // Three genuine user runs meet the ordinary switch/shutdown threshold.
 for(let i=0;i<3;i++){await session.prompt('SYNTHETIC_USER_'+i);await session.waitForIdle();}
 assert.equal(consolidationCalls,0);
 await stop(); // Normal SDK host shutdown hook triggers automatic consolidation, not a memory tool/command.
 assert.equal(consolidationCalls,1);assert(instructionSeen);
 const store=new MemoryStore(path.join(dbDir,'memory.db'));
 const fact=store.getSemantic('project.foo-bar.new_fact');assert.equal(fact.value,marker);assert.equal(fact.source,'consolidation');assert.equal(store.getSemantic('project.foo_bar.rejected'),undefined);store.close();
 await stop();
 for(const leaf of ['foo-bar','foreign-project','alias-tree']){
  await start(leaf);const before=seen.length;
  await session.prompt('new_fact');await session.waitForIdle();
  assert.equal(JSON.stringify(seen.slice(before)).includes(marker),leaf!=='foreign-project',leaf+' automatic context');
  await stop();
 }
 // Real remember tool accepts exact/alias/global scopes and refuses foreign/underscore.
 for(const leaf of ['foo-bar','alias-tree']){
  await start(leaf);
  for(const key of ['project.foo_bar.bad','project.foreign.bad','project.foo-bar.manual','pref.global','user.global','tool.global']){
   command={type:'fact',key,value:'SYNTHETIC_MANUAL'};
   const before=session.messages.length;await session.prompt('SYNTHETIC_REMEMBER');await session.waitForIdle();
   const result=session.messages.slice(before).find(m=>m.role==='toolResult');assert(result);
   const refused=key.includes('foo_bar')||key.includes('foreign');assert.equal(result.isError===true,refused);
   if(refused)assert(JSON.stringify(result.content).includes('expected project.foo-bar.'));
  }
  command=null;await stop();
 }
 assert.deepEqual(errors,[]);
 console.log(JSON.stringify({status:'PASS',scope:'REAL_PI_SQLITE_AUTOMATIC_CONSOLIDATION_SYNTHETIC_HTTP_NOT_LIVE',consolidationCalls,instructionSeen,source:'consolidation',projectScope:'foo-bar',contextChecks:['own','foreign-excluded','alias'],writeChecks:['exact','underscore-refused','foreign-refused','alias','pref','user','tool']}));
}finally{command=null;await stop();await new Promise(resolve=>server.close(resolve));}
