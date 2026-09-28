import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { spawn, spawnSync } from "node:child_process";
import {
  existsSync,
  lstatSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, relative, resolve } from "node:path";
import { setTimeout as delay } from "node:timers/promises";
import { DatabaseSync } from "node:sqlite";
import test from "node:test";

const skillDir = resolve(import.meta.dirname, "../../skills/memory-ops");
const scriptsDir = join(skillDir, "scripts");
const UUID_A = "11111111-1111-4111-8111-111111111111";
const UUID_B = "22222222-2222-4222-8222-222222222222";

function run(script, args = [], cwd = skillDir, env = process.env) {
  return spawnSync(process.execPath, [join(scriptsDir, script), ...args], {
    cwd,
    env,
    encoding: "utf8",
  });
}

function runAsync(script, args = [], cwd = skillDir, env = process.env) {
  const child = spawn(process.execPath, [join(scriptsDir, script), ...args], {
    cwd,
    env,
    stdio: ["ignore", "pipe", "pipe"],
  });
  let stdout = "";
  let stderr = "";
  child.stdout.setEncoding("utf8").on("data", (chunk) => { stdout += chunk; });
  child.stderr.setEncoding("utf8").on("data", (chunk) => { stderr += chunk; });
  return {
    child,
    result: new Promise((resolveResult) => child.on("close", (status, signal) => resolveResult({ status, signal, stdout, stderr }))),
  };
}

function hash(path) {
  return createHash("sha256").update(readFileSync(path)).digest("hex");
}

function fileState(path) {
  return existsSync(path) ? { size: statSync(path).size, hash: hash(path) } : null;
}

function sqliteState(dbPath) {
  return Object.fromEntries([dbPath, `${dbPath}-wal`, `${dbPath}-shm`].map((path) => [path.slice(dbPath.length), fileState(path)]));
}

function tree(root) {
  const out = [];
  function walk(dir) {
    for (const name of readdirSync(dir).sort()) {
      const path = join(dir, name);
      const rel = relative(root, path).replaceAll("\\", "/");
      out.push(rel);
      if (lstatSync(path).isDirectory()) walk(path);
    }
  }
  walk(root);
  return out;
}

function fixture({ wal = false } = {}) {
  const dir = mkdtempSync(join(tmpdir(), "memory-ops-test-"));
  const dbPath = join(dir, "memory.db");
  const db = new DatabaseSync(dbPath);
  if (wal) {
    db.exec("PRAGMA journal_mode=WAL; PRAGMA wal_autocheckpoint=0;");
  }
  db.exec(`
    CREATE TABLE semantic (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      confidence REAL,
      source TEXT NOT NULL,
      created_at TEXT,
      updated_at TEXT,
      last_accessed TEXT,
      embedding BLOB
    );
    CREATE TABLE lessons (
      id TEXT PRIMARY KEY,
      rule TEXT NOT NULL,
      category TEXT,
      source TEXT NOT NULL,
      negative INTEGER DEFAULT 0,
      is_deleted INTEGER DEFAULT 0,
      created_at TEXT,
      project TEXT
    );
  `);
  const fact = db.prepare("INSERT INTO semantic (key,value,confidence,source,created_at,updated_at,embedding) VALUES (?,?,?,?,datetime('now'),datetime('now'),?)");
  fact.run("demo.domain.keep", "KEEP_TOKEN 42: подробная исходная формулировка", 0.8, "consolidation", Buffer.from("old-embedding"));
  fact.run("demo.domain.drop", "OWNER_TOKEN: формулировка владельца", 0.95, "user", Buffer.from("old-embedding"));
  fact.run("user.fact", "USER_TOKEN 7: очень длинная формулировка владельца", 0.95, "user", Buffer.from("old-embedding"));
  fact.run("cons.fact", "CONS_TOKEN 9: машинная формулировка для сжатия", 0.8, "consolidation", Buffer.from("old-embedding"));
  fact.run("signed.fact", "LIMIT -1: отрицательный sentinel", 0.8, "consolidation", Buffer.from("old-embedding"));
  fact.run("exponent.fact", "EPSILON 1e-6: научная запись", 0.8, "consolidation", Buffer.from("old-embedding"));
  fact.run("fraction.fact", "FRACTION -.5: дробный sentinel", 0.8, "consolidation", Buffer.from("old-embedding"));
  fact.run("path.fact", "/srv/KeyFile --Mode API_TIMEOUT: точные регистрозависимые tokens", 0.8, "consolidation", Buffer.from("old-embedding"));
  fact.run("unicode.fact", "/srv/cafe\u0301/config: decomposed path", 0.8, "consolidation", Buffer.from("old-embedding"));
  fact.run("retention.fact", "backups run daily and retention is seven days", 0.8, "consolidation", Buffer.from("old-embedding"));
  fact.run("winpath.fact", "Use C:\\Program Files\\foo\\bar with detailed wording", 0.8, "consolidation", Buffer.from("old-embedding"));
  fact.run("posixspace.fact", "Use /srv/My File with detailed wording", 0.8, "consolidation", Buffer.from("old-embedding"));
  fact.run("posixsingle.fact", "Use /srv/My A with detailed wording", 0.8, "consolidation", Buffer.from("old-embedding"));
  fact.run("order.fact", "encrypt before upload with detailed wording", 0.8, "consolidation", Buffer.from("old-embedding"));
  fact.run("negation.fact", "не удалять backup with detailed wording", 0.8, "consolidation", Buffer.from("old-embedding"));
  const lesson = db.prepare("INSERT INTO lessons (id,rule,category,source,negative,is_deleted,created_at,project) VALUES (?,?,?,?,?,0,datetime('now'),?)");
  lesson.run(UUID_A, "OWNER_RULE API_TIMEOUT 42", "general", "user", 0, "demo");
  lesson.run(UUID_B, "SECOND_RULE API_TIMEOUT 42 detailed wording", "general", "consolidation", 0, "demo");
  if (!wal) db.close();
  return { dir, dbPath, db: wal ? db : null };
}

