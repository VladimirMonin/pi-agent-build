#!/usr/bin/env bash
# verify.sh — POSIX verifier for the portable Pi Agent build.
#
# Mirrors scripts/verify.ps1. Checks repository structure and JSON schemas,
# profile templates against manifests, installed runtime/profile composition,
# patch states and external tool resolution.
#
# Runtime note: manifests pin Windows x64 versions (Node 25.8.1, npm 11.11.0,
# Git 2.54.0.windows.1). On macOS/Linux those exact versions are reported as
# WARN, not FAIL; Pi package version, profile composition and patch states
# remain hard failures. Use --strict-runtime to fail on runtime drift too.
#
# Usage:
#   scripts/verify.sh [--profile Code|Task|Both] [--pi-root <dir>]
#                     [--repo-root <dir>] [--repository-only] [--external-only]
#                     [--skip-patch-checks] [--skip-external-checks]
#                     [--strict-runtime]
#
# Exit codes: 0 no failures; 1 failures; 2 fatal.
#
# shellcheck shell=bash

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
. "$SCRIPT_DIR/common.sh"

PROFILE="Both"
PI_ROOT="${HOME}/.pi"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPOSITORY_ONLY=0
EXTERNAL_ONLY=0
SKIP_PATCH_CHECKS=0
SKIP_EXTERNAL_CHECKS=0
STRICT_RUNTIME=0

while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --pi-root) PI_ROOT="$2"; shift 2 ;;
    --repo-root) REPO_ROOT="$2"; shift 2 ;;
    --repository-only) REPOSITORY_ONLY=1; shift ;;
    --external-only) EXTERNAL_ONLY=1; shift ;;
    --skip-patch-checks) SKIP_PATCH_CHECKS=1; shift ;;
    --skip-external-checks) SKIP_EXTERNAL_CHECKS=1; shift ;;
    --strict-runtime) STRICT_RUNTIME=1; shift ;;
    -h|--help) sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) err "unknown argument: $1"; exit 2 ;;
  esac
done

case "$PROFILE" in Code|Task|Both) ;; *) err "invalid --profile: $PROFILE"; exit 2 ;; esac

REPO_ROOT="$(resolve_full_path "$REPO_ROOT")"
PI_ROOT="$(resolve_full_path "$PI_ROOT")"

FAILURES=0
WARNINGS=0
pass() { log "PASS $*"; }
warn() { WARNINGS=$((WARNINGS + 1)); log "WARN $*"; }
fail() { FAILURES=$((FAILURES + 1)); log "FAIL $*"; }

require_python || exit 2
PYTHON="$(resolve_python)"

test_required_path() {
  local path="$1" label="$2"
  if [ -e "$path" ]; then pass "$label"; else fail "$label missing: $path"; fi
}

# --------------------------------------------------------------------------- #
# repository gates
# --------------------------------------------------------------------------- #
required_paths=(
  "manifests/runtime.lock.json" "manifests/pi-packages.lock.json" "manifests/external-tools.lock.json"
  "manifests/schemas/runtime-lock.schema.json" "manifests/schemas/pi-packages-lock.schema.json"
  "manifests/schemas/external-tools-lock.schema.json" "profiles/code/settings.template.json"
  "profiles/task/settings.template.json" "scripts/install.sh" "scripts/apply-patches.sh"
  "scripts/verify.sh" "scripts/safety-check.sh" "scripts/install-launchers.sh"
  "launchers/pi-code.cmd" "launchers/pi-task.cmd" "launchers/pi-code" "launchers/pi-task"
)
for rel in "${required_paths[@]}"; do
  test_required_path "$REPO_ROOT/$rel" "$rel"
done

RUNTIME_MANIFEST="$REPO_ROOT/manifests/runtime.lock.json"
PACKAGES_MANIFEST="$REPO_ROOT/manifests/pi-packages.lock.json"
EXTERNAL_MANIFEST="$REPO_ROOT/manifests/external-tools.lock.json"

# JSON schema validation (requires python jsonschema)
validate_schema() {
  local manifest="$1" label
  label="$(basename "$manifest")"
  local schema_rel schema_path
  schema_rel="$(json_get "$manifest" 'd["$schema"]')"
  schema_path="$REPO_ROOT/manifests/${schema_rel#./}"
  if [ ! -f "$schema_path" ]; then fail "schema target for $label"; return; fi
  local out code
  set +e
  out="$("$PYTHON" - "$manifest" "$schema_path" <<'PY' 2>&1
import json, sys
try:
    from jsonschema import Draft202012Validator as V
except Exception as exc:
    print(f"jsonschema unavailable: {exc}")
    raise SystemExit(2)
with open(sys.argv[1], encoding="utf-8") as fh:
    instance = json.load(fh)
with open(sys.argv[2], encoding="utf-8") as fh:
    schema = json.load(fh)
V.check_schema(schema)
errors = list(V(schema).iter_errors(instance))
for e in errors:
    print(e.message)
raise SystemExit(1 if errors else 0)
PY
)"
  code=$?
  set -e
  if [ "$code" = "0" ]; then pass "schema $label"
  elif printf '%s' "$out" | grep -q "jsonschema unavailable"; then
    fail "jsonschema validator unavailable for $label (pip install jsonschema)"
  else fail "schema validation $label: $out"; fi
}

