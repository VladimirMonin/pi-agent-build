// Fail-closed application of an exact «Группы слияния фактов» plan.
import { readFileSync } from "node:fs";
import {
  SafetyError,
  assertPreserved,
  beginImmediate,
  createConsistentSnapshot,
  digest,
  hasColumn,
  openSnapshot,
  option,
  ownerOverride,
  parseKey,
  parseKeyList,
  parsePreservedList,
  parseStrictSection,
  positional,
  printSummary,
  reportFailure,
  requireDatabase,
  requireInput,
  stableRowsDigest,
  validateCli,
} from "./lib/safety.mjs";

const LABELS = ["KEEP KEY", "НОВОЕ ЗНАЧЕНИЕ", "ВОШЛО", "ЧТО СОХРАНЕНО", "УДАЛИТЬ"];

function parsePlan(raw, sectionName) {
  const blocks = parseStrictSection(raw, sectionName, LABELS);
  const groups = blocks.map(({ title, fields }) => ({
    title,
    keep: parseKey(fields["KEEP KEY"]),
    value: fields["НОВОЕ ЗНАЧЕНИЕ"],
    members: parseKeyList(fields.ВОШЛО),
    preserved: parsePreservedList(fields["ЧТО СОХРАНЕНО"]),
    deletes: parseKeyList(fields.УДАЛИТЬ),
  }));
  const keeps = groups.map((group) => group.keep);
  const members = groups.flatMap((group) => group.members);
  const deletes = groups.flatMap((group) => group.deletes);
  if (new Set(keeps).size !== keeps.length) throw new SafetyError("plan", "ОТКАЗ: KEEP KEY повторяется.");
  if (new Set(members).size !== members.length) throw new SafetyError("plan", "ОТКАЗ: исходный ключ указан более чем в одной группе.");
  if (new Set(deletes).size !== deletes.length) throw new SafetyError("plan", "ОТКАЗ: ключ удаления повторяется.");
  const keepSet = new Set(keeps);
  for (const group of groups) {
    if (!group.members.includes(group.keep)) throw new SafetyError("plan", "ОТКАЗ: KEEP KEY должен входить в ВОШЛО.");
    if (group.deletes.includes(group.keep)) throw new SafetyError("plan", "ОТКАЗ: KEEP KEY нельзя удалить.");
    if (group.deletes.some((key) => !group.members.includes(key))) throw new SafetyError("plan", "ОТКАЗ: УДАЛИТЬ должен быть подмножеством ВОШЛО.");
    if (!group.value.trim()) throw new SafetyError("plan", "ОТКАЗ: пустое значение запрещено.");
    if (group.value.length > 2000) throw new SafetyError("plan", "ОТКАЗ: значение превышает безопасный предел.");
  }
  if (deletes.some((key) => keepSet.has(key))) throw new SafetyError("plan", "ОТКАЗ: KEEP одной группы удаляется другой группой.");
  return groups;
}

function analyze(db, groups, prefix) {
  const get = db.prepare("SELECT key,value,source FROM semantic WHERE key=?");
  const stateRows = [];
  let owners = 0;
  let protectedCount = 0;
  for (const group of groups) {
    for (const key of [group.keep, ...group.members, ...group.deletes]) {
      if (prefix && !key.startsWith(prefix)) throw new SafetyError("scope", "ОТКАЗ: план выходит за разрешённый префикс.");
    }
    const rows = group.members.map((key) => get.get(key));
    if (rows.some((row) => !row)) throw new SafetyError("stale", "ОТКАЗ: план отсутствует или устарел.");
    protectedCount += assertPreserved(rows.map((row) => row.value), group.value, group.preserved);
    const owner = rows.some((row) => row.source === "user");
    if (owner) owners += 1;
    group.source = owner ? "user" : "consolidation";
    stateRows.push(...rows.map((row) => ({ group: group.title, ...row })));
  }
  stateRows.sort((left, right) => `${left.group}\0${left.key}`.localeCompare(`${right.group}\0${right.key}`));
  return {
    owners,
    protectedCount,
    stateDigest: stableRowsDigest(stateRows),
    changes: groups.length + groups.reduce((sum, group) => sum + group.deletes.length, 0),
  };
}

function applyGroups(db, groups) {
  const embedding = hasColumn(db, "semantic", "embedding");
  const update = db.prepare(`UPDATE semantic SET value=?,source=?,updated_at=datetime('now'),last_accessed=NULL${embedding ? ",embedding=NULL" : ""} WHERE key=?`);
  const remove = db.prepare("DELETE FROM semantic WHERE key=?");
  for (const group of groups) {
    if (update.run(group.value, group.source, group.keep).changes !== 1) throw new SafetyError("stale", "ОТКАЗ: план отсутствует или устарел.");
    for (const key of group.deletes) {
      if (remove.run(key).changes !== 1) throw new SafetyError("stale", "ОТКАЗ: план отсутствует или устарел.");
    }
  }
  const verify = db.prepare(`SELECT value,source${embedding ? ",embedding" : ""} FROM semantic WHERE key=?`);
  const exists = db.prepare("SELECT 1 FROM semantic WHERE key=?");
  for (const group of groups) {
    const row = verify.get(group.keep);
    if (!row || row.value !== group.value || row.source !== group.source || (embedding && row.embedding !== null)) {
      throw new SafetyError("verification", "ОТКАЗ: транзакционная самопроверка не пройдена.");
    }
    if (group.deletes.some((key) => exists.get(key))) throw new SafetyError("verification", "ОТКАЗ: транзакционная самопроверка не пройдена.");
  }
}

let snapshot;
let snapshotDb;
let applyDb;
try {
  const argv = process.argv.slice(2);
  validateCli(argv, { values: ["db", "prefix", "section"], booleans: ["apply", "owner-override"] });
  const dbPath = requireDatabase(argv);
  const inputs = positional(argv);
  if (inputs.length !== 1) throw new SafetyError("arguments", "ОТКАЗ: требуется ровно один файл плана.");
  const planPath = requireInput(inputs[0], "файл плана");
  const apply = argv.includes("--apply");
  const allowOwner = ownerOverride(argv);
  const prefix = option(argv, "prefix", "");
  const sectionName = option(argv, "section", "Группы слияния фактов");
  const initialRaw = readFileSync(planPath, "utf8");
  const initialPlanDigest = digest(initialRaw);

  snapshot = createConsistentSnapshot(dbPath);
  snapshotDb = openSnapshot(snapshot.path);
  const initialGroups = parsePlan(initialRaw, sectionName);
  const initialAnalysis = analyze(snapshotDb, initialGroups, prefix);
  snapshotDb.close();
  snapshotDb = undefined;

  if (!apply) {
    printSummary({ groups: initialGroups.length, ...initialAnalysis, apply: false });
  } else {
    // No query against the target occurs before the writer lock.
    applyDb = beginImmediate(dbPath);
    try {
      const lockedRaw = readFileSync(planPath, "utf8");
      if (digest(lockedRaw) !== initialPlanDigest) throw new SafetyError("stale", "ОТКАЗ: план изменился и устарел.");
      const lockedGroups = parsePlan(lockedRaw, sectionName);
      const lockedAnalysis = analyze(applyDb, lockedGroups, prefix);
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
