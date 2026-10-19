import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { pathToFileURL } from 'node:url';
import { createRequire } from 'node:module';

export async function runGoal(sdk, ai, sdkRoot, profile, root) {
  fs.mkdirSync(root); const cwd = path.join(root, 'project'); fs.mkdirSync(cwd);
  const agentDir = path.join(root, 'agent'); fs.mkdirSync(agentDir);
  const goalRoot = path.join(profile, 'npm/node_modules/pi-goal-x');
  const { createJiti } = await import(pathToFileURL(path.join(sdkRoot, 'node_modules/jiti/lib/jiti.mjs')).href);
  const jiti = createJiti(import.meta.url, { alias: { typebox: createRequire(path.join(sdkRoot, 'dist/core/extensions/loader.js')).resolve('typebox'),
    '@earendil-works/pi-coding-agent': path.join(sdkRoot, 'dist/index.js'),
    '@earendil-works/pi-ai': path.join(sdkRoot, 'node_modules/@earendil-works/pi-ai/dist/index.js'),
    '@earendil-works/pi-tui': path.join(sdkRoot, 'node_modules/@earendil-works/pi-tui/dist/index.js') } });
  const goalExtension = await jiti.import(path.join(goalRoot, 'extensions/goal.ts'), { default: true });
  const { GOAL_EVENT_ENTRY } = await jiti.import(path.join(goalRoot, 'extensions/goal-format.ts'), { default: false });
  const { checkpointTriggerPrompt } = await jiti.import(path.join(goalRoot, 'extensions/prompts/goal-prompts.ts'), { default: false });
  const report = { status: 'STARTED', checks: [], starts: [], snapshots: [] }, errors = [];
  let session, core, phase = 'idle', calls = 0, auditorCalls = 0, providerAbortInjected = false, holdEntered = false;
  const wait = async (predicate, label) => { const end = Date.now() + 20000;
    while (!predicate()) { if (Date.now() > end) throw Error('Timeout: ' + label); await new Promise(resolve => setTimeout(resolve, 20)); } };
  const runtime = await sdk.ModelRuntime.create({ authPath: path.join(agentDir, 'auth.json'), modelsPath: null,
    modelsStorePath: path.join(agentDir, 'models.json'), allowModelNetwork: false, refreshOnCreate: false });
  runtime.registerProvider('goal-fixture', { api: 'openai-completions', baseUrl: 'https://mock.invalid', apiKey: 'synthetic',
    models: [{ id: 'mock', name: 'mock', reasoning: false, input: ['text'], contextWindow: 32768, maxTokens: 256,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 } }],
    streamSimple(model, _context, options) {
      calls++; if (calls > 20) throw Error('Synthetic Goal fixture exceeded its finite response sequence');
      const stream = ai.createAssistantMessageEventStream();
      const message = { role: 'assistant', api: model.api, provider: model.provider, model: model.id, timestamp: Date.now(),
        content: [], stopReason: 'stop', usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0,
          cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } } };
      queueMicrotask(() => {
        stream.push({ type: 'start', partial: message });
        if (phase === 'create' && core.state.goal?.status === 'active') {
          if (!providerAbortInjected) {
            providerAbortInjected = true; message.stopReason = 'aborted'; message.errorMessage = 'SYNTHETIC_PROVIDER_ABORT_WITHOUT_USER_SIGNAL';
            stream.push({ type: 'error', reason: 'aborted', error: message }); stream.end(); return;
          }
          holdEntered = true;
          const abort = () => { message.stopReason = 'aborted'; message.errorMessage = 'SYNTHETIC_USER_STOP';
            stream.push({ type: 'error', reason: 'aborted', error: message }); stream.end(); };
          options.signal.addEventListener('abort', abort, { once: true });
          if (options.signal.aborted) abort();
          return;
        }
        let tool;
        if (phase === 'create') tool = { name: 'create_goal', arguments: { objective: 'Synthetic fixture goal: complete only after the Stop/resume check.', mode: 'regular' } };
        else if (phase === 'complete' && core.state.goal?.status === 'active') tool = { name: 'update_goal', arguments: { status: 'complete', completion_summary: 'Synthetic Stop and checkpoint contract verified.' } };
        message.content = tool ? [{ type: 'toolCall', id: 'goal-' + calls, ...tool }] : [{ type: 'text', text: 'GOAL_FIXTURE_DONE' }];
        message.stopReason = tool ? 'toolUse' : 'stop';
        stream.push({ type: 'done', reason: message.stopReason, message }); stream.end();
      });
      return stream;
    } });
  try {
    const settings = sdk.SettingsManager.inMemory({ packages: [], extensions: ['-builtin:mcp'], compaction: { enabled: false }, retry: { enabled: false } });
    const loader = new sdk.DefaultResourceLoader({ cwd, agentDir, settingsManager: settings, noSkills: true,
      noPromptTemplates: true, noThemes: true, noContextFiles: true, extensionFactories: [pi => {
        goalExtension(pi, { runCompletionAuditor: async () => { auditorCalls++; return { approved: true, disapproved: false, output: 'SYNTHETIC_AUDIT_APPROVED' }; } });
        core = pi._goalCore; // Upstream's explicit test/debug introspection hook.
        pi.on('before_agent_start', event => report.starts.push({ messageType: event.messageType, prompt: event.prompt,
          customType: event.message?.customType, checkpoint: core.runtime.getCheckpointGoalId() }));
      }] });
    await loader.reload(); assert.deepEqual(loader.getExtensions().errors, []);
    ({ session } = await sdk.createAgentSession({ cwd, agentDir, modelRuntime: runtime, model: runtime.getModel('goal-fixture', 'mock'),
      settingsManager: settings, resourceLoader: loader, noTools: 'builtin', sessionManager: sdk.SessionManager.create(cwd, path.join(root, 'sessions')) }));
    await session.bindExtensions({ mode: 'rpc', uiContext: { ...session.extensionRunner.getUIContext() }, onError: error => errors.push(String(error.error)) });
    await session.prompt('Synthetic ordinary user turn'); await session.waitForIdle();
    const beforeStale = calls;
    await session.sendCustomMessage({ customType: GOAL_EVENT_ENTRY, content: checkpointTriggerPrompt('synthetic-stale-goal'),
      details: { version: 3, kind: 'checkpoint', goalId: 'synthetic-stale-goal' }, display: false }, { triggerTurn: true });
    await session.waitForIdle();
    report.snapshots.push({ case: 'stale-custom-checkpoint', before: beforeStale, after: calls });
    assert.equal(calls, beforeStale, 'Stale custom Goal checkpoint reached the model instead of aborting');
    phase = 'create';
    const activePrompt = session.prompt('Explicitly create the synthetic fixture goal, then wait for Stop.');
    await wait(() => providerAbortInjected, 'provider-side abort'); await activePrompt; await session.waitForIdle();
    assert.equal(core.state.goal?.status, 'active', 'Provider-side abort without user signal must not pause Goal');
    const goalId = core.state.goal.id;
    const stopPrompt = session.prompt('Synthetic explicit Stop check');
    await wait(() => holdEntered, 'active goal and blocked stream');
    await session.abort(); await stopPrompt; await session.waitForIdle();
    assert.equal(core.state.goal?.status, 'paused', 'Genuine user Stop must pause the synthetic goal');
    const stoppedCalls = calls; await new Promise(resolve => setTimeout(resolve, 250));
    assert.equal(calls, stoppedCalls, 'Goal ignored Stop and continued');
    phase = 'complete';
    await session.prompt('/goal-resume');
    // Let Goal's real scheduler claim and deliver its own generation/dispatch;
    // fabricating a checkpoint here would correctly fail its authorization gate.
    report.snapshots.push({case:'resume',goal:core.state.goal});
    await wait(() => session.messages.some(message => message.role === 'toolResult' && message.toolName === 'update_goal'
      && message.details?.goal?.id === goalId && message.details.goal.status === 'complete'), 'audited synthetic completion');
    await session.waitForIdle();
    // Completion may remove the goal from the open-goal cache; verify durable output.
    const goalDir = process.env.PI_GOAL_ROOT || path.join(cwd, '.pi/goals');
    const completed = fs.readdirSync(goalDir, { recursive: true }).filter(name => name.endsWith('.md'))
      .map(name => fs.readFileSync(path.join(goalDir, name), 'utf8'));
    assert(completed.some(text => text.includes(`"id": "${goalId}"`) && /"status"\s*:\s*"complete"/.test(text)), 'No durable completed synthetic goal');
    assert.equal(auditorCalls, 1); assert.deepEqual(errors, []);
    report.checks.push('ORDINARY_USER_STALE_CUSTOM_CHECKPOINT_REJECTED', 'PROVIDER_ABORT_WITHOUT_SIGNAL_DOES_NOT_PAUSE', 'GENUINE_USER_STOP_PAUSES_NO_AUTONOMOUS_CONTINUATION',
      'VALID_CUSTOM_CHECKPOINT_RESUME_COMPLETES_WITH_OFFLINE_AUDITOR');
    report.status = 'PASS';
  } catch (error) { report.status = 'FAIL'; report.error = String(error.stack || error); throw error; }
  finally {
    if (session) { await session.abort(); await session.extensionRunner.emit({ type: 'session_shutdown', reason: 'exit' }); session.dispose(); }
    runtime.unregisterProvider('goal-fixture'); report.calls = calls; report.auditorCalls = auditorCalls; report.errors = errors;
    fs.writeFileSync(path.join(root, 'report.json'), JSON.stringify(report, null, 2), { flag: 'wx' });
  }
  return report;
}
