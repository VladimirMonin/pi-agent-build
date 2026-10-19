import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';
import { createHash } from 'node:crypto';

// Same real SDK/local-model fixture as core-smoke, plus installed production extensions.
export async function runCoordination(sdk, ai, sdkRoot, installedProfile, root) {
  fs.mkdirSync(root);
  const cwd = path.join(root, 'project'); fs.mkdirSync(cwd);
  fs.mkdirSync(path.join(cwd, '.pi', 'agents'), { recursive: true });
  const provider = fileURLToPath(new URL('./coordination-provider.mjs', import.meta.url));
  fs.writeFileSync(path.join(cwd, '.pi', 'agents', 'synthetic-child.md'), `---\nname: synthetic-child\ndescription: Synthetic read-only coordination child\nmodel: coord-child/mock\nthinking: off\ntools: contact_supervisor\nextensions: ${provider.replaceAll('\\', '/')}\nacceptanceRole: read-only\ninheritProjectContext: false\ninheritGlobalContext: false\ninheritSkills: false\n---\nAsk the supervisor once, then return the number it authorized. No model network.\n`);
  const report = { status: 'STARTED', checks: [], parentEvents: [], results: [] };
  const active = [], errors = [];
  let phase='setup';
  const completionRelease=path.join(cwd,'release-initial-completion');
  const completionNotices=(session,id)=>session.messages.filter(row=>row.customType==='subagent-notify'&&row.details?.runs?.some(run=>run.runId===id));
  const packagePath = name => path.join(installedProfile, 'npm/node_modules', name);
  for (const [name, version] of [['pi-subagents', '0.79.1'], ['pi-goal-x', '0.32.3'], ['pi-intercom', '0.17.1']]) {
    assert.equal(JSON.parse(fs.readFileSync(path.join(packagePath(name), 'package.json'), 'utf8')).version, version);
  }
  const wait = async (predicate, label, timeout = 45000) => {
    const deadline = Date.now() + timeout;
    while (!predicate()) { if (Date.now() > deadline) throw Error('Timeout: ' + label); await new Promise(resolve => setTimeout(resolve, 25)); }
  };
  async function probeForeignProcess(instance, id) {
    const env = {};
    for (const key of ('PATH PATHEXT SystemRoot WINDIR COMSPEC HOME USERPROFILE APPDATA LOCALAPPDATA TEMP TMP '
      + 'XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME PI_CODING_AGENT_SESSION_DIR '
      + 'PI_SESSION_DIR PI_SESSION_ARCHIVE_DIR PI_AGENT_BUILD_NPM_PREFIX PI_MCP_CONFIG_MODE PI_SUBAGENTS_TEMP_ROOT '
      + 'npm_config_cache npm_config_userconfig npm_config_globalconfig npm_config_prefix UV_CACHE_DIR UV_TOOL_DIR UV_TOOL_BIN_DIR').split(' ')) {
      if (process.env[key] !== undefined) env[key] = process.env[key];
    }
    assert(env.HOME && env.USERPROFILE && env.TEMP, 'Private child environment required');
    env.PI_PACKAGE_DIR = sdkRoot; env.PI_SUBAGENTS_PI_CODING_AGENT_PACKAGE_ROOT = sdkRoot; env.PI_OFFLINE = '1';
    env.PI_CODING_AGENT_DIR = path.join(root, 'foreign-process-agent'); fs.mkdirSync(env.PI_CODING_AGENT_DIR);
    fs.writeFileSync(path.join(env.PI_CODING_AGENT_DIR,'settings.json'), JSON.stringify({packages:[],extensions:['-builtin:mcp'],
      compaction:{enabled:false},retry:{enabled:false}}));
    const saved = path.join(root,'foreign-process-session.jsonl');
    fs.copyFileSync(instance.manager.getSessionFile(),saved); // Synthetic saved context; no concurrent file writers.
    const args = [fileURLToPath(new URL('../core-smoke.mjs',import.meta.url)),sdkRoot,
      path.join(root,'foreign-process'),installedProfile,'ownership',saved,id];
    const child = spawn(process.execPath,args,{cwd,env,stdio:['ignore','pipe','pipe'],timeout:15000});
    const result = {pid:child.pid,execPath:process.execPath,args,stdout:'',stderr:'',exitCode:null,signal:null};
    child.stdout.on('data',data => {result.stdout += data;}); child.stderr.on('data',data => {result.stderr += data;});
    await new Promise((resolve,reject) => {child.once('error',reject);child.once('close',(code,signal) => {
      result.exitCode=code;result.signal=signal;resolve();});});
    report.foreignProcess = result;
    assert.equal(result.signal,null);assert.equal(result.exitCode,0,result.stderr);
    const childReport = JSON.parse(fs.readFileSync(path.join(root,'foreign-process/report.json'),'utf8'));
    assert.equal(childReport.status,'PASS');
    const receipt = childReport.ownership;
    assert(receipt.pid === child.pid && receipt.pid !== process.pid && receipt.ppid === process.pid);
    assert.equal(receipt.sessionId,instance.manager.getSessionId(),'Probe must reopen the saved parent session identity');
    assert.equal(path.resolve(receipt.sdkRoot),path.resolve(sdkRoot));
    assert(receipt.result.isError && !receipt.result.details?.asyncId);
    report.foreignProcess.receipt = receipt;
  }
  let parent, peer, runId;
  async function start(label, manager) {
    const agentDir = path.join(root, label); if (!fs.existsSync(agentDir)) fs.mkdirSync(agentDir);
    const runtime = await sdk.ModelRuntime.create({ authPath: path.join(agentDir, 'auth.json'), modelsPath: null,
      modelsStorePath: path.join(agentDir, 'models.json'), allowModelNetwork: false, refreshOnCreate: false });
    const state = { label, command: null, answered: new Set(), channel: null, waitingForJoint: false };
    let session;
    runtime.registerProvider('coord-parent-' + label, { api: 'openai-completions', baseUrl: 'https://mock.invalid', apiKey: 'synthetic',
      models: [{ id: 'mock', name: 'mock', reasoning: false, input: ['text'], contextWindow: 65536, maxTokens: 256,
        compat: { supportsMidConvoSystemMessages: true, supportsMidConvoToolAdditions: true },
        cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 } }],
      streamSimple(model) {
        const stream = ai.createAssistantMessageEventStream();
        const message = { role: 'assistant', api: model.api, provider: model.provider, model: model.id,
          timestamp: Date.now(), content: [], stopReason: 'stop', usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0,
            totalTokens: 0, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } } };
        queueMicrotask(async () => {
          stream.push({ type: 'start', partial: message });
          let call;
          if (state.command && !state.command.used) { state.command.used = true; call = state.command; }
          else if (!state.command) {
            const request = session.messages.findLast(row => row.role === 'custom' && row.customType === 'subagent_supervisor_request'
              && row.details?.requestId && !state.answered.has(row.details.requestId));
            if (request) {
              state.waitingForJoint = true;
              if (state.jointGate) await state.jointGate;
              state.answered.add(request.details.requestId);
              call = { tool: 'subagent_supervisor', args: { action: 'reply', replyTo: request.details.requestId, message: 'USE_42' } };
            } else {
              const ask = session.messages.findLast(row => row.role === 'custom' && row.customType === 'intercom_message'
                && row.details?.message?.expectsReply && !state.answered.has(row.details.message.id));
              if (ask) {
                state.answered.add(ask.details.message.id);
                call = { tool: 'intercom', args: { action: 'reply', replyTo: ask.details.message.id, message: 'PEER_ANSWER:42' } };
              }
            }
          }
          message.content = call ? [{ type: 'toolCall', id: 'coord-' + Date.now(), name: call.tool, arguments: call.args }]
            : [{ type: 'text', text: 'COORDINATION_USEFUL_PARENT_RESULT' }];
          message.stopReason = call ? 'toolUse' : 'stop';
          stream.push({ type: 'done', reason: message.stopReason, message }); stream.end();
        });
        return stream;
      } });
    const settings = sdk.SettingsManager.inMemory({ packages: [], extensions: ['-builtin:mcp'],
      compaction: { enabled: false }, retry: { enabled: false } });
    const loader = new sdk.DefaultResourceLoader({ cwd, agentDir, settingsManager: settings,
      additionalExtensionPaths: [path.join(packagePath('pi-subagents'), 'index.js'),
        path.join(packagePath('pi-goal-x'), 'extensions/goal.ts'), path.join(packagePath('pi-intercom'), 'index.ts'), provider],
      extensionFactories: [pi => {
        pi.on('before_agent_start', event => {
          report.parentEvents.push({ label, phase, at:Date.now(), wake:event.prompt!=='FIXTURE_CALL',messageType: event.messageType, prompt: event.prompt,
            completionRuns:session.messages.filter(row=>row.customType==='subagent-notify').flatMap(row=>row.details?.runs?.map(run=>run.runId)??[]),
            intercomIds:session.messages.filter(row=>row.customType==='intercom_message').map(row=>row.details?.message?.id) });
        });
        pi.on('session_start', () => pi.events.emit('intercom:extension-register', { namespace: 'pi-build-fixture/v1', ownerEligible: label === 'parent',
          onReady: channel => { state.channel = channel; }, onEvent() {} }));
      }], noSkills: true, noPromptTemplates: true, noThemes: true, noContextFiles: true });
    await loader.reload(); assert.deepEqual(loader.getExtensions().errors, []);
    manager ??= sdk.SessionManager.create(cwd, path.join(root, 'sessions'));
    if (!manager.getSessionName()) manager.appendSessionInfo('fixture-' + label);
    ({ session } = await sdk.createAgentSession({ cwd, agentDir, modelRuntime: runtime,
      model: runtime.getModel('coord-parent-' + label, 'mock'), resourceLoader: loader, settingsManager: settings,
      sessionManager: manager, noTools: 'builtin' }));
    // RPC UI contract enables ordinary idle background operation, not headless auto-drain.
    const uiContext = { ...session.extensionRunner.getUIContext() };
    await session.bindExtensions({ mode: 'rpc', uiContext, onError: error => errors.push(String(error.error)) });
    const instance = { session, runtime, state, manager };
    active.push(instance);
    return instance;
  }
  async function call(instance, tool, args, allowError = false) {
    await instance.session.waitForIdle();
    instance.state.command = { tool, args, used: false };
    const before = instance.session.messages.length;
    try { await instance.session.prompt('FIXTURE_CALL'); await instance.session.waitForIdle(); }
    finally { instance.state.command = null; }
    const rows = instance.session.messages.slice(before).filter(row => row.role === 'toolResult' && row.toolName === tool);
    assert(rows.length, `No result for ${tool}`);
    const result = rows[0]; report.results.push({ label: instance.state.label, tool, args, result });
    if (!allowError) assert(!result.isError, JSON.stringify(result.content));
    return result;
  }
  async function close(instance) {
    if (!instance || instance.closed) return;
    instance.state.releaseJoint?.();
    await instance.session.abort();
    await instance.session.extensionRunner.emit({ type: 'session_shutdown', reason: 'exit' });
    instance.session.dispose(); instance.runtime.unregisterProvider('coord-parent-' + instance.state.label);
    instance.closed = true;
  }
  try {
    parent = await start('parent'); peer = await start('peer');
    await wait(() => parent.state.channel?.snapshot().connected && peer.state.channel?.snapshot().connected, 'real broker channels');
    await wait(() => parent.state.channel.snapshot().owner?.sessionId, 'extension owner');
    const roster = await call(peer, 'intercom', { action: 'list' });
    assert(JSON.stringify(roster).includes('fixture-parent'));
    parent.state.channel.commitState({ canary: 'RESTART_STATE_42' }, 0);
    await wait(() => parent.state.channel.snapshot().state?.payload?.canary === 'RESTART_STATE_42', 'state commit');
    if (parent.session.getActiveToolNames().includes('subagents_enable')) await call(parent, 'subagents_enable', {});
    if (peer.session.getActiveToolNames().includes('subagents_enable')) await call(peer, 'subagents_enable', {});
    assert(parent.session.getActiveToolNames().includes('subagent'));
    phase='joint';
    parent.state.jointGate = new Promise(resolve => { parent.state.releaseJoint = resolve; });
    const output = path.join(root, 'original-output.md');
    const launched = await call(parent, 'subagent', { agent: 'synthetic-child', task: 'SYNTHETIC_CHILD_TASK', async: true,
      output, model: 'coord-child/mock', options: { timeoutMs: 30000, context: 'fresh', mission: false } });
    runId = launched.details?.asyncId ?? launched.details?.runId ?? launched.details?.id;
    assert(runId, JSON.stringify(launched));
    await wait(() => parent.state.waitingForJoint, 'actual supervisor request and wake');
    const foreignResume = await call(peer, 'subagent', {action:'resume',id:runId,message:'FOREIGN_LIVE_RESUME_MUST_FAIL'}, true);
    assert(foreignResume.isError && !foreignResume.details?.asyncId, 'Another SDK session adopted a live run');
    await probeForeignProcess(parent, runId);
    const sent = await call(peer, 'intercom', { action: 'send', to: 'fixture-parent', message: 'JOINT_INTERCOM_CANARY' });
    assert.equal(sent.details?.delivery, 'socket_delivered', JSON.stringify(sent));
    // A busy receiver acknowledges receipt now, and injects steering only at the
    // next model/tool boundary. Do not deadlock that boundary behind the gate.
    parent.state.releaseJoint(); parent.state.jointGate = null;
    await wait(() => parent.session.messages.some(row => row.customType === 'intercom_message' && JSON.stringify(row).includes('JOINT_INTERCOM_CANARY')), 'receiver injection');
    await wait(()=>fs.readdirSync(cwd).some(name=>/^completion-held-\d+\.json$/.test(name)),'child authorized response held before completion');
    await parent.session.waitForIdle();
    await new Promise(resolve=>setTimeout(resolve,250));await parent.session.waitForIdle();
    const jointWakes=report.parentEvents.filter(row=>row.label==='parent'&&row.phase==='joint'&&row.wake);
    const injected=parent.session.messages.find(row=>row.customType==='intercom_message'&&JSON.stringify(row).includes('JOINT_INTERCOM_CANARY'));
    assert(injected?.details?.message?.id,'Missing actual injected message identity');
    assert.equal(jointWakes.length,1,'Joint exchange generated duplicate wakes AFTER injection/settlement');
    assert.equal(completionNotices(parent.session,runId).length,0,'Completion escaped its gate');
    assert(!fs.existsSync(output)||!fs.readFileSync(output,'utf8').includes('CHILD_USEFUL_RESULT:42'));
    report.wakeAccounting={joint:{wakes:jointWakes,injectedMessageId:injected.details.message.id,completionNoticeCount:0,completionHeld:true}};
    phase='completion';
    fs.writeFileSync(completionRelease,JSON.stringify({phase,at:Date.now()}));
    await wait(() => fs.existsSync(output) && fs.readFileSync(output, 'utf8').includes('CHILD_USEFUL_RESULT:42'), 'useful child output');
    await wait(()=>completionNotices(parent.session,runId).length>0,'distinct completion notice');
    await parent.session.waitForIdle();await new Promise(resolve=>setTimeout(resolve,250));await parent.session.waitForIdle();
    const completionWakes=report.parentEvents.filter(row=>row.label==='parent'&&row.phase==='completion'&&row.wake);
    const notifications=completionNotices(parent.session,runId);
    assert.equal(notifications.length,1);assert.equal(completionWakes.length,1,'Idle completion must independently wake once');
    assert(completionWakes[0].completionRuns.includes(runId),'Completion wake lacks actual run notice');
    assert(completionWakes[0].intercomIds.includes(injected.details.message.id),'Prior joint injection not retained');
    report.wakeAccounting.completion={wakes:completionWakes,runId,noticeCount:notifications.length};
    phase='post-completion';
    const status=await call(parent,'subagent',{action:'status',id:runId});
    assert(!JSON.stringify(status).includes('MISSING_SUPERVISOR_ANSWER'));
    const original = fs.readFileSync(output);
    phase='resume';
    const resumed = await call(parent, 'subagent', { action: 'resume', id: runId, message: 'RESUME_CANARY' });
    const resumedId = resumed.details?.asyncId ?? resumed.details?.runId ?? resumed.details?.id;
    assert(resumedId && resumedId !== runId, JSON.stringify(resumed));
    await wait(() => fs.readdirSync(root).some(name => name !== 'original-output.md' && name.endsWith('.md')
      && fs.readFileSync(path.join(root, name), 'utf8').includes('RESUMED_RESULT:84')), 'new resumed output');
    assert.deepEqual(fs.readFileSync(output), original, 'Resume overwrote original output');
    await parent.session.waitForIdle();
    const answer = await call(parent, 'intercom', { action: 'ask', to: 'fixture-peer', message: 'PEER_ASK_CANARY' });
    assert(JSON.stringify(answer).includes('PEER_ANSWER:42'));
    const manager = parent.manager, sessionFile = manager.getSessionFile();
    assert(sessionFile && fs.existsSync(sessionFile), 'Restart needs a real persisted session');
    await close(parent);
    parent = await start('parent', sdk.SessionManager.open(sessionFile));
    await wait(() => parent.state.channel?.snapshot().state?.payload?.canary === 'RESTART_STATE_42', 'extension-state readback after client restart');
    const after = await call(parent, 'subagent', { action: 'status' });
    assert(!JSON.stringify(after).includes('SYNTHETIC_CHILD_TASK'), 'Restart must not claim live-run ownership');
    const childReceipts = fs.readdirSync(cwd).filter(name => /^child-\d+\.json$/.test(name))
      .map(name => JSON.parse(fs.readFileSync(path.join(cwd, name), 'utf8'))).filter(row => row.pid !== process.pid);
    assert.equal(childReceipts.length,2,'Expected exactly initial and resumed child receipts');
    const hash=file=>createHash('sha256').update(fs.readFileSync(file)).digest('hex');
    const expectedRunner=fs.realpathSync(path.join(packagePath('pi-subagents'),'src/runs/background/subagent-runner-bootstrap.js'));
    const expectedSdk=fs.realpathSync(sdkRoot), expectedEntry=fs.realpathSync(path.join(sdkRoot,'dist/index.js'));
    function validateIdentity(receipt) {
      assert.equal(receipt.entrypoint.path,expectedRunner);assert.equal(receipt.entrypoint.sha256,hash(expectedRunner));
      assert.equal(receipt.sdkIdentity.root,expectedSdk);assert.equal(receipt.sdkIdentity.entry,expectedEntry);
      assert.equal(receipt.sdkIdentity.entrySha256,hash(expectedEntry));assert.equal(receipt.sdkIdentity.packageSha256,hash(path.join(sdkRoot,'package.json')));
      assert.equal(receipt.sdkIdentity.name,'@earendil-works/pi-coding-agent');assert.equal(receipt.sdkIdentity.version,'1.3.0');
      assert.equal(receipt.sdkIdentity.sessionManagerConstructorMatches,true,'Active context uses a different SDK class');
    }
    for (const receipt of childReceipts) {
      validateIdentity(receipt);
      assert.throws(()=>validateIdentity({...receipt,sdkIdentity:{...receipt.sdkIdentity,sessionManagerConstructorMatches:false}}));
      assert.throws(()=>validateIdentity({...receipt,entrypoint:{...receipt.entrypoint,sha256:'0'.repeat(64)}}));
      assert.equal(receipt.execPath, process.execPath);
      assert.equal(receipt.ppid, process.pid, 'Detached child must link to this SDK host');
      await wait(() => { try { process.kill(receipt.pid, 0); return false; } catch (error) { if (error.code === 'ESRCH') return true; throw error; } }, 'natural child process exit');
    }
    assert.deepEqual(errors, []);
    report.childReceipts = childReceipts;
    report.checks.push('HOST_FIRST_ACTUAL_CHILD_SUPERVISOR_REPLY_USEFUL_COMPLETION', 'JOINT_SUPERVISOR_INTERCOM_ONE_WAKE',
      'SEND_SOCKET_RECEIPT_ASK_REPLY', 'FOREIGN_SESSION_CANNOT_RESUME_LIVE_RUN', 'ACTUAL_FOREIGN_PI_PROCESS_SAME_SESSION_CANNOT_ADOPT_LIVE_RUN', 'NEW_RESUME_OUTPUT_PRESERVES_PRIOR_BYTES', 'CLIENT_RESTART_EXTENSION_STATE_NO_LIVE_OWNER_TRANSFER');
    report.status = 'PASS';
  } catch (error) { report.status = 'FAIL'; report.error = String(error.stack || error); throw error; }
  finally {
    if(!fs.existsSync(completionRelease))fs.writeFileSync(completionRelease,'failed-case cleanup');
    for (const instance of active.reverse()) await close(instance);
    report.errors = errors;
    fs.writeFileSync(path.join(root, 'report.json'), JSON.stringify(report, null, 2), { flag: 'wx' });
  }
  return report;
}

