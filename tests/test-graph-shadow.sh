#!/usr/bin/env bash
# Contract-v2 execution-graph/event shadowing observes the runner's existing
# decisions and fails closed before promotion when the observation disagrees.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

command -v jq >/dev/null 2>&1 || { pass "graph-shadow-skipped-no-jq"; finish; exit 0; }
make_tmpdir

BIN="$(cd "$(dirname "$RUNNER")" && pwd)"
EVENTS="$BIN/polylane-events.sh"

write_manifest() {
  local dir="$1"
  mkdir -p "$dir"
  cat > "$dir/run.json" <<'JSON'
{
  "orchestration_contract": 2,
  "run_id": "shadow-run",
  "cycle": 2,
  "target_subgoals": ["g1"],
  "integrator": {
    "name": "integrator",
    "model": "gpt-strong",
    "effort": "xhigh"
  },
  "lanes": [{
    "name": "builder",
    "model": "gpt-fast",
    "effort": "high",
    "own_globs": ["src/**"],
    "target_subgoals": ["g1"]
  }]
}
JSON
}

new_shadow_case() {
  local name="$1"
  SHADOW_DIR="$TEST_TMPDIR/$name/.polylane"
  write_manifest "$SHADOW_DIR"
  MANIFEST="$SHADOW_DIR/run.json"
  ORCHESTRATION_CONTRACT=2
  RUN_ID=shadow-run
  CYCLE=2
  RESUME=0
  DRY_RUN=0
  unset POLYLANE_GRAPH_SHADOW GRAPH_FILE EVENTS_FILE GRAPH_ID
}

assert_shadow_init() {
  local name="$1" rc=0
  graph_shadow_init >/dev/null 2>&1 || rc=$?
  if [ "$rc" = 0 ]; then pass "$name"; else fail "$name" "expected rc 0, got $rc"; fi
}

run_main_fixture() (
  local mode="$1" root="$TEST_TMPDIR/main-$1" order="$TEST_TMPDIR/main-$1.order"
  local manifest="$root/.polylane/run.json"
  mkdir -p "$root/.polylane"
  write_manifest "$root/.polylane"
  . "$RUNNER"

  parse_args() { DRY_RUN=0; YES=1; RESUME=0; PUSH=0; MANIFEST="$manifest"; }
  preflight_basic() { printf '%s\n' preflight-basic >> "$order"; }
  load_manifest() {
    ORCHESTRATION_CONTRACT=2; RUN_ID=shadow-run; CYCLE=2
    PROJECT_ROOT="$root"; REPO_ROOT="$root"; BASE=main
    INT_NAME=integrator; INT_WORKTREE="$root/int"; INT_BRANCH=lane/int
    LANE_NAMES=(builder); LANE_WORKTREES=("$root/builder")
    LANE_RESUMED=(0); LANE_ADOPTED=(0); LANE_PANE_IDX=(-1)
    LANE_POLLSPEC=("builder:$root/builder")
  }
  preflight_agent() { :; }
  apply_overrides() { :; }
  preflight_contract() { printf '%s\n' contract-v2 >> "$order"; }
  mark_resumed() { :; }
  split_worktrees() {
    if [ "$mode" = enabled ]; then
      [ -f "$root/.polylane/graph.json" ] && [ -f "$root/.polylane/events.jsonl" ] || {
        echo 'side effect reached before graph shadow initialization' >&2
        return 91
      }
    else
      [ ! -e "$root/.polylane/graph.json" ] && [ ! -e "$root/.polylane/events.jsonl" ] || return 92
    fi
    printf '%s\n' side-effect >> "$order"
  }
  adopt_existing_session() { :; }
  launch_panes() { LAUNCHED=1; }
  tmux_watch_command() { printf 'fixture'; }
  verify_seeds() { :; }
  poll_done() { return 0; }
  notify_event() { :; }
  run_integrator() { :; }
  adopt_integrator() { return 1; }
  capture_stats() { :; }
  gate_with_repairs() { VERDICT_RESULT=GO; return 0; }
  assert_no_conflict() { :; }
  promote_to_main() { printf '%s\n' promote >> "$order"; }
  finalize_cycle_state() { :; }
  cleanup() { :; }
  write_report() { :; }

  if [ "$mode" = disabled ]; then
    POLYLANE_GRAPH_SHADOW=0 main fixture
  else
    main fixture
  fi
)

