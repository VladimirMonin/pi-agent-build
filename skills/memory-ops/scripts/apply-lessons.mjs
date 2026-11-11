// apply-lessons.mjs — применитель плана слияния УРОКОВ (раздел "Слияние уроков"
// файла-плана memory-ops, блоки ### LR<n>).
//
// Отличие от слияния фактов: уроки переписываются через НОВУЮ строку с новым id
// (потому что memory_remember дедуплицирует по Jaccard >= 0.7), а старые id
// удаляются. Здесь это делается прямой записью в БД без дедупликации, зато
// с ЯВНЫМ сохранением project-скоупа: новый урок наследует project большинства
// поглощённых записей. Иначе слияние потеряло бы достижимость (инжектор фильтрует
// уроки по project = слаг cwd).
//
// Обязательная проверка: сохранность ТОКЕНОВ (идентификаторы, числа, пути,
// строки в backticks) — объединение токенов поглощённых текстов должно
// присутствовать в слитом тексте. Группа ниже порога по умолчанию НЕ применяется.
//
// node apply-lessons.mjs <plan.md> [--apply] [--min-coverage=0.9] [--db=<path>]
import { DatabaseSync } from "node:sqlite";
import { readFileSync } from "node:fs";
import { randomUUID } from "node:crypto";
import os from "node:os";

const argv = process.argv.slice(2);
const planPath = argv.find(a => !a.startsWith("--"));
const APPLY = argv.includes("--apply");
const MIN_COV = Number((argv.find(a => a.startsWith("--min-coverage=")) || "").split("=")[1] || 0.9);
const home = os.homedir().replaceAll("\\", "/");
const DB = (argv.find(a => a.startsWith("--db=")) || "").split("=")[1] || process.env.PI_MEMORY_DB || home + "/.pi/memory/memory.db";
const sectionArg = (argv.find(a => a.startsWith("--section=")) || "").split("=")[1] || "Слияние уроков";

const raw = readFileSync(planPath, "utf8").replace(/\r\n/g, "\n");
const start = raw.indexOf("## " + sectionArg);
if (start < 0) { console.error("SECTION NOT FOUND:", sectionArg); process.exit(2); }
const tail = raw.slice(start + 3);
const nextH2 = tail.indexOf("\n## ");
const section = nextH2 >= 0 ? tail.slice(0, nextH2) : tail;

