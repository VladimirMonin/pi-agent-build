"""Guarded pi-memory 1.6.0 injector: scope, whole records and upstream hybrid recall.

No private project names, paths, memory values, or credentials belong here.
The caller first validates the immutable stock 1.6.0 SHA before invoking this module.
"""

INJECTION_MARKER = "// pi-memory scoped injection v3"


def replace_once(text: str, old: str, new: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"injector anchor count {count}, expected 1: {old.splitlines()[0][:75]}")
    return text.replace(old, new, 1)


def replace_region(text: str, start: str, end: str, replacement: str) -> str:
    if text.count(start) != 1 or text.count(end) != 1:
        raise RuntimeError(f"injector region anchors not unique: {start[:65]}")
    a = text.index(start)
    b = text.index(end, a + len(start))
    return text[:a] + replacement + text[b:]


HELPERS = r'''// pi-memory scoped injection v3: normalize fact scopes independently of legacy lesson tags.
function projectFactScope(cwd, config) {
  if (!cwd) return "";
  const path = cwd.replaceAll("\\", "/").replace(/\/+$/, "").toLowerCase();
  for (const alias of config?.factProjectAliases ?? []) {
    if (!alias || typeof alias.path !== "string" || typeof alias.scope !== "string") continue;
    const prefix = alias.path.replaceAll("\\", "/").replace(/\/+$/, "").toLowerCase();
    const scope = alias.scope.toLowerCase();
    if (!prefix || !/^[a-z0-9_-]+$/.test(scope)) continue;
    if (path === prefix || alias.includeChildren === true && path.startsWith(prefix + "/")) return scope;
  }
  return path.split("/").filter(Boolean).pop() || "";
}
// Select only complete lines. Section quotas reserve room for local corrections,
// relevant facts and approaches; a second pass uses any remaining budget.
function fitMemorySections(groups) {
  const selected = new Map(groups.map((g) => [g.title, []]));
  const render = () => {
    const sections = groups.filter((g) => selected.get(g.title).length)
      .map((g) => formatSection(g.title, selected.get(g.title)));
    return `<memory>\n${sections.join("\n")}\n\n${MEMORY_DRIFT_CAVEAT}\n</memory>`;
  };
  const ordered = [...groups].sort((a, b) => a.priority - b.priority);
  for (const limited of [true, false]) {
    for (const group of ordered) {
      const chosen = selected.get(group.title);
      for (const line of group.lines) {
        if (chosen.includes(line)) continue;
        const used = chosen.reduce((n, value) => n + value.length + 2, 0);
        if (limited && used + line.length + 2 > group.quota) continue;
        chosen.push(line);
        if (render().length > MAX_CONTEXT_CHARS) chosen.pop();
      }
    }
  }
  const count = [...selected.values()].reduce((n, lines) => n + lines.length, 0);
  return { text: count ? render() : "", selected };
}
'''

