#!/usr/bin/env bash
# Fake private lifecycle only: never invokes real npm/Pi, patchers or credentials.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
py="${PI_BUILD_PYTHON:-python3}"
tmp="$(mktemp -d "$(dirname "$repo")/lab-posix-test.XXXXXX")"
trap 'if [ "${KEEP_TMP:-0}" = 1 ]; then echo "FAKE LAB: $tmp"; else rm -rf "$tmp"; fi' EXIT
lab="$tmp/lab"
fake="$tmp/fake-repo"
mkdir -p "$lab/test-cwd/.pi" "$lab/pi-root/agent" "$lab/pi-root/task" \
  "$tmp/bin" "$fake/manifests" "$fake/profiles" "$fake/config" "$fake/skills"
for profile in agent task; do
  printf '%s\n' '{"mcpServers":{},"settings":{"scriptMode":false}}' > "$lab/pi-root/$profile/mcp.json"
done
cp "$repo"/manifests/*.json "$fake/manifests/"
cp -R "$repo/manifests/schemas" "$fake/manifests/"
cp -R "$repo/profiles/code" "$repo/profiles/task" "$fake/profiles/"
cp "$repo/config/models.polza-memory.example.json" "$repo/config/ollama-cloud.example.json" "$fake/config/"
cp -R "$repo/skills/memory-ops" "$fake/skills/"
printf '%s\n' '{"pi-memory":{"localPath":"../memory"}}' > "$lab/test-cwd/.pi/settings.json"
# Fake patch scripts exercise the orchestrator without installing or patching.
"$py" - "$fake" <<'PY'
import json, pathlib, sys
root=pathlib.Path(sys.argv[1]); m=json.loads((root/'manifests/pi-packages.lock.json').read_text())
for e in m['profiles']['common']+m['profiles']['codeOnly']:
    for name in (e.get('patch'),e.get('taskProfilePatch')):
        if name:
            p=root/'patches'/name/'apply.py';p.parent.mkdir(parents=True,exist_ok=True)
            p.write_text('import os,sys\nassert os.environ.get("PYTHONDONTWRITEBYTECODE") == "1"\nsys.exit(0)\n')
PY
cat > "$tmp/bin/npm" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$(dirname "$(dirname "${npm_config_prefix:?}")")/calls"
[[ "$*" == *'--global --prefix '* ]] || exit 91
prefix="${npm_config_prefix:?}"
lab="$(dirname "$prefix")"
[ "$HOME" = "$lab/home" ] && [ "$PI_CODING_AGENT_DIR" = "$lab/pi-root/agent" ] || exit 93
[ -z "${POLZA_API_KEY:-}" ] && [ -z "${NODE_OPTIONS:-}" ] || exit 94
[ "${PYTHONDONTWRITEBYTECODE:-}" = 1 ] || exit 99
mkdir -p "$prefix/lib/node_modules/@earendil-works/pi-coding-agent" "$prefix/bin"
printf '%s\n' '{"version":"0.99.1"}' > "$prefix/lib/node_modules/@earendil-works/pi-coding-agent/package.json"
cp "$(dirname "$lab")/fake-pi" "$prefix/bin/pi"
chmod +x "$prefix/bin/pi"
SH
cat > "$tmp/fake-pi" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
lab="$(dirname "${npm_config_prefix:?}")"
[ "$1" = install ] && [ "$PWD" = "$lab/test-cwd" ] || exit 95
[[ "$PI_CODING_AGENT_DIR" == "$lab/pi-root/agent" || "$PI_CODING_AGENT_DIR" == "$lab/pi-root/task" ]] || exit 96
[ -z "${POLZA_API_KEY:-}" ] && [ -z "${NODE_OPTIONS:-}" ] || exit 97
[ "${PYTHONDONTWRITEBYTECODE:-}" = 1 ] || exit 99
printf '%s %s\n' "$PI_CODING_AGENT_DIR" "$2" >> "$(dirname "$lab")/calls"
source="$2"
if [[ "$source" == npm:* ]]; then
  package="${source#npm:}"; package="${package%@*}"
  version="${source##*@}"
  mkdir -p "$PI_CODING_AGENT_DIR/npm/node_modules/$package"
  printf '{"version":"%s"}\n' "$version" > "$PI_CODING_AGENT_DIR/npm/node_modules/$package/package.json"
else
  name="${source#https://github.com/}"; name="${name%@*}"
  mkdir -p "$PI_CODING_AGENT_DIR/git/github.com/$name/.git"
  printf '%s\n' "${source##*@}" > "$PI_CODING_AGENT_DIR/git/github.com/$name/.git/HEAD"
  "$PI_BUILD_PYTHON" - "$(dirname "$lab")/fake-repo/manifests/pi-packages.lock.json" "$source" "$PI_CODING_AGENT_DIR/git/github.com/$name" <<'PY'
import json,sys,pathlib
m=json.load(open(sys.argv[1])); e=next(e for e in m['profiles']['common']+m['profiles']['codeOnly'] if e['source']==sys.argv[2])
p=pathlib.Path(sys.argv[3]); (p/'package.json').write_text(json.dumps({'version':e['version']}))
(p/'.git/TAG_OBJECT').write_bytes((e['tagObject']+'\n').encode())
PY
fi
SH
cat > "$tmp/bin/git" <<'SH'
#!/usr/bin/env bash
# Only the pinned synthetic checkout is queried by package assertions.
[ "$1" = -C ] && [ "$3" = rev-parse ] || exit 98
case "$4" in
  HEAD|*'^'{commit}) cat "$2/.git/HEAD" ;;
  refs/tags/*) cat "$2/.git/TAG_OBJECT" ;;
  *) exit 98 ;;
esac
SH
chmod +x "$tmp/bin/npm" "$tmp/bin/git" "$tmp/fake-pi"
FAKE_CALLS="$tmp/calls"
export PI_BUILD_PYTHON="$(command -v "$py")"
export PATH="$tmp/bin:$PATH" POLZA_API_KEY='synthetic-must-not-propagate' NODE_OPTIONS='--synthetic-must-not-propagate'
"$repo/scripts/install.sh" --lab-root "$lab" --repo-root "$fake" > "$tmp/plan" 2>&1
[ ! -e "$FAKE_CALLS" ] && [ ! -e "$lab/npm-prefix" ]
if "$repo/scripts/install.sh" --lab-root "$lab" --repo-root "$fake" --apply --skip-patches > "$tmp/skip" 2>&1; then exit 1; fi
[ ! -e "$FAKE_CALLS" ]
# Refuse an unsafe sibling profile even when package installation would target both.
mkdir -p "$lab/pi-root/task"
printf 'unsafe\n' > "$lab/pi-root/task/auth.json"
if "$repo/scripts/install.sh" --lab-root "$lab" --repo-root "$fake" --apply > "$tmp/refused" 2>&1; then exit 1; fi
[ ! -e "$FAKE_CALLS" ]
rm "$lab/pi-root/task/auth.json"
"$repo/scripts/install.sh" --lab-root "$lab" --repo-root "$fake" --apply > "$tmp/apply" 2>&1
[ -f "$lab/npm-prefix/bin/pi" ] && [ -f "$lab/pi-root/agent/settings.json" ] && [ -f "$lab/pi-root/task/settings.json" ]
[ "$(wc -l < "$FAKE_CALLS")" = 28 ] # one npm call + 15 Code + 12 Task installs
[ -z "$(find "$lab" "$fake/patches" -name __pycache__ -print -quit)" ]
if "$repo/scripts/install.sh" --lab-root "$lab" --repo-root "$fake" --apply > "$tmp/reapply" 2>&1; then
  echo 'FAIL repeat Apply accepted an installed prefix' >&2; exit 1
fi
grep -q 'repeat Apply is NOT idempotent and refused' "$tmp/reapply"
[ "$(wc -l < "$FAKE_CALLS")" = 28 ] # repeat did not call npm or Pi
if "$repo/scripts/verify.sh" --lab-root "$lab" --repo-root "$fake" > "$tmp/verify" 2>&1; then
  echo 'FAIL lab verifier reported complete despite untested Code tools' >&2; exit 1
fi
grep -q 'private candidate Pi 0.99.1' "$tmp/verify"
grep -q 'external Code tools NOT TESTED' "$tmp/verify"
grep -q 'VERIFY result: failures=1' "$tmp/verify"
if grep -q 'global Pi package' "$tmp/verify"; then exit 1; fi
# Native symlink privileges vary on Windows. Never replace the working fake
# launcher unless a disposable probe can create and resolve a real symlink.
if "$py" - "$tmp" <<'PY'
import pathlib, sys
base = pathlib.Path(sys.argv[1]); probe = base / 'symlink-probe'
try:
    probe.symlink_to(base / 'fake-pi')
    assert probe.resolve(strict=True) == (base / 'fake-pi').resolve()
except (OSError, AssertionError):
    probe.unlink(missing_ok=True)
    raise SystemExit(1)
probe.unlink()
PY
then
  "$py" - "$lab" <<'PY'
import os, pathlib, sys
lab = pathlib.Path(sys.argv[1]); prefix = lab / 'npm-prefix'
launcher = prefix / 'bin/pi'
target = prefix / 'lib/node_modules/@earendil-works/pi-coding-agent/pi.js'
launcher.rename(target)
launcher.symlink_to(os.path.relpath(target, launcher.parent))
bin_dir = lab / 'pi-root/agent/npm/node_modules/.bin'
bin_dir.mkdir(parents=True, exist_ok=True)
linked = bin_dir / 'memory-link'
target = lab / 'pi-root/agent/npm/node_modules/@samfp/pi-memory/package.json'
linked.symlink_to(os.path.relpath(target, bin_dir))
PY
  if "$repo/scripts/verify.sh" --lab-root "$lab" --repo-root "$fake" > "$tmp/linked" 2>&1; then
    echo 'FAIL linked fake lab verifier reported complete despite untested Code tools' >&2; exit 1
  fi
  grep -q 'private candidate Pi 0.99.1' "$tmp/linked"
  grep -q 'VERIFY result: failures=1' "$tmp/linked"
  "$py" - "$lab" "$tmp" <<'PY'
import pathlib, sys
lab, outside = map(pathlib.Path, sys.argv[1:])
(outside / 'escape-target').write_text('outside fixture')
(lab / 'npm-prefix/bin/escape').symlink_to(outside / 'escape-target')
PY
  if "$repo/scripts/verify.sh" --lab-root "$lab" --repo-root "$fake" > "$tmp/escape" 2>&1; then
    echo 'FAIL escaping installed symlink was accepted' >&2; exit 1
  fi
  grep -q 'symlink/reparse escapes lab' "$tmp/escape"
  "$py" - "$lab" <<'PY'
import pathlib, sys
prefix = pathlib.Path(sys.argv[1]) / 'npm-prefix/bin'
(prefix / 'escape').unlink()
(prefix / 'broken').symlink_to('missing-private-target')
PY
  if "$repo/scripts/verify.sh" --lab-root "$lab" --repo-root "$fake" > "$tmp/broken" 2>&1; then
    echo 'FAIL broken installed symlink was accepted' >&2; exit 1
  fi
  grep -q 'broken/cyclic symlink/reparse' "$tmp/broken"
  "$py" - "$lab" <<'PY'
import pathlib, sys
(pathlib.Path(sys.argv[1]) / 'npm-prefix/bin/broken').unlink()
PY
  echo 'PASS installed in-lab launcher/.bin symlinks; escaping and broken links refused'
else
  echo 'SKIP symlink fixture: Windows/POSIX host denied real symlink creation'
fi
# Unsafe project-local memory must be rejected before reinstall writes.
printf '%s\n' '{"pi-memory":{"localPath":"../../outside"}}' > "$lab/test-cwd/.pi/settings.json"
if "$repo/scripts/install.sh" --lab-root "$lab" --repo-root "$fake" --apply > "$tmp/memory" 2>&1; then exit 1; fi
[ "$(wc -l < "$FAKE_CALLS")" = 28 ]
echo 'PASS fake POSIX lab plan, fresh-only apply, repeat refusal and fail-closed verify'
