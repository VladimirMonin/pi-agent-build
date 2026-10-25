#!/usr/bin/env python3
"""Exact pi-session-search 1.6.0 roots, safe discovery and embedding prefixes."""
from __future__ import annotations
import argparse
import datetime as dt
import hashlib
import json
import pathlib
import shutil
import subprocess
import sys

VERSION = "1.6.0"
HERE = pathlib.Path(__file__).resolve().parent
STORE = HERE / "store" / VERSION
REL_FILES = tuple(map(pathlib.Path, ("src/config.ts", "src/parser.ts", "dist/index.js", "src/index.ts",
                                   "src/utils.ts", "src/session-index.ts", "dist/index-worker.js", "src/fts-index.ts", "src/index-service.ts", "src/embedder.ts")))
STOCK_HASHES = (
    "e6103a7010615e059a01a3954d3135092b46e197cec6ce878ae84271c9211427",
    "2f67818bc768a3f7e89aa2f8135cf8fb70611b148dfbd7ef41e8cf7d3dd1746a",
    "9d011f994d6de8bb873ba242a9b705ab560046a4eae3c66c75068c98aa29090b",
    "e2e36ee96ca972d8e98bc9dec857ca1ac883c1063f8f8ca11786713d3f1574bc",
    "fd8cff09d6557df8b1dd4b55770aa4fdbdd37546a0da454bb25596055926bf5e",
    "4c0fa27ae77ff037fe393f24efda51fb7ca2b995143b0560d5b09902f82a8622",
    "7901989942a790c549d328a3d49e491090f514c0b5a650a4547dad9b73a99b57",
    "9f01a4fe3cf51ad1db8663be34603b9d71cee5ead30fbd18d0e7d590bb92316f",
    "369d4d64531f82fcaae93f1354813328db73aead72488263f5e7d0f928d93d58",
    "0aa80d061c9973993c85b4df85c6f342f2180351003966afab94ae507008e5be",
)
BACKUP_ROOT = pathlib.Path()
TIMER_NEW = '''const runSync = () => {
        let timeout;
        return Promise.race([
          index.sync({onProgress: (msg) => ctx.ui.setStatus("session-search", msg), onError: notifySyncError(ctx)}),
          new Promise((resolve) => { timeout = scheduleTimer(() => resolve(null), SYNC_TIMEOUT_MS); })
        ]).finally(() => {
          clearTimeout(timeout);
          pendingTimers.delete(timeout);
        });
      };'''


def package_root(agent_dir):
    return agent_dir / "npm" / "node_modules" / "pi-session-search"


def configure_paths(agent_dir):
    global BACKUP_ROOT
    BACKUP_ROOT = agent_dir / ".pi-agent-build-backups" / "session-search-profile"


def assert_version(root):
    version = json.loads((root / "package.json").read_text(encoding="utf-8")).get("version")
    if version != VERSION:
        raise RuntimeError(f"unsupported {version}; expected exactly {VERSION}")


def replace_once(text, old, new, label):
    if text.count(old) != 1:
        raise RuntimeError(f"{label}: expected exactly one anchor")
    return text.replace(old, new, 1)


def read_files(root):
    return {rel: (root / rel).read_bytes() for rel in REL_FILES}


def replace_body(text, start, end, body):
    if text.count(start) != 1 or text.count(end) != 1:
        raise RuntimeError(f"ambiguous anchors: {start}")
    a = text.index(start)
    b = text.index(end, a)
    return text[:a] + body + text[b:]


def patch_parser(text, runtime_only, dist=False, *, worker=False):
    join = "join2" if dist and not worker else "join"
    typed = "" if dist else ": string"
    exported = "" if dist else "export "
    def body(name, override, leaf, modern=""):
        fallback = f'{join}(process.env.HOME || "~", ".pi", "agent", "{leaf}")'
        if not runtime_only:
            fallback = f'(process.env.PI_CODING_AGENT_DIR?.trim() ? {join}(process.env.PI_CODING_AGENT_DIR.trim(), "{leaf}") : {fallback})'
        modern = f"process.env.{modern} || " if modern else ""
        return f'{exported}function {name}(){typed} {{\n  return process.env.{override} || {modern}{fallback}; // local-profile-patch\n}}'
    # Source contains documentation between these functions: replace bodies only.
    for name, override, leaf, modern in [
        ("getDefaultSessionDir", "PI_SESSION_DIR", "sessions", "PI_CODING_AGENT_SESSION_DIR"),
        ("getDefaultArchiveDir", "PI_SESSION_ARCHIVE_DIR", "sessions-archive", ""),
    ]:
        start = f"function {name}(){typed} {{"
        if text.count(start) != 1:
            raise RuntimeError(f"missing parser anchor: {name}")
        a = text.index(start)
        b = text.index("\n}", a) + 2
        text = text[:a] + body(name, override, leaf, modern) + text[b:]
    return text


def patch_roots(text):
    text = 'import { homedir as sessionHomedir } from "node:os";\n' + text
    return text.replace('process.env.HOME || "~"', 'sessionHomedir()').replace('process.env.HOME || ""', 'sessionHomedir()')


