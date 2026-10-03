// Source fixture only. The host controller must accept an actual VM dummy boundary
// and its independent raw review before invoking this inside a fresh guest.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';

const norm = value => path.resolve(value).toLowerCase();
function within(root, candidate) {
  const rel = path.relative(norm(root), norm(candidate));
  return rel !== '' && !rel.startsWith('..') && !path.isAbsolute(rel);
}
function confinedExisting(root, candidate) {
  if (!within(root, candidate) || norm(fs.realpathSync.native(candidate)) !== norm(candidate)) throw Error('Guest path absent, redirected or outside owned root');
  return candidate;
}
function regularJson(file) {
  const stat = fs.lstatSync(file);
  if (!stat.isFile() || stat.isSymbolicLink() || stat.size > 1048576) throw Error('Bounded regular JSON required');
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}
function peerManifest(entry, root) {
  for (let dir = path.dirname(entry); within(root, dir); dir = path.dirname(dir)) {
    const file = path.join(dir, 'package.json');
    if (fs.existsSync(file)) return { file, value: regularJson(file) };
  }
  throw Error('Peer package identity absent within guest root');
}
function localProvider(createStream, calls) {
  return {
    name: 'Local provider-free SDK baseline',
    api: 'openai-completions', baseUrl: 'https://mock.invalid', apiKey: 'synthetic',
    models: [{ id: 'mock-1.0.0', name: 'mock', input: ['text'], reasoning: false,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, contextWindow: 4096, maxTokens: 64 }],
    streamSimple(model, _context, options = {}) {
      calls.push({ provider: model.provider, model: model.id, api: model.api });
      const stream = createStream();
      const message = { role: 'assistant', api: model.api, provider: model.provider, model: model.id,
        timestamp: Date.now(), content: [], stopReason: 'stop', usage: { input: 0, output: 0,
          cacheRead: 0, cacheWrite: 0, totalTokens: 0,
          cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } } };
      queueMicrotask(() => {
        if (options.signal?.aborted) {
          message.stopReason = 'aborted'; message.errorMessage = 'Baseline request aborted';
          stream.push({ type: 'error', reason: 'aborted', error: message });
        } else {
          stream.push({ type: 'start', partial: message });
          message.content = [{ type: 'text', text: 'SDK_BASELINE_DONE' }];
          stream.push({ type: 'done', reason: 'stop', message });
        }
        stream.end();
      });
      return stream;
    },
  };
}

