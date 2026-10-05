#!/usr/bin/env python3
"""Make pi-session-search 1.4.3 respect PI_CODING_AGENT_DIR.

The repository store is immutable. Apply and restore accept only byte-exact
stock/canonical states and keep runtime backups under the selected profile.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
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
BACKUP_ROOT = pathlib.Path()
STOCK_HASHES = (
    '625fdbefd346e8b2b820be6319eea8bd66779bced277dca81a2fa3974355b912',
    '2f67818bc768a3f7e89aa2f8135cf8fb70611b148dfbd7ef41e8cf7d3dd1746a',
    'e89d2d9d69380559ed735c378fdab2d43a3d8e546bfcab941ee69c0895b6f545',
)
TIMER_OLD = '''        const runSync = () => Promise.race([
          sessionIndex.sync(
            (msg) => ctx.ui.setStatus("session-search", msg),
            notifySyncError(ctx)
          ),
          new Promise(
            (resolve2) => scheduleTimer(() => resolve2(null), SYNC_TIMEOUT_MS)
          )
        ]);'''
TIMER_NEW = '''        const runSync = () => {
          let timeout;
          return Promise.race([
            sessionIndex.sync(
              (msg) => ctx.ui.setStatus("session-search", msg),
              notifySyncError(ctx)
            ),
            new Promise((resolve2) => {
              timeout = scheduleTimer(() => resolve2(null), SYNC_TIMEOUT_MS);
            })
          ]).finally(() => {
            clearTimeout(timeout);
            pendingTimers.delete(timeout);
          });
        };'''

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


def configure_paths(agent_dir: pathlib.Path) -> None:
    global BACKUP_ROOT
    BACKUP_ROOT = agent_dir / ".pi-agent-build-backups" / "session-search-profile"


def assert_version(root: pathlib.Path) -> None:
    package_file = root / "package.json"
    if not package_file.is_file():
        raise RuntimeError(f"package.json missing: {package_file}")
    package = json.loads(package_file.read_text(encoding="utf-8"))
    actual = package.get("version")
    if actual != VERSION:
        raise RuntimeError(f"unsupported pi-session-search {actual}; expected exactly {VERSION}")
    missing = [str(rel) for rel in REL_FILES if not (root / rel).is_file()]
    if missing:
        raise RuntimeError(f"installed files missing: {missing}")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


def read_files(root: pathlib.Path) -> dict[pathlib.Path, bytes]:
    return {rel: (root / rel).read_bytes() for rel in REL_FILES}


def canonical_files(runtime_only: bool = False, *, timers: bool = True) -> tuple[dict[pathlib.Path, bytes], dict[pathlib.Path, bytes]]:
    missing = [str(rel) for rel in REL_FILES if not (STORE / rel).is_file()]
    if missing:
        raise RuntimeError(f"immutable pristine files missing: {missing}")
    stock = read_files(STORE)
    if tuple(hashlib.sha256(stock[r]).hexdigest() for r in REL_FILES) != STOCK_HASHES:
        raise RuntimeError("immutable stock hash mismatch")
    c = stock[REL_FILES[0]].decode("utf-8")
    p = stock[REL_FILES[1]].decode("utf-8")
    d = stock[REL_FILES[2]].decode("utf-8")
    c = replace_once(c, CONFIG_OLD, CONFIG_NEW, "src/config.ts")
    p = replace_once(p, PARSER_OLD, PARSER_NEW, "src/parser.ts")
    d = replace_once(d, DIST_CONFIG_OLD, DIST_CONFIG_NEW, "dist config")
    d = replace_once(d, DIST_PARSER_OLD, DIST_PARSER_NEW, "dist parser")
    if runtime_only:
        c, p, d = (stock[r].decode("utf-8") for r in REL_FILES)
    if timers:
        d = replace_once(d, TIMER_OLD, TIMER_NEW, "dist sync timeout")
    canonical = {
        REL_FILES[0]: c.encode("utf-8"),
        REL_FILES[1]: p.encode("utf-8"),
        REL_FILES[2]: d.encode("utf-8"),
    }
    return stock, canonical


def classify(root: pathlib.Path, runtime_only: bool = False) -> tuple[str, dict[pathlib.Path, bytes], dict[pathlib.Path, bytes]]:
    stock, canonical = canonical_files(runtime_only)
    current = read_files(root)
    if current == canonical:
        return "patched", stock, canonical
    if current == stock:
        return "stock", stock, canonical
    if not runtime_only and current == canonical_files(timers=False)[1]:
        return "legacy-canonical", stock, canonical
    return "unknown", stock, canonical


def runtime_backup(root: pathlib.Path, label: str) -> pathlib.Path:
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    target = BACKUP_ROOT / f"{label}-{stamp}"
    for rel in REL_FILES:
        dst = target / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(root / rel, dst)
    return target


def apply(root: pathlib.Path, runtime_only: bool = False) -> None:
    status, _stock, canonical = classify(root, runtime_only)
    if status == "patched":
        print("ALREADY PATCHED")
        return
    if status not in {"stock", "legacy-canonical"}:
        raise RuntimeError("installed files differ from immutable stock and canonical patch")
    print(f"runtime backup: {runtime_backup(root, status)}")
    for rel, body in canonical.items():
        (root / rel).write_bytes(body)
    subprocess.run(["node", "--check", str(root / REL_FILES[2])], check=True)
    if read_files(root) != canonical:
        raise RuntimeError("post-write verification failed")
    print("PATCH APPLIED")


def restore(root: pathlib.Path, runtime_only: bool = False) -> None:
    status, stock, _canonical = classify(root, runtime_only)
    if status == "stock":
        print("ALREADY STOCK")
        return
    if status not in {"patched", "legacy-canonical"}:
        raise RuntimeError("installed files are neither immutable stock nor canonical patch")
    print(f"runtime backup: {runtime_backup(root, 'patched')}")
    for rel, body in stock.items():
        (root / rel).write_bytes(body)
    if read_files(root) != stock:
        raise RuntimeError("post-restore verification failed")
    print("RESTORED BYTE-EXACT")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--agent-dir", required=True)
    ap.add_argument("--runtime-only", action="store_true", help="Code: timer cleanup only; preserve stock paths")
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--apply", action="store_true")
    mode.add_argument("--restore", action="store_true")
    args = ap.parse_args()
    agent_dir = pathlib.Path(args.agent_dir).expanduser().resolve()
    configure_paths(agent_dir)
    root = package_root(agent_dir)
    if not root.is_dir():
        print(f"ERROR: package not found: {root}", file=sys.stderr)
        return 2
    try:
        assert_version(root)
        if args.check:
            status, _stock, _canonical = classify(root, args.runtime_only)
            print(f"version={VERSION} state={status}")
            print("ALREADY PATCHED" if status == "patched" else "PATCH REQUIRED" if status in {"stock", "legacy-canonical"} else "UNKNOWN STATE")
            return 0 if status == "patched" else 1 if status in {"stock", "legacy-canonical"} else 2
        if args.apply:
            apply(root, args.runtime_only)
        else:
            restore(root, args.runtime_only)
        return 0
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
