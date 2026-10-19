import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { createRequire, syncBuiltinESMExports } from 'node:module';
import { pathToFileURL } from 'node:url';
import os from 'node:os';

export async function runProfiles(sdk, ai, profile, root) {
  fs.mkdirSync(root); const cwd = path.join(root, 'project'); fs.mkdirSync(path.join(cwd, '.pi'), { recursive: true });
  const source = path.join(root, 'source-sessions'), archive = path.join(root, 'archive'), extra = path.join(root, 'extra');
  for (const dir of [source, archive, extra, path.join(root, 'search')]) fs.mkdirSync(dir);
  fs.writeFileSync(path.join(cwd, '.pi/settings.json'), JSON.stringify({ 'pi-memory': { localPath: path.join(root, 'memory') },
    'pi-session-search': { localPath: path.join(root, 'search') } }));
  fs.writeFileSync(path.join(root, 'search/config.json'), JSON.stringify({ sessionDir: source, archiveDir: archive,
    extraSessionDirs: [extra], extraArchiveDirs: [], sync: { interval: -1, initialDelay: 0 }, primer: { enabled: false } }));
  const id = randomUUID(), canary = 'SYNTHETIC_SEARCH_CANARY_' + id;
  const nativeMessage = { role: 'assistant', content: [{ type: 'text', text: canary }], api: 'openai-completions',
    provider: 'profile-fixture', model: 'mock', timestamp: Date.now(), stopReason: 'stop',
    usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } } };
  const manager = sdk.SessionManager.create(cwd, source);
  manager.appendMessage({ role: 'user', content: canary, timestamp: Date.now() }); manager.appendMessage(nativeMessage);
  const ownFile = manager.getSessionFile(); assert(ownFile && fs.existsSync(ownFile));
  const extraFiles = [archive, extra].map(dir => {
    const saved = sdk.SessionManager.create(cwd, dir);
    saved.appendMessage({role:'user',content:canary,timestamp:Date.now()}); saved.appendMessage(nativeMessage);
    return saved.getSessionFile();
  });
  const previousPrefix = process.env.PI_AGENT_BUILD_NPM_PREFIX;
  const fakePrefix = path.join(root, 'consolidation-prefix');
  const fakeCli = path.join(fakePrefix, 'node_modules/@earendil-works/pi-coding-agent/dist/bundle/cli.js');
  fs.mkdirSync(path.dirname(fakeCli), {recursive:true});
  fs.writeFileSync(fakeCli, 'console.log(JSON.stringify({semantic:[],lessons:[]}));');
  process.env.PI_AGENT_BUILD_NPM_PREFIX = fakePrefix; // No consolidation/model service probes in the full-profile case.
  const sdkRoot = process.env.PI_PACKAGE_DIR;
  const {createJiti} = await import(pathToFileURL(path.join(sdkRoot,'node_modules/jiti/lib/jiti.mjs')).href);
  const jiti = createJiti(import.meta.url);
  const configApi = await jiti.import(path.join(profile,'npm/node_modules/pi-session-search/src/config.ts'),{default:false});
  const defaultBase = path.basename(profile) === 'task' ? path.join(profile,'session-search') : path.join(os.homedir(),'.pi/session-search');
  assert.equal(path.resolve(configApi.getConfigPath()),path.resolve(path.join(defaultBase,'config.json')));
  assert.equal(path.resolve(configApi.getIndexDir()),path.resolve(path.join(defaultBase,'index')));
  const outside = path.join(root, 'outside.jsonl'); fs.copyFileSync(ownFile, outside);
  const originalSettings = fs.readFileSync(path.join(profile, 'settings.json'));
  const settingsData = JSON.parse(originalSettings);
  const workerModule = createRequire(import.meta.url)('node:worker_threads'), OriginalWorker = workerModule.Worker;
  const workers = [];
  workerModule.Worker = class extends OriginalWorker {
    constructor(file, options) { super(file, options);
      if (String(file).includes('pi-session-search')) { const row = { file: String(file), threadId: this.threadId, exited: false };
        workers.push(row); this.on('error', error => { row.error = String(error); });
        this.on('exit', code => { row.exited = true; row.exitCode = code; }); }
    }
  };
  syncBuiltinESMExports();
  const report = { status: 'STARTED', workers, phases: [], checks: [] }, errors = [];
  let session, runtime;
  try {
    for (const traceOn of [false, true, false]) {
      let command;
      const settings = sdk.SettingsManager.inMemory(settingsData);
      const tracePath = path.join(profile, 'npm/node_modules/pi-trace-extension/extensions/trace/index.ts');
      const loader = new sdk.DefaultResourceLoader({ cwd, agentDir: profile, settingsManager: settings,
        additionalExtensionPaths: traceOn ? [tracePath] : [], noSkills: true, noPromptTemplates: true,
        noThemes: true, noContextFiles: true });
      await loader.reload(); assert.deepEqual(loader.getExtensions().errors, []);
      assert.equal(loader.getExtensions().extensions.some(extension => extension.path.includes('pi-trace-extension')), traceOn);
      runtime = await sdk.ModelRuntime.create({ authPath: path.join(root, `auth-${report.phases.length}.json`), modelsPath: null,
        modelsStorePath: path.join(root, `models-${report.phases.length}.json`), allowModelNetwork: false, refreshOnCreate: false });
      runtime.registerProvider('profile-fixture', { api: 'openai-completions', baseUrl: 'https://mock.invalid', apiKey: 'synthetic',
        models: [{ id: 'mock', name: 'mock', reasoning: false, input: ['text'], contextWindow: 65536, maxTokens: 256,
          cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 } }],
        streamSimple(model, context) {
          const stream = ai.createAssistantMessageEventStream();
          const last = context.messages.findLast(message => message.role !== 'system');
          const call = command && last?.role !== 'toolResult';
          const message = { ...nativeMessage, provider: model.provider, model: model.id, timestamp: Date.now(),
            content: call ? [{ type: 'toolCall', id: 'profile-' + Date.now(), name: command.tool, arguments: command.args }]
              : [{ type: 'text', text: 'PROFILE_FULL_COMBINATION_OK' }], stopReason: call ? 'toolUse' : 'stop' };
          queueMicrotask(() => { stream.push({ type: 'start', partial: message }); stream.push({ type: 'done', reason: message.stopReason, message }); stream.end(); });
          return stream;
        } });
      ({ session } = await sdk.createAgentSession({ cwd, agentDir: profile, modelRuntime: runtime,
        model: runtime.getModel('profile-fixture', 'mock'), settingsManager: settings, resourceLoader: loader,
        sessionManager: sdk.SessionManager.create(cwd, path.join(root, 'sessions')), noTools: 'builtin' }));
      await session.bindExtensions({ mode: 'rpc', onError: error => errors.push(String(error.error)) });
      assert(!session.getActiveToolNames().some(name => /^(fusion_|bg_run|bg_delegate)/.test(name)), 'Background Tasks re-enabled');
      async function call(tool, args) {
        command = { tool, args }; const before = session.messages.length;
        await session.prompt('SYNTHETIC_PROFILE_CHECK'); await session.waitForIdle(); command = null;
        const rows = session.messages.slice(before).filter(message => message.role === 'toolResult' && message.toolName === tool);
        assert.equal(rows.length, 1); return rows[0];
      }
      if (report.phases.length === 0) {
        let found; const deadline = Date.now() + 20000;
        do { found = await call('session_search', { query: canary, limit: 5 });
          if (JSON.stringify(found).includes(id)) break;
          await new Promise(resolve => setTimeout(resolve, 50));
        } while (Date.now() < deadline);
        assert(JSON.stringify(found).includes(id), 'Worker did not index the configured synthetic source');
        const read = await call('session_read', { session: ownFile });
        assert(JSON.stringify(read).includes(canary));
        const archiveRead = await call('session_read', { session: extraFiles[0] });
        const extraRead = await call('session_read', { session: extraFiles[1] });
        assert(JSON.stringify(archiveRead).includes(canary) && JSON.stringify(extraRead).includes(canary));
        const rejected = await call('session_read', { session: outside });
        assert(!JSON.stringify(rejected.content).includes(canary), 'Reader exposed a file outside configured roots');
        assert(/outside|not allowed|not found|escape|denied/i.test(JSON.stringify(rejected.content)), JSON.stringify(rejected));
        report.search = { found, read, archiveRead, extraRead, rejected, defaultBase };
      } else { await session.prompt('TRACE_SYNTHETIC_TURN'); await session.waitForIdle(); }
      assert.equal(session.getLastAssistantText(), 'PROFILE_FULL_COMBINATION_OK');
      const sessionId = session.sessionManager.getSessionId();
      const sessionFile = session.sessionManager.getSessionFile();
      await session.extensionRunner.emit({ type: 'session_shutdown', reason: 'exit' }); session.dispose(); session = null;
      runtime.unregisterProvider('profile-fixture'); runtime = null;
      const traceDir = path.join(profile, 'traces', path.basename(sessionFile, '.jsonl'));
      assert.equal(fs.existsSync(path.join(traceDir, 'events.jsonl')), traceOn, 'Trace default/opt-in behavior drift');
      if (traceOn) assert(fs.existsSync(path.join(traceDir, 'trace.html')), 'Trace renderer did not finish');
      report.phases.push({ traceOn, sessionId, traceDir });
    }
    const deadline = Date.now() + 10000;
    while (workers.some(worker => !worker.exited) && Date.now() < deadline) await new Promise(resolve => setTimeout(resolve, 25));
    assert(workers.length >= 3, 'Actual Session Search workers were not observed');
    assert(workers.every(worker => worker.threadId > 0 && worker.exited && !worker.error), 'Worker cleanup incomplete or failed');
    assert.deepEqual(fs.readFileSync(path.join(profile, 'settings.json')), originalSettings, 'Canonical settings changed');
    assert.deepEqual(errors, []);
    report.checks.push('FULL_PROFILE_LOCAL_MOCK_BOTH_FILTERS', 'TRACE_OFF_OPT_IN_OFF_WITH_HTML', 'ACTUAL_WORKER_SEARCH_READ_CONFIGURED_SOURCE_ESCAPE_REJECTION_CLEANUP');
    report.status = 'PASS';
  } catch (error) { report.status = 'FAIL'; report.error = String(error.stack || error); throw error; }
  finally {
    if (session) { await session.extensionRunner.emit({ type: 'session_shutdown', reason: 'exit' }); session.dispose(); }
    runtime?.unregisterProvider('profile-fixture'); workerModule.Worker = OriginalWorker; syncBuiltinESMExports();
    if (previousPrefix === undefined) delete process.env.PI_AGENT_BUILD_NPM_PREFIX;
    else process.env.PI_AGENT_BUILD_NPM_PREFIX = previousPrefix;
    report.errors = errors; fs.writeFileSync(path.join(root, 'report.json'), JSON.stringify(report, null, 2), { flag: 'wx' });
  }
  return report;
}
