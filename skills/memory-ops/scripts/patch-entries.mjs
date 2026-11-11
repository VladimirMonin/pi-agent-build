// patch-entries.mjs — точечные правки по JSON-манифесту:
//   { "renames": {old: new}, "facts": {key: newValue}, "lessons": {id: newRule} }
//
// Уроки правятся НА МЕСТЕ (id, project, source, negative сохраняются) — это
// предпочтительнее схемы "forget + add", которая теряет project-скоуп: новый
// урок получил бы project текущего cwd и перестал попадать в свою выборку.
// Переименование ключа факта сохраняет саму строку (и её эмбеддинг); FTS
// обновляют триггеры. Все проверки — до записи, запись — в транзакции.
//
//   node patch-entries.mjs data.json [--apply] [--db=<path>]
import { DatabaseSync } from "node:sqlite";
import { readFileSync } from "node:fs";
import os from "node:os";

const argv = process.argv.slice(2);
const dataPath = argv.find(a => !a.startsWith("--"));
const APPLY = argv.includes("--apply");
const home = os.homedir().replaceAll("\\", "/");
const DB = (argv.find(a => a.startsWith("--db=")) || "").split("=")[1] || process.env.PI_MEMORY_DB || home + "/.pi/memory/memory.db";
const data = JSON.parse(readFileSync(dataPath, "utf8"));
const db = new DatabaseSync(DB);
const problems = [];
let savedFact = 0, savedLesson = 0;

for (const [k, v] of Object.entries(data.facts || {})) {
  const row = db.prepare("select value from semantic where key=?").get(k);
  if (!row) problems.push("нет факта: " + k);
  else if (v.length >= row.value.length) problems.push("не короче исходного: " + k);
  else savedFact += row.value.length - v.length;
}
for (const [o, n] of Object.entries(data.renames || {})) {
  if (!db.prepare("select 1 from semantic where key=?").get(o)) problems.push("нет ключа: " + o);
  if (db.prepare("select 1 from semantic where key=?").get(n)) problems.push("целевой ключ занят: " + n);
}
for (const [id, rule] of Object.entries(data.lessons || {})) {
  const row = db.prepare("select rule, project, source, negative, is_deleted from lessons where id=?").get(id);
  if (!row) problems.push("нет урока: " + id);
  else if (row.is_deleted) problems.push("урок уже удалён: " + id);
  else if (rule.length >= row.rule.length) problems.push("не короче исходного: " + id);
  else savedLesson += row.rule.length - rule.length;
}

console.log("правок: фактов", Object.keys(data.facts || {}).length, "(−" + savedFact + " симв.)",
  "· переименований", Object.keys(data.renames || {}).length,
  "· уроков", Object.keys(data.lessons || {}).length, "(−" + savedLesson + " симв.)");
console.log("проблемы:", problems.length ? problems : "нет");
if (!APPLY) { console.log("DRY-RUN. Запусти с --apply."); process.exit(problems.length ? 3 : 0); }
if (problems.length) { console.error("ОТКАЗ: сначала устрани проблемы."); process.exit(3); }

db.exec("BEGIN IMMEDIATE");
try {
  const sv = db.prepare("update semantic set value=?, updated_at=datetime('now') where key=?");
  const rk = db.prepare("update semantic set key=? where key=?");
  const sr = db.prepare("update lessons set rule=? where id=?");
  for (const [k, v] of Object.entries(data.facts || {})) sv.run(v, k);
  for (const [o, n] of Object.entries(data.renames || {})) rk.run(n, o);
  for (const [i, r] of Object.entries(data.lessons || {})) sr.run(r, i);
  db.exec("COMMIT");
} catch (e) { db.exec("ROLLBACK"); console.error("ОШИБКА, откат:", e.message); process.exit(4); }
console.log("ПРИМЕНЕНО.");
