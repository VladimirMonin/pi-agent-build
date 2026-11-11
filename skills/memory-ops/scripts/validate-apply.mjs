// validate-apply.mjs — pre-apply validation for lane plan files (READ-ONLY).
// Checks: format, existence, no user-source in deletions, cross-block AND
// cross-file disjointness, value length, project backticks, held blocks in
// applied sections. Exit 1 on violations.
//
// Usage (all plans of a run in ONE call — cross-plan disjointness needs it):
//   node validate-apply.mjs --db=<db-or-copy> <plan1.md> [plan2.md ...]
//   node validate-apply.mjs --db=<db> --dir=<plans-dir> --files=A.md,B.md
import { DatabaseSync } from "node:sqlite";
import { readFileSync, existsSync } from "node:fs";
import os from "node:os";

const argv = process.argv.slice(2);
const opt = (n, d) => (argv.find(a => a.startsWith("--" + n + "=")) || "").split("=").slice(1).join("=") || d;
const home = os.homedir().replaceAll("\\", "/");
const DB = opt("db", process.env.PI_MEMORY_DB || home + "/.pi/memory/memory.db");
const DIR = opt("dir", ".");
const positional = argv.filter(a => !a.startsWith("--"));
const FILES = positional.length
  ? positional
  : (opt("files", "") ? opt("files", "").split(",").map(s => s.trim()).filter(Boolean) : null);
if (!FILES || !FILES.length) {
  console.error("usage: node validate-apply.mjs --db=<db> <plan1.md> [plan2.md ...]  (or --dir=<dir> --files=a.md,b.md)");
  process.exit(2);
}

const db = new DatabaseSync(DB, { readOnly: true });
const factRow = db.prepare("select source from semantic where key=?");
const lessonRow = db.prepare("select source, is_deleted from lessons where id=?");

const uuidRe = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/g;
const keyRe = /`([A-Za-z0-9_\-]+(?:\.[A-Za-z0-9_\-]+)+)`|[A-Za-z0-9_\-]+(?:\.[A-Za-z0-9_\-]+)+/g;
const violations = [];
const warnings = [];
const memberSeen = new Map(); // key/id -> block label (across all files)
let gBlocks = 0, lrBlocks = 0, gDeletes = 0, lrCovered = 0, held = 0;

