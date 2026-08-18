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
"$MEM" "$STATE_FILE" add-criterion c2 "host gate proves the cycle" >/dev/null
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
{"target_subgoals":["s1"],"target_criteria":["c2"]}
JSON
ORCHESTRATION_CONTRACT=2
CYCLE=1
INT_WORKTREE="$P/int"
REPO_ROOT="$P"
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
assert_eq "accept-ready-preserves-external-route" "EXTERNAL-EVIDENCE-OPEN" "$(contract_ready_verdict)"
assert_ok "accept-external-allows-declared-gap" contract_acceptance_gate EXTERNAL-EVIDENCE-OPEN
assert_eq "accept-terminal-gate-counted" "1" "$(wc -l < "$TERMINAL_LOG" | tr -d ' ')"
assert_eq "accept-terminal-runs-at-boundary" "pass" "$(jq -r '.accept[1].status' "$STATE_FILE")"
assert_eq "accept-external-terminal-not-executed" "unchecked" "$(jq -r '.accept[3].status' "$STATE_FILE")"
assert_eq "accept-historical-terminal-not-replayed" "unchecked" "$(jq -r '.accept[4].status' "$STATE_FILE")"
assert_fail "accept-go-rejects-external-gap" contract_acceptance_gate GO
assert_eq "accept-failing-terminal-gate-counted" "2" "$(wc -l < "$TERMINAL_LOG" | tr -d ' ')"

VERDICT_RESULT=EXTERNAL-EVIDENCE-OPEN
out=$(finalize_cycle_state)
assert_eq "accept-target-marked-done" "done" "$(jq -r '.milestones[].subgoals[] | select(.id=="s1") | .status' "$STATE_FILE")"
assert_eq "accept-host-criterion-deferred-until-cleanup" "open" "$(jq -r '.criteria[] | select(.id=="c2") | .status' "$STATE_FILE")"
out=$(finalize_cycle_criteria)
assert_contains "accept-finalize-routes-needs-user" "NEEDS-USER" "$out"
assert_eq "accept-target-criterion-marked-done" "done" "$(jq -r '.criteria[] | select(.id=="c2") | .status' "$STATE_FILE")"

# Failure output belongs to the canonical runner project, not the disposable
# integrator checkout where the acceptance command executes.
"$MEM" "$STATE_FILE" add-subgoal m1 s3 failing 1 >/dev/null
"$MEM" "$STATE_FILE" add-accept s3 "printf 'canonical failure tail\\n' >&2; exit 9" >/dev/null
jq '.target_subgoals = ["s3"]' "$MANIFEST" > "$MANIFEST.tmp"
mv "$MANIFEST.tmp" "$MANIFEST"
RUN_ID=accept-canonical
assert_fail "accept-focused-failure-is-rejected" contract_focused_acceptance_gate
CANONICAL_FAILURE="$P/docs/polylane/host-gate-failures/accept-canonical.acceptance.jsonl"
assert_ok "accept-failure-output-is-canonical" test -f "$CANONICAL_FAILURE"
assert_fail "accept-failure-output-is-not-in-integrator-worktree" \
  test -e "$P/int/docs/polylane/host-gate-failures/accept-canonical.acceptance.jsonl"
assert_ok "accept-canonical-output-retains-current-run" jq -e '
  length == 1
  and .[0].run == "accept-canonical"
  and .[0].phase == "focused"
  and .[0].return_code == 9
  and (. [0].output_tail | contains("canonical failure tail"))
' "$CANONICAL_FAILURE"
unset RUN_ID

# A focused-only target may be source-complete even with no remaining
# autonomous work.  It must promote without inventing a terminal boundary.
FOCUSED_STATE="$TEST_TMPDIR/focused-only.json"
"$MEM" "$FOCUSED_STATE" init goal >/dev/null
"$MEM" "$FOCUSED_STATE" add-milestone m1 build >/dev/null
"$MEM" "$FOCUSED_STATE" add-subgoal m1 focused "focused only" >/dev/null
"$MEM" "$FOCUSED_STATE" add-accept focused true >/dev/null
printf '%s\n' '{"target_subgoals":["focused"]}' > "$MANIFEST"
STATE_FILE="$FOCUSED_STATE"
: > "$TERMINAL_LOG"
assert_ok "accept-focused-only-target-promotes" contract_acceptance_gate GO
assert_eq "accept-focused-only-target-never-counts-terminal" "0" "$(wc -l < "$TERMINAL_LOG" | tr -d ' ')"

