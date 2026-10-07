#!/usr/bin/env python3
"""Exact pi-session-search 1.6.0 profile roots, containment and timer patch."""
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
REL_FILES = tuple(map(pathlib.Path, ("src/config.ts", "src/parser.ts", "dist/index.js", "src/index.ts")))
STOCK_HASHES = (
    "e6103a7010615e059a01a3954d3135092b46e197cec6ce878ae84271c9211427",
    "2f67818bc768a3f7e89aa2f8135cf8fb70611b148dfbd7ef41e8cf7d3dd1746a",
    "9d011f994d6de8bb873ba242a9b705ab560046a4eae3c66c75068c98aa29090b",
    "e2e36ee96ca972d8e98bc9dec857ca1ac883c1063f8f8ca11786713d3f1574bc",
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


def patch_parser(text, runtime_only, dist=False):
    join = "join2" if dist else "join"
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


def canonical_files(runtime_only=False):
    stock = read_files(STORE)
    if tuple(hashlib.sha256(stock[r]).hexdigest() for r in REL_FILES) != STOCK_HASHES:
        raise RuntimeError("immutable stock hash mismatch")
    c, p, d, i = (stock[r].decode("utf-8") for r in REL_FILES)
    if not runtime_only:
        c = replace_once(c, 'return join(homedir(), ".pi", "session-search");', 'return process.env.PI_CODING_AGENT_DIR?.trim() ? join(process.env.PI_CODING_AGENT_DIR.trim(), "session-search") : join(homedir(), ".pi", "session-search"); // local-profile-patch', "config")
        d = replace_once(d, 'return join(homedir(), ".pi", "session-search");', 'return process.env.PI_CODING_AGENT_DIR?.trim() ? join(process.env.PI_CODING_AGENT_DIR.trim(), "session-search") : join(homedir(), ".pi", "session-search"); // local-profile-patch', "dist config")
    p = patch_parser(p, runtime_only)
    d = patch_index(patch_parser(d, runtime_only, True))
    i = patch_index(i, True)
    return stock, dict(zip(REL_FILES, (v.encode("utf-8") for v in (c, p, d, i))))


def classify(root, runtime_only=False):
    stock, canonical = canonical_files(runtime_only)
    current = read_files(root)
    return ("patched" if current == canonical else "stock" if current == stock else "unknown"), stock, canonical


def runtime_backup(root, label):
    dst = BACKUP_ROOT / f"{label}-{dt.datetime.now().strftime('%Y%m%d-%H%M%S-%f')}"
    for rel in REL_FILES:
        (dst / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(root / rel, dst / rel)
    return dst


def apply(root, runtime_only=False):
    state, stock, canonical = classify(root, runtime_only)
    if state == "patched":
        print("ALREADY PATCHED")
        return
    if state != "stock":
        raise RuntimeError("unknown/mixed installed state")
    print(f"runtime backup: {runtime_backup(root, state)}")
    for rel, body in canonical.items():
        (root / rel).write_bytes(body)
    subprocess.run(["node", "--check", str(root / REL_FILES[2])], check=True)
    if read_files(root) != canonical:
        raise RuntimeError("post-write verification failed")
    print("PATCH APPLIED")


def restore(root, runtime_only=False):
    state, stock, canonical = classify(root, runtime_only)
    if state == "stock":
        print("ALREADY STOCK")
        return
    if state != "patched":
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
            return {"patched": 0, "stock": 1, "unknown": 2}[state]
        (apply if args.apply else restore)(root, args.runtime_only)
        return 0
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

if __name__ == "__main__":
    raise SystemExit(main())