const STOP = new Set(["the", "and", "with", "that", "this", "from", "must", "only", "when", "then", "each", "never", "always", "into", "than", "same", "over", "after", "before", "because", "which", "while", "without", "their", "there", "them", "they", "does", "doesn", "have", "must", "should", "would", "could"]);
function tokens(s) {
  const out = new Set();
  for (const m of s.matchAll(/`[^`]+`/g)) out.add(m[0].toLowerCase());
  for (const m of s.matchAll(/[A-Za-z]:[\\/][^\s,;)]+/g)) out.add(m[0].toLowerCase());
  for (const m of s.matchAll(/\b\d+(?:[._]\d+)*\b/g)) out.add(m[0]);
  for (const m of s.matchAll(/\b[A-Za-z][A-Za-z0-9]*(?:_[A-Za-z0-9]+)+\b/g)) out.add(m[0].toLowerCase()); // snake_case
  for (const m of s.matchAll(/\b[a-z]+[A-Z][A-Za-z0-9]*\b/g)) out.add(m[0].toLowerCase());           // camelCase
  for (const m of s.matchAll(/\b[A-Z][A-Z0-9_]{3,}\b/g)) out.add(m[0].toLowerCase());                // CONSTANTS
  for (const m of out) if (STOP.has(m)) out.delete(m);
  return out;
}

const db = new DatabaseSync(DB);
const getLesson = db.prepare("select id, rule, category, negative, project, is_deleted, source from lessons where id=?");
const blocks = section.split(/\n### /).slice(1);
const groups = [];
const problems = [];
const notes = [];

for (const b of blocks) {
  const title = b.split("\n")[0].trim();
  const lines = b.split("\n");
  const grab = (label) => {
    const i = lines.findIndex(l => l.trimStart().startsWith(label));
    if (i < 0) return "";
    const out = [lines[i]];
    for (let j = i + 1; j < lines.length; j++) {
      const t = lines[j].trimStart();
      if (/^(ГОТОВЫЙ ТЕКСТ|ТИП:|ПРОЕКТ:|ВОШЛО|ПОКРЫВАЕТ|ЧТО СОХРАНЕНО|УДАЛИТЬ|###|##|# )/.test(t)) break;
      out.push(lines[j]);
    }
    return out.join("\n");
  };
  const ruleLine = lines.find(l => l.trimStart().startsWith("ГОТОВЫЙ ТЕКСТ УРОКА"));
  if (!ruleLine) {
    if (/УРОК|ВОШЛО/.test(b) && !/💀/.test(title)) problems.push("нераспознанный блок урока (диалект формата?): " + title);
    continue;
  }
  const rule = ruleLine.slice(ruleLine.indexOf(": ") + 2).trim();
  const typeLine = lines.find(l => l.trimStart().startsWith("ТИП:")) || "";
  const projLine = lines.find(l => l.trimStart().startsWith("ПРОЕКТ:")) || "";
  const negative = /negative=1/.test(typeLine + projLine) ? 1 : 0;
  const catM = (typeLine + " · " + projLine).match(/КАТЕГОРИЯ:\s*([A-Za-z0-9_\-]+)/);
  const category = catM ? catM[1] : "general";
  const rawProj = projLine ? projLine.slice(projLine.indexOf(":") + 1).split("·")[0].trim() : "";
  const hasProj = !!projLine;
  const projVal = /^null\b/i.test(rawProj) ? null : (rawProj || null);

  const covLine = grab("ПОКРЫВАЕТ") || grab("ВОШЛО");
  const uuid = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/g;
  const idsAll = [...covLine.matchAll(uuid)].map(m => m[0]);
  const delIdx = covLine.indexOf("УДАЛИТЬ id:");
  const covered = delIdx >= 0 ? [...covLine.slice(0, delIdx).matchAll(uuid)].map(m => m[0]) : idsAll;
  let deletes = delIdx >= 0 ? [...covLine.slice(delIdx).matchAll(uuid)].map(m => m[0]) : covered;
  if (!covered.length) { problems.push("нет покрытых id: " + title); continue; }

  const rowsAll = covered.map(id => getLesson.get(id));
  const skippedIds = covered.filter((id, i) => !rowsAll[i] || rowsAll[i].is_deleted);
  const rows = rowsAll.filter(r => r && !r.is_deleted);
  for (const r of rows) if (r.source === "user") problems.push("USER-урок нельзя поглощать скриптом (ручной путь владельца): " + r.id);
  const liveCovered = covered.filter((id, i) => rowsAll[i] && !rowsAll[i].is_deleted);
  if (skippedIds.length) notes.push(title + ": уже удалён/нет " + skippedIds.length + " id, пропущены");
  if (!rows.length) { notes.push(title + ": не осталось живых записей, группа пропущена"); continue; }
  if (!deletes.length) deletes = covered;

  // Проверка токенов: объединение «субстанции» поглощённых текстов против слитого.
  const union = new Set();
  for (const r of rows) if (r) for (const t of tokens(r.rule)) union.add(t);
  const merged = rule.toLowerCase();
  const lost = [...union].filter(t => !merged.includes(t));
  const cov = union.size ? (union.size - lost.length) / union.size : 1;
  const projects = new Map();
  for (const r of rows) if (r) projects.set(r.project, (projects.get(r.project) || 0) + 1);
  const project = hasProj ? projVal : ([...projects.entries()].sort((a, b) => b[1] - a[1])[0]?.[0] ?? null);

  groups.push({ title, rule, negative, category, project, covered: liveCovered, deletes: deletes.filter(d => liveCovered.includes(d)), coverage: cov, union: union.size, lost, chars: rule.length });
}

let delTotal = 0, addChars = 0, oldChars = 0, ok = 0, below = 0, noMetric = 0;
const blocking = (g) => g.union >= 3 && g.coverage < MIN_COV;
for (const g of groups) {
  delTotal += g.deletes.length;
  addChars += g.chars;
  if (g.union < 3) noMetric++; else if (blocking(g)) below++; else ok++;
  for (const id of g.covered) {
    const r = getLesson.get(id);
    if (r) oldChars += r.rule.length;
  }
}
const before = db.prepare("select count(*) c, sum(length(rule)) s from lessons where is_deleted=0").get();
console.log("plan:", planPath, "| групп:", groups.length);
console.log("БД до: уроков", before.c, "/", before.s, "симв.");
console.log("будет: добавлено", groups.length, "уроков (" + addChars + " симв.), удалено", delTotal, "id (поглощено " + oldChars + " симв.)");
console.log("по проверке токенов: чистых", ok, "· заблокировано", below, "· метрика неприменима (мало токенов)", noMetric, "(порог", MIN_COV + ")");
console.log("по проектам:", JSON.stringify(groups.reduce((m, g) => (m[g.project || "NULL"] = (m[g.project || "NULL"] || 0) + 1, m), {})));
for (const g of groups.filter(g => g.union >= 3 && g.lost.length)) {
  console.log("  ⚠", g.title, "покрытие", g.coverage.toFixed(2), "потеряно:", g.lost.slice(0, 8).join(", "), g.lost.length > 8 ? "…" : "");
}
console.log("проблемы:", problems.length ? problems : "нет");
if (notes.length) console.log("примечания:", notes);

if (!APPLY) { console.log("DRY-RUN. Запусти с --apply."); process.exit(problems.length ? 3 : 0); }
if (problems.length) { console.error("ОТКАЗ: сначала устрани проблемы."); process.exit(3); }

db.exec("BEGIN IMMEDIATE");
try {
  const ins = db.prepare("insert into lessons (id, rule, category, source, negative, is_deleted, created_at, project) values (?,?,?,'consolidation',?,0,datetime('now'),?)");
  const del = db.prepare("update lessons set is_deleted=1 where id=?");
  const inserted = [];
  for (const g of groups) {
    if (blocking(g)) continue; // fail-closed: непроверенная группа не применяется
    const newId = randomUUID();
    ins.run(newId, g.rule, g.category, g.negative, g.project);
    inserted.push(newId);
    for (const did of g.deletes) del.run(did);
  }
  // Самопроверка внутри транзакции: каждая вставка обязана существовать.
  // Иначе серия удалений прошла бы без замен (именно этот класс ошибок уже случался).
  const check = db.prepare("select 1 from lessons where id=? and is_deleted=0");
  const missing = inserted.filter(id => !check.get(id));
  if (missing.length) throw new Error("вставка не подтверждена: " + missing.join(","));
  db.exec("COMMIT");
} catch (e) { db.exec("ROLLBACK"); console.error("ОШИБКА, откат:", e.message); process.exit(4); }

const after = db.prepare("select count(*) c, sum(length(rule)) s from lessons where is_deleted=0").get();
if (after.c < 1) { console.error("ПОДОЗРИТЕЛЬНО: не осталось живых уроков"); process.exit(5); }
console.log("ПРИМЕНЕНО. уроков", after.c, "/", after.s, "симв.");
