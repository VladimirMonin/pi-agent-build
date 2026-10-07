// Structural regression only; real provider evidence comes from the paid canary.
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const file=process.argv[2];assert(file,'usage: node test-memory-embedder.mjs <patched-dist>');
const src=readFileSync(file,'utf8');
assert(src.includes('await searchMemory(event.prompt, SEARCH_LIMIT, ctx)'));
assert(src.includes('injectorConfig, recall)'));
assert(src.includes('function createEmbedder('));
assert(src.includes('function reciprocalRankFusion('));
assert(src.includes('config.embedding = parseEmbeddingSettings(m.embedding) ?? config.embedding;'));
assert(src.includes('config.injectionMode = m.injectionMode;'));
assert(src.includes('a.length !== b.length'),'Mixed dimensions must not be scored together');
assert(!src.includes('Xenova/'));assert(!src.includes('async function withTimeout('));
console.log('PASS upstream provider/RRF automatic recall, config preservation, dimension separation; no Xenova');