def patch_discovery(text, *, source=False, worker=False):
    """Retain deletion authority only for successfully enumerated directories."""
    join = "join" if source or worker else "join2"
    text = 'import { resolve as sourceResolve, relative as sourceRelative, isAbsolute as sourceIsAbsolute, sep as sourceSep } from "node:path";\n' + text
    signature = '''export function discoverSessionFiles(
  extraSessionDirs: string[] = [],
  extraArchiveDirs: string[] = [],
  sessionDir?: string,
  archiveDir?: string,
): { files: { file: string; archived: boolean }[]; scannedDirs: string[]; unavailableDirs: string[] } {''' if source else 'function discoverSessionFiles(extraSessionDirs = [], extraArchiveDirs = [], sessionDir, archiveDir) {'
    array_type = ': string[]' if source else ''
    results_type = ': { file: string; archived: boolean }[]' if source else ''
    walk_signature = 'function walkJsonl(dir: string, scannedDirs: string[], unavailableDirs: string[]): string[] {' if source else 'function walkJsonl(dir, scannedDirs, unavailableDirs) {'
    predicate_signature = 'export function canRemoveSession(file: string, scannedDirs: string[], unavailableDirs: string[]): boolean {' if source else 'function canRemoveSession(file, scannedDirs, unavailableDirs) {'
    dir_type = ': string' if source else ''
    body = f'''{signature}
  const sDirs = [sessionDir ?? getDefaultSessionDir(), ...extraSessionDirs];
  const aDirs = [archiveDir ?? getDefaultArchiveDir(), ...extraArchiveDirs];
  const files{results_type} = [];
  const scannedDirs{array_type} = [];
  const unavailableDirs{array_type} = [];
  for (const [dirs, archived] of [[sDirs, false], [aDirs, true]]{' as const' if source else ''}) {{
    for (const dir of dirs) {{
      for (const file of walkJsonl(dir, scannedDirs, unavailableDirs)) {{
        files.push({{ file, archived }});
      }}
    }}
  }}
  return {{ files, scannedDirs, unavailableDirs }};
}}

{walk_signature}
  const files{array_type} = [];
  try {{
    const entries = readdirSync(dir, {{ withFileTypes: true }});
    scannedDirs.push(dir);
    for (const entry of entries) {{
      const full = {join}(dir, entry.name);
      if (entry.isDirectory()) {{
        files.push(...walkJsonl(full, scannedDirs, unavailableDirs));
      }} else if (entry.name.endsWith(".jsonl") && entry.name !== "pins.json" && entry.name !== "active-sessions.json") {{
        files.push(full);
      }}
    }}
  }} catch {{
    unavailableDirs.push(dir);
  }}
  return files;
}}

{predicate_signature}
  const within = (dir{dir_type}) => {{
    const rel = sourceRelative(sourceResolve(dir), sourceResolve(file));
    return rel === "" || (rel !== ".." && !rel.startsWith(".." + sourceSep) && !sourceIsAbsolute(rel));
  }};
  return scannedDirs.some(within) && !unavailableDirs.some(within);
}}

'''
    # Keep the source header-read documentation and every parse/read predicate.
    start = ('export ' if source else '') + 'function discoverSessionFiles('
    end = '// ─── Header-only read' if source else 'function readSessionId('
    return replace_body(text, start, end, body)


def patch_safe_removal(text, *, source=False):
    if source:
        text = replace_once(text, 'import { discoverSessionFiles, parseSession, readSessionId }',
                            'import { discoverSessionFiles, canRemoveSession, parseSession, readSessionId }', 'discovery import')
    text = text.replace('const discovered = discoverSessionFiles(',
                        'const { files: discovered, scannedDirs, unavailableDirs } = discoverSessionFiles(')
    text = text.replace('if (!discoveredIds.has(id)) {',
                        'if (!discoveredIds.has(id) && canRemoveSession(this.data.sessions[id].session.file, scannedDirs, unavailableDirs)) {')
    text = text.replace('if (!idToFile.has(id)) {',
                        'if (!idToFile.has(id) && canRemoveSession(currentById.get(id)' + ('!' if source else '') + '.file, scannedDirs, unavailableDirs)) {')
    # A discovered file that cannot be stat'ed/read is not proof of deletion.
    text = text.replace("} catch { continue; }", "} catch { unavailableDirs.push(file); continue; }")
    text = text.replace("continue; // can't stat — skip", "unavailableDirs.push(file); continue; // unavailable, not deleted")
    if not source:
        text = text.replace('} catch {\n        continue;\n      }', '} catch {\n        unavailableDirs.push(file); continue;\n      }')
        text = text.replace('} catch {\n          continue;\n        }', '} catch {\n          unavailableDirs.push(file); continue;\n        }')
    return text.replace('if (!id) continue;', 'if (!id) { unavailableDirs.push(file); continue; }')


def patch_partial_fts(text, *, source=False):
    old = '''  count(): number {
    return (this.db.prepare("SELECT count(*) as c FROM s").get() as any).c;
  }''' if source else '''  count() {
    return this.db.prepare("SELECT count(*) as c FROM s").get().c;
  }'''
    new = '''  ids(): Set<string> {
    return new Set((this.db.prepare("SELECT DISTINCT id FROM s").all() as { id: string }[]).map(row => row.id));
  }''' if source else '''  ids() {
    return new Set(this.db.prepare("SELECT DISTINCT id FROM s").all().map(row => row.id));
  }'''
    text = replace_once(text, old, new, 'hybrid FTS IDs')
    text = replace_once(text, 'sessionCount > 0 && this.fts.count() === 0', 'sessionCount > 0', 'partial FTS load')
    signature = 'private populateFtsFromIndex(): void {' if source else 'populateFtsFromIndex() {'
    text = replace_once(text, signature, signature + '\n    const existingIds = this.fts.ids();', 'FTS existing IDs')
    pos = text.index(signature)
    prefix, tail = text[:pos], text[pos:]
    tail = tail.replace('for (const [id, entry] of Object.entries(this.data.sessions)) {',
                        'for (const [id, entry] of Object.entries(this.data.sessions)) {\n      if (existingIds.has(id)) continue;', 1)
    text = prefix + tail
    text = text.replace("Populate FTS side-car if it's empty but the JSON index has sessions", "Fill missing legacy FTS IDs from saved metadata, preserving existing full text")
    return text.replace('Used when the JSON index is loaded but the FTS DB is empty (e.g. first', 'Used when the JSON index has IDs missing from the FTS DB (e.g. first')


