// Invoke the actual checker CLI so a printed FAIL cannot hide exit zero.
import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';import {fileURLToPath} from 'node:url';
import {assertSyntheticPaths} from './fixtures/synthetic-paths.mjs';
const [sdkRoot,root]=process.argv.slice(2);assert(sdkRoot&&root);assertSyntheticPaths(sdkRoot,root);fs.mkdirSync(root,{recursive:true});
const checker=fileURLToPath(new URL('../../scripts/check-main-model.mjs',import.meta.url));
const fixture=fileURLToPath(new URL('./fixtures/main-model.ts',import.meta.url));
const refusedOutput=path.join(root,'guard-must-not-create');
assert.throws(()=>assertSyntheticPaths(sdkRoot,refusedOutput,fixture),/admitted runtime root/);
assert(!fs.existsSync(refusedOutput),'outside package rejected before fixture I/O');
const rows=[];
const cases=[
 ['code-valid','code-main',['code-main','alternate'],'valid',[],0,'PASS'],
 ['task-valid','task-main',['task-main'],'valid',[],0,'PASS'],
 ['empty-main-memory-present','code-main',[],'valid',[],2,'EXPECTED_MODEL_UNAVAILABLE'],
 ['bad-id','bad-id',['code-main'],'valid',[],2,'EXPECTED_MODEL_UNAVAILABLE'],
 ['explicit-alternate','code-main',['code-main','alternate'],'valid',['--provider','polza','--model','alternate'],0,'PASS'],
 ['missing-explicit-alternate','code-main',['code-main'],'valid',['--model','missing-alternate'],2,'REQUESTED_MODEL_UNAVAILABLE'],
 ['error-answer','code-main',['code-main'],'error',[],2,'ANSWER_ERROR_OR_ABORT'],
 ['aborted-answer','code-main',['code-main'],'aborted',[],2,'ANSWER_ERROR_OR_ABORT'],
 ['wrong-structured-model','code-main',['code-main'],'wrong-model',[],2,'ANSWER_MODEL_MISMATCH'],
 ['wrong-canary','code-main',['code-main'],'wrong-answer',[],2,'ANSWER_CANARY_MISMATCH'],
 ['timeout','code-main',['code-main'],'timeout',['--timeout-ms','4000'],2,'TIMEOUT'],
];
for(const [name,expected,models,mode,extra,exit,reason]of cases){
 const profile=path.join(root,name);fs.mkdirSync(profile);
 fs.writeFileSync(path.join(profile,'settings.json'),JSON.stringify({defaultProvider:'polza',defaultModel:expected,packages:[],extensions:[fixture,'-builtin:mcp','-builtin:llama.cpp','-builtin:codemode','-builtin:tool-search'],retry:{enabled:false},compaction:{enabled:false}}));
 fs.writeFileSync(path.join(profile,'main-model-fixture.json'),JSON.stringify({models,mode}));
 const p=spawnSync(process.execPath,[checker,'--sdk-root',sdkRoot,'--profile-dir',profile,...extra],{cwd:root,env:{...process.env,PI_CODING_AGENT_DIR:profile},encoding:'utf8',timeout:15000});
 fs.writeFileSync(path.join(profile,'stdout.txt'),p.stdout??'');fs.writeFileSync(path.join(profile,'stderr.txt'),p.stderr??'');
 assert.equal(p.status,exit,`${name}: native exit ${p.status}: ${p.stderr} ${p.error??''}`);
 const report=JSON.parse((exit===0?p.stdout:p.stderr).trim().split(/\r?\n/).at(-1));
 assert.equal(exit===0?report.status:report.reason,reason,`${name}: ${JSON.stringify(report)}`);
 assert.equal(report.expected.provider,'polza');
 if(exit===0){assert.equal(report.expected.model,name==='explicit-alternate'?'alternate':expected);assert.deepEqual(report.actual,report.expected);assert.equal(report.answer.provider,'polza');assert.equal(report.answer.model,report.expected.model);}
 if(name==='empty-main-memory-present')assert.notEqual(report.actual?.provider,'polza','memory fallback must not certify main');
 rows.push({name,exit:p.status,status:report.status,reason:report.reason??null,expected:report.expected,actual:report.actual,answer:report.answer});
}
console.log(JSON.stringify({status:'PASS',scope:'REAL_PI_SDK_SYNTHETIC_PROVIDERS_NO_NETWORK',cases:rows}));
