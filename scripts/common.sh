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
  if [ -n "${PI_BUILD_PYTHON:-}" ]; then
    [ -f "$PI_BUILD_PYTHON" ] && "$PI_BUILD_PYTHON" -c 'import sys' >/dev/null 2>&1 || return 1
    printf '%s' "$PI_BUILD_PYTHON"; return 0
  fi
  local c
  for c in python3 python; do
    if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys' >/dev/null 2>&1; then printf '%s' "$c"; return 0; fi
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

# A Windows python.exe may emit CRLF through Git Bash pipes. Keep manifest
# records (including patch names) byte-exact on both platforms.
manifest_lines_lf() { "$@" | tr -d '\r'; }

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
# private lab path and environment gate (read-only until lab_run is invoked)
# --------------------------------------------------------------------------- #
lab_installed_state() (
  # Subshell confines cwd and environment changes even when the gate refuses.
  LAB_PYTHON="$(command -v "$(resolve_python)")" || exit 2
  local node git tool
  node="$(command -v node)"; git="$(command -v git)"
  [ -f "$node" ] && [ -f "$git" ] || { err 'absolute node/git required'; exit 2; }
  LAB_PATH="$LAB_PREFIX/bin:$LAB_PREFIX:$(dirname "$node"):$(dirname "$git"):$(dirname "$LAB_PYTHON"):/usr/bin:/bin"
  LAB_NAME=agent LAB_PROFILE="$PI_ROOT/agent"
  lab_run "$LAB_PYTHON" "$SCRIPT_DIR/lab-state.py" --lab-root "$LAB_ROOT" --repo-root "$REPO_ROOT" \
    --node "$node" --git "$git" "$@"
)

lab_preflight() {
  local py mode="${1:-fresh}"
  if [ "$mode" = installed ]; then lab_installed_state; return $?; fi
  py="$(resolve_python)" || return 2
  "$py" - "$LAB_ROOT" "$REPO_ROOT" "$PI_ROOT" "$LAB_PREFIX" "$LAB_CWD" "$mode" "${HOME:-}" "${USERPROFILE:-}" <<'PY'
import json, os, pathlib, sys
lab, repo, profiles, prefix, cwd = map(pathlib.Path, sys.argv[1:6])
mode = sys.argv[6]
homes = [pathlib.Path(home) for home in sys.argv[7:]]
if mode not in ('fresh', 'installed'): raise SystemExit('ERROR invalid lab preflight mode')
def reject(message):
    raise SystemExit('ERROR lab preflight: ' + message)
def normalized(path):
    if not path.is_absolute() or '..' in path.parts or str(path) in ('/', ''):
        reject('absolute path without parent traversal required: ' + str(path))
    # Never accept symlink/reparse ancestors, including missing path descendants.
    for part in (path, *path.parents):
        if part.is_symlink() or (hasattr(part, 'is_junction') and part.is_junction()):
            reject('symlink/reparse ancestor: ' + str(part))
    return path.resolve(strict=False)
def inside(path, parent):
    return path == parent or parent in path.parents
lab, repo, profiles, prefix, cwd = map(normalized, (lab, repo, profiles, prefix, cwd))
if not lab.is_dir() or not repo.is_dir() or inside(lab, repo) or inside(repo, lab):
    reject('lab and repository must be disjoint existing directories')
# Inspect links before reading any config/marker under the lab. Never follow a
# linked directory while walking, including Windows junctions.
for current, dirs, files in os.walk(lab, followlinks=False):
    for entry in list(dirs) + files:
        p = pathlib.Path(current) / entry
        if p.is_symlink() or (hasattr(p, 'is_junction') and p.is_junction()):
            if entry in dirs: dirs.remove(entry)
            if mode == 'fresh': reject('symlink/reparse descendant: ' + str(p))
            try:
                target = p.resolve(strict=True)
            except (OSError, RuntimeError):
                reject('broken/cyclic symlink/reparse descendant: ' + str(p))
            if target == lab or not inside(target, lab):
                reject('symlink/reparse escapes lab: ' + str(p))
for home in homes:
    if str(home) not in ('', '.') and home.is_absolute() and inside(lab, normalized(home)):
        reject('lab must not be inside the live home')
for ancestor in (lab, *lab.parents):
    if (ancestor / '.git').exists(): reject('lab is inside a Git checkout')
if (profiles, prefix, cwd) != (lab / 'pi-root', lab / 'npm-prefix', lab / 'test-cwd'):
    reject('use the fixed pi-root, npm-prefix and test-cwd under lab')
for label, target in [('profiles', profiles), ('npm prefix', prefix), ('cwd', cwd)]:
    if not inside(target, lab) or target == lab: reject(label + ' must be inside the lab')
    if target.exists() and not target.is_dir(): reject(label + ' is not a directory')
for a, b in ((profiles, prefix), (profiles, cwd), (prefix, cwd)):
    if inside(a, b) or inside(b, a): reject('profiles, prefix and cwd must be disjoint')
if not cwd.is_dir(): reject('test-cwd must already exist')
if set(p.name for p in cwd.iterdir()) != {'.pi'}: reject('test-cwd must contain only .pi')
project = cwd / '.pi'
if not project.is_dir() or set(p.name for p in project.iterdir()) != {'settings.json'}:
    reject('project .pi must contain only settings.json')
try:
    settings = json.loads((project / 'settings.json').read_text(encoding='utf-8'))
except (OSError, ValueError) as exc: reject('project settings unavailable: ' + str(exc))
if settings != {'pi-memory': {'localPath': '../memory'}}:
    reject('project memory localPath must be exactly ../memory')
memory = normalized(lab / 'memory')
if memory.exists() and (not memory.is_dir() or any(memory.iterdir())):
    reject('memory must be empty before runtime gate')
# Apply is fresh-only. Even a previously marked prefix must be inspected
# separately, never overwritten by a second Apply in this slice.
marker = prefix / '.pi-agent-build-lab'
if mode == 'fresh' and prefix.exists() and any(prefix.iterdir()):
    reject('npm prefix not empty; repeat Apply is NOT idempotent and refused')
if mode == 'installed' and not marker.is_file():
    reject('installed private lab marker is missing')
if profiles.exists():
    if {p.name for p in profiles.iterdir()} - {'agent', 'task'}:
        reject('pi-root contains unexpected entries')
for name in ('agent', 'task'):
    root = normalized(profiles / name)
    if not root.is_dir(): reject(name + ' synthetic profile directory is missing')
    entries = {p.name for p in root.iterdir()}
    if entries - ({'mcp.json'} if mode == 'fresh' else
                  {'mcp.json', 'settings.json', 'models.json', 'ollama-cloud.json',
                   'skills', 'npm', 'git', '.pi-agent-build-backups'}):
        reject(name + ' contains non-synthetic content')
    if mode == 'installed':
        template = repo / 'profiles' / ('code' if name == 'agent' else 'task') / 'settings.template.json'
        for filename, expected in (
            ('models.json', repo / 'config/models.polza-memory.example.json'),
            ('ollama-cloud.json', repo / 'config/ollama-cloud.example.json')):
            target = root / filename
            if not target.is_file() or target.read_bytes() != expected.read_bytes():
                reject(name + ' existing ' + filename + ' differs from synthetic template')
        try:
            actual = json.loads((root / 'settings.json').read_text(encoding='utf-8'))
            desired = json.loads(template.read_text(encoding='utf-8'))
        except (OSError, ValueError) as exc: reject(name + ' existing settings invalid: ' + str(exc))
        if actual != desired:
            reject(name + ' existing settings differ from synthetic template')
    mcp = root / 'mcp.json'
    if not mcp.is_file(): reject(name + ' empty synthetic MCP config is missing')
    if mcp.exists():
        try: config = json.loads(mcp.read_text(encoding='utf-8'))
        except (OSError, ValueError) as exc: reject(name + ' MCP invalid: ' + str(exc))
        if config != {'mcpServers': {}, 'settings': {'scriptMode': False}}:
            reject(name + ' MCP is not empty synthetic config')
for name in ('user.npmrc', 'global.npmrc'):
    config = lab / 'npm-config' / name
    if config.exists() and any(line.strip() and not line.lstrip().startswith(('#', ';'))
                               for line in config.read_text(encoding='utf-8').splitlines()):
        reject(name + ' contains npm directives')
print('LAB PREFLIGHT: PASS (static paths only; runtime isolation NOT TESTED)')
PY
}