def patch_index(text, source=False):
    if source:
        text = replace_once(text, 'import { existsSync } from "node:fs";', 'import { existsSync, realpathSync } from "node:fs";', "fs import")
        text = replace_once(text, 'import { resolve } from "node:path";', 'import { resolve, relative, isAbsolute, sep } from "node:path";\nimport { getDefaultSessionDir, getDefaultArchiveDir } from "./parser";', "path import")
    else:
        text = replace_once(text, 'import { existsSync as existsSync4 } from "node:fs";', 'import { existsSync as existsSync4, realpathSync } from "node:fs";', "dist fs")
        text = replace_once(text, 'import { resolve } from "node:path";', 'import { resolve, relative, isAbsolute, sep } from "node:path";', "dist path")
    for key, fn in [("sessionDir", "getDefaultSessionDir"), ("archiveDir", "getDefaultArchiveDir")]:
        text = replace_once(text, f"{key}: config?.{key},", f"{key}: config?.{key} ?? {fn}(),", "worker roots")
    home_anchor = '      const home = process.env.HOME || "";' if not source else '      const home = process.env.HOME || "";'
    # Replace the complete read-path guard; index and reader use identical roots.
    a = text.index(home_anchor, text.index('name: "session_read"'))
    end = '      const limit = Math.min(params.limit ?? 50, 100);'
    b = text.index(end, a)
    exists = "existsSync" if source else "existsSync4"
    guard = f'''      const allowedRoots = [
        resolve(currentConfig?.sessionDir ?? getDefaultSessionDir()),
        resolve(currentConfig?.archiveDir ?? getDefaultArchiveDir()),
        ...(currentConfig?.extraSessionDirs ?? []).map((d) => resolve(d)),
        ...(currentConfig?.extraArchiveDirs ?? []).map((d) => resolve(d))
      ];
      const resolvedPath = {exists}(filePath) ? realpathSync(filePath) : resolve(filePath);
      if (!allowedRoots.some((root) => {{
        const canonicalRoot = {exists}(root) ? realpathSync(root) : resolve(root);
        const rel = relative(canonicalRoot, resolvedPath);
        return rel === "" || (rel !== ".." && !rel.startsWith(".." + sep) && !isAbsolute(rel));
      }})) {{
        return textResult(`Access denied: path "${{filePath}}" is outside the allowed session directories.`);
      }}
'''
    text = text[:a] + guard + text[b:]
    timer = TIMER_NEW
    if source:
        timer = timer.replace("let timeout;", "let timeout: ReturnType<typeof setTimeout> | undefined;").replace("new Promise((resolve)", "new Promise<null>((resolve)")
    return replace_body(text, "const runSync = () =>", "const initialSync = async () =>", timer + "\n\n      ")


def patch_display(text, typed=False):
    if typed and 'export function createIndexService' in text:
        text = replace_once(text, 'import { Worker } from "node:worker_threads";',
                            'import { Worker } from "node:worker_threads";\nimport { buildSummary } from "./utils";', 'service display import')
    signature = 'function slugToProject(slug: string): string {' if typed else 'function slugToProject(slug) {'
    replacement = 'function slugToProject(slug: string, cwd?: string): string {' if typed else 'function slugToProject(slug, cwd) {'
    if signature in text:
        text = replace_once(text, signature, replacement, 'project display signature')
        text = replace_once(text,
            '  if (!slug.startsWith("--") || !slug.endsWith("--")) return slug;\n  return slug.slice(2, -2).replace(/-/g, "/");',
            '  return typeof cwd === "string" && cwd.trim() ? cwd : slug; // display only: slug is not reversible',
            'project display body')
    text = text.replace('slugToProject(s.projectSlug)', 'slugToProject(s.projectSlug, s.cwd)')
    # Refresh old derived display on read. Do not mutate source JSONL, identities,
    # filters, stored vectors or trigger an embedding/reindex migration.
    text = text.replace('summary: entry.summary', 'summary: buildSummary(entry.session)')
    text = text.replace('summary: String(r.summary ?? "")', 'summary: buildSummary(JSON.parse(String(r.json)))')
    text = text.replace('summary: String(row.summary ?? "")', 'summary: buildSummary(JSON.parse(String(row.json)))')
    return text


