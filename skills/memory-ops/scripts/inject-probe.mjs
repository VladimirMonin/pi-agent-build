// inject-probe.mjs — измерение РЕАЛЬНОГО инжектируемого блока памяти.
//
// Зачем: любой бюджетный вывод по дампу БД — это оценка. Настоящий блок
// собирает плагин: у него есть свои предикаты (FTS + семантика + co-expansion
// для фактов; project = слаг cwd для уроков) и свой потолок символов.
// Единственный способ узнать, что доедет до модели, — вызвать сборщик.
//
//   node inject-probe.mjs --db=<COPY>           # ОБЯЗАТЕЛЬНО: только копия базы
//   node inject-probe.mjs --db=<COPY> --estimate # без импорта плагина (SQL-модель)
//   node inject-probe.mjs --db=<COPY> --cases=cases.json    # [{cwd, prompt}, ...]
//   node inject-probe.mjs --db=<COPY> --lesson-injection=all|selective  # override
//   node inject-probe.mjs --db=<COPY> --settings=<settings.json>  # профиль
//   node inject-probe.mjs --db=<COPY> --bundle=<dist/index.js>    # сборщик
//
// ВАЖНО: сборщик трогает last_accessed и может дописать эмбеддинги, поэтому
// запускай только по КОПИИ (scripts/db-copy.mjs). Живой memory.db запрещён
// (guard ниже). Реальная выборка зависит от профильного конфига: без
// memory.factProjectAliases факты project.* отфильтровываются и замер искажается —
// конфиг передаётся в buildContextBlock целиком.
//
// Пути портируемы: --db/--settings/--bundle > переменные окружения
// PI_MEMORY_DB / PI_CODING_AGENT_DIR / PI_MEMORY_BUNDLE > домашняя папка.
// Работает на Windows и macOS без правок.
import { DatabaseSync } from "node:sqlite";
import { readFileSync, existsSync } from "node:fs";
import os from "node:os";

const home = os.homedir().replaceAll("\\", "/");
const argv = process.argv.slice(2);
const arg = (name, dflt) => (argv.find(a => a.startsWith("--" + name + "=")) || "").split("=").slice(1).join("=") || dflt;
const LIVE_DB = (process.env.PI_MEMORY_DB || home + "/.pi/memory/memory.db").replaceAll("\\", "/");

const DB = arg("db", "");
if (!DB) throw Error('--db=<COPY> is required: the probe updates last_accessed and may backfill embeddings; copy the live store first: node scripts/db-copy.mjs "' + LIVE_DB + '" <COPY>');
if (DB.replaceAll("\\", "/").toLowerCase() === LIVE_DB.toLowerCase()) throw Error("refusing the live memory.db; pass a .backup copy via --db (scripts/db-copy.mjs)");
const ESTIMATE = argv.includes("--estimate");
const CASES_FILE = arg("cases", "");
const settingsPath = arg("settings", process.env.PI_CODING_AGENT_DIR
  ? process.env.PI_CODING_AGENT_DIR + "/settings.json"
  : home + "/.pi/agent/settings.json");
let memoryConfig = {};
try { memoryConfig = JSON.parse(readFileSync(settingsPath, "utf8")).memory ?? {}; } catch { /* plugin default */ }
const configuredMode = memoryConfig.lessonInjection ?? "all";
const LESSON_MODE = arg("lesson-injection", configuredMode);
if (!["all", "selective"].includes(LESSON_MODE)) throw Error("lesson-injection must be all or selective");

