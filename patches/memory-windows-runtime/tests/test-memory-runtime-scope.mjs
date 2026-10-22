// Boot the installed extension through the actual launcher and Pi ExtensionRunner.
// This explicit canary can use the configured model; never run it as an offline gate.
import {spawnSync} from 'node:child_process';
import {existsSync,readFileSync,realpathSync} from 'node:fs';
import {homedir} from 'node:os';
import {join,resolve,extname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {parseArgs} from 'node:util';
const {values,positionals}=parseArgs({allowPositionals:true,options:{launcher:{type:'string'},'launcher-dir':{type:'string'},'profile-dir':{type:'string'},'sdk-root':{type:'string'}}});
const profile=positionals[0]??'code';
if(!['code','task'].includes(profile)||positionals.length>1||values.launcher&&values['launcher-dir'])throw Error('usage: node test-memory-runtime-scope.mjs [code|task] [--launcher <path> | --launcher-dir <dir>] [--profile-dir <dir>] [--sdk-root <core-package>]');
const dir=values['launcher-dir']??join(homedir(),process.platform==='win32'?'bin':'.local/bin');
const base=join(dir,`pi-${profile}`);
const launcher=resolve(values.launcher??(existsSync(base)?base:process.platform==='win32'?base+'.cmd':base));
if(!existsSync(launcher))throw Error(`launcher not found: ${launcher}; pass --launcher or --launcher-dir for a custom installation`);
const expectedProfile=realpathSync(values['profile-dir']??join(homedir(),'.pi',profile==='code'?'agent':'task'));
const expectedSdk=values['sdk-root']?realpathSync(values['sdk-root']):null;
const target=JSON.parse(readFileSync(new URL('../../../manifests/runtime.lock.json',import.meta.url))).runtime.pi.version;
function launch(args){
 const opts={cwd:process.cwd(),encoding:'utf8',shell:false,timeout:180000};
 if(extname(launcher).toLowerCase()==='.cmd'){
  // These arguments are checker-owned; quote file paths for cmd's /s wrapper.
  const quote=s=>'"'+s.replaceAll('"','""')+'"';
  return spawnSync(process.env.ComSpec??process.env.COMSPEC??'cmd.exe',['/d','/s','/c','"'+[launcher,...args].map(quote).join(' ')+'"'],{...opts,windowsVerbatimArguments:true});
 }
 return spawnSync('bash',[launcher,...args],opts);
}
const version=launch(['--version']);
if(version.error)throw version.error;
if(version.status!==0||version.stdout.trim()!==target)throw Error(`wrong launcher core version: expected ${target}; exit ${version.status}`);
const witness=fileURLToPath(new URL('./launcher-identity.ts',import.meta.url));
const result=launch(['-p','--no-skills','--no-context-files','--no-tools','--no-session','--thinking','off','--extension',witness,'Reply with exactly OK.']);
if(result.error)throw result.error;
if(result.status!==0)throw Error(`pi-${profile} exited ${result.status}`);
const combined=`${result.stdout}\n${result.stderr}`;
if(/pending(?:User|Assistant)Messages is not defined|Extension(?: "| error \()[^\r\n]*pi-memory[^\r\n]*(?:error|\))?:?/i.test(combined))throw Error('pi-memory runtime failure');
const row=combined.split(/\r?\n/).find(line=>line.startsWith('PI_BUILD_RUNTIME_IDENTITY '));
if(!row)throw Error('launcher runtime identity witness missing');
const actual=JSON.parse(row.slice('PI_BUILD_RUNTIME_IDENTITY '.length));
if(realpathSync(actual.profileDir)!==expectedProfile)throw Error('launcher profile mismatch');
if(actual.version!==target||expectedSdk&&realpathSync(actual.sdkRoot)!==expectedSdk)throw Error('launcher SDK mismatch');
if(!result.stdout.includes('OK'))throw Error('launcher did not return canary');
console.log(JSON.stringify({status:'PASS',scope:'ACTUAL_LAUNCHER_PI_HOST_AGENT_END',profile,version:actual.version,profileMatched:true,sdkMatched:expectedSdk?true:'version-only'}));