# READY may consume one just-passed focused proof only at the unchanged,
# committed integrator tip.  A dirty tip invalidates it and reruns the command.
REUSE="$TEST_TMPDIR/reuse"; REUSE_INT="$REUSE/int"; REUSE_LOG="$TEST_TMPDIR/reuse.log"
mkdir -p "$REUSE_INT"
git -C "$REUSE_INT" init -q -b main
git -C "$REUSE_INT" config user.email test@example.invalid
git -C "$REUSE_INT" config user.name test
printf 'clean\n' > "$REUSE_INT/README.md"
git -C "$REUSE_INT" add README.md && git -C "$REUSE_INT" commit -qm clean
REUSE_PROMPT="$REUSE/compiled-prompt.txt"
printf 'authoritative runtime prompt\n' > "$REUSE_PROMPT"
cp "$REUSE_PROMPT" "$REUSE_INT/.polylane-prompt.txt"
REUSE_STATE="$REUSE/state.json"; mkdir -p "$REUSE"
"$MEM" "$REUSE_STATE" init goal >/dev/null
"$MEM" "$REUSE_STATE" add-milestone m1 build >/dev/null
"$MEM" "$REUSE_STATE" add-subgoal m1 s1 target >/dev/null
"$MEM" "$REUSE_STATE" add-accept s1 "printf 'focused\\n' >> '$REUSE_LOG'" >/dev/null
"$MEM" "$REUSE_STATE" add-accept s1 "printf 'terminal\\n' >> '$REUSE_LOG'" --tier terminal >/dev/null
printf '%s\n' '{"target_subgoals":["s1"]}' > "$MANIFEST"
STATE_FILE="$REUSE_STATE"; REPO_ROOT="$REUSE"; INT_WORKTREE="$REUSE_INT"; FOCUSED_ACCEPTANCE_PROOF=""
INT_NAME=integrator; INT_PROMPT="$REUSE_PROMPT"
: > "$REUSE_LOG"
contract_focused_acceptance_gate; reuse_capture_rc=$?
assert_eq "ready-focused-proof-captures-pass" "0" "$reuse_capture_rc"
assert_ok "ready-focused-proof-accepts-identical-runner-prompt" test -n "$FOCUSED_ACCEPTANCE_PROOF"
contract_acceptance_gate GO 1 1; reuse_rc=$?
assert_eq "ready-focused-proof-reuses-unchanged-tip" "0" "$reuse_rc"
assert_eq "ready-focused-proof-runs-focused-once" "1" "$(grep -c '^focused$' "$REUSE_LOG")"
contract_focused_acceptance_gate; recapture_rc=$?
assert_eq "ready-focused-proof-recaptures-before-mutation" "0" "$recapture_rc"
printf 'dirty\n' >> "$REUSE_INT/README.md"
contract_acceptance_gate GO 1 1; dirty_reuse_rc=$?
assert_eq "ready-focused-proof-reruns-when-dirty" "0" "$dirty_reuse_rc"
assert_eq "ready-focused-proof-dirty-reruns-focused" "3" "$(grep -c '^focused$' "$REUSE_LOG")"

# Returning to a clean tree is not enough when the committed tip changed.
# Likewise, acceptance definitions are part of the receipt even when HEAD and
# the worktree remain unchanged.
git -C "$REUSE_INT" restore README.md
contract_focused_acceptance_gate; head_capture_rc=$?
assert_eq "ready-focused-proof-recaptures-before-head-change" "0" "$head_capture_rc"
printf 'new tip\n' > "$REUSE_INT/tip.txt"
git -C "$REUSE_INT" add tip.txt && git -C "$REUSE_INT" commit -qm 'new tip'
contract_acceptance_gate GO 1 1; head_reuse_rc=$?
assert_eq "ready-focused-proof-reruns-when-head-changes" "0" "$head_reuse_rc"
assert_eq "ready-focused-proof-head-change-reruns-focused" "5" "$(grep -c '^focused$' "$REUSE_LOG")"
contract_focused_acceptance_gate; definition_capture_rc=$?
assert_eq "ready-focused-proof-recaptures-before-definition-change" "0" "$definition_capture_rc"
jq --arg cmd "printf 'focused-definition\\n' >> '$REUSE_LOG'" \
  '(.accept[] | select((.tier // "focused") == "focused") | .cmd) = $cmd' \
  "$REUSE_STATE" > "$REUSE_STATE.tmp"
mv "$REUSE_STATE.tmp" "$REUSE_STATE"
contract_acceptance_gate GO 1 1; definition_reuse_rc=$?
assert_eq "ready-focused-proof-reruns-when-definition-changes" "0" "$definition_reuse_rc"
assert_eq "ready-focused-proof-definition-change-runs-new-command" "1" "$(grep -c '^focused-definition$' "$REUSE_LOG")"

finish
