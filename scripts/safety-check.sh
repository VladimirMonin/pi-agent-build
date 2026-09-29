#!/usr/bin/env bash
# safety-check.sh — POSIX public-repository safety scan.
#
# Mirrors scripts/safety-check.ps1. Scans the tracked tree (git checkout-index
# snapshot) and/or the working tree for credentials, personal absolute paths
# and forbidden runtime artifacts. Values are never printed in full — only
# file, line and match class.
#
# Usage:
#   scripts/safety-check.sh [--scope Tracked|Tree|Both] [--root <dir>]
#
# Exit codes: 0 clean; 1 findings; 2 fatal.
#
# shellcheck shell=bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
. "$SCRIPT_DIR/common.sh"

SCOPE="Both"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

while [ $# -gt 0 ]; do
  case "$1" in
    --scope) SCOPE="$2"; shift 2 ;;
    --root) ROOT="$2"; shift 2 ;;
    -h|--help) sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) err "unknown argument: $1"; exit 2 ;;
  esac
done

case "$SCOPE" in Tracked|Tree|Both) ;; *) err "invalid --scope: $SCOPE"; exit 2 ;; esac

ROOT="$(resolve_full_path "$ROOT")"
[ -d "$ROOT" ] || { err "scan root not found: $ROOT"; exit 2; }

PYTHON="$(resolve_python)" || { err "python3 is required for the safety scan"; exit 2; }

snapshot_root=""
cleanup() { [ -n "$snapshot_root" ] && [ -d "$snapshot_root" ] && rm -rf "$snapshot_root"; }
trap cleanup EXIT

# Build the file list (absolute paths, one per line) into a temp file.
file_list="$(mktemp)"
: > "$file_list"

is_work_tree=0
if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then is_work_tree=1; fi

if [ "$SCOPE" = "Tracked" ] || [ "$SCOPE" = "Both" ]; then
  [ "$is_work_tree" = "1" ] || { err "Tracked scan requires a Git work tree: $ROOT"; exit 2; }
  snapshot_root="$(mktemp -d)"
  git -C "$ROOT" checkout-index --all --force "--prefix=$snapshot_root/"
  find "$snapshot_root" -type f >> "$file_list"
fi

if [ "$SCOPE" = "Tree" ] || [ "$SCOPE" = "Both" ]; then
  if [ "$is_work_tree" = "1" ]; then
    while IFS= read -r rel; do
      [ -n "$rel" ] || continue
      [ -f "$ROOT/$rel" ] && printf '%s\n' "$ROOT/$rel" >> "$file_list"
    done < <(git -c core.quotepath=false -C "$ROOT" ls-files --cached --others --exclude-standard)
  else
    find "$ROOT" -type f -not -path '*/.git/*' >> "$file_list"
  fi
fi

# Deduplicate while preserving order.
sorted_list="$(mktemp)"
sort -u "$file_list" > "$sorted_list"

"$PYTHON" - "$sorted_list" "$snapshot_root" "$ROOT" <<'PY'
import os, re, sys

list_path, snapshot_root, root = sys.argv[1:4]

FORBIDDEN_LEAF = [
    re.compile(r"^auth\.json$"),
    re.compile(r"^\.env(\..+)?$"),
    re.compile(r"\.(db|db-wal|db-shm|sqlite|sqlite3|jsonl)$"),
    re.compile(r"\.(pem|key)$"),
    re.compile(r"^models-store\.json$"),
    re.compile(r"^mcp-cache\.json$"),
    re.compile(r"^trace\.html$"),
]
FORBIDDEN_PATH = re.compile(r"(?i)(?:^|/)(?:sessions|traces|missions|memory|node_modules|secrets|cache|\.cache)(?:/|$)")

