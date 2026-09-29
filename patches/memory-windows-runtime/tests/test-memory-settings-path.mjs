import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir, homedir } from "node:os";
import { join, resolve } from "node:path";

const dist = resolve(process.argv[2] ?? "");
if (!process.argv[2]) throw new Error("usage: node test-memory-settings-path.mjs <patched-dist>");
const src = readFileSync(dist, "utf8").replace(/\r\n/g, "\n");

function extractFunction(name) {
  const start = src.indexOf(`function ${name}(`);
  if (start < 0) throw new Error(`${name} not found`);
  let i = src.indexOf("{", start), depth = 0;
  for (; i < src.length; i++) {
    if (src[i] === "{") depth++;
    else if (src[i] === "}" && --depth === 0) return src.slice(start, i + 1);
  }
  throw new Error(`${name} is not balanced`);
}

const settingsStart = src.indexOf("// pi-memory profile settings: PI_CODING_AGENT_DIR");
const settingsEnd = src.indexOf("var DEFAULT_CONSOLIDATION_MODEL", settingsStart);
if (settingsStart < 0 || settingsEnd < 0) throw new Error("profile settings assignment missing");
const settingsAssignment = src.slice(settingsStart, settingsEnd);
const mergeSource = extractFunction("mergeMemorySettings");
const readSource = extractFunction("readSettingsConfig");
const taskDir = mkdtempSync(join(tmpdir(), "pi-memory-task-settings-"));
const prior = process.env.PI_CODING_AGENT_DIR;
try {
  writeFileSync(join(taskDir, "settings.json"), JSON.stringify({
    memory: { consolidationModel: "task-only/model",
      factProjectAliases: [{ path: "/example/worktrees", scope: "example", includeChildren: true }] },
  }));
  const projectDir = join(taskDir, "project");
  mkdirSync(join(projectDir, ".pi"), { recursive: true });
  writeFileSync(join(projectDir, ".pi", "settings.json"), JSON.stringify({
    memory: { factProjectAliases: [{ path: "/other", scope: "foreign" }], lessonInjection: "selective" }
  }));
  process.env.PI_CODING_AGENT_DIR = taskDir;
  const result = new Function("join", "homedir", "readFileSync", "projectDir", `
    ${settingsAssignment}
    ${mergeSource}
    ${readSource}
    return { path: GLOBAL_SETTINGS_PATH, config: readSettingsConfig(projectDir) };
  `)(join, homedir, readFileSync, projectDir);
  if (resolve(result.path) !== resolve(join(taskDir, "settings.json"))) {
    throw new Error(`settings path ignored PI_CODING_AGENT_DIR: ${result.path}`);
  }
  if (result.config.consolidationModel !== "task-only/model" ||
      result.config.factProjectAliases?.[0]?.scope !== "example" ||
      result.config.lessonInjection !== "selective") {
    throw new Error(`Task-only memory settings and private aliases were not loaded: ${JSON.stringify(result.config)}`);
  }
  if (!src.includes('var DEFAULT_MEMORY_DIR = join(homedir(), ".pi", "memory");')) {
    throw new Error("shared default memory DB path changed unexpectedly");
  }
  console.log(`PASS Task-only memory settings path: ${result.path}`);
} finally {
  if (prior === undefined) delete process.env.PI_CODING_AGENT_DIR;
  else process.env.PI_CODING_AGENT_DIR = prior;
  rmSync(taskDir, { recursive: true, force: true });
}
