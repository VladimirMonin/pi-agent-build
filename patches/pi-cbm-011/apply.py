#!/usr/bin/env python3
"""
Compatibility patch: pi-cbm 1.2.1 against codebase-memory-mcp 0.11.x.

THE DEFECT
----------
CBM 0.11.0 changed its tool output contract: every graph tool gained
`--format <tree|json>` and TREE IS NOW THE DEFAULT. Its release notes state it
plainly — "the tool output contract changes", JSON moved "behind explicit opt-in".

pi-cbm passes no `format`, then parses the response as structured JSON:

    // src/domain/symbols.ts
    if (!isRecord(data) || !Array.isArray(data.results)) return [];

With tree output, `typeof data === "string"`, that guard fails, and the tool
returns an EMPTY LIST where the graph actually had results. Verified by
simulating the wrapper's own parser against a real 0.11.0 response:

    envelope found: true | isError: false
    typeof data = string          <- not an object
    guard isRecord && Array.isArray(data.results) -> FAIL -> returns []
    raw text: "results: 2  (cols: qn label file lines rank) ..."

A SILENT wrong answer — worse than a loud error, because the agent reports
"nothing found".

THE FIX — ONE PLACE, NOT SEVEN
------------------------------
The adapter in CbmClient.callTool() does two things:

1. forces `format: "json"` for the seven graph tools unless the caller supplied
   a format;
2. translates CBM 0.11 compact JSON (`cols + rows`, nested `groups`) back to
   the object-array contract expected by pi-cbm 1.2.1 (`results[]`, array
   callers/callees, `impacted_symbols[]`, architecture arrays).

Patching the seven tool definitions individually would miss the wrapper's own
higher-level helpers (resolve_symbol, read_symbol, read_symbols,
get_code_snippets, search_and_read_symbols), which call upstream tools internally.

Upstream CBM is NOT touched. No version rollback. The version guard is deliberately
narrow: exactly pi-cbm 1.2.1 and CBM 0.11.x. CBM 0.12+ fails closed until its
output schema is smoke-tested.

DURABILITY
----------
This edits a file INSIDE the installed npm package. Any `npm install` /
`pi install` / `pi update` reinstalling pi-cbm WILL OVERWRITE IT. Re-run --apply
afterwards. The reviewed pristine file in this repository is immutable;
runtime backups live under the selected Pi profile, and any source/version
mismatch fails closed.

USAGE
-----
  python apply-pi-cbm-011-patch.py --check     # report only
  python apply-pi-cbm-011-patch.py --apply     # patch (profile-local backup)
  python apply-pi-cbm-011-patch.py --restore   # byte-exact undo
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

PKG_NAME = "pi-cbm"
HERE = Path(__file__).resolve().parent
STORE = HERE / "store"
PKG_DIR = Path()
TARGET = Path()
PKG_JSON = Path()
BACKUP_ROOT = Path()


def configure_paths(agent_dir: Path) -> None:
    """Resolve package and backup paths from the selected Pi profile."""
    global PKG_DIR, TARGET, PKG_JSON, BACKUP_ROOT
    PKG_DIR = agent_dir / "npm" / "node_modules" / "pi-cbm"
    TARGET = PKG_DIR / "src" / "cbm" / "client.ts"
    PKG_JSON = PKG_DIR / "package.json"
    BACKUP_ROOT = agent_dir / ".pi-agent-build-backups" / "pi-cbm-011"

MARKER = "// [local-compat-patch]"

# This translator is deliberately narrow. It knows the exact compact table/group
# contract introduced in CBM 0.11. A future 0.12 may change it again and must
# fail closed until smoke-tested — especially because the original defect was a
# silent empty result rather than a loud error.
CBM_MIN_VERSION = (0, 11, 0)
CBM_MAX_EXCLUSIVE = (0, 12, 0)
AUTHORED_AGAINST = "1.2.1"

JSON_FORMAT_TOOLS = [
    "search_graph",
    "trace_path",
    "get_architecture",
    "detect_changes",
    "search_code",
    "get_code_snippet",
    "query_graph",
]

# The three anchors this patch rewrites, as they appear in stock 1.2.1.
ANCHOR_SPAWN = (
    '    const child = spawn(binary, ["cli", "--json", toolName, '
    'JSON.stringify(args)], {'
)
ANCHOR_DATA = "      const data = parseMaybeJson(text);"
ANCHOR_CLASS = "export class CbmClient {"

CONST_BLOCK = """// [local-compat-patch] CBM >= 0.11.0 changed TWO contracts:
//   1. graph tools default to compact \"tree\" text instead of JSON;
//   2. JSON tables changed from `results: object[]` to `cols + rows` and some
//      nested arrays changed to compressed tables/groups.
// pi-cbm 1.2.1 predates both changes. Its helpers require the old shape
// (`Array.isArray(data.results)`) and silently report \"not found\" otherwise.
const JSON_FORMAT_TOOLS = new Set([
  "search_graph",
  "trace_path",
  "get_architecture",
  "detect_changes",
  "search_code",
  "get_code_snippet",
  "query_graph",
]);