/** No CLI auto-entry point: invoked only by the separately approved guest runner. */
export async function runSdkBaseline({ guestRoot, sdkRoot, role }) {
  // Actual OS user, never an inherited USERNAME assertion. Refuse before writes/imports.
  if (process.platform !== 'win32' || os.userInfo().username !== 'WDAGUtilityAccount') throw Error('Sandbox guest identity required');
  if (!/^C:\\PiLabVM-[a-f0-9]{32}$/i.test(guestRoot) || !['root', 'child'].includes(role)) throw Error('Exact owned guest root/role required');
  for (const candidate of [sdkRoot, process.execPath, process.cwd()]) confinedExisting(guestRoot, candidate);
  const envNames = ['HOME', 'USERPROFILE', 'APPDATA', 'LOCALAPPDATA', 'TEMP', 'TMP', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME', 'XDG_DATA_HOME', 'XDG_STATE_HOME'];
  const env = Object.fromEntries(envNames.map(name => [name, process.env[name]]));
  if (process.env.NODE_OPTIONS !== undefined || envNames.some(name => typeof env[name] !== 'string' || !within(guestRoot, env[name]))) throw Error('Guest environment not confined');
  const manifestFile = confinedExisting(guestRoot, path.join(sdkRoot, 'package.json'));
  const manifest = regularJson(manifestFile);
  if (manifest.name !== '@earendil-works/pi-coding-agent' || manifest.version !== '1.0.0') throw Error('Exact Pi 1.0.0 SDK required');
  const sdkEntry = confinedExisting(guestRoot, path.join(sdkRoot, 'dist', 'index.js'));
  const require = createRequire(pathToFileURL(manifestFile));
  const peerEntry = confinedExisting(guestRoot, require.resolve('@earendil-works/pi-ai'));
  const peer = peerManifest(peerEntry, guestRoot);
  confinedExisting(guestRoot, peer.file);
  if (peer.value.name !== '@earendil-works/pi-ai' || peer.value.version !== '1.0.0') throw Error('Exact Pi AI 1.0.0 peer required');
  const agentDir = path.join(guestRoot, `sdk-${role}`);
  fs.mkdirSync(agentDir); // fresh only; never overwrite/repair an old run
  const calls = [], events = [];
  const report = { scope: 'CORE_SDK_LOCAL_MOCK_ONLY_NOT_PLUGINS_DEFAULT_ACCEPTANCE_OR_HOST_CLEANUP',
    piVersion: manifest.version, role, pid: process.pid, ppid: process.ppid,
    execPath: process.execPath, cwd: process.cwd(), modulePath: import.meta.url, env,
    sdkEntry, peerEntry, peerManifest: peer.file, calls, events, status: 'STARTED' };
  let session, unsubscribe, modelRuntime;
  try {
    const sdk = await import(pathToFileURL(sdkEntry).href);
    const ai = await import(pathToFileURL(peerEntry).href);
    if (typeof ai.createAssistantMessageEventStream !== 'function') throw Error('Pinned peer stream factory absent');
    modelRuntime = await sdk.ModelRuntime.create({ authPath: path.join(agentDir, 'auth.json'),
      modelsPath: null, modelsStorePath: path.join(agentDir, 'models-store.json'),
      allowModelNetwork: false, refreshOnCreate: false });
    modelRuntime.registerProvider('lab-sdk-local', localProvider(ai.createAssistantMessageEventStream, calls));
    const model = modelRuntime.getModel('lab-sdk-local', 'mock-1.0.0');
    if (!model) throw Error('Synthetic model absent');
    const resourceLoader = {
      getExtensions: () => ({ extensions: [], errors: [], runtime: sdk.createExtensionRuntime() }),
      getSkills: () => ({ skills: [], diagnostics: [] }), getPrompts: () => ({ prompts: [], diagnostics: [] }),
      getThemes: () => ({ themes: [], diagnostics: [] }), getAgentsFiles: () => ({ agentsFiles: [] }),
      getSystemPrompt: () => 'Return the synthetic baseline canary.', getSystemPromptSource: () => undefined,
      getAppendSystemPrompt: () => [], getAppendSystemPromptSources: () => [],
      extendResources: () => {}, reload: async () => {},
    };
    ({ session } = await sdk.createAgentSession({ cwd: process.cwd(), agentDir, model, modelRuntime,
      thinkingLevel: 'off', tools: [], noTools: 'all', resourceLoader,
      sessionManager: sdk.SessionManager.inMemory(process.cwd()),
      settingsManager: sdk.SettingsManager.inMemory({ compaction: { enabled: false }, retry: { enabled: false } }) }));
    let settle;
    const settled = new Promise(resolve => { settle = resolve; });
    unsubscribe = session.subscribe(event => {
      if (['agent_end', 'agent_settled', 'message_end'].includes(event.type)) events.push(event.type);
      if (event.type === 'agent_settled') settle();
    });
    await session.prompt('SDK_BASELINE_CANARY');
    await settled; // outer guest deadline owns a missing-event failure; no losing timer
    await session.waitForIdle();
    if (session.getLastAssistantText() !== 'SDK_BASELINE_DONE' || calls.length !== 1 || !events.includes('agent_settled')) throw Error('Baseline response/lifecycle mismatch');
    report.status = 'CORE_SDK_MOCK_OBSERVED_NOT_COMPLETE_RUNTIME_ACCEPTANCE';
  } catch (error) {
    report.status = 'FAIL'; report.error = String(error?.stack || error);
    throw error;
  } finally {
    const cleanupErrors = [];
    for (const cleanup of [() => unsubscribe?.(), () => session?.dispose(), () => modelRuntime?.unregisterProvider('lab-sdk-local')]) {
      try { cleanup(); } catch (error) { cleanupErrors.push(String(error)); }
    }
    report.cleanupErrors = cleanupErrors;
    if (cleanupErrors.length) report.status = 'FAIL';
    fs.writeFileSync(path.join(agentDir, 'report.json'), JSON.stringify(report, null, 2), { flag: 'wx' });
    if (cleanupErrors.length) throw new AggregateError(cleanupErrors, 'SDK cleanup failed');
  }
  return report;
}