# Break caught: main reaches its first worktree side effect before the immutable
# graph and empty run-scoped ledger exist beside the manifest.
main_out=$(run_main_fixture enabled 2>&1); main_rc=$?
assert_eq "shadow-main-preflight-before-side-effects" "0" "$main_rc"
assert_eq "shadow-main-order" $'preflight-basic\ncontract-v2\nside-effect\npromote' \
  "$(cat "$TEST_TMPDIR/main-enabled.order" 2>/dev/null)"
assert_eq "shadow-main-builder-recorded" "succeeded" \
  "$(jq -r '.nodes["lane:builder"].state' < <("$EVENTS" replay \
    "$TEST_TMPDIR/main-enabled/.polylane/events.jsonl" shadow-run \
    "$(jq -r .graph_id "$TEST_TMPDIR/main-enabled/.polylane/graph.json")" 2>/dev/null) 2>/dev/null)"
assert_eq "shadow-main-integrator-recorded" "succeeded" \
  "$(jq -r '.nodes.integrator.state' < <("$EVENTS" replay \
    "$TEST_TMPDIR/main-enabled/.polylane/events.jsonl" shadow-run \
    "$(jq -r .graph_id "$TEST_TMPDIR/main-enabled/.polylane/graph.json")" 2>/dev/null) 2>/dev/null)"

# Break caught: an invalid graph reaches a downstream side effect.
new_shadow_case invalid
assert_shadow_init "shadow-invalid-setup"
jq '(.nodes[] | select(.id=="promote")).kind="terminal"' "$GRAPH_FILE" > "$SHADOW_DIR/bad.json"
mv "$SHADOW_DIR/bad.json" "$GRAPH_FILE"
invalid_side="$SHADOW_DIR/side-effect"
invalid_out=$({ graph_shadow_validate && touch "$invalid_side"; } 2>&1); invalid_rc=$?
assert_fail "shadow-invalid-graph-aborts" test "$invalid_rc" -eq 0
assert_contains "shadow-invalid-graph-actionable" "GRAPH-SHADOW:" "$invalid_out"
assert_fail "shadow-invalid-before-side-effect" test -e "$invalid_side"

recorded_state() {
  "$EVENTS" replay "$EVENTS_FILE" "$RUN_ID" "$GRAPH_ID" | jq -r --arg node "$1" '.nodes[$node].state'
}

# Break caught: runner terminal decisions diverge from the graph route or omit
# their verifier/promotion/terminal event transitions.
new_shadow_case go
assert_shadow_init "shadow-go-init"
assert_ok "shadow-go-route" graph_shadow_record_decision GO
assert_eq "shadow-go-promote" "succeeded" "$(recorded_state promote)"
assert_eq "shadow-go-complete" "succeeded" "$(recorded_state complete)"

new_shadow_case external
assert_shadow_init "shadow-external-init"
assert_ok "shadow-external-route" graph_shadow_record_decision EXTERNAL-EVIDENCE-OPEN
assert_eq "shadow-external-promote" "succeeded" "$(recorded_state promote)"
assert_eq "shadow-external-complete" "succeeded" "$(recorded_state complete)"

new_shadow_case no-go
assert_shadow_init "shadow-no-go-init"
assert_ok "shadow-no-go-route" graph_shadow_record_decision NO-GO
assert_eq "shadow-no-go-halt" "succeeded" "$(recorded_state halt)"

