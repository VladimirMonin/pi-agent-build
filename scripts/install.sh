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
#   --lab-root <dir>             opt in to private two-profile install (static gate only)
#   --repo-root <dir>            default: repository root (parent of scripts/)
#   --skip-package-install       do not install Pi/packages/external tools
#   --skip-patches               do not run the patch orchestrator
#   --sync-settings-only         pin existing settings without package/patch installs
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
SYNC_SETTINGS_ONLY=0
REPLACE_PROFILE_CONFIGS=0
LAB_ROOT=""
PI_ROOT_EXPLICIT=0

usage() { sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --apply) APPLY=1; shift ;;
    --pi-root) PI_ROOT="$2"; PI_ROOT_EXPLICIT=1; shift 2 ;;
    --lab-root) LAB_ROOT="$2"; shift 2 ;;
    --repo-root) REPO_ROOT="$2"; shift 2 ;;
    --skip-package-install) SKIP_PACKAGE_INSTALL=1; shift ;;
    --skip-patches) SKIP_PATCHES=1; shift ;;
    --sync-settings-only) SYNC_SETTINGS_ONLY=1; shift ;;
    --replace-profile-configs) REPLACE_PROFILE_CONFIGS=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) err "unknown argument: $1"; usage; exit 2 ;;
  esac
done

case "$PROFILE" in Code|Task|Both) ;; *) err "invalid --profile: $PROFILE"; exit 2 ;; esac

REPO_ROOT="$(resolve_full_path "$REPO_ROOT")"
PI_ROOT="$(resolve_full_path "$PI_ROOT")"
if [ -n "$LAB_ROOT" ]; then
  LAB_PREFIX="$LAB_ROOT/npm-prefix"
  LAB_CWD="$LAB_ROOT/test-cwd"
  [ "$PI_ROOT_EXPLICIT" = 0 ] || { err '--lab-root cannot be combined with --pi-root'; exit 2; }
  PI_ROOT="$LAB_ROOT/pi-root"
  [ "$PROFILE" = Both ] && [ "$SKIP_PACKAGE_INSTALL" = 0 ] && [ "$SKIP_PATCHES" = 0 ] && \
    [ "$SYNC_SETTINGS_ONLY" = 0 ] && [ "$REPLACE_PROFILE_CONFIGS" = 0 ] || {
      err 'lab install requires Both profiles and all package/patch gates; no skip or replace flags'; exit 2;
    }
fi

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
if [ -n "$LAB_ROOT" ]; then
  log "private lab root: $LAB_ROOT"
  log 'existing install requires full private installed-state validation; no repair/reinstall'
fi
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
if [ "$SYNC_SETTINGS_ONLY" = "1" ]; then
  log 'settings-only: verify installed payloads, back up and merge settings; no package/patch/credential writes'
else
  log 'Pi interactive/model execution: disabled; Apply uses only the pi install package lifecycle'
fi

if [ -n "$LAB_ROOT" ]; then
  if lab_fresh_result="$(lab_preflight fresh 2>&1)"; then
    log "$lab_fresh_result"
  else
    lab_installed_state --mcp || exit 2
    if [ "$APPLY" = "1" ]; then
      for dir in agent task; do
        profile_root="$PI_ROOT/$dir"
        backup_root="$profile_root/.pi-agent-build-backups/install/$(backup_stamp)"
        install_profile_file "$REPO_ROOT/config/pi-goal-x-settings.json" "$profile_root/pi-goal-x-settings.json" "$backup_root" 'pi-goal-x-settings.json' 0 >/dev/null
        install_profile_file "$REPO_ROOT/config/goal-autonomy.AGENTS.md" "$profile_root/AGENTS.md" "$backup_root" 'AGENTS.md' 0 >/dev/null
      done
    fi
    log "LAB $MODE: VERIFIED INSTALLED-STATE NO-OP; no npm/package/launcher writes"
    exit 0
  fi
fi

if [ "$APPLY" != "1" ]; then
  log "PLAN complete; no files or packages were changed. Re-run with --apply."
  exit 0
fi

