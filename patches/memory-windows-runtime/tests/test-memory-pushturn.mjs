// Structural guard for pushTurn's lexical scope and session-local ordered state.
// Runtime execution of the real handler is covered by test-memory-runtime-scope.mjs.
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join, resolve } from "node:path";

const defaultDist = join(homedir(), ".pi", "agent", "npm", "node_modules",
  "@samfp", "pi-memory", "dist", "index.js");
const dist = resolve(process.argv[2] ?? defaultDist);
const src = readFileSync(dist, "utf8").replace(/\r\n/g, "\n");

const indexStart = src.indexOf("function index_default(pi) {");
const helper = src.indexOf("  function pushTurn(role, text) {", indexStart);
const firstHandler = src.indexOf('  pi.on("session_start"', indexStart);
const extractText = src.indexOf("\nfunction extractText(content) {");

const problems = [];
if (!(indexStart >= 0 && indexStart < helper && helper < firstHandler && firstHandler < extractText)) {
  problems.push("pushTurn is not inside index_default before registered handlers");
}
if (!src.includes("// pi-memory ordered turns: session-local lexical state")) {
  problems.push("runtime-safe scope marker missing");
}
if (!src.includes("let pendingTurns = [];")) problems.push("session-local pendingTurns missing");
if (!src.includes("pendingTurns.push({ role, text });")) problems.push("pushTurn does not append ordered turns");
if (!src.includes("turns: pendingTurns.slice(),")) problems.push("consolidation input does not copy pendingTurns");
if (!src.includes("// pi-memory profile settings: PI_CODING_AGENT_DIR")) problems.push("profile settings marker missing");
if (!src.includes("process.env.PI_CODING_AGENT_DIR?.trim()")) problems.push("settings.json does not follow PI_CODING_AGENT_DIR");
if (!src.includes("process.env.PI_AGENT_BUILD_NPM_PREFIX?.trim()")) problems.push("custom npm prefix is ignored by Windows consolidation spawn");
if (src.includes("globalThis.__piMemoryTurns")) problems.push("process-global turn state remains");
if ((src.match(/pendingTurns = \[\];/g) ?? []).length < 3) problems.push("turn state is not reset at both session boundaries");
if (!src.includes("if (text) pushTurn(msg.role, text);")) problems.push("handlers do not call pushTurn");

if (problems.length) {
  console.error("FAIL:");
  for (const problem of problems) console.error(`  - ${problem}`);
  process.exit(1);
}
console.log(`PASS pushTurn lexical scope + session-local ordered state: ${dist}`);
