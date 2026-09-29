#!/usr/bin/env node
// Validate the static route used by pi-memory's --no-extensions child.
// Never execute credential commands or print credential values.
import { readFileSync } from "node:fs";
import { join } from "node:path";

const [root, settingsPath = join(root || "", "settings.json")] = process.argv.slice(2);
if (!root) {
  console.error("Usage: check-memory-model.mjs <profile-root> [settings-or-template.json]");
  process.exit(2);
}
try {
  const settings = JSON.parse(readFileSync(settingsPath, "utf8"));
  const model = settings.memory?.consolidationModel;
  const match = typeof model === "string" && /^([^/]+)\/(.+)$/.exec(model);
  if (!match) throw new Error("memory.consolidationModel must be provider/model-id");
  const [, providerName, modelId] = match;
  const models = JSON.parse(readFileSync(join(root, "models.json"), "utf8"));
  const provider = models.providers?.[providerName];
  if (!provider || !Array.isArray(provider.models) ||
      !provider.models.some(entry => entry.id === modelId)) {
    throw new Error(`static model ${model} absent from models.json`);
  }
  if (typeof provider.baseUrl !== "string" || !provider.baseUrl ||
      typeof provider.api !== "string" || !provider.api) {
    throw new Error(`static provider ${providerName} lacks baseUrl/api`);
  }
  const key = provider.apiKey;
  if (typeof key !== "string" || !key.trim()) {
    throw new Error(`static provider ${providerName} lacks credential configuration`);
  }
  let credential = "configured";
  if (key.startsWith("!")) {
    if (!key.slice(1).trim()) throw new Error(`static provider ${providerName} has empty credential command`);
    credential = "command not executed";
  } else if (key.startsWith("$")) {
    const envName = /^\$(?:\{([A-Za-z_][A-Za-z0-9_]*)\}|([A-Za-z_][A-Za-z0-9_]*))$/.exec(key);
    if (!envName || !process.env[envName[1] || envName[2]]) {
      throw new Error(`static provider ${providerName} has unresolved credential environment reference`);
    }
    credential = "environment present";
  }
  console.log(`PASS static memory model ${model} (${credential}; request not attempted)`);
} catch (error) {
  console.error(`FAIL memory consolidation route: ${error.message}`);
  process.exitCode = 2;
}
