#!/usr/bin/env bash
# test-control-room.sh — control snapshots inherit runner/state nonce semantics.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

DASH="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-dashboard.sh"

if ! command -v jq >/dev/null 2>&1; then
  pass "control-room-skipped-no-jq"
  finish
fi

make_tmpdir
ROOT="$TEST_TMPDIR/project"
WT="$ROOT/.polylane/wt/api"
mkdir -p "$WT/docs" "$ROOT/docs/polylane"
MAN="$ROOT/.polylane/run.json"
cat > "$MAN" <<'JSON'
{
  "orchestration_contract": 2,
  "run_id": "fresh-nonce",
  "cycle": 9,
  "lanes": [{"name":"api","branch":"pl/api","worktree":"__WT__"}],
  "integrator": {"name":"integrate","branch":"pl/int","worktree":"__INT_WT__"}
}
JSON
sed -i.bak "s|__WT__|$WT|; s|__INT_WT__|$ROOT/.polylane/wt/integrate|" "$MAN"
rm -f "$MAN.bak"

assert_not_done() {
  local name="$1" marker="$2" snapshot
  printf '%b' "$marker" > "$WT/docs/status-api.md"
  snapshot=$("$DASH" "$MAN" --once --json)
  assert_ok "$name-json" jq -e . >/dev/null <<<"$snapshot"
  assert_eq "$name-not-done" "no-pane" "$(jq -r '.lanes[0].status' <<<"$snapshot")"
}

assert_not_done "bare-marker" 'STATUS: api DONE\n'
assert_not_done "mismatched-nonce" 'STATUS: api DONE run=old-nonce\n'
assert_not_done "stale-run-marker" 'STATUS: api DONE run=old-nonce\nSTATUS: api DONE run=fresh-nonce\n'
assert_not_done "extra-first-line-marker" 'STATUS: api DONE run=fresh-nonce extra\n'

printf 'STATUS: api DONE run=fresh-nonce\n' > "$WT/docs/status-api.md"
( cd "$WT" && git init -q -b main && git config user.email t@t && git config user.name t && git add docs/status-api.md && git commit -qm done-newline )
snapshot=$("$DASH" "$MAN" --once --json)
assert_eq "current-nonce-done" "done" "$(jq -r '.lanes[0].status' <<<"$snapshot")"

# polylane-markers.sh intentionally emits an exact current-nonce marker without
# a final newline. The shared state helper must accept that valid wire format.
printf 'STATUS: api DONE run=fresh-nonce' > "$WT/docs/status-api.md"
( cd "$WT" && git add docs/status-api.md && git commit -qm done-no-newline )
snapshot=$("$DASH" "$MAN" --once --json)
assert_eq "current-nonce-no-final-newline-done" "done" "$(jq -r '.lanes[0].status' <<<"$snapshot")"

finish