function writeFactPlan(dir, {
  name = "facts-plan.md",
  section = "Группы слияния фактов",
  keep = "demo.domain.keep",
  value = "KEEP_TOKEN 42 и OWNER_TOKEN",
  members = ["demo.domain.keep", "demo.domain.drop"],
  preserved = "KEEP_TOKEN, OWNER_TOKEN, 42",
  deletes = ["demo.domain.drop"],
  extra = "",
} = {}) {
  const path = join(dir, name);
  const quoted = (values) => values.map((item) => `\`${item}\``).join(", ");
  writeFileSync(path, `# Синтетический план\n\n## ${section}\n\n### G1\nKEEP KEY: \`${keep}\`\nНОВОЕ ЗНАЧЕНИЕ: ${value}\nВОШЛО: ${quoted(members)}\nЧТО СОХРАНЕНО: ${preserved}\nУДАЛИТЬ: ${quoted(deletes)}\n${extra}`);
  return path;
}

function lessonGroup({
  title = "LR1",
  value = "OWNER_RULE и SECOND_RULE используют API_TIMEOUT 42",
  members = [UUID_A, UUID_B],
  preserved = "OWNER_RULE, SECOND_RULE, API_TIMEOUT, 42",
  deletes = [UUID_A, UUID_B],
} = {}) {
  return `### ${title}\nПРОЕКТ: demo · ТИП: negative=0 · КАТЕГОРИЯ: general\nГОТОВЫЙ ТЕКСТ УРОКА: ${value}\nВОШЛО: ${members.join(", ")}\nЧТО СОХРАНЕНО: ${preserved}\nУДАЛИТЬ: ${deletes.join(", ")}\n`;
}

function writeLessonPlan(dir, groups = [lessonGroup()], name = "lessons-plan.md") {
  const path = join(dir, name);
  writeFileSync(path, `# Синтетический план\n\n## Слияние уроков\n\n${groups.join("\n")}`);
  return path;
}

function openReadOnly(path) {
  return new DatabaseSync(path, { readOnly: true });
}

function assertNoMutation(dbPath, before) {
  assert.deepEqual(sqliteState(dbPath), before);
}

function combined(result) {
  return `${result.stdout}\n${result.stderr}`;
}

test("каждый скрипт требует явный --db без раскрытия пути", () => {
  for (const [script, args] of [
    ["apply-facts.mjs", ["missing.md"]],
    ["apply-lessons.mjs", ["missing.md"]],
    ["patch-entries.mjs", ["missing.json"]],
    ["inject-probe.mjs", ["--estimate"]],
  ]) {
    const result = run(script, args);
    assert.notEqual(result.status, 0, script);
    assert.match(result.stderr, /--db/iu, script);
    assert.doesNotMatch(combined(result), /(?:[A-Z]:[\\/]|\/Users\/|\\Users\\)/u, script);
  }
});

