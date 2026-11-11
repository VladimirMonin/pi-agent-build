// export-lanes.mjs — READ-ONLY export of disjoint lane slices for bulk work.
// Facts are split by 2-segment key domain (leaf keys stay individually), lessons
// by project tag; groups are balanced by characters and written as one UTF-8
// file per lane. Lane helpers analyse their file only — never the database, so
// "read-only" is enforced by construction, not by promise.
//
//   node export-lanes.mjs --out=<dir> [--db=<db>] [--lanes=4] [--mode=both|facts|lessons]
import { DatabaseSync } from "node:sqlite";
import { mkdirSync, writeFileSync } from "node:fs";
import os from "node:os";

const argv = process.argv.slice(2);
const opt = (n, d) => (argv.find(a => a.startsWith("--" + n + "=")) || "").split("=").slice(1).join("=") || d;
const home = os.homedir().replaceAll("\\", "/");
const DB = opt("db", process.env.PI_MEMORY_DB || home + "/.pi/memory/memory.db");
const OUT = opt("out", "");
const N = Math.max(1, Number(opt("lanes", "4")));
const MODE = opt("mode", "both");
if (!OUT) { console.error("usage: node export-lanes.mjs --out=<dir> [--db=<db>] [--lanes=4] [--mode=both|facts|lessons]"); process.exit(2); }

const db = new DatabaseSync(DB, { readOnly: true });
mkdirSync(OUT, { recursive: true });

const factGroups = new Map();
for (const r of db.prepare("select key, value, source from semantic order by key").all()) {
  const parts = r.key.split(".");
  const g = parts.length >= 3 ? parts.slice(0, 2).join(".") : r.key;
  if (!factGroups.has(g)) factGroups.set(g, []);
  factGroups.get(g).push(r);
}
const lessonGroups = new Map();
for (const r of db.prepare("select id, rule, category, negative, project, source from lessons where is_deleted=0 order by project, created_at").all()) {
  const g = r.project ?? "NULL";
  if (!lessonGroups.has(g)) lessonGroups.set(g, []);
  lessonGroups.get(g).push(r);
}

const sizeOf = (rows, idField) => rows.reduce((a, r) => a + String(r.value ?? r.rule ?? "").length + String(r[idField] ?? "").length + 24, 0);
function pack(groups, idField) {
  const items = [...groups.entries()].map(([g, rows]) => ({ g, rows, s: sizeOf(rows, idField) })).sort((a, b) => b.s - a.s);
  const lanes = Array.from({ length: N }, () => ({ items: [], s: 0 }));
  for (const it of items) { const l = lanes.sort((a, b) => a.s - b.s)[0]; l.items.push(it); l.s += it.s; }
  return lanes;
}
const factLanes = MODE === "lessons" ? [] : pack(factGroups, "key");
const lessonLanes = MODE === "facts" ? [] : pack(lessonGroups, "id");

for (let i = 0; i < N; i++) {
  const parts = ["# Срез полки " + (i + 1) + " — только чтение; план пишется отдельным файлом (см. references/lane-contract.md)\n"];
  const tags = [];
  let chars = 0;
  if (factLanes[i]) {
    parts.push("\n## ФАКТЫ (semantic)\n");
    for (const { g, rows, s } of factLanes[i].items) {
      parts.push("\n### домен `" + g + "`\n");
      for (const r of rows) parts.push("- KEY: `" + r.key + "` [" + r.source + "]\n  " + String(r.value).replace(/\n/g, "\n  ") + "\n");
      tags.push("facts:" + g + "(" + rows.length + ")");
      chars += s;
    }
  }
  if (lessonLanes[i]) {
    parts.push("\n## УРОКИ (lessons)\n");
    for (const { g, rows, s } of lessonLanes[i].items) {
      parts.push("\n### project " + g + "\n");
      for (const r of rows) parts.push("- ID: " + r.id + " [" + r.source + "] negative=" + r.negative + " category=" + r.category + "\n  " + String(r.rule).replace(/\n/g, "\n  ") + "\n");
      tags.push("lessons:" + g + "(" + rows.length + ")");
      chars += s;
    }
  }
  const f = OUT.replace(/[\\/]+$/, "") + "/lane-" + (i + 1) + ".md";
  writeFileSync(f, parts.join(""), "utf8");
  console.log(f, "|", chars, "chars |", tags.join(" "));
}
const totalFacts = [...factGroups.values()].reduce((a, b) => a + b.length, 0);
const totalLessons = [...lessonGroups.values()].reduce((a, b) => a + b.length, 0);
console.log("lanes:", N, "| facts:", totalFacts, "| active lessons:", totalLessons, "| slices disjoint by domain/project by construction");
