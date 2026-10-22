// Real Pi provider registration, deterministic synthetic responses, no network.
import fs from 'node:fs';
import path from 'node:path';
import {createAssistantMessageEventStream} from '@earendil-works/pi-ai';
export default function(pi) {
 const config=JSON.parse(fs.readFileSync(path.join(process.env.PI_CODING_AGENT_DIR!,'main-model-fixture.json'),'utf8'));
 for(const provider of ['polza','polza-memory']) {
  const ids=provider==='polza'?config.models:['memory-only'];
  pi.registerProvider(provider,{name:'Synthetic '+provider,api:'openai-completions',apiKey:'EXAMPLE_SYNTHETIC_FIXTURE',baseUrl:'https://mock.invalid',
   models:ids.map(id=>({id,name:id,reasoning:false,input:['text'],contextWindow:32768,maxTokens:128,cost:{input:0,output:0,cacheRead:0,cacheWrite:0}})),
   streamSimple(model,context,options){
    const stream=createAssistantMessageEventStream();
    const message={role:'assistant',api:model.api,provider:model.provider,model:model.id,timestamp:Date.now(),content:[{type:'text',text:config.answer??'PI_READY_OK'}],stopReason:'stop',usage:{input:0,output:0,cacheRead:0,cacheWrite:0,totalTokens:0,cost:{input:0,output:0,cacheRead:0,cacheWrite:0,total:0}}};
    const finish=()=>{if(config.mode==='error'){message.stopReason='error';message.errorMessage='Synthetic response failure';}if(config.mode==='aborted')message.stopReason='aborted';if(config.mode==='wrong-answer')message.content=[{type:'text',text:'WRONG_SYNTHETIC_ANSWER'}];if(config.mode==='wrong-model')message.model='not-the-selected-model';stream.push({type:'start',partial:message});stream.push({type:'done',reason:message.stopReason,message});stream.end();};
    if(config.mode==='timeout')options?.signal?.addEventListener('abort',()=>{message.stopReason='aborted';finish();},{once:true});else queueMicrotask(finish);
    return stream;
   }});
 }
}
