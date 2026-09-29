// warm-memory-embedder.mjs — pre-download the pi-memory local embedder model.
//
// @samfp/pi-memory loads its embedding model lazily on first semantic search
// with a hard 30s load timeout. On a cold cache the download alone can exceed
// that on slow links, so the plugin silently degrades to FTS-only. This helper
// downloads the model ahead of time into the profile's @xenova/transformers
// cache, with a generous, configurable timeout and bounded retries.
//
// Usage:
//   node warm-memory-embedder.mjs <profile_root> [--timeout-ms N] [--retries N]
//
// Exit codes: 0 model cached (or already present); 1 download failed; 2 fatal.
// The model id is read from the patched dist so there is a single source of
// truth; nothing is hardcoded here.

import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const profileRoot = process.argv[2];
if (!profileRoot) {
  console.error("usage: node warm-memory-embedder.mjs <profile_root> [--timeout-ms N] [--retries N]");
  process.exit(2);
}

function argValue(flag, fallback) {
  const i = process.argv.indexOf(flag);
  return i >= 0 && process.argv[i + 1] ? Number(process.argv[i + 1]) : fallback;
}
const TIMEOUT_MS = argValue("--timeout-ms", 600_000);
const RETRIES = argValue("--retries", 3);

const distPath = join(profileRoot, "npm", "node_modules", "@samfp", "pi-memory", "dist", "index.js");
if (!existsSync(distPath)) {
  console.error(`FATAL pi-memory dist not found: ${distPath}`);
  process.exit(2);
}
const dist = readFileSync(distPath, "utf8");
const match = dist.match(/var MODEL = "([^"]+)"/);
if (!match) {
  console.error("FATAL could not read embedder model id from patched dist");
  process.exit(2);
}
const MODEL = match[1];

// Resolve @xenova/transformers from the profile's own npm tree. ESM resolution
// is relative to this file, not the cwd, so import the package by absolute
// path into the profile's node_modules.
const transformersEntry = join(profileRoot, "npm", "node_modules", "@xenova", "transformers");
if (!existsSync(transformersEntry)) {
  console.error(`FATAL @xenova/transformers not installed in ${join(profileRoot, "npm")}`);
  process.exit(2);
}
let transformers;
try {
  transformers = await import(pathToFileURL(join(transformersEntry, "src", "transformers.js")).href);
} catch (err) {
  console.error(`FATAL could not load @xenova/transformers: ${err?.message ?? err}`);
  process.exit(2);
}
const { pipeline, env } = transformers;
env.allowRemoteModels = true;
env.useBrowserCache = false;

async function attempt(n) {
  const started = Date.now();
  const timer = setTimeout(() => {
    console.error(`  attempt ${n}: still downloading after ${Math.round((Date.now() - started) / 1000)}s ...`);
  }, 30_000);
  try {
    const pipe = await pipeline("feature-extraction", MODEL, { quantized: true });
    const out = await pipe("warmup", { pooling: "mean", normalize: true });
    clearTimeout(timer);
    const secs = ((Date.now() - started) / 1000).toFixed(1);
    console.log(`PASS warmed ${MODEL} (${out.data.length}d) in ${secs}s`);
    return true;
  } catch (err) {
    clearTimeout(timer);
    console.error(`  attempt ${n} failed: ${err?.message ?? err}`);
    return false;
  }
}

for (let n = 1; n <= RETRIES; n++) {
  const ok = await Promise.race([
    attempt(n),
    new Promise((resolve) => setTimeout(() => {
      console.error(`  attempt ${n} exceeded timeout ${TIMEOUT_MS}ms`);
      resolve(false);
    }, TIMEOUT_MS)),
  ]);
  if (ok) process.exit(0);
  if (n < RETRIES) console.error(`  retrying (${n}/${RETRIES}) ...`);
}

console.error(`FAIL could not warm ${MODEL} after ${RETRIES} attempts`);
process.exit(1);
