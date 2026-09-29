#!/usr/bin/env bash
# Synthetic regression for the POSIX verifier's goal-x/intercom order gates.
# Bash 3.2+; PI_BUILD_PYTHON may override python3 (e.g. Windows Git Bash test).
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
py="${PI_BUILD_PYTHON:-python3}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

"$repo/scripts/verify.sh" --repository-only --profile Both >/dev/null
mkdir -p "$tmp/repo"
for dir in scripts manifests profiles patches launchers; do cp -R "$repo/$dir" "$tmp/repo/$dir"; done
"$py" - "$tmp/repo/manifests/pi-packages.lock.json" <<'PY'
import json, sys
p = sys.argv[1]
with open(p, encoding="utf-8") as fh:
    doc = json.load(fh)
entries = doc["profiles"]["common"]
a = next(i for i, e in enumerate(entries) if e["package"] == "pi-goal-x")
b = next(i for i, e in enumerate(entries) if e["package"] == "pi-intercom")
entries[a], entries[b] = entries[b], entries[a]
with open(p, "w", encoding="utf-8") as fh:
    json.dump(doc, fh, indent=2)
PY
if "$tmp/repo/scripts/verify.sh" --repository-only --repo-root "$tmp/repo" >"$tmp/reversed.log" 2>&1; then
  echo 'FAIL reversed manifest was accepted' >&2; exit 1
fi
grep -q 'manifest must load pi-goal-x before pi-intercom' "$tmp/reversed.log"

mkdir -p "$tmp/pi/agent"
printf '%s\n' '{"packages":["npm:pi-intercom@0.13.0","npm:pi-goal-x@0.31.9"]}' >"$tmp/pi/agent/settings.json"
"$repo/scripts/verify.sh" --profile Code --pi-root "$tmp/pi" --skip-patch-checks --skip-external-checks >"$tmp/bad.log" 2>&1 || true
grep -q 'installed settings must load pinned pi-goal-x before pi-intercom' "$tmp/bad.log"
printf '%s\n' '{"packages":["npm:pi-goal-x@0.31.9","npm:pi-intercom@0.13.0"]}' >"$tmp/pi/agent/settings.json"
"$repo/scripts/verify.sh" --profile Code --pi-root "$tmp/pi" --skip-patch-checks --skip-external-checks >"$tmp/good.log" 2>&1 || true
grep -q 'PASS Code installed goal-x/intercom order' "$tmp/good.log"
echo 'PASS POSIX goal-x/intercom order regression'
