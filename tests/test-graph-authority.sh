#!/usr/bin/env bash
# Authoritative graph admission: no tmux side effect may occur until the
# immutable graph and ledger say that exact node is ready.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

command -v jq >/dev/null 2>&1 || { pass "authority-skipped-no-jq"; finish; exit 0; }
make_tmpdir

BIN="$(cd "$(dirname "$RUNNER")" && pwd)"
MANIFEST="$TEST_TMPDIR/run.json"
cat > "$MANIFEST" <<'JSON'
{"orchestration_contract":2,"run_id":"authority-run","cycle":3,"target_subgoals":["g1"],"integrator":{"name":"integrator","model":"m","effort":"high"},"lanes":[{"name":"blocked","model":"m","effort":"high","own_globs":["src/**"],"target_subgoals":["g1"]}]}
JSON

ORCHESTRATION_CONTRACT=2
RUN_ID=authority-run
MANIFEST="$MANIFEST"
RESUME=0
graph_shadow_init >/dev/null 2>&1; authority_init_rc=$?
assert_eq "authority-initializes-immutable-graph" "0" "$authority_init_rc"

# Break caught: removing start's successful transition still creates a tmux pane.
# A wrong readiness gate (or an observational-only graph) makes this pass.
GRAPH_MODE=authoritative
GRAPH_AUTHORITY_MODE=authoritative
TMUX_SESSION="authority-test-$$"
SESSION_STARTED=0
NEXT_PANE_IDX=0
LANE_NAMES=(blocked)
LANE_MODELS=(m)
LANE_EFFORTS=(high)
LANE_WORKTREES=("$TEST_TMPDIR/wt")
LANE_PROMPTS=("$TEST_TMPDIR/prompt")
LANE_RESUMED=(0)
LANE_ADOPTED=(0)
LANE_PANE_IDX=(-1)
cat > "$TEST_TMPDIR/prompt" <<'EOF'
ULTIMATE-GOAL: Prove authoritative graph admission.
CURRENT-SUBGOAL: Exercise one bounded lane launch.
GOAL: launch only graph-ready work.
OWN: tests/test-graph-authority.sh.
FORBIDDEN: bypassing the immutable graph.
PREDEFINED-SKILLS: engineering:testing-strategy
LANE-SPECIFIC-SKILLS: engineering:architecture
Read only the named kit once.
TEST-CADENCE: focused first; terminal suite in integration.
DELEGATION: forbidden.
CHECK-CACHE: use the integration cache.
EXTERNAL-EVIDENCE: none.
VERIFY: record STATUS: blocked DONE run=authority-run.
EOF
mkdir -p "$TEST_TMPDIR/wt"
TMUX_CALLS="$TEST_TMPDIR/tmux.calls"
tmux() { [ "$1" = has-session ] && return 1; printf '%s\n' "$*" >> "$TMUX_CALLS"; return 0; }

blocked_out=$(launch_panes 2>&1); blocked_rc=$?
assert_fail "authority-blocked-lane-fails-closed" test "$blocked_rc" -eq 0
assert_fail "authority-blocked-lane-no-new-pane" test -e "$TMUX_CALLS"
assert_contains "authority-blocked-lane-actionable" "GRAPH-AUTHORITY:" "$blocked_out"

assert_ok "authority-start-advances" graph_authority_start
assert_ok "authority-ready-lane-launches" launch_panes
assert_contains "authority-ready-lane-new-pane" "new-session" "$(cat "$TMUX_CALLS")"

# A corrupt ledger must refuse the next runner action instead of guessing a route.
printf '{not-json\n' > "$EVENTS_FILE"
corrupt_out=$(graph_authority_require "lane:blocked" "launch" 2>&1); corrupt_rc=$?
assert_fail "authority-corrupt-ledger-fails-closed" test "$corrupt_rc" -eq 0
assert_contains "authority-corrupt-ledger-actionable" "GRAPH-AUTHORITY:" "$corrupt_out"

# Independent authoritative cases exercise the terminal routes and the repair
# loop against the real compiler, ledger, replay, and readiness CLIs.
new_authority_case() {
  local name="$1" dir="$TEST_TMPDIR/$name/.polylane"
  mkdir -p "$dir"
  cat > "$dir/run.json" <<'JSON'
{"orchestration_contract":2,"run_id":"authority-run","cycle":3,"target_subgoals":["g1"],"integrator":{"name":"integrator","model":"m","effort":"high"},"lanes":[{"name":"blocked","model":"m","effort":"high","own_globs":["src/**"],"target_subgoals":["g1"]}]}
JSON
  MANIFEST="$dir/run.json"
  ORCHESTRATION_CONTRACT=2
  RUN_ID=authority-run
  RESUME=0
  unset POLYLANE_GRAPH_MODE POLYLANE_GRAPH_SHADOW MANIFEST_GRAPH_MODE
  graph_shadow_init >/dev/null 2>&1
}

