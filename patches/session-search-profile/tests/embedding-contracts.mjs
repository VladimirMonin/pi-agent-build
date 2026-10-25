// Generated production code, synthetic data and a real loopback HTTP server only.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import { stripTypeScriptTypes } from 'node:module';
const [pkg, kind, scenario = 'mapping'] = process.argv.slice(2);
const compile = s => stripTypeScriptTypes(s, { mode: 'transform' });
const load = s => import('data:text/javascript;base64,' + Buffer.from(s).toString('base64'));
const section = (text, start, end) => {
  const a = text.indexOf(start), b = text.indexOf(end, a + start.length);
  assert(a >= 0 && b > a, `missing production section ${start}`);
  return text.slice(a, b);
};
const bundle = kind === 'source' ? '' : fs.readFileSync(path.join(pkg, `dist/${kind === 'worker' ? 'index-worker' : 'index'}.js`), 'utf8');
const code = leaf => kind === 'source' ? fs.readFileSync(path.join(pkg, `src/${leaf}.ts`), 'utf8') : section(bundle, `// src/${leaf}.ts`, '\n// src/');
const ec = code('embedder');
const exports = ['createEmbedder', 'resolveModelPrefixes', 'prepareEmbeddingInput'].filter(name => ec.includes(`function ${name}(`));
const em = await load(compile(ec) + (kind === 'source' ? '' : `\nexport {${exports.join(',')}};`));
const { createEmbedder, resolveModelPrefixes, prepareEmbeddingInput } = em;
const raw = { queryPrefix: '', documentPrefix: '' };
const qwen = { queryPrefix: 'Instruct: Retrieve previous coding sessions relevant to the search query.\nQuery: ', documentPrefix: '' };
const google = { queryPrefix: 'task: search result | query: ', documentPrefix: 'title: none | text: ' };
const nemotron = { queryPrefix: 'query: ', documentPrefix: 'passage: ' };

