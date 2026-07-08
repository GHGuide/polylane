#!/usr/bin/env bash
# test-dashboard.sh — bin/polylane-dashboard.sh as a CLI: help, arg errors, and
# one rendered frame in --demo and manifest modes.
#
# The dashboard renders forever (`while :; sleep`), so the render tests launch
# it in the background, wait for its first flushed frame, then kill it. bash
# flushes stdout before running its external `sleep`, so once the capture file
# is non-empty it already holds a complete frame (a frame is well under one
# buffer, so it flushes all-at-once — never a partial row). This never hangs
# tests/run.sh. bash-3.2 safe; the manifest render is guarded on jq.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
DASH="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-dashboard.sh"

# run_frame OUTFILE CMD... : run a looping CLI in the background, capture its
# first frame into OUTFILE, then kill it (bounded wait, never hangs).
run_frame() {
  local out="$1"; shift
  : > "$out"
  "$@" >"$out" 2>&1 &
  local pid=$! n=0
  while [ ! -s "$out" ] && [ "$n" -lt 50 ]; do sleep 0.1; n=$((n + 1)); done
  kill "$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
}

# --- help / usage : exits 0 and prints usage ------------------------------
assert_rc       "help-exit-0"      0        "$DASH" --help
assert_contains "help-shows-usage" "USAGE:" "$("$DASH" --help 2>&1)"

# --- arg errors : each exits 2, all before the render loop ----------------
assert_rc "no-args-exit-2"          2 "$DASH"
assert_rc "missing-manifest-exit-2" 2 "$DASH" /no/such/manifest.json
assert_rc "bad-interval-exit-2"     2 "$DASH" --demo --interval abc

# --- --demo renders a frame (no manifest, no jq needed) -------------------
make_tmpdir
run_frame "$TEST_TMPDIR/demo.out" "$DASH" --demo --interval 1
demo=$(cat "$TEST_TMPDIR/demo.out")
assert_contains "demo-renders-header" "POLYLANE DASHBOARD" "$demo"
assert_contains "demo-renders-lane"   "integrate"          "$demo"

# --- manifest mode renders a table; DONE comes from the fake status file --
if command -v jq >/dev/null 2>&1; then
  export POLYLANE_SESSION="polylane-test-$$"   # no such tmux session -> no panes
  ROOT="$TEST_TMPDIR/proj"
  WT="$ROOT/.polylane/wt/api"
  mkdir -p "$WT/docs"
  printf 'STATUS: api DONE\n' > "$WT/docs/status-api.md"
  MAN="$ROOT/.polylane/run.json"
  cat > "$MAN" <<'JSON'
{
  "lanes": [
    { "name": "api", "model": "claude-sonnet-5", "worktree": ".polylane/wt/api" }
  ],
  "integrator": { "name": "integrate", "model": "claude-opus-4-8", "worktree": ".polylane/wt/integrate" }
}
JSON
  run_frame "$TEST_TMPDIR/live.out" "$DASH" "$MAN" --interval 1
  live=$(cat "$TEST_TMPDIR/live.out")
  assert_contains "manifest-renders-lane"          "api"             "$live"
  assert_contains "manifest-renders-model"         "claude-sonnet-5" "$live"
  assert_contains "manifest-done-from-status-file" "DONE"            "$live"
else
  pass "manifest-render-skipped-no-jq"
fi

finish
