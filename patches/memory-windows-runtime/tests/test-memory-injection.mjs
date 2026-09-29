// Execute extracted patched functions against a synthetic store; never open a real memory DB.
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
const file = process.argv[2];
if (!file) throw new Error("usage: node test-memory-injection.mjs <patched-dist>");
const src = readFileSync(resolve(file), "utf8");
function region(start, end) {
  const a = src.indexOf(start), b = src.indexOf(end, a + start.length);
  if (a < 0 || b < 0) throw new Error(`missing injector region: ${start}`);
  return src.slice(a, b);
}
const helpers = region("// pi-memory scoped injection v2", "function projectSlug(cwd) {");
const context = region("async function buildContextBlock(", "async function buildSelectiveBlock(");
const selective = region("async function buildSelectiveBlock(", "function getRelevantLessons(");
const lessons = region("function getRelevantLessons(", "function buildFallbackBlock(");
const fallback = region("function buildFallbackBlock(", "var STALE_WARNING_DAYS = 30;");
const compiled = new Function("store", "cwd", "prompt", "config", `
  const MAX_CONTEXT_CHARS = 8000, SEARCH_LIMIT = 20, LESSON_SEARCH_LIMIT = 20;
  const MEMORY_DRIFT_CAVEAT = "Verify memories before acting on them.";
  const formatSection = (title, items) => '## ' + title + '\\n' + items.map((x) => '- ' + x).join('\\n');
  const formatSemantic = (r) => r.key.split('.').slice(1).join('.') + ': ' + r.value;
  const keyDomainPrefix = (key) => key.split('.').length >= 3 ? key.split('.').slice(0, 2).join('.') + '.' : '';
  const embed = async () => new Float32Array([1]);
  const fromBlob = (v) => v;
  const similarity = () => 1;
  const backfillEmbeddings = async () => {};
  const projectSlug = (path) => path.toLowerCase();
  ${helpers}\n${context}\n${selective}\n${lessons}\n${fallback}
  return buildContextBlock(store, cwd, prompt, config);
`);
function ensure(ok, message) { if (!ok) throw new Error(message); }
const root = String.raw`C:\example\main`, tree = String.raw`C:\example\trees\branch`;
const alias = { factProjectAliases: [
  { path: root.replaceAll("\\", "/"), scope: "alpha" },
  { path: String.raw`C:\example\trees`, scope: "alpha", includeChildren: true }
], lessonInjection: "selective" };
const facts = Array.from({ length: 95 }, (_, i) => ({
  key: `project.alpha.fact${i}`, value: `complete line ${i} ` + "X".repeat(95)
}));
const foreign = [
  { key: "project.beta.foreign", value: "WRONG_PROJECT_FACT" },
  { key: "project.beta.sibling", value: "WRONG_PROJECT_SIBLING" }
];
const globals = [{ key: "pref.general", value: "shared preference" }];
const allFacts = [...facts, ...foreign, ...globals];
const localLessons = Array.from({ length: 3 }, (_, i) => ({
  id: i + 1, rule: `local-${i}-` + "L".repeat(90), negative: true, category: "general",
  project: tree.toLowerCase(), source: "user"
}));
const otherLessons = Array.from({ length: 30 }, (_, i) => ({
  id: i + 5, rule: `global-${i}-` + "G".repeat(90), negative: true,
  category: "general", project: null, source: "model"
}));
const badLesson = { id: 100, rule: "WRONG_PROJECT_LESSON", negative: true,
  category: "general", project: "some-other-project", source: "user" };
const touched = [];
const store = {
  searchSemantic(query) { return query === "alpha" ? [facts[0]] : [foreign[0], facts[1], globals[0]]; },
  getAllEmbeddings() { return [foreign[0], facts[2]].map((f) => ({ key: f.key, embedding: [1] })); },
  getSemantic(key) { return allFacts.find((f) => f.key === key); },
  listSemantic(prefix, limit) { return allFacts.filter((f) => f.key.startsWith(prefix)).slice(0, limit); },
  searchLessons() { return [badLesson, ...otherLessons]; },
  listLessons(category, limit, project) {
    const pool = [...localLessons, ...otherLessons, badLesson];
    return pool.filter((l) => (category === undefined || l.category === category)
      && (project === undefined || l.project === project || l.project === null)).slice(0, limit);
  },
  touchAccessed(keys) { touched.push(...keys); }
};
const knownFacts = new Set(allFacts.map((f) => `${f.key.split('.').slice(1).join('.')}: ${f.value}`));
const knownLessons = new Set([...localLessons, ...otherLessons, badLesson].map((l) => `DON'T: ${l.rule}`));
for (const [cwd, prompt, opts] of [
  [tree, "topic", alias], [tree.replaceAll("\\", "/"), "topic", alias],
  [root, "", alias], [String.raw`C:\example\beta`, "topic", alias]
]) {
  const result = await compiled(store, cwd, prompt, opts), text = result.text;
  ensure(text.length <= 8000 && text.endsWith("</memory>"), `${cwd}: incomplete or oversized block`);
  ensure(!text.includes("... (truncated)"), `${cwd}: truncated mid-record`);
  if (cwd.endsWith("beta")) {
    ensure(!text.includes("alpha.fact"), `${cwd}: alpha fact entered beta project`);
  } else {
    ensure(!text.includes("WRONG_PROJECT_FACT") && !text.includes("WRONG_PROJECT_SIBLING"),
      `${cwd}: foreign fact entered the block`);
  }
  ensure(!text.includes("WRONG_PROJECT_LESSON"), `${cwd}: foreign lesson entered the block`);
  if (cwd.toLowerCase() === tree.toLowerCase()) ensure(text.includes("local-0-"), "local lesson starved by global hits");
  for (const line of text.split("\n").filter((l) => l.startsWith("- "))) {
    const body = line.slice(2);
    ensure(knownFacts.has(body) || knownLessons.has(body) || body === "pref.general: shared preference",
      `${cwd}: partial or unknown record: ${body.slice(0, 80)}`);
  }
}
ensure(touched.some((key) => key.startsWith("project.alpha.")), "local fact was not touched");
console.log("PASS scoped memory: aliases, FTS, embeddings, siblings, local lessons, fallback, complete records");
