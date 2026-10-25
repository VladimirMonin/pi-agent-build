// Actual canonical parser/merge + searchMemory + HTTP embedder, synthetic I/O only.
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import test from 'node:test';
const source=readFileSync(process.argv[2],'utf8');
function region(start,end) {
 const a=source.indexOf(start),b=source.indexOf(end,a+start.length);
 assert(a>=0&&b>a,`missing region: ${start}`);return source.slice(a,b);
}
function topFunction(name) {
 const a=source.indexOf(`function ${name}(`),b=source.indexOf('\n}',a);
 assert(a>=0&&b>a,`missing function: ${name}`);return source.slice(a,b+2);
}
const embedder=region('// src/embedder.ts','// src/hybrid.ts');
const factory=await import('data:text/javascript;base64,'+Buffer.from(embedder+'\nexport {createEmbedder};').toString('base64'));
const configCode=region('var EMBEDDER_TYPES =','function readSettingsConfig(');
const merge=topFunction('mergeMemorySettings');
const search=region('  async function searchMemory(','  let pendingContextBlock =');
const rrf=new Function(region('var RRF_K =','function reciprocalRankFusion(')+topFunction('reciprocalRankFusion')+';return reciprocalRankFusion;')();
const official='Instruct: Given a web search query, retrieve relevant passages that answer the query\nQuery:';
const cases=[
 ['Qwen namespaced', {model:'qwen/qwen3-embedding-8b'},official],
 ['Qwen mixed-case local', {model:'QwEn3-EmBeDdInG-0.6B-GGUF'},official],
 ['OpenAI raw', {model:'text-embedding-3-small'},''],
 ['unknown family raw', {model:'unknown-encoder'},''],
 ['missing model uses raw provider default', {},''],
 ['empty override', {model:'qwen/qwen3-embedding-8b',queryPrefix:''},''],
 ['whitespace override', {model:'qwen/qwen3-embedding-8b',queryPrefix:' \n '},' \n '],
 ['custom override on another family', {model:'unknown-encoder',queryPrefix:'CUSTOM:\n'},'CUSTOM:\n'],
 ...[null,7,{},false].map(value=>['non-string override '+JSON.stringify(value),{model:'qwen/qwen3-embedding-8b',queryPrefix:value},official])
];
for(const [label,extra,prefix] of cases)test(label,{concurrency:false},async()=>{
 const warnings=[];
 const parseAndMerge=new Function('warnUnknownKeys',`${configCode}\n${merge}\nreturn (raw)=>{const c={};mergeMemorySettings(c,{embedding:raw});return c;};`)((block,_name,keys)=>warnings.push(...Object.keys(block).filter(k=>!keys.includes(k))));
 const raw={type:'openai-compatible',baseUrl:'https://fixture.invalid',apiKey:'EXAMPLE_SYNTHETIC_KEY',dimensions:1024,sendDimensions:true,...extra};
 const config=parseAndMerge(raw);
 const calls=[],fts=[];let vectorSearches=0;
 const previousFetch=globalThis.fetch;
 globalThis.fetch=async(url,options)=>{
  const body=JSON.parse(options.body);calls.push({url:String(url),...body});
  const inputs=Array.isArray(body.input)?body.input:[body.input];
  return new Response(JSON.stringify({data:inputs.map((_,index)=>({index,embedding:Array.from({length:1024},(_,i)=>i===0?1:0)}))}),{status:200,headers:{'content-type':'application/json'}});
 };
 try{
  const emb=factory.createEmbedder(config.embedding);
  await emb.embed('synthetic document');
  await emb.embedBatch(['batch document one','batch document two']);
  const entry={key:'user.synthetic_fixture',value:'synthetic value'};
  const store={searchSemantic(q){fts.push(q);return [entry];},searchSemanticByVector(v){assert(v instanceof Float32Array);assert.equal(v.length,1024);vectorSearches++;return [entry];}};
  const run=new Function('store','getEmbedder','injectorConfig','reportEmbedFailure','reciprocalRankFusion',search+'\nreturn searchMemory;')(store,()=>emb,config,e=>{throw e;},rrf);
  const query='synthetic retrieval question';
  const found=await run(query,10);
  assert.deepEqual(fts,[query],'FTS input must remain raw');
  assert.equal(vectorSearches,1);assert.equal(found[0].key,entry.key);
  assert.deepEqual(calls[0].input,['synthetic document'],'single document changed');
  assert.deepEqual(calls[1].input,['batch document one','batch document two'],'batch documents changed');
  for(const call of calls){assert.equal(call.model,raw.model??'text-embedding-3-small');assert.equal(call.dimensions,1024);assert.equal(call.url,'https://fixture.invalid/v1/embeddings');}
  assert.deepEqual(calls[2].input,[prefix+query],'embedding query must follow model/explicit prefix');
  if(typeof extra.queryPrefix==='string')assert.equal(config.embedding.queryPrefix,extra.queryPrefix,'parser/merge lost exact override');
  else assert(!Object.hasOwn(config.embedding,'queryPrefix'),'invalid or absent override should be omitted');
  assert.deepEqual(warnings,[],'supported prefix must not be an unknown key');
 }finally{globalThis.fetch=previousFetch;}
});