for name in runtime pi-packages external-tools; do
  validate_schema "$REPO_ROOT/manifests/$name.lock.json"
done

# profile template vs manifest
compare_template() {
  local profile="$1" template="$2" pi_version="$3" out code
  set +e
  out="$("$PYTHON" - "$template" "$PACKAGES_MANIFEST" "$profile" "$pi_version" <<'PY' 2>&1
import json, sys
template, manifest, profile, pi_version = sys.argv[1:5]
def load(p):
    with open(p, encoding="utf-8") as fh:
        return json.load(fh)
settings = load(template)
m = load(manifest)
problems = []
if str(settings.get("lastChangelogVersion")) != pi_version:
    problems.append(f"{profile} template Pi version is {settings.get('lastChangelogVersion')}, expected {pi_version}")
entries = list(m["profiles"]["common"])
if profile == "Code":
    entries += list(m["profiles"].get("codeOnly", []))
expected = [e["source"] for e in entries]
def src(item):
    return item if isinstance(item, str) else item.get("source", "")
actual = [src(i) for i in settings.get("packages", [])]
if expected != actual:
    problems.append(f"{profile} template package list differs from pi-packages.lock.json")
for p in problems:
    print(p)
raise SystemExit(1 if problems else 0)
PY
)"
  code=$?
  set -e
  if [ "$code" = "0" ]; then
    pass "$profile template Pi version $pi_version"
    pass "$profile template package list and exact versions"
  else fail "$out"; fi
}

PI_VERSION="$(json_get "$RUNTIME_MANIFEST" 'd["runtime"]["pi"]["version"]')"
compare_template Code "$REPO_ROOT/profiles/code/settings.template.json" "$PI_VERSION"
compare_template Task "$REPO_ROOT/profiles/task/settings.template.json" "$PI_VERSION"

# patch files present
while IFS= read -r patch_name; do
  [ -n "$patch_name" ] || continue
  test_required_path "$REPO_ROOT/patches/$patch_name/apply.py" "patch $patch_name"
done < <("$PYTHON" - "$PACKAGES_MANIFEST" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as fh:
    m = json.load(fh)
names = []
for e in list(m["profiles"]["common"]) + list(m["profiles"].get("codeOnly", [])):
    if e.get("patch"):
        names.append(e["patch"])
    if e.get("taskProfilePatch"):
        names.append(e["taskProfilePatch"])
for n in dict.fromkeys(names):
    print(n)
PY
)

# --------------------------------------------------------------------------- #
# external tools
# --------------------------------------------------------------------------- #
# strip_exe <name> — Windows manifests name binaries with a .exe suffix;
# on macOS/Linux the same tool is installed without it.
strip_exe() { printf '%s' "${1%.exe}"; }

test_exact_tool_version() {
  local cmd="$1" expected="$2" label="$3" required="${4:-1}" out actual
  if ! command_exists "$cmd"; then
    [ "$required" = "1" ] && fail "$label command not found: $cmd" || warn "$label not installed (optional)"
    return
  fi
  out="$(command_output "$cmd" --version || true)"
  actual="$(get_version_from_text "$out")"
  if [ "$actual" = "$expected" ]; then pass "$label $actual"
  elif [ -z "$actual" ] && [ "$required" != "1" ]; then warn "$label present but version probe is unparseable (optional)"
  else fail "$label expected $expected, found $actual"; fi
}

test_direct_spawn() {
  local cmd="$1" expected="$2" label="$3" required="${4:-1}" path out actual
  if ! command_exists "$cmd"; then
    [ "$required" = "1" ] && fail "$label command not found: $cmd" || warn "$label not installed (optional)"
    return
  fi
  path="$(command -v "$cmd")"
  case "$(basename "$path")" in *.cmd|*.bat|*.ps1) fail "$label resolves to a shell shim: $path"; return ;; esac
  out="$(command_output "$path" --version || true)"
  actual="$(get_version_from_text "$out")"
  if [ -n "$expected" ] && [ "$actual" != "$expected" ]; then fail "$label expected $expected, found $actual"
  else pass "$label direct spawn $actual"; fi
}

