import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {pathToFileURL, fileURLToPath} from 'node:url';

// Run only against a synthetic profile in a private HOME. No model or session.
const [sdkRoot, profileRoot, mcpFixtureRoot] = process.argv.slice(2);
assert(sdkRoot && profileRoot, 'Explicit SDK and synthetic profile paths required');
assert(!path.resolve(profileRoot).replaceAll('\\', '/').includes('/.pi/'), 'Do not use a working user profile as a fixture');
const settings = JSON.parse(fs.readFileSync(path.join(profileRoot, 'settings.json'), 'utf8'));
assert(settings.extensions?.includes('-builtin:mcp'), 'Retained adapter must explicitly disable builtin:mcp');
let receipt;
if (mcpFixtureRoot) {
  const repo = fileURLToPath(new URL('../../', import.meta.url));
  const relative = path.relative(repo, path.resolve(mcpFixtureRoot));
  assert(relative.startsWith('..' + path.sep) || path.isAbsolute(relative), 'Fixture writes must stay outside Git');
  assert.equal(process.env.PI_MCP_CONFIG_MODE, 'exclusive', 'Use the private child-env contract');
  fs.mkdirSync(mcpFixtureRoot); // Fresh only; never repair or overwrite a prior case.
  // Route module-level adapter paths before SDK/extensions are imported.
  process.env.PI_CODING_AGENT_DIR = path.join(mcpFixtureRoot, 'agent');
  receipt = { status: 'STARTED', stage: 'sdk-import', sdkRoot, profileRoot,
    pid: process.pid, ppid: process.ppid, execPath: process.execPath, checks: [] };
}
let fetchAttempts = 0;
const originalFetch = globalThis.fetch;
globalThis.fetch = () => { fetchAttempts++; throw Error('Network forbidden in profile loading test'); };
try {
  const sdk = await import(pathToFileURL(path.join(sdkRoot, 'dist/index.js')).href);
  if (!receipt) {
  const loader = new sdk.DefaultResourceLoader({cwd: process.cwd(), agentDir: profileRoot,
    settingsManager: sdk.SettingsManager.inMemory(settings), noSkills: true,
    noPromptTemplates: true, noThemes: true, noContextFiles: true});
  await loader.reload();
  const result = loader.getExtensions();
  assert.deepEqual(result.errors, [], 'Extension loading errors');
  assert.deepEqual(result.warnings ?? [], [], 'Extension package/startup warnings');
  assert(!result.extensions.some(e => e.path.includes('pi-trace-extension')), 'Trace must remain default-off');
  assert.equal(fetchAttempts, 0);
  console.log(JSON.stringify({status: 'PASS', scope: 'SYNTHETIC_PROFILE_LOADING_NOT_LIVE_PROVIDER_OR_TUI',
    extensions: result.extensions.length, warnings: 0, errors: 0, fetchAttempts}));
  }
  if (receipt) {
    receipt.stage = 'mcp-scenario';
    await checkMcp(sdk, sdkRoot, profileRoot, mcpFixtureRoot, receipt);
    assert.equal(fetchAttempts, 0);
    receipt.status = 'PASS';
  }
} catch (error) {
  if (receipt) { receipt.status = 'FAIL'; receipt.error = String(error.stack || error); }
  throw error;
} finally {
  globalThis.fetch = originalFetch;
  if (receipt) {
    receipt.fetchAttempts = fetchAttempts;
    fs.writeFileSync(path.join(mcpFixtureRoot, 'report.json'), JSON.stringify(receipt, null, 2), { flag: 'wx' });
  }
}

