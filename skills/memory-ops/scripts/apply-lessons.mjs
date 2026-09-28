// Fail-closed application of an exact «Слияние уроков» plan.
import { randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";
import {
  SafetyError,
  assertPreserved,
  beginImmediate,
  createConsistentSnapshot,
  digest,
  openSnapshot,
  option,
  ownerOverride,
  parsePreservedList,
  parseStrictSection,
  parseUuidList,
  positional,
  printSummary,
  reportFailure,
  requireDatabase,
  requireInput,
  stableRowsDigest,
  validateCli,
} from "./lib/safety.mjs";

const LABELS = ["ПРОЕКТ", "ГОТОВЫЙ ТЕКСТ УРОКА", "ВОШЛО", "ЧТО СОХРАНЕНО", "УДАЛИТЬ"];

function parsePlan(raw, sectionName) {
  const blocks = parseStrictSection(raw, sectionName, LABELS);
  const groups = blocks.map(({ title, fields }) => {
    const metadata = fields.ПРОЕКТ.match(/^(.+?) · ТИП: negative=([01]) · КАТЕГОРИЯ: ([A-Za-z0-9_-]+)$/u);
    if (!metadata) throw new SafetyError("plan", "ОТКАЗ: metadata урока некорректна.");
    const project = /^NULL$/u.test(metadata[1]) ? null : metadata[1];
    if (project !== null && !project.trim()) throw new SafetyError("plan", "ОТКАЗ: пустой project запрещён.");
    return {
      title,
      project,
      negative: Number(metadata[2]),
      category: metadata[3],
      rule: fields["ГОТОВЫЙ ТЕКСТ УРОКА"],
      members: parseUuidList(fields.ВОШЛО),
      preserved: parsePreservedList(fields["ЧТО СОХРАНЕНО"]),
      deletes: parseUuidList(fields.УДАЛИТЬ),
    };
  });
  const members = groups.flatMap((group) => group.members);
  const deletes = groups.flatMap((group) => group.deletes);
  if (new Set(members).size !== members.length) throw new SafetyError("plan", "ОТКАЗ: UUID указан более чем в одной группе.");
  if (new Set(deletes).size !== deletes.length) throw new SafetyError("plan", "ОТКАЗ: UUID удаления повторяется.");
  for (const group of groups) {
    if (!group.rule.trim()) throw new SafetyError("plan", "ОТКАЗ: пустой текст урока запрещён.");
    if (group.rule.length > 4000) throw new SafetyError("plan", "ОТКАЗ: текст урока превышает безопасный предел.");
    if (group.deletes.some((id) => !group.members.includes(id))) throw new SafetyError("plan", "ОТКАЗ: УДАЛИТЬ должен быть подмножеством ВОШЛО.");
  }
  return groups;
}

function analyze(db, groups) {
  const get = db.prepare("SELECT id,rule,category,source,negative,is_deleted,project FROM lessons WHERE id=?");
  const stateRows = [];
  let owners = 0;
  let protectedCount = 0;
  for (const group of groups) {
    const rows = group.members.map((id) => get.get(id));
    if (rows.some((row) => !row || row.is_deleted !== 0)) throw new SafetyError("stale", "ОТКАЗ: план отсутствует или устарел.");
    if (rows.some((row) => row.category !== group.category || Number(row.negative) !== group.negative || row.project !== group.project)) {
      throw new SafetyError("preservation", "ОТКАЗ: metadata исходных уроков не сохранена.");
    }
    protectedCount += assertPreserved(rows.map((row) => row.rule), group.rule, group.preserved);
    const owner = rows.some((row) => row.source === "user");
    if (owner) owners += 1;
    group.source = owner ? "user" : "consolidation";
    stateRows.push(...rows.map((row) => ({ group: group.title, ...row })));
  }
  stateRows.sort((left, right) => `${left.group}\0${left.id}`.localeCompare(`${right.group}\0${right.id}`));
  return {
    owners,
    protectedCount,
    stateDigest: stableRowsDigest(stateRows),
    changes: groups.length + groups.reduce((sum, group) => sum + group.deletes.length, 0),
  };
}

function applyGroups(db, groups) {
  const insert = db.prepare("INSERT INTO lessons (id,rule,category,source,negative,is_deleted,created_at,project) VALUES (?,?,?,?,?,0,datetime('now'),?)");
  const remove = db.prepare("UPDATE lessons SET is_deleted=1 WHERE id=? AND is_deleted=0");
  const created = [];
  for (const group of groups) {
    const id = randomUUID();
    insert.run(id, group.rule, group.category, group.source, group.negative, group.project);
    created.push({ id, group });
    for (const oldId of group.deletes) {
      if (remove.run(oldId).changes !== 1) throw new SafetyError("stale", "ОТКАЗ: план отсутствует или устарел.");
    }
  }
  const get = db.prepare("SELECT rule,category,source,negative,is_deleted,project FROM lessons WHERE id=?");
  for (const { id, group } of created) {
    const row = get.get(id);
    if (!row || row.rule !== group.rule || row.category !== group.category || row.source !== group.source || Number(row.negative) !== group.negative || row.is_deleted !== 0 || row.project !== group.project) {
      throw new SafetyError("verification", "ОТКАЗ: транзакционная самопроверка не пройдена.");
    }
  }
  for (const group of groups) {
    for (const id of group.deletes) {
      if (get.get(id)?.is_deleted !== 1) throw new SafetyError("verification", "ОТКАЗ: транзакционная самопроверка не пройдена.");
    }
  }
}

let snapshot;
let snapshotDb;
let applyDb;
try {
  const argv = process.argv.slice(2);
  validateCli(argv, { values: ["db", "section", "min-coverage"], booleans: ["apply", "owner-override"] });
  const dbPath = requireDatabase(argv);
  const inputs = positional(argv);
  if (inputs.length !== 1) throw new SafetyError("arguments", "ОТКАЗ: требуется ровно один файл плана.");
  const planPath = requireInput(inputs[0], "файл плана");
  const apply = argv.includes("--apply");
  const allowOwner = ownerOverride(argv);
  const sectionName = option(argv, "section", "Слияние уроков");
  const coverage = option(argv, "min-coverage", "1");
  if (coverage !== "1") throw new SafetyError("arguments", "ОТКАЗ: token coverage обязана быть 1 и не может быть отключена.");
  const initialRaw = readFileSync(planPath, "utf8");
  const initialPlanDigest = digest(initialRaw);

  snapshot = createConsistentSnapshot(dbPath);
  snapshotDb = openSnapshot(snapshot.path);
  const initialGroups = parsePlan(initialRaw, sectionName);
  const initialAnalysis = analyze(snapshotDb, initialGroups);
  snapshotDb.close();
  snapshotDb = undefined;

  if (!apply) {
    printSummary({ groups: initialGroups.length, ...initialAnalysis, apply: false });
  } else {
    applyDb = beginImmediate(dbPath);
    try {
      const lockedRaw = readFileSync(planPath, "utf8");
      if (digest(lockedRaw) !== initialPlanDigest) throw new SafetyError("stale", "ОТКАЗ: план изменился и устарел.");
      const lockedGroups = parsePlan(lockedRaw, sectionName);
      const lockedAnalysis = analyze(applyDb, lockedGroups);
      if (lockedAnalysis.stateDigest !== initialAnalysis.stateDigest) throw new SafetyError("stale", "ОТКАЗ: план отсутствует или устарел.");
      if (lockedAnalysis.owners && !allowOwner) throw new SafetyError("owner", "ОТКАЗ: source=user требует --owner-override.");
      applyGroups(applyDb, lockedGroups);
      if (digest(readFileSync(planPath, "utf8")) !== initialPlanDigest) throw new SafetyError("stale", "ОТКАЗ: план изменился и устарел.");
      applyDb.exec("COMMIT");
      applyDb.close();
      applyDb = undefined;
      printSummary({ groups: lockedGroups.length, ...lockedAnalysis, apply: true });
    } catch (error) {
      try { applyDb.exec("ROLLBACK"); } catch {}
      applyDb.close();
      applyDb = undefined;
      throw error;
    }
  }
} catch (error) {
  process.exitCode = reportFailure(error);
} finally {
  try { snapshotDb?.close(); } catch {}
  try { applyDb?.close(); } catch {}
  snapshot?.cleanup();
}