for (const f of FILES) {
  const path = f.includes("/") || f.includes("\\") ? f : `${DIR}/${f}`;
  if (!existsSync(path)) { warnings.push(`${f}: файл ещё не готов`); continue; }
  const raw = readFileSync(path, "utf8").replace(/\r\n/g, "\n");
  if (raw.includes("\uFFFD")) warnings.push(`${f}: заменённые символы (�) — проверь кодировку записи, нужен UTF-8`);

  // --- held section (report only) ---
  const heldIdx = raw.indexOf("## Ждёт подтверждения");
  if (heldIdx >= 0) held += (raw.slice(heldIdx).match(uuidRe) || []).length + (raw.slice(heldIdx).match(/`[a-z][a-z0-9_.\-]*\.[a-z0-9_.\-]+`/gi) || []).length;

  // --- G blocks (facts) ---
  for (const sec of raw.split(/(?:^|\n)## /)) {
    if (sec.startsWith("Группы слияния фактов")) {
      for (const b of sec.split(/\n### /).slice(1)) {
        const label = `${f}#${b.split("\n")[0].trim()}`;
        if (!/KEEP KEY:/.test(b)) {
          if (/НОВОЕ|ВОШЛО/.test(b) && !/💀/.test(b.split("\n")[0]))
            violations.push(`${label}: нераспознанный блок фактов (диалект формата?) — применитель молча пропустит`);
          continue;
        }
        gBlocks++;
        const keep = (b.match(/KEEP KEY:\s*`([^`]+)`/) || b.match(/KEEP KEY:\s*([A-Za-z0-9_.\-]+)/) || [])[1];
        if (!keep) { violations.push(`${label}: KEEP KEY не распознан`); continue; }
        const valLine = b.split("\n").find(l => l.trimStart().startsWith("НОВОЕ ЗНАЧЕНИЕ")) || "";
        const titleLine = b.split("\n")[0];
        if (/ЖДЁТ|⚠️/.test(titleLine)) violations.push(`${label}: блок-«ждёт подтверждения» в применяемой секции (скрипт применит! перенести)`);
        const keepRow = factRow.get(keep);
        if (keepRow && keepRow.source === "user") violations.push(`${label}: KEEP KEY source=user — перепись перебьёт источник (перенести в ожидание)`);
        const value = valLine.slice(valLine.indexOf(": ") + 2).trim();
        if (!value) violations.push(`${label}: пустое значение`);
        if (value.length > 2000) violations.push(`${label}: значение ${value.length} > 2000`);
        const wStart = b.indexOf("ВОШЛО");
        let wEnd = b.indexOf("ЧТО СОХРАНЕНО", wStart + 1);
        if (wEnd < 0) wEnd = b.indexOf("УДАЛИТЬ", wStart + 1);
        const memberBlock = wStart >= 0 ? b.slice(wStart, wEnd >= 0 ? wEnd : undefined) : "";
        const dStart = b.indexOf("УДАЛИТЬ");
        const delBlock = dStart >= 0 ? b.slice(dStart) : "";
        const members = [...new Set([...(memberBlock + "\n" + delBlock).matchAll(keyRe)].map(m => m[1] || m[0]))].filter(k => k !== keep);
        for (const k of members) {
          const r = factRow.get(k);
          if (!r) violations.push(`${label}: нет ключа в semantic: ${k}`);
          else if (r.source === "user") violations.push(`${label}: USER-ключ в поглощении: ${k} (нельзя)`);
          const prev = memberSeen.get(k);
          if (prev) violations.push(`${label}: ключ ${k} уже в блоке ${prev}`);
          memberSeen.set(k, label);
        }
        gDeletes += members.length;
      }
    }
    if (sec.startsWith("Слияние уроков")) {
      for (const b of sec.split(/\n### /).slice(1)) {
        const label = `${f}#${b.split("\n")[0].trim()}`;
        if (!/ГОТОВЫЙ ТЕКСТ УРОКА:/.test(b)) {
          if (/УРОК|ВОШЛО|ПРОЕКТ/.test(b) && !/💀/.test(b.split("\n")[0]))
            violations.push(`${label}: нераспознанный блок уроков (диалект формата?) — применитель молча пропустит`);
          continue;
        }
        lrBlocks++;
        const projLine = b.split("\n").find(l => l.trimStart().startsWith("ПРОЕКТ:")) || "";
        if (projLine.includes("`")) warnings.push(`${label}: ПРОЕКТ в backticks — снять (иначе кавычки попадут в project)`);
        const ruleLine = b.split("\n").find(l => l.trimStart().startsWith("ГОТОВЫЙ ТЕКСТ УРОКА")) || "";
        const rule = ruleLine.slice(ruleLine.indexOf(": ") + 2).trim();
        if (!rule) violations.push(`${label}: пустой текст урока`);
        const covStart = Math.min(...["ВОШЛО", "ПОКРЫВАЕТ"].map(s => b.indexOf(s)).filter(i => i >= 0).concat([1e9]));
        const ids = [...new Set([...b.slice(covStart).matchAll(uuidRe)].map(m => m[0]))];
        if (!ids.length) violations.push(`${label}: нет uuid в ВОШЛО`);
        for (const id of ids) {
          const r = lessonRow.get(id);
          if (!r) violations.push(`${label}: нет урока ${id}`);
          else {
            if (r.is_deleted) violations.push(`${label}: урок уже удалён ${id}`);
            if (r.source === "user") violations.push(`${label}: USER-урок в тарелке ${id} (нельзя)`);
          }
          const prev = memberSeen.get(id);
          if (prev) violations.push(`${label}: uuid ${id} уже в блоке ${prev}`);
          memberSeen.set(id, label);
        }
        lrCovered += ids.length;
      }
    }
  }
}

console.log(`G-блоков: ${gBlocks} (поглощений фактов: ${gDeletes}) | LR-блоков: ${lrBlocks} (членов тарелок: ${lrCovered}) | в «Ждёт подтверждения»: ${held}`);
console.log("ПРЕДУПРЕЖДЕНИЯ:", warnings.length ? warnings : "нет");
console.log("НАРУШЕНИЯ:", violations.length ? violations : "нет");
process.exit(violations.length ? 1 : 0);
