#!/usr/bin/env bash
# Synthetic POSIX settings-only reconciliation and unknown-bundle preflight.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
py="${PI_BUILD_PYTHON:-python3}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/pi/task/git/github.com/VladimirMonin/pi-polza/.git"
cat >"$tmp/bin/git" <<'SH'
#!/usr/bin/env bash
[ "$3" = rev-parse ] && [ "$4" = HEAD ] || exit 9
printf '%s\n' "$PROBE_PINNED_COMMIT"
SH
chmod +x "$tmp/bin/git"
export PROBE_PINNED_COMMIT="$($py - "$repo/manifests/pi-packages.lock.json" <<'PY'
import json,sys
with open(sys.argv[1],encoding='utf8') as fh: doc=json.load(fh)
print(next(e['commit'] for e in doc['profiles']['common'] if e['package']=='pi-polza'))
PY
)"
"$py" - "$repo/manifests/pi-packages.lock.json" "$tmp/pi/task" "$repo/config/models.polza-memory.example.json" <<'PY'
import json,sys,pathlib,shutil
with open(sys.argv[1],encoding='utf8') as fh:doc=json.load(fh)
root=pathlib.Path(sys.argv[2]);sources=[]
shutil.copy2(sys.argv[3],root/'models.json')
for entry in doc['profiles']['common']:
  sources.append(entry['source'])
  if entry['source'].startswith('npm:'):
    meta=root/'npm'/'node_modules'/entry['package']/'package.json'
    meta.parent.mkdir(parents=True,exist_ok=True)
    meta.write_text(json.dumps({'version':entry['version']}),encoding='utf8')
sources[0]='npm:pi-ollama-cloud'
sources.append('npm:private-extra')
(root/'settings.json').write_text(json.dumps({'packages':sources,
  'memory':{'consolidationModel':'personal/model','factProjectAliases':[{'path':'/private','scope':'example'}]},
  'owner':'keep'},indent=2),encoding='utf8')
dist=root/'npm'/'node_modules'/'@samfp'/'pi-memory'/'dist'/'index.js'
dist.parent.mkdir(parents=True,exist_ok=True)
dist.write_text('private-bundle-untouched',encoding='utf8')
PY
if env -u POLZA_API_KEY PATH="$tmp/bin:$PATH" "$repo/scripts/install.sh" --apply --sync-settings-only --profile Task \
    --pi-root "$tmp/pi" >"$tmp/unavailable.log" 2>&1; then
  echo 'FAIL settings sync accepted unavailable memory route' >&2; exit 1
fi
grep -q 'unresolved credential environment reference' "$tmp/unavailable.log"
grep -q 'npm:pi-ollama-cloud' "$tmp/pi/task/settings.json"
credential_name=POLZA_API_KEY
env "$credential_name=synthetic-test-only" PATH="$tmp/bin:$PATH" "$repo/scripts/install.sh" --apply --sync-settings-only --profile Task \
  --pi-root "$tmp/pi" >"$tmp/sync.log" 2>&1
"$py" - "$repo/manifests/pi-packages.lock.json" "$tmp/pi/task" <<'PY'
import json,sys,pathlib
with open(sys.argv[1],encoding='utf8') as fh:doc=json.load(fh)
root=pathlib.Path(sys.argv[2]);settings=json.loads((root/'settings.json').read_text(encoding='utf8'))
expected=[e['source'] for e in doc['profiles']['common']]
actual=[item if isinstance(item,str) else item['source'] for item in settings['packages']]
assert actual[:len(expected)]==expected, (actual[:len(expected)],expected)
assert actual[-1]=='npm:private-extra'
assert settings['memory']['factProjectAliases'][0]['scope']=='example'
assert settings['owner']=='keep'
assert (root/'npm/node_modules/@samfp/pi-memory/dist/index.js').read_text()=='private-bundle-untouched'
assert list((root/'.pi-agent-build-backups/install').rglob('settings.before-merge.json'))
PY
# A full install must refuse a modified bundle before launching npm/pi.
if PATH="$tmp/bin:$PATH" "$repo/scripts/install.sh" --apply --skip-patches --profile Task \
    --pi-root "$tmp/pi" >"$tmp/refused.log" 2>&1; then
  echo 'FAIL unknown memory bundle survived full-install preflight' >&2; exit 1
fi
grep -q 'memory preflight refused unknown state before reinstall' "$tmp/refused.log"
[ "$(<"$tmp/pi/task/npm/node_modules/@samfp/pi-memory/dist/index.js")" = 'private-bundle-untouched' ]
"$py" - "$tmp/pi/task/models.json" <<'PY'
import json,sys
from pathlib import Path
p=Path(sys.argv[1]);models=json.loads(p.read_text(encoding='utf8'))
models['providers']['polza']={'apiKey':'!private-command'}
p.write_text(json.dumps(models),encoding='utf8')
PY
if PATH="$tmp/bin:$PATH" "$repo/scripts/install.sh" --apply --skip-patches --profile Task \
    --pi-root "$tmp/pi" >"$tmp/conflict.log" 2>&1; then
  echo 'FAIL full install accepted conflicting static Polza' >&2; exit 1
fi
grep -q 'static polza conflicts with pi-polza' "$tmp/conflict.log"
echo 'PASS POSIX settings sync, memory preflight, and Polza collision guard'