test_external_tools() {
  if [ "$PROFILE" = "Code" ] || [ "$PROFILE" = "Both" ]; then
    while IFS="$IFS_US" read -r pkg ver probe command relpath; do
      [ -n "$pkg" ] || continue
      case "$probe" in
        npm-root-executable-version)
          local root; root="$(npm root --global 2>/dev/null || true)"
          local path="$root/$(strip_exe "$relpath")"
          if [ -f "$path" ]; then
            local actual; actual="$(get_version_from_text "$(command_output "$path" --version || true)")"
            [ "$actual" = "$ver" ] && pass "$pkg $actual" || fail "$pkg expected $ver, found $actual"
          else warn "$pkg executable not found at $path"; fi
          ;;
        direct-version) test_direct_spawn "$(strip_exe "$command")" "$ver" "$pkg" 1 ;;
        *) fail "unsupported external probe '$probe' for $pkg" ;;
      esac
    done < <("$PYTHON" - "$EXTERNAL_MANIFEST" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as fh:
    m = json.load(fh)
for t in m.get("codeProfile", []):
    print("\x1f".join([t.get("package",""), t.get("version",""), t.get("probe",""),
                     t.get("command",""), t.get("npmExecutableRelativePath","")]))
PY
)
  fi
  while IFS="$IFS_US" read -r pkg ver probe command optional; do
    [ -n "$pkg" ] || continue
    local req=1; [ "$optional" = "True" ] && req=0
    case "$probe" in
      command-present)
        if command_exists "$command"; then pass "$pkg command present"
        else [ "$req" = "1" ] && fail "$pkg command not found: $command" || warn "$pkg not installed (optional)"; fi
        ;;
      command-version) test_exact_tool_version "$command" "$ver" "$pkg" "$req" ;;
      *) fail "unsupported MCP probe '$probe' for $pkg" ;;
    esac
  done < <("$PYTHON" - "$EXTERNAL_MANIFEST" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as fh:
    m = json.load(fh)
for t in m.get("mcp", []):
    print("\x1f".join([t.get("package",""), t.get("version",""), t.get("probe",""),
                     t.get("command",""), str(bool(t.get("optional")))]))
PY
)
}

# --------------------------------------------------------------------------- #
# installed profile
# --------------------------------------------------------------------------- #
test_installed_profile() {
  local name="$1" dir="$2" profile_root settings
  profile_root="$PI_ROOT/$dir"
  settings="$profile_root/settings.json"
  test_required_path "$settings" "$name settings"
  if [ -f "$settings" ]; then
    if json_get "$settings" 'd' >/dev/null 2>&1; then pass "$name settings JSON"; else fail "$name settings JSON invalid"; fi
  fi
  while IFS="$IFS_US" read -r source pkg ver _patch _taskpatch kind commit _tag releaseTag; do
    [ -n "$source" ] || continue
    case "$source" in
      npm:*)
        local meta="$profile_root/npm/node_modules/$pkg/package.json"
        if [ ! -f "$meta" ]; then fail "$name package missing: $pkg"; continue; fi
        local actual; actual="$(json_get "$meta" 'd.get("version")')"
        [ "$actual" = "$ver" ] && pass "$name $pkg@$ver" || fail "$name $pkg expected $ver, found $actual"
        ;;
      https://github.com/*)
        local rest owner repo git_root head tagobj peeled
        rest="${source#https://github.com/}"; owner="${rest%%/*}"; rest="${rest#*/}"
        repo="${rest%@*}"; repo="${repo%.git}"
        git_root="$profile_root/git/github.com/$owner/$repo"
        if [ ! -d "$git_root/.git" ]; then fail "$name Git package missing: $git_root"; continue; fi
        local meta="$git_root/package.json"
        if [ -f "$meta" ]; then
          local actual; actual="$(json_get "$meta" 'd.get("version")')"
          [ "$actual" = "$ver" ] || { fail "$name $pkg expected $ver, found $actual"; continue; }
        fi
        head="$(git -C "$git_root" rev-parse HEAD 2>/dev/null || true)"
        tagobj="$(git -C "$git_root" rev-parse "refs/tags/$releaseTag" 2>/dev/null || true)"
        peeled="$(git -C "$git_root" rev-parse "$tagobj^{commit}" 2>/dev/null || true)"
        if [ "$tagobj" != "$_tag" ]; then fail "$name $pkg release tag object differs from metadata"
        elif [ "$peeled" != "$commit" ] || [ "$head" != "$commit" ]; then fail "$name $pkg checkout/tag does not resolve to pinned commit"
        else pass "$name $pkg@$ver git $commit"; fi
        ;;
      *) fail "$name unsupported package source: $source" ;;
    esac
  done < <(manifest_packages "$PACKAGES_MANIFEST" "$name")
}

