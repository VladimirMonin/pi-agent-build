#!/usr/bin/env node
// Add only a missing Context7 default. The pinned adapter owns config precedence.
import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
import {parseArgs} from 'node:util';
export async function ensureContext7({profileDir,adapterRoot,sdkRoot,cwd=process.cwd(),check=false}) {
 profileDir=path.resolve(profileDir);adapterRoot=path.resolve(adapterRoot??path.join(profileDir,'npm/node_modules/pi-mcp-adapter'));
 if(JSON.parse(fs.readFileSync(path.join(adapterRoot,'package.json'),'utf8')).version!=='5.3.2')throw Error('Exact pi-mcp-adapter 5.3.2 required');
 if(!sdkRoot)throw Error('Explicit installed --sdk-root required (no global SDK fallback)');
 process.env.PI_CODING_AGENT_DIR=profileDir;
 const require=createRequire(path.join(path.resolve(sdkRoot),'package.json'));
 const {createJiti}=await import(pathToFileURL(require.resolve('jiti')));
 const jiti=createJiti(import.meta.url,{moduleCache:false});
 const api=await jiti.import(path.join(adapterRoot,'config.ts'),{default:false});
 const utils=await jiti.import(path.join(adapterRoot,'utils.ts'),{default:false});
 const {isServerDisabled}=await jiti.import(path.join(adapterRoot,'types.ts'),{default:false});
 api.setPiMcpConfigEnabled(true); // Pi 1.4 native mcp.json is an import, not adapter settings.
 const effective=api.loadMcpConfig(undefined,cwd);
 const existing=Object.entries(effective.mcpServers).find(([name])=>name.toLowerCase()==='context7');
 if(existing){
  const state=isServerDisabled(existing[1])?'DISABLED_PRESERVED':existing[1].url==='https://mcp.context7.com/mcp'?'CONFIGURED_PRESERVED':'CUSTOM_PRESERVED';
  return {status:'PASS',context7:state,changed:false};
 }
 if(check)throw Error('Context7 is absent from effective adapter configuration');
 const target=path.join(profileDir,'mcp-adapter.json');
 const before=fs.existsSync(target)?fs.readFileSync(target,'utf8'):null;
 const local=before===null?{}:utils.parseJsonWithComments(before);
 if(!local||typeof local!=='object'||Array.isArray(local))throw Error('Invalid adapter config object');
 const defaults=JSON.parse(fs.readFileSync(fileURLToPath(new URL('../config/mcp-adapter.default.json',import.meta.url)),'utf8'));
 for(const field of ['mcpServers','settings'])if(local[field]!==undefined&&(!local[field]||typeof local[field]!=='object'||Array.isArray(local[field])))throw Error('Invalid adapter config '+field);
 const next={...local,mcpServers:{...(local.mcpServers??{}),...defaults.mcpServers},settings:{...(effective.settings?.scriptMode===undefined?defaults.settings:{}),...local.settings}};
 if(before!==null){
  const backup=path.join(profileDir,'.pi-agent-build-backups/context7',String(Date.now()));fs.mkdirSync(backup,{recursive:true});
  fs.copyFileSync(target,path.join(backup,'mcp-adapter.json'));
 }
 fs.mkdirSync(profileDir,{recursive:true});api.writeSharedConfigText(target,JSON.stringify(next,null,2)+'\n');
 const after=api.loadMcpConfig(undefined,cwd);
 if(!after.mcpServers.context7||isServerDisabled(after.mcpServers.context7))throw Error('Context7 effective readback failed');
 return {status:'PASS',context7:'DEFAULT_ADDED',changed:true};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{
  const {values}=parseArgs({options:{'profile-dir':{type:'string'},'adapter-root':{type:'string'},'sdk-root':{type:'string'},cwd:{type:'string'},check:{type:'boolean',default:false}}});
  if(!values['profile-dir'])throw Error('Usage: ensure-context7.mjs --profile-dir <profile> --sdk-root <core-package> [--adapter-root <adapter>] [--cwd <project>] [--check]');
  console.log(JSON.stringify(await ensureContext7({profileDir:values['profile-dir'],adapterRoot:values['adapter-root'],sdkRoot:values['sdk-root'],cwd:values.cwd,check:values.check})));
 }catch{console.error('FAIL Context7 default configuration; inspect the pinned adapter configuration and installed SDK paths (no credential values logged)');process.exitCode=2;}
}
