// Проверка бюджетов консолидации: берём настоящую buildConsolidationPrompt из
// пропатченного dist и кормим её синтетикой — пары, обрезка реплик, блоки
// памяти, guard итогового промпта и текст инструкции извлечения.
// Запуск: node test-memory-consolidation.mjs [<patched-dist>] (по умолчанию живой dist).
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const DIST = process.argv[2] ?? join(homedir(), ".pi", "agent", "npm", "node_modules",
  "@samfp", "pi-memory", "dist", "index.js");
const src = readFileSync(DIST, "utf8");

function ensure(ok, message) {
  if (!ok) { console.error(`ПРОВАЛ: ${message}`); process.exit(1); }
}

ensure(src.includes("function buildConsolidationPrompt("), "buildConsolidationPrompt не найдена — нужен пропатченный dist");
ensure(src.includes("const CONVO_BUDGET = 25000;"), "бюджеты консолидации не применены — нужен пропатченный dist");

// ── Вырезаем buildConsolidationPrompt целиком (балансировка скобок) ─────
const start = src.indexOf("function buildConsolidationPrompt(");
let i = src.indexOf("{", start), depth = 0, end = -1;
for (; i < src.length; i++) {
  if (src[i] === "{") depth++;
  else if (src[i] === "}" && --depth === 0) { end = i + 1; break; }
}
const fnSrc = src.slice(start, end);

// Заглушки для имён из скоупа модуля; promptText подменяется в кейсе guard.
const promptMatch = src.match(/var CONSOLIDATION_PROMPT = `([\s\S]*?)`;/);
ensure(promptMatch, "CONSOLIDATION_PROMPT не найден");
const CONSOLIDATION_PROMPT = promptMatch[1];
const truncate2 = (t, m) => (t.length > m ? t.slice(0, m) + "\u2026" : t);
const make = (promptText) => new Function("CONSOLIDATION_PROMPT", "truncate2",
  `${fnSrc}; return buildConsolidationPrompt;`)(promptText, truncate2);
const buildConsolidationPrompt = make(CONSOLIDATION_PROMPT);

const tag = (k) => "P" + String(k).padStart(2, "0") + " ";
const conversation = (prompt) => prompt.split("## Conversation")[1] ?? "";

// ── a) 40 пар × (5000 + 1200): бюджет разговора, новейшая пара, порядок ──
const turnsA = [];
for (let k = 0; k < 40; k++) {
  turnsA.push({ role: "user", text: tag(k) + "u".repeat(5000 - tag(k).length) });
  turnsA.push({ role: "assistant", text: tag(k) + "a".repeat(1200 - tag(k).length) });
}
const promptA = buildConsolidationPrompt(
  { userMessages: [], assistantMessages: [], turns: turnsA, cwd: "C:/tmp", sessionId: "t" },
  [], []);
const convA = conversation(promptA);
const linesA = convA.split("\n").map((l) => l.trim()).filter(Boolean);
const sumA = linesA.reduce((n, l) => n + l.length, 0);
ensure(sumA <= 25000, `сумма строк разговора ${sumA} > 25000`);
ensure(convA.includes(tag(39)), "самая новая пара не влезла в бюджет");
ensure(!convA.includes(tag(0)), "самая старая пара не должна попадать в бюджет");
const orderA = [];
for (let k = 0; k < 40; k++) if (convA.indexOf(tag(k)) >= 0) orderA.push(k);
const sortedA = [...orderA].sort((x, y) => x - y);
ensure(JSON.stringify(orderA) === JSON.stringify(sortedA), `пары не в хронологическом порядке: ${orderA}`);
ensure(orderA.length > 0 && orderA[orderA.length - 1] === 39, "новейшая пара не последняя в разговоре");
console.log(`a) ok: пар ${orderA.length} (${orderA[0]}..${orderA[orderA.length - 1]}), сумма ${sumA} ≤ 25000, порядок хронологический`);

// ── b) обрезка реплик: user 9000 → 5000+…, assistant 5000 → 1200+… ──────
const promptB = buildConsolidationPrompt(
  { userMessages: [], assistantMessages: [],
    turns: [{ role: "user", text: "U".repeat(9000) }, { role: "assistant", text: "A".repeat(5000) }],
    cwd: "", sessionId: "t" },
  [], []);
const convB = conversation(promptB);
ensure(convB.includes("User: " + "U".repeat(5000) + "\u2026"), "user не обрезан до 5000+…");
ensure(convB.includes("Assistant: " + "A".repeat(1200) + "\u2026"), "assistant не обрезан до 1200+…");
console.log("b) ok: user 5000+…, assistant 1200+…");

// ── c) память в промпте: факты ≤2000+строка, уроки ≤700+строка ───────────
const factsC = Array.from({ length: 40 }, (_, k) => ({
  key: "f" + String(k).padStart(2, "0"), value: "v".repeat(250)
}));
const lessonsC = Array.from({ length: 30 }, () => ({ category: "c", rule: "r".repeat(200) }));
const promptC = buildConsolidationPrompt(
  { userMessages: [], assistantMessages: [],
    turns: [{ role: "user", text: "q" }, { role: "assistant", text: "a" }], cwd: "", sessionId: "t" },
  factsC, lessonsC);
