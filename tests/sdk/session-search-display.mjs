// Main-thread and actual worker services under real Pi, synthetic JSONL/SQLite.
import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';
import {createRequire,registerHooks} from 'node:module';import {pathToFileURL} from 'node:url';import {DatabaseSync} from 'node:sqlite';import {createHash,randomUUID} from 'node:crypto';
import {assertSyntheticPaths} from './fixtures/synthetic-paths.mjs';
const [sdkRoot,pkg,root]=process.argv.slice(2);assert(sdkRoot&&pkg&&root);assertSyntheticPaths(sdkRoot,root,pkg);fs.mkdirSync(root,{recursive:true});
const require=createRequire(path.join(sdkRoot,'package.json'));
const typeboxUrl=pathToFileURL(require.resolve('typebox')).href;
const hooks=registerHooks({resolve(specifier,context,next){return specifier==='typebox'?{url:typeboxUrl,shortCircuit:true}:next(specifier,context);}});
const main=await import(pathToFileURL(path.join(pkg,'dist/index.js')));const sdk=await import(pathToFileURL(path.join(sdkRoot,'dist/index.js')));
let session;const errors=[],rows=[];const hash=p=>createHash('sha256').update(fs.readFileSync(p)).digest('hex');
async function stop(){if(session){await session.extensionRunner.emit({type:'session_shutdown',reason:'exit'});session.dispose();session=null;}}
try{
 for(const worker of [false,true]){
  main._setIndexWorkerEnabled(worker);
  const caseRoot=path.join(root,worker?'worker':'main'),profile=path.join(caseRoot,'profile'),cwd=path.join(caseRoot,'project'),store=path.join(caseRoot,'search'),sessions=path.join(caseRoot,'sessions'),archive=path.join(caseRoot,'archive');
  for(const p of [profile,path.join(cwd,'.pi'),store,sessions,archive])fs.mkdirSync(p,{recursive:true});
  process.env.PI_CODING_AGENT_DIR=profile;
  fs.writeFileSync(path.join(cwd,'.pi/settings.json'),JSON.stringify({'pi-session-search':{localPath:store}}));
  fs.writeFileSync(path.join(store,'config.json'),JSON.stringify({sessionDir:sessions,archiveDir:archive,sync:{interval:-1,initialDelay:-1},primer:{enabled:false}}));
  const files=[];const ids=[];
  for(const [slug,work] of [['--work-proj-alpha--','/work/proj-alpha'],['--opaque-hyphen-slug--',undefined]]){
   const folder=path.join(sessions,slug);fs.mkdirSync(folder);const file=path.join(folder,randomUUID()+'.jsonl'),id=randomUUID();ids.push(id);
   const data=[{type:'session',version:3,id,timestamp:'2026-01-01T00:00:00Z',cwd:work??''},{type:'message',id:'u1',parentId:null,timestamp:'2026-01-01T00:00:01Z',message:{role:'user',content:[{type:'text',text:'synthetic searchable phrase'}]}},{type:'message',id:'a1',parentId:'u1',timestamp:'2026-01-01T00:00:02Z',message:{role:'assistant',provider:'synthetic',model:'fixture',content:[{type:'text',text:'synthetic result'}]}}];fs.writeFileSync(file,data.map(x=>JSON.stringify(x)).join('\n')+'\n');files.push([file,hash(file)]);
  }
  for(const [file]of files)assert.equal(main.parseSession(file,false)?.userMessageCount,1,'synthetic session must be parsable');
  const notices=[];
  const settings=sdk.SettingsManager.inMemory({packages:[],extensions:['-builtin:mcp','-builtin:llama.cpp','-builtin:codemode','-builtin:tool-search']});
  const ports=()=>process.getActiveResourcesInfo().filter(x=>x==='MessagePort').length;
  const start=async()=>{const loader=new sdk.DefaultResourceLoader({cwd,agentDir:profile,settingsManager:settings,additionalExtensionPaths:[path.join(pkg,'dist/index.js')],noSkills:true,noPromptTemplates:true,noThemes:true,noContextFiles:true});await loader.reload();assert.deepEqual(loader.getExtensions().errors,[]);({session}=await sdk.createAgentSession({cwd,agentDir:profile,resourceLoader:loader,settingsManager:settings,noTools:'builtin',sessionManager:sdk.SessionManager.inMemory(cwd)}));await session.bindExtensions({mode:'rpc',onError:e=>errors.push(e.error),uiContext:{notify:(message,type)=>notices.push({message,type}),setStatus(){}}});};
  const beforePorts=ports();await start();const afterPorts=ports();assert.equal(afterPorts>beforePorts,worker,'requested main/worker path must actually execute');
  const ctx=()=>session.extensionRunner.createContext();
  const search=async params=>{const r=await session.extensionRunner.getToolDefinition('session_search').execute('search-fixture',params,undefined,undefined,ctx());return r.content.map(x=>x.text??'').join('\n');};
  await session.extensionRunner.getCommand('session-sync').handler('',ctx());
  let text=await search({query:'synthetic'});assert(text.includes('Project: /work/proj-alpha |'),text+' '+JSON.stringify(notices));assert(text.includes('Project: --opaque-hyphen-slug-- |'));assert(!text.includes('Project: work/proj/alpha'));for(const id of ids)assert(text.includes(id));
  const filtered=await search({query:'synthetic',project:'proj-alpha'});assert(filtered.includes(ids[0]));assert(!filtered.includes(ids[1]));
  await stop();
  const dbFile=path.join(store,'index/sessions-fts.db');let db=new DatabaseSync(dbFile);assert.equal(db.prepare('SELECT count(*) AS c FROM sessions').get().c,2);db.prepare('UPDATE sessions SET summary=?').run('STALE_DERIVED_SUMMARY');db.close();
  await start();text=await search({query:'synthetic'});assert(text.includes('Project: /work/proj-alpha |'));assert(text.includes('Project: --opaque-hyphen-slug-- |'));assert(!text.includes('STALE_DERIVED_SUMMARY'));await stop();
  db=new DatabaseSync(dbFile);assert.equal(db.prepare('SELECT count(*) AS c FROM sessions WHERE summary=?').get('STALE_DERIVED_SUMMARY').c,2,'read refresh must not reindex/rewrite stored history');db.close();
  for(const [file,digest]of files)assert.equal(hash(file),digest,'source JSONL unchanged');
  rows.push({worker,workerPortObserved:afterPorts>beforePorts,cwd:true,slugFallback:true,ids:true,filter:true,oldSummaryDisplayRefreshedWithoutReindex:true});
 }
 assert.deepEqual(errors,[]);console.log(JSON.stringify({status:'PASS',scope:'REAL_PI_SDK_MAIN_AND_WORKER_SYNTHETIC_JSONL_SQLITE_NO_NETWORK_OR_EMBEDDINGS',cases:rows}));
}finally{await stop();hooks.deregister();}