SECRET_PREFIX = re.compile(r"(?i)(?:sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{30,})")
JWT = re.compile(r"(?<![A-Za-z0-9_-])eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}(?![A-Za-z0-9_-])")
CRED_ASSIGN = re.compile(r"(?i)(?:api[_-]?key|access[_-]?token|refresh[_-]?token|password|secret)\s*[=:]\s*[\"']?([A-Za-z0-9_./+=-]{16,})")
PERSONAL_PATH = re.compile(r"(?i)(?:[A-Z]:[\\/](?:Users[\\/][A-Za-z0-9][^<%$\\/\s]*|PY[\\/][A-Za-z0-9][^<%$\\/\s]*)|/(?:home|Users)/[A-Za-z0-9][^<${}/\s]*/)")
LONG_RANDOM = re.compile(r"(?<![A-Za-z0-9+/=_-])[A-Za-z0-9+/_-]{48,}={0,2}(?![A-Za-z0-9+/=_-])")

PLACEHOLDER = re.compile(
    r"^(?:PASTE_|CHANGE_ME|EXAMPLE|REDACTED|<[^>]+>|\$\{?[A-Z][A-Z0-9_]*\}?|\$[A-Z][A-Z0-9_]*|process\.env\.|os\.environ|apiKey\.{2,})"
    r"|^(?:true|false|null)$"
)

def entropy(value):
    if len(value) < 48:
        return 0.0
    counts = {}
    for ch in value:
        counts[ch] = counts.get(ch, 0) + 1
    import math
    total = len(value)
    return -sum((c / total) * math.log(c / total, 2) for c in counts.values())

findings = []
seen = set()

def add(path, line, cls):
    key = (path, line, cls)
    if key not in seen:
        seen.add(key)
        findings.append(key)

with open(list_path, encoding="utf-8") as fh:
    files = [ln.strip() for ln in fh if ln.strip()]

for full in files:
    if snapshot_root and full.startswith(snapshot_root):
        rel = os.path.relpath(full, snapshot_root)
    else:
        rel = os.path.relpath(full, root)
    rel = rel.replace(os.sep, "/")
    leaf = os.path.basename(full)

    for pat in FORBIDDEN_LEAF:
        if pat.search(leaf):
            add(rel, 0, "runtime-data-name")
            break
    if FORBIDDEN_PATH.search(rel):
        add(rel, 0, "runtime-data-path")

    try:
        size = os.path.getsize(full)
    except OSError:
        continue
    if size > 10 * 1024 * 1024:
        add(rel, 0, "oversized-unscanned-file")
        continue
    try:
        with open(full, "rb") as fh:
            data = fh.read()
    except OSError:
        continue
    if b"\x00" in data:
        continue
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        continue

    ext = os.path.splitext(full)[1].lower()
    for idx, line in enumerate(text.splitlines(), start=1):
        if SECRET_PREFIX.search(line):
            add(rel, idx, "secret-prefix")
        if JWT.search(line):
            add(rel, idx, "jwt-like-token")
        m = CRED_ASSIGN.search(line)
        if m and not PLACEHOLDER.match(m.group(1)):
            add(rel, idx, "credential-assignment")
        if PERSONAL_PATH.search(line):
            add(rel, idx, "personal-absolute-path")
        if ext in (".json", ".yaml", ".yml", ".md", ".env", ".toml"):
            for m2 in LONG_RANDOM.finditer(line):
                cand = m2.group(0)
                if re.fullmatch(r"[0-9a-fA-F]{64}", cand):
                    continue
                if PLACEHOLDER.match(cand):
                    continue
                if entropy(cand) < 4.5:
                    continue
                add(rel, idx, "long-random-string")
                break

if findings:
    for path, line, cls in sorted(findings):
        loc = f"{path}:{line}" if line > 0 else path
        print(f"FAIL {loc} [{cls}]")
    print(f"Safety scan failed: {len(findings)} finding(s). Values are intentionally redacted.")
    sys.exit(1)

print(f"PASS safety scan: {len(files)} file(s), no findings.")
sys.exit(0)
PY

rm -f "$file_list" "$sorted_list"