test("dry-run читает WAL snapshot и оставляет db/wal/shm byte-identical", () => {
  const { dir, dbPath, db } = fixture({ wal: true });
  const plan = writeFactPlan(dir);
  assert.ok(existsSync(`${dbPath}-wal`));
  assert.ok(existsSync(`${dbPath}-shm`));
  const before = sqliteState(dbPath);
  const result = run("apply-facts.mjs", [plan, `--db=${dbPath}`], skillDir);
  assert.equal(result.status, 0, combined(result));
  assert.match(result.stdout, /DRY-RUN/u);
  assertNoMutation(dbPath, before);
  db.close();
});

test("dry-run patch и lessons также не касаются SQLite sidecars", () => {
  for (const [script, createInput] of [
    ["apply-lessons.mjs", (dir) => writeLessonPlan(dir)],
    ["patch-entries.mjs", (dir) => {
      const path = join(dir, "patch.json");
      writeFileSync(path, JSON.stringify({ facts: { "cons.fact": "CONS_TOKEN 9: кратко" } }));
      return path;
    }],
  ]) {
    const { dir, dbPath, db } = fixture({ wal: true });
    const input = createInput(dir);
    const before = sqliteState(dbPath);
    const result = run(script, [input, `--db=${dbPath}`], skillDir);
    assert.equal(result.status, 0, combined(result));
    assertNoMutation(dbPath, before);
    db.close();
  }
});

test("apply-facts блокирует source=user без owner override и очищает embedding", () => {
  const { dir, dbPath } = fixture();
  const plan = writeFactPlan(dir);
  const blocked = run("apply-facts.mjs", [plan, `--db=${dbPath}`, "--apply"], skillDir);
  assert.notEqual(blocked.status, 0);
  assert.match(combined(blocked), /owner-override/u);

  const applied = run("apply-facts.mjs", [plan, `--db=${dbPath}`, "--apply", "--owner-override"], skillDir);
  assert.equal(applied.status, 0, combined(applied));
  const db = openReadOnly(dbPath);
  assert.equal(db.prepare("SELECT 1 FROM semantic WHERE key=?").get("demo.domain.drop"), undefined);
  const kept = db.prepare("SELECT value,source,embedding FROM semantic WHERE key=?").get("demo.domain.keep");
  assert.equal(kept.value, "KEEP_TOKEN 42 и OWNER_TOKEN");
  assert.equal(kept.source, "user");
  assert.equal(kept.embedding, null);
  db.close();
});

test("patch-entries требует сохранения токенов, запрещает пустые строки и очищает embedding", () => {
  const { dir, dbPath } = fixture();
  for (const [name, manifest] of [
    ["lost", { facts: { "cons.fact": "коротко" } }],
    ["empty-fact", { facts: { "cons.fact": "" } }],
    ["empty-lesson", { lessons: { [UUID_B]: "" } }],
    ["empty-rename", { renames: { "cons.fact": "" } }],
  ]) {
    const path = join(dir, `${name}.json`);
    writeFileSync(path, JSON.stringify(manifest));
    const result = run("patch-entries.mjs", [path, `--db=${dbPath}`, "--apply"], skillDir);
    assert.notEqual(result.status, 0, name);
  }

  const path = join(dir, "valid.json");
  writeFileSync(path, JSON.stringify({
    facts: { "cons.fact": "CONS_TOKEN 9: кратко" },
    renames: { "demo.domain.keep": "demo.domain.kept" },
  }));
  const applied = run("patch-entries.mjs", [path, `--db=${dbPath}`, "--apply"], skillDir);
  assert.equal(applied.status, 0, combined(applied));
  const db = openReadOnly(dbPath);
  assert.equal(db.prepare("SELECT embedding FROM semantic WHERE key=?").get("cons.fact").embedding, null);
  assert.equal(db.prepare("SELECT embedding FROM semantic WHERE key=?").get("demo.domain.kept").embedding, null);
  db.close();
});

