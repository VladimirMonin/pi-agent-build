import { createHash, timingSafeEqual } from "node:crypto";
import {
  existsSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { DatabaseSync } from "node:sqlite";

export class SafetyError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "SafetyError";
    this.code = code;
  }
}

export function option(argv, name, fallback = "") {
  const inline = argv.filter((arg) => arg.startsWith(`--${name}=`));
  const indexes = argv.flatMap((arg, index) => arg === `--${name}` ? [index] : []);
  if (inline.length + indexes.length > 1) throw new SafetyError("arguments", `ОТКАЗ: параметр --${name} указан повторно.`);
  if (inline.length) return inline[0].slice(name.length + 3);
  if (indexes.length) {
    const index = indexes[0];
    if (index + 1 >= argv.length || argv[index + 1].startsWith("--")) throw new SafetyError("arguments", `ОТКАЗ: параметр --${name} пуст.`);
    return argv[index + 1];
  }
  return fallback;
}

export function positional(argv) {
  const values = [];
  const valueOptions = new Set(["db", "prefix", "section", "min-coverage", "cases", "plugin"]);
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg.startsWith("--")) {
      const name = arg.slice(2).split("=", 1)[0];
      if (!arg.includes("=") && valueOptions.has(name) && index + 1 < argv.length) index += 1;
      continue;
    }
    values.push(arg);
  }
  return values;
}

export function validateCli(argv, { values = [], booleans = [] } = {}) {
  const valueSet = new Set(values);
  const booleanSet = new Set(booleans);
  const seen = new Set();
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (!arg.startsWith("--")) continue;
    const equal = arg.indexOf("=");
    const name = arg.slice(2, equal >= 0 ? equal : undefined);
    if (!valueSet.has(name) && !booleanSet.has(name)) throw new SafetyError("arguments", "ОТКАЗ: неизвестный параметр CLI.");
    if (seen.has(name)) throw new SafetyError("arguments", "ОТКАЗ: параметр CLI указан повторно.");
    seen.add(name);
    if (booleanSet.has(name)) {
      if (equal >= 0) throw new SafetyError("arguments", "ОТКАЗ: boolean-параметр не принимает значение.");
      continue;
    }
    if (equal >= 0) {
      if (!arg.slice(equal + 1)) throw new SafetyError("arguments", "ОТКАЗ: параметр CLI пуст.");
    } else {
      if (index + 1 >= argv.length || argv[index + 1].startsWith("--")) throw new SafetyError("arguments", "ОТКАЗ: параметр CLI пуст.");
      index += 1;
    }
  }
}

export function requireDatabase(argv) {
  const path = option(argv, "db");
  if (!path) throw new SafetyError("database", "ОТКАЗ: укажите явный путь --db=<path>. Значения по умолчанию нет.");
  if (!existsSync(path) || !statSync(path).isFile()) throw new SafetyError("database", "ОТКАЗ: файл --db не найден.");
  return path;
}

export function requireInput(path, label) {
  if (!path) throw new SafetyError("input", `ОТКАЗ: не указан ${label}.`);
  if (!existsSync(path) || !statSync(path).isFile()) throw new SafetyError("input", `ОТКАЗ: ${label} не найден.`);
  return path;
}

export function ownerOverride(argv) {
  return argv.includes("--owner-override");
}

export function digest(value) {
  return createHash("sha256").update(value).digest("hex");
}

function sameBuffer(left, right) {
  if (left === null || right === null) return left === right;
  return left.length === right.length && timingSafeEqual(left, right);
}

function captureSqliteFiles(path) {
  const capture = [];
  for (const suffix of ["", "-wal", "-shm", "-journal"]) {
    const file = `${path}${suffix}`;
    try {
      capture.push(existsSync(file) ? readFileSync(file) : null);
    } catch {
      return null;
    }
  }
  return capture;
}

