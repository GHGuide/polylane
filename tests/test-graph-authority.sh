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
printf 'work\n' > "$TEST_TMPDIR/prompt"
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

finish