def patch_embedding_prefixes(text, *, source=False):
    """One model table and two literal overrides; no provider/index migration."""
    if source:
        text = replace_once(text, '  dimensions?: number;\n}',
            '  dimensions?: number;\n  /** Override model defaults; an empty string disables the prefix. */\n  documentPrefix?: string;\n  queryPrefix?: string;\n}', 'prefix config')
    signature = 'export function createEmbedder(config: EmbedderConfig): Embedder {' if source else 'function createEmbedder(config) {'
    provider_signature = signature.replace('export ', '').replace('createEmbedder(', 'createProviderEmbedder(')
    wrapper = r'''const MODEL_PREFIXES = [
  {
    model: /(?:^|[\/_-])qwen3-embedding-(?:0\.6b|8b)(?:$|[-_.])/i,
    documentPrefix: "",
    queryPrefix: "Instruct: Given a web search query, retrieve relevant passages that answer the query\nQuery:",
  },
  {
    model: /(?:^|[\/_-])(?:gemini-embedding-2(?:-preview)?|embeddinggemma-2)(?:$|[-_.])/i,
    documentPrefix: "title: none | text: ",
    queryPrefix: "task: search result | query: ",
  },
];

SIGNATURE
  const rule = MODEL_PREFIXES.find((rule) => rule.model.test(config.model ?? ""));
  const documentPrefix = config.documentPrefix ?? rule?.documentPrefix ?? "";
  const queryPrefix = config.queryPrefix ?? rule?.queryPrefix ?? "";
  const provider = createProviderEmbedder(config);
  return {
    embed: (text, signal) => provider.embed(queryPrefix + text, signal),
    embedBatch: (texts, signal) => provider.embedBatch(texts.map((text) => documentPrefix + text), signal),
  };
}

'''.replace('SIGNATURE', signature)
    return replace_once(text, signature, wrapper + provider_signature, 'embedding factory')


def patch_semantic_first(text, *, source=False):
    """Keep existing vector order/scores, without running the noisy FTS arm."""
    text = replace_once(text, '    const ftsRanks = this.fts.searchRanks(query, poolSize, allowedIds);\n', '', 'defer keyword arm')
    start = '    if (this.fusion === "vector-primary") {'
    end = '      const K = 60;'
    cast = ' as [string, number]' if source else ''
    body = (start + '\n      // Semantic-only: preserve vector order and existing score semantics.\n'
            '      sorted = cosineScored.slice(0, limit).map((s, rank) =>\n'
            f'        [s.entry.session.id, 1 / (60 + rank + 1)]{cast});\n'
            '    } else {\n'
            '      const ftsRanks = this.fts.searchRanks(query, poolSize, allowedIds);\n')
    return replace_body(text, start, end, body)