test("preservation сохраняет byte-exact tokens, Unicode и все знаки числа", () => {
  const { dir, dbPath } = fixture();
  for (const [name, manifest] of [
    ["identifier-case", { facts: { "cons.fact": "cons_token 9: кратко" } }],
    ["numeric-sign", { facts: { "signed.fact": "LIMIT 1: sentinel" } }],
    ["numeric-exponent", { facts: { "exponent.fact": "EPSILON 1e+6: запись" } }],
    ["numeric-leading-decimal", { facts: { "fraction.fact": "FRACTION +.5: sentinel" } }],
    ["path-flag-case", { facts: { "path.fact": "/srv/keyfile --mode api_timeout" } }],
    ["unicode-bytes", { facts: { "unicode.fact": "/srv/café/config: path" } }],
    ["semantic-loss", { facts: { "retention.fact": "backups run daily" } }],
    ["path-after-space-case", { facts: { "winpath.fact": "Use C:\\Program Files\\foo\\BAR" } }],
    ["posix-path-after-space-case", { facts: { "posixspace.fact": "Use /srv/My file" } }],
    ["single-character-path-case", { facts: { "posixsingle.fact": "Use /srv/My a" } }],
    ["semantic-order", { facts: { "order.fact": "upload before encrypt" } }],
    ["semantic-negation", { facts: { "negation.fact": "удалять backup" } }],
  ]) {
    const path = join(dir, `${name}.json`);
    writeFileSync(path, JSON.stringify(manifest));
    const before = sqliteState(dbPath);
    const result = run("patch-entries.mjs", [path, `--db=${dbPath}`, "--apply"], skillDir);
    assert.notEqual(result.status, 0, name);
    assertNoMutation(dbPath, before);
  }
});

test("duplicate JSON members abort manifest instead of discarding operations", () => {
  const { dir, dbPath } = fixture();
  const manifests = [
    '{"facts":{"cons.fact":"CONS_TOKEN 9: кратко"},"facts":{"signed.fact":"LIMIT -1: sentinel"}}',
    '{"facts":{"cons.fact":"CONS_TOKEN 9: кратко","cons.fact":"CONS_TOKEN 9: ещё короче"}}',
  ];
  for (const [index, raw] of manifests.entries()) {
    const path = join(dir, `duplicate-${index}.json`);
    writeFileSync(path, raw);
    const before = sqliteState(dbPath);
    const result = run("patch-entries.mjs", [path, `--db=${dbPath}`, "--apply"], skillDir);
    assert.notEqual(result.status, 0, combined(result));
    assert.match(combined(result), /повтор/iu);
    assertNoMutation(dbPath, before);
  }
});

test("lesson УДАЛИТЬ honored: не перечисленный вход остаётся активным", () => {
  const { dir, dbPath } = fixture();
  const plan = writeLessonPlan(dir, [lessonGroup({ deletes: [UUID_A] })]);
  const applied = run("apply-lessons.mjs", [plan, `--db=${dbPath}`, "--apply", "--owner-override"], skillDir);
  assert.equal(applied.status, 0, combined(applied));
  const db = openReadOnly(dbPath);
  assert.equal(db.prepare("SELECT is_deleted FROM lessons WHERE id=?").get(UUID_A).is_deleted, 1);
  assert.equal(db.prepare("SELECT is_deleted FROM lessons WHERE id=?").get(UUID_B).is_deleted, 0);
  assert.equal(db.prepare("SELECT count(*) n FROM lessons WHERE is_deleted=0").get().n, 2);
  db.close();
});

test("lost lesson tokens abort the whole apply even with --min-coverage=0", () => {
  const { dir, dbPath } = fixture();
  const plan = writeLessonPlan(dir, [lessonGroup({ value: "API_TIMEOUT", preserved: "API_TIMEOUT" })]);
  const before = sqliteState(dbPath);
  const result = run("apply-lessons.mjs", [plan, `--db=${dbPath}`, "--apply", "--owner-override", "--min-coverage=0"], skillDir);
  assert.notEqual(result.status, 0, combined(result));
  assertNoMutation(dbPath, before);
});

test("lost fact tokens abort apply", () => {
  const { dir, dbPath } = fixture();
  const plan = writeFactPlan(dir, { value: "KEEP_TOKEN 42", preserved: "KEEP_TOKEN, 42" });
  const before = sqliteState(dbPath);
  const result = run("apply-facts.mjs", [plan, `--db=${dbPath}`, "--apply", "--owner-override"], skillDir);
  assert.notEqual(result.status, 0, combined(result));
  assertNoMutation(dbPath, before);
});

