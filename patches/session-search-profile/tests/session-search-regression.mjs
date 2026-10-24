// Real bundled handlers and index services; only the Pi registry/UI host is a fixture.
// Native child environment is set by test_regression.py before this module is imported.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import http from 'node:http';

import {registerHooks, stripTypeScriptTypes} from 'node:module';
import {pathToFileURL, fileURLToPath} from 'node:url';
import {DatabaseSync} from 'node:sqlite';
import {createHash} from 'node:crypto';

const [pkg, root, scenario, mode, workerFlag, backend = 'fts'] = process.argv.slice(2);
assert(pkg && root && scenario && mode && workerFlag);
assert.equal(process.env.HOME, undefined, 'the native Node process, not a shell, must lack HOME');
assert.equal(os.homedir(), process.env.USERPROFILE, 'Windows native homedir must use the owned profile');
assert(path.resolve(root).startsWith(path.resolve(process.env.USERPROFILE) + path.sep));
// The immutable store keeps only affected TS files. Unchanged dependencies are
// loaded from their exact shipped bundle sections, never from personal config.
const bundle = fs.readFileSync(path.join(pkg, 'dist/index.js'), 'utf8');
const bundledModule = (start, end, exports) => {
  const a = bundle.indexOf(start), b = bundle.indexOf(end, a + start.length);
  assert(a >= 0 && b > a);
  return 'data:text/javascript;base64,' + Buffer.from(bundle.slice(a, b) + `\nexport {${exports}};`).toString('base64');
};
const dependencies = {
  './embedder': bundledModule('// src/embedder.ts', '// src/fts-index.ts', 'createEmbedder'),
  './fts5-probe': bundledModule('// src/fts5-probe.ts', '// src/fts-index.ts', 'assertFts5Available'),
  './reader': bundledModule('// src/reader.ts', '// src/index.ts', 'readSessionConversation')
};
const sourceBase = pathToFileURL(path.join(pkg, 'src/')).href;
const hooks = registerHooks({resolve(specifier, context, next) {
  if (specifier === 'typebox') return {url: pathToFileURL(process.env.SESSION_SEARCH_TYPEBOX).href, shortCircuit: true};
  if (context.parentURL?.startsWith(sourceBase) && specifier.startsWith('./')) {
    return {url: dependencies[specifier] ?? new URL(specifier + '.ts', context.parentURL).href, shortCircuit: true};
  }
  return next(specifier, context);
}, load(url, context, next) {
  if (url.startsWith(sourceBase) && url.endsWith('.ts')) {
    return {format: 'module', source: stripTypeScriptTypes(fs.readFileSync(fileURLToPath(url), 'utf8'), {mode: 'transform'}), shortCircuit: true};
  }
  return next(url, context);
}});
const main = await import(pathToFileURL(path.join(pkg, workerFlag === 'source' ? 'src/index.ts' : 'dist/index.js')));
const worker = workerFlag === 'worker';
main._setIndexWorkerEnabled(worker);
const home = process.env.USERPROFILE;
const profile = process.env.PI_CODING_AGENT_DIR;
const defaultBase = mode === 'code' ? path.join(home, '.pi/agent') : profile;
let sessions = path.join(defaultBase, 'sessions');
let archive = path.join(defaultBase, 'sessions-archive');
const store = path.join(root, 'store'), cwd = path.join(root, 'project-alpha');
const extra = path.join(root, 'extra'), extraArchive = path.join(root, 'extra-archive');
for (const p of [cwd, sessions, archive, extra, extraArchive, store]) fs.mkdirSync(p, {recursive: true});
fs.mkdirSync(path.join(cwd, '.pi'));
fs.writeFileSync(path.join(cwd, '.pi/settings.json'), JSON.stringify({'pi-session-search': {localPath: store}}));
const config = {extraSessionDirs: [extra], extraArchiveDirs: [extraArchive], sync: {interval: -1, initialDelay: -1}, primer: {enabled: false}};
if (scenario === 'configured') {
  const ignored = path.join(root, 'ignored-env');
  process.env.PI_SESSION_DIR = ignored;
  process.env.PI_CODING_AGENT_SESSION_DIR = path.join(root, 'ignored-modern');
  process.env.PI_SESSION_ARCHIVE_DIR = path.join(root, 'ignored-archive');
  sessions = config.sessionDir = path.join(root, 'configured-sessions');
  archive = config.archiveDir = path.join(root, 'configured-archive');
  for (const p of [sessions, archive]) fs.mkdirSync(p);
}
if (['preservation', 'unreadable', 'partial-fts', 'own-sync'].includes(scenario)) {
  config.sessionDir = sessions;
  config.archiveDir = archive;
}
if (scenario === 'env-roots') {
  sessions = process.env.PI_CODING_AGENT_SESSION_DIR = path.join(root, 'modern-sessions');
  archive = process.env.PI_SESSION_ARCHIVE_DIR = path.join(root, 'env-archive');
  for (const p of [sessions, archive]) fs.mkdirSync(p);
}
const requests = [];
const server = http.createServer(async (req, res) => {
  let body = ''; for await (const chunk of req) body += chunk;
  const payload = JSON.parse(body); requests.push(payload.input);
  assert.equal(payload.model, 'fixture');
  res.setHeader('content-type', 'application/json');
  res.end(JSON.stringify({data: payload.input.map((_, index) => ({index, embedding: [1, 0]}))}));
});
if (backend === 'hybrid') {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  config.embedder = {type: 'openai-compatible', model: 'fixture', dimensions: 2, sendDimensions: false, apiKey: '', baseUrl: `http://127.0.0.1:${server.address().port}`};
}
fs.writeFileSync(path.join(store, 'config.json'), JSON.stringify(config));
const tools = new Map(), commands = new Map(), handlers = new Map(), notices = [];
const pi = {registerTool: tool => tools.set(tool.name, tool), registerCommand: (name, command) => commands.set(name, command),
  on: (name, handler) => handlers.set(name, handler), sendMessage() {}, registerShortcut() {}};