def patch_embedding_contracts(text, *, source=False):
    """Exact configuration records; formatting belongs to indexer call sites."""
    if source:
        text = replace_once(text, 'export interface EmbedderConfig {', '''export type EmbeddingInputType = "query" | "passage";

export interface ModelPrefixes {
  queryPrefix: string;
  documentPrefix: string;
  /** API owns the role template; both text prefixes must then be empty. */
  inputType?: { query: "query"; document: "passage" };
}

export interface EmbedderConfig {''', 'model mapping type')
        text = replace_once(text, '  dimensions?: number;\n}', '''  dimensions?: number;
  /** Required exact-ID records. Empty strings explicitly mean no prefix. */
  modelPrefixes?: Record<string, ModelPrefixes>;
  /** Exact endpoint; otherwise keep the existing baseUrl + /v1/embeddings. */
  embeddingsEndpoint?: string;
}''', 'mapping config')
        # Only OpenAI-compatible transport consumes the optional API role. The
        # other providers keep their existing interface implementation unchanged.
        text = text.replace('embed(text: string, signal?: AbortSignal):',
                            'embed(text: string, signal?: AbortSignal, inputType?: EmbeddingInputType):', 1)
        text = text.replace('    signal?: AbortSignal\n  ): Promise<(number[] | null)[]>;',
                            '    signal?: AbortSignal,\n    inputType?: EmbeddingInputType\n  ): Promise<(number[] | null)[]>;', 1)
    exported = 'export ' if source else ''
    helper = '''EXPORTfunction resolveModelPrefixes(MODEL, MAPPING)RETURN {
  if (typeof model !== "string" || !mapping || typeof mapping !== "object" ||
      Array.isArray(mapping) || !Object.hasOwn(mapping, model)) {
    throw new Error(`Add embedder.modelPrefixes[${JSON.stringify(model)}] with string queryPrefix and documentPrefix (empty strings are explicit).`);
  }
  const prefixes = mapping[model];
  if (!prefixes || typeof prefixes !== "object" || Array.isArray(prefixes) ||
      typeof prefixes.queryPrefix !== "string" || typeof prefixes.documentPrefix !== "string") {
    throw new Error(`embedder.modelPrefixes[${JSON.stringify(model)}] requires string queryPrefix and documentPrefix.`);
  }
  if (prefixes.inputType !== undefined &&
      (!prefixes.inputType || prefixes.inputType.query !== "query" || prefixes.inputType.document !== "passage" ||
       prefixes.queryPrefix !== "" || prefixes.documentPrefix !== "")) {
    throw new Error("modelPrefixes.inputType requires query/passage roles and empty text prefixes; do not apply both templates.");
  }
  return prefixes;
}

EXPORTfunction prepareEmbeddingInput(TEXT, ROLE, PREFIXES)TEXTRETURN {
  return prefixes[role === "query" ? "queryPrefix" : "documentPrefix"] + text;
}

'''
    tokens = {
        'EXPORT': exported, 'MODEL': 'model: string | undefined' if source else 'model',
        'MAPPING': 'mapping?: Record<string, ModelPrefixes>' if source else 'mapping',
        'TEXT': 'text: string' if source else 'text',
        'ROLE': 'role: "query" | "document"' if source else 'role',
        'PREFIXES': 'prefixes: ModelPrefixes' if source else 'prefixes',
        'TEXTRETURN': ': string' if source else '', 'RETURN': ': ModelPrefixes' if source else '',
    }
    # Longer marker first: TEXTRETURN must not become textRETURN.
    for key in sorted(tokens, key=len, reverse=True):
        helper = helper.replace(key, tokens[key])
    signature = 'export function createEmbedder(config: EmbedderConfig): Embedder {' if source else 'function createEmbedder(config) {'
    text = replace_once(text, signature, helper + signature + '''
  const prefixes = resolveModelPrefixes(config.model, config.modelPrefixes);
  if (prefixes.inputType && config.type !== "openai-compatible") {
    throw new Error("modelPrefixes.inputType requires an openai-compatible provider.");
  }''', 'strict embedding factory')
    for suffix in ('true', 'false'):
        text = text.replace('merged.sendDimensions ?? ' + suffix + '\n',
                            'merged.sendDimensions ?? ' + suffix + ',\n        merged.embeddingsEndpoint\n')
    # Keep provider wire behavior, batching and limits; add one optional role
    # argument and one endpoint override, without any provider-side formatting.
    start = text.index('class OpenAICompatibleEmbedder' if source else 'var OpenAICompatibleEmbedder = class')
    end = text.index('class BedrockEmbedder' if source else 'var BedrockEmbedder = class', start)
    part = text[start:end]
    if source:
        part = replace_once(part, '    private sendDimensions: boolean\n',
                            '    private sendDimensions: boolean,\n    embeddingsEndpoint?: string\n', 'endpoint parameter')
        part = replace_once(part, 'async embed(text: string, signal?: AbortSignal):',
                            'async embed(text: string, signal?: AbortSignal, inputType?: EmbeddingInputType):', 'query API role')
        part = replace_once(part, '    signal?: AbortSignal\n  ): Promise<(number[] | null)[]> {',
                            '    signal?: AbortSignal,\n    inputType?: EmbeddingInputType\n  ): Promise<(number[] | null)[]> {', 'document API role')
    else:
        part = replace_once(part, 'constructor(apiKey, model, dimensions, baseUrl, sendDimensions)',
                            'constructor(apiKey, model, dimensions, baseUrl, sendDimensions, embeddingsEndpoint)', 'endpoint parameter')
        part = replace_once(part, 'async embed(text, signal)', 'async embed(text, signal, inputType)', 'query API role')
        part = replace_once(part, 'async embedBatch(texts, signal)', 'async embedBatch(texts, signal, inputType)', 'document API role')
    part = replace_once(part, 'this.endpoint = `${baseUrl.replace(/\\/$/, "")}/v1/embeddings`;',
                        'this.endpoint = embeddingsEndpoint ?? `${baseUrl.replace(/\\/$/, "")}/v1/embeddings`;', 'endpoint URL')
    part = replace_once(part, 'this.embedBatch([text], signal)', 'this.embedBatch([text], signal, inputType)', 'singleton API role')
    part = replace_once(part, '      if (this.dimensions && this.sendDimensions)',
                        '      if (inputType !== undefined) body.input_type = inputType;\n      if (this.dimensions && this.sendDimensions)', 'wire API role')
    return text[:start] + part + text[end:]


def patch_indexer_formatting(text, *, source=False):
    if source:
        text = replace_once(text, 'import type { Embedder } from "./embedder";',
                            'import { prepareEmbeddingInput } from "./embedder";\nimport type { Embedder, ModelPrefixes } from "./embedder";', 'index formatter import')
        text = replace_once(text, '  private fts: FtsSide;', '  private fts: FtsSide;\n  private prefixes: ModelPrefixes;', 'index format field')
        text = replace_once(text, '    private fusion: "rrf" | "vector-primary" = "rrf",\n',
                            '    private fusion: "rrf" | "vector-primary" = "rrf",\n    prefixes?: ModelPrefixes,\n', 'index formatter argument')
        anchor = '    mkdirSync(indexDir, { recursive: true });'
    else:
        text = replace_once(text, 'sessionDir, archiveDir, fusion = "rrf")',
                            'sessionDir, archiveDir, fusion = "rrf", prefixes)', 'index formatter argument')
        anchor = '    this.fusion = fusion;'
    text = replace_once(text, anchor, '''    if (!prefixes) throw new Error("SessionIndex requires resolved modelPrefixes.");
    this.prefixes = prefixes;
''' + anchor, 'resolved index format')
    text = replace_once(text, 'buildEmbeddingText(session));',
                        'prepareEmbeddingInput(buildEmbeddingText(session), "document", this.prefixes));', 'document input')
    text = replace_once(text, 'this.embedder.embedBatch(texts);',
                        'this.embedder.embedBatch(texts, undefined, this.prefixes.inputType?.document);', 'document role')
    return replace_once(text, 'this.embedder.embed(query);',
                        'this.embedder.embed(prepareEmbeddingInput(query, "query", this.prefixes), signal, this.prefixes.inputType?.query);', 'query input and role')


def patch_index_service_formatting(text, *, source=False):
    if source:
        text = replace_once(text, 'import { createEmbedder } from "./embedder";',
                            'import { createEmbedder, resolveModelPrefixes } from "./embedder";', 'service formatter import')
    anchor = '            options.fusion,\n' if source else '        options.fusion\n'
    indent = '            ' if source else '        '
    return replace_once(text, anchor, indent + 'options.fusion,\n' + indent +
                        'resolveModelPrefixes(options.embedder.model, options.embedder.modelPrefixes),\n', 'worker/main resolved format')


