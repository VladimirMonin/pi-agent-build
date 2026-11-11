// security.test.mjs — тестовая обвязка навыка skills/memory-ops против его
// НОВЫХ скриптов (9 шт.: apply-facts, apply-lessons, check-injector, db-copy,
// export-lanes, inject-probe, normalize-apply, patch-entries, validate-apply).
// CLI — skills/memory-ops/scripts/README.md; диалект планов —
// references/lane-contract.md + instructions/09-bulk-apply.md.
//
// КАРТА ПРОВЕРОК (сохранена / адаптирована / убрана + почему) — в отчёте:
//   ОБРАТНАЯ СВЯЗЬ/TEST-memory-ops-port.md
//
// Убранные прежние проверки — только те, чья фича удалена БЕЗ преемника;
// номера дефектов (D1…) — в отчёте:
//  - «байт-точное сохранение токенов/регистра/Unicode/знаков чисел» в
//    patch-entries и фактах: новые скрипты сверяют только длину (patch-entries)
//    либо покрытие токенов БЕЗ регистра (apply-lessons) — прежней сверки нет (D3);
//  - «дубликаты JSON-членов / групп отклоняются»: JSON.parse схлопывает
//    дубликаты молча, дубликат KEEP KEY между группами не отслеживается (D4/D6);
//  - гоночные проверки (owner-guard повторяется после BEGIN IMMEDIATE;
//    staleness плана/манифеста во время ожидания блокировки): этих защит в
//    новых скриптах нет (D7);
//  - «CLI-диагностика редактирует пути/токены/идентификаторы»: новый CLI
//    печатает пути, ключи и uuid по дизайну (контракт редактирования удалён);
//  - «inject-probe отклоняет исполнение плагина (--plugin)»: --plugin удалён,
//    вызов сборщика (--bundle) теперь НАЗНАЧЕНИЕ пробника (см. тест T2);
//  - «--owner-override существует», «embedding очищается», «журналов нет»,
//    «reports содержат СИНТЕТИЧЕСКИЙ ПРИМЕР» — см. комментарии у местных тестов.
//
// ОХРАННЫЕ проверки сохранены полностью: запрет симлинков, UTF-8, запрет
// секретов, целостность markdown-ссылок — по ВСЕМУ навыку, включая journal/.
// Единственное послабление — запрет машинных путей ограничен каталогом
// journal/ (обоснование — в последнем тесте). Фикстуры — временные каталоги
// os.tmpdir(); skills/** не изменяется.
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
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
import { DatabaseSync } from "node:sqlite";
import test from "node:test";

const skillDir = resolve(import.meta.dirname, "../../skills/memory-ops");
const scriptsDir = join(skillDir, "scripts");
const UUID_A = "11111111-1111-4111-8111-111111111111"; // source=user — неприкосновенен
const UUID_B = "22222222-2222-4222-8222-222222222222";
const UUID_C = "33333333-3333-4333-8333-333333333333";
const UUID_D = "44444444-4444-4444-8444-444444444444";
const UUID_MISSING = "99999999-9999-4999-8999-999999999999";
// Слитый текст урока, покрывающий ВСЕ токены B и C (7 токенов, покрытие 1.0).
const MERGED_BC = "SECOND_RULE и PICKLE_TIMEOUT 7: API_TIMEOUT 42, alpha_token beta_flag";

function run(script, args = [], cwd = skillDir, env = process.env) {
  return spawnSync(process.execPath, [join(scriptsDir, script), ...args], {
    cwd,
    env,
    encoding: "utf8",
  });
}

function hash(path) {
  return createHash("sha256").update(readFileSync(path)).digest("hex");
}

function fileState(path) {
  return existsSync(path) ? { size: statSync(path).size, hash: hash(path) } : null;
}