// Optional installed-adapter seam, extending the same SDK profile fixture. The server
// is a real stdio child; only the model is deterministic. No provider/network calls.
async function checkMcp(sdk, sdkRoot, installedProfile, root, receipt) {
  const adapter = path.join(installedProfile, 'npm/node_modules/pi-mcp-adapter');
  assert.equal(JSON.parse(fs.readFileSync(path.join(adapter, 'package.json'), 'utf8')).version, '5.3.2');
  const agentDir = path.join(root, 'agent'), cwd = path.join(root, 'project');
  fs.mkdirSync(agentDir); fs.mkdirSync(cwd);
  const childEnv = {};
  for (const name of ['SystemRoot', 'WINDIR', 'HOME', 'USERPROFILE', 'APPDATA', 'LOCALAPPDATA', 'TEMP', 'TMP']) {
    assert(process.env[name], `Missing private child env ${name}`);
    childEnv[name] = process.env[name];
  }
  fs.writeFileSync(path.join(agentDir, 'mcp-adapter.json'), JSON.stringify({ mcpServers: { fixture: {
    command: process.execPath, args: [fileURLToPath(new URL('./fixtures/mcp-server.mjs', import.meta.url))],
    inheritEnv: false, env: childEnv, directTools: ['probe'], lifecycle: 'lazy',
  } }, settings: { scriptMode: false, hostConfigDiscovery: 'off' } }));
  const ai = await import(pathToFileURL(path.join(sdkRoot, 'node_modules/@earendil-works/pi-ai/dist/index.js')).href);
  const runtime = await sdk.ModelRuntime.create({ authPath: path.join(agentDir, 'auth.json'), modelsPath: null,
    modelsStorePath: path.join(agentDir, 'models.json'), allowModelNetwork: false, refreshOnCreate: false });
  const errors = [], results = [];
  receipt.results = results;
  receipt.errors = errors;
  let session, instruction;
  runtime.registerProvider('mcp-fixture', { name: 'Synthetic MCP fixture', api: 'openai-completions',
    apiKey: 'synthetic', baseUrl: 'https://mock.invalid', models: [{ id: 'mock', name: 'mock', reasoning: false,
      input: ['text'], contextWindow: 32768, maxTokens: 128,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 } }],
    streamSimple(model, context) {
      const stream = ai.createAssistantMessageEventStream();
      const last = context.messages.findLast(message => message.role !== 'system');
      const message = { role: 'assistant', api: model.api, provider: model.provider, model: model.id,
        timestamp: Date.now(), content: [], stopReason: 'stop', usage: { input: 0, output: 0,
          cacheRead: 0, cacheWrite: 0, totalTokens: 0, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } } };
      queueMicrotask(() => {
        stream.push({ type: 'start', partial: message });
        if (last?.role === 'toolResult') {
          message.content = [{ type: 'text', text: 'MCP_FIXTURE_STEP_DONE' }];
        } else {
          message.stopReason = 'toolUse';
          message.content = [{ type: 'toolCall', id: 'fixture-' + results.length, name: instruction.tool, arguments: instruction.args }];
        }
        stream.push({ type: 'done', reason: message.stopReason, message }); stream.end();
      });
      return stream;
    } });
  try {
    const settingsManager = sdk.SettingsManager.inMemory({ packages: [], extensions: ['-builtin:mcp'],
      compaction: { enabled: false }, retry: { enabled: false } });
    const loader = new sdk.DefaultResourceLoader({ cwd, agentDir, settingsManager,
      additionalExtensionPaths: [path.join(adapter, 'index.ts')], noSkills: true,
      noPromptTemplates: true, noThemes: true, noContextFiles: true });
    await loader.reload(); assert.deepEqual(loader.getExtensions().errors, []);
    ({ session } = await sdk.createAgentSession({ cwd, agentDir, modelRuntime: runtime,
      model: runtime.getModel('mcp-fixture', 'mock'), noTools: 'builtin', resourceLoader: loader,
      settingsManager, sessionManager: sdk.SessionManager.create(cwd, path.join(root, 'sessions')) }));
    await session.bindExtensions({ mode: 'rpc', onError: error => errors.push(String(error.error)) });
    assert(session.getActiveToolNames().includes('mcp'));
    assert(!session.getActiveToolNames().includes('mcpScript'));
    async function call(tool, args) {
      instruction = { tool, args };
      const before = session.messages.length;
      await session.prompt('MCP_SYNTHETIC_STEP'); await session.waitForIdle();
      const rows = session.messages.slice(before).filter(message => message.role === 'toolResult');
      assert.equal(rows.length, 1, 'Exactly one requested tool operation per fixture step');
      assert.equal(rows[0].isError, false, JSON.stringify(rows[0].content));
      assert(!rows[0].details?.error, JSON.stringify(rows[0].content));
      results.push(rows[0]); return rows[0];
    }
    await call('mcp', { connect: 'fixture' });
    const search = await call('mcp', { search: 'fixture probe' });
    assert(JSON.stringify(search).includes('probe'));
    receipt.activeTools = session.getActiveToolNames();
    receipt.registeredTools = session.getAllTools().map(({name, exposure}) => ({name, exposure}));
    const direct = session.getActiveToolNames().filter(name => name.endsWith('_probe'));
    assert.equal(direct.length, 1, 'Selected direct tool must hot-load after discovery');
    assert(!session.getActiveToolNames().some(name => name.endsWith('_proxy_only')), 'Unselected tool must remain proxy-only');
    const described = await call('mcp', { describe: direct[0] });
    assert(JSON.stringify(described).includes('minimum'), 'Original argument constraints must survive describe');
    assert(JSON.stringify(await call('mcp', { tool: direct[0], args: { value: 21 } })).includes('FIXTURE_RESULT:22'));
    assert(JSON.stringify(await call(direct[0], { value: 41 })).includes('FIXTURE_RESULT:42'));
    assert.deepEqual(errors, []);
    receipt.checks.push('ACTUAL_STDIO_DISCOVERY_SEARCH_DESCRIBE_SAFE_PROXY_CALL', 'SELECTED_DIRECT_CALL_UNSELECTED_PROXY_ONLY', 'SCRIPT_MODE_OFF');
    receipt.directTool = direct[0]; receipt.results = results;
  } finally {
    if (session) { await session.extensionRunner.emit({ type: 'session_shutdown', reason: 'exit' }); session.dispose(); }
    runtime.unregisterProvider('mcp-fixture');
  }
}
