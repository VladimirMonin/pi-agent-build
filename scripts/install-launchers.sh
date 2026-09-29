#!/usr/bin/env bash
# install-launchers.sh — render and install pi-code / pi-task launchers (POSIX).
#
# Mirrors scripts/install-launchers.ps1. Launcher templates in launchers/ carry
# tokens and must not be copied directly; this script substitutes the exact
# profile root and npm prefix, backs up existing launchers and sets the
# executable bit. On POSIX it installs the shell launchers only.
#
# Usage:
#   scripts/install-launchers.sh [--profile Code|Task|Both] [--apply]
#                                [--target-dir <dir>] [--pi-root <dir>]
#                                [--npm-prefix <dir>] [--repo-root <dir>]
#
# Defaults: target-dir $HOME/.local/bin, pi-root $HOME/.pi,
#           npm-prefix $(npm prefix -g) or $HOME/.npm-global.
#
# shellcheck shell=bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
. "$SCRIPT_DIR/common.sh"

PROFILE="Both"
APPLY=0
TARGET_DIR="${HOME}/.local/bin"
PI_ROOT="${HOME}/.pi"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NPM_PREFIX=""

while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --apply) APPLY=1; shift ;;
    --target-dir) TARGET_DIR="$2"; shift 2 ;;
    --pi-root) PI_ROOT="$2"; shift 2 ;;
    --npm-prefix) NPM_PREFIX="$2"; shift 2 ;;
    --repo-root) REPO_ROOT="$2"; shift 2 ;;
    -h|--help) sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) err "unknown argument: $1"; exit 2 ;;
  esac
done

case "$PROFILE" in Code|Task|Both) ;; *) err "invalid --profile: $PROFILE"; exit 2 ;; esac

REPO_ROOT="$(resolve_full_path "$REPO_ROOT")"
TARGET_DIR="$(resolve_full_path "$TARGET_DIR")"
PI_ROOT="$(resolve_full_path "$PI_ROOT")"
if [ -z "$NPM_PREFIX" ]; then
  NPM_PREFIX="$(npm prefix -g 2>/dev/null || true)"
  [ -n "$NPM_PREFIX" ] || NPM_PREFIX="$HOME/.npm-global"
fi
NPM_PREFIX="$(resolve_full_path "$NPM_PREFIX")"

# render_launcher <template> <profile_dir>
render_launcher() {
  local src="$1" profile_dir="$2" text
  text="$(cat "$src")"
  text="${text//__PI_PROFILE_DIR_POSIX__/$PI_ROOT/$profile_dir}"
  text="${text//__NPM_PREFIX_POSIX__/$NPM_PREFIX}"
  if printf '%s' "$text" | grep -Eq '__[A-Z0-9_]+__'; then
    err "unresolved launcher token in $src"
    return 2
  fi
  printf '%s\n' "$text"
}

MODE="PLAN"; [ "$APPLY" = "1" ] && MODE="APPLY"
log "$MODE launcher installation"
log "target: $TARGET_DIR"
log "Pi root: $PI_ROOT"
log "npm prefix: $NPM_PREFIX"

# collect items: "baseName<TAB>profileDir"
items=""
while IFS=$'\t' read -r name dir; do
  base="pi-code"; [ "$name" = Task ] && base="pi-task"
  items="$items$base\t$dir\n"
done < <(selected_profiles "$PROFILE")

while IFS=$'\t' read -r base dir; do
  [ -n "$base" ] || continue
  src="$REPO_ROOT/launchers/$base"
  [ -f "$src" ] || { err "launcher source missing: $src"; exit 2; }
  render_launcher "$src" "$dir" >/dev/null
  log "  RENDER $base"
done < <(printf '%b' "$items")

if [ "$APPLY" != "1" ]; then
  log "PLAN complete; no files were written. Re-run with --apply."
  exit 0
fi

backup_dir="$TARGET_DIR/.pi-agent-build-backups/launchers/$(backup_stamp)"
mkdir -p "$TARGET_DIR"

while IFS=$'\t' read -r base dir; do
  [ -n "$base" ] || continue
  src="$REPO_ROOT/launchers/$base"
  dst="$TARGET_DIR/$base"
  content="$(render_launcher "$src" "$dir")"
  if [ -f "$dst" ] && [ "$(cat "$dst")" = "$content" ]; then
    log "  unchanged $dst"
    continue
  fi
  backup_file_if_present "$dst" "$backup_dir" "$base" >/dev/null
  printf '%s\n' "$content" > "$dst"
  chmod +x "$dst"
  log "  written $dst"
done < <(printf '%b' "$items")

log "Launcher installation complete. Pi was not started."
