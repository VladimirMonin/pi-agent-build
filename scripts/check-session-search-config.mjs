#!/usr/bin/env node
// Validate the session-search config (embedder.modelPrefixes contract).
// Case-sensitive exact model IDs are legitimate distinct keys (JSON.parse is
// case-sensitive); never print config values beyond model IDs and counts.
// Exit codes mirror check-memory-model.mjs: 0 validated, 3 not configured, 2 invalid.
import { readFileSync, existsSync } from 'node:fs';

const [configPath] = process.argv.slice(2);
if (!configPath) {
  console.error('Usage: check-session-search-config.mjs <session-search config.json>');
  process.exit(2);
}
if (!existsSync(configPath)) {
  console.error('NOT CONFIGURED session-search: config absent');
  process.exit(3);
}
try {
  const cfg = JSON.parse(readFileSync(configPath, 'utf8'));
  const embedder = cfg.embedder ?? {};
  const model = embedder.model;
  const prefixes = embedder.modelPrefixes;
  if (typeof model !== 'string' || !model.trim() || typeof prefixes !== 'object' || prefixes === null || Array.isArray(prefixes)) {
    console.error('FAIL session-search config: embedder.model/modelPrefixes absent');
    process.exit(2);
  }
  if (!Object.prototype.hasOwnProperty.call(prefixes, model)) {
    console.error(`FAIL session-search config: no modelPrefixes entry for exact model ${model}`);
    process.exit(2);
  }
  const entry = prefixes[model];
  if (typeof entry !== 'object' || entry === null ||
      !Object.prototype.hasOwnProperty.call(entry, 'documentPrefix') ||
      !Object.prototype.hasOwnProperty.call(entry, 'queryPrefix') ||
      typeof entry.documentPrefix !== 'string' || typeof entry.queryPrefix !== 'string') {
    console.error(`FAIL session-search config: documentPrefix and queryPrefix are both required strings for ${model}`);
    process.exit(2);
  }
  console.log(`OK session-search config model=${model} entries=${Object.keys(prefixes).length}`);
  process.exitCode = 0;
} catch (error) {
  console.error(`FAIL session-search config invalid: ${error.message}`);
  process.exit(2);
}
