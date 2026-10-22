// Actual rendered launchers -> Pi CLI -> loaded memory extension; synthetic LLM.
import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';import {fileURLToPath} from 'node:url';
import {assertSyntheticPaths} from './fixtures/synthetic-paths.mjs';
const [sdkRoot,memoryRoot,root]=process.argv.slice(2);assert(sdkRoot&&memoryRoot&&root);assertSyntheticPaths(sdkRoot,root,memoryRoot);fs.mkdirSync(root,{recursive:true});
const repo=fileURLToPath(new URL('../../',import.meta.url));const home=path.join(root,'home'),profiles=path.join(root,'pi-root'),cwd=path.join(root,'project');fs.mkdirSync(home);fs.mkdirSync(cwd);fs.mkdirSync(path.join(cwd,'.pi'));
fs.writeFileSync(path.join(cwd,'.pi/settings.json'),JSON.stringify({'pi-memory':{localPath:path.join(root,'memory')}}));
const prefix=path.resolve(sdkRoot,'../../..'); // <prefix>/node_modules/@scope/core
assert.equal(path.basename(prefix),'npm-prefix','explicit isolated npm prefix expected');
const env={...process.env,HOME:home,USERPROFILE:home};
const provider=fileURLToPath(new URL('./fixtures/main-model.ts',import.meta.url));
for(const leaf of ['agent','task']){const profile=path.join(profiles,leaf);fs.mkdirSync(profile,{recursive:true});fs.writeFileSync(path.join(profile,'settings.json'),JSON.stringify({defaultProvider:'polza',defaultModel:'synthetic-main',packages:[],extensions:[provider,path.join(memoryRoot,'dist/index.js'),'-builtin:mcp','-builtin:llama.cpp','-builtin:codemode','-builtin:tool-search'],retry:{enabled:false},compaction:{enabled:false}}));fs.writeFileSync(path.join(profile,'main-model-fixture.json'),JSON.stringify({models:['synthetic-main'],mode:'valid',answer:'OK'}));}
function run(cmd,args,expected=0){const p=spawnSync(cmd,args,{env,cwd,encoding:'utf8',timeout:60000});assert.equal(p.status,expected,`${cmd}: ${p.stderr} ${p.stdout} ${p.error??''}`);return p;}
const target=path.join(root,'custom launcher dir');
if(process.platform==='win32')run('powershell.exe',['-NoProfile','-ExecutionPolicy','Bypass','-File',path.join(repo,'scripts/install-launchers.ps1'),'-Apply','-Shell','Both','-TargetDir',target,'-PiRoot',profiles,'-NpmPrefix',prefix,'-RepoRoot',repo]);
else run('bash',[path.join(repo,'scripts/install-launchers.sh'),'--apply','--target-dir',target,'--pi-root',profiles,'--npm-prefix',prefix,'--repo-root',repo]);
const checker=path.join(repo,'patches/memory-windows-runtime/tests/test-memory-runtime-scope.mjs'),results=[];
for(const profile of ['code','task']){
 const profileDir=path.join(profiles,profile==='code'?'agent':'task');
 for(const ext of process.platform==='win32'?['','.cmd']:['']){const launcher=path.join(target,'pi-'+profile+ext);const p=run(process.execPath,[checker,profile,'--launcher',launcher,'--profile-dir',profileDir,'--sdk-root',sdkRoot]);results.push(JSON.parse(p.stdout.trim().split(/\r?\n/).at(-1)));}
 const other=path.join(profiles,profile==='code'?'task':'agent');run(process.execPath,[checker,profile,'--launcher-dir',target,'--profile-dir',other,'--sdk-root',sdkRoot],1);
}
// The POSIX installer default is really ~/.local/bin; no ~/bin symlink.
run('bash',[path.join(repo,'scripts/install-launchers.sh'),'--apply','--pi-root',profiles,'--npm-prefix',prefix,'--repo-root',repo]);
const posixDir=path.join(home,'.local/bin');for(const profile of ['code','task']){assert(fs.existsSync(path.join(posixDir,'pi-'+profile)));run(process.execPath,[checker,profile,'--launcher-dir',posixDir,'--profile-dir',path.join(profiles,profile==='code'?'agent':'task'),'--sdk-root',sdkRoot]);}
const wrongSdk=path.join(root,'wrong-core');fs.mkdirSync(wrongSdk);run(process.execPath,[checker,'code','--launcher-dir',target,'--profile-dir',path.join(profiles,'agent'),'--sdk-root',wrongSdk],1);
assert(!fs.existsSync(path.join(home,'bin')),'no compatibility symlink required');
console.log(JSON.stringify({status:'PASS',scope:'NATIVE_WINDOWS_CMD_AND_GIT_BASH_SYNTHETIC_PROVIDER' ,checks:['custom-path-with-spaces','Code-profile','Task-profile','actual-core-identity','wrong-profile-refused','wrong-sdk-refused','POSIX-installer-default-local-bin','no-user-symlinks','real-memory-agent-end'],results}));
