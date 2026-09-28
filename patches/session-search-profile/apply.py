#!/usr/bin/env python3
"""Make pi-session-search 1.4.3 respect PI_CODING_AGENT_DIR.

Usage:
  python apply.py --agent-dir <USER_HOME>/.pi/task --check
  python apply.py --agent-dir <USER_HOME>/.pi/task --apply
  python apply.py --agent-dir <USER_HOME>/.pi/task --restore
"""
from __future__ import annotations

import argparse
import json
import pathlib
import shutil
import subprocess
import sys

VERSION = "1.4.3"
MARKER = "local-profile-patch"
HERE = pathlib.Path(__file__).resolve().parent
STORE = HERE / "store" / VERSION
REL_FILES = (
    pathlib.Path("src/config.ts"),
    pathlib.Path("src/parser.ts"),
    pathlib.Path("dist/index.js"),
)

CONFIG_OLD = '''function globalConfigDir(): string {
  return join(homedir(), ".pi", "session-search");
}'''
CONFIG_NEW = '''function globalConfigDir(): string {
  const agentDir = process.env.PI_CODING_AGENT_DIR?.trim();
  return agentDir
    ? join(agentDir, "session-search") // local-profile-patch
    : join(homedir(), ".pi", "session-search");
}'''

PARSER_OLD = '''function getDefaultSessionDir(): string {
  return (
    process.env.PI_SESSION_DIR ||
    join(process.env.HOME || "~", ".pi", "agent", "sessions")
  );
}

/**
 * Return the default session archive directory.
 * Honours `PI_SESSION_ARCHIVE_DIR` env var, falling back to the standard
 * global location.
 */
function getDefaultArchiveDir(): string {
  return (
    process.env.PI_SESSION_ARCHIVE_DIR ||
    join(process.env.HOME || "~", ".pi", "agent", "sessions-archive")
  );
}'''
PARSER_NEW = '''function getDefaultSessionDir(): string {
  const agentDir = process.env.PI_CODING_AGENT_DIR?.trim();
  return (
    process.env.PI_SESSION_DIR ||
    (agentDir
      ? join(agentDir, "sessions") // local-profile-patch
      : join(process.env.HOME || "~", ".pi", "agent", "sessions"))
  );
}

/**
 * Return the default session archive directory.
 * Honours `PI_SESSION_ARCHIVE_DIR` env var, falling back to the standard
 * global location.
 */
function getDefaultArchiveDir(): string {
  const agentDir = process.env.PI_CODING_AGENT_DIR?.trim();
  return (
    process.env.PI_SESSION_ARCHIVE_DIR ||
    (agentDir
      ? join(agentDir, "sessions-archive") // local-profile-patch
      : join(process.env.HOME || "~", ".pi", "agent", "sessions-archive"))
  );
}'''

DIST_CONFIG_OLD = '''function globalConfigDir() {
  return join(homedir(), ".pi", "session-search");
}'''
DIST_CONFIG_NEW = '''function globalConfigDir() {
  const agentDir = process.env.PI_CODING_AGENT_DIR?.trim();
  return agentDir ? join(agentDir, "session-search") : join(homedir(), ".pi", "session-search"); // local-profile-patch
}'''

DIST_PARSER_OLD = '''function getDefaultSessionDir() {
  return process.env.PI_SESSION_DIR || join2(process.env.HOME || "~", ".pi", "agent", "sessions");
}
function getDefaultArchiveDir() {
  return process.env.PI_SESSION_ARCHIVE_DIR || join2(process.env.HOME || "~", ".pi", "agent", "sessions-archive");
}'''
DIST_PARSER_NEW = '''function getDefaultSessionDir() {
  const agentDir = process.env.PI_CODING_AGENT_DIR?.trim();
  return process.env.PI_SESSION_DIR || (agentDir ? join2(agentDir, "sessions") : join2(process.env.HOME || "~", ".pi", "agent", "sessions")); // local-profile-patch
}
function getDefaultArchiveDir() {
  const agentDir = process.env.PI_CODING_AGENT_DIR?.trim();
  return process.env.PI_SESSION_ARCHIVE_DIR || (agentDir ? join2(agentDir, "sessions-archive") : join2(process.env.HOME || "~", ".pi", "agent", "sessions-archive")); // local-profile-patch
}'''


def package_root(agent_dir: pathlib.Path) -> pathlib.Path:
    return agent_dir / "npm" / "node_modules" / "pi-session-search"


def assert_version(root: pathlib.Path) -> None:
    package = json.loads((root / "package.json").read_text(encoding="utf-8"))
    actual = package.get("version")
    if actual != VERSION:
        raise RuntimeError(f"unsupported pi-session-search {actual}; expected exactly {VERSION}")


def save_pristine(root: pathlib.Path) -> None:
    STORE.mkdir(parents=True, exist_ok=True)
    for rel in REL_FILES:
        src, dst = root / rel, STORE / rel
        if not dst.exists():
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)


def state(root: pathlib.Path) -> list[bool]:
    return [MARKER in (root / rel).read_text(encoding="utf-8") for rel in REL_FILES]


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


def apply(root: pathlib.Path) -> None:
    current = state(root)
    if all(current):
        print("ALREADY PATCHED")
        return
    if any(current):
        raise RuntimeError(f"partial patch state: {current}")
    save_pristine(root)
    c = (STORE / REL_FILES[0]).read_text(encoding="utf-8")
    p = (STORE / REL_FILES[1]).read_text(encoding="utf-8")
    d = (STORE / REL_FILES[2]).read_text(encoding="utf-8")
    c = replace_once(c, CONFIG_OLD, CONFIG_NEW, "src/config.ts")
    p = replace_once(p, PARSER_OLD, PARSER_NEW, "src/parser.ts")
    d = replace_once(d, DIST_CONFIG_OLD, DIST_CONFIG_NEW, "dist config")
    d = replace_once(d, DIST_PARSER_OLD, DIST_PARSER_NEW, "dist parser")
    (root / REL_FILES[0]).write_text(c, encoding="utf-8", newline="")
    (root / REL_FILES[1]).write_text(p, encoding="utf-8", newline="")
    (root / REL_FILES[2]).write_text(d, encoding="utf-8", newline="")
    subprocess.run(["node", "--check", str(root / REL_FILES[2])], check=True)
    print("PATCH APPLIED")


def restore(root: pathlib.Path) -> None:
    missing = [str(rel) for rel in REL_FILES if not (STORE / rel).exists()]
    if missing:
        raise RuntimeError(f"pristine files missing: {missing}")
    for rel in REL_FILES:
        shutil.copy2(STORE / rel, root / rel)
    print("RESTORED BYTE-EXACT")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--agent-dir", required=True)
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--apply", action="store_true")
    mode.add_argument("--restore", action="store_true")
    args = ap.parse_args()
    root = package_root(pathlib.Path(args.agent_dir).expanduser().resolve())
    if not root.is_dir():
        print(f"ERROR: package not found: {root}", file=sys.stderr)
        return 2
    try:
        assert_version(root)
        if args.check:
            current = state(root)
            print(f"version={VERSION} files={current}")
            print("ALREADY PATCHED" if all(current) else "PATCH REQUIRED" if not any(current) else "PARTIAL PATCH")
            return 0 if all(current) or not any(current) else 2
        if args.apply:
            apply(root)
        else:
            restore(root)
        return 0
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
