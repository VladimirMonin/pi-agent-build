// Estimate memory injection cost against a stable temporary SQLite snapshot.
import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import {
  SafetyError,
  createConsistentSnapshot,
  option,
  reportFailure,
  requireDatabase,
  requireInput,
  validateCli,
} from "./lib/safety.mjs";

function slug(cwd) {
  const skip = new Set(["workplace", "local", "home", "src", "scratch"]);
  for (const part of cwd.replaceAll("\\", "/").split("/").filter(Boolean).reverse()) {
    if (!skip.has(part.toLowerCase()) && part.length > 1) return part.toLowerCase();
  }
  return "";
}

function estimate(db, cwd) {
  const project = slug(cwd);
  const lessons = db.prepare("SELECT length(rule) l FROM lessons WHERE is_deleted=0 AND (project=? OR project IS NULL) ORDER BY created_at DESC LIMIT 50").all(project);
  const facts = db.prepare("SELECT key,length(value) l FROM semantic").all();
  const domains = new Map();
  let leafCount = 0;
  let leafChars = 0;
  for (const row of facts) {
    const parts = row.key.split(".");
    if (parts.length >= 3) {
      const prefix = parts.slice(0, 2).join(".");
      const current = domains.get(prefix) || { n: 0, chars: 0 };
      current.n += 1;
      current.chars += row.l;
      domains.set(prefix, current);
    } else {
      leafCount += 1;
      leafChars += row.l;
    }
  }
  const sorted = [...domains.values()].sort((left, right) => right.chars - left.chars);
  const lessonChars = lessons.reduce((sum, row) => sum + row.l, 0) + lessons.length * 15;
  const domainLowerBound = sorted.slice(0, 2).reduce((sum, value) => sum + Math.min(value.chars, value.chars * 20 / Math.max(value.n, 1)), 0);
  return { lessons: lessons.length, lessonChars, domains: domains.size, leafCount, leafChars, total: lessonChars + domainLowerBound + leafChars };
}

function readCases(path) {
  if (!path) return [{ cwd: "C:/workspace/example", prompt: "synthetic workflow preference query" }];
  requireInput(path, "файл кейсов");
  let cases;
  try {
    cases = JSON.parse(readFileSync(path, "utf8"));
  } catch {
    throw new SafetyError("input", "ОТКАЗ: файл кейсов содержит некорректный JSON.");
  }
  if (!Array.isArray(cases) || !cases.length || cases.some((item) => typeof item?.cwd !== "string" || !item.cwd.trim() || typeof item?.prompt !== "string" || !item.prompt.trim())) {
    throw new SafetyError("input", "ОТКАЗ: --cases должен содержать непустой JSON-массив {cwd,prompt}.");
  }
  return cases;
}

let snapshot;
let db;
try {
  const argv = process.argv.slice(2);
  validateCli(argv, { values: ["db", "cases"], booleans: ["estimate"] });
  const dbPath = requireDatabase(argv);
  const cases = readCases(option(argv, "cases", ""));
  snapshot = createConsistentSnapshot(dbPath);
  db = new DatabaseSync(snapshot.path, { timeout: 5000 });
  db.exec("PRAGMA query_only=ON");
  const totals = cases.map((item) => estimate(db, item.cwd));
  db.close();
  db = undefined;
  console.log(`оценка: кейсов ${totals.length} · уроков ${totals.reduce((sum, item) => sum + item.lessons, 0)} · доменов ${totals.reduce((sum, item) => sum + item.domains, 0)} · символов ~${Math.round(totals.reduce((sum, item) => sum + item.total, 0))}`);
  console.log("SNAPSHOT: исходная БД и sidecars не изменены.");
  console.log("ПРИМЕЧАНИЕ: это консервативная структурная оценка всех leaf values и выбранных доменов; prompt используется только как описание кейса, reachability не моделируется, код plugin не исполняется.");
} catch (error) {
  process.exitCode = reportFailure(error);
} finally {
  try { db?.close(); } catch {}
  snapshot?.cleanup();
}