authority_state() {
  "$BIN/polylane-events.sh" replay "$EVENTS_FILE" "$RUN_ID" "$GRAPH_ID" |
    jq -r --arg node "$1" '.nodes[$node].state // "missing"'
}

authority_attempt() {
  "$BIN/polylane-events.sh" replay "$EVENTS_FILE" "$RUN_ID" "$GRAPH_ID" |
    jq -r --arg node "$1" '.nodes[$node].attempt // -1'
}

authority_reach_verifier() {
  graph_authority_start || return 1
  graph_authority_record_ready_node lane:blocked succeeded 0 builder-done || return 1
  graph_authority_record_ready_node builders-joined succeeded 0 builders-joined || return 1
  graph_authority_record_ready_node integrator succeeded 0 integrator-done
}

# Break caught: an authoritative GO can reach promotion without every action
# being admitted by its declared route.
new_authority_case go; authority_case_rc=$?
assert_eq "authority-go-case-init" "0" "$authority_case_rc"
assert_ok "authority-go-reaches-verifier" authority_reach_verifier
assert_ok "authority-go-verifier-ready" graph_authority_require verifier "run verifier"
assert_ok "authority-go-verifier-passes" graph_authority_record_ready_node verifier succeeded 0 GO
assert_ok "authority-go-promote-ready" graph_authority_require promote "promote"
assert_ok "authority-go-promotes" graph_authority_record_ready_node promote succeeded 0 GO
assert_ok "authority-go-complete-ready" graph_authority_require complete "complete"
assert_ok "authority-go-completes" graph_authority_record_ready_node complete succeeded 0 GO
assert_eq "authority-go-terminal-state" "succeeded" "$(authority_state complete)"

# Break caught: after one declared repair loop, a second verifier attempt is
# not ready and terminal NO-GO cannot take a declared halt route.  Attempt 1
# proves this is a retry rather than an idempotent replay of attempt 0.
new_authority_case retry; authority_case_rc=$?
assert_eq "authority-retry-case-init" "0" "$authority_case_rc"
assert_ok "authority-retry-reaches-verifier" authority_reach_verifier
assert_ok "authority-retry-first-verifier-fails" graph_authority_record_ready_node verifier failed 0 NO-GO
assert_ok "authority-retry-repair-succeeds" graph_authority_record_ready_node repair succeeded 0 repaired
assert_ok "authority-retry-verifier-ready" graph_authority_require verifier "retry verifier"
assert_ok "authority-retry-second-verifier-fails" graph_authority_record_ready_node verifier failed 1 NO-GO
assert_eq "authority-retry-attempt-recorded" "1" "$(authority_attempt verifier)"
assert_ok "authority-retry-no-go-halts" graph_authority_no_go
assert_eq "authority-retry-no-go-terminal-state" "succeeded" "$(authority_state halt)"

# A runner can die after the repair agent commits a fresh GO verdict but before
# recording the repair boundary. Resume must append the declared repair event
# before asking the graph to admit verifier attempt 1; otherwise verifier stays
# terminal-failed forever and every supervisor restart repeats the refusal.
new_authority_case resume-repair; authority_case_rc=$?
assert_eq "authority-resume-repair-case-init" "0" "$authority_case_rc"
assert_ok "authority-resume-repair-reaches-verifier" authority_reach_verifier
assert_ok "authority-resume-repair-first-verifier-fails" \
  graph_authority_record_ready_node verifier failed 0 NO-GO
INT_WORKTREE="$TEST_TMPDIR/resume-repair/wt"
mkdir -p "$INT_WORKTREE/docs"
printf 'POLYLANE-VERDICT: GO run=%s\n' "$RUN_ID" > "$INT_WORKTREE/docs/verify-integration.md"
RESUME=1
assert_ok "authority-resume-repair-reconciles" graph_authority_reconcile_verifier_repair
assert_eq "authority-resume-repair-node-succeeded" "succeeded" "$(authority_state repair)"
assert_ok "authority-resume-repair-verifier-ready" graph_authority_require verifier "resume verifier"
assert_eq "authority-resume-repair-verifier-attempt" "0" "$(authority_attempt verifier)"
RESUME=0