lab_run() (
  cd "$LAB_CWD" || exit 2
  env -i PATH="$LAB_PATH" HOME="$LAB_ROOT/home" USERPROFILE="$LAB_ROOT/home" \
    APPDATA="$LAB_ROOT/appdata" LOCALAPPDATA="$LAB_ROOT/localappdata" \
    TEMP="$LAB_ROOT/temp" TMP="$LAB_ROOT/temp" TMPDIR="$LAB_ROOT/temp" \
    XDG_CONFIG_HOME="$LAB_ROOT/xdg-config" XDG_CACHE_HOME="$LAB_ROOT/xdg-cache" \
    XDG_DATA_HOME="$LAB_ROOT/xdg-data" XDG_STATE_HOME="$LAB_ROOT/xdg-state" \
    npm_config_prefix="$LAB_PREFIX" PI_AGENT_BUILD_NPM_PREFIX="$LAB_PREFIX" \
    npm_config_cache="$LAB_ROOT/npm-cache" \
    npm_config_userconfig="$LAB_ROOT/npm-config/user.npmrc" \
    npm_config_globalconfig="$LAB_ROOT/npm-config/global.npmrc" \
    UV_CACHE_DIR="$LAB_ROOT/uv-cache" UV_TOOL_DIR="$LAB_ROOT/uv-tools" \
    UV_TOOL_BIN_DIR="$LAB_ROOT/uv-bin" PI_CODING_AGENT_DIR="$LAB_PROFILE" \
    PI_CODING_AGENT_SESSION_DIR="$LAB_ROOT/sessions/$LAB_NAME" \
    PI_SESSION_DIR="$LAB_ROOT/sessions/$LAB_NAME" \
    PI_SESSION_ARCHIVE_DIR="$LAB_ROOT/sessions-archive/$LAB_NAME" \
    PI_CBM_CACHE_DIR="$LAB_ROOT/cbm-cache" CBM_CACHE_DIR="$LAB_ROOT/cbm-cache" \
    PI_MCP_CONFIG_MODE=exclusive PI_INTERCOM_SCOPE_ID="lab-$LAB_NAME" \
    PYTHONDONTWRITEBYTECODE=1 PI_BUILD_PYTHON="${LAB_PATCH_PYTHON:-$LAB_PYTHON}" \
    PI_LAB_LIVE_HOME="${HOME:-}" PI_LAB_LIVE_USERPROFILE="${USERPROFILE:-}" \
    SystemRoot="${SYSTEMROOT:-${SystemRoot:-}}" COMSPEC="${COMSPEC:-}" "$@"
)

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
if "extensions" in desired:
    current["extensions"] = list(dict.fromkeys(current.get("extensions", []) + desired["extensions"]))

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
