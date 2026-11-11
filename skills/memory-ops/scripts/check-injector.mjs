// check-injector.mjs — behavioural regression for the memory injector, on a
// COPY of the store (never the live DB — the collector updates access/embeddings).
//
//   node check-injector.mjs --db=<copy.db> [--settings=<settings.json>]
//                           [--bundle=<dist/index.js>] [--cases=<cases.json>]
//
// Without --cases the checks are generic and store-derived — block integrity,
// whole-line formatting, project-tag coverage — so the test travels between
// machines. With --cases ([{name,cwd,prompt,present,absent}]) the named
// present/absent assertions are added; use that for project-scope leak tests
// on a machine with factProjectAliases.
import { existsSync, readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";
import { DatabaseSync } from "node:sqlite";
import os from "node:os";

const argv = process.argv.slice(2);
const opt = (n, d) => (argv.find(a => a.startsWith("--" + n + "=")) || "").split("=").slice(1).join("=") || d;
const home = os.homedir().replaceAll("\\", "/");
const LIVE = (process.env.PI_MEMORY_DB || home + "/.pi/memory/memory.db").replaceAll("\\", "/").toLowerCase();

const DB = opt("db", "");
if (!DB || !existsSync(DB)) throw Error("Pass --db=<existing backup copy> (make one with scripts/db-copy.mjs)");
if (DB.replaceAll("\\", "/").toLowerCase() === LIVE) throw Error("refusing the live memory.db; pass a .backup copy");

const settingsPath = opt("settings", process.env.PI_CODING_AGENT_DIR
  ? process.env.PI_CODING_AGENT_DIR + "/settings.json"
  : home + "/.pi/agent/settings.json");
let MEM = {};
try { MEM = JSON.parse(readFileSync(settingsPath, "utf8")).memory ?? {}; } catch { /* plugin defaults */ }
const CFG = { ...MEM, lessonInjection: "selective" };

const bundle = opt("bundle", process.env.PI_MEMORY_BUNDLE
  || home + "/.pi/agent/npm/node_modules/@samfp/pi-memory/dist/index.js");
const bundlePath = existsSync(bundle) ? bundle : home + "/.pi/task/npm/node_modules/@samfp/pi-memory/dist/index.js";
if (!existsSync(bundlePath)) throw Error("plugin bundle not found — pass --bundle=<dist/index.js>");
const mod = await import(pathToFileURL(bundlePath).href);

const db = new DatabaseSync(DB, { readOnly: true });
const factLines = db.prepare("select key,value from semantic").all()
  .map(({ key, value }) => `- ${key.split(".").slice(1).join(".")}: ${value}`);
const lessonLines = db.prepare("select rule,negative from lessons where is_deleted=0").all()
  .map(({ rule, negative }) => `- ${negative ? "DON'T: " : ""}${rule}`);

const casesFile = opt("cases", "");
const cases = casesFile ? JSON.parse(readFileSync(casesFile, "utf8")) : null;

async function blockFor(cwd, prompt) {
  const result = await mod.buildContextBlock(new mod.MemoryStore(DB), cwd, prompt || "", CFG);
  return result.text ?? "";
}

function integrity(name, text) {
  if (text.length > 8000 || text.includes("... (truncated)") || !text.endsWith("</memory>"))
    throw Error(`${name}: incomplete block (${text.length})`);
  for (const section of ["Relevant Memory", "Learned Corrections", "Validated Approaches"]) {
    const fragment = text.split(`## ${section}\n`)[1]?.split("\n## ")[0] ?? "";
    for (const line of fragment.split("\n").filter(s => s.startsWith("- "))) {
      const known = section === "Relevant Memory" ? factLines : lessonLines;
      if (!known.some(full => line.startsWith(full)))
        throw Error(`${name}: partial or unknown line in ${section}: ${line.slice(0, 80)}`);
    }
  }
}

if (cases) {
  for (const { name, cwd, prompt, present, absent } of cases) {
    const text = await blockFor(cwd, prompt);
    integrity(name, text);
    if (present && !text.includes(present)) throw Error(`${name}: missing ${present}`);
    if (absent && text.includes(absent)) throw Error(`${name}: foreign ${absent}`);
    console.log(`${name}: ${text.length} chars — OK`);
  }
} else {
  const text = await blockFor(home, "продолжи работу над задачей");
  integrity("home", text);
  console.log(`home: ${text.length} chars — OK`);
}

const tagged = db.prepare("select distinct project from lessons where is_deleted=0 and project is not null").all();
for (const { project } of tagged) {
  const text = await blockFor(project, "продолжи работу над задачей в этом проекте");
  integrity(project, text);
  const local = db.prepare("select rule from lessons where is_deleted=0 and project=?").all(project);
  if (!local.some(({ rule }) => text.includes(rule)))
    throw Error(`project-specific lesson absent: ${project}`);
  console.log(`project ${project}: local lessons present — OK`);
}
console.log(`project-tag coverage: ${tagged.length}/${tagged.length} — OK`);