const ctx = {cwd, hasUI: false, ui: {notify: (message, type) => notices.push({message, type}), setStatus() {}}, sessionManager: {getEntries: () => []}};
main.default(pi);
let started = false;
const hash = file => createHash('sha256').update(fs.readFileSync(file)).digest('hex');
function writeSession(dir, id, text = 'synthetic needle', work = cwd) {
  const folder = path.join(dir, '--project-alpha--'); fs.mkdirSync(folder, {recursive: true});
  const file = path.join(folder, `${id}.jsonl`);
  fs.writeFileSync(file, [
    {type: 'session', version: 3, id, timestamp: '2026-01-01T00:00:00Z', cwd: work},
    {type: 'message', id: 'u1', parentId: null, timestamp: '2026-01-01T00:00:01Z', message: {role: 'user', content: [{type: 'text', text}]}}
  ].map(row => JSON.stringify(row)).join('\n') + '\n');
  assert.equal(main.parseSession(file, false)?.userMessageCount, 1);
  return file;
}
const call = async (name, params) => (await tools.get(name).execute('fixture', params, undefined, undefined, ctx)).content.map(x => x.text ?? '').join('\n');
async function sync() {await commands.get('session-sync').handler('', ctx);}
async function start() {
  const before = process.getActiveResourcesInfo().filter(x => x === 'MessagePort').length;
  started = true;
  await handlers.get('session_start')({}, ctx);
  // session_start bounds primer wait. Poll the real tool, not an arbitrary sleep for sync.
  const deadline = Date.now() + 5000;
  while ((await call('session_list', {})).includes('warming (loading')) {
    assert(Date.now() < deadline, 'index load deadline');
    await new Promise(resolve => setImmediate(resolve));
  }
  const after = process.getActiveResourcesInfo().filter(x => x === 'MessagePort').length;
  assert.equal(after > before, worker, 'the requested worker/main path must actually run');
}
function keywordRows() {
  const db = new DatabaseSync(path.join(store, 'index/sessions-fts.db'));
  try {return db.prepare('SELECT id, file, json, summary, content FROM sessions ORDER BY id').all();} finally {db.close();}
}
function hybridRows() {
  const db = new DatabaseSync(path.join(store, 'index/hybrid-fts.db'));
  try {return db.prepare('SELECT id, name, content FROM s ORDER BY id').all();} finally {db.close();}
}
function indexSnapshot() {
  return backend === 'hybrid'
    ? {json: fs.readFileSync(path.join(store, 'index/session-index.json'), 'utf8'), rows: hybridRows()}
    : keywordRows();
}
try {
  if (scenario === 'partial-fts') {
    assert.equal(backend, 'hybrid');
    const indexDir = path.join(store, 'index'); fs.mkdirSync(indexDir);
    const a = writeSession(sessions, 'partial-a', 'alpha metadata');
    const b = writeSession(sessions, 'partial-b', 'missingword metadata');
    const data = {version: 3, sessions: {}};
    for (const [id, file] of [['partial-a', a], ['partial-b', b]]) {
      const st = fs.statSync(file);
      data.sessions[id] = {session: main.parseSession(file, false), summary: 'retained summary', embedding: Buffer.from(new Float32Array([1, 0]).buffer).toString('base64'), mtimeMs: st.mtimeMs, sizeBytes: st.size};
    }
    const jsonFile = path.join(indexDir, 'session-index.json');
    fs.writeFileSync(jsonFile, JSON.stringify(data));
    const before = hash(jsonFile);
    const db = new DatabaseSync(path.join(indexDir, 'hybrid-fts.db'));
    db.exec("CREATE VIRTUAL TABLE s USING fts5(id UNINDEXED, name, content, tokenize='porter unicode61')");
    const insert = db.prepare('INSERT INTO s (id,name,content) VALUES (?,?,?)');
    insert.run('partial-a', 'rich existing row', 'rich full text must survive');
    insert.run('orphan', '', 'same count is not same ID coverage');
    db.close();
    await start();
    const rows = hybridRows();
    assert(rows.some(row => row.id === 'partial-b' && row.content.includes('missingword')), 'partial hybrid sidecar must recover missing IDs even with equal row counts');
    assert.equal(rows.find(row => row.id === 'partial-a').content, 'rich full text must survive');
    const recoveredDb = new DatabaseSync(path.join(indexDir, 'hybrid-fts.db'));
    try {
      assert.deepEqual(recoveredDb.prepare('SELECT id FROM s WHERE s MATCH ?').all('missingword').map(row => row.id), ['partial-b']);
    } finally {recoveredDb.close();}
    assert.equal(hash(jsonFile), before, 'load recovery must preserve exact JSON/vector bytes');
    assert.equal(requests.length, 0, 'sidecar recovery must not call the embedder');
    assert((await call('session_list', {})).includes('partial-b'));
  } else if (scenario === 'own-sync') {
    await start();
    assert((await call('session_search', {query: 'synthetic'})).includes('Session index is empty'));
    const file = writeSession(sessions, 'fresh-session'); const digest = hash(file);
    await sync();
    const list = await call('session_list', {}), search = await call('session_search', {query: 'synthetic'});
    assert(list.includes('fresh-session'), `own sync must refresh the tool reader: ${list}`);
    assert(search.includes('fresh-session'), search);
    assert((await call('session_read', {session: 'fresh-session'})).includes('synthetic needle'));
    assert.equal(hash(file), digest);
  } else if (scenario === 'preservation' || scenario === 'unreadable') {
    const file = writeSession(sessions, 'preserved-session');
    await start(); await sync();
    assert((await call('session_list', {})).includes('preserved-session'));
    const before = indexSnapshot(), calls = requests.length;
    // A missing source tree must not become evidence of deleted sessions.
    if (scenario === 'preservation') {
      const moved = sessions + '-offline'; fs.renameSync(sessions, moved);
      try {
        await sync();
        assert.deepEqual(indexSnapshot(), before, 'missing source root must preserve persisted rows and vectors');
        assert((await call('session_list', {})).includes('preserved-session'), 'missing source root must preserve the live reader');
      } finally {fs.renameSync(moved, sessions);}
    }
    // Existing but unreadable as a directory: a real native ENOTDIR, not a
    // mocked discovery result. Permission failures use this same catch path.
    const unavailable = sessions + '-unavailable'; fs.renameSync(sessions, unavailable);
    try {
      fs.writeFileSync(sessions, 'synthetic unavailable root');
      assert.throws(() => fs.readdirSync(sessions), e => e.code === 'ENOTDIR', 'enumeration must really fail');
      await sync();
      assert.deepEqual(indexSnapshot(), before, 'unreadable source root must preserve persisted rows and vectors');
    } finally {
      fs.unlinkSync(sessions); fs.renameSync(unavailable, sessions);
      fs.readdirSync(sessions);
    }
    assert.equal(requests.length, calls, 'unavailable roots must not re-embed history');
    // A readable empty root IS authoritative deletion evidence.
    fs.unlinkSync(file); fs.rmdirSync(archive); await sync();
    assert(!(await call('session_list', {})).includes('preserved-session'), 'readable empty source root must remove deleted sessions even when the optional archive is absent');
    if (backend === 'hybrid') {
      assert.deepEqual(JSON.parse(fs.readFileSync(path.join(store, 'index/session-index.json'), 'utf8')).sessions, {});
      assert.equal(hybridRows().length, 0);
    } else assert.equal(keywordRows().length, 0);
  } else {
    const files = [writeSession(sessions, 'active-session'), writeSession(archive, 'archived-session'),
      writeSession(extra, 'extra-session'), writeSession(extraArchive, 'extra-archive-session')];
    const hashes = files.map(hash);
    await start();
    // Run safeguards before the new positive assertions, so baseline RED does
    // not hide successful refusal controls behind the missing HOME behavior.
    const outside = writeSession(path.join(root, 'outside'), 'outside-session', 'PRIVATE_OUTSIDE_SENTINEL');
    const sibling = writeSession(sessions + '-sibling', 'sibling-session', 'PRIVATE_SIBLING_SENTINEL');
    const junction = path.join(sessions, 'escape'); fs.symlinkSync(path.dirname(outside), junction, 'junction');
    try {
      for (const denied of [outside, sibling, path.join(sessions, '..', path.basename(sessions + '-sibling'), '--project-alpha--', 'sibling-session.jsonl'), path.join(junction, path.basename(outside))]) {
        const read = await call('session_read', {session: denied});
        assert(read.startsWith('Access denied:'), 'containment refusal must survive');
        assert(!read.includes('PRIVATE_OUTSIDE_SENTINEL') && !read.includes('PRIVATE_SIBLING_SENTINEL'));
      }
    } finally {fs.unlinkSync(junction);}
    console.log(JSON.stringify({stage: 'containment-safeguards', scenario, mode, path: workerFlag, status: 'PASS'}));
    assert((await call('session_read', {session: files[0]})).includes('synthetic needle'), 'absolute session_read must use the same native no-HOME source root');
    await sync();
    const list = await call('session_list', {}), search = await call('session_search', {query: 'synthetic'});
    for (const [i, file] of files.entries()) {
      assert(list.includes(['active-session', 'archived-session', 'extra-session', 'extra-archive-session'][i]), list);
      const displayFile = '~' + file.slice(home.length);
      assert(search.includes(displayFile), 'search must return a valid native-home abbreviation');
      assert((await call('session_read', {session: displayFile})).includes('synthetic needle'), 'search file reference must round-trip through session_read');
      assert((await call('session_read', {session: file})).includes('synthetic needle'), 'reader must allow the same roots as discovery');
      assert.equal(hash(file), hashes[i]);
    }
    if (scenario === 'no-home' && mode === 'code') {
      const tilde = '~' + path.sep + path.relative(home, files[0]);
      assert((await call('session_read', {session: tilde})).includes('synthetic needle'), 'tilde must use the native homedir too');
    }

  }
  assert(!notices.some(n => n.message.includes('init failed') || n.message.includes('Embedding batch failed')), JSON.stringify(notices));
  console.log(JSON.stringify({scenario, mode, execution: workerFlag, worker, backend, status: 'PASS', nativeNoHome: true, requests: requests.length}));
} finally {

  if (started) await handlers.get('session_shutdown')({}, ctx);
  if (server.listening) await new Promise(resolve => server.close(resolve));
  hooks.deregister();
}
