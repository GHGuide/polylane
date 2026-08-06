#!/usr/bin/env bash
# test-dashboard.sh — bin/polylane-dashboard.sh as a CLI: help, arg errors, and
# one rendered frame in --demo and manifest modes.
#
# The dashboard renders forever (`while :; sleep`), so the render tests launch
# it in the background, wait for a COMPLETE first frame, then kill it. A
# non-empty capture can be observed between rows under load, so the sentinel
# must include both the header and final hint line. This never hangs
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
  # Wait up to ~30s. The frame appears in milliseconds when the box is idle,
  # but under full-suite load the old 5s ceiling could expire with the file still
  # empty — every assertion then failed for a reason the test does not test. This
  # loop still exits the INSTANT the frame lands, so the common case stays fast;
  # only a genuinely stuck render pays the longer bound.
  while [ "$n" -lt 300 ]; do
    if grep -q 'POLYLANE DASHBOARD' "$out" 2>/dev/null && grep -q 'hint: tmux attach -t' "$out" 2>/dev/null; then break; fi
    sleep 0.1; n=$((n + 1))
  done
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

# --- canonical one-shot snapshot: JSON is produced before any render loop ---
if command -v jq >/dev/null 2>&1; then
  make_tmpdir
  SNAP_ROOT="$TEST_TMPDIR/snapshot"
  SNAP_WT="$SNAP_ROOT/.polylane/wt/api"
  mkdir -p "$SNAP_WT/docs" "$SNAP_ROOT/docs/polylane"
  SNAP_MAN="$SNAP_ROOT/.polylane/run.json"
  cat > "$SNAP_MAN" <<'JSON'
{
  "orchestration_contract": 2,
  "run_id": "current-nonce",
  "cycle": 9,
  "goal": "ship canonical control room",
  "state_file": "docs/polylane/max-state.json",
  "target_subgoals": ["m8.8"],
  "lanes": [{"name":"api","model":"gpt-5.6-terra","effort":"high","branch":"pl/api","worktree":"__WT__","own_globs":["src/**"],"target_subgoals":["m8.8"]}],
  "integrator": {"name":"integrate","model":"gpt-5.6-sol","effort":"xhigh","branch":"pl/int","worktree":"__INT_WT__"}
}
JSON
  sed -i.bak "s|__WT__|$SNAP_WT|; s|__INT_WT__|$SNAP_ROOT/.polylane/wt/integrate|" "$SNAP_MAN"
  rm -f "$SNAP_MAN.bak"
  printf '%s\n' '{"version":1,"goal":"durable goal","milestones":[]}' > "$SNAP_ROOT/docs/polylane/max-state.json"
  printf '%s\n' '{"run_id":"current-nonce","cost":12}' > "$SNAP_ROOT/docs/polylane/spend-ledger.jsonl"
  printf '%s\n' 'STATUS: api DONE run=current-nonce' > "$SNAP_WT/docs/status-api.md"
  "$(dirname "$DASH")/polylane-graph.sh" compile "$SNAP_MAN" "$SNAP_ROOT/.polylane/graph.json"
  snapshot=$("$DASH" "$SNAP_MAN" --once --json)
  assert_ok "once-json-is-valid" jq -e . >/dev/null <<<"$snapshot"
  for key in schema goal cycle run_id route graph lanes spend verdict heartbeat cleanup next_action; do
    assert_ok "once-json-schema:$key" jq -e --arg key "$key" 'has($key)' >/dev/null <<<"$snapshot"
  done
  assert_eq "once-json-current-run" "current-nonce" "$(jq -r '.run_id' <<<"$snapshot")"
  assert_eq "once-json-lane-from-state" "done" "$(jq -r '.lanes[0].status' <<<"$snapshot")"
  assert_eq "once-json-canonical-spend" "12" "$(jq -r '.spend.total' <<<"$snapshot")"
  assert_eq "once-json-graph-ready" "start" "$(jq -r '.graph.ready[0]' <<<"$snapshot")"
  graph_id=$(jq -r '.graph_id' "$SNAP_ROOT/.polylane/graph.json")
  events="$(dirname "$DASH")/polylane-events.sh"
  "$events" append "$SNAP_ROOT/.polylane/events.jsonl" current-nonce "$graph_id" start pending ready 0 dashboard-start-ready
  "$events" append "$SNAP_ROOT/.polylane/events.jsonl" current-nonce "$graph_id" start ready running 0 dashboard-start-running
  "$events" append "$SNAP_ROOT/.polylane/events.jsonl" current-nonce "$graph_id" start running succeeded 0 dashboard-start-succeeded
  replayed_snapshot=$("$DASH" "$SNAP_MAN" --once --json)
  assert_eq "once-json-replayed-event-count" "3" "$(jq -r '.graph.events' <<<"$replayed_snapshot")"
  assert_eq "once-json-replayed-graph-ready" "lane:api" "$(jq -r '.graph.ready[0]' <<<"$replayed_snapshot")"
  text_snapshot=$("$DASH" "$SNAP_MAN" --once)
  assert_contains "once-text-goal" "goal: ship canonical control room" "$text_snapshot"
  assert_contains "once-text-graph" "graph:" "$text_snapshot"
  assert_contains "once-text-spend" "spend:" "$text_snapshot"
  assert_contains "once-text-next-action" "next:" "$text_snapshot"
  snapshot_text=$("$DASH" "$SNAP_MAN" --once)
  assert_contains "once-text-renders-header" "POLYLANE DASHBOARD" "$snapshot_text"
  assert_contains "once-text-renders-current-run" "current-nonce" "$snapshot_text"
else
  pass "once-json-skipped-no-jq"
fi

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
  printf 'STATUS: api DONE run=live-nonce\n' > "$WT/docs/status-api.md"
  MAN="$ROOT/.polylane/run.json"
  cat > "$MAN" <<'JSON'
{
  "run_id": "live-nonce",
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
  assert_contains "manifest-done-from-status-file" "done"            "$live"
else
  pass "manifest-render-skipped-no-jq"
fi

finish