def patch_semantic_only(text, *, source=False):
    """Early cosine return; explicit legacy fusion modes stay upstream-compatible."""
    text = text.replace('"rrf" | "vector-primary"', '"rrf" | "vector-primary" | "semantic-only"')
    return replace_once(text, '    const poolSize = Math.max(limit * 5, 100);', '''    if (this.fusion === "semantic-only") {
      return cosineScored.slice(0, limit).map(({ entry, score }) => ({
        session: entry.session,
        summary: buildSummary(entry.session),
        score,
      }));
    }

    const poolSize = Math.max(limit * 5, 100);''', 'early semantic return')


def patch_build_config(text, *, source=False):
    text = text.replace('"rrf" | "vector-primary"', '"rrf" | "vector-primary" | "semantic-only"')
    text = replace_once(text, 'fusion: file.fusion === "vector-primary" ? "vector-primary" : "rrf"',
                        'fusion: file.fusion === "rrf" || file.fusion === "vector-primary" ? file.fusion : "semantic-only"', 'build semantic default')
    if source:
        text = text.replace('`"rrf"` (default)', '`"rrf"` (opt-in)').replace('@default "rrf"', '@default "semantic-only"')
        text = text.replace('   * Fusion strategy used when combining cosine (vector) and FTS ranks.',
                            '   * Search policy. semantic-only returns cosine scores without querying FTS.').replace(
                            '   * - `"rrf"` (opt-in)', '   * - `"semantic-only"` (build default): cosine only, no FTS search/fusion.\n   * - `"rrf"` (opt-in)')
    signature = 'export function saveConfig(file: ConfigFile, cwd?: string): void {' if source else 'function saveConfig(file, cwd) {'
    reader = '''EXPORTfunction readConfigFile(CWD)RETURN {
  const path = getConfigPath(cwd);
  if (!existsSync(path)) return {};
  const file = JSON.parse(readFileSync(path, "utf8"));
  if (!file || typeof file !== "object" || Array.isArray(file)) throw new Error("Session search config must be a JSON object.");
  return file;
}

'''.replace('EXPORT', 'export ' if source else '').replace('CWD', 'cwd?: string' if source else 'cwd').replace('RETURN', ': ConfigFile' if source else '')
    text = replace_once(text, signature, reader + signature + '''
  const current = readConfigFile(cwd);
  file = { ...current, ...file,
    ...(file.embedder ? { embedder: { ...current.embedder, ...file.embedder } } : {}),
  };''', 'preserving save')
    return text


def patch_setup_mapping(text, *, source=False):
    if source:
        text = replace_once(text, '  saveConfig,', '  saveConfig,\n  readConfigFile,', 'setup raw config import')
        text = 'import { resolveModelPrefixes } from "./embedder";\n' + text
    start = text.index('  pi.registerCommand("session-embeddings-setup"')
    end = text.index('  pi.registerCommand("session-sync"', start)
    part = text[start:end].replace('Enable semantic embeddings for hybrid search (FTS5 is always on)',
                                   'Configure semantic embeddings and explicit model input formats')
    part = replace_once(part, '    handler: async (_args, ctx) => {',
                        '    handler: async (_args, ctx) => {\n      const existing = readConfigFile(sessionCwd);', 'setup current config')
    extra = '''      const mapping = { ...existing.embedder?.modelPrefixes };
      if (typeof embedder?.model !== "string" || !embedder.model) {
        ctx.ui.notify("An exact embedding model ID is required.", "warning");
        return;
      }
      if (!Object.hasOwn(mapping, embedder.model)) {
        const queryPrefix = await ctx.ui.input("Query prefix (literal; empty means explicitly none):", "");
        const documentPrefix = await ctx.ui.input("Document prefix (literal; empty means explicitly none):", "");
        if (queryPrefix === undefined || documentPrefix === undefined) return;
        const confirmed = await ctx.ui.select(
          `Save explicit prefixes? query=${JSON.stringify(queryPrefix)}, document=${JSON.stringify(documentPrefix)}`,
          ["Use explicit prefixes", "Cancel"],
        );
        if (confirmed !== "Use explicit prefixes") return;
        mapping[embedder.model] = { queryPrefix, documentPrefix };
      }
      const prefixes = resolveModelPrefixes(embedder.model, mapping);
      if (prefixes.inputType && embedder.type !== "openai-compatible") {
        ctx.ui.notify("API inputType roles require an openai-compatible provider.", "warning");
        return;
      }
      ctx.ui.notify(`Model input format: query=${JSON.stringify(prefixes.queryPrefix)}, document=${JSON.stringify(prefixes.documentPrefix)}, inputType=${JSON.stringify(prefixes.inputType ?? null)}`, "info");
      embedder.modelPrefixes = mapping;
      if (embedder.type === existing.embedder?.type && !embedder.apiKey) embedder.apiKey = existing.embedder.apiKey;
      if (embedder.type === "openai-compatible") {
        const endpoint = await ctx.ui.input("Full embeddings endpoint (optional; empty uses base URL):", existing.embedder?.embeddingsEndpoint ?? "");
        if (endpoint === undefined) return;
        embedder.embeddingsEndpoint = endpoint || undefined;
      }

'''
    part = replace_once(part, '      const extraDirs = await ctx.ui.input(', extra + '      const extraDirs = await ctx.ui.input(', 'setup explicit mapping')
    part = part.replace('"Extra session directories (comma-separated, optional):",\n        ""',
                        '"Extra session directories (comma-separated, optional):",\n        (existing.extraSessionDirs ?? []).join(",")').replace(
                        '"Extra archive directories (comma-separated, optional):",\n        ""',
                        '"Extra archive directories (comma-separated, optional):",\n        (existing.extraArchiveDirs ?? []).join(",")')
    part = replace_once(part, '      saveConfig({',
                        '      if (extraDirs === undefined || extraArchive === undefined) return;\n      saveConfig({', 'cancel before save')
    part = part.replace(': undefined,', ': [],') if source else part.replace(': void 0,', ': [],').replace(': void 0\n', ': []\n')
    return text[:start] + part + text[end:]


