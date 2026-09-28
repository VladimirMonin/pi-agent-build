// Fail-closed point edits from strict JSON: {renames, facts, lessons}.
import { readFileSync } from "node:fs";
import {
  SafetyError,
  assertPreserved,
  beginImmediate,
  createConsistentSnapshot,
  digest,
  hasColumn,
  openSnapshot,
  ownerOverride,
  positional,
  printSummary,
  protectedTokens,
  reportFailure,
  requireDatabase,
  requireInput,
  stableRowsDigest,
  validateCli,
} from "./lib/safety.mjs";

const KEY_RE = /^[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)+$/u;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu;

function plainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value) && Object.getPrototypeOf(value) === Object.prototype;
}

function assertUniqueJsonKeys(raw) {
  let cursor = 0;
  const fail = (message = "ОТКАЗ: некорректный JSON manifest.") => { throw new SafetyError("plan", message); };
  const whitespace = () => { while (/\s/u.test(raw[cursor] ?? "")) cursor += 1; };
  function string() {
    if (raw[cursor] !== '"') fail();
    const start = cursor;
    cursor += 1;
    while (cursor < raw.length) {
      if (raw[cursor] === '"') {
        cursor += 1;
        try { return JSON.parse(raw.slice(start, cursor)); } catch { fail(); }
      }
      if (raw[cursor] === "\\") {
        cursor += 1;
        if (raw[cursor] === "u") {
          if (!/^[0-9a-f]{4}$/iu.test(raw.slice(cursor + 1, cursor + 5))) fail();
          cursor += 5;
          continue;
        }
        if (!/["\\/bfnrt]/u.test(raw[cursor] ?? "")) fail();
      } else if (raw.charCodeAt(cursor) < 0x20) fail();
      cursor += 1;
    }
    fail();
  }
  function value() {
    whitespace();
    if (raw[cursor] === "{") return object();
    if (raw[cursor] === "[") return array();
    if (raw[cursor] === '"') { string(); return; }
    const tail = raw.slice(cursor);
    const primitive = tail.match(/^(?:true|false|null|-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?)/u);
    if (!primitive) fail();
    cursor += primitive[0].length;
  }
  function array() {
    cursor += 1;
    whitespace();
    if (raw[cursor] === "]") { cursor += 1; return; }
    while (true) {
      value();
      whitespace();
      if (raw[cursor] === "]") { cursor += 1; return; }
      if (raw[cursor] !== ",") fail();
      cursor += 1;
    }
  }
  function object() {
    cursor += 1;
    whitespace();
    if (raw[cursor] === "}") { cursor += 1; return; }
    const keys = new Set();
    while (true) {
      whitespace();
      const key = string();
      if (keys.has(key)) fail("ОТКАЗ: JSON manifest содержит повторное поле.");
      keys.add(key);
      whitespace();
      if (raw[cursor] !== ":") fail();
      cursor += 1;
      value();
      whitespace();
      if (raw[cursor] === "}") { cursor += 1; return; }
      if (raw[cursor] !== ",") fail();
      cursor += 1;
    }
  }
  value();
  whitespace();
  if (cursor !== raw.length) fail();
}

function parseManifest(raw) {
  assertUniqueJsonKeys(raw);
  let data;
  try {
    data = JSON.parse(raw);
  } catch {
    throw new SafetyError("plan", "ОТКАЗ: некорректный JSON manifest.");
  }
  if (!plainObject(data)) throw new SafetyError("plan", "ОТКАЗ: manifest должен быть JSON-объектом.");
  const allowed = new Set(["renames", "facts", "lessons"]);
  if (Object.keys(data).some((key) => !allowed.has(key))) throw new SafetyError("plan", "ОТКАЗ: manifest содержит неизвестное поле.");
  const manifest = {};
  for (const key of allowed) {
    const value = data[key] ?? {};
    if (!plainObject(value)) throw new SafetyError("plan", "ОТКАЗ: секции manifest должны быть объектами.");
    manifest[key] = value;
  }
  if (![...Object.values(manifest)].some((value) => Object.keys(value).length)) throw new SafetyError("plan", "ОТКАЗ: пустой manifest запрещён.");

  for (const [key, value] of Object.entries(manifest.facts)) {
    if (!KEY_RE.test(key) || typeof value !== "string" || !value.trim()) throw new SafetyError("plan", "ОТКАЗ: факт содержит пустой или некорректный key/value.");
  }
  for (const [id, rule] of Object.entries(manifest.lessons)) {
    if (!UUID_RE.test(id) || typeof rule !== "string" || !rule.trim()) throw new SafetyError("plan", "ОТКАЗ: урок содержит пустой или некорректный id/rule.");
  }
  const targets = [];
  for (const [oldKey, newKey] of Object.entries(manifest.renames)) {
    if (!KEY_RE.test(oldKey) || typeof newKey !== "string" || !KEY_RE.test(newKey) || oldKey === newKey) {
      throw new SafetyError("plan", "ОТКАЗ: rename содержит пустой или некорректный key.");
    }
    targets.push(newKey);
  }
  if (new Set(targets).size !== targets.length) throw new SafetyError("plan", "ОТКАЗ: rename targets повторяются.");
  const renameSources = new Set(Object.keys(manifest.renames));
  if (targets.some((target) => renameSources.has(target))) throw new SafetyError("plan", "ОТКАЗ: цепочки rename запрещены.");
  if (Object.keys(manifest.facts).some((key) => renameSources.has(key) || targets.includes(key))) throw new SafetyError("plan", "ОТКАЗ: fact patch конфликтует с rename.");
  return manifest;
}

function analyze(db, manifest) {
  const fact = db.prepare("SELECT key,value,source FROM semantic WHERE key=?");
  const lesson = db.prepare("SELECT id,rule,source,is_deleted,project,category,negative,created_at FROM lessons WHERE id=?");
  const stateRows = [];
  let owners = 0;
  let protectedCount = 0;

  for (const [key, value] of Object.entries(manifest.facts)) {
    const row = fact.get(key);
    if (!row) throw new SafetyError("stale", "ОТКАЗ: manifest отсутствует или устарел.");
    if (value.length >= row.value.length) throw new SafetyError("plan", "ОТКАЗ: fact patch не сокращает значение.");
    protectedCount += assertPreserved([row.value], value, [...protectedTokens(row.value)]);
    if (row.source === "user") owners += 1;
    stateRows.push({ kind: "fact", ...row });
  }
  for (const [oldKey, newKey] of Object.entries(manifest.renames)) {
    const row = fact.get(oldKey);
    if (!row || fact.get(newKey)) throw new SafetyError("stale", "ОТКАЗ: manifest отсутствует или устарел.");
    if (row.source === "user") owners += 1;
    stateRows.push({ kind: "rename", target: newKey, ...row });
  }
  for (const [id, rule] of Object.entries(manifest.lessons)) {
    const row = lesson.get(id);
    if (!row || row.is_deleted !== 0) throw new SafetyError("stale", "ОТКАЗ: manifest отсутствует или устарел.");
    if (rule.length >= row.rule.length) throw new SafetyError("plan", "ОТКАЗ: lesson patch не сокращает правило.");
    protectedCount += assertPreserved([row.rule], rule, [...protectedTokens(row.rule)]);
    if (row.source === "user") owners += 1;
    stateRows.push({ kind: "lesson", ...row });
  }
  stateRows.sort((left, right) => JSON.stringify(left).localeCompare(JSON.stringify(right)));
  return {
    owners,
    protectedCount,
    changes: stateRows.length,
    stateDigest: stableRowsDigest(stateRows),
  };
}

function applyManifest(db, manifest) {
  const embedding = hasColumn(db, "semantic", "embedding");
  const updateFact = db.prepare(`UPDATE semantic SET value=?,updated_at=datetime('now'),last_accessed=NULL${embedding ? ",embedding=NULL" : ""} WHERE key=?`);
  const renameFact = db.prepare(`UPDATE semantic SET key=?,updated_at=datetime('now'),last_accessed=NULL${embedding ? ",embedding=NULL" : ""} WHERE key=?`);
  const updateLesson = db.prepare("UPDATE lessons SET rule=? WHERE id=? AND is_deleted=0");
  for (const [key, value] of Object.entries(manifest.facts)) if (updateFact.run(value, key).changes !== 1) throw new SafetyError("stale", "ОТКАЗ: manifest отсутствует или устарел.");
  for (const [oldKey, newKey] of Object.entries(manifest.renames)) if (renameFact.run(newKey, oldKey).changes !== 1) throw new SafetyError("stale", "ОТКАЗ: manifest отсутствует или устарел.");
  for (const [id, rule] of Object.entries(manifest.lessons)) if (updateLesson.run(rule, id).changes !== 1) throw new SafetyError("stale", "ОТКАЗ: manifest отсутствует или устарел.");

  const getFact = db.prepare(`SELECT value${embedding ? ",embedding" : ""} FROM semantic WHERE key=?`);
  const getLesson = db.prepare("SELECT rule FROM lessons WHERE id=? AND is_deleted=0");
  for (const [key, value] of Object.entries(manifest.facts)) {
    const row = getFact.get(key);
    if (!row || row.value !== value || (embedding && row.embedding !== null)) throw new SafetyError("verification", "ОТКАЗ: транзакционная самопроверка не пройдена.");
  }
  for (const [oldKey, newKey] of Object.entries(manifest.renames)) {
    const row = getFact.get(newKey);
    if (!row || getFact.get(oldKey) || (embedding && row.embedding !== null)) throw new SafetyError("verification", "ОТКАЗ: транзакционная самопроверка не пройдена.");
  }
  for (const [id, rule] of Object.entries(manifest.lessons)) {
    if (getLesson.get(id)?.rule !== rule) throw new SafetyError("verification", "ОТКАЗ: транзакционная самопроверка не пройдена.");
  }
}

let snapshot;
let snapshotDb;
let applyDb;
try {
  const argv = process.argv.slice(2);
  validateCli(argv, { values: ["db"], booleans: ["apply", "owner-override"] });
  const dbPath = requireDatabase(argv);
  const inputs = positional(argv);
  if (inputs.length !== 1) throw new SafetyError("arguments", "ОТКАЗ: требуется ровно один JSON manifest.");
  const manifestPath = requireInput(inputs[0], "JSON manifest");
  const apply = argv.includes("--apply");
  const allowOwner = ownerOverride(argv);
  const initialRaw = readFileSync(manifestPath, "utf8");
  const initialPlanDigest = digest(initialRaw);

  snapshot = createConsistentSnapshot(dbPath);
  snapshotDb = openSnapshot(snapshot.path);
  const initialManifest = parseManifest(initialRaw);
  const initialAnalysis = analyze(snapshotDb, initialManifest);
  snapshotDb.close();
  snapshotDb = undefined;

  if (!apply) {
    printSummary({ groups: 0, ...initialAnalysis, apply: false });
  } else {
    applyDb = beginImmediate(dbPath);
    try {
      const lockedRaw = readFileSync(manifestPath, "utf8");
      if (digest(lockedRaw) !== initialPlanDigest) throw new SafetyError("stale", "ОТКАЗ: manifest изменился и устарел.");
      const lockedManifest = parseManifest(lockedRaw);
      const lockedAnalysis = analyze(applyDb, lockedManifest);
      if (lockedAnalysis.stateDigest !== initialAnalysis.stateDigest) throw new SafetyError("stale", "ОТКАЗ: manifest отсутствует или устарел.");
      if (lockedAnalysis.owners && !allowOwner) throw new SafetyError("owner", "ОТКАЗ: source=user требует --owner-override.");
      applyManifest(applyDb, lockedManifest);
      if (digest(readFileSync(manifestPath, "utf8")) !== initialPlanDigest) throw new SafetyError("stale", "ОТКАЗ: manifest изменился и устарел.");
      applyDb.exec("COMMIT");
      applyDb.close();
      applyDb = undefined;
      printSummary({ groups: 0, ...lockedAnalysis, apply: true });
    } catch (error) {
      try { applyDb.exec("ROLLBACK"); } catch {}
      applyDb.close();
      applyDb = undefined;
      throw error;
    }
  }
} catch (error) {
  process.exitCode = reportFailure(error);
} finally {
  try { snapshotDb?.close(); } catch {}
  try { applyDb?.close(); } catch {}
  snapshot?.cleanup();
}