/**
 * Copy a stable db/WAL view without opening the source database. Two identical
 * consecutive byte captures are required; the source db, WAL and SHM are never
 * created, locked, checkpointed, or rewritten by this process.
 */
export function createConsistentSnapshot(path) {
  let stable = null;
  for (let attempt = 0; attempt < 20; attempt += 1) {
    const first = captureSqliteFiles(path);
    const second = captureSqliteFiles(path);
    if (first && second && first.every((value, index) => sameBuffer(value, second[index]))) {
      stable = second;
      break;
    }
  }
  if (!stable || !stable[0]) throw new SafetyError("snapshot", "ОТКАЗ: не удалось получить стабильный SQLite snapshot.");

  const directory = mkdtempSync(join(tmpdir(), "memory-ops-snapshot-"));
  const snapshotPath = join(directory, "memory.db");
  writeFileSync(snapshotPath, stable[0]);
  // SQLite reconstructs SHM locally. Only the stable WAL bytes are durable input.
  if (stable[1]) writeFileSync(`${snapshotPath}-wal`, stable[1]);
  // A hot rollback journal is copied too; SQLite may safely recover only the temp copy.
  if (stable[3]) writeFileSync(`${snapshotPath}-journal`, stable[3]);
  return {
    directory,
    path: snapshotPath,
    cleanup() { rmSync(directory, { recursive: true, force: true }); },
  };
}

export function openSnapshot(path) {
  const db = new DatabaseSync(path, { timeout: 5000 });
  db.exec("PRAGMA query_only=ON");
  const result = db.prepare("PRAGMA quick_check").all();
  if (result.length !== 1 || result[0].quick_check !== "ok") {
    db.close();
    throw new SafetyError("snapshot", "ОТКАЗ: проверка SQLite snapshot не пройдена.");
  }
  return db;
}

/** Opening the apply target and acquiring the writer lock are one operation. */
export function beginImmediate(path) {
  const db = new DatabaseSync(path, { timeout: 5000 });
  try {
    db.exec("BEGIN IMMEDIATE");
    return db;
  } catch {
    db.close();
    throw new SafetyError("locked", "ОТКАЗ: не удалось захватить транзакцию записи.");
  }
}

export function hasColumn(db, table, column) {
  return db.prepare(`PRAGMA table_info(${table})`).all().some((row) => row.name === column);
}

export function normalizePlan(raw) {
  if (typeof raw !== "string" || raw.includes("\0")) throw new SafetyError("plan", "ОТКАЗ: план повреждён.");
  return raw.replace(/\r\n?/gu, "\n");
}