def patch_semantic_service(text, *, source=False):
    text = text.replace('"rrf" | "vector-primary"', '"rrf" | "vector-primary" | "semantic-only"')
    signature = 'export function createIndexService(options: IndexOptions): IndexService {' if source else 'function createIndexService(options) {'
    return replace_once(text, signature, signature + '''
  if ((options.fusion ?? "semantic-only") === "semantic-only" && !options.embedder) {
    throw new Error("semantic-only requires an embedder and explicit modelPrefixes. Run /session-embeddings-setup, then /reload.");
  }''', 'no silent lexical fallback')


def canonical_files(runtime_only=False, *, previous=False, published=False, released=False, build3=False):
    if sum((previous, published, released, build3)) > 1:
        raise ValueError('select one exact historical state')
    stock = read_files(STORE)
    if tuple(hashlib.sha256(stock[r]).hexdigest() for r in REL_FILES) != STOCK_HASHES:
        raise RuntimeError("immutable stock hash mismatch")
    c, p, d, i = (stock[r].decode("utf-8") for r in REL_FILES[:4])
    if not runtime_only:
        c = replace_once(c, 'return join(homedir(), ".pi", "session-search");', 'return process.env.PI_CODING_AGENT_DIR?.trim() ? join(process.env.PI_CODING_AGENT_DIR.trim(), "session-search") : join(homedir(), ".pi", "session-search"); // local-profile-patch', "config")
        d = replace_once(d, 'return join(homedir(), ".pi", "session-search");', 'return process.env.PI_CODING_AGENT_DIR?.trim() ? join(process.env.PI_CODING_AGENT_DIR.trim(), "session-search") : join(homedir(), ".pi", "session-search"); // local-profile-patch', "dist config")
    p = patch_parser(p, runtime_only)
    d = patch_index(patch_parser(d, runtime_only, True))
    i = patch_index(i, True)
    canonical = {**stock, **dict(zip(REL_FILES[:4], (v.encode("utf-8") for v in (c, p, d, i))))}
    if not previous:
        for rel in (REL_FILES[2], *REL_FILES[4:]):
            canonical[rel] = patch_display(canonical[rel].decode("utf-8"), rel.suffix == '.ts').encode("utf-8")
    if not (previous or published):
        for leaf in ('src/parser.ts', 'src/index.ts', 'dist/index.js', 'dist/index-worker.js'):
            rel = pathlib.Path(leaf)
            text = canonical[rel].decode('utf-8')
            worker = leaf.endswith('index-worker.js')
            if worker:
                text = patch_parser(text, runtime_only, True, worker=True)
            text = patch_roots(text)
            if leaf != 'src/index.ts':
                text = patch_discovery(text, source=rel.suffix == '.ts', worker=worker)
            canonical[rel] = text.encode('utf-8')
        for leaf in ('src/session-index.ts', 'src/fts-index.ts', 'dist/index.js', 'dist/index-worker.js'):
            rel = pathlib.Path(leaf)
            text = patch_safe_removal(canonical[rel].decode('utf-8'), source=rel.suffix == '.ts')
            if leaf != 'src/fts-index.ts':
                text = patch_partial_fts(text, source=rel.suffix == '.ts')
            canonical[rel] = text.encode('utf-8')
    if build3:
        for leaf in ('src/embedder.ts', 'dist/index.js', 'dist/index-worker.js'):
            rel = pathlib.Path(leaf)
            canonical[rel] = patch_embedding_prefixes(canonical[rel].decode('utf-8'), source=rel.suffix == '.ts').encode('utf-8')
        for leaf in ('src/session-index.ts', 'dist/index.js', 'dist/index-worker.js'):
            rel = pathlib.Path(leaf)
            canonical[rel] = patch_semantic_first(canonical[rel].decode('utf-8'), source=rel.suffix == '.ts').encode('utf-8')
        for leaf in ('src/config.ts', 'dist/index.js'):
            rel = pathlib.Path(leaf)
            text = replace_once(canonical[rel].decode('utf-8'),
                'fusion: file.fusion === "vector-primary" ? "vector-primary" : "rrf"',
                'fusion: file.fusion === "rrf" ? "rrf" : "vector-primary"', 'semantic default')
            if rel.suffix == '.ts':
                text = text.replace('`"rrf"` (default)', '`"rrf"` (opt-in)').replace('@default "rrf"', '@default "vector-primary"')
                text = text.replace('Preserve cosine order; append top-5 FTS hits that\n   *   the vector arm missed.', 'Semantic-only cosine order, without FTS fusion.\n   *  ')
            canonical[rel] = text.encode('utf-8')
    elif not (previous or published or released):
        for leaf in ('src/embedder.ts', 'dist/index.js', 'dist/index-worker.js'):
            rel = pathlib.Path(leaf)
            canonical[rel] = patch_embedding_contracts(canonical[rel].decode('utf-8'), source=rel.suffix == '.ts').encode('utf-8')
        for leaf in ('src/session-index.ts', 'dist/index.js', 'dist/index-worker.js'):
            rel = pathlib.Path(leaf)
            text = patch_indexer_formatting(canonical[rel].decode('utf-8'), source=rel.suffix == '.ts')
            canonical[rel] = patch_semantic_only(text, source=rel.suffix == '.ts').encode('utf-8')
        for leaf in ('src/index-service.ts', 'dist/index.js', 'dist/index-worker.js'):
            rel = pathlib.Path(leaf)
            canonical[rel] = patch_index_service_formatting(canonical[rel].decode('utf-8'), source=rel.suffix == '.ts').encode('utf-8')
        for leaf in ('src/config.ts', 'dist/index.js'):
            rel = pathlib.Path(leaf)
            canonical[rel] = patch_build_config(canonical[rel].decode('utf-8'), source=rel.suffix == '.ts').encode('utf-8')
        for leaf in ('src/index.ts', 'dist/index.js'):
            rel = pathlib.Path(leaf)
            canonical[rel] = patch_setup_mapping(canonical[rel].decode('utf-8'), source=rel.suffix == '.ts').encode('utf-8')
        for leaf in ('src/index-service.ts', 'dist/index.js', 'dist/index-worker.js'):
            rel = pathlib.Path(leaf)
            canonical[rel] = patch_semantic_service(canonical[rel].decode('utf-8'), source=rel.suffix == '.ts').encode('utf-8')
    return stock, canonical


