import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { registerHooks } from 'node:module';
import { pathToFileURL } from 'node:url';

// Adapt the pinned pi-polza stream-native contract's SDK locator, not its provider.
export async function runPolza(sdkRoot, profile, root) {
  fs.mkdirSync(root);
  const polza = path.join(profile, 'git/github.com/VladimirMonin/pi-polza');
  const aiRoot = path.join(sdkRoot, 'node_modules/@earendil-works/pi-ai');
  const metadata = JSON.parse(fs.readFileSync(path.join(aiRoot, 'package.json'), 'utf8'));
  assert.equal(metadata.version, JSON.parse(fs.readFileSync(path.join(sdkRoot, 'package.json'), 'utf8')).version);
  const compat = pathToFileURL(path.join(aiRoot, metadata.exports['./compat'].import)).href;
  const hooks = registerHooks({ resolve(specifier, context, next) {
    return specifier === '@earendil-works/pi-ai/compat' ? { url: compat, shortCircuit: true } : next(specifier, context);
  } });
  let createPolzaApiStreams;
  try { ({ createPolzaApiStreams } = await import(pathToFileURL(path.join(polza, '.pi/extensions/pi-polza/stream.ts')).href)); }
  finally { hooks.deregister(); }
  const chunks = [
    { choices: [{ delta: { role: 'assistant', reasoning_content: 'SYNTHETIC_REASONING' }, finish_reason: null }] },
    { choices: [{ delta: { tool_calls: [{ index: 0, id: 'synthetic-call', type: 'function', function: { name: 'echo', arguments: '{"value":' } }] }, finish_reason: null }] },
    { choices: [{ delta: { tool_calls: [{ index: 0, function: { arguments: '42}' } }] }, finish_reason: null }] },
    { choices: [{ delta: {}, finish_reason: 'tool_calls' }] },
    { choices: [], usage: { prompt_tokens: 10, completion_tokens: 2, cost_rub: 0.25 } },
  ];
  let closed = false, cancelled = false, timer, controller, fetches = 0;
  const close = () => { if (!closed && !cancelled) { closed = true; controller.close(); } };
  const response = new Response(new ReadableStream({ start(value) { controller = value;
    value.enqueue(new TextEncoder().encode(chunks.map(chunk => `data: ${JSON.stringify(chunk)}\n\n`).join('') + 'data: [DONE]\n\n'));
    timer = setTimeout(close, 2000);
  }, cancel() { cancelled = true; clearTimeout(timer); } }), { headers: { 'content-type': 'text/event-stream' } });
  const records = [], events = [], report = { status: 'STARTED', scope: 'PINNED_POLZA_REAL_PI_TRANSPORT_SYNTHETIC_SSE', piVersion: metadata.version };
  try {
    const model = { id: 'offline/model', name: 'Offline', api: 'openai-completions', provider: 'polza',
      baseUrl: 'https://offline.invalid/v1', reasoning: true, input: ['text'], contextWindow: 8192, maxTokens: 64,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 } };
    const stream = createPolzaApiStreams(record => records.push(record)).streamSimple(model,
      { messages: [{ role: 'user', content: 'Synthetic reasoning/tool request', timestamp: 1 }] },
      { apiKey: 'synthetic', fetch: async () => { fetches++; return response; } });
    const result = await stream.result();
    assert.equal(result.stopReason, 'toolUse', JSON.stringify(result));
    assert(result.content.some(item => item.type === 'thinking' && item.thinking.includes('SYNTHETIC_REASONING')));
    assert(result.content.some(item => item.type === 'toolCall' && item.name === 'echo' && item.arguments.value === 42));
    assert.equal(closed, false, '[DONE] accounting waited for delayed EOF');
    assert.equal(result.usage.cost.total, 0, 'RUB must not enter USD usage');
    for await (const event of stream) events.push(event.type);
    await stream.result();
    assert.equal(fetches, 1); assert.equal(records.length, 1); assert.equal(records[0].costRub, 0.25);
    report.result = result; report.records = records; report.events = events;
    report.checks = ['NATIVE_REASONING_TOOL_JSON_USAGE', 'DONE_BEFORE_DELAYED_EOF', 'EXACTLY_ONCE_RUB_NOT_USD'];
    report.status = 'PASS';
  } catch (error) { report.status = 'FAIL'; report.error = String(error.stack || error); throw error; }
  finally { clearTimeout(timer); close(); fs.writeFileSync(path.join(root, 'report.json'), JSON.stringify(report, null, 2), { flag: 'wx' }); }
  return report;
}
