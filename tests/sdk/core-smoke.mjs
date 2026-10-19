import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';

// Core-only local mock. No extension discovery, real credentials or provider calls.
const [sdkRoot, dataDir, coordinationProfile, qualification = 'coordination'] = process.argv.slice(2);
assert(sdkRoot && dataDir, 'Explicit SDK path and fresh synthetic data directory required');
const repoRoot = fileURLToPath(new URL('../../', import.meta.url));
const outputRelative = path.relative(repoRoot, path.resolve(dataDir));
assert(outputRelative && (outputRelative.startsWith('..' + path.sep) || path.isAbsolute(outputRelative)), 'Runtime output must stay outside Git');
const target = JSON.parse(fs.readFileSync(path.join(repoRoot, 'manifests/runtime.lock.json'), 'utf8')).runtime.pi.version;
const manifest = JSON.parse(fs.readFileSync(path.join(sdkRoot, 'package.json'), 'utf8'));
assert.equal(manifest.name, '@earendil-works/pi-coding-agent');
assert.equal(manifest.version, target);
// Check every internal dependency edge, including agent-core -> AI -> telemetry.
// Top-level CLI version alone did not catch the former 1.0.4/caret mixed graph.
const dependencyGraph = [];
const pending = [path.resolve(sdkRoot)], visited = new Set();
function locatePackage(from, name) {
  for (let cursor = from; ; cursor = path.dirname(cursor)) {
    const candidate = path.join(cursor, 'node_modules', name, 'package.json');
    if (fs.existsSync(candidate)) return path.dirname(candidate);
    if (path.dirname(cursor) === cursor) throw Error(`Missing installed internal dependency ${name} from ${from}`);
  }
}
assert(!manifest.dependencies['@earendil-works/chord'], 'New core must not depend on chord');
while (pending.length) {
  const root = fs.realpathSync(pending.shift());
  if (visited.has(root)) continue;
  visited.add(root);
  const metadata = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'));
  assert.equal(metadata.version, target, `Mixed internal graph: ${metadata.name}`);
  dependencyGraph.push({ name: metadata.name, version: metadata.version, root });
  for (const [name, spec] of Object.entries(metadata.dependencies ?? {})) {
    if (!name.startsWith('@earendil-works/')) continue;
    assert.equal(spec, target, `Internal dependency must be exact: ${metadata.name} -> ${name}`);
    pending.push(locatePackage(root, name));
  }
}
for (const name of ['pi-agent-core', 'pi-ai', 'pi-codemode', 'pi-mcp', 'pi-tui', 'pi-telemetry']) {
  assert(dependencyGraph.some(entry => entry.name === '@earendil-works/' + name), `Unverified graph node ${name}`);
}
const aiDir = locatePackage(path.resolve(sdkRoot), '@earendil-works/pi-ai');
const aiManifest = JSON.parse(fs.readFileSync(path.join(aiDir, 'package.json'), 'utf8'));
assert.equal(aiManifest.name, '@earendil-works/pi-ai');
assert.equal(aiManifest.version, target);
const aiEntry = path.join(aiDir, aiManifest.exports['.'].import);
fs.mkdirSync(dataDir);
let networkAttempts = 0;
const originalFetch = globalThis.fetch;
globalThis.fetch = () => { networkAttempts++; throw Error('Network forbidden in local mock'); };
const calls = [], events = [];
const report = { scope: 'CORE_SDK_LOCAL_MOCK_NOT_PLUGIN_OR_RELEASE_ACCEPTANCE', piVersion: manifest.version,
  aiVersion: aiManifest.version, dependencyGraph, sdkRoot, aiEntry, pid: process.pid, ppid: process.ppid,
  execPath: process.execPath, cwd: process.cwd(), calls, events, status: 'STARTED' };