# --------------------------------------------------------------------------- #
# run
# --------------------------------------------------------------------------- #
if [ "$EXTERNAL_ONLY" = "1" ]; then
  [ "$REPOSITORY_ONLY" = "1" ] && { err "--external-only cannot be combined with --repository-only"; exit 2; }
  [ "$SKIP_EXTERNAL_CHECKS" != "1" ] && test_external_tools
elif [ "$REPOSITORY_ONLY" != "1" ]; then
  # runtime versions
  actual_node="$(get_version_from_text "$(command_output node --version || true)")"
  expected_node="$(json_get "$RUNTIME_MANIFEST" 'd["runtime"]["node"]')"
  if [ "$actual_node" = "$expected_node" ]; then pass "Node.js $actual_node"
  elif [ "$STRICT_RUNTIME" = "1" ]; then fail "Node.js expected $expected_node, found $actual_node"
  else warn "Node.js is $actual_node; manifest pins Windows $expected_node (>=24 required)"; fi

  actual_npm="$(get_version_from_text "$(command_output npm --version || true)")"
  expected_npm="$(json_get "$RUNTIME_MANIFEST" 'd["runtime"]["npm"]')"
  if [ "$actual_npm" = "$expected_npm" ]; then pass "npm $actual_npm"
  elif [ "$STRICT_RUNTIME" = "1" ]; then fail "npm expected $expected_npm, found $actual_npm"
  else warn "npm is $actual_npm; manifest pins Windows $expected_npm"; fi

  actual_git="$(get_version_from_text "$(command_output git --version || true)")"
  expected_git="$(json_get "$EXTERNAL_MANIFEST" 'd["common"][0]["version"]')"
  if [ "$actual_git" = "$expected_git" ]; then pass "Git $actual_git"
  elif [ "$STRICT_RUNTIME" = "1" ]; then fail "Git expected $expected_git, found $actual_git"
  else warn "Git is $actual_git; manifest pins Windows $expected_git"; fi

  py_min="$(json_get "$EXTERNAL_MANIFEST" 'd["common"][1]["minimumVersion"]')"
  actual_py="$(get_version_from_text "$(command_output "$PYTHON" --version || true)")"
  if version_ge "$actual_py" "$py_min"; then pass "Python $actual_py"; else fail "Python expected >= $py_min, found $actual_py"; fi

  # global Pi package
  global_root="$(npm root --global 2>/dev/null || true)"
  pi_meta="$global_root/@earendil-works/pi-coding-agent/package.json"
  if [ -f "$pi_meta" ] && [ "$(json_get "$pi_meta" 'd.get("version")')" = "$PI_VERSION" ]; then
    pass "Pi package $PI_VERSION"
  else fail "global Pi package missing or wrong version: $pi_meta"; fi

  while IFS=$'\t' read -r name dir; do
    test_installed_profile "$name" "$dir"
  done < <(selected_profiles "$PROFILE")

  # memory embedder cache: the pi-memory patch selects a local multilingual
  # model. If it is not cached, the plugin still works but the first semantic
  # search falls back to FTS-only until the model downloads. Network speed
  # varies, so a missing cache is a WARN (run the warm-up helper), not a FAIL.
  if [ "$SKIP_PATCH_CHECKS" != "1" ]; then
    while IFS=$'\t' read -r name dir; do
      profile_root="$PI_ROOT/$dir"
      dist="$profile_root/npm/node_modules/@samfp/pi-memory/dist/index.js"
      [ -f "$dist" ] || continue
      model="$(sed -n 's/^var MODEL = "\(.*\)";$/\1/p' "$dist" | head -n1)" || true
      [ -n "$model" ] || continue
      cache="$profile_root/npm/node_modules/@xenova/transformers/.cache/$model"
      if [ -d "$cache" ]; then
        pass "$name memory embedder cached ($model)"
      else
        warn "$name memory embedder not cached ($model); run scripts/warm-memory-embedder.mjs $profile_root"
      fi
    done < <(selected_profiles "$PROFILE")
  fi

  if [ "$SKIP_PATCH_CHECKS" != "1" ]; then
    set +e
    "$SCRIPT_DIR/apply-patches.sh" --profile "$PROFILE" --mode Check --pi-root "$PI_ROOT" --repo-root "$REPO_ROOT" >/dev/null 2>&1
    patch_exit=$?
    set -e
    case "$patch_exit" in
      0) pass "installed patch checks" ;;
      1) fail "one or more installed patches require application" ;;
      *) fail "patch checks failed with exit code $patch_exit" ;;
    esac
  fi

  [ "$SKIP_EXTERNAL_CHECKS" != "1" ] && test_external_tools
fi

log "VERIFY result: failures=$FAILURES warnings=$WARNINGS"
[ "$FAILURES" -gt 0 ] && exit 1
exit 0
