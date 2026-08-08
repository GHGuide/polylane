#!/usr/bin/env bash
# Contract-v2 acceptance runs focused target checks per cycle, defers terminal
# checks until the last autonomous route, and permits only declared external
# subgoals to remain unverified under EXTERNAL-EVIDENCE-OPEN.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

command -v jq >/dev/null 2>&1 || { pass "accept-gate-skipped-no-jq"; finish; exit 0; }

# Cycle 12's focused test files are intentionally regular files. Frozen
# acceptance must invoke them through Bash instead of failing before the
# product check has a chance to run. Its terminal check also isolates the
# product suite from a transient host disk floor.
CANONICAL_STATE="$(cd "$(dirname "$RUNNER")/.." && pwd)/docs/polylane/max-state.json"
assert_ok "c12-frozen-acceptance-uses-bash" jq -e '
  [.accept[] | select((.sid | startswith("m12.")) and .tier == "focused")] as $focused
  | [.accept[] | select(.sid == "m12.4" and .tier == "terminal")] as $terminal
  | ($focused | length == 4)
  and all($focused[]; (.cmd | startswith("bash tests/")))
  and ($terminal | length == 1)
  and ($terminal[0].cmd == "POLYLANE_MIN_DISK_GB=0 bash tests/run.sh && shellcheck -S warning bin/*.sh && bash tests/test-skill-parity.sh")
' "$CANONICAL_STATE"

make_tmpdir
P="$TEST_TMPDIR/project"
mkdir -p "$P/.polylane" "$P/int" "$P/docs/polylane"
STATE_FILE="$P/docs/polylane/max-state.json"
MEM="$(dirname "$RUNNER")/polylane-memory.sh"
"$MEM" "$STATE_FILE" init goal >/dev/null
"$MEM" "$STATE_FILE" add-criterion c1 works >/dev/null
"$MEM" "$STATE_FILE" add-milestone m1 build >/dev/null
"$MEM" "$STATE_FILE" add-subgoal m1 s0 historical 1 >/dev/null
"$MEM" "$STATE_FILE" add-subgoal m1 s1 target 10 >/dev/null
"$MEM" "$STATE_FILE" add-subgoal m1 s2 physical 5 >/dev/null
"$MEM" "$STATE_FILE" add-accept s1 'test "${REPO:-}" = "$PWD" && test "${REPO_ROOT:-}" = "$PWD"' >/dev/null
"$MEM" "$STATE_FILE" add-accept s1 'test "${REPO:-}" = "$PWD" && test "${REPO_ROOT:-}" = "$PWD"' --tier terminal >/dev/null
"$MEM" "$STATE_FILE" add-accept s2 false >/dev/null
"$MEM" "$STATE_FILE" add-accept s2 false --tier terminal >/dev/null
"$MEM" "$STATE_FILE" add-accept s0 false --tier terminal >/dev/null
"$MEM" "$STATE_FILE" set-status s0 done "verified in an earlier cycle" 0 >/dev/null

MANIFEST="$P/.polylane/run.json"
cat > "$MANIFEST" <<'JSON'
{"target_subgoals":["s1"]}
JSON
ORCHESTRATION_CONTRACT=2
CYCLE=1
INT_WORKTREE="$P/int"
TERMINAL_LOG="$TEST_TMPDIR/terminal-gates.log"; : > "$TERMINAL_LOG"
run_stats() {
  [ "${1:-}" = terminal-gate ] && printf 'terminal\n' >> "$TERMINAL_LOG"
  return 0
}

assert_ok "accept-focused-cycle-pass" contract_acceptance_gate GO
assert_eq "accept-focused-does-not-count-terminal" "0" "$(wc -l < "$TERMINAL_LOG" | tr -d ' ')"
assert_eq "accept-focused-stamped" "pass" "$(jq -r '.accept[0].status' "$STATE_FILE")"
assert_eq "accept-terminal-deferred" "unchecked" "$(jq -r '.accept[1].status' "$STATE_FILE")"
assert_eq "accept-other-deferred" "unchecked" "$(jq -r '.accept[2].status' "$STATE_FILE")"
assert_eq "accept-external-terminal-deferred" "unchecked" "$(jq -r '.accept[3].status' "$STATE_FILE")"

"$MEM" "$STATE_FILE" set-status s2 external "physical proof" 1 >/dev/null
assert_ok "accept-external-allows-declared-gap" contract_acceptance_gate EXTERNAL-EVIDENCE-OPEN
assert_eq "accept-terminal-gate-counted" "1" "$(wc -l < "$TERMINAL_LOG" | tr -d ' ')"
assert_eq "accept-terminal-runs-at-boundary" "pass" "$(jq -r '.accept[1].status' "$STATE_FILE")"
assert_eq "accept-external-terminal-not-executed" "unchecked" "$(jq -r '.accept[3].status' "$STATE_FILE")"
assert_eq "accept-historical-terminal-not-replayed" "unchecked" "$(jq -r '.accept[4].status' "$STATE_FILE")"
assert_fail "accept-go-rejects-external-gap" contract_acceptance_gate GO
assert_eq "accept-failing-terminal-gate-counted" "2" "$(wc -l < "$TERMINAL_LOG" | tr -d ' ')"

VERDICT_RESULT=EXTERNAL-EVIDENCE-OPEN
out=$(finalize_cycle_state)
assert_contains "accept-finalize-routes-needs-user" "NEEDS-USER" "$out"
assert_eq "accept-target-marked-done" "done" "$(jq -r '.milestones[0].subgoals[0].status' "$STATE_FILE")"

finish