let session, unsubscribe, runtime;
try {
  const sdk = await import(pathToFileURL(path.join(sdkRoot, 'dist/index.js')).href);
  const ai = await import(pathToFileURL(aiEntry).href);
  runtime = await sdk.ModelRuntime.create({ authPath: path.join(dataDir, 'auth.json'), modelsPath: null,
    modelsStorePath: path.join(dataDir, 'models.json'), allowModelNetwork: false, refreshOnCreate: false });
  runtime.registerProvider('local-smoke', { name: 'Local smoke', api: 'openai-completions',
    baseUrl: 'https://mock.invalid', apiKey: 'synthetic',
    models: [{ id: 'mock', name: 'mock', input: ['text'], reasoning: false,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, contextWindow: 4096, maxTokens: 64 }],
    streamSimple(model) {
      calls.push(model.provider + '/' + model.id);
      const stream = ai.createAssistantMessageEventStream();
      const message = { role: 'assistant', api: model.api, provider: model.provider, model: model.id,
        timestamp: Date.now(), content: [], stopReason: 'stop', usage: { input: 0, output: 0,
          cacheRead: 0, cacheWrite: 0, totalTokens: 0, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } } };
      queueMicrotask(() => {
        stream.push({ type: 'start', partial: message });
        message.content = [{ type: 'text', text: 'SDK_SMOKE_OK' }];
        stream.push({ type: 'done', reason: 'stop', message }); stream.end();
      });
      return stream;
    } });
  const resourceLoader = {
    getExtensions: () => ({ extensions: [], errors: [], runtime: sdk.createExtensionRuntime() }),
    getSkills: () => ({ skills: [], diagnostics: [] }), getPrompts: () => ({ prompts: [], diagnostics: [] }),
    getThemes: () => ({ themes: [], diagnostics: [] }), getAgentsFiles: () => ({ agentsFiles: [] }),
    getSystemPrompt: () => 'Return the synthetic canary.', getSystemPromptSource: () => undefined,
    getAppendSystemPrompt: () => [], getAppendSystemPromptSources: () => [], extendResources: () => {}, reload: async () => {},
  };
  ({ session } = await sdk.createAgentSession({ cwd: process.cwd(), agentDir: dataDir, modelRuntime: runtime,
    model: runtime.getModel('local-smoke', 'mock'), thinkingLevel: 'off', tools: [], noTools: 'all', resourceLoader,
    sessionManager: sdk.SessionManager.inMemory(process.cwd()),
    settingsManager: sdk.SettingsManager.inMemory({ compaction: { enabled: false }, retry: { enabled: false } }) }));
  let settle;
  const settled = new Promise(resolve => { settle = resolve; });
  unsubscribe = session.subscribe(event => {
    if (['message_end', 'agent_end', 'agent_settled'].includes(event.type)) events.push(event.type);
    if (event.type === 'agent_settled') settle();
  });
  await session.prompt('LOCAL_SMOKE_CANARY'); await settled; await session.waitForIdle();
  assert.equal(session.getLastAssistantText(), 'SDK_SMOKE_OK');
  assert.equal(calls.length, 1); assert.equal(networkAttempts, 0);
  assert(events.includes('agent_settled'));
  if (coordinationProfile) {
    if (qualification === 'goal') {
      const { runGoal } = await import('./fixtures/goal.mjs');
      report.goal = await runGoal(sdk, ai, sdkRoot, coordinationProfile, path.join(dataDir, 'goal'));
    } else if (qualification === 'ownership') {
      const { runOwnershipProbe } = await import('./fixtures/coordination.mjs');
      report.ownership = await runOwnershipProbe(sdk, ai, sdkRoot, coordinationProfile, path.join(dataDir, 'ownership'), process.argv[6], process.argv[7]);
    } else if (qualification === 'cli') {
      const { runCli } = await import('./fixtures/cli.mjs');
      report.cli = await runCli(sdkRoot, path.join(dataDir, 'cli'));
    } else if (qualification === 'profiles') {
      const { runProfiles } = await import('./fixtures/profiles.mjs');
      report.profiles = await runProfiles(sdk, ai, coordinationProfile, path.join(dataDir, 'profiles'));
    } else if (qualification === 'polza') {
      const { runPolza } = await import('./fixtures/polza.mjs');
      report.polza = await runPolza(sdkRoot, coordinationProfile, path.join(dataDir, 'polza'));
    } else {
      assert.equal(qualification, 'coordination');
      const { runCoordination } = await import('./fixtures/coordination.mjs');
      report.coordination = await runCoordination(sdk, ai, sdkRoot, coordinationProfile, path.join(dataDir, 'coordination'));
    }
  }
  report.status = 'PASS';
} catch (error) { report.status = 'FAIL'; report.error = String(error.stack || error); throw error; }
finally {
  const cleanupErrors = [];
  for (const cleanup of [() => unsubscribe?.(), () => session?.dispose(), () => runtime?.unregisterProvider('local-smoke')]) {
    try { cleanup(); } catch (error) { cleanupErrors.push(String(error)); }
  }
  globalThis.fetch = originalFetch;
  report.networkAttempts = networkAttempts; report.cleanupErrors = cleanupErrors;
  if (cleanupErrors.length) report.status = 'FAIL';
  fs.writeFileSync(path.join(dataDir, 'report.json'), JSON.stringify(report, null, 2), { flag: 'wx' });
  if (cleanupErrors.length) throw new AggregateError(cleanupErrors, 'SDK cleanup failed');
}
console.log(JSON.stringify(report));