SELECTIVE = r'''async function buildSelectiveBlock(store, prompt, cwd, config, recall = []) {
  const mode = config?.lessonInjection ?? "all";
  const slug = cwd ? projectSlug(cwd) : "";
  const factScope = projectFactScope(cwd, config);
  const belongsHere = (key) => !key.startsWith("project.") || key.split(".")[1] === factScope;
  const results = [...recall];
  const recallKeys = new Set(results.map((r) => r.key));
  for (const r of store.searchSemantic(prompt, SEARCH_LIMIT)) {
    if (!recallKeys.has(r.key)) { results.push(r); recallKeys.add(r.key); }
  }
  if (factScope) {
    const seenProject = new Set(results.map((r) => r.key));
    for (const r of store.searchSemantic(factScope, 5)) {
      if (!seenProject.has(r.key)) { results.push(r); seenProject.add(r.key); }
    }
  }
  const filteredResults = results.filter((r) => belongsHere(r.key));
  const seen = new Set(filteredResults.map((r) => r.key));
  // Upstream searchMemory supplies hybrid/RRF results; no Xenova backend here.
  const semanticKeys = new Set(recall.filter((r) => belongsHere(r.key)).map((r) => r.key));
  const expandedPrefixes = new Set();
  for (const r of [...filteredResults]) {
    const prefix = keyDomainPrefix(r.key);
    if (!prefix || expandedPrefixes.has(prefix)) continue;
    expandedPrefixes.add(prefix);
    const limit = semanticKeys.has(r.key) ? 20 : 5;
    for (const sibling of store.listSemantic(prefix, limit)) {
      if (belongsHere(sibling.key) && !seen.has(sibling.key)) {
        filteredResults.push(sibling);
        seen.add(sibling.key);
      }
    }
  }
  // Exact embedding hits keep their relevance order; FTS hits and siblings follow.
  const ranks = new Map([...semanticKeys].map((key, i) => [key, i]));
  filteredResults.sort((a, b) => (ranks.get(a.key) ?? 1e6) - (ranks.get(b.key) ?? 1e6));
  const lessons = mode === "selective" ? getRelevantLessons(store, prompt, cwd, config)
    : store.listLessons(void 0, 50, slug || void 0).filter((l) => l.project == null || l.project === slug || l.project === factScope);
  const localFirst = (a, b) => Number(b.project === slug) - Number(a.project === slug)
    || Number(b.source === "user") - Number(a.source === "user");
  const negatives = lessons.filter((l) => l.negative).sort(localFirst)
    .map((l) => `DON'T: ${l.rule}${l.category !== "general" ? ` [${l.category}]` : ""}`);
  const positives = lessons.filter((l) => !l.negative).sort(localFirst)
    .map((l) => `${l.rule}${l.category !== "general" ? ` [${l.category}]` : ""}`);
  const groups = [
    { title: "Relevant Memory", lines: filteredResults.map(formatSemantic), quota: 4300, priority: 1 },
    { title: "Learned Corrections", lines: negatives, quota: 2900, priority: 0 },
    { title: "Validated Approaches", lines: positives, quota: 1800, priority: 2 }
  ];
  const fitted = fitMemorySections(groups);
  const factLines = fitted.selected.get("Relevant Memory");
  if (factLines.length) {
    store.touchAccessed(filteredResults.filter((r) => factLines.includes(formatSemantic(r))).map((r) => r.key));
  }
  return { text: fitted.text, stats: { semantic: factLines.length,
    lessons: fitted.selected.get("Learned Corrections").length + fitted.selected.get("Validated Approaches").length } };
}
'''

LESSONS = r'''function getRelevantLessons(store, prompt, cwd, config) {
  const seen = new Set();
  const result = [];
  function add(items) {
    for (const lesson of items) {
      if (!seen.has(lesson.id)) { seen.add(lesson.id); result.push(lesson); }
    }
  }
  // Reserve a small local core before global/topic search can fill the limit.
  const slug = cwd ? projectSlug(cwd) : "";
  if (slug) add(store.listLessons(void 0, 50, slug).filter((l) => l.project === slug).slice(0, 3));
  add(store.searchLessons(prompt, LESSON_SEARCH_LIMIT));
  if (slug) add(store.searchLessons(slug, 5));
  add(store.listLessons("general", 10));
  const normalized = cwd ? cwd.replaceAll("\\", "/").split("/").filter(Boolean).pop().toLowerCase() : "";
  const factScope = projectFactScope(cwd, config);
  return result.filter((l) => l.project == null || l.project === slug || l.project === normalized || l.project === factScope)
    .slice(0, LESSON_SEARCH_LIMIT);
}
'''