// Состояние SQLite-снапшота: db и -wal сравниваются побайтово; -shm — нет.
// -shm это общий wal-index (read marks читателей): проверено, что его байты
// переписываются при ЛЮБОМ открытии соединения — даже readOnly open/close без
// запуска скриптов, — поэтому для него сравниваем существование и размер.
function sqliteState(dbPath) {
  return {
    "": fileState(dbPath),
    "-wal": fileState(`${dbPath}-wal`),
    "-shm": existsSync(`${dbPath}-shm`) ? { size: statSync(`${dbPath}-shm`).size } : null,
  };
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
  lesson.run(UUID_C, "PICKLE_TIMEOUT 7: alpha_token beta_flag", "general", "consolidation", 0, "demo");
  lesson.run(UUID_D, "RELEASE_MARKER 8: gamma_path delta_case", "general", "consolidation", 0, "demo");
  if (!wal) db.close();
  return { dir, dbPath, db: wal ? db : null };
}

function writeFactPlan(dir, {
  name = "facts-plan.md",
  section = "Группы слияния фактов",
  keep = "demo.domain.keep",
  value = "KEEP_TOKEN 42 и CONS_TOKEN 9: краткий слитый текст",
  members = ["demo.domain.keep", "cons.fact"],
  preserved = "KEEP_TOKEN, CONS_TOKEN, 42, 9",
  deletes = ["cons.fact"],
  extra = "",
} = {}) {
  const path = join(dir, name);
  const quoted = (values) => values.map((item) => `\`${item}\``).join(", ");
  writeFileSync(path, `# Синтетический план\n\n## ${section}\n\n### G1\nKEEP KEY: \`${keep}\`\nНОВОЕ ЗНАЧЕНИЕ: ${value}\nВОШЛО: ${quoted(members)}\nЧТО СОХРАНЕНО: ${preserved}\nУДАЛИТЬ: ${quoted(deletes)}\n${extra}`);
  return path;
}