# READY is also evidence of a completed repair: the outer runner, rather than
# the integrator, still owns the terminal verdict conversion.
new_authority_case resume-ready; authority_case_rc=$?
assert_eq "authority-resume-ready-case-init" "0" "$authority_case_rc"
assert_ok "authority-resume-ready-reaches-verifier" authority_reach_verifier
assert_ok "authority-resume-ready-first-verifier-fails" \
  graph_authority_record_ready_node verifier failed 0 NO-GO
INT_WORKTREE="$TEST_TMPDIR/resume-ready/wt"
mkdir -p "$INT_WORKTREE/docs"
printf 'POLYLANE-VERDICT: READY-FOR-HOST-GATE run=%s\n' "$RUN_ID" > "$INT_WORKTREE/docs/verify-integration.md"
RESUME=1
assert_ok "authority-resume-ready-reconciles" graph_authority_reconcile_verifier_repair
assert_eq "authority-resume-ready-node-succeeded" "succeeded" "$(authority_state repair)"
assert_ok "authority-resume-ready-verifier-ready" graph_authority_require verifier "resume READY verifier"
RESUME=0

# Break caught: a HALTED lane bypasses its failed outcome route.
new_authority_case halted; authority_case_rc=$?
assert_eq "authority-halted-case-init" "0" "$authority_case_rc"
assert_ok "authority-halted-start" graph_authority_start
assert_ok "authority-halted-route" graph_authority_halt_node lane:blocked
assert_eq "authority-halted-terminal-state" "succeeded" "$(authority_state halt)"

# Break caught: resume writes a completed lane before the start checkpoint has
# made that lane ready.  Once start advances, duplicate resume is idempotent.
new_authority_case resume; authority_case_rc=$?
assert_eq "authority-resume-case-init" "0" "$authority_case_rc"
resume_blocked_out=$(graph_shadow_record_resume lane:blocked 2>&1); resume_blocked_rc=$?
assert_fail "authority-resume-before-start-refused" test "$resume_blocked_rc" -eq 0
assert_contains "authority-resume-before-start-actionable" "GRAPH-AUTHORITY:" "$resume_blocked_out"
assert_eq "authority-resume-before-start-no-state" "missing" "$(authority_state lane:blocked)"
assert_ok "authority-resume-start" graph_authority_start
assert_ok "authority-resume-first" graph_shadow_record_resume lane:blocked
resume_rows=$(wc -l < "$EVENTS_FILE" | tr -d ' ')
assert_ok "authority-resume-duplicate" graph_shadow_record_resume lane:blocked
assert_eq "authority-resume-idempotent" "$resume_rows" "$(wc -l < "$EVENTS_FILE" | tr -d ' ')"
resume_started_rows=$(wc -l < "$EVENTS_FILE" | tr -d ' ')
assert_ok "authority-resume-start-idempotent" graph_authority_start
assert_eq "authority-resume-start-no-duplicate" "$resume_started_rows" \
  "$(wc -l < "$EVENTS_FILE" | tr -d ' ')"

# Break caught: the second verifier action after a repair runs before graph
# admission, so an undeclared/not-ready retry can execute and only fail later.
GATE_ORDER="$TEST_TMPDIR/gate-order.log"
: > "$GATE_ORDER"
GATE_MERGES=0
graph_authority_enabled() { return 0; }
graph_authority_require() { printf 'require:%s\n' "$1" >> "$GATE_ORDER"; }
graph_authority_record_ready_node() {
  printf 'record:%s:%s:%s\n' "$1" "$2" "${3:-0}" >> "$GATE_ORDER"
}
merge_gate() {
  GATE_MERGES=$((GATE_MERGES + 1))
  printf 'merge:%s\n' "$GATE_MERGES" >> "$GATE_ORDER"
  if [ "$GATE_MERGES" -eq 1 ]; then VERDICT_RESULT=NO-GO; return 1; fi
  VERDICT_RESULT=GO
}
repair_integrator_verdict() { printf 'repair:%s\n' "$1" >> "$GATE_ORDER"; }
poll_done() { printf 'poll\n' >> "$GATE_ORDER"; }
capture_stats() { :; }
POLYLANE_INTEGRATOR_REPAIRS=1
unset VERDICT_REPAIRABLE
assert_ok "authority-gate-repair-eventually-go" gate_with_repairs
assert_eq "authority-gate-before-every-verifier-action" \
  $'require:verifier\nmerge:1\nrecord:verifier:failed:0\nrequire:repair\nrepair:1\npoll\nrecord:repair:succeeded:1\nrequire:verifier\nmerge:2' \
  "$(cat "$GATE_ORDER")"

finish