const memC = (promptC.split("## Current Memory State")[1] ?? "").split("\n\n## Conversation")[0];
const factsBlock = memC.split("And these lessons")[0];
const lessonsBlock = memC.split("And these lessons")[1] ?? "";
const blockLines = (block) => block.split("\n").map((l) => l.trim())
  .filter((l) => l.startsWith("- ") && !l.includes("(truncated)"));
const factLines = blockLines(factsBlock), lessonLines = blockLines(lessonsBlock);
const factSum = factLines.reduce((n, l) => n + l.length, 0);
const lessonSum = lessonLines.reduce((n, l) => n + l.length, 0);
ensure(factSum <= 2000 + Math.max(...factLines.map((l) => l.length)), `факты ${factSum} > 2000+строка`);
ensure(lessonSum <= 700 + Math.max(...lessonLines.map((l) => l.length)), `уроки ${lessonSum} > 700+строка`);
ensure(factsBlock.includes("- ... (truncated)"), "блок фактов не обрезан (нет '- ... (truncated)')");
ensure(lessonsBlock.includes("- ... (truncated)"), "блок уроков не обрезан (нет '- ... (truncated)')");
console.log(`c) ok: факты ${factSum} ≤ 2000+строка, уроки ${lessonSum} ≤ 700+строка, оба обрезаны`);

// ── d) guard: подменённый длинный промпт → trim + console.error ──────────
const guardBuild = make("X".repeat(12000));
const turnsD = [];
for (let k = 0; k < 5; k++) {
  turnsD.push({ role: "user", text: tag(k) + "u".repeat(4000 - tag(k).length) });
  turnsD.push({ role: "assistant", text: tag(k) + "a".repeat(800 - tag(k).length) });
}
const captured = [];
const origError = console.error;
console.error = (...args) => captured.push(args.join(" "));
let promptD;
try {
  promptD = guardBuild({ userMessages: [], assistantMessages: [], turns: turnsD, cwd: "C:/tmp", sessionId: "t" }, [], []);
} finally {
  console.error = origError;
}
ensure(promptD.length <= 31500, `guard не удержал промпт: ${promptD.length} > 31500`);
ensure(captured.length === 1, `guard должен писать ровно одну строку в stderr, поймано ${captured.length}`);
const guardMatch = captured[0].match(/^pi-memory: consolidation prompt trimmed to (\d+) chars \(dropped (\d+) pairs\)$/);
ensure(guardMatch, `неожиданный текст guard-сообщения: ${captured[0]}`);
const reportedChars = Number(guardMatch[1]), droppedPairs = Number(guardMatch[2]);
ensure(droppedPairs >= 1, "guard не сработал (dropped 0 pairs)");
ensure(reportedChars === promptD.length, `guard сообщил ${reportedChars}, итог ${promptD.length}`);
const convD = conversation(promptD);
for (let k = 0; k < 5; k++) {
  const present = convD.includes(tag(k));
  ensure(present === (k >= droppedPairs), `пара ${k}: ожидалось ${k >= droppedPairs ? "есть" : "нет"} (dropped ${droppedPairs})`);
}
console.log(`d) ok: guard сработал — итог ${reportedChars} ≤ 31500, dropped ${droppedPairs}, старые пары ${Array.from({ length: droppedPairs }, (_, k) => tag(k).trim()).join(",")} отброшены`);

// ── e) текст инструкции: reuse rule на месте, старые формулировки удалены ─
for (const needle of ["## Where a fact belongs (reuse rule)", "30-40%",
  "user.* is for stable working conditions", "because the graph is checked at compile time"]) {
  ensure(CONSOLIDATION_PROMPT.includes(needle), `в промпте нет: ${needle}`);
}
for (const needle of ["coding style, tool preferences, workflow habits",
  "languages, frameworks, architecture decisions"]) {
  ensure(!CONSOLIDATION_PROMPT.includes(needle), `в промпте осталось: ${needle}`);
}
console.log("e) ok: reuse rule и уточнённые категории на месте, старые формулировки удалены");

// ── f) структура dist: бюджеты, guard, таймауты, старый код пар удалён ───
for (const needle of ["EXEC_TIMEOUT_MS = 90e3", "HARD_TIMEOUT_MS = 12e4", "CONVO_BUDGET = 25000",
  "MAX_PROMPT_CHARS = 31500", "> 2000)", "> 700)"]) {
  ensure(src.includes(needle), `в dist нет: ${needle}`);
}
for (const needle of ["const messages = []", "messages.push"]) {
  ensure(!src.includes(needle), `в dist осталось: ${needle}`);
}
console.log("f) ok: 90e3/12e4, CONVO_BUDGET 25000, MAX_PROMPT_CHARS 31500, память 2000/700, старых messages[] нет");

console.log("\nУСПЕХ: бюджеты консолидации, обрезка, память, guard и текст промпта соответствуют сборке.");
