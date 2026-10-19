import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';import http from 'node:http';import {fileURLToPath,pathToFileURL} from 'node:url';import {createRequire} from 'node:module';import {spawnSync} from 'node:child_process';
// Explicit synthetic root only; never use a working profile or a Git directory.
const [sdkRoot, root, profileName='code', installedProfile]=process.argv.slice(2);
const profile=installedProfile ?? root+'/'+profileName;
assert(sdkRoot && root, 'usage: node memory-smoke.mjs <sdk-root> <synthetic-root> [code|task]');
assert(['code','task'].includes(profileName));
assert(!path.resolve(root).replaceAll('\\','/').includes('/.pi/'), 'Working profiles are not fixtures');
const repo=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const relative=path.relative(repo,path.resolve(root));assert(relative.startsWith('..') || path.isAbsolute(relative), 'Runtime writes must stay outside Git');
// Validate the actual profile, not merely the output directory, before any SDK,
// Memory import or settings read. Installed profiles are siblings of checks,
// not children of each case root. Reuse the existing Windows owner/ancestor gate.
function assertMemoryFixturePaths() {
 const refuse=condition=>assert(condition,'MEMORY_FIXTURE_GUARD: unsafe private profile/path');
 refuse(process.platform==='win32');
 const lab=path.resolve(sdkRoot,'../../../..');
 const within=(p,base)=>{const rel=path.relative(base,path.resolve(p));return rel!==''&&!rel.startsWith('..'+path.sep)&&rel!=='..'&&!path.isAbsolute(rel);};
 for(const p of [sdkRoot,root,profile]) {
  refuse(path.isAbsolute(p)&&!p.split(/[\\/]/).includes('..'));
  refuse(!path.resolve(p).split(path.sep).some(part=>part.toLowerCase()==='.pi'));
 }
 refuse(within(root,lab)&&within(profile,lab));
 refuse(!within(root,repo)&&!within(profile,repo));
 const payload=Buffer.from(JSON.stringify({lab,repo,root:path.resolve(root),profile:path.resolve(profile),sdk:path.resolve(sdkRoot)})).toString('base64');
 const ps=`$ErrorActionPreference='Stop';try {
 $p=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('${payload}'))|ConvertFrom-Json
 . (Join-Path $p.repo 'scripts/common.ps1')
 $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $p.repo 'scripts/lab-stand.ps1'),[ref]$null,[ref]$null)
 foreach($name in @('Stand-Sid','Assert-StandAncestors')) {
  $def=$ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true)
  if(-not $def){throw 'Missing existing guard'}; . ([scriptblock]::Create($def.Extent.Text))
 }
 $currentSid=[Security.Principal.WindowsIdentity]::GetCurrent().User
 $trusted=@($currentSid.Value,'S-1-5-18','S-1-5-32-544')
 $null=Assert-PrivateLabRoot -LabRoot $p.lab -RepoRoot $p.repo
 Assert-StandAncestors $p.lab -Owned
 foreach($target in @($p.root,$p.profile,$p.sdk)){Assert-StandAncestors $target}
 $settings=Get-Item -LiteralPath (Join-Path $p.profile 'settings.json') -Force
 if($settings.PSIsContainer -or ($settings.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Settings link/type'}
 Write-Output 'MEMORY_FIXTURE_GUARD_PASS'
 } catch {Write-Output 'MEMORY_FIXTURE_GUARD_REFUSED';exit 1}`;
 const env={};for(const key of 'PATH PATHEXT SystemRoot WINDIR COMSPEC HOME USERPROFILE APPDATA LOCALAPPDATA TEMP TMP PSModuleAnalysisCachePath'.split(' '))if(process.env[key]!==undefined)env[key]=process.env[key];
 const executable=path.join(process.env.SystemRoot,'System32/WindowsPowerShell/v1.0/powershell.exe');
 const checked=spawnSync(executable,['-NoProfile','-NonInteractive','-EncodedCommand',Buffer.from(ps,'utf16le').toString('base64')],{env,encoding:'utf8',timeout:20000});
 refuse(!checked.error&&checked.signal===null&&checked.status===0&&checked.stdout.trim()==='MEMORY_FIXTURE_GUARD_PASS');
 return {lab,profile:path.resolve(profile),policy:'existing Assert-PrivateLabRoot + Assert-StandAncestors; settings metadata only'};
}
const profileGuard=assertMemoryFixturePaths();
const sdk=await import(pathToFileURL(sdkRoot+'/dist/index.js'));const ai=await import(pathToFileURL(sdkRoot+'/node_modules/@earendil-works/pi-ai/dist/index.js'));
const pkg=profile+'/npm/node_modules/@samfp/pi-memory';const {createJiti}=await import(pathToFileURL(sdkRoot+'/node_modules/jiti/lib/jiti.mjs'));const jiti=createJiti(import.meta.url,{alias:{typebox:createRequire(sdkRoot+'/dist/core/extensions/loader.js').resolve('typebox')}});const {MemoryStore}=await jiti.import(pkg+'/dist/index.js',{default:false});
const cwd=root+'/native-fixture-'+profileName;assert(!fs.existsSync(cwd),'Fresh synthetic case required');fs.mkdirSync(cwd+'/.pi',{recursive:true});fs.writeFileSync(cwd+'/.pi/settings.json',JSON.stringify({'pi-memory':{localPath:cwd+'/data'}}));process.chdir(cwd);
fs.rmSync(cwd+'/data',{recursive:true,force:true});
const fakePrefix=root+'/fake-prefix';const cli=fakePrefix+'/node_modules/@earendil-works/pi-coding-agent/dist/bundle/cli.js';fs.mkdirSync(path.dirname(cli),{recursive:true});fs.writeFileSync(cli,`const fs=require('node:fs');fs.writeFileSync(${JSON.stringify(root+'/consolidation-argv.json')},JSON.stringify(process.argv));console.log(JSON.stringify({semantic:[{key:'pref.native_consolidation',value:'SYNTHETIC',confidence:0.9}],lessons:[{rule:'Do not publish confidential tokens.',category:'general',negative:true}]}));`);process.env.PI_AGENT_BUILD_NPM_PREFIX=fakePrefix;
const store=new MemoryStore(cwd+'/data/memory.db');
for(const [key,value] of [['pref.theme','DARK_THEME_FACT: предпочитает тёмное оформление'],['project.synth.current','CORRECT_PROJECT_FACT'],['project.foreign.other','WRONG_PROJECT_FACT']]){store.setSemantic(key,value);store.setEmbedding(key,new Float32Array([1,0,0]));}
store.addLesson('Нельзя публиковать секреты','general','user',true);store.addLesson('WRONG_PROJECT_LESSON','general','user',true,'foreign');store.close();
let requests=0;const server=http.createServer((req,res)=>{let body='';req.on('data',b=>body+=b);req.on('end',()=>{requests++;const input=JSON.parse(body).input;const texts=Array.isArray(input)?input:[input];res.writeHead(200,{'Content-Type':'application/json'});res.end(JSON.stringify({data:texts.map((_,index)=>({index,embedding:[1,0,0]}))}));});});await new Promise(r=>server.listen(0,'127.0.0.1',r));
const original=fs.readFileSync(profile+'/settings.json');const config=JSON.parse(original);config.memory={consolidationModel:'fixture/mock',embedding:{type:'openai-compatible',model:'synthetic',apiKey:'synthetic',dimensions:3,baseUrl:'http://127.0.0.1:'+server.address().port},factProjectAliases:[{path:cwd,scope:'synth'}]};fs.writeFileSync(profile+'/settings.json',JSON.stringify(config));
let session,runtime;const seen=[],errors=[];const report={status:'STARTED',profile:profileName,profileGuard,scope:'REAL_PI_MEMORY_SQLITE_HOOKS_LOCAL_MOCK_EMBEDDER',checks:[]};
function message(model,content,stopReason='stop'){return {role:'assistant',api:model.api,provider:model.provider,model:model.id,timestamp:Date.now(),content,stopReason,usage:{input:0,output:0,cacheRead:0,cacheWrite:0,totalTokens:0,cost:{input:0,output:0,cacheRead:0,cacheWrite:0,total:0}}};}
try {
 runtime=await sdk.ModelRuntime.create({authPath:root+'/synthetic-auth.json',modelsPath:null,modelsStorePath:root+'/synthetic-models.json',allowModelNetwork:false,refreshOnCreate:false});
 runtime.registerProvider('fixture',{api:'openai-completions',baseUrl:'https://fixture.invalid',apiKey:'synthetic',models:[{id:'mock',name:'mock',input:['text'],reasoning:false,cost:{input:0,output:0,cacheRead:0,cacheWrite:0},contextWindow:64000,maxTokens:128}],streamSimple(model,context){seen.push(context);const stream=ai.createAssistantMessageEventStream();const msg=seen.length===1?message(model,[{type:'toolCall',id:'stats',name:'memory_stats',arguments:{}}],'toolUse'):message(model,[{type:'text',text:'SYNTHETIC_REPLY'}]);queueMicrotask(()=>{stream.push({type:'start',partial:msg});stream.push({type:'done',reason:msg.stopReason,message:msg});stream.end();});return stream;}});
 const settings=sdk.SettingsManager.inMemory({extensions:['-builtin:mcp','-builtin:llama.cpp','-builtin:codemode','-builtin:tool-search'],packages:['npm:@samfp/pi-memory@1.6.1'],compaction:{enabled:false},retry:{enabled:false}});
 const loader=new sdk.DefaultResourceLoader({cwd,agentDir:profile,settingsManager:settings,noSkills:true,noPromptTemplates:true,noThemes:true,noContextFiles:true});await loader.reload();assert.deepEqual(loader.getExtensions().errors,[]);
 ({session}=await sdk.createAgentSession({cwd,agentDir:profile,modelRuntime:runtime,model:runtime.getModel('fixture','mock'),noTools:'builtin',resourceLoader:loader,settingsManager:settings,sessionManager:sdk.SessionManager.create(cwd,root+'/sessions')}));await session.bindExtensions({mode:'rpc',onError:e=>errors.push(String(e.error))});
 await session.prompt('Какой внешний вид выбрать?');await session.waitForIdle();assert.equal(seen.length,2);assert.equal(requests,1);
 for(const context of seen){const text=JSON.stringify(context.messages);assert(text.includes('DARK_THEME_FACT'));assert(text.includes('CORRECT_PROJECT_FACT'));assert(!text.includes('WRONG_PROJECT'));assert(text.includes('<memory>'));const systems=context.messages.filter(m=>m.role==='system');assert(!JSON.stringify(systems).includes('<memory>'));}
 // One connected lifecycle: user/tool recall above, then custom, empty/error,
 // fresh user recall and finally the session-switch boundary below.
 const recalled = seen.map(context=>JSON.stringify(context.messages));
 assert.equal(recalled.filter(text=>text.includes('<memory>')).length,2);
 const countBeforeCustom=requests;
 await session.sendCustomMessage({customType:'synthetic-memory-custom',content:'CUSTOM_NO_RECALL',display:false},{triggerTurn:true});
 await session.waitForIdle();
 assert.equal(requests,countBeforeCustom,'Custom must not embed or search');
 assert(!JSON.stringify(seen.at(-1).messages).includes('<memory>'),'Custom inherited an old block');
 const runner=session.extensionRunner;
 const contextProbe=()=>runner.emitContext([{role:'user',content:'CONTEXT_PROBE',timestamp:Date.now()}]);
 await runner.emitBeforeAgentStart({messageType:'user',prompt:'   '},{cwd,tools:[]});
 assert(!JSON.stringify(await contextProbe()).includes('<memory>'),'Empty prompt retained recall');
 const beforeError=errors.length;
 // Inject an actual SQLite search failure, not a different loader's class double.
 // This DB is created by this case; restore its schema before any next turn.
 const faultStore=new MemoryStore(cwd+'/data/memory.db');
 faultStore.db.exec('ALTER TABLE semantic RENAME TO fixture_semantic_hidden');
 try {
   await runner.emitBeforeAgentStart({messageType:'user',prompt:'error canary'},{cwd,tools:[]});
 } finally {faultStore.db.exec('ALTER TABLE fixture_semantic_hidden RENAME TO semantic');faultStore.close();}
 assert.equal(errors.length,beforeError+1,'Injected real-store search failure did not reach hook');
 assert(errors.pop().includes('semantic'));
 assert(!JSON.stringify(await contextProbe()).includes('<memory>'),'Search error retained recall');
 const updated=new MemoryStore(cwd+'/data/memory.db');updated.setSemantic('pref.theme','FRESH_RECALL_FACT');updated.setEmbedding('pref.theme',new Float32Array([1,0,0]));updated.close();
 await session.prompt('Новый запрос про оформление');await session.waitForIdle();
 assert(JSON.stringify(seen.at(-1).messages).includes('FRESH_RECALL_FACT'),'New user did not get fresh recall');
 assert(!JSON.stringify(seen.at(-1).messages).includes('DARK_THEME_FACT'),'New user inherited stale recall');
 await session.prompt('Второй синтетический вопрос');await session.waitForIdle();
 await session.prompt('/memory-consolidate');
 const argv=JSON.parse(fs.readFileSync(root+'/consolidation-argv.json','utf8'));assert.equal(argv[0],process.execPath);assert.equal(path.resolve(argv[1]),path.resolve(cli));assert.equal(argv[argv.indexOf('--model')+1],'fixture/mock');
 const transcript=argv[argv.indexOf('-p')+1].split('## Conversation')[1];assert(!transcript.includes('<memory>'));assert.match(transcript,/User: Какой внешний вид выбрать\?[\s\S]*Assistant: SYNTHETIC_REPLY[\s\S]*User: Второй синтетический вопрос[\s\S]*Assistant: SYNTHETIC_REPLY/);
 const saved=new MemoryStore(cwd+'/data/memory.db');assert.equal(saved.getSemantic('pref.native_consolidation').source,'consolidation');assert.equal(saved.listLessons().find(l=>l.rule==='Do not publish confidential tokens.').source,'session:'+session.sessionManager.getSessionId());saved.close();
 assert(!JSON.stringify(session.sessionManager.getEntries()).includes('<memory>'));assert.deepEqual(errors,[]);
 report.checks.push('NATIVE_WINDOWS_NODE_CLI_SELECTED_PREFIX_PROFILE_MODEL','ORDERED_CONSOLIDATION_EXCLUDES_EPHEMERAL_MEMORY','REAL_SESSION_ID_ON_SAVED_LESSON');
 await session.extensionRunner.emit({type:'session_before_switch',reason:'new'});
 assert(!JSON.stringify(await contextProbe()).includes('<memory>'),'Session switch retained recall');
 report.checks.push('USER_TOOL_CUSTOM_EMPTY_ERROR_FRESH_USER_SESSION_SWITCH_LIFECYCLE');
 report.checks.push('UPSTREAM_PROVIDER_USED_FOR_AUTOMATIC_VECTOR_RECALL','SCOPED_FACTS_LESSONS_ALIASES','EPHEMERAL_CONTEXT_ON_TOOL_CONTINUATION_NOT_SYSTEM_OR_HISTORY','REAL_AGENT_END_ORDERED_TURNS_SCOPE');report.status='PASS';
} catch(error){report.status='FAIL';report.error=String(error.stack||error);throw error;}
finally {if(session){await session.extensionRunner.emit({type:'session_shutdown',reason:'exit'});session.dispose();}if(runtime)runtime.unregisterProvider('fixture');fs.writeFileSync(profile+'/settings.json',original);await new Promise(r=>server.close(r));report.embeddingRequests=requests;fs.writeFileSync(root+'/smoke-report-'+profileName+'.json',JSON.stringify(report,null,2));}
console.log(JSON.stringify(report));