def classify(root, runtime_only=False):
    stock, canonical = canonical_files(runtime_only)
    current = read_files(root)
    _, previous = canonical_files(runtime_only, previous=True)
    _, published = canonical_files(runtime_only, published=True)
    _, released = canonical_files(runtime_only, released=True)
    _, old_build3 = canonical_files(runtime_only, build3=True)
    return ("patched" if current == canonical else "stock" if current == stock else
            "previous-patched" if current == previous else "published-patched" if current == published else
            "released-patched" if current == released else "build3-patched" if current == old_build3 else "unknown"), stock, canonical


def runtime_backup(root, label):
    dst = BACKUP_ROOT / f"{label}-{dt.datetime.now().strftime('%Y%m%d-%H%M%S-%f')}"
    for rel in REL_FILES:
        (dst / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(root / rel, dst / rel)
    hashes = {rel.as_posix(): hashlib.sha256((dst / rel).read_bytes()).hexdigest() for rel in REL_FILES}
    if any((dst / rel).read_bytes() != (root / rel).read_bytes() for rel in REL_FILES):
        raise RuntimeError("runtime backup verification failed")
    (dst / 'receipt.json').write_text(json.dumps({'version': VERSION, 'state': label, 'sha256': hashes}, indent=2), encoding='utf-8')
    return dst


def apply(root, runtime_only=False):
    state, stock, canonical = classify(root, runtime_only)
    if state == "patched":
        print("ALREADY PATCHED")
        return
    if state not in {"stock", "previous-patched", "published-patched", "released-patched", "build3-patched"}:
        raise RuntimeError("unknown/mixed installed state")
    print(f"runtime backup: {runtime_backup(root, state)}")
    for rel, body in canonical.items():
        (root / rel).write_bytes(body)
    subprocess.run(["node", "--check", str(root / REL_FILES[2])], check=True)
    subprocess.run(["node", "--check", str(root / 'dist/index-worker.js')], check=True)
    if read_files(root) != canonical:
        raise RuntimeError("post-write verification failed")
    print("PATCH APPLIED")


def restore(root, runtime_only=False):
    state, stock, canonical = classify(root, runtime_only)
    if state == "stock":
        print("ALREADY STOCK")
        return
    if state not in {"patched", "previous-patched", "published-patched", "released-patched", "build3-patched"}:
        raise RuntimeError("unknown/mixed installed state")
    print(f"runtime backup: {runtime_backup(root, state)}")
    for rel, body in stock.items():
        (root / rel).write_bytes(body)
    if read_files(root) != stock:
        raise RuntimeError("post-restore verification failed")
    print("RESTORED BYTE-EXACT")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--agent-dir", required=True)
    ap.add_argument("--runtime-only", action="store_true", help="Code: retain stock config/index paths")
    mode = ap.add_mutually_exclusive_group(required=True)
    for flag in ("check", "apply", "restore"):
        mode.add_argument("--" + flag, action="store_true")
    args = ap.parse_args()
    agent = pathlib.Path(args.agent_dir).expanduser().resolve()
    configure_paths(agent)
    root = package_root(agent)
    try:
        assert_version(root)
        if args.check:
            state, _, _ = classify(root, args.runtime_only)
            print(f"version={VERSION} state={state}")
            return {"patched": 0, "stock": 1, "previous-patched": 1, "published-patched": 1, "released-patched": 1, "build3-patched": 1, "unknown": 2}[state]
        (apply if args.apply else restore)(root, args.runtime_only)
        return 0
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

if __name__ == "__main__":
    raise SystemExit(main())
