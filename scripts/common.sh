#!/usr/bin/env bash
# common.sh — POSIX helpers for the portable Pi Agent build (macOS/Linux).
#
# Mirrors scripts/common.ps1 for the Windows build. Sourced by the POSIX
# installer, patch orchestrator, launcher installer, verifier and safety scan.
# Requires bash 3.2+ (the default /bin/bash on macOS) and python3 for JSON.
#
# shellcheck shell=bash

set -euo pipefail

# --------------------------------------------------------------------------- #
# logging
# --------------------------------------------------------------------------- #
log()  { printf '%s\n' "$*"; }
warn() { printf 'WARN %s\n' "$*" >&2; }
err()  { printf 'ERROR %s\n' "$*" >&2; }

# --------------------------------------------------------------------------- #
# python resolution (used for JSON parsing and version comparison)
# --------------------------------------------------------------------------- #
resolve_python() {
  if [ -n "${PI_BUILD_PYTHON:-}" ]; then printf '%s' "$PI_BUILD_PYTHON"; return 0; fi
  local c
  for c in python3 python; do
    if command -v "$c" >/dev/null 2>&1; then printf '%s' "$c"; return 0; fi
  done
  return 1
}

require_python() {
  resolve_python >/dev/null 2>&1 || { err "python3 is required (patchers, JSON, version checks)"; return 2; }
}

# --------------------------------------------------------------------------- #
# JSON
# --------------------------------------------------------------------------- #
# json_get <file> <python expression evaluated with variable `d`>
json_get() {
  local file="$1" expr="$2" py
  py="$(resolve_python)" || { err "python3 is required to parse JSON: $file"; return 2; }
  "$py" - "$file" "$expr" <<'PY'
import json, sys
path, expr = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as fh:
    d = json.load(fh)
v = eval(expr, {"__builtins__": {}}, {"d": d})
if isinstance(v, (dict, list)):
    print(json.dumps(v, ensure_ascii=False))
elif v is not None:
    print(v)
PY
}

# manifest_packages <manifest> <Code|Task>
# Emits one record per package, fields joined by the ASCII unit separator
# (0x1f). Do NOT use TAB: bash treats TAB as IFS whitespace and collapses
# runs of it, which shifts empty fields (patch/taskProfilePatch/kind).
#   source  package  version  patch  taskProfilePatch  kind  commit  tagObject  releaseTag
manifest_packages() {
  local manifest="$1" profile="$2" py
  py="$(resolve_python)" || { err "python3 is required to read $manifest"; return 2; }
  "$py" - "$manifest" "$profile" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as fh:
    m = json.load(fh)
profile = sys.argv[2]
entries = list(m["profiles"]["common"])
if profile == "Code":
    entries += list(m["profiles"].get("codeOnly", []))
for e in entries:
    print("\x1f".join(str(e.get(k, "")) for k in (
        "source", "package", "version", "patch", "taskProfilePatch",
        "kind", "commit", "tagObject", "releaseTag",
    )))
PY
}

# Field separator used by manifest_packages and external-tool listings.
IFS_US=$'\x1f'

# --------------------------------------------------------------------------- #
# profiles
# --------------------------------------------------------------------------- #
# selected_profiles <Code|Task|Both>  -> lines "Name<TAB>directory"
selected_profiles() {
  case "$1" in
    Code) printf 'Code\tagent\n' ;;
    Task) printf 'Task\ttask\n' ;;
    Both) printf 'Code\tagent\nTask\ttask\n' ;;
    *) err "unknown profile: $1"; return 2 ;;
  esac
}

# --------------------------------------------------------------------------- #
# paths and backups
# --------------------------------------------------------------------------- #
resolve_full_path() {
  local p="$1"
  if [ -d "$p" ]; then (cd "$p" && pwd -P); else
    local d b; d="$(dirname "$p")"; b="$(basename "$p")"
    (cd "$d" 2>/dev/null && printf '%s/%s\n' "$(pwd -P)" "$b") || printf '%s\n' "$p"
  fi
}

backup_stamp() {
  date '+%Y%m%d-%H%M%S'
}

# backup_file_if_present <source> <backup_dir> <backup_name>
backup_file_if_present() {
  local src="$1" dir="$2" name="$3"
  [ -f "$src" ] || return 0
  mkdir -p "$dir"
  mkdir -p "$(dirname "$dir/$name")"
  cp -p "$src" "$dir/$name"
  printf '%s\n' "$dir/$name"
}

