#!/usr/bin/env node
// One fresh SDK session: configured/explicit selection -> SDK state -> structured answer.
// This is an explicit one-request readiness check, not an offline installer gate.
import {readFileSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {parseArgs} from 'node:util';
export async function checkMainModel({sdkRoot,profileDir,cwd=process.cwd(),provider,model,timeoutMs=60000}) {
 const report={status:'FAIL',route:'main',expected:null,actual:null,answer:null};
 let session,timer;
 const fail=reason=>{const error=new Error(reason);error.report={...report,reason};return error;};
 const work=async()=>{
  // The caller selects the exact installed SDK; never resolve a global fallback.
  const sdk=await import(pathToFileURL(join(resolve(sdkRoot),'dist/index.js')));
  const settings=sdk.SettingsManager.create(cwd,resolve(profileDir));
  const expected={provider:provider??settings.getDefaultProvider(),model:model??settings.getDefaultModel()};
  report.expected=expected;
  if(!expected.provider||!expected.model)throw fail('EXPECTED_MODEL_NOT_CONFIGURED');
  // Use the same public services path as Pi's host: provider registrations must
  // enter the runtime before its initial selection (raw createAgentSession alone
  // initializes dynamic extension providers too late).
  const services=await sdk.createAgentSessionServices({cwd,agentDir:resolve(profileDir),settingsManager:settings,resourceLoaderOptions:{noSkills:true,noPromptTemplates:true,noThemes:true,noContextFiles:true}});
  if(services.resourceLoader.getExtensions().errors.length||services.diagnostics.some(item=>item.type==='error'))throw fail('EXTENSION_LOAD_ERROR');
  ({session}=await sdk.createAgentSessionFromServices({services,noTools:'all',thinkingLevel:'off',sessionManager:sdk.SessionManager.inMemory(cwd)}));
  const errors=[];await session.bindExtensions({mode:'rpc',onError:()=>errors.push(true)});
  // Use Pi's exact model API for an explicit selection; it refuses an absent ID.
  if(provider!==undefined||model!==undefined){
   const selected=session.modelRuntime.getModel(expected.provider,expected.model);
   if(!selected)throw fail('REQUESTED_MODEL_UNAVAILABLE');
   await session.setModel(selected);
  }
  report.actual=session.model?{provider:session.model.provider,model:session.model.id}:null;
  if(!session.modelRuntime.getModel(expected.provider,expected.model))throw fail('EXPECTED_MODEL_UNAVAILABLE');
  if(report.actual?.provider!==expected.provider||report.actual?.model!==expected.model)throw fail('MODEL_STATE_MISMATCH');
  await session.prompt('Reply with exactly PI_READY_OK.');await session.waitForIdle();
  const messages=session.messages.filter(message=>message.role==='assistant');
  const answer=messages.at(-1);
  report.answer=answer?{provider:answer.provider,model:answer.model,stopReason:answer.stopReason}:null;
  if(errors.length||!answer||answer.stopReason!=='stop')throw fail('ANSWER_ERROR_OR_ABORT');
  if(messages.some(message=>message.provider!==expected.provider||message.model!==expected.model))throw fail('ANSWER_MODEL_MISMATCH');
  const text=answer.content.filter(block=>block.type==='text').map(block=>block.text).join('').trim();
  if(text!=='PI_READY_OK')throw fail('ANSWER_CANARY_MISMATCH');
  report.status='PASS';return report;
 };
 try{
  return await Promise.race([work(),new Promise((_,reject)=>{timer=setTimeout(()=>reject(fail('TIMEOUT')),timeoutMs);})]);
 }finally{clearTimeout(timer);if(session){await session.abort();await session.extensionRunner?.emit({type:'session_shutdown',reason:'exit'});session.dispose();}}
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{
  const {values}=parseArgs({options:{'sdk-root':{type:'string'},'profile-dir':{type:'string'},provider:{type:'string'},model:{type:'string'},'timeout-ms':{type:'string'}}});
  if(!values['sdk-root']||!values['profile-dir'])throw Error('Usage: check-main-model.mjs --sdk-root <installed-core-package> --profile-dir <Code-or-Task-profile> [--provider <name>] [--model <id>] [--timeout-ms <ms>]');
  const timeoutMs=Number(values['timeout-ms']??60000);if(!Number.isFinite(timeoutMs)||timeoutMs<1)throw Error('Invalid timeout-ms');
  const result=await checkMainModel({sdkRoot:values['sdk-root'],profileDir:values['profile-dir'],provider:values.provider,model:values.model,timeoutMs});console.log(JSON.stringify(result));
 }catch(error){console.error(JSON.stringify(error.report??{status:'FAIL',route:'main',reason:'CHECK_FAILED',message:error.message.startsWith('Usage:')?error.message:undefined}));process.exitCode=2;}
}
