// Structural guard for the consolidation session-id fix.
//
// ExtensionContext exposes no `sessionId`/`session` field — only the read-only
// `sessionManager`. Stock's `ctx.sessionId ?? ctx.session?.id` therefore always
// resolves to undefined and every consolidated fact/lesson is labelled
// `session:unknown`. The patch must read the real id from the session manager.
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join, resolve } from "node:path";

const defaultDist = join(homedir(), ".pi", "agent", "npm", "node_modules",
  "@samfp", "pi-memory", "dist", "index.js");
const dist = resolve(process.argv[2] ?? defaultDist);
const src = readFileSync(dist, "utf8").replace(/\r\n/g, "\n");

const problems = [];

if (!src.includes("// ExtensionContext has no sessionId/session field")) {
  problems.push("session-id marker comment missing");
}
if (!src.includes("ctx.sessionManager?.getSessionId?.()")) {
  problems.push("session id is not read from sessionManager.getSessionId()");
}
// The undefined stock expression must not survive as the primary lookup.
if (src.includes("sessionId = ctx.sessionId ?? ctx.session?.id;")) {
  problems.push("stock `ctx.sessionId ?? ctx.session?.id` assignment still present");
}
// The label must still fall back to `unknown` when no id is available.
if (!src.includes('`session:${sessionId ?? "unknown"}`')) {
  problems.push("consolidation source label lost its unknown fallback");
}

// Runtime check: the patched assignment must yield the real id when a session
// manager is present, and stay undefined-safe when it is not.
const assignStart = src.indexOf("// ExtensionContext has no sessionId/session field");
const assignEnd = src.indexOf("resolvedDbPath = resolveDbPath(sessionCwd);", assignStart);
if (assignStart < 0 || assignEnd < 0) {
  problems.push("patched session-id assignment block not found");
} else {
  const block = src.slice(assignStart, assignEnd);
  const run = (ctx) => new Function("ctx", `let sessionId;\n${block}\nreturn sessionId;`)(ctx);
  const withManager = run({ sessionManager: { getSessionId: () => "abc-123" } });
  if (withManager !== "abc-123") {
    problems.push(`sessionManager.getSessionId() not used: got ${JSON.stringify(withManager)}`);
  }
  const withoutManager = run({});
  if (withoutManager !== undefined) {
    problems.push(`missing session manager must stay undefined: got ${JSON.stringify(withoutManager)}`);
  }
}

if (problems.length) {
  console.error("FAIL:");
  for (const problem of problems) console.error(`  - ${problem}`);
  process.exit(1);
}
console.log(`PASS consolidation session id from sessionManager: ${dist}`);