# copy_file_with_backup <source> <destination> <backup_dir> [backup_name]
# Prints: unchanged | written
copy_file_with_backup() {
  local src="$1" dst="$2" dir="$3" name="${4:-}"
  [ -f "$src" ] || { err "source file not found: $src"; return 2; }
  if [ -f "$dst" ]; then
    if cmp -s "$src" "$dst"; then printf 'unchanged\n'; return 0; fi
    [ -n "$name" ] || name="$(basename "$dst")"
    backup_file_if_present "$dst" "$dir" "$name" >/dev/null
  fi
  mkdir -p "$(dirname "$dst")"
  cp -p "$src" "$dst"
  printf 'written\n'
}

# install_profile_file <source> <destination> <backup_dir> <backup_name> <replace:0|1>
install_profile_file() {
  local src="$1" dst="$2" dir="$3" name="$4" replace="$5"
  if [ -f "$dst" ] && [ "$replace" != "1" ]; then printf 'preserved\n'; return 0; fi
  copy_file_with_backup "$src" "$dst" "$dir" "$name"
}

# install_profile_directory <source> <destination> <backup_dir> <backup_name> <replace:0|1>
install_profile_directory() {
  local src="$1" dst="$2" dir="$3" name="$4" replace="$5"
  [ -d "$src" ] || { err "source directory not found: $src"; return 2; }
  if [ -d "$dst" ] && [ "$replace" != "1" ]; then printf 'preserved\n'; return 0; fi
  if [ -d "$dst" ]; then
    [ -n "$name" ] || name="$(basename "$dst")"
    mkdir -p "$dir"
    [ -e "$dir/$name" ] && { err "backup destination already exists: $dir/$name"; return 2; }
    mkdir -p "$(dirname "$dir/$name")"
    cp -R "$dst" "$dir/$name"
    rm -rf "$dst"
  fi
  mkdir -p "$(dirname "$dst")"
  cp -R "$src" "$dst"
  printf 'written\n'
}

# --------------------------------------------------------------------------- #
# command helpers
# --------------------------------------------------------------------------- #
# command_output <command> [args...] -> prints stdout+stderr; never fails the caller
command_output() {
  "$@" 2>&1 || true
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

# get_version_from_text <text> -> first dotted version token (empty if none)
get_version_from_text() {
  printf '%s' "$1" | grep -oE '[0-9]+\.[0-9]+(\.[0-9A-Za-z][0-9A-Za-z.-]*)?' | head -n1 || true
}

# version_ge <actual> <minimum> -> 0 if actual >= minimum
version_ge() {
  local py
  py="$(resolve_python)" || return 2
  "$py" - "$1" "$2" <<'PY'
import re, sys
def parts(v):
    m = re.search(r"(\d+(?:\.\d+)*)", v or "")
    return tuple(int(x) for x in m.group(1).split(".")) if m else ()
a, b = parts(sys.argv[1]), parts(sys.argv[2])
sys.exit(0 if a and b and a >= b else 1)
PY
}

# run_checked <label> <command> [args...]
run_checked() {
  local label="$1"; shift
  log "RUN  $label: $*"
  if ! "$@"; then err "$label failed"; return 1; fi
}

# --------------------------------------------------------------------------- #
# memory embedder warm-up
# --------------------------------------------------------------------------- #
# warm_memory_embedder <profile_root> [timeout_ms] [retries]
# Pre-downloads the pi-memory local embedding model into the profile's
# @xenova/transformers cache. The plugin loads the model lazily with a 30s
# timeout; a cold download on a slow link can exceed it and the plugin then
# silently falls back to FTS-only search. Network speed varies, so this uses a
# generous timeout with bounded retries and never fails the whole install.
# Prints: warmed | already-cached | skipped | failed
warm_memory_embedder() {
  local profile_root="$1" timeout_ms="${2:-600000}" retries="${3:-3}"
  local dist="$profile_root/npm/node_modules/@samfp/pi-memory/dist/index.js"
  [ -f "$dist" ] || { printf 'skipped\n'; return 0; }
  command_exists node || { warn "node not found; skipping memory embedder warm-up"; printf 'skipped\n'; return 0; }
  local helper="$SCRIPT_DIR/warm-memory-embedder.mjs"
  [ -f "$helper" ] || { warn "warm-up helper missing: $helper"; printf 'skipped\n'; return 0; }
  local out code
  set +e
  out="$(node "$helper" "$profile_root" --timeout-ms "$timeout_ms" --retries "$retries" 2>&1)"
  code=$?
  set -e
  [ -n "$out" ] && printf '%s\n' "$out" >&2
  if [ "$code" = "0" ]; then
    printf 'warmed\n'
  else
    warn "memory embedder warm-up failed (exit $code); semantic memory search stays FTS-only until the model downloads"
    printf 'failed\n'
  fi
  return 0
}

# --------------------------------------------------------------------------- #
# installed package assertions
# --------------------------------------------------------------------------- #
# assert_installed_package <profile_root> <source> <package> <version>
assert_installed_package() {
  local profile_root="$1" source="$2" pkg="$3" ver="$4" py
  py="$(resolve_python)" || return 2
  case "$source" in
    npm:*)
      local meta="$profile_root/npm/node_modules/$pkg/package.json"
      [ -f "$meta" ] || { err "installed package missing: $pkg"; return 1; }
      local actual; actual="$(json_get "$meta" 'd.get("version")')"
      [ "$actual" = "$ver" ] || { err "$pkg version mismatch: expected $ver, found $actual"; return 1; }
      log "PASS $pkg@$ver"
      ;;
    https://github.com/*)
      # source: https://github.com/<owner>/<repo>@<commit>
      local rest owner repo commit git_root head
      rest="${source#https://github.com/}"
      owner="${rest%%/*}"
      rest="${rest#*/}"
      repo="${rest%@*}"; commit="${rest##*@}"
      repo="${repo%.git}"
      git_root="$profile_root/git/github.com/$owner/$repo"
      [ -d "$git_root/.git" ] || { err "installed Git checkout missing: $git_root"; return 1; }
      head="$(git -C "$git_root" rev-parse HEAD 2>/dev/null || true)"
      [ "$head" = "$commit" ] || { err "$pkg HEAD $head != pinned $commit"; return 1; }
      log "PASS $pkg@$ver (git $commit)"
      ;;
    *) err "unsupported installed source: $source"; return 1 ;;
  esac
}