// Called only through core-smoke's ownership qualification in a separate real Node process.
export async function runOwnershipProbe(sdk, ai, sdkRoot, installedProfile, root, savedSession, liveRunId) {
  fs.mkdirSync(root);
  const cwd = process.cwd(), manager = sdk.SessionManager.open(savedSession);
  const runtime = await sdk.ModelRuntime.create({authPath:path.join(root,'auth.json'),modelsPath:null,
    modelsStorePath:path.join(root,'models.json'),allowModelNetwork:false,refreshOnCreate:false});
  let command, session;
  const errors=[];
  runtime.registerProvider('coord-owner',{api:'openai-completions',baseUrl:'https://mock.invalid',apiKey:'synthetic',
    models:[{id:'mock',name:'mock',reasoning:false,input:['text'],contextWindow:65536,maxTokens:256,
      cost:{input:0,output:0,cacheRead:0,cacheWrite:0}}],
    streamSimple(model){
      const stream=ai.createAssistantMessageEventStream();
      const call=command&&!command.used ? command : null;if(call)call.used=true;
      const message={role:'assistant',api:model.api,provider:model.provider,model:model.id,timestamp:Date.now(),
        content:call?[{type:'toolCall',id:'owner-'+Date.now(),name:call.tool,arguments:call.args}]:[{type:'text',text:'OWNERSHIP_PROBE_DONE'}],
        stopReason:call?'toolUse':'stop',usage:{input:0,output:0,cacheRead:0,cacheWrite:0,totalTokens:0,
          cost:{input:0,output:0,cacheRead:0,cacheWrite:0,total:0}}};
      queueMicrotask(()=>{stream.push({type:'start',partial:message});stream.push({type:'done',reason:message.stopReason,message});stream.end();});return stream;
    }});
  try {
    const settings=sdk.SettingsManager.inMemory({packages:[],extensions:['-builtin:mcp'],compaction:{enabled:false},retry:{enabled:false}});
    const loader=new sdk.DefaultResourceLoader({cwd,agentDir:root,settingsManager:settings,
      additionalExtensionPaths:[path.join(installedProfile,'npm/node_modules/pi-subagents/index.js')],
      noSkills:true,noPromptTemplates:true,noThemes:true,noContextFiles:true});
    await loader.reload();assert.deepEqual(loader.getExtensions().errors,[]);
    ({session}=await sdk.createAgentSession({cwd,agentDir:root,modelRuntime:runtime,model:runtime.getModel('coord-owner','mock'),
      resourceLoader:loader,settingsManager:settings,sessionManager:manager,noTools:'builtin'}));
    await session.bindExtensions({mode:'rpc',uiContext:{...session.extensionRunner.getUIContext()},onError:e=>errors.push(String(e.error))});
    async function invoke(tool,args){
      await session.waitForIdle();const before=session.messages.length;command={tool,args,used:false};
      try{await session.prompt('SYNTHETIC_LIVE_OWNER_PROBE');await session.waitForIdle();}finally{command=null;}
      const result=session.messages.slice(before).find(row=>row.role==='toolResult'&&row.toolName===tool);assert(result);return result;
    }
    if(session.getActiveToolNames().includes('subagents_enable'))assert(!(await invoke('subagents_enable',{})).isError);
    assert(session.getActiveToolNames().includes('subagent'));
    const result=await invoke('subagent',{action:'resume',id:liveRunId,message:'FOREIGN_PROCESS_MUST_NOT_ADOPT_LIVE_RUN'});
    assert(result.isError&&!result.details?.asyncId,JSON.stringify(result));
    assert(/not found in the active session|another (?:live )?(?:process|session)|owned by|already running/i.test(JSON.stringify(result.content)),JSON.stringify(result));
    assert.deepEqual(errors,[]);
    return {status:'PASS',pid:process.pid,ppid:process.ppid,sdkRoot,sessionId:manager.getSessionId(),result};
  } finally {
    if(session){await session.abort();await session.extensionRunner.emit({type:'session_shutdown',reason:'exit'});session.dispose();}
    runtime.unregisterProvider('coord-owner');
  }
}
