// apply-facts.mjs — применитель раздела "Группы слияния фактов" файла-плана.
// Значения НЕ проходят через контекст агента: план парсится здесь.
// Порядок безопасный: сначала upsert слитого значения, затем удаление поглощённых.
// 💀-группы пропускаются (их удаление — отдельное решение владельца).
//   node apply-facts.mjs <plan.md> [--apply] [--prefix=pref.] [--section="Группы слияния фактов"] [--db=<path>]
import { DatabaseSync } from "node:sqlite";
import { readFileSync, writeFileSync } from "node:fs";
import os from "node:os";

const argv = process.argv.slice(2);
const planPath = argv.find(a => !a.startsWith("--"));
const APPLY = argv.includes("--apply");
const opt = (n, d) => (argv.find(a => a.startsWith("--" + n + "=")) || "").split("=").slice(1).join("=") || d;
const prefix = opt("prefix", "");
const sectionArg = opt("section", "Группы слияния фактов");
const home = os.homedir().replaceAll("\\", "/");
const DB = opt("db", process.env.PI_MEMORY_DB || home + "/.pi/memory/memory.db");

const raw = readFileSync(planPath, "utf8").replace(/\r\n/g, "\n");
const s0 = raw.indexOf("## " + sectionArg);
if (s0 < 0) { console.error("SECTION NOT FOUND:", sectionArg); process.exit(2); }
const tail = raw.slice(s0 + 3);
const h2 = tail.indexOf("\n## ");
const section = h2 >= 0 ? tail.slice(0, h2) : tail;

const keysOf = (s) => {
  const bt = [...s.matchAll(/`([^`]+)`/g)].map(m => m[1]);
  return bt.length ? bt : [...s.matchAll(/[A-Za-z0-9_\-]+(?:\.[A-Za-z0-9_\-]+)+/g)].map(m => m[0]);
};
const db = new DatabaseSync(DB);
const groups = [], problems = [], skipped = [];
for (const b of section.split(/\n### /).slice(1)) {
  const title = b.split("\n")[0].trim();
  if (/💀/.test(title)) { skipped.push(title); continue; }
  const keepM = b.match(/KEEP KEY:\s*`([^`]+)`/) || b.match(/KEEP KEY:\s*([A-Za-z0-9_.\-]+)/);
  if (!keepM) {
    if (/НОВОЕ|ВОШЛО/.test(b)) problems.push("нераспознанный блок (диалект формата?): " + title);
    continue;
  }
  const keep = keepM[1];
  const lines = b.split("\n");
  const grab = (label) => {
    const i = lines.findIndex(l => l.trimStart().startsWith(label));
    if (i < 0) return "";
    const out = [lines[i]];
    for (let j = i + 1; j < lines.length; j++) {
      const t = lines[j].trimStart();
      if (/^(KEEP KEY|НОВОЕ ЗНАЧЕНИЕ|ВОШЛО|ЧТО СОХРАНЕНО|УДАЛИТЬ|ИЗ ЧЕГО ВЗЯТО|###|##|# )/.test(t)) break;
      out.push(lines[j]);
    }
    return out.join("\n");
  };
  const valLine = lines.find(l => l.trimStart().startsWith("НОВОЕ ЗНАЧЕНИЕ"));
  if (!valLine) { problems.push("нет значения: " + title); continue; }
  const value = valLine.slice(valLine.indexOf(": ") + 2).trim();
  const members = keysOf(grab("ВОШЛО"));
  const explicit = keysOf(grab("УДАЛИТЬ"));
  const deletes = [...new Set([...members, ...explicit])].filter(k => k !== keep);
  if (!value) problems.push("пустое значение: " + keep);
  if (value.length > 2000) problems.push("слишком длинное значение: " + keep);
  const keepRow = db.prepare("select source from semantic where key=?").get(keep);
  if (keepRow && keepRow.source === "user") problems.push("KEEP KEY source=user — перепись только ручным путём владельца: " + keep);
  if (prefix && !keep.startsWith(prefix)) problems.push("KEEP вне префикса: " + keep);
  for (const d of deletes) {
    if (prefix && !d.startsWith(prefix)) problems.push("удаление вне префикса: " + d);
    const dRow = db.prepare("select source from semantic where key=?").get(d);
    if (!dRow) problems.push("нет ключа для удаления: " + d);
    else if (dRow.source === "user") problems.push("USER-ключ нельзя поглощать/удалять скриптом: " + d);
  }
  groups.push({ title, keep, value, deletes });
}
const allKeeps = new Set(groups.map(g => g.keep));
const allDels = new Set(groups.flatMap(g => g.deletes));
if ([...allKeeps].some(k => groups.some(g => g.deletes.includes(k)))) problems.push("KEEP удаляется другой группой");
const before = db.prepare("select count(*) c, sum(length(value)) s from semantic").get();
const newKeeps = [...allKeeps].filter(k => !db.prepare("select 1 from semantic where key=?").get(k));
const unaddressed = db.prepare("select key, source, length(value) l from semantic where key like ? order by key")
  .all(prefix + "%").filter(r => !allKeeps.has(r.key) && !allDels.has(r.key));
console.log("план:", planPath, "| групп:", groups.length, "| удалений:", allDels.size, "| новых значений:", groups.reduce((a, g) => a + g.value.length, 0), "симв.");
console.log("БД до:", before.c, "/", before.s, "симв. | новые KEEP-ключи:", newKeeps.length, "| 💀-группы пропущены:", skipped.length);
console.log("не затронуто (", unaddressed.length, "):", unaddressed.map(r => r.key + "[" + r.source + "]").join(", ").slice(0, 400));
console.log("проблемы:", problems.length ? problems : "нет");
if (!APPLY) { writeFileSync(planPath.replace(/\.md$/, "") + ".manifest.json", JSON.stringify({ plan: planPath, groups }, null, 1)); console.log("DRY-RUN."); process.exit(problems.length ? 3 : 0); }
if (problems.length) { console.error("ОТКАЗ."); process.exit(3); }
db.exec("BEGIN IMMEDIATE");
try {
  const up = db.prepare("insert into semantic (key,value,confidence,source,created_at,updated_at) values (?,?,0.95,'consolidation',datetime('now'),datetime('now')) on conflict(key) do update set value=excluded.value, updated_at=datetime('now'), last_accessed=null");
  const del = db.prepare("delete from semantic where key=?");
  for (const g of groups) { up.run(g.keep, g.value); for (const d of g.deletes) del.run(d); }
  const bad = groups.filter(g => !db.prepare("select 1 from semantic where key=?").get(g.keep));
  if (bad.length) throw new Error("upsert не подтверждён: " + bad.map(g => g.keep).join(","));
  db.exec("COMMIT");
} catch (e) { db.exec("ROLLBACK"); console.error("ОШИБКА, откат:", e.message); process.exit(4); }
const after = db.prepare("select count(*) c, sum(length(value)) s from semantic").get();
console.log("ПРИМЕНЕНО. БД:", after.c, "/", after.s, "симв.");
