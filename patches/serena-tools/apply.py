#!/usr/bin/env python3
"""
Local tool-surface compatibility patch for @bacnh85/pi-serena.

WHY THIS EXISTS
---------------
The wrapper registers 20 Serena tools. Two of them are dead in the current
runtime, so the model should never see them:

  serena_check_onboarding_performed
      Serena 1.7.0 DELETED this tool. Onboarding is now an agent MODE
      (SerenaAgentMode "onboarding" / "no-onboarding"), not a checker tool.
      The wrapper still calls it by name with no fallback.

  serena_find_implementations
      The current Python backend (Pyright) does not advertise
      textDocument/implementation -> implementationProvider is absent from the
      LSP initialize capabilities, so Pyright answers -32601 Unhandled method.
      This is a BACKEND limitation, not a Serena version regression, so
      restarting the language server never helps. Re-test before restoring
      (a JetBrains backend or another LSP may well support it).

NO FAKE FALLBACKS. serena_find_implementations is NOT remapped onto
serena_find_referencing_symbols: the semantics differ, and hiding a capability
the runtime does not have is the whole point of this patch.

WHAT IT DOES
------------
Comments out only the two pi.registerTool({...}) blocks, leaving visible
markers in place. Nothing else is touched: not worker.ts, not the Python
bridge, not Serena, not .serena/project.yml.

HOW RESTORE STAYS EXACT
-----------------------
Rather than reversing the text surgery (fragile: an off-by-one in marker
handling silently duplicates or drops a block), --apply first stores a
PRISTINE copy of the stock file, keyed by package version, and --restore
copies that back byte for byte. --apply always rebuilds from the pristine
copy, so it is idempotent no matter how many times it runs.

DURABILITY
----------
This patch edits the file INSIDE the installed npm package. Any
`npm install` / `pi install` / `pi update` that reinstalls @bacnh85/pi-serena
WILL OVERWRITE IT. Re-run `--apply` afterwards. When the package version
changes, --apply notices the file is stock again and refreshes the pristine
copy for the new revision.

USAGE
-----
  python apply-serena-tools-patch.py --check     # report only, changes nothing
  python apply-serena-tools-patch.py --apply     # patch (stores pristine copy)
  python apply-serena-tools-patch.py --restore   # byte-exact undo
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

PKG_NAME = "@bacnh85/pi-serena"
HERE = Path(__file__).resolve().parent
STORE = HERE / "store"
PKG_DIR = Path()
TARGET = Path()
PKG_JSON = Path()
BACKUP_ROOT = Path()


def configure_paths(agent_dir: Path) -> None:
    """Resolve all writable/runtime paths from the selected Pi profile."""
    global PKG_DIR, TARGET, PKG_JSON, BACKUP_ROOT
    PKG_DIR = agent_dir / "npm" / "node_modules" / "@bacnh85" / "pi-serena"
    TARGET = PKG_DIR / "extensions" / "index.ts"
    PKG_JSON = PKG_DIR / "package.json"
    BACKUP_ROOT = agent_dir / ".pi-agent-build-backups" / "serena-tools"

MARKER = "// [local-compat-patch]"
MARKER_END = "// [/local-compat-patch]"

PATCHED_TOOLS = {
    "serena_check_onboarding_performed": (
        "Serena 1.7.0 deleted this tool; onboarding is now an agent mode"
    ),
    "serena_find_implementations": (
        "Pyright does not advertise implementationProvider (LSP backend limit); "
        "re-test before restoring"
    ),
}

AUTHORED_AGAINST = "0.9.16"
STOCK_BLOCK_COUNT = 20
PATCHED_BLOCK_COUNT = STOCK_BLOCK_COUNT - len(PATCHED_TOOLS)


# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #
def installed_version() -> str | None:
    if not PKG_JSON.exists():
        return None
    try:
        return json.loads(PKG_JSON.read_text(encoding="utf-8")).get("version")
    except Exception:
        return None


def serena_version() -> str | None:
    try:
        out = subprocess.run(
            ["serena", "--version"], capture_output=True, text=True, timeout=60
        ).stdout
        m = re.search(r"(\d+\.\d+\.\d+)", out)
        return m.group(1) if m else None
    except Exception:
        return None


def read_raw(path: Path) -> str:
    """Read preserving the file's original line endings.

    Path.read_text() applies universal-newline translation, which silently
    rewrites CRLF to LF — invisible in a diff that ignores carriage returns,
    but it changes the file by one byte per line. Read and write bytes so the
    untouched parts of the file stay byte-identical.
    """
    return path.read_bytes().decode("utf-8")


def write_raw(path: Path, text: str) -> None:
    path.write_bytes(text.encode("utf-8"))


def count_registrations(text: str) -> int:
    """Count ACTIVE (non-commented) pi.registerTool blocks.

    Anchored on horizontal whitespace only: Python's \\s also matches newlines,
    so a `^\\s*` pattern spans lines and over-counts.
    """
    return len(re.findall(r"^[ \t]*pi\.registerTool\(\{", text, re.M))


def registered_names(text: str) -> list[str]:
    return re.findall(r'^[ \t]*name: "(serena_[a-z_]+)"', text, re.M)


def is_patched(text: str, tool_name: str) -> bool:
    return f"{MARKER} {tool_name}" in text


def pristine_path(version: str | None) -> Path:
    return STORE / f"index.ts.orig-{version or 'unknown'}"


def find_blocks(text: str, tool_name: str) -> list[tuple[int, int]]:
    """(start, end) char offsets of the pi.registerTool({...}); block
    registering tool_name; end is exclusive."""
    spans: list[tuple[int, int]] = []
    for m in re.finditer(re.escape(f'name: "{tool_name}"'), text):
        start = text.rfind("pi.registerTool({", 0, m.start())
        if start == -1:
            continue
        close = text.find("\n  });", m.end())
        if close == -1:
            continue
        spans.append((start, close + len("\n  });")))
    return spans


def comment_out(text: str, tool_name: str) -> tuple[str, int]:
    spans = find_blocks(text, tool_name)
    if not spans:
        return text, 0
    for start, end in sorted(spans, reverse=True):
        indent = "  "
        block = text[start:end]
        commented = "\n".join(
            (f"{indent}// {line}" if line.strip() else f"{indent}//")
            for line in block.split("\n")
        )
        reason = PATCHED_TOOLS.get(tool_name, "")
        header = (
            f"{indent}{MARKER} {tool_name}: disabled locally -> {reason}\n"
            f"{indent}// Restore with: python apply-serena-tools-patch.py --restore\n"
        )
        footer = f"\n{indent}{MARKER_END} {tool_name}"
        text = text[:start] + header + commented + footer + text[end:]
    return text, len(spans)


def make_backup(tag: str) -> Path:
    BACKUP_ROOT.mkdir(parents=True, exist_ok=True)
    ts = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    dst = BACKUP_ROOT / f"pi-serena-index.ts.{tag}-{ts}"
    shutil.copy2(TARGET, dst)
    return dst


def emit_patched_from(pristine_text: str) -> tuple[str, list[str], list[str]]:
    """Deterministically build the patched text from a pristine body."""
    text = pristine_text
    done, skipped = [], []
    for tool in PATCHED_TOOLS:
        if not find_blocks(text, tool):
            skipped.append(tool)
            continue
        text, _ = comment_out(text, tool)
        done.append(tool)
    return text, done, skipped


# --------------------------------------------------------------------------- #
# commands
# --------------------------------------------------------------------------- #
def cmd_check() -> int:
    print("=== tool-surface compatibility patch: CHECK ===")
    ver = installed_version()
    if ver is None:
        print(f"  package NOT installed at {PKG_DIR}")
        return 2
    print(f"  package:          {PKG_NAME} {ver}")
    if not TARGET.exists():
        print(f"  index.ts NOT found at {TARGET}")
        return 2
    print(f"  serena-agent:     {serena_version() or 'unknown'}")

    text = read_raw(TARGET)
    active = count_registrations(text)
    names = registered_names(text)
    print(f"  active registerTool blocks: {active}")
    print(f"  registered serena_* names:  {len(names)}")

    pristine = pristine_path(ver)
    print(f"  pristine copy:    {pristine.name} "
          f"({'present' if pristine.exists() else 'MISSING'})")

    if ver != AUTHORED_AGAINST:
        print(f"\n  NOTE: authored against {AUTHORED_AGAINST}, installed {ver}.")
        print("  Blocks are matched by content, not by version string.")

    print("\n  --- per-tool state ---")
    needs_patch, already = [], []
    for tool, reason in PATCHED_TOOLS.items():
        has_block = bool(find_blocks(text, tool))
        patched = is_patched(text, tool)
        if patched:
            state = "PATCHED (disabled)"
            already.append(tool)
        elif has_block:
            state = "ACTIVE -> patch needed"
            needs_patch.append(tool)
        else:
            state = "not registered by this revision"
        print(f"    {tool:38} {state}")
        if not has_block and not patched:
            print(f"      known reason: {reason}")

    print("\n  --- verdict ---")
    if needs_patch:
        print(f"  PATCH REQUIRED for: {', '.join(needs_patch)}")
        print(f"  would leave {active - len(needs_patch)} active registerTool blocks")
        return 1
    if already:
        print(f"  ALREADY PATCHED ({len(already)} disabled), "
              f"{active} active blocks. Nothing to do.")
        print("  Use --restore to return to stock.")
        return 0
    print("  PATCH NOT REQUIRED: neither dead tool is registered by this revision.")
    print("  Upstream likely fixed it — this patch can be dropped.")
    return 0


def cmd_apply() -> int:
    print("=== tool-surface compatibility patch: APPLY ===")
    if not TARGET.exists():
        print(f"  index.ts NOT found at {TARGET}")
        return 2
    ver = installed_version()
    print(f"  package: {PKG_NAME} {ver}")

    text = read_raw(TARGET)
    patched_now = any(is_patched(text, t) for t in PATCHED_TOOLS)
    pristine = pristine_path(ver)

    if patched_now and pristine.exists():
        base = read_raw(pristine)
        print(f"  rebuilding from pristine copy: {pristine.name}")
    else:
        # Stock file (fresh install or after an npm update): capture it first.
        if count_registrations(text) < len(PATCHED_TOOLS) + 1:
            print("  refusing to patch: file does not look like a stock extension")
            return 2
        STORE.mkdir(parents=True, exist_ok=True)
        write_raw(pristine, text)
        print(f"  pristine copy stored: {pristine}")
        base = text

    before = count_registrations(base)
    new_text, done, skipped = emit_patched_from(base)
    for t in done:
        print(f"  {t:38} disabled")
    for t in skipped:
        print(f"  {t:38} no registration block found, skipped")

    if not done:
        print("  nothing to do")
        return 0

    if new_text == text:
        print("  file already in patched state (idempotent)")
        return 0

    backup = make_backup("bak")
    print(f"  backup: {backup}")
    write_raw(TARGET, new_text)

    after = count_registrations(read_raw(TARGET))
    print(f"\n  active registerTool blocks: {before} -> {after}")
    if after != before - len(done):
        print("  WARNING: disabled count does not match active-block delta — inspect the file")
    print("  restart Pi (or /reload) so the extension reloads")
    return 0


def cmd_restore() -> int:
    print("=== tool-surface compatibility patch: RESTORE ===")
    if not TARGET.exists():
        print(f"  index.ts NOT found at {TARGET}")
        return 2
    ver = installed_version()
    pristine = pristine_path(ver)
    text = read_raw(TARGET)

    if any(is_patched(text, t) for t in PATCHED_TOOLS) and not pristine.exists():
        print(f"  no pristine copy for version {ver} — cannot restore byte-exactly")
        return 2

    if not any(is_patched(text, t) for t in PATCHED_TOOLS):
        print("  file is already stock — nothing to restore")
        return 0

    if not pristine.exists():
        print(f"  pristine copy missing: {pristine}")
        return 2

    backup = make_backup("patched")
    print(f"  backup of patched state: {backup}")
    shutil.copy2(pristine, TARGET)
    print(f"  restored from pristine copy: {pristine.name}")
    after = count_registrations(read_raw(TARGET))
    print(f"  active registerTool blocks: {after}")
    print("  restart Pi (or /reload) so the extension reloads")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Disable dead Serena tools in the Pi wrapper (local patch)."
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
