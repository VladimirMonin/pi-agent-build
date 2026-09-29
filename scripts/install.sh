#!/usr/bin/env bash
# install.sh — POSIX (macOS/Linux) installer for the portable Pi Agent build.
#
# Mirrors scripts/install.ps1. Runs as a dry-run plan by default; pass --apply
# to change anything. It never starts an interactive/model Pi session and never
# reads, copies, requests or writes credentials.
#
# Usage:
#   scripts/install.sh [--profile Code|Task|Both] [--apply] [options]
#
# Options:
#   --profile <Code|Task|Both>   default: Both
#   --pi-root <dir>              default: $HOME/.pi
#   --repo-root <dir>            default: repository root (parent of scripts/)
#   --skip-package-install       do not install Pi/packages/external tools
#   --skip-patches               do not run the patch orchestrator
#   --replace-profile-configs    replace profile configs from templates (with backup)
#   -h | --help
#
# shellcheck shell=bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
. "$SCRIPT_DIR/common.sh"

PROFILE="Both"
APPLY=0
PI_ROOT="${HOME}/.pi"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKIP_PACKAGE_INSTALL=0
SKIP_PATCHES=0
REPLACE_PROFILE_CONFIGS=0

usage() { sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --apply) APPLY=1; shift ;;
    --pi-root) PI_ROOT="$2"; shift 2 ;;
    --repo-root) REPO_ROOT="$2"; shift 2 ;;
    --skip-package-install) SKIP_PACKAGE_INSTALL=1; shift ;;
    --skip-patches) SKIP_PATCHES=1; shift ;;
    --replace-profile-configs) REPLACE_PROFILE_CONFIGS=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) err "unknown argument: $1"; usage; exit 2 ;;
  esac
done

case "$PROFILE" in Code|Task|Both) ;; *) err "invalid --profile: $PROFILE"; exit 2 ;; esac

REPO_ROOT="$(resolve_full_path "$REPO_ROOT")"
PI_ROOT="$(resolve_full_path "$PI_ROOT")"

RUNTIME_MANIFEST="$REPO_ROOT/manifests/runtime.lock.json"
PACKAGES_MANIFEST="$REPO_ROOT/manifests/pi-packages.lock.json"
EXTERNAL_MANIFEST="$REPO_ROOT/manifests/external-tools.lock.json"

for f in "$RUNTIME_MANIFEST" "$PACKAGES_MANIFEST" "$EXTERNAL_MANIFEST"; do
  [ -f "$f" ] || { err "required manifest missing: $f"; exit 2; }
done

require_python || exit 2

PI_VERSION="$(json_get "$RUNTIME_MANIFEST" 'd["runtime"]["pi"]["version"]')"
PI_PACKAGE="$(json_get "$RUNTIME_MANIFEST" 'd["runtime"]["pi"]["package"]')"
NODE_VERSION="$(json_get "$RUNTIME_MANIFEST" 'd["runtime"]["node"]')"
NPM_VERSION="$(json_get "$RUNTIME_MANIFEST" 'd["runtime"]["npm"]')"

# --------------------------------------------------------------------------- #
# plan
# --------------------------------------------------------------------------- #
MODE="PLAN"; [ "$APPLY" = "1" ] && MODE="APPLY"
log "$MODE Pi Agent installation (POSIX)"
log "profiles: $PROFILE"
log "Pi root: $PI_ROOT"
log "runtime: node@$NODE_VERSION, npm@$NPM_VERSION, $PI_PACKAGE@$PI_VERSION"

while IFS=$'\t' read -r name dir; do
  log "profile $name -> $PI_ROOT/$dir"
  log "  settings <- profiles/$([ "$name" = Code ] && echo code || echo task)/settings.template.json"
  while IFS="$IFS_US" read -r source _pkg _ver _patch _taskpatch _kind _commit _tag _rel; do
    [ -n "$source" ] && log "  package $source"
  done < <(manifest_packages "$PACKAGES_MANIFEST" "$name")
done < <(selected_profiles "$PROFILE")

if [ "$PROFILE" = "Code" ] || [ "$PROFILE" = "Both" ]; then
  while IFS="$IFS_US" read -r pkg ver _rest; do
    [ -n "$pkg" ] && log "external $pkg@$ver"
  done < <("$(resolve_python)" - "$EXTERNAL_MANIFEST" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as fh:
    m = json.load(fh)
for t in m.get("codeProfile", []):
    print(f'{t.get("package","")}\x1f{t.get("version","")}')
PY
)
fi

log "credentials: not read, copied, requested, or written"
log "existing profile configs: $([ "$REPLACE_PROFILE_CONFIGS" = 1 ] && echo 'replace with backup' || echo preserve)"
log "Pi interactive/model execution: disabled; Apply uses only the pi install package lifecycle"

if [ "$APPLY" != "1" ]; then
  log "PLAN complete; no files or packages were changed. Re-run with --apply."
  exit 0
fi

