// Regression: boot the installed extension in the real Pi ExtensionRunner and
// let a one-shot reach agent_end. This preserves the extension's real lexical
// scope; no helper extraction and no injected pending arrays.
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const profile = process.argv[2] ?? "code";
if (!new Set(["code", "task"]).has(profile)) {
  throw new Error("usage: node test-memory-runtime-scope.mjs [code|task]");
}

const launcher = join(homedir(), "bin", `pi-${profile}`);
if (!existsSync(launcher)) throw new Error(`launcher not found: ${launcher}`);

const result = spawnSync("bash", [launcher,
  "-p",
  "--no-skills",
  "--no-context-files",
  "--no-tools",
  "--no-session",
  "--thinking", "off",
  "Reply with exactly OK.",
], {
  cwd: process.cwd(),
  encoding: "utf8",
  shell: false,
  timeout: 180_000,
});

const stdout = result.stdout ?? "";
const stderr = result.stderr ?? "";
const combined = `${stdout}\n${stderr}`;
process.stdout.write(stdout);
process.stderr.write(stderr);

if (result.error) throw result.error;
if (result.status !== 0) {
  throw new Error(`pi-${profile} exited ${result.status}`);
}
const extensionError = combined.match(/Extension(?: "| error \()[^\r\n]*pi-memory[^\r\n]*(?:error|\))?:?[^\r\n]*/i);
const scopeError = combined.match(/pending(?:User|Assistant)Messages is not defined/i);
if (extensionError || scopeError) {
  throw new Error(`pi-memory runtime failure: ${(scopeError ?? extensionError)[0]}`);
}
if (!stdout.includes("OK")) throw new Error(`pi-${profile} did not return OK`);

console.log(`PASS real Pi ExtensionRunner agent_end: pi-${profile}`);
