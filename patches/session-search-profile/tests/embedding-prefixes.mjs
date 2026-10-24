// Exact generated source/bundle behavior. Only external network I/O is replaced.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { stripTypeScriptTypes } from 'node:module';
const [pkg, kind, scenario = 'prefixes'] = process.argv.slice(2);
const load = async source => import('data:text/javascript;base64,' + Buffer.from(source).toString('base64'));
const compile = source => stripTypeScriptTypes(source, { mode: 'transform' });
const source = fs.readFileSync(path.join(pkg, kind === 'source' ? `src/${scenario === 'search' ? 'session-index' : 'embedder'}.ts` : `dist/${kind === 'worker' ? 'index-worker' : 'index'}.js`), 'utf8');
const section = (text, start, end) => {
  const a = text.indexOf(start), b = text.indexOf(end, a + start.length);
  assert(a >= 0 && b > a, `missing production section ${start}`);
  return text.slice(a, b);
};
if (scenario === 'defaults') {
  const code = kind === 'source' ? fs.readFileSync(path.join(pkg, 'src/config.ts'), 'utf8')
    : section(source, '// src/config.ts', '\n// src/');
  const { loadConfig, getConfigPath } = await load(compile(code) + (kind === 'source' ? '' : '\nexport {loadConfig, getConfigPath};'));
  const owned = path.join(pkg, 'owned-config');
  fs.mkdirSync(owned);
  fs.mkdirSync(path.join(pkg, '.pi'));
  fs.writeFileSync(path.join(pkg, '.pi/settings.json'), JSON.stringify({ 'pi-session-search': { localPath: owned } }));
  assert.equal(getConfigPath(pkg), path.join(owned, 'config.json'));
  for (const [given, expected] of [[undefined, 'vector-primary'], ['vector-primary', 'vector-primary'], ['rrf', 'rrf']]) {
    fs.writeFileSync(getConfigPath(pkg), JSON.stringify({ fusion: given, embedder: { type: 'openai-compatible', model: 'opaque', documentPrefix: '', queryPrefix: 'Q:' } }));
    const config = loadConfig(pkg);
    assert.equal(config.fusion, expected);
    assert.equal(config.embedder.documentPrefix, '');
    assert.equal(config.embedder.queryPrefix, 'Q:');
  }
  console.log(`${kind}: semantic config default, explicit RRF and prefix settings retained`);
} else if (scenario === 'search') {
  const code = kind === 'source' ? source : source.slice(source.indexOf('// src/session-index.ts'));
  const method = section(code, '  async search(', '\n  list(');
  const cosine = section(code, 'function cosineSimilarity(', '\n}') + '\n}';
  const decode = section(code, kind === 'source' ? 'export function decodeEmbedding(' : 'function decodeEmbedding(', '\n}') + '\n}';
  const { search } = await load(compile(`${decode}\n${cosine}\nfunction buildSummary(){return '';}\nexport const search = {${method}}.search;`));
  const entries = {
    target: { session: { id: 'target', projectSlug: 'demo', cwd: '/demo' }, embedding: [1, 0] },
    noise: { session: { id: 'noise', projectSlug: 'demo', cwd: '/demo' }, embedding: [0, 1] }
  };
  let keywordCalls = 0;
  const context = { data: { sessions: entries }, fusion: 'vector-primary', embedder: { embed: async () => [1, 0] },
    fts: { searchRanks: () => { keywordCalls++; return new Map([['noise', 1]]); } } };
  const primary = await search.call(context, 'needle', 2);
  assert.deepEqual(primary.map(x => x.session.id), ['target', 'noise']);
  assert.equal(keywordCalls, 0, 'vector-primary must not consult keyword ranking');
  context.fusion = 'rrf';
  const hybrid = await search.call(context, 'needle', 2);
  assert.equal(keywordCalls, 1, 'explicit rrf retains the keyword arm');
  assert.equal(hybrid[0].session.id, 'noise');
  console.log(`${kind}: semantic-first skips FTS; explicit RRF preserved`);
} else {
  const moduleSource = kind === 'source' ? compile(source) : section(source, '// src/embedder.ts', '\n// src/') + '\nexport {createEmbedder};';
  const { createEmbedder } = await load(moduleSource);
  const qwen = 'Instruct: Given a web search query, retrieve relevant passages that answer the query\nQuery:';
  const googleDoc = 'title: none | text: ', googleQuery = 'task: search result | query: ';
  const cases = [
    { model: 'openai/text-embedding-3-large', doc: '', query: '' },
    { model: 'openai/text-embedding-3-small', doc: '', query: '' },
    { model: 'qwen/qwen3-embedding-8b', doc: '', query: qwen },
    { model: 'google/gemini-embedding-2-preview', doc: googleDoc, query: googleQuery },
    { model: 'Qwen/Qwen3-Embedding-0.6B', doc: '', query: qwen },
    { model: 'google/embeddinggemma-2', doc: googleDoc, query: googleQuery },
    { model: 'text-embedding-qwen3-embedding-0.6b', doc: '', query: qwen },
    { model: 'community/Qwen3-Embedding-0.6B-Q8_0.gguf', doc: '', query: qwen },
    { model: 'text-embedding-embeddinggemma-2', doc: googleDoc, query: googleQuery },
    { model: 'opaque-local-alias', doc: '', query: '' },
    { model: 'future-model', documentPrefix: 'DOC: ', queryPrefix: 'QUESTION: ', doc: 'DOC: ', query: 'QUESTION: ' },
    { model: 'qwen/qwen3-embedding-8b', queryPrefix: '', doc: '', query: '' },
    { model: 'google/embeddinggemma-2', documentPrefix: '', queryPrefix: '', doc: '', query: '' },
    { model: 'google/gemini-embedding-2-preview', queryPrefix: 'task: code retrieval | query: ', doc: googleDoc, query: 'task: code retrieval | query: ' },
    { model: 'opaque-local-alias', documentPrefix: 'D:', queryPrefix: 'Q:', doc: 'D:', query: 'Q:' }
  ];
  const nativeFetch = globalThis.fetch;
  let calls = 0;
  const inputs = [], signals = [];
  globalThis.fetch = async (url, options) => {
    assert.equal(url, 'http://127.0.0.1:1/v1/embeddings');
    assert.equal(options.method, 'POST');
    const body = JSON.parse(options.body);
    calls++;
    inputs.push(body); signals.push(options.signal);
    return new Response(JSON.stringify({ data: body.input.map((_, index) => ({ index, embedding: [1, 0] })).reverse() }), { status: 200, headers: { 'Content-Type': 'application/json' } });
  };
  try {
    for (const item of cases) {
      const config = { type: 'openai-compatible', baseUrl: 'http://127.0.0.1:1', model: item.model, dimensions: 2, sendDimensions: true };
      for (const key of ['documentPrefix', 'queryPrefix']) if (Object.hasOwn(item, key)) config[key] = item[key];
      Object.freeze(config);
      const embedder = createEmbedder(config);
      const signal = new AbortController().signal;
      const before = calls;
      assert.deepEqual(await embedder.embedBatch(['Document alpha', 'Document beta'], signal), [[1, 0], [1, 0]]);
      assert.deepEqual(await embedder.embed('Where is alpha?', signal), [1, 0]);
      assert.equal(calls - before, 2);
      const [documents, query] = inputs.slice(-2);
      assert.deepEqual(documents.input, [item.doc + 'Document alpha', item.doc + 'Document beta'], `${item.model}: document prefix`);
      assert.deepEqual(query.input, [item.query + 'Where is alpha?'], `${item.model}: query prefix (no document-prefix double application)`);
      for (const body of [documents, query]) { assert.equal(body.model, item.model); assert.equal(body.dimensions, 2); }
      assert(signals.slice(-2).every(x => x === signal));
    }
    const embedder = createEmbedder({ type: 'openai-compatible', baseUrl: 'http://127.0.0.1:1', model: 'qwen/qwen3-embedding-8b' });
    await embedder.embed('x'.repeat(13000));
    assert(inputs.at(-1).input[0].startsWith(qwen));
    assert.equal(inputs.at(-1).input[0].length, 12000, 'existing transport limit retained');
    assert(!Object.hasOwn(inputs.at(-1), 'dimensions'), 'provider dimensions default is preserved');
    console.log(`${kind}: ${cases.length} document/query pairs, empty/custom overrides, exact wire fields, abort and truncation preserved`);
  } finally { globalThis.fetch = nativeFetch; }
}