new_shadow_case halted
assert_shadow_init "shadow-halted-init"
assert_ok "shadow-halted-route" graph_shadow_record_decision HALTED lane:builder
assert_eq "shadow-halted-builder-failed" "failed" "$(recorded_state lane:builder)"
assert_eq "shadow-halted-terminal" "succeeded" "$(recorded_state halt)"

# Break caught: supervisor resume appends the same logical transition twice.
new_shadow_case resume
RESUME=1
assert_shadow_init "shadow-resume-init"
assert_ok "shadow-resume-first" graph_shadow_record_resume lane:builder
resume_rows=$(wc -l < "$EVENTS_FILE" | tr -d ' ')
assert_ok "shadow-resume-duplicate" graph_shadow_record_resume lane:builder
assert_eq "shadow-resume-idempotent" "$resume_rows" "$(wc -l < "$EVENTS_FILE" | tr -d ' ')"
assert_eq "shadow-resume-succeeded" "succeeded" "$(recorded_state lane:builder)"

# Break caught: resuming a failed node reuses attempt-0 running/succeeded keys.
new_shadow_case resume-failed
assert_shadow_init "shadow-resume-failed-init"
assert_ok "shadow-resume-failed-setup" graph_shadow_record_node lane:builder failed 0 prior-halt
RESUME=1
assert_shadow_init "shadow-resume-failed-ledger-preserved"
assert_ok "shadow-resume-failed-retries" graph_shadow_record_resume lane:builder
assert_eq "shadow-resume-failed-succeeded" "succeeded" "$(recorded_state lane:builder)"
assert_eq "shadow-resume-failed-next-attempt" "1" \
  "$("$EVENTS" replay "$EVENTS_FILE" "$RUN_ID" "$GRAPH_ID" | jq -r '.nodes["lane:builder"].attempt')"

# Break caught: disabling shadow mode changes the legacy runner path or creates
# graph artifacts despite the explicit opt-out.
disabled_out=$(run_main_fixture disabled 2>&1); disabled_rc=$?
assert_eq "shadow-disabled-old-main-path" "0" "$disabled_rc"
assert_eq "shadow-disabled-still-promotes" $'preflight-basic\ncontract-v2\nside-effect\npromote' \
  "$(cat "$TEST_TMPDIR/main-disabled.order" 2>/dev/null)"

# Break caught: --dry-run silently becomes a second, undocumented shadow opt-out.
new_shadow_case dry-run
DRY_RUN=1
assert_shadow_init "shadow-dry-run-still-initializes"
assert_ok "shadow-dry-run-graph-exists" test -f "$SHADOW_DIR/graph.json"
assert_ok "shadow-dry-run-events-exist" test -f "$SHADOW_DIR/events.jsonl"

# Break caught: a valid but differently routed graph is accepted as parity.
new_shadow_case mismatch
assert_shadow_init "shadow-mismatch-init"
jq '(.edges[] | select(.from=="verifier" and .outcome=="passed")).to="halt"' \
  "$GRAPH_FILE" > "$SHADOW_DIR/mismatch.json"
mv "$SHADOW_DIR/mismatch.json" "$GRAPH_FILE"
mismatch_out=$(graph_shadow_record_decision GO 2>&1); mismatch_rc=$?
assert_fail "shadow-mismatch-fails-closed" test "$mismatch_rc" -eq 0
assert_contains "shadow-mismatch-actionable" "GRAPH-SHADOW:" "$mismatch_out"
assert_eq "shadow-mismatch-no-events" "0" "$(wc -l < "$EVENTS_FILE" | tr -d ' ')"

# Break caught: corrupt event history is ignored and promotion remains possible.
new_shadow_case corrupt-events
assert_shadow_init "shadow-corrupt-events-init"
printf '%s\n' '{not-json' > "$EVENTS_FILE"
event_out=$(graph_shadow_record_resume lane:builder 2>&1); event_rc=$?
assert_fail "shadow-corrupt-events-fails-closed" test "$event_rc" -eq 0
assert_contains "shadow-corrupt-events-actionable" "GRAPH-SHADOW:" "$event_out"

finish