if [ -n "$LAB_ROOT" ]; then
  # Read-only preflight on both roots before the first mkdir, npm or patch write.
  lab_preflight fresh || exit 2
  for tool in node npm git; do
    command_exists "$tool" || { err "lab prerequisite missing: $tool"; exit 2; }
  done
  LAB_NPM_PATH="$(command -v npm)"
  LAB_PATH="$LAB_PREFIX/bin:$(dirname "$LAB_NPM_PATH")"
  for tool in node npm git; do
    tool_path="$(command -v "$tool")"
    LAB_PATH="$LAB_PATH:$(dirname "$tool_path")"
  done
  LAB_PATH="$LAB_PATH:/usr/bin:/bin"
  py_path="$(command -v "$(resolve_python)")"
  [ -f "$py_path" ] || { err 'lab Python must resolve to a real executable'; exit 2; }
  LAB_PATH="$LAB_PATH:$(dirname "$py_path")"
  LAB_PYTHON="$py_path"
  # No inherited auth/redirect variables, npmrc, global Pi or uv tool writes.
  # Private directories are created only after all static checks passed.
  for dir in home appdata localappdata temp xdg-config xdg-cache xdg-data xdg-state \
    npm-cache npm-config uv-cache uv-tools uv-bin sessions/agent sessions/task \
    sessions-archive/agent sessions-archive/task cbm-cache pi-root/agent pi-root/task memory; do
    mkdir -p "$LAB_ROOT/$dir"
  done
  LAB_NAME=agent LAB_PROFILE="$PI_ROOT/agent"
  run_checked "private Pi npm install" lab_run "$LAB_NPM_PATH" install --global --prefix "$LAB_PREFIX" \
    --no-audit --no-fund "$PI_PACKAGE@$PI_VERSION"
  pi_meta="$LAB_PREFIX/lib/node_modules/$PI_PACKAGE/package.json"
  [ -f "$pi_meta" ] && [ "$(json_get "$pi_meta" 'd.get("version")')" = "$PI_VERSION" ] || {
    err "candidate Pi metadata missing/wrong version: $pi_meta"; exit 1;
  }
  lab_pi="$LAB_PREFIX/bin/pi"
  [ -f "$lab_pi" ] || { err "private Pi binary missing: $lab_pi"; exit 1; }
  for name in agent task; do
    LAB_NAME="$name" LAB_PROFILE="$PI_ROOT/$name"
    template="$([ "$name" = agent ] && echo code || echo task)"
    # Only synthetic profiles; no copying/merging live configs or credentials.
    cp "$REPO_ROOT/profiles/$template/settings.template.json" "$LAB_PROFILE/settings.json"
    cp "$REPO_ROOT/config/pi-goal-x-settings.json" "$LAB_PROFILE/pi-goal-x-settings.json"
    cp "$REPO_ROOT/config/goal-autonomy.AGENTS.md" "$LAB_PROFILE/AGENTS.md"
    cp "$REPO_ROOT/config/models.polza-memory.example.json" "$LAB_PROFILE/models.json"
    cp "$REPO_ROOT/config/ollama-cloud.example.json" "$LAB_PROFILE/ollama-cloud.json"
    mkdir -p "$LAB_PROFILE/skills"
    cp -R "$REPO_ROOT/skills/memory-ops" "$LAB_PROFILE/skills/memory-ops"
    selected="$([ "$name" = agent ] && echo Code || echo Task)"
    while IFS="$IFS_US" read -r source pkg ver _patch _taskpatch _kind _commit _tag _rel; do
      [ -n "$source" ] || continue
      run_checked "[$name] private pi install $source" lab_run "$lab_pi" install "$source"
      assert_installed_package "$LAB_PROFILE" "$source" "$pkg" "$ver"
    done < <(manifest_packages "$PACKAGES_MANIFEST" "$selected")
  done
  # Windows python.exe writes CRLF to pipes; the existing patch orchestrator
  # reads patch names linewise. Keep its interpreter output LF without changing
  # the shared non-lab orchestrator.
  mkdir -p "$LAB_ROOT/bin"
  printf '#!/usr/bin/env bash\nset -o pipefail\n%s "$@" | tr -d "\\r"\n' \
    "$(printf '%q' "$LAB_PYTHON")" > "$LAB_ROOT/bin/python-lf"
  chmod +x "$LAB_ROOT/bin/python-lf"
  LAB_PATCH_PYTHON="$LAB_ROOT/bin/python-lf"
  LAB_NAME=agent LAB_PROFILE="$PI_ROOT/agent"
  run_checked 'private profile patches' lab_run "$SCRIPT_DIR/apply-patches.sh" \
    --profile Both --mode Apply --pi-root "$PI_ROOT" --repo-root "$REPO_ROOT"
  printf '%s\n' "$PI_PACKAGE@$PI_VERSION" > "$LAB_PREFIX/.pi-agent-build-lab"
  log 'NOT TESTED: external Code tools are not installed; no global fallback or portability claim.'
  log 'Runtime isolation gate NOT TESTED: do not load credentials, models, MCP or real Pi sessions.'
  exit 0
fi