test("missing lesson in any group aborts all groups without partial apply", () => {
  const { dir, dbPath } = fixture();
  const missing = "33333333-3333-4333-8333-333333333333";
  const plan = writeLessonPlan(dir, [
    lessonGroup({ title: "GOOD", members: [UUID_B], value: "SECOND_RULE API_TIMEOUT 42", preserved: "SECOND_RULE, API_TIMEOUT, 42", deletes: [UUID_B] }),
    lessonGroup({ title: "MISSING", members: [missing], value: "MISSING_TOKEN", preserved: "MISSING_TOKEN", deletes: [missing] }),
  ]);
  const before = sqliteState(dbPath);
  const result = run("apply-lessons.mjs", [plan, `--db=${dbPath}`, "--apply"], skillDir);
  assert.notEqual(result.status, 0, combined(result));
  assertNoMutation(dbPath, before);
});

test("one blocked lesson group aborts all groups", () => {
  const { dir, dbPath } = fixture();
  const plan = writeLessonPlan(dir, [
    lessonGroup({ title: "GOOD", members: [UUID_B], value: "SECOND_RULE API_TIMEOUT 42", preserved: "SECOND_RULE, API_TIMEOUT, 42", deletes: [UUID_B] }),
    lessonGroup({ title: "LOST", members: [UUID_A], value: "API_TIMEOUT", preserved: "API_TIMEOUT", deletes: [UUID_A] }),
  ]);
  const before = sqliteState(dbPath);
  const result = run("apply-lessons.mjs", [plan, `--db=${dbPath}`, "--apply", "--owner-override"], skillDir);
  assert.notEqual(result.status, 0, combined(result));
  assertNoMutation(dbPath, before);
});

test("strict fact parser rejects substring/fenced/malformed/mixed/duplicate plans", () => {
  const { dir, dbPath } = fixture();
  const cases = [];
  cases.push(writeFactPlan(dir, { name: "substring.md", section: "Группы слияния фактов extra" }));
  const fenced = join(dir, "fenced.md");
  writeFileSync(fenced, `# plan\n\n\`\`\`markdown\n${readFileSync(writeFactPlan(dir, { name: "seed.md" }), "utf8")}\n\`\`\`\n`);
  cases.push(fenced);
  const malformed = writeFactPlan(dir, { name: "malformed.md" });
  writeFileSync(malformed, readFileSync(malformed, "utf8").replace(/^ЧТО СОХРАНЕНО:.*\n/mu, ""));
  cases.push(malformed);
  const mixed = writeFactPlan(dir, { name: "mixed.md" });
  writeFileSync(mixed, readFileSync(mixed, "utf8").replace("`demo.domain.keep`, `demo.domain.drop`", "`demo.domain.keep`, demo.domain.drop"));
  cases.push(mixed);
  const duplicate = writeFactPlan(dir, { name: "duplicate.md", extra: "\n### G2\nKEEP KEY: `demo.domain.keep`\nНОВОЕ ЗНАЧЕНИЕ: KEEP_TOKEN 42 и OWNER_TOKEN\nВОШЛО: `demo.domain.keep`, `demo.domain.drop`\nЧТО СОХРАНЕНО: KEEP_TOKEN, OWNER_TOKEN, 42\nУДАЛИТЬ: `demo.domain.drop`\n" });
  cases.push(duplicate);

  for (const path of cases) {
    const result = run("apply-facts.mjs", [path, `--db=${dbPath}`], skillDir);
    assert.notEqual(result.status, 0, path);
  }
});

test("strict lesson parser rejects malformed and duplicate groups", () => {
  const { dir, dbPath } = fixture();
  const malformed = writeLessonPlan(dir, [lessonGroup().replace(/^ЧТО СОХРАНЕНО:.*\n/mu, "")], "malformed-lessons.md");
  const duplicate = writeLessonPlan(dir, [lessonGroup({ title: "A" }), lessonGroup({ title: "A" })], "duplicate-lessons.md");
  for (const path of [malformed, duplicate]) {
    const result = run("apply-lessons.mjs", [path, `--db=${dbPath}`], skillDir);
    assert.notEqual(result.status, 0, path);
  }
});