export function parseStrictSection(rawInput, sectionName, labels) {
  const raw = normalizePlan(rawInput);
  const lines = raw.split("\n");
  if (lines.some((line) => /^\s*(?:```|~~~)/u.test(line))) throw new SafetyError("plan", "ОТКАЗ: fenced-блоки в плане запрещены.");
  const exact = lines.flatMap((line, index) => line === `## ${sectionName}` ? [index] : []);
  if (exact.length !== 1) throw new SafetyError("plan", "ОТКАЗ: требуется ровно один точный раздел плана.");
  const start = exact[0] + 1;
  let end = lines.length;
  for (let index = start; index < lines.length; index += 1) {
    if (/^## /u.test(lines[index])) {
      end = index;
      break;
    }
  }
  const sectionLines = lines.slice(start, end);
  const groups = [];
  let cursor = 0;
  while (cursor < sectionLines.length && sectionLines[cursor] === "") cursor += 1;
  while (cursor < sectionLines.length) {
    const heading = sectionLines[cursor].match(/^### ([^#\s].*)$/u);
    if (!heading || heading[1].trim() !== heading[1]) throw new SafetyError("plan", "ОТКАЗ: некорректный заголовок группы.");
    const title = heading[1];
    cursor += 1;
    const fields = {};
    for (const label of labels) {
      if (cursor >= sectionLines.length || !sectionLines[cursor].startsWith(`${label}: `)) {
        throw new SafetyError("plan", "ОТКАЗ: отсутствует или переставлено обязательное поле плана.");
      }
      const first = sectionLines[cursor].slice(label.length + 2);
      if (first !== first.trim()) throw new SafetyError("plan", "ОТКАЗ: пробелы в обязательном поле плана некорректны.");
      cursor += 1;
      const parts = [first];
      while (cursor < sectionLines.length && /^  \S/u.test(sectionLines[cursor])) {
        const continuation = sectionLines[cursor].slice(2);
        if (continuation !== continuation.trim()) throw new SafetyError("plan", "ОТКАЗ: пробелы в продолжении поля некорректны.");
        parts.push(continuation);
        cursor += 1;
      }
      const value = parts.join(" ").trim();
      if (!value) throw new SafetyError("plan", "ОТКАЗ: пустое поле плана запрещено.");
      fields[label] = value;
    }
    while (cursor < sectionLines.length && sectionLines[cursor] === "") cursor += 1;
    if (cursor < sectionLines.length && !/^### /u.test(sectionLines[cursor])) {
      throw new SafetyError("plan", "ОТКАЗ: лишняя или некорректная строка в группе плана.");
    }
    groups.push({ title, fields });
  }
  if (!groups.length) throw new SafetyError("plan", "ОТКАЗ: раздел плана не содержит групп.");
  const titles = groups.map((group) => group.title);
  if (new Set(titles).size !== titles.length) throw new SafetyError("plan", "ОТКАЗ: заголовки групп повторяются.");
  return groups;
}

const KEY_RE = /^[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)+$/u;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu;

function uniqueList(values) {
  if (new Set(values).size !== values.length) throw new SafetyError("plan", "ОТКАЗ: список плана содержит дубликаты.");
  return values;
}

export function parseKey(value) {
  const match = value.match(/^`([^`]+)`$/u);
  if (!match || !KEY_RE.test(match[1])) throw new SafetyError("plan", "ОТКАЗ: ключ должен быть одним точным backtick-значением.");
  return match[1];
}

export function parseKeyList(value) {
  if (!/^`[^`]+`(?:, `[^`]+`)*$/u.test(value)) throw new SafetyError("plan", "ОТКАЗ: список ключей должен быть единообразным и точным.");
  return uniqueList(value.split(", ").map(parseKey));
}

export function parseUuidList(value) {
  const values = value.split(", ");
  if (!values.length || values.some((item) => !UUID_RE.test(item))) throw new SafetyError("plan", "ОТКАЗ: список UUID некорректен.");
  return uniqueList(values);
}

export function parsePreservedList(value) {
  const values = value.split(", ");
  if (!values.length || values.some((item) => !item || item !== item.trim() || item.includes("`") || item.includes("\n"))) {
    throw new SafetyError("plan", "ОТКАЗ: список сохранённых токенов некорректен.");
  }
  return uniqueList(values);
}

function canonical(value) {
  return value;
}

const NON_SUBSTANTIVE_WORDS = new Set([
  "a", "an", "and", "are", "as", "at", "be", "by", "for", "from", "in", "is", "it", "of", "on", "or", "the", "to", "with",
  "brief", "concise", "detailed", "machine", "merged", "original", "owner", "source", "wording",
  "в", "для", "и", "из", "или", "к", "на", "но", "о", "от", "по", "с", "у",
  "владельца", "исходная", "краткая", "кратко", "машинная", "объединено", "подробная", "сжатия", "формулировка",
]);

function substantiveWords(text) {
  const result = [];
  for (const match of String(text).normalize("NFC").matchAll(/[\p{L}\p{N}][\p{L}\p{M}\p{N}_-]*/gu)) {
    const exact = match[0];
    if (exact.length === 1 || !NON_SUBSTANTIVE_WORDS.has(exact.toLocaleLowerCase("und"))) result.push(exact);
  }
  return result;
}

function isOrderedSubsequence(required, actual) {
  let index = 0;
  for (const value of actual) if (index < required.length && value === required[index]) index += 1;
  return index === required.length;
}

export function protectedTokens(text) {
  const source = String(text);
  const values = new Set();
  const patterns = [
    /`([^`\n]+)`/gu,
    /\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b/giu,
    /(?:[A-Za-z]:[\\/]|\/)[^\s,;)}\]]+/gu,
    /(?:[A-Za-z0-9._-]+[\\/])+(?:[A-Za-z0-9._-]+)/gu,
    /https?:\/\/[^\s,;)}\]]+/giu,
    /--[A-Za-z0-9][A-Za-z0-9_-]*/gu,
    /\b[A-Za-z][A-Za-z0-9-]*(?:\.[A-Za-z0-9_-]+)+\b/gu,
    /\b[A-Za-zА-ЯЁ][A-Za-zА-Яа-яЁё0-9]*(?:_[A-Za-zА-Яа-яЁё0-9]+)+\b/gu,
    /\b[a-zа-яё]+[A-ZА-ЯЁ][A-Za-zА-Яа-яЁё0-9]*\b/gu,
    /\b[A-ZА-ЯЁ][A-ZА-ЯЁ0-9-]{1,}\b/gu,
    /(?<![A-Za-z0-9_])[+\-−]?(?:\d+(?:[._:]\d+)+(?:[eE][+\-−]?\d+)?|\d+(?:\.\d*)?(?:[eE][+\-−]?\d+)?|\.\d+(?:[eE][+\-−]?\d+)?)(?![A-Za-z0-9_])/gu,
  ];
  for (const pattern of patterns) {
    for (const match of source.matchAll(pattern)) values.add(canonical(match[1] ?? match[0]));
  }
  return values;
}

export function assertPreserved(sourceTexts, resultText, declaredValues) {
  const required = new Set();
  for (const text of sourceTexts) for (const token of protectedTokens(text)) required.add(token);
  const result = protectedTokens(resultText);
  const declared = new Set();
  const normalizedResult = canonical(resultText);
  let missingDeclaredFact = false;
  for (const value of declaredValues) {
    if (!normalizedResult.includes(canonical(value))) missingDeclaredFact = true;
    const extracted = protectedTokens(value);
    if (extracted.size) for (const token of extracted) declared.add(token);
  }
  const missing = [...required].filter((token) => !result.has(token) || !declared.has(token));
  const actualWords = substantiveWords(resultText);
  const missingWords = sourceTexts.some((text) => !isOrderedSubsequence(substantiveWords(text), actualWords));
  if (missing.length || missingWords || missingDeclaredFact) throw new SafetyError("preservation", "ОТКАЗ: проверка сохранности фактов/токенов не пройдена.");
  return required.size + sourceTexts.reduce((sum, text) => sum + substantiveWords(text).length, 0);
}

export function stableRowsDigest(rows) {
  const normalized = rows.map((row) => Object.fromEntries(Object.entries(row).map(([key, value]) => [key, value instanceof Uint8Array ? Buffer.from(value).toString("base64") : value])));
  return digest(JSON.stringify(normalized));
}

export function printSummary({ groups = 0, changes = 0, owners = 0, protectedCount = 0, apply = false }) {
  console.log(`проверено: групп ${groups} · изменений ${changes} · owner-записей ${owners} · защищённых токенов ${protectedCount}`);
  console.log(apply ? "ПРИМЕНЕНО: транзакция подтверждена." : "DRY-RUN: исходная БД и sidecars не изменены.");
}

export function reportFailure(error) {
  if (error instanceof SafetyError) {
    console.error(error.message);
    return error.code === "arguments" || error.code === "database" || error.code === "input" || error.code === "plan" ? 2 : 3;
  }
  console.error("ОТКАЗ: операция не выполнена; детали скрыты.");
  return 4;
}
