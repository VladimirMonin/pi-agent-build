import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';
import {ensureContext7} from '../../scripts/ensure-context7.mjs';
import {createRequire} from 'node:module';import {pathToFileURL} from 'node:url';
import {assertSyntheticPaths} from '../sdk/fixtures/synthetic-paths.mjs';
import {spawnSync} from 'node:child_process';import {fileURLToPath} from 'node:url';
const [sdkRoot,adapterRoot,root]=process.argv.slice(2);assert(sdkRoot&&adapterRoot&&root);
assertSyntheticPaths(sdkRoot,root,adapterRoot);fs.mkdirSync(root,{recursive:true});
const home=path.join(root,'home'),cwd=path.join(root,'project');fs.mkdirSync(home);fs.mkdirSync(cwd);
process.env.HOME=home;process.env.USERPROFILE=home;delete process.env.PI_MCP_CONFIG_MODE;delete process.env.CONTEXT7_API_KEY;
const write=(p,value)=>{fs.mkdirSync(path.dirname(p),{recursive:true});fs.writeFileSync(p,JSON.stringify(value));};
const opts=profileDir=>({profileDir,adapterRoot,sdkRoot,cwd});
for(const name of ['agent','task']){
 const profile=path.join(root,name);
 assert.equal((await ensureContext7(opts(profile))).context7,'DEFAULT_ADDED');
 const file=path.join(profile,'mcp-adapter.json');const first=fs.readFileSync(file);const parsed=JSON.parse(first);
 assert.deepEqual(parsed,JSON.parse(fs.readFileSync(new URL('../../config/mcp-adapter.default.json',import.meta.url))));
 assert(!Object.hasOwn(parsed.mcpServers.context7,'headers'));assert(!fs.existsSync(path.join(profile,'mcp.json')));
 assert.equal((await ensureContext7(opts(profile))).changed,false);assert.deepEqual(fs.readFileSync(file),first);
}
const merge=path.join(root,'merge');write(path.join(merge,'mcp-adapter.json'),{imports:['cursor'],mcpServers:{other:{command:'synthetic-missing-command',disabled:true}},settings:{scriptMode:true,connectTimeout:2345}});
await ensureContext7(opts(merge));let merged=JSON.parse(fs.readFileSync(path.join(merge,'mcp-adapter.json')));assert.deepEqual(merged.imports,['cursor']);assert.equal(merged.settings.scriptMode,true);assert.equal(merged.settings.connectTimeout,2345);assert(merged.mcpServers.other);
for(const [name,entry] of [['custom',{url:'https://custom.invalid/mcp',headers:{Authorization:'Bearer synthetic-fixture'}}],['disabled',{url:'https://mcp.context7.com/mcp',disabled:true}]]){
 const profile=path.join(root,name),file=path.join(profile,'mcp-adapter.json');write(file,{mcpServers:{context7:entry}});const before=fs.readFileSync(file);assert.equal((await ensureContext7(opts(profile))).changed,false);assert.deepEqual(fs.readFileSync(file),before);
}
const shared=path.join(home,'.config/mcp/mcp.json');
write(shared,{mcpServers:{otherShared:{url:'https://shared.invalid/mcp',disabled:true}},settings:{scriptMode:true,connectTimeout:6789}});
const sharedSettings=path.join(root,'shared-settings');await ensureContext7(opts(sharedSettings));
assert(!Object.hasOwn(JSON.parse(fs.readFileSync(path.join(sharedSettings,'mcp-adapter.json'))).settings,'scriptMode'),'do not override shared user settings');
write(shared,{mcpServers:{context7:{url:'https://shared.invalid/mcp',disabled:true}}});
const fresh=path.join(root,'shared-profile');const result=await ensureContext7(opts(fresh));assert.equal(result.context7,'DISABLED_PRESERVED');assert(!fs.existsSync(path.join(fresh,'mcp-adapter.json')));
fs.unlinkSync(shared);
write(path.join(home,'.cursor/mcp.json'),{mcpServers:{context7:{url:'https://imported.invalid/mcp',disabled:true}}});
const imported=path.join(root,'imported');write(path.join(imported,'mcp-adapter.json'),{imports:['cursor'],settings:{scriptMode:false}});const first=fs.readFileSync(path.join(imported,'mcp-adapter.json'));assert.equal((await ensureContext7(opts(imported))).context7,'DISABLED_PRESERVED');assert.deepEqual(fs.readFileSync(path.join(imported,'mcp-adapter.json')),first);
const require=createRequire(path.join(sdkRoot,'package.json'));const {createJiti}=await import(pathToFileURL(require.resolve('jiti')));const jiti=createJiti(import.meta.url);
const {interpolateEnvRecord}=await jiti.import(path.join(adapterRoot,'utils.ts'),{default:false});assert.equal(interpolateEnvRecord({Authorization:'Bearer ${CONTEXT7_API_KEY}'},{CONTEXT7_API_KEY:'synthetic-only'}).Authorization,'Bearer synthetic-only');
// Exercise the real installers' configuration stage. Packages are not installed in
// this scenario: tiny fixture forwarding modules use the exact acquired adapter's
// real loader and dependency graph, not a second priority implementation.
const repo=fileURLToPath(new URL('../../',import.meta.url)),installerChecks=[];
for(const shell of process.platform==='win32'?['powershell','bash']:['bash']){
 const piRoot=path.join(root,'installer-'+shell);
 for(const leaf of ['agent','task']){
  const adapter=path.join(piRoot,leaf,'npm/node_modules/pi-mcp-adapter');fs.mkdirSync(adapter,{recursive:true});
  write(path.join(adapter,'package.json'),{name:'pi-mcp-adapter',version:'5.3.2'});
  for(const file of ['config.ts','utils.ts','types.ts'])fs.writeFileSync(path.join(adapter,file),'export * from '+JSON.stringify(path.join(adapterRoot,file))+';\n');
 }
 const args=shell==='powershell'?['-NoProfile','-ExecutionPolicy','Bypass','-File',path.join(repo,'scripts/install.ps1'),'-Apply','-Profile','Both','-SkipPackageInstall','-SkipPatches','-PiRoot',piRoot,'-RepoRoot',repo]:[path.join(repo,'scripts/install.sh'),'--apply','--profile','Both','--skip-package-install','--skip-patches','--pi-root',piRoot,'--repo-root',repo];
 const invoke=()=>{const p=spawnSync(shell==='powershell'?'powershell.exe':'bash',args,{cwd,env:{...process.env,PI_AGENT_BUILD_NPM_PREFIX:path.resolve(sdkRoot,'../../..')},encoding:'utf8',timeout:60000});assert.equal(p.status,0,shell+' config-stage native exit: '+p.stderr+' '+p.stdout);};
 invoke();const snapshots=[];
 for(const leaf of ['agent','task']){
  const file=path.join(piRoot,leaf,'mcp-adapter.json'),before=fs.readFileSync(file);
  assert.deepEqual(JSON.parse(before),JSON.parse(fs.readFileSync(new URL('../../config/mcp-adapter.default.json',import.meta.url))));
  assert(!fs.existsSync(path.join(piRoot,leaf,'mcp.json')));snapshots.push([file,before]);
 }
 invoke();for(const [file,before]of snapshots)assert.deepEqual(fs.readFileSync(file),before);
 const task=snapshots[1][0],custom={mcpServers:{context7:{url:'https://user.invalid/mcp',disabled:true,headers:{Authorization:'Bearer synthetic-user-choice'}}},settings:{scriptMode:true}};
 write(task,custom);const customBytes=fs.readFileSync(task);invoke();assert.deepEqual(fs.readFileSync(task),customBytes);
 installerChecks.push({shell,profiles:['Code','Task'],fresh:true,repeatByteIdentical:true,userOverridePreserved:true,scope:'REAL_CONFIG_STAGE_WITH_REAL_PINNED_LOADER_PACKAGE_INSTALL_AND_PATCHES_NOT_RUN'});
}
console.log(JSON.stringify({status:'PASS',checks:['fresh-Code','fresh-Task','repeat-byte-identical','other-servers','imports','settings','shared-settings','custom-url-auth','disabled','shared-precedence','import-precedence','no-key-no-headers','optional-auth-interpolation','no-native-mcp-config','no-local-Context7-CLI-required'],installerChecks,scope:'PINNED_ADAPTER_LOADER_SYNTHETIC_CONFIG_NO_NETWORK'}));