const homeWin = home.replace(/\//g, "\\");
const DEFAULT_CASES = [
  { cwd: home, prompt: "какие у меня предпочтения по работе" },
  { cwd: home, prompt: "продолжи работу над задачей" },
  { cwd: home + "/projects/example/worktrees/feature-x", prompt: "продолжи работу над задачей" },
  { cwd: homeWin + "\\projects\\example\\worktrees\\feature-x", prompt: "продолжи работу над задачей" },
];
const cases = CASES_FILE ? JSON.parse(readFileSync(CASES_FILE, "utf8")) : DEFAULT_CASES;

// ── SQL-модель предикатов (fallback и --estimate) ──────────────────────────
// Факты: FTS/семантические попадания + co-expansion соседей по ПЕРВЫМ ДВУМ
// сегментам — но только для ключей с 3+ сегментами (2-сегментные листовые).
// Уроки: project = слаг(cwd) ИЛИ project IS NULL, ORDER BY created_at DESC
// LIMIT 50. Слаг = последний сегмент пути ПОСЛЕ split("/") — поэтому Windows-путь
// с обратными слэшами даёт слагом весь путь, и он совпадает с записями,
// которые консолидация сохранила полным путём.
function slug(cwd) {
  // Та же логика, что в плагине: последний сегмент, кроме служебных. Имя
  // пользователя ОС НЕ пропускается (сверено 2026-11-11: C:/Users/<user> → "user").
  const skip = new Set(["workplace", "local", "home", "src", "scratch"]);
  for (const p of cwd.split("/").filter(Boolean).reverse()) {
    if (!skip.has(p.toLowerCase()) && p.length > 1) return p.toLowerCase();
  }
  return "";
}

// Честная модель: не предсказываем попадания FTS (это невозможно), а считаем
// ДОСТУПНОСТЬ и максимальный вклад каждого источника.
function estimate(db, cwd) {
  const s = slug(cwd);
  const lessons = db.prepare(
    "select length(rule) l from lessons where is_deleted=0 and (project = ? or project is null) order by created_at desc limit 50"
  ).all(s);
  const all = db.prepare("select key, length(value) l from semantic").all();
  const expanding = new Map(), leaf = { n: 0, chars: 0 };
  for (const r of all) {
    const parts = r.key.split(".");
    if (parts.length >= 3) {
      const p = parts.slice(0, 2).join(".");
      const cur = expanding.get(p) || { n: 0, chars: 0 };
      cur.n++; cur.chars += r.l;
      expanding.set(p, cur);
    } else { leaf.n++; leaf.chars += r.l; }
  }
  const domains = [...expanding.entries()].sort((a, b) => b[1].chars - a[1].chars);
  const worst = domains.slice(0, 2).reduce((a, [, v]) => a + Math.min(v.chars, v.chars * 20 / Math.max(v.n, 1)), 0);
  const lessonChars = lessons.reduce((a, b) => a + b.l, 0) + lessons.length * 15;
  return { slug: s, lessons: lessons.length, lessonChars, domains: domains.slice(0, 5), leaf, worst, total: lessonChars + worst };
}

// ── Настоящий сборщик блока ────────────────────────────────────────────────
const DISTS = [
  arg("bundle", process.env.PI_MEMORY_BUNDLE || ""),
  home + "/.pi/agent/npm/node_modules/@samfp/pi-memory/dist/index.js",
  home + "/.pi/task/npm/node_modules/@samfp/pi-memory/dist/index.js",
].filter(Boolean);
const db = new DatabaseSync(DB);

if (ESTIMATE) {
  console.log("режим: расчёт доступности (не прогноз попаданий FTS и не настоящий сборщик)");
  console.log("  слаг здесь считается по правилу плагина; при расхождении с живым пробником доверяй пробнику — от слага зависит выборка уроков");
  for (const { cwd } of cases) {
    const e = estimate(db, cwd);
    console.log("- " + cwd + " | слаг: " + JSON.stringify(e.slug));
    console.log("  уроки по предикату (project=слаг OR NULL, до 50): " + e.lessons + " шт / " + e.lessonChars + " симв.");
    console.log("  расширяемые домены (3+ сегмента → co-expansion тянет соседей): " +
      (e.domains.map(([p, v]) => p + "(" + v.n + "/" + v.chars + ")").join(" ") || "нет"));
    console.log("  листовые 2-сегментные (соседей не тянут): " + e.leaf.n + " шт / " + e.leaf.chars + " симв.");
    console.log("  нижняя граница блока ~" + e.total + " симв." + (e.total > 8000 ? " → уже перебор" : " → зависит от попаданий"));
  }
  process.exit(0);
}

let mod = null, usedDist = null;
for (const p of DISTS) {
  if (!existsSync(p)) continue;
  try { mod = await import("file:///" + p); usedDist = p; break; } catch (e) {
    if (!/ERR_MODULE_NOT_FOUND/.test(String(e))) { console.error("импорт упал:", e.message); process.exit(2); }
  }
}
if (!mod) {
  console.error("не удалось импортировать сборщик (проверь --bundle / PI_MEMORY_BUNDLE).");
  console.error("Частая причина — не резолвится @sinclair/typebox; шим описан в scripts/README.md.");
  console.error("Либо запусти с --estimate (грубее, но работает всегда).");
  process.exit(2);
}

const store = new mod.MemoryStore(DB);
console.log("сборщик:", usedDist, "| база:", DB, "| уроки:", LESSON_MODE);
for (const { cwd, prompt } of cases) {
  const block = await mod.buildContextBlock(store, cwd, prompt, { ...memoryConfig, lessonInjection: LESSON_MODE });
  const text = block?.text ?? String(block ?? "");
  const lines = text.split("\n");
  const facts = lines.filter(l => /^- .+?: /.test(l));
  const donts = lines.filter(l => l.startsWith("- DON'T:"));
  console.log("-", cwd);
  console.log("  слаг:", JSON.stringify(mod.projectSlug(cwd)), "| промпт:", prompt);
  console.log("  chars:", text.length, "| truncated:", text.includes("... (truncated)"));
  console.log("  секции: строк-фактов", facts.length, "· DON'T", donts.length);
}
const total = db.prepare("select count(*) c from lessons where is_deleted=0").get().c;
console.log("активных уроков в базе:", total);