// Блок слияния уроков в диалекте instructions/09-bulk-apply.md (Step 3).
// `cov` — содержимое после «ВОШЛО: »; для частичного удаления применяется
// inline-маркер «УДАЛИТЬ id: <uuid>» ВНУТРИ строки ВОШЛО (единственный синтаксис,
// который разбирает apply-lessons — см. дефект D1 в отчёте).
function lessonGroup({
  title = "LR1",
  project = "demo",
  negative = 0,
  category = "general",
  value = MERGED_BC,
  cov = `${UUID_B}, ${UUID_C}`,
  preserved = "SECOND_RULE, PICKLE_TIMEOUT, API_TIMEOUT, 42, 7, alpha_token, beta_flag",
  deleteLine = `УДАЛИТЬ: ${UUID_B}, ${UUID_C}`,
} = {}) {
  return `### ${title}\nПРОЕКТ: ${project} · ТИП: negative=${negative} · КАТЕГОРИЯ: ${category}\nГОТОВЫЙ ТЕКСТ УРОКА: ${value}\nВОШЛО: ${cov}\nЧТО СОХРАНЕНО: ${preserved}\n${deleteLine}\n`;
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

// ── T1: явные обязательные аргументы нового CLI ─────────────────────────────
// Старое требование «--db обязателен каждому скрипту» снято самим CLI: новые
// скрипты резолвят БД как --db → PI_MEMORY_DB → <home>/.pi/memory/memory.db.
// Адаптация: (а) скрипты, для которых аргумент остался обязательным (живая
// копия/каталог/планы), отказывают с подсказкой --db/usage; (б) мутаторы без
// входного файла падают НА ЧТЕНИИ входа — до открытия БД, т.е. дефолтная
// память пользователя не создаётся и не трогается. Прежняя половина «диагностика
// без путей машины» убрана: новый CLI печатает пути по дизайну (отчёт, D-карта).
test("T1: обязательные аргументы CLI отказывают корректно; мутаторы не доходят до БД без входа", () => {
  for (const [script, args, hint] of [
    ["inject-probe.mjs", [], /--db/],
    ["check-injector.mjs", [], /--db/],
    ["export-lanes.mjs", [], /usage/iu],
    ["validate-apply.mjs", [], /usage/iu],
    ["db-copy.mjs", [], /usage/iu],
  ]) {
    const result = run(script, args);
    assert.notEqual(result.status, 0, script);
    assert.match(combined(result), hint, script);
  }
  for (const [script, args] of [
    ["apply-facts.mjs", ["missing.md"]],
    ["apply-lessons.mjs", ["missing.md"]],
    ["patch-entries.mjs", ["missing.json"]],
  ]) {
    const result = run(script, args);
    assert.notEqual(result.status, 0, script); // ENOENT на входе — БД не открывалась
  }
});

// ── T2: guard живой БД — инжекция/регрессия только по копии ─────────────────
// Преемник убранных проверок «inject-probe отклоняет --plugin и редактирует
// ввод» (--plugin удалён; вызов сборщика — теперь назначение пробника):
// охрана «пробы только по копии» живёт в guard'е живого memory.db — проверяем.
test("T2: inject-probe и check-injector отклоняют живой memory.db", () => {
  const { dir, dbPath } = fixture();
  const env = { ...process.env, PI_MEMORY_DB: dbPath };
  for (const script of ["inject-probe.mjs", "check-injector.mjs"]) {
    const result = run(script, [`--db=${dbPath}`], skillDir, env);
    assert.notEqual(result.status, 0, script);
    assert.match(combined(result), /refusing the live/iu, script);
  }
});

// ── T3: dry-run apply-facts на WAL-снапшоте не меняет db/-wal/-shm ──────────
test("T3: dry-run apply-facts оставляет db/-wal/-shm нетронутыми (WAL-снапшот)", () => {
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

// ── T4: dry-run apply-lessons и patch-entries тоже не касаются sidecars ─────
test("T4: dry-run apply-lessons и patch-entries не касаются db/-wal/-shm", () => {
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

// ── T5: apply-facts — user-записи неприкосновенны, без обхода ──────────────
// Прежний флаг --owner-override УДАЛЁН: защита стала абсолютной (это усиление,
// не ослабление) — передача старого флага обхода не даёт. Прежняя проверка
// «embedding очищается при переписи» убрана: новые скрипты embedding не трогают
// (дефект D2 — зафиксирован в отчёте, скрипты не правились).
test("T5: apply-facts блокирует user-записи (KEEP и поглощение) даже со старым --owner-override", () => {
  const { dir, dbPath } = fixture();

  const keepPlan = writeFactPlan(dir, {
    name: "user-keep.md",
    keep: "user.fact",
    value: "USER_TOKEN 7 сжато",
    members: ["user.fact", "cons.fact"],
    preserved: "USER_TOKEN, 7",
    deletes: ["cons.fact"],
  });
  let before = sqliteState(dbPath);
  let result = run("apply-facts.mjs", [keepPlan, `--db=${dbPath}`, "--apply"], skillDir);
  assert.notEqual(result.status, 0, combined(result));
  assert.match(combined(result), /source=user/iu, combined(result));
  assertNoMutation(dbPath, before);

  const delPlan = writeFactPlan(dir, {
    name: "user-del.md",
    members: ["demo.domain.keep", "demo.domain.drop"],
    deletes: ["demo.domain.drop"],
  });
  before = sqliteState(dbPath);
  result = run("apply-facts.mjs", [delPlan, `--db=${dbPath}`, "--apply", "--owner-override"], skillDir);
  assert.notEqual(result.status, 0, combined(result));
  assert.match(combined(result), /USER-ключ/iu, combined(result));
  assertNoMutation(dbPath, before);

  const okPlan = writeFactPlan(dir);
  result = run("apply-facts.mjs", [okPlan, `--db=${dbPath}`, "--apply"], skillDir);
  assert.equal(result.status, 0, combined(result));
  const db = openReadOnly(dbPath);
  assert.equal(db.prepare("SELECT 1 FROM semantic WHERE key=?").get("cons.fact"), undefined);
  const kept = db.prepare("SELECT value,source FROM semantic WHERE key=?").get("demo.domain.keep");
  assert.equal(kept.value, "KEEP_TOKEN 42 и CONS_TOKEN 9: краткий слитый текст");
  assert.equal(kept.source, "consolidation");
  db.close();
});

// ── T6: patch-entries сохраняет идентификаторы записи ───────────────────────
// Тема «сохранение регистра/идентификаторов» адаптирована к новому CLI: урок
// правится НА МЕСТЕ (id/project/source/negative сохраняются), переименование
// сохраняет строку целиком (value + embedding). Убранные подпроверки прежнего
// теста — токены/пустые строки/очистка embedding: новый скрипт сверяет только
// длину (новое должно быть короче); пустая строка проходит, embedding не
// очищается (D3/D5/D2 — в отчёте).
test("T6: patch-entries: точечная правка сохраняет id/project/source/negative и эмбеддинг при rename", () => {
  const { dir, dbPath } = fixture();
  const path = join(dir, "valid.json");
  writeFileSync(path, JSON.stringify({
    facts: { "cons.fact": "CONS_TOKEN 9: кратко" },
    renames: { "demo.domain.keep": "demo.domain.kept" },
    lessons: { [UUID_B]: "SECOND_RULE API_TIMEOUT 42" },
  }));
  const result = run("patch-entries.mjs", [path, `--db=${dbPath}`, "--apply"], skillDir);
  assert.equal(result.status, 0, combined(result));
  const db = openReadOnly(dbPath);
  const renamed = db.prepare("SELECT value, source, embedding FROM semantic WHERE key=?").get("demo.domain.kept");
  assert.equal(renamed.value, "KEEP_TOKEN 42: подробная исходная формулировка");
  assert.equal(renamed.source, "consolidation");
  assert.equal(Buffer.from(renamed.embedding).toString("utf8"), "old-embedding");
  assert.equal(db.prepare("SELECT 1 FROM semantic WHERE key=?").get("demo.domain.keep"), undefined);
  assert.equal(db.prepare("SELECT value FROM semantic WHERE key=?").get("cons.fact").value, "CONS_TOKEN 9: кратко");
  const row = db.prepare("SELECT rule, project, source, negative, is_deleted FROM lessons WHERE id=?").get(UUID_B);
  assert.equal(row.rule, "SECOND_RULE API_TIMEOUT 42");
  assert.deepEqual(
    { project: row.project, source: row.source, negative: row.negative, is_deleted: row.is_deleted },
    { project: "demo", source: "consolidation", negative: 0, is_deleted: 0 },
  );
  db.close();
});

// ── T7: apply-lessons — потеря токенов блокирует группу (fail-closed) ───────
// Адаптация прежних «lost lesson tokens abort the whole apply даже с
// --min-coverage=0» и «one blocked lesson group aborts all groups»: новый
// контракт — ПОШТУЧНЫЙ fail-closed (непроверенная группа не применяется,
// проверенные применяются). Убранное: откат всего прогона и «--min-coverage=0
// не обходит порог» — теперь --min-coverage=0 снимает порог вовсе (D9, отчёт).
test("T7: apply-lessons: группа с потерей токенов не применяется, целая — применяется", () => {
  const { dir, dbPath } = fixture();
  const plan = writeLessonPlan(dir, [
    lessonGroup({ title: "GOOD", cov: `${UUID_B}, ${UUID_C}` }),
    lessonGroup({ title: "LOST", value: "RELEASE_MARKER 8", cov: UUID_D, preserved: "RELEASE_MARKER, 8", deleteLine: `УДАЛИТЬ: ${UUID_D}` }),
  ]);
  const result = run("apply-lessons.mjs", [plan, `--db=${dbPath}`, "--apply"], skillDir);
  assert.equal(result.status, 0, combined(result));
  const db = openReadOnly(dbPath);
  // GOOD применена: слитый урок на месте, наследует project/категорию из плана
  const merged = db.prepare("SELECT project, category, negative, source, is_deleted FROM lessons WHERE rule=?").get(MERGED_BC);
  assert.ok(merged, combined(result));
  assert.deepEqual(
    { project: merged.project, category: merged.category, negative: merged.negative, source: merged.source, is_deleted: merged.is_deleted },
    { project: "demo", category: "general", negative: 0, source: "consolidation", is_deleted: 0 },
  );
  for (const id of [UUID_B, UUID_C]) {
    assert.equal(db.prepare("SELECT is_deleted FROM lessons WHERE id=?").get(id).is_deleted, 1);
  }
  // LOST не применена (потеря gamma_path/delta_case, покрытие 0.5 < 0.9): вход цел
  assert.equal(db.prepare("SELECT is_deleted FROM lessons WHERE id=?").get(UUID_D).is_deleted, 0);
  assert.equal(db.prepare("SELECT 1 FROM lessons WHERE rule=?").get("RELEASE_MARKER 8"), undefined);
  // урок source=user не участвовал и не тронут
  assert.equal(db.prepare("SELECT is_deleted FROM lessons WHERE id=?").get(UUID_A).is_deleted, 0);
  db.close();
});

// ── T8: частичное удаление уроков — невошедший в «УДАЛИТЬ id:» вход цел ────
// ВНИМАНИЕ (дефект D1, отчёт): документированная строка «УДАЛИТЬ: <uuid>…»
// (09-bulk-apply.md) применителем УРОКОВ НЕ разбирается — grab() обрывается на
// ней, и удаляются ВСЕ id из ВОШЛО. Подмножество удаляется только inline-
// маркером «УДАЛИТЬ id: <uuid>» внутри строки ВОШЛО — он здесь и проверяется.
test("T8: apply-lessons: вход вне «УДАЛИТЬ id:» остаётся активным", () => {
  const { dir, dbPath } = fixture();
  const plan = writeLessonPlan(dir, [
    lessonGroup({ title: "PARTIAL", cov: `${UUID_B}, ${UUID_C} УДАЛИТЬ id: ${UUID_B}`, deleteLine: "" }),
  ]);
  const result = run("apply-lessons.mjs", [plan, `--db=${dbPath}`, "--apply"], skillDir);
  assert.equal(result.status, 0, combined(result));
  const db = openReadOnly(dbPath);
  assert.equal(db.prepare("SELECT is_deleted FROM lessons WHERE id=?").get(UUID_B).is_deleted, 1);
  assert.equal(db.prepare("SELECT is_deleted FROM lessons WHERE id=?").get(UUID_C).is_deleted, 0);
  assert.ok(db.prepare("SELECT 1 FROM lessons WHERE rule=?").get(MERGED_BC));
  db.close();
});

// ── T9: отказ при отсутствии/потере записей ─────────────────────────────────
// Адаптация «lost fact tokens abort» / «missing lesson aborts all groups»:
// прежней проверки потери ТОКЕНОВ фактов нет ни в одном новом скрипте (D3) —
// убрана; преемник «отказ при потере ЗАПИСЕЙ»: apply-facts не применяет ничего
// при отсутствующем ключе удаления, а validate-apply (обязательный шаг
// конвейера, 09-bulk-apply.md Шаг 5) отсекает отсутствующие uuid и двойное
// потребление одного ключа. Примечание (D8): сам apply-lessons при отсутствующем
// id делает пометку и продолжает по остатку — это зафиксировано в отчёте.
test("T9: отсутствующие/потерянные записи: apply-facts отказывает целиком, validate-apply отсекает", () => {
  const { dir, dbPath } = fixture();

  const ghost = writeFactPlan(dir, {
    name: "ghost-key.md",
    members: ["demo.domain.keep", "ghost.domain.key"],
    deletes: ["ghost.domain.key"],
  });
  let before = sqliteState(dbPath);
  let result = run("apply-facts.mjs", [ghost, `--db=${dbPath}`, "--apply"], skillDir);
  assert.notEqual(result.status, 0, combined(result));
  assert.match(combined(result), /нет ключа для удаления/iu, combined(result));
  assertNoMutation(dbPath, before);

  const ghostLesson = writeLessonPlan(dir, [
    lessonGroup({ title: "GHOST", value: "MISSING_TOKEN 5", cov: UUID_MISSING, preserved: "MISSING_TOKEN, 5", deleteLine: `УДАЛИТЬ: ${UUID_MISSING}` }),
  ], "ghost-lesson.md");
  result = run("validate-apply.mjs", [`--db=${dbPath}`, ghostLesson], skillDir);
  assert.equal(result.status, 1, combined(result));
  assert.match(combined(result), /нет урока/iu, combined(result));

  const overlap = writeFactPlan(dir, {
    name: "overlap.md",
    extra: "\n### G2\nKEEP KEY: `signed.fact`\nНОВОЕ ЗНАЧЕНИЕ: LIMIT -1 и CONS_TOKEN 9 кратко\nВОШЛО: `signed.fact`, `cons.fact`\nЧТО СОХРАНЕНО: LIMIT, CONS_TOKEN\nУДАЛИТЬ: `cons.fact`\n",
  });
  result = run("validate-apply.mjs", [`--db=${dbPath}`, overlap], skillDir);
  assert.equal(result.status, 1, combined(result));
  assert.match(combined(result), /уже в блоке/iu, combined(result));
});

// ── T10: строгий диалект — нераспознанный блок это отказ, не тихий пропуск ──
// Адаптация прежних «strict fact/lesson parser»: конкретные отказы старого
// парсера (подстрочный заголовок секции, план в ```-заборе, блок без
// «ЧТО СОХРАНЕНО», смешанные backticks, дубликаты групп) у БЕЗ преемника —
// новые парсеры принимают и такое (D4/D11, отчёт). Преемник строгости —
// «молчание запрещено» (с 1.0.0): нераспознанный блок любого диалекта —
// ошибка у обоих применителей и у валидатора; это здесь и проверяется.
test("T10: блок в чужом диалекте — отказ у apply-facts, apply-lessons и validate-apply", () => {
  const { dir, dbPath } = fixture();
  const factPlan = join(dir, "dialect-facts.md");
  writeFileSync(factPlan, "# Синтетический план\n\n## Группы слияния фактов\n\n### G1\nНОВОЕ: значение в старом диалекте\nВОШЛО: `cons.fact`\n");
  const lessonPlan = join(dir, "dialect-lessons.md");
  writeFileSync(lessonPlan, `# Синтетический план\n\n## Слияние уроков\n\n### LR1\nПРОЕКТ: demo · ТИП: negative=0 · КАТЕГОРИЯ: general\nУРОК: старый диалект\nВОШЛО: ${UUID_B}\n`);

  let result = run("apply-facts.mjs", [factPlan, `--db=${dbPath}`], skillDir);
  assert.notEqual(result.status, 0, combined(result));
  assert.match(combined(result), /нераспознанный блок/iu, combined(result));

  result = run("apply-lessons.mjs", [lessonPlan, `--db=${dbPath}`], skillDir);
  assert.notEqual(result.status, 0, combined(result));
  assert.match(combined(result), /нераспознанный блок/iu, combined(result));

  result = run("validate-apply.mjs", [`--db=${dbPath}`, factPlan, lessonPlan], skillDir);
  assert.equal(result.status, 1, combined(result));
  assert.match(combined(result), /нераспознанный блок/iu, combined(result));
});

// ── T11: транзакционное применение — одна проблема, весь прогон без правок ──
// Тема «транзакционное применение» адаптирована: все проверки — до записи,
// запись — одним прогоном; при любой проблеме не применяется НИ ОДНА правка,
// даже валидная. Убранные прежние гоночные проверки (owner-guard повторяется
// после BEGIN IMMEDIATE; staleness плана/манифеста под блокировкой) — этих
// защит в новых скриптах нет (D7, отчёт).
test("T11: одна проблема в прогоне — не применяется и валидная часть (никаких частичных правок)", () => {
  const { dir, dbPath } = fixture();

  const manifest = join(dir, "mixed.json");
  writeFileSync(manifest, JSON.stringify({
    facts: { "cons.fact": "CONS_TOKEN 9: кратко" },
    renames: { "demo.domain.keep": "demo.domain.drop" }, // цель занята
  }));
  let before = sqliteState(dbPath);
  let result = run("patch-entries.mjs", [manifest, `--db=${dbPath}`, "--apply"], skillDir);
  assert.notEqual(result.status, 0, combined(result));
  assert.match(combined(result), /целевой ключ занят/iu, combined(result));
  assertNoMutation(dbPath, before);

  const plan = writeFactPlan(dir, {
    name: "mixed.md",
    extra: "\n### G2\nKEEP KEY: `exponent.fact`\nНОВОЕ ЗНАЧЕНИЕ: EPSILON 1e-6 сжато\nВОШЛО: `exponent.fact`, `user.fact`\nЧТО СОХРАНЕНО: EPSILON\nУДАЛИТЬ: `user.fact`\n",
  });
  result = run("apply-facts.mjs", [plan, `--db=${dbPath}`, "--apply"], skillDir);
  assert.notEqual(result.status, 0, combined(result));
  assert.match(combined(result), /USER-ключ/iu, combined(result));
  assertNoMutation(dbPath, before);
});

// ── T12: inject-probe --estimate — листовые значения учтены, БД не меняется ─
// Адаптация прежней «консервативной оценки»: теперь листовые 2-сегментные
// значения считаются ОТДЕЛЬНОЙ строкой (её и проверяем). Убранное: прежняя
// формула «символов ~N» с требованием N ≥ всех листовых и фраза «reachability не
// моделируется» — заменены выводом «расчёт доступности / не прогноз попаданий
// FTS». Дефект D10 (отчёт): итоговая строка «нижняя граница блока ~N» листовые
// НЕ включает и противоречит README («не нижняя граница»).
test("T12: inject-probe --estimate консервативно считает листовые значения и не меняет БД", () => {
  const dir = mkdtempSync(join(tmpdir(), "memory-ops-leaf-"));
  const dbPath = join(dir, "memory.db");
  const db = new DatabaseSync(dbPath);
  db.exec("CREATE TABLE semantic (key TEXT PRIMARY KEY,value TEXT NOT NULL); CREATE TABLE lessons (id TEXT PRIMARY KEY,rule TEXT NOT NULL,project TEXT,is_deleted INTEGER,created_at TEXT);");
  db.prepare("INSERT INTO semantic (key,value) VALUES (?,?)").run("leaf.fact", "x".repeat(12000));
  db.close();
  const cases = join(dir, "cases.json");
  writeFileSync(cases, JSON.stringify([{ cwd: "C:/work/demo", prompt: "test" }]));
  const before = sqliteState(dbPath);
  const result = run("inject-probe.mjs", [`--db=${dbPath}`, `--cases=${cases}`, "--estimate"], skillDir);
  assert.equal(result.status, 0, combined(result));
  const leaf = combined(result).match(/листовые 2-сегментные[^:]*: \d+ шт \/ (\d+) симв/u);
  assert.ok(leaf, combined(result));
  assert.ok(Number(leaf[1]) >= 12000, combined(result));
  assert.match(combined(result), /не прогноз попаданий FTS/iu, combined(result));
  assertNoMutation(dbPath, before);
});

// ── T13: гигиена навыка ─────────────────────────────────────────────────────
// Охрана сохранена полностью: симлинки, UTF-8, секреты, целостность
// markdown-ссылок — по ВСЕМУ навыку, включая journal/.
// ЕДИНСТВЕННОЕ послабление (разрешено ТЗ): запрет МАШИННЫХ ПУТЕЙ ограничен
// каталогом journal/ — журналы это локальные логи запусков (SKILL.md,
// «Journals»: приватные, не синхронизируются и не пакуются), путь машины в них
// ожидаем по их назначению. Секреты/UTF-8/симлинки проверяются и в журналах.
// Убранные прежние проверки: «journal/*.md не существует» — журналы теперь
// постоянные файлы по SKILL.md (file map + .gitignore для runtime-артефактов);
// «reports содержат СИНТЕТИЧЕСКИЙ ПРИМЕР» — шаблоны помечены авторами как
// «пример из реальной сессии», маркер удалён (отчёт).
test("T13: гигиена навыка: без симлинков, UTF-8, без секретов, без машинных путей (кроме journal/)", () => {
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
  const inJournal = (path) => relative(skillDir, path).replaceAll("\\", "/").startsWith("journal/");
  for (const path of files) {
    const bytes = readFileSync(path);
    const text = bytes.toString("utf8");
    assert.equal(Buffer.from(text, "utf8").equals(bytes), true, `non-UTF8/binary file: ${path}`);
    // секреты — везде, включая journal/
    assert.doesNotMatch(text, /(?:sk-[A-Za-z0-9]{12,}|ghp_[A-Za-z0-9]{12,}|api[_-]?key\s*[:=]\s*["']?[^<\s]{8,}|password\s*[:=]\s*["']?[^<\s]{8,})/iu, path);
    if (!inJournal(path)) {
      assert.doesNotMatch(text, /(?:C:[\\/](?:Users|PY)[\\/]|\\Users\\|\/home\/[A-Za-z0-9._-]+\/|\/Users\/[A-Za-z0-9._-]+\/)/iu, path);
    }
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
});