FALLBACK = r'''function buildFallbackBlock(store, cwd, config) {
  const slug = cwd ? projectSlug(cwd) : "";
  const factScope = projectFactScope(cwd, config);
  const projects = store.listSemantic("project.", 50)
    .filter((entry) => entry.key.split(".")[1] === factScope);
  const lessons = store.listLessons(void 0, 50, slug || void 0)
    .filter((l) => l.project == null || l.project === slug || l.project === factScope);
  const localFirst = (a, b) => Number(b.project === slug) - Number(a.project === slug)
    || Number(b.source === "user") - Number(a.source === "user");
  const groups = [
    { title: "User Preferences", lines: store.listSemantic("pref.", 50).map(formatSemantic), quota: 1100, priority: 2 },
    { title: "Project Context", lines: projects.map(formatSemantic), quota: 2900, priority: 1 },
    { title: "Tool Preferences", lines: store.listSemantic("tool.", 20).map(formatSemantic), quota: 700, priority: 3 },
    { title: "Learned Corrections", lines: lessons.filter((l) => l.negative).sort(localFirst)
      .map((l) => `DON'T: ${l.rule}${l.category !== "general" ? ` [${l.category}]` : ""}`), quota: 2700, priority: 0 },
    { title: "Validated Approaches", lines: lessons.filter((l) => !l.negative).sort(localFirst)
      .map((l) => `${l.rule}${l.category !== "general" ? ` [${l.category}]` : ""}`), quota: 1800, priority: 5 },
    { title: "User", lines: store.listSemantic("user.", 10).map(formatSemantic), quota: 550, priority: 4 }
  ];
  const fitted = fitMemorySections(groups);
  const lessonCount = fitted.selected.get("Learned Corrections").length
    + fitted.selected.get("Validated Approaches").length;
  const semanticCount = [...fitted.selected.entries()].reduce((n, [title, lines]) =>
    n + (title === "Learned Corrections" || title === "Validated Approaches" ? 0 : lines.length), 0);
  return { text: fitted.text, stats: { semantic: semanticCount, lessons: lessonCount } };
}
'''


def apply_injection(text: str) -> str:
    """Apply only to the verified stock-derived base (not to an arbitrary bundle)."""
    if INJECTION_MARKER in text:
        raise RuntimeError("injector already patched")
    text = replace_once(text, "function projectSlug(cwd) {", HELPERS + "function projectSlug(cwd) {")
    text = replace_once(text, "async function buildContextBlock(store, cwd, prompt, config) {", "async function buildContextBlock(store, cwd, prompt, config, recall = []) {")
    text = replace_once(text, "return buildSelectiveBlock(store, prompt, cwd, config);", "return buildSelectiveBlock(store, prompt, cwd, config, recall);")
    text = replace_once(text, "  return buildFallbackBlock(store, cwd);", "  return buildFallbackBlock(store, cwd, config);")
    text = replace_region(text, "async function buildSelectiveBlock(store, prompt, cwd, config) {",
                          "function getRelevantLessons(store, prompt, cwd) {", SELECTIVE)
    text = replace_region(text, "function getRelevantLessons(store, prompt, cwd) {",
                          "function buildFallbackBlock(store, cwd) {", LESSONS)
    text = replace_region(text, "function buildFallbackBlock(store, cwd) {",
                          "var STALE_WARNING_DAYS = 30;", FALLBACK)
    text = replace_once(text,
        'var PI_MEMORY_KNOWN_KEYS = ["localPath", "lessonInjection", "consolidationModel", "perTurnInjection", "injectionMode", "embedding"];',
        'var PI_MEMORY_KNOWN_KEYS = ["localPath", "lessonInjection", "consolidationModel", "perTurnInjection", "injectionMode", "embedding", "factProjectAliases"];')
    text = replace_once(text,
        "function mergeMemorySettings(config, memorySettings) {",
        "function mergeMemorySettings(config, memorySettings, allowAliases = false) {")
    text = replace_once(text,
        "    mergeMemorySettings(config, settings?.memory);",
        "    mergeMemorySettings(config, settings?.memory, true);")
    text = replace_once(text,
        '''  config.embedding = parseEmbeddingSettings(m.embedding) ?? config.embedding;
}''',
        '''  config.embedding = parseEmbeddingSettings(m.embedding) ?? config.embedding;
  if (allowAliases && Array.isArray(m.factProjectAliases)) {
    config.factProjectAliases = m.factProjectAliases.filter((alias) => alias &&
      typeof alias.path === "string" && typeof alias.scope === "string");
  }
}''')
    return text


def is_injection_safe(text: str) -> bool:
    return (INJECTION_MARKER in text and "function projectFactScope(cwd, config)" in text
            and "function fitMemorySections(groups)" in text
            and "recall.filter((r) => belongsHere(r.key))" in text
            and "if (belongsHere(sibling.key)" in text
            and "return buildFallbackBlock(store, cwd, config);" in text
            and '"factProjectAliases"' in text
            and 'text.slice(0, MAX_CONTEXT_CHARS - 20)' not in text)
