#!/usr/bin/env bash
# apply-patches.sh — POSIX orchestrator for local Pi package patches.
#
# Mirrors scripts/apply-patches.ps1. Reads the patch list from
# manifests/pi-packages.lock.json and runs each patcher against the selected
# profile(s). The memory-windows-runtime patcher has no --apply flag: its
# absence of --check/--restore means apply.
#
# Usage:
#   scripts/apply-patches.sh [--profile Code|Task|Both] [--mode Check|Apply|Restore]
#                            [--pi-root <dir>] [--repo-root <dir>]
#
# Exit codes: 0 ok / already applied; 1 (Check) one or more patches need apply;
#             2 fatal (missing patcher, unknown state).
#
# shellcheck shell=bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
. "$SCRIPT_DIR/common.sh"

PROFILE="Both"
MODE="Check"
PI_ROOT="${HOME}/.pi"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --pi-root) PI_ROOT="$2"; shift 2 ;;
    --repo-root) REPO_ROOT="$2"; shift 2 ;;
    -h|--help) sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) err "unknown argument: $1"; exit 2 ;;
  esac
done

case "$PROFILE" in Code|Task|Both) ;; *) err "invalid --profile: $PROFILE"; exit 2 ;; esac
case "$MODE" in Check|Apply|Restore) ;; *) err "invalid --mode: $MODE"; exit 2 ;; esac

REPO_ROOT="$(resolve_full_path "$REPO_ROOT")"
PI_ROOT="$(resolve_full_path "$PI_ROOT")"
MANIFEST="$REPO_ROOT/manifests/pi-packages.lock.json"
[ -f "$MANIFEST" ] || { err "manifest missing: $MANIFEST"; exit 2; }

PYTHON="$(resolve_python)" || { err "python3 is required to check or apply local patches"; exit 2; }

# patches_for_profile <Code|Task> -> unique patch names, one per line
patches_for_profile() {
  "$PYTHON" - "$MANIFEST" "$1" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as fh:
    m = json.load(fh)
profile = sys.argv[2]
names = []
for e in m["profiles"]["common"]:
    if e.get("patch"):
        names.append(e["patch"])
    if profile == "Task" and e.get("taskProfilePatch"):
        names.append(e["taskProfilePatch"])
if profile == "Code":
    for e in m["profiles"].get("codeOnly", []):
        if e.get("patch"):
            names.append(e["patch"])
seen = []
for n in names:
    if n not in seen:
        seen.append(n)
for n in seen:
    print(n)
PY
}

log "PATCH $MODE"
fatal=0
needs_apply=0

while IFS=$'\t' read -r name dir; do
  agent_dir="$PI_ROOT/$dir"
  log "profile $name: $agent_dir"
  while IFS= read -r patch_name; do
    [ -n "$patch_name" ] || continue
    patcher="$REPO_ROOT/patches/$patch_name/apply.py"
    if [ ! -f "$patcher" ]; then
      log "FAIL $patch_name patcher missing: $patcher"
      fatal=1
      continue
    fi
    args=("$patcher" --agent-dir "$agent_dir")
    case "$MODE" in
      Check) args+=(--check) ;;
      Restore) args+=(--restore) ;;
      Apply) [ "$patch_name" = "memory-windows-runtime" ] || args+=(--apply) ;;
    esac
    log "  $patch_name"
    set +e
    output="$("$PYTHON" "${args[@]}" 2>&1)"
    code=$?
    set -e
    [ -n "$output" ] && printf '%s\n' "$output"
    if [ "$MODE" = "Check" ]; then
      case "$code" in
        0) log "PASS $patch_name" ;;
        1) log "NEEDS-APPLY $patch_name"; needs_apply=1 ;;
        *) log "FAIL $patch_name check exited $code"; fatal=1 ;;
      esac
    elif [ "$code" -ne 0 ]; then
      log "FAIL $patch_name $MODE exited $code"; fatal=1
    else
      log "PASS $patch_name $MODE"
    fi
  done < <(patches_for_profile "$name")
done < <(selected_profiles "$PROFILE")

[ "$fatal" = "1" ] && exit 2
[ "$MODE" = "Check" ] && [ "$needs_apply" = "1" ] && exit 1
exit 0
