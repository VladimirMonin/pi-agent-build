// Проверка ПРАВКИ 2 (порядок реплик): берём настоящую buildConsolidationPrompt
// из пропатченного dist, кормим её реальной рассинхронизированной сессией —
// и смотрим, правильно ли собраны пары «вопрос — ответ».
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const DIST = join(homedir(), ".pi", "agent", "npm", "node_modules",
  "@samfp", "pi-memory", "dist", "index.js");
const src = readFileSync(DIST, "utf8");

if (!src.includes("function pushTurn(role, text) {")) {
  console.error("ПРАВКА 2 НЕ ПРИМЕНЕНА — сначала: python apply-memory-win.py");
  process.exit(1);
}

// ── Вырезаем buildConsolidationPrompt целиком (балансировка скобок) ─────
const start = src.indexOf("function buildConsolidationPrompt(");
if (start < 0) { console.error("buildConsolidationPrompt не найдена"); process.exit(1); }
let i = src.indexOf("{", start), depth = 0, end = -1;
for (; i < src.length; i++) {
  if (src[i] === "{") depth++;
  else if (src[i] === "}" && --depth === 0) { end = i + 1; break; }
}
const fnSrc = src.slice(start, end);

// Заглушки для имён из скоупа модуля.
const CONSOLIDATION_PROMPT = src.match(/var CONSOLIDATION_PROMPT = `([\s\S]*?)`;/)[1];
const truncate = (t, m) => (t.length > m ? t.slice(0, m) + "…" : t);
const buildConsolidationPrompt = new Function("CONSOLIDATION_PROMPT", "truncate",
  `${fnSrc}; return buildConsolidationPrompt;`)(CONSOLIDATION_PROMPT, truncate);

// ── Реальная рассинхронизированная сессия (см. probe-pairing.mjs) ───────
// 19 вопросов, 60 ответов с текстом — при индексации по i пары разъезжались.
const QA = [
  ["попроси оракла дать шутку про наш проект", "Принято — перехожу в режим руководителя."],
  ["Используй scout. Пусть найдёт точки входа проекта.", "Скаут вернул пустой ответ (cold-start gpt-oss-20b)."],
  ["отлично", "Модель gpt-oss-20b дала cold-start (0 tool calls). Перезапускаю."],
  ["Итак, я положил план на следующий релиз. Прочитай его", "Четыре подряд неудачи на этом probe (abort, 2× timeout)."],
  ["Только читаем)", "Нашёл точку: async-execution.js:510 спавнит раннер."],
  ["ничего не правим", "Нашёл ключевое: runnerEnv наследует весь env родителя."],
];

// turns: между вопросом и ответом вставляем assistant-сообщение БЕЗ текста
// (только thinking) — именно это и вызывало рассинхрон.
const turns = [];
for (const [q, a] of QA) {
  turns.push({ role: "user", text: q });
  turns.push({ role: "assistant", text: "" });      // thinking-only, выброшен
  turns.push({ role: "assistant", text: a });       // настоящий ответ
}

// Массивы, как их собрала бы старая сборка (независимо, thinking выброшен):
const userMessages = QA.map(([q]) => q);
const assistantMessages = [];
for (const [q, a] of QA) { assistantMessages.push(""); assistantMessages.push(a); }

const prompt = buildConsolidationPrompt(
  { userMessages, assistantMessages, turns, cwd: "C:/tmp", sessionId: "t" },
  [{ key: "project.x.a", value: "b" }],
  [],
);

// ── Разбираем, что попало в промпт ─────────────────────────────────────
const conv = prompt.split("## Conversation")[1] ?? "";
const lines = conv.split("\n").map((l) => l.trim()).filter(Boolean);

console.log("=== пары в промпте ===");
let bad = 0, pairs = 0;
for (let k = 0; k < lines.length; k++) {
  if (!lines[k].startsWith("User:")) continue;
  pairs++;
  const u = lines[k].slice(5).trim();
  const next = lines[k + 1] ?? "";
  const a = next.startsWith("Assistant:") ? next.slice(10).trim() : "(нет ответа)";
  const expected = QA.find(([q]) => u.startsWith(q.slice(0, 30)))?.[1];
  const ok = expected !== undefined && a.startsWith(expected.slice(0, 30));
  if (!ok) bad++;
  console.log(`  ${ok ? "ok " : "МИМО"} User: ${u.slice(0, 45)}`);
  console.log(`        Assistant: ${a.slice(0, 60)}`);
}

console.log(`\nпар: ${pairs}, перепутанных: ${bad}`);
if (pairs === 0) { console.error("ПРОВАЛ: пар нет вообще."); process.exit(1); }
if (bad > 0) { console.error("ПРОВАЛ: пары всё ещё перепутаны."); process.exit(1); }
console.log("\nУСПЕХ: каждый вопрос соединён со своим ответом (thinking-сообщения не сбивают пары).");

// ── Совместимость: без turns промпт работает по-старому ────────────────
const legacy = buildConsolidationPrompt(
  { userMessages: ["вопрос один", "вопрос два"], assistantMessages: ["ответ один"] }, [], []);
const legacyConv = legacy.split("## Conversation")[1] ?? "";
const hasLegacy = legacyConv.includes("вопрос один") && legacyConv.includes("вопрос два");
console.log("совместимость без turns:", hasLegacy ? "ok (старый путь работает)" : "ПРОВАЛ");
process.exit(hasLegacy ? 0 : 1);