# --------------------------------------------------------------------------- #
# settings / models merge (preserve unknown user fields)
# --------------------------------------------------------------------------- #
# merge_preserved_settings <destination> <template> <packages_manifest> <profile> <backup_dir>
merge_preserved_settings() {
  local dst="$1" template="$2" manifest="$3" profile="$4" backup_dir="$5" py
  py="$(resolve_python)" || return 2
  backup_file_if_present "$dst" "$backup_dir" "settings.before-merge.json" >/dev/null
  "$py" - "$dst" "$template" "$manifest" "$profile" <<'PY'
import json, re, sys
dst, template, manifest, profile = sys.argv[1:5]

def load(p):
    with open(p, encoding="utf-8") as fh:
        return json.load(fh)

with open(manifest, encoding="utf-8") as fh:
    m = json.load(fh)
entries = list(m["profiles"]["common"])
if profile == "Code":
    entries += list(m["profiles"].get("codeOnly", []))
build_names = {e["package"] for e in entries}

def identity(item):
    src = item if isinstance(item, str) else item.get("source", "")
    mm = re.match(r"^npm:(@[^/]+/[^@]+|[^@]+)(?:@.+)?$", src)
    if mm:
        return mm.group(1)
    if re.search(r"(?i)pi-polza(?:-connection-plugin)?(?:@|[\\/]|$)", src):
        return "pi-polza"
    return src

current = load(dst)
desired = load(template)

extras = [item for item in current.get("packages", []) if identity(item) not in build_names]
current["packages"] = list(desired["packages"]) + extras

mem = current.setdefault("memory", {})
mem["consolidationModel"] = desired["memory"]["consolidationModel"]

with open(dst, "w", encoding="utf-8") as fh:
    json.dump(current, fh, ensure_ascii=False, indent=2)
    fh.write("\n")
PY
  printf 'merged\n'
}

# merge_polza_memory_provider <destination> <template> <backup_dir>
merge_polza_memory_provider() {
  local dst="$1" template="$2" backup_dir="$3" py
  py="$(resolve_python)" || return 2
  "$py" - "$dst" "$template" "$backup_dir" <<'PY'
import json, sys, shutil, os
dst, template, backup_dir = sys.argv[1:4]
with open(dst, encoding="utf-8") as fh:
    current = json.load(fh)
with open(template, encoding="utf-8") as fh:
    desired = json.load(fh)
providers = current.setdefault("providers", {})
if "polza-memory" in providers:
    print("preserved")
    sys.exit(0)
os.makedirs(backup_dir, exist_ok=True)
shutil.copy2(dst, os.path.join(backup_dir, "models.before-merge.json"))
providers["polza-memory"] = desired["providers"]["polza-memory"]
with open(dst, "w", encoding="utf-8") as fh:
    json.dump(current, fh, ensure_ascii=False, indent=2)
    fh.write("\n")
print("merged")
PY
}