test("owner guard is repeated after BEGIN IMMEDIATE and cannot race", async () => {
  const { dir, dbPath } = fixture();
  const plan = writeFactPlan(dir, {
    keep: "cons.fact",
    value: "CONS_TOKEN 9 и KEEP_TOKEN 42: кратко",
    members: ["cons.fact", "demo.domain.keep"],
    preserved: "CONS_TOKEN, 9, KEEP_TOKEN, 42",
    deletes: ["demo.domain.keep"],
  });
  // Make the delete valid but non-owner in the snapshot; turn KEEP into owner while apply waits.
  const writer = new DatabaseSync(dbPath, { timeout: 5000 });
  writer.exec("BEGIN IMMEDIATE");
  writer.prepare("UPDATE semantic SET source='user' WHERE key='cons.fact'").run();
  const pending = runAsync("apply-facts.mjs", [plan, `--db=${dbPath}`, "--apply"], skillDir);
  await delay(350);
  writer.exec("COMMIT");
  writer.close();
  const result = await pending.result;
  assert.notEqual(result.status, 0, combined(result));
  assert.match(combined(result), /owner-override|устарел/iu);
  const db = openReadOnly(dbPath);
  assert.ok(db.prepare("SELECT 1 FROM semantic WHERE key='demo.domain.keep'").get());
  db.close();
});

test("plan changed while apply waits is stale and aborts", async () => {
  const { dir, dbPath } = fixture();
  const plan = writeFactPlan(dir);
  const writer = new DatabaseSync(dbPath, { timeout: 5000 });
  writer.exec("BEGIN IMMEDIATE");
  const pending = runAsync("apply-facts.mjs", [plan, `--db=${dbPath}`, "--apply", "--owner-override"], skillDir);
  await delay(350);
  writeFileSync(plan, readFileSync(plan, "utf8").replace("KEEP_TOKEN 42 и OWNER_TOKEN", "KEEP_TOKEN 42 и OWNER_TOKEN CHANGED_TOKEN"));
  writer.exec("COMMIT");
  writer.close();
  const result = await pending.result;
  assert.notEqual(result.status, 0, combined(result));
  assert.match(combined(result), /план.*измен|устарел/iu);
  const db = openReadOnly(dbPath);
  assert.ok(db.prepare("SELECT 1 FROM semantic WHERE key='demo.domain.drop'").get());
  db.close();
});

test("lesson metadata change while patch waits is stale and aborts", async () => {
  const { dir, dbPath } = fixture();
  const manifest = join(dir, "lesson-patch.json");
  writeFileSync(manifest, JSON.stringify({ lessons: { [UUID_B]: "SECOND_RULE API_TIMEOUT 42" } }));
  const writer = new DatabaseSync(dbPath, { timeout: 5000 });
  writer.exec("BEGIN IMMEDIATE");
  writer.prepare("UPDATE lessons SET project='changed',category='changed',negative=1 WHERE id=?").run(UUID_B);
  const pending = runAsync("patch-entries.mjs", [manifest, `--db=${dbPath}`, "--apply"], skillDir);
  await delay(350);
  writer.exec("COMMIT");
  writer.close();
  const result = await pending.result;
  assert.notEqual(result.status, 0, combined(result));
  assert.match(combined(result), /устарел/iu);
  const db = openReadOnly(dbPath);
  const row = db.prepare("SELECT rule,project,category,negative FROM lessons WHERE id=?").get(UUID_B);
  assert.equal(row.rule, "SECOND_RULE API_TIMEOUT 42 detailed wording");
  assert.deepEqual({ project: row.project, category: row.category, negative: row.negative }, { project: "changed", category: "changed", negative: 1 });
  db.close();
});

test("inject-probe includes all leaf values in conservative estimate", () => {
  const dir = mkdtempSync(join(tmpdir(), "memory-ops-leaf-"));
  const dbPath = join(dir, "memory.db");
  const db = new DatabaseSync(dbPath);
  db.exec("CREATE TABLE semantic (key TEXT PRIMARY KEY,value TEXT NOT NULL); CREATE TABLE lessons (id TEXT PRIMARY KEY,rule TEXT NOT NULL,project TEXT,is_deleted INTEGER,created_at TEXT);");
  db.prepare("INSERT INTO semantic (key,value) VALUES (?,?)").run("leaf.fact", "x".repeat(12000));
  db.close();
  const before = sqliteState(dbPath);
  const result = run("inject-probe.mjs", [`--db=${dbPath}`, "--estimate"], skillDir);
  assert.equal(result.status, 0, combined(result));
  const match = combined(result).match(/символов ~(\d+)/u);
  assert.ok(match, combined(result));
  assert.ok(Number(match[1]) >= 12000, combined(result));
  assert.match(combined(result), /reachability не моделируется/iu);
  assertNoMutation(dbPath, before);
});