# --------------------------------------------------------------------------- #
# apply: runtime prerequisites
# --------------------------------------------------------------------------- #
if [ "$SKIP_PACKAGE_INSTALL" != "1" ]; then
  actual_node="$(get_version_from_text "$(command_output node --version || true)")"
  if [ "$actual_node" != "$NODE_VERSION" ]; then
    warn "Node.js is $actual_node, manifest pins $NODE_VERSION (minimum is enforced by pi-session-search >=24)"
  else
    log "PASS Node.js $actual_node"
  fi
  actual_npm="$(get_version_from_text "$(command_output npm --version || true)")"
  if [ "$actual_npm" != "$NPM_VERSION" ]; then
    warn "npm is $actual_npm, manifest pins $NPM_VERSION"
  else
    log "PASS npm $actual_npm"
  fi

  run_checked "install npm@$NPM_VERSION" npm install --global --no-audit --no-fund "npm@$NPM_VERSION"
  run_checked "install $PI_PACKAGE@$PI_VERSION" npm install --global --no-audit --no-fund "$PI_PACKAGE@$PI_VERSION"

  global_root="$(npm root --global)"
  pi_meta="$global_root/${PI_PACKAGE}/package.json"
  if [ -f "$pi_meta" ] && [ "$(json_get "$pi_meta" 'd["version"]')" = "$PI_VERSION" ]; then
    log "PASS Pi package $PI_VERSION"
  else
    err "global Pi package missing or wrong version: $pi_meta"
    exit 1
  fi
fi

# --------------------------------------------------------------------------- #
# apply: profiles
# --------------------------------------------------------------------------- #
while IFS=$'\t' read -r name dir; do
  profile_root="$PI_ROOT/$dir"
  template_dir="$([ "$name" = Code ] && echo code || echo task)"
  backup_root="$profile_root/.pi-agent-build-backups/install/$(backup_stamp)"
  mkdir -p "$profile_root"

  copy_status="$(install_profile_file "$REPO_ROOT/profiles/$template_dir/settings.template.json" \
    "$profile_root/settings.json" "$backup_root" "settings.json" "$REPLACE_PROFILE_CONFIGS")"
  log "$copy_status $profile_root/settings.json"

  models_status="$(install_profile_file "$REPO_ROOT/config/models.polza-memory.example.json" \
    "$profile_root/models.json" "$backup_root" "models.json" "$REPLACE_PROFILE_CONFIGS")"
  if [ "$models_status" = "preserved" ]; then
    models_status="$(merge_polza_memory_provider "$profile_root/models.json" \
      "$REPO_ROOT/config/models.polza-memory.example.json" "$backup_root")"
  fi
  log "$models_status $profile_root/models.json"

  ollama_status="$(install_profile_file "$REPO_ROOT/config/ollama-cloud.example.json" \
    "$profile_root/ollama-cloud.json" "$backup_root" "ollama-cloud.json" "$REPLACE_PROFILE_CONFIGS")"
  log "$ollama_status $profile_root/ollama-cloud.json"

  skill_status="$(install_profile_directory "$REPO_ROOT/skills/memory-ops" \
    "$profile_root/skills/memory-ops" "$backup_root" "skills/memory-ops" "$REPLACE_PROFILE_CONFIGS")"
  log "$skill_status $profile_root/skills/memory-ops"

  if [ "$SKIP_PACKAGE_INSTALL" != "1" ]; then
    if [ "$copy_status" = "preserved" ]; then
      backup_file_if_present "$profile_root/settings.json" "$backup_root" "settings.pre-install.json" >/dev/null
    fi
    while IFS="$IFS_US" read -r source pkg ver _patch _taskpatch _kind _commit _tag _rel; do
      [ -n "$source" ] || continue
      run_checked "[$name] pi install $source" env "PI_CODING_AGENT_DIR=$profile_root" pi install "$source"
      assert_installed_package "$profile_root" "$source" "$pkg" "$ver"
    done < <(manifest_packages "$PACKAGES_MANIFEST" "$name")

    if [ "$copy_status" = "preserved" ]; then
      merge_preserved_settings "$profile_root/settings.json" \
        "$REPO_ROOT/profiles/$template_dir/settings.template.json" "$PACKAGES_MANIFEST" "$name" "$backup_root"
      log "merged $profile_root/settings.json"
    fi
  fi
done < <(selected_profiles "$PROFILE")

# --------------------------------------------------------------------------- #
# apply: external Code tools
# --------------------------------------------------------------------------- #
if [ "$SKIP_PACKAGE_INSTALL" != "1" ] && { [ "$PROFILE" = "Code" ] || [ "$PROFILE" = "Both" ]; }; then
  while IFS="$IFS_US" read -r pkg ver installer; do
    [ -n "$pkg" ] || continue
    if [ "$installer" = "uv tool" ]; then
      run_checked "uv tool install $pkg==$ver" uv tool install --force --prerelease=allow "$pkg==$ver"
    else
      run_checked "npm install -g $pkg@$ver" npm install --global --no-audit --no-fund "$pkg@$ver"
    fi
  done < <("$(resolve_python)" - "$EXTERNAL_MANIFEST" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as fh:
    m = json.load(fh)
for t in m.get("codeProfile", []):
    print(f'{t.get("package","")}\x1f{t.get("version","")}\x1f{t.get("installer","")}')
PY
)
  # NOTE: the Windows-only ast-grep.exe staging step is intentionally omitted:
  # on macOS/Linux the npm shim is a directly spawnable executable.
fi

# --------------------------------------------------------------------------- #
# apply: patches
# --------------------------------------------------------------------------- #
if [ "$SKIP_PATCHES" != "1" ]; then
  run_checked "apply patches" "$SCRIPT_DIR/apply-patches.sh" --profile "$PROFILE" --mode Apply \
    --pi-root "$PI_ROOT" --repo-root "$REPO_ROOT"
fi

log "Installation complete. Pi was not started. No credentials were written."