if [ "$SYNC_SETTINGS_ONLY" = "1" ]; then
  [ "$REPLACE_PROFILE_CONFIGS" != "1" ] || { err 'settings-only mode preserves configs'; exit 2; }
  while IFS=$'\t' read -r name dir; do
    profile_root="$PI_ROOT/$dir"
    [ -f "$profile_root/settings.json" ] || { err "settings missing: $profile_root/settings.json"; exit 2; }
    while IFS="$IFS_US" read -r source pkg ver _patch _taskpatch _kind _commit _tag _release; do
      [ -n "$source" ] && assert_installed_package "$profile_root" "$source" "$pkg" "$ver"
    done < <(manifest_packages "$PACKAGES_MANIFEST" "$name")
    template_dir="$([ "$name" = Code ] && echo code || echo task)"
    if ! node "$REPO_ROOT/scripts/check-memory-model.mjs" "$profile_root" \
      "$REPO_ROOT/profiles/$template_dir/settings.template.json"; then
      err "$name settings sync refused unavailable memory model"
      exit 2
    fi
  done < <(selected_profiles "$PROFILE")
  # Validate BOTH profiles before writing either settings file.
  while IFS=$'\t' read -r name dir; do
    profile_root="$PI_ROOT/$dir"
    template_dir="$([ "$name" = Code ] && echo code || echo task)"
    backup_root="$profile_root/.pi-agent-build-backups/install/$(backup_stamp)"
    merge_preserved_settings "$profile_root/settings.json" \
      "$REPO_ROOT/profiles/$template_dir/settings.template.json" "$PACKAGES_MANIFEST" "$name" "$backup_root"
    log "merged $profile_root/settings.json (settings only; packages and patches untouched)"
  done < <(selected_profiles "$PROFILE")
  exit 0
fi

# Static polza conflicts with dynamic pi-polza; never add polza-memory beside it.
if [ "$REPLACE_PROFILE_CONFIGS" != "1" ]; then
  while IFS=$'\t' read -r name dir; do
    models="$PI_ROOT/$dir/models.json"
    if [ -f "$models" ] && [ "$(json_get "$models" 'd.get("providers", {}).get("polza") is not None')" = True ]; then
      err "$name static polza conflicts with pi-polza; back up models.json and migrate its provider to polza-memory before install"
      exit 2
    fi
  done < <(selected_profiles "$PROFILE")
fi

# Refuse unknown installed memory bundles before pi install could overwrite them.
if [ "$SKIP_PACKAGE_INSTALL" != "1" ]; then
  while IFS=$'\t' read -r name dir; do
    profile_root="$PI_ROOT/$dir"
    dist="$profile_root/npm/node_modules/@samfp/pi-memory/dist/index.js"
    [ -f "$dist" ] || continue
    set +e
    "$(resolve_python)" "$REPO_ROOT/patches/memory-windows-runtime/apply.py" --check --agent-dir "$profile_root" >/dev/null
    probe_code=$?
    set -e
    [ "$probe_code" -le 1 ] || { err "$name memory preflight refused unknown state before reinstall"; exit 2; }
    log "PASS $name memory preflight (known state; exit $probe_code)"
  done < <(selected_profiles "$PROFILE")
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

  if [[ "$(npm --version 2>/dev/null)" != "$NPM_VERSION" ]]; then
    run_checked "install npm@$NPM_VERSION" npm install --global --no-audit --no-fund "npm@$NPM_VERSION"
  fi
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
  for config_pair in 'pi-goal-x-settings.json:pi-goal-x-settings.json' 'goal-autonomy.AGENTS.md:AGENTS.md'; do
    config_status="$(install_profile_file "$REPO_ROOT/config/${config_pair%%:*}" \
      "$profile_root/${config_pair#*:}" "$backup_root" "${config_pair#*:}" "$REPLACE_PROFILE_CONFIGS")"
    log "$config_status $profile_root/${config_pair#*:}"
  done

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
  while IFS="$IFS_US" read -r pkg ver installer python_version; do
    [ -n "$pkg" ] || continue
    if [ "$installer" = "uv tool" ]; then
      run_checked "uv tool install $pkg==$ver" uv tool install --python "$python_version" --force --prerelease=allow "$pkg==$ver"
    else
      run_checked "npm install -g $pkg@$ver" npm install --global --no-audit --no-fund "$pkg@$ver"
    fi
  done < <("$(resolve_python)" - "$EXTERNAL_MANIFEST" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as fh:
    m = json.load(fh)
for t in m.get("codeProfile", []):
    print(f'{t.get("package","")}\x1f{t.get("version","")}\x1f{t.get("installer","")}\x1f{t.get("pythonVersion","")}')
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

# --------------------------------------------------------------------------- #
# apply: memory embedder warm-up
# --------------------------------------------------------------------------- #

log "Installation complete. Pi was not started. No credentials were written."