test("inject-probe rejects plugin execution and redacts inputs", () => {
  const { dir, dbPath, db } = fixture({ wal: true });
  const plugin = join(dir, "untrusted-plugin.mjs");
  const secretPrompt = "PROMPT_SECRET_9f91";
  const cases = join(dir, "cases.json");
  writeFileSync(plugin, "throw new Error('must never execute');\n");
  writeFileSync(cases, JSON.stringify([{ cwd: dir, prompt: secretPrompt }]));
  const before = sqliteState(dbPath);
  const rejected = run("inject-probe.mjs", [`--db=${dbPath}`, `--plugin=${plugin}`, `--cases=${cases}`], skillDir);
  assert.notEqual(rejected.status, 0, combined(rejected));
  assertNoMutation(dbPath, before);
  const estimated = run("inject-probe.mjs", [`--db=${dbPath}`, `--cases=${cases}`, "--estimate"], skillDir);
  assert.equal(estimated.status, 0, combined(estimated));
  assertNoMutation(dbPath, before);
  for (const forbidden of [dbPath, dir, plugin, cases, secretPrompt, "KEEP_TOKEN", "OWNER_TOKEN"]) {
    assert.equal(combined(rejected).includes(forbidden), false, `rejected output leaked: ${forbidden}`);
    assert.equal(combined(estimated).includes(forbidden), false, `estimate output leaked: ${forbidden}`);
  }
  db.close();
});

test("CLI diagnostics redact input paths, protected tokens, and record identifiers", () => {
  const { dir, dbPath } = fixture();
  const plan = writeFactPlan(dir, { value: "KEEP_TOKEN", preserved: "KEEP_TOKEN" });
  const result = run("apply-facts.mjs", [plan, `--db=${dbPath}`], skillDir);
  assert.notEqual(result.status, 0);
  for (const forbidden of [dir, dbPath, plan, "KEEP_TOKEN", "OWNER_TOKEN", "demo.domain.keep", "demo.domain.drop"]) {
    assert.equal(combined(result).includes(forbidden), false, `leaked: ${forbidden}`);
  }
});

test("public skill hygiene scans every file and contains every local link", () => {
  const files = [];
  function walk(dir) {
    for (const name of readdirSync(dir)) {
      const path = join(dir, name);
      const stat = lstatSync(path);
      assert.equal(stat.isSymbolicLink(), false, `symlink not allowed: ${path}`);
      if (stat.isDirectory()) walk(path);
      else files.push(path);
    }
  }
  walk(skillDir);
  for (const path of files) {
    const bytes = readFileSync(path);
    const text = bytes.toString("utf8");
    assert.equal(Buffer.from(text, "utf8").equals(bytes), true, `non-UTF8/binary file: ${path}`);
    assert.doesNotMatch(text, /(?:C:[\\/](?:Users|PY)[\\/]|\\Users\\|\/home\/[A-Za-z0-9._-]+\/|\/Users\/[A-Za-z0-9._-]+\/)/iu, path);
    assert.doesNotMatch(text, /(?:sk-[A-Za-z0-9]{12,}|ghp_[A-Za-z0-9]{12,}|api[_-]?key\s*[:=]\s*["']?[^<\s]{8,}|password\s*[:=]\s*["']?[^<\s]{8,})/iu, path);
    if (path.endsWith(".md")) {
      for (const match of text.matchAll(/\[[^\]]*\]\(([^)]+)\)/gu)) {
        const target = match[1].split("#")[0];
        if (!target || /^(?:https?:|mailto:)/u.test(target)) continue;
        const resolved = resolve(dirname(path), decodeURIComponent(target));
        assert.ok(existsSync(resolved), `${path}: missing ${target}`);
        const rel = relative(skillDir, resolved);
        assert.equal(rel.startsWith("..") || resolve(skillDir, rel) !== resolved, false, `${path}: link escapes skill: ${target}`);
      }
    }
  }
  assert.equal(existsSync(join(skillDir, "journal", "work-log.md")), false);
  assert.equal(existsSync(join(skillDir, "journal", "defect-log.md")), false);
  for (const name of readdirSync(join(skillDir, "reports"))) {
    const text = readFileSync(join(skillDir, "reports", name), "utf8");
    assert.match(text, /СИНТЕТИЧЕСКИЙ ПРИМЕР/u, name);
  }
});
