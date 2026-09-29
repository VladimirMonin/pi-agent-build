#!/usr/bin/env bash
# Synthetic POSIX probe test: Brave version comes from npm metadata, not a server launch.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/npm/node_modules/@brave/brave-search-mcp-server"
cat >"$tmp/bin/npm" <<'SH'
#!/usr/bin/env bash
[ "$1" = root ] && [ "$2" = --global ] || exit 9
printf '%s\n' "$PROBE_NPM_ROOT"
SH
cat >"$tmp/bin/brave-search-mcp-server" <<'SH'
#!/usr/bin/env bash
printf 'started\n' >"$PROBE_BRAVE_MARKER"
exit 9
SH
cat >"$tmp/bin/context7-mcp" <<'SH'
#!/usr/bin/env bash
echo 3.2.2
SH
cat >"$tmp/bin/mcp-server-fetch" <<'SH'
#!/usr/bin/env bash
printf 'started\n' >"$PROBE_FETCH_MARKER"
exit 9
SH
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH" PROBE_NPM_ROOT="$tmp/npm/node_modules"
export PROBE_BRAVE_MARKER="$tmp/brave-started" PROBE_FETCH_MARKER="$tmp/fetch-started"
meta="$tmp/npm/node_modules/@brave/brave-search-mcp-server/package.json"
printf '%s\n' '{"version":"2.0.85"}' >"$meta"
"$repo/scripts/verify.sh" --profile Task --external-only >"$tmp/good.log" 2>&1
grep -q 'brave-search-mcp-server 2.0.85 (npm metadata; server not started)' "$tmp/good.log"
[ ! -e "$PROBE_BRAVE_MARKER" ] && [ ! -e "$PROBE_FETCH_MARKER" ]
printf '%s\n' '{"version":"0.0.0"}' >"$meta"
if "$repo/scripts/verify.sh" --profile Task --external-only >"$tmp/bad.log" 2>&1; then
  echo 'FAIL wrong Brave package version was accepted' >&2; exit 1
fi
grep -q 'brave-search-mcp-server expected 2.0.85' "$tmp/bad.log"
[ ! -e "$PROBE_BRAVE_MARKER" ] && [ ! -e "$PROBE_FETCH_MARKER" ]
echo 'PASS POSIX Brave npm-metadata probe'