if (scenario === 'mapping') {
  assert.throws(() => createEmbedder({ type: 'openai-compatible', baseUrl: 'http://127.0.0.1:1', model: 'unknown' }), /modelPrefixes/, 'unknown model must fail before any request');
  // Resolve an exact selected ID, never a family/name guess or an inherited key.
  const pairs = [
    ['text-embedding-3-small', raw], ['text-embedding-3-large', raw],
    ['qwen/qwen3-embedding-8b', qwen], ['Qwen/Qwen3-Embedding-0.6B', qwen],
    ['gemini-embedding-2-preview', google], ['google/embeddinggemma-2', google],
    ['nvidia/Nemotron-3-Embed-1B-BF16', nemotron], ['nvidia/Nemotron-3-Embed-8B-BF16', nemotron],
    ['nvidia/Nemotron-3.5-Embed-1B-BF16', nemotron], ['nvidia/Nemotron-3.5-Embed-8B-BF16', nemotron],
    ['opaque-local-name', raw], ['explicit-space', { queryPrefix: ' Q:  ', documentPrefix: ' D: ' }]
  ];
  const mapping = Object.fromEntries(pairs);
  for (const [model, expected] of pairs) {
    const before = JSON.stringify(mapping);
    const prefixes = resolveModelPrefixes(model, mapping);
    assert.equal(prepareEmbeddingInput('Текст сессии', 'document', prefixes), expected.documentPrefix + 'Текст сессии');
    assert.equal(prepareEmbeddingInput('Как исправляли ошибку?', 'query', prefixes), expected.queryPrefix + 'Как исправляли ошибку?');
    assert.equal(JSON.stringify(mapping), before);
  }
  for (const [model, mapping] of [
    ['qwen/qwen3-embedding-8b', undefined], ['unknown', {}], ['toString', {}],
    ['QWEN/QWEN3-EMBEDDING-8B', Object.fromEntries(pairs)],
    ['bad', { bad: { queryPrefix: '' } }], ['bad', { bad: { documentPrefix: '' } }],
    ['bad', { bad: { queryPrefix: null, documentPrefix: '' } }],
    ['bad', { bad: { queryPrefix: 0, documentPrefix: '' } }], ['bad', { bad: [] }],
    ['bad', { bad: { ...raw, inputType: { query: 'query' } } }],
    ['bad', { bad: { ...nemotron, inputType: { query: 'query', document: 'passage' } } }]
  ]) {
    assert.throws(() => resolveModelPrefixes(model, mapping), /modelPrefixes|prefix|inputType/);
  }
  let fetched = false;
  const original = globalThis.fetch;
  globalThis.fetch = async () => { fetched = true; throw new Error('must not reach network'); };
  try {
    assert.throws(() => createEmbedder({ type: 'openai-compatible', baseUrl: 'http://127.0.0.1:1', model: 'unknown' }), /modelPrefixes/);
    assert.equal(fetched, false);
  } finally { globalThis.fetch = original; }
  console.log(`${kind}: exact mappings, required strings, literal empties/spaces and fail-before-HTTP`);
} else if (scenario === 'transport') {
  const requests = [];
  const server = http.createServer(async (req, res) => {
    let data = '';
    for await (const chunk of req) data += chunk;
    const body = JSON.parse(data);
    requests.push({ url: req.url, body });
    const input = Array.isArray(body.input) ? body.input : [body.input];
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify(req.url === '/api/embed'
      ? { embeddings: [[1, 0]] }
      : { data: input.map((_, index) => ({ index, embedding: [index + 1, 0] })).reverse() }));
  });
  await new Promise(r => server.listen(0, '127.0.0.1', r));
  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  try {
    for (const [model, prefixes] of [['raw', raw], ['qwen', qwen], ['google', google], ['local-nemotron', nemotron], ['api-nemotron', { ...raw, inputType: { query: 'query', document: 'passage' } }]]) {
      const cfg = { type: 'openai-compatible', baseUrl, model, dimensions: 2, sendDimensions: true, modelPrefixes: { [model]: prefixes } };
      const provider = createEmbedder(cfg);
      const resolved = resolveModelPrefixes(model, cfg.modelPrefixes);
      const signal = new AbortController().signal;
      assert.deepEqual(await provider.embedBatch(['Документ', 'Ещё сессия'].map(t => prepareEmbeddingInput(t, 'document', resolved)), signal, resolved.inputType?.document), [[1, 0], [2, 0]]);
      assert.deepEqual(await provider.embed(prepareEmbeddingInput('Где ошибка?', 'query', resolved), signal, resolved.inputType?.query), [1, 0]);
      const [doc, query] = requests.slice(-2);
      assert.equal(doc.url, '/v1/embeddings');
      assert.deepEqual(doc.body.input, [prefixes.documentPrefix + 'Документ', prefixes.documentPrefix + 'Ещё сессия']);
      assert.deepEqual(query.body.input, [prefixes.queryPrefix + 'Где ошибка?']);
      for (const item of [doc, query]) { assert.equal(item.body.model, model); assert.equal(item.body.dimensions, 2); }
      assert.equal(doc.body.input_type, prefixes.inputType?.document);
      assert.equal(query.body.input_type, prefixes.inputType?.query);
      // Provider methods themselves remain neutral, even singleton→batch.
      await provider.embed('Уже готовая строка');
      assert.deepEqual(requests.at(-1).body.input, ['Уже готовая строка']);
    }
    const cfg = { type: 'openai-compatible', baseUrl, model: 'google', modelPrefixes: { google }, embeddingsEndpoint: baseUrl + '/v1beta/openai/embeddings' };
    const provider = createEmbedder(cfg);
    await provider.embed(prepareEmbeddingInput('я'.repeat(13000), 'query', google));
    assert.equal(requests.at(-1).url, '/v1beta/openai/embeddings');
    assert.equal(requests.at(-1).body.input[0].length, 12000);
    assert(requests.at(-1).body.input[0].startsWith(google.queryPrefix));
    assert(!Object.hasOwn(requests.at(-1).body, 'dimensions'));
    const abort = new AbortController(); abort.abort();
    const before = requests.length;
    await assert.rejects(provider.embed('Отмена', abort.signal));
    assert.equal(requests.length, before);
    const ollama = createEmbedder({ type: 'ollama', url: baseUrl, model: 'local', modelPrefixes: { local: nemotron } });
    await ollama.embedBatch(['первый', 'второй'].map(t => prepareEmbeddingInput(t, 'document', nemotron)));
    assert.deepEqual(requests.slice(-2).map(r => r.body.input), ['passage: первый', 'passage: второй']);
    assert.throws(() => createEmbedder({ type: 'ollama', url: baseUrl, model: 'api', modelPrefixes: { api: { ...raw, inputType: { query: 'query', document: 'passage' } } } }), /inputType/);
    console.log(`${kind}: real loopback UTF-8, literal prefixes, neutral clients, input_type, full endpoint, length and abort; Ollama batch→single`);
  } finally { server.closeAllConnections(); await new Promise(r => server.close(r)); }
} else if (scenario === 'search') {
  const sc = code('session-index');
  const method = section(sc, '  async search(', '\n  list(');
  const cosine = section(sc, 'function cosineSimilarity(', '\n}') + '\n}';
  const decode = section(sc, kind === 'source' ? 'export function decodeEmbedding(' : 'function decodeEmbedding(', '\n}') + '\n}';
  const { search } = await load(compile(`${ec}\n${decode}\n${cosine}\nfunction buildSummary(){return 'summary';}\nexport const search = {${method}}.search;`));
  const entries = {
    target: { session: { id: 'target', projectSlug: 'Demo', cwd: '/demo' }, embedding: [1, 0] },
    partial: { session: { id: 'partial', projectSlug: 'Demo', cwd: '/demo' }, embedding: [3, 4] },
    opposite: { session: { id: 'opposite', projectSlug: 'Other', cwd: '/other' }, embedding: [-1, 0] }
  };
  let keywordCalls = 0, embeddingCalls = 0;
  const signal = new AbortController().signal;
  const context = { data: { sessions: entries }, prefixes: qwen, fusion: 'semantic-only',
    embedder: { embed: async (text, gotSignal, inputType) => {
      embeddingCalls++; assert.equal(text, qwen.queryPrefix + 'Как исправляли ошибку?');
      assert.equal(gotSignal, signal); assert.equal(inputType, undefined); return [1, 0];
    } },
    fts: { searchRanks: () => { keywordCalls++; throw new Error('semantic-only must not call FTS'); } } };
  const result = await search.call(context, 'Как исправляли ошибку?', 3, signal);
  assert.deepEqual(result.map(x => x.session.id), ['target', 'partial', 'opposite']);
  assert.equal(result[0].score, 1);
  assert(Math.abs(result[1].score - 3 / Math.sqrt(25)) < 1e-12);
  assert.equal(result[2].score, -1);
  assert.equal(keywordCalls, 0);
  assert.deepEqual((await search.call(context, 'Как исправляли ошибку?', 1, signal, 'DEMO')).map(x => x.session.id), ['target']);
  assert.deepEqual((await search.call(context, 'Как исправляли ошибку?', 5, signal, 'OTHER')).map(x => x.session.id), ['opposite']);
  const before = embeddingCalls;
  assert.deepEqual(await search.call(context, 'ignored', 5, signal, 'absent'), []);
  assert.equal(embeddingCalls, before);
  context.embedder.embed = async () => { throw new Error('provider unavailable'); };
  await assert.rejects(search.call(context, 'error', 5), /provider unavailable/);
  assert.equal(keywordCalls, 0, 'API failure must not activate a lexical fallback');
  context.embedder.embed = async () => [1, 0];
  context.fts.searchRanks = () => { keywordCalls++; return new Map([['partial', 1]]); };
  for (const mode of ['rrf', 'vector-primary']) {
    context.fusion = mode;
    const old = await search.call(context, 'legacy', 2);
    assert(old.length > 0);
    assert.notEqual(old[0].score, 1, 'explicit legacy modes retain their own scoring');
  }
  assert.equal(keywordCalls, 2);
  console.log(`${kind}: semantic-only exact cosine, no FTS, project/top-N, provider error, query formatting and opt-in legacy modes`);
} else if (scenario === 'config') {
  const cc = code('config');
  const configModule = await load(compile(cc) + (kind === 'source' ? '' : '\nexport {loadConfig,saveConfig,getConfigPath};'));
  const cwd = path.join(pkg, 'config-project'), store = path.join(pkg, 'owned-config');
  fs.mkdirSync(path.join(cwd, '.pi'), { recursive: true }); fs.mkdirSync(store);
  fs.writeFileSync(path.join(cwd, '.pi/settings.json'), JSON.stringify({ 'pi-session-search': { localPath: store } }));
  const file = configModule.getConfigPath(cwd);
  const seed = { customFutureSetting: { keep: true }, sessionDir: 'session-source', extraArchiveDirs: ['archive'],
    sync: { interval: 17, initialDelay: -1, disableForChild: true }, primer: { enabled: false },
    embedder: { type: 'openai-compatible', baseUrl: 'http://127.0.0.1:1', model: 'old', modelPrefixes: { old: raw }, embeddingsEndpoint: 'http://127.0.0.1:1/exact' } };
  fs.writeFileSync(file, JSON.stringify(seed));
  assert.equal(configModule.loadConfig(cwd).fusion, 'semantic-only');
  for (const fusion of ['rrf', 'vector-primary', 'semantic-only']) {
    configModule.saveConfig({ fusion }, cwd);
    assert.equal(configModule.loadConfig(cwd).fusion, fusion);
  }
  configModule.saveConfig({ embedder: { model: 'new', modelPrefixes: { old: raw, new: nemotron } }, extraSessionDirs: [] }, cwd);
  const saved = JSON.parse(fs.readFileSync(file, 'utf8'));
  for (const key of ['customFutureSetting', 'sessionDir', 'extraArchiveDirs', 'sync', 'primer']) assert.deepEqual(saved[key], seed[key]);
  assert.equal(saved.fusion, 'semantic-only');
  assert.equal(saved.embedder.embeddingsEndpoint, seed.embedder.embeddingsEndpoint);
  assert.equal(saved.embedder.baseUrl, seed.embedder.baseUrl);
  assert.deepEqual(saved.embedder.modelPrefixes.new, nemotron);
  console.log(`${kind}: semantic default/explicit modes and whole-config/nested embedder preservation`);
} else {
  throw new Error(`unknown scenario ${scenario}`);
}
