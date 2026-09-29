import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const dist = resolve(process.argv[2] ?? "");
if (!process.argv[2]) throw new Error("usage: node test-memory-embedder.mjs <patched-dist>");
const src = readFileSync(dist, "utf8").replace(/\r\n/g, "\n");

// The multilingual embedder must be selected, keep 384 dimensions (mean
// pooling) so existing vectors stay valid, and stay offline (no API key).
const MODEL_LINE = 'var MODEL = "Xenova/paraphrase-multilingual-MiniLM-L12-v2";';
if (!src.includes(MODEL_LINE)) {
  throw new Error("multilingual embedder model is not selected");
}
if (src.includes('var MODEL = "Xenova/all-MiniLM-L6-v2";')) {
  throw new Error("English-only all-MiniLM-L6-v2 is still present");
}
if (!src.includes("// pi-memory multilingual embedder: Russian-capable, 384d")) {
  throw new Error("embedder marker comment missing");
}

// Pooling must stay mean/normalize — the multilingual MiniLM is an encoder.
if (!src.includes('{ pooling: "mean", normalize: true }')) {
  throw new Error("mean pooling was removed; multilingual MiniLM requires it");
}

// The embedder must remain local: no HTTP endpoint or API key in the embed path.
const embedStart = src.indexOf("async function embed(text) {");
const embedEnd = src.indexOf("function similarity(", embedStart);
if (embedStart < 0 || embedEnd < 0) throw new Error("embed()/similarity() not found");
const embedBody = src.slice(embedStart, embedEnd);
if (/fetch\(|https?:\/\//.test(embedBody)) {
  throw new Error("embed() must stay local (no network calls)");
}

// Dimension compatibility: the semantic table stores raw BLOBs, and
// similarity() compares by min-length. Multilingual MiniLM is 384d like stock,
// so no reindex is needed — assert the threshold was not silently changed.
if (!src.includes("const SEMANTIC_THRESHOLD = 0.25;")) {
  throw new Error("SEMANTIC_THRESHOLD changed; reindex/retune required");
}

console.log("PASS multilingual embedder: 384d, mean pooling, offline, threshold intact");