type CbmRecord = Record<string, unknown>;

function isCbmRecord(value: unknown): value is CbmRecord {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function splitLines(value: unknown): { start_line?: number; end_line?: number } {
  if (typeof value !== "string") return {};
  const match = value.match(/^(\\d+)(?:-(\\d+))?$/);
  if (!match) return {};
  return { start_line: Number(match[1]), end_line: Number(match[2] ?? match[1]) };
}

function oldColumnName(column: string): string {
  return ({
    qn: "qualified_name",
    file: "file_path",
    in: "in_degree",
    out: "out_degree",
    matches: "match_lines",
    files: "file_count",
    nodes: "node_count",
  } as Record<string, string>)[column] ?? column;
}

function tableRow(cols: string[], row: unknown[], group: CbmRecord = {}): CbmRecord {
  const item: CbmRecord = {};
  cols.forEach((column, index) => {
    const value = row[index];
    if (column === "lines") Object.assign(item, splitLines(value));
    else item[oldColumnName(column)] = value;
  });

  const prefix = typeof group.qn_prefix === "string" ? group.qn_prefix : "";
  if (typeof item.name === "string" && prefix && item.qualified_name === undefined) {
    item.qualified_name = `${prefix}.${item.name}`;
  }
  if (typeof group.file === "string" && item.file_path === undefined) item.file_path = group.file;
  if (typeof item.qualified_name === "string" && item.name === undefined) {
    item.name = item.qualified_name.slice(item.qualified_name.lastIndexOf(".") + 1);
  }
  // Old search_code called this field `node`; retaining both keeps direct tool
  // output and the helper parsers compatible.
  if (typeof item.name === "string" && item.node === undefined) item.node = item.name;
  return item;
}

function expandTable(value: unknown): unknown[] {
  if (Array.isArray(value)) return value;
  if (!isCbmRecord(value) || !Array.isArray(value.cols)) return [];
  const cols = value.cols.filter((item): item is string => typeof item === "string");
  if (Array.isArray(value.rows)) {
    return value.rows.filter(Array.isArray).map((row) => tableRow(cols, row));
  }
  if (Array.isArray(value.groups)) {
    return value.groups.flatMap((group) => {
      if (!isCbmRecord(group) || !Array.isArray(group.rows)) return [];
      return group.rows.filter(Array.isArray).map((row) => tableRow(cols, row, group));
    });
  }
  return [];
}

function normalizeCbm011Result(toolName: string, value: unknown): unknown {
  if (!isCbmRecord(value)) return value;
  const data: CbmRecord = { ...value };

  if (toolName === "search_graph" || toolName === "search_code") {
    if (!Array.isArray(data.results) && Array.isArray(data.cols) && (Array.isArray(data.rows) || Array.isArray(data.groups))) {
      data.results = expandTable(data);
    }
  } else if (toolName === "trace_path") {
    data.callers = expandTable(data.callers);
    data.callees = expandTable(data.callees);
  } else if (toolName === "detect_changes") {
    if (!Array.isArray(data.impacted_symbols)) data.impacted_symbols = expandTable(data.impacted);
    if (typeof data.changed_count !== "number" && typeof data.changed_total === "number") {
      data.changed_count = data.changed_total;
    }
  } else if (toolName === "get_architecture") {
    for (const key of ["node_labels", "edge_types", "languages", "packages", "entry_points"]) {
      if (!Array.isArray(data[key])) data[key] = expandTable(data[key]);
    }
  }

  return data;
}
// [/local-compat-patch]

"""

CALL_PATCH = """    // [local-compat-patch] see JSON_FORMAT_TOOLS above
    // Restore with: python apply-pi-cbm-011-patch.py --restore
    const effectiveArgs =
      JSON_FORMAT_TOOLS.has(toolName) && args.format === undefined
        ? { ...args, format: "json" }
        : args;
    const child = spawn(binary, ["cli", "--json", toolName, JSON.stringify(effectiveArgs)], {"""

DATA_PATCH = """      // [local-compat-patch] normalize CBM 0.11 compact JSON tables back to
      // the object-array contract expected by pi-cbm 1.2.1 and its helpers.
      const data = normalizeCbm011Result(toolName, parseMaybeJson(text));"""


# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #
def read_raw(path: Path) -> str:
    """Read preserving original line endings (read_text() rewrites CRLF -> LF,
    which silently changes one byte per line and breaks byte-exact restore)."""
    return path.read_bytes().decode("utf-8")


def write_raw(path: Path, text: str) -> None:
    path.write_bytes(text.encode("utf-8"))


def installed_version() -> str | None:
    if not PKG_JSON.exists():
        return None
    try:
        return json.loads(PKG_JSON.read_text(encoding="utf-8")).get("version")
    except Exception:
        return None


def parse_version(text: str) -> tuple[int, ...] | None:
    m = re.search(r"(\d+)\.(\d+)\.(\d+)", text or "")
    return tuple(int(g) for g in m.groups()) if m else None


def resolve_cbm() -> tuple[str | None, str]:
    """Locate the real CBM executable, not the npm shell shim.

    On Windows a global npm install creates only shell wrappers (foo, foo.cmd,
    foo.ps1). subprocess without shell=True cannot execute those — the same trap
    Pi hits with spawn(..., {shell:false}). The real binary lives inside the
    package tree, so look there first, then fall back to a plain PATH lookup
    (which works on Linux/macOS).
    """
    candidates = [
        Path(os.environ.get("CODEBASE_MEMORY_MCP_BIN", "")),
        Path(os.environ.get("CBM_BIN", "")),
        Path(os.environ.get("APPDATA", "")) / "npm" / "node_modules"
        / "codebase-memory-mcp" / "bin" / "codebase-memory-mcp.exe",
        Path.home() / ".local" / "bin" / "codebase-memory-mcp",
    ]
    for c in candidates:
        if c and str(c) and c.is_file():
            return str(c), "resolved"
    found = shutil.which("codebase-memory-mcp")
    if found:
        return found, "PATH"
    return None, "not found"


def run_cbm(args: list[str]) -> str:
    binary, _ = resolve_cbm()
    if not binary:
        return ""
    try:
        return subprocess.run(
            [binary, *args], capture_output=True, text=True, timeout=180
        ).stdout or ""
    except Exception:
        return ""


def cbm_version() -> str | None:
    out = run_cbm(["--version"])
    m = re.search(r"(\d+\.\d+\.\d+)", out)
    return m.group(1) if m else None


def cbm_supports_format() -> bool:
    """Does the installed CBM expose --format? (0.11.0+ does.)"""
    return "--format" in run_cbm(["cli", "search_graph", "--help"])


def is_patched(text: str) -> bool:
    return MARKER in text


def pristine_path(version: str | None) -> Path:
    return STORE / f"client.ts.orig-{version or 'unknown'}"


def build_patched(pristine_text: str) -> tuple[str, list[str]]:
    """Deterministically produce the patched file from a pristine body."""
    problems: list[str] = []
    text = pristine_text

    if ANCHOR_CLASS not in text:
        problems.append(f"class anchor not found: {ANCHOR_CLASS!r}")
    else:
        text = text.replace(ANCHOR_CLASS, CONST_BLOCK + ANCHOR_CLASS, 1)

    if ANCHOR_SPAWN not in text:
        problems.append("spawn call anchor not found in callTool()")
    else:
        text = text.replace(ANCHOR_SPAWN, CALL_PATCH, 1)

    if ANCHOR_DATA not in text:
        problems.append("response data anchor not found in callTool()")
    else:
        text = text.replace(ANCHOR_DATA, DATA_PATCH, 1)

    return text, problems


def previous_patched(expected: str) -> str:
    """Exact previous canonical body: grouped search results were not expanded."""
    current = "Array.isArray(data.cols) && (Array.isArray(data.rows) || Array.isArray(data.groups))"
    if expected.count(current) != 1:
        raise RuntimeError("grouped-result migration anchor mismatch")
    return expected.replace(current, "Array.isArray(data.cols) && Array.isArray(data.rows)", 1)


# --------------------------------------------------------------------------- #
# commands
# --------------------------------------------------------------------------- #
def cmd_check() -> int:
    print("=== pi-cbm x CBM 0.11 compatibility patch: CHECK ===")
    ver = installed_version()
    if ver is None:
        print(f"  package NOT installed at {PKG_DIR}")
        return 2
    print(f"  package:        {PKG_NAME} {ver}")
    if ver != AUTHORED_AGAINST:
        print(f"\n  UNSUPPORTED: patch authored for pi-cbm {AUTHORED_AGAINST}, installed {ver}.")
        print("  Refusing to infer compatibility from text anchors alone. Re-audit first.")
        return 2

    cv = cbm_version()
    cvt = parse_version(cv or "")
    print(f"  cbm binary:     {cv or 'not found on PATH'}")
    has_format = cbm_supports_format()
    print(f"  cbm --format:   {'supported' if has_format else 'absent'}")

    if cvt is None:
        print("\n  UNSUPPORTED: cannot determine the CBM version. Fail closed.")
        return 2
    if cvt >= CBM_MAX_EXCLUSIVE:
        print(f"\n  UNSUPPORTED: translator is tested only for CBM 0.11.x; found {cv}.")
        print("  CBM 0.12+ requires a fresh output-schema smoke test before use.")
        return 2

    if not TARGET.exists():
        print(f"  client.ts NOT found at {TARGET}")
        return 2

    pristine = pristine_path(ver)
    if not pristine.exists():
        print(f"  immutable pristine store missing: {pristine}")
        return 2
    base = read_raw(pristine)
    expected, problems = build_patched(base)
    if problems:
        print(f"  immutable pristine store does not match patch anchors: {problems}")
        return 2
    text = read_raw(TARGET)

    print("\n  --- verdict ---")
    if cvt is not None and cvt < CBM_MIN_VERSION:
        if text != base:
            print("  UNKNOWN STATE: patch is not required but installed source is not immutable stock.")
            return 2
        print(f"  PATCH NOT REQUIRED: CBM {cv} predates the tree-output default;")
        return 0
    if not cbm_supports_format():
        print("  UNSUPPORTED: CBM 0.11.x does not expose the required --format flag.")
        return 2
    # An editor may normalize the mixed-CRLF/LF canonical output to LF-only.
    # Accept that one exact, derivable byte state; never accept arbitrary drift.
    if text in (expected, expected.replace("\r\n", "\n")):
        print("  ALREADY PATCHED. Nothing to do.")
        return 0
    previous = previous_patched(expected)
    if text in (previous, previous.replace("\r\n", "\n")):
        print("  PATCH REQUIRED: exact previous canonical lacks grouped search results.")
        return 1
    if text == base:
        print(f"  PATCH REQUIRED: CBM {cv} defaults graph tools to tree output.")
        return 1
    print("  UNKNOWN STATE: installed file differs from immutable stock and canonical patch.")
    return 2


def cmd_apply() -> int:
    print("=== pi-cbm x CBM 0.11 compatibility patch: APPLY ===")
    if not TARGET.exists():
        print(f"  client.ts NOT found at {TARGET}")
        return 2
    ver = installed_version()
    print(f"  package: {PKG_NAME} {ver}")
    if ver != AUTHORED_AGAINST:
        print(f"  REFUSING: patch supports exactly pi-cbm {AUTHORED_AGAINST}.")
        return 2

    cv = cbm_version()
    cvt = parse_version(cv or "")
    if cvt is None:
        print("  REFUSING: cannot determine installed CBM version.")
        return 2
    if cvt < CBM_MIN_VERSION:
        print(f"  CBM {cv} predates the compact 0.11 contract — patch not required.")
        return 0
    if cvt >= CBM_MAX_EXCLUSIVE:
        print(f"  REFUSING: CBM {cv} is outside tested range 0.11.x.")
        print("  Smoke-test its output schema and update the translator first.")
        return 2
    if not cbm_supports_format():
        print(f"  REFUSING: CBM {cv} should expose --format but does not.")
        return 2

    text = read_raw(TARGET)
    pristine = pristine_path(ver)
    if not pristine.exists():
        print(f"  immutable pristine store missing: {pristine}")
        return 2
    base = read_raw(pristine)
    new_text, problems = build_patched(base)
    if problems:
        print("\n  REFUSING TO PATCH — immutable store anchors not found:")
        for p in problems:
            print(f"    - {p}")
        return 2
    if text in (new_text, new_text.replace("\r\n", "\n")):
        print("  file already in canonical patched state (idempotent)")
        return 0
    previous = previous_patched(new_text)
    if text not in (base, previous, previous.replace("\r\n", "\n")):
        print("  REFUSING: installed file differs from immutable stock and canonical patch")
        return 2

    ts = dt.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    BACKUP_ROOT.mkdir(parents=True, exist_ok=True)
    backup = BACKUP_ROOT / f"pi-cbm-client.ts.stock-{ts}"
    shutil.copy2(TARGET, backup)
    print(f"  runtime backup: {backup}")

    write_raw(TARGET, new_text)
    if read_raw(TARGET) != new_text:
        print("  post-write verification failed")
        return 2
    print("\n  patched:")
    for t in JSON_FORMAT_TOOLS:
        print(f"    {t}")
    print(f"\n  guard: caller-supplied format still wins (only injected when undefined)")
    print("  restart Pi (or /reload) so the extension reloads")
    return 0


def cmd_restore() -> int:
    print("=== pi-cbm x CBM 0.11 compatibility patch: RESTORE ===")
    if not TARGET.exists():
        print(f"  client.ts NOT found at {TARGET}")
        return 2
    ver = installed_version()
    if ver != AUTHORED_AGAINST:
        print(f"  unsupported package version: {ver}")
        return 2
    pristine = pristine_path(ver)
    if not pristine.exists():
        print(f"  immutable pristine store missing: {pristine}")
        return 2
    base = read_raw(pristine)
    expected, problems = build_patched(base)
    if problems:
        print(f"  immutable pristine store does not match patch anchors: {problems}")
        return 2
    text = read_raw(TARGET)
    if text == base:
        print("  file is already stock — nothing to restore")
        return 0
    previous = previous_patched(expected)
    if text not in (expected, expected.replace("\r\n", "\n"), previous, previous.replace("\r\n", "\n")):
        print("  REFUSING: installed file is neither stock nor canonical patched state")
        return 2

    ts = dt.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    BACKUP_ROOT.mkdir(parents=True, exist_ok=True)
    backup = BACKUP_ROOT / f"pi-cbm-client.ts.patched-{ts}"
    shutil.copy2(TARGET, backup)
    print(f"  backup of patched state: {backup}")

    shutil.copy2(pristine, TARGET)
    if read_raw(TARGET) != base:
        print("  post-restore verification failed")
        return 2
    print(f"  restored from immutable pristine: {pristine.name}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Adapt the CBM 0.11.x compact schema for pi-cbm 1.2.1 (local patch)."
    )
    ap.add_argument(
        "--agent-dir",
        help="Pi profile directory; default: PI_CODING_AGENT_DIR or ~/.pi/agent",
    )
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--check", action="store_true", help="report only")
    g.add_argument("--apply", action="store_true", help="patch the package")
    g.add_argument("--restore", action="store_true", help="byte-exact undo")
    a = ap.parse_args()
    agent_dir = Path(
        a.agent_dir
        or os.environ.get("PI_CODING_AGENT_DIR", "")
        or Path.home() / ".pi" / "agent"
    ).expanduser().resolve()
    configure_paths(agent_dir)
    if a.check:
        return cmd_check()
    if a.apply:
        return cmd_apply()
    return cmd_restore()


if __name__ == "__main__":
    sys.exit(main())
