#!/usr/bin/env bash
# polylane-memory.sh — the /polylane-max blackboard + HTN goal-tree. Exercised as
# a CLI (it runs on invocation), asserting output + exit codes.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
MEM="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-memory.sh"

if ! command -v jq >/dev/null 2>&1; then
  pass "memory-skipped-no-jq"; finish; exit 0
fi

make_tmpdir
S="$TEST_TMPDIR/state.json"

assert_ok   "init"          "$MEM" "$S" init "Publish polylane"
assert_ok   "add-criterion" "$MEM" "$S" add-criterion c1 "tests pass" 2
assert_ok   "add-milestone" "$MEM" "$S" add-milestone m1 "Distribution"
assert_ok   "add-subgoal-a" "$MEM" "$S" add-subgoal m1 m1.1 "write docs" 1
assert_ok   "add-subgoal-b" "$MEM" "$S" add-subgoal m1 m1.2 "publish" 5

# next = highest-weight OPEN sub-goal
assert_eq   "next-picks-heaviest" "m1.2  publish" "$("$MEM" "$S" next)"

# blackboard: an attempt is remembered so the loop never repeats it
"$MEM" "$S" log 3 attempt "flat cycles no tree" "hard to score" >/dev/null
assert_ok   "attempted-seen"     "$MEM" "$S" attempted "flat cycles no tree"
assert_fail "attempted-unseen"   "$MEM" "$S" attempted "some fresh approach"

# progress + met transitions
assert_contains "progress-fmt" "subgoals: 0/2 done" "$("$MEM" "$S" progress)"
assert_fail "not-met-initially" "$MEM" "$S" met
"$MEM" "$S" add-accept m1.1 true >/dev/null
"$MEM" "$S" add-accept m1.2 true >/dev/null
"$MEM" "$S" set-status m1.1 done "commit abc" 3 >/dev/null
"$MEM" "$S" set-status m1.2 done >/dev/null
"$MEM" "$S" set-status c1  done >/dev/null
"$MEM" "$S" check-accept >/dev/null
assert_ok   "met-when-all-done"  "$MEM" "$S" met

# after m1.2 is done, next has no open sub-goal left
assert_eq   "next-empty-when-done" "" "$("$MEM" "$S" next)"

# set-weight: the Phase-4 council's focus lever — "top" makes `next` return it
W="$TEST_TMPDIR/weight.json"
"$MEM" "$W" init g >/dev/null; "$MEM" "$W" add-milestone m1 M >/dev/null
"$MEM" "$W" add-subgoal m1 sa "A" 2 >/dev/null; "$MEM" "$W" add-subgoal m1 sb "B" 5 >/dev/null
assert_eq   "weight-next-before" "sb  B" "$("$MEM" "$W" next)"
"$MEM" "$W" set-weight sa top >/dev/null
assert_eq   "weight-top-elevates" "sa  A" "$("$MEM" "$W" next)"
"$MEM" "$W" set-weight sb 1 >/dev/null
assert_eq   "weight-numeric-set" "sa  A" "$("$MEM" "$W" next)"
assert_fail "weight-bad-id-fails" "$MEM" "$W" set-weight NOPE top

# --- verify-FIRST acceptance checks (frozen executable graders) -------------
A="$TEST_TMPDIR/accept.json"
"$MEM" "$A" init "g" >/dev/null
"$MEM" "$A" add-criterion c1 "x" >/dev/null
"$MEM" "$A" add-milestone m1 M >/dev/null
"$MEM" "$A" add-subgoal m1 s1 "A" >/dev/null
"$MEM" "$A" add-subgoal m1 s2 "B" >/dev/null
assert_ok   "accept-add"            "$MEM" "$A" add-accept s2 "exit 1"
# Key metadata is optional: old registrations remain unkeyed, while a safe key is
# stored as metadata rather than becoming a dependency glob.
assert_eq   "accept-old-syntax-has-empty-key" "" "$(jq -r '.accept[0].key // ""' "$A")"
assert_ok   "accept-add-key"         "$MEM" "$A" add-accept s2 "true" --key shared-check
assert_eq   "accept-add-key-stored"  "shared-check" "$(jq -r '.accept[1].key' "$A")"
# a done sub-goal cannot receive a NEW (weaker) grader after the fact
"$MEM" "$A" set-status s1 done >/dev/null
assert_fail "accept-refused-when-done" "$MEM" "$A" add-accept s1 "true"
# a registered-but-failing check blocks met even with every status=done
"$MEM" "$A" set-status s2 done >/dev/null
"$MEM" "$A" set-status c1 done >/dev/null
assert_fail "accept-check-fails"    "$MEM" "$A" check-accept
assert_fail "met-blocked-by-accept" "$MEM" "$A" met
assert_contains "unmet-lists-failing" "s2: exit 1" "$("$MEM" "$A" unmet-accept)"

# A failing frozen grader must leave enough evidence for an autonomous repair;
# swallowing both streams turns every terminal failure into a blind full rerun.
D="$TEST_TMPDIR/accept-diagnostic.json"
"$MEM" "$D" init g >/dev/null; "$MEM" "$D" add-milestone m1 M >/dev/null
"$MEM" "$D" add-subgoal m1 s1 A >/dev/null
"$MEM" "$D" add-accept s1 "printf 'accept-diagnostic-token\\n' >&2; exit 7" >/dev/null
diagnostic_out=$("$MEM" "$D" check-accept 2>&1); diagnostic_rc=$?
assert_eq "accept-diagnostic-fails" "1" "$diagnostic_rc"
assert_contains "accept-failure-surfaces-command" "ACCEPTANCE-COMMAND-FAILED rc=7" "$diagnostic_out"
assert_contains "accept-failure-surfaces-output" "accept-diagnostic-token" "$diagnostic_out"

# A runner-owned acceptance boundary retains a bounded, nonce-scoped JSONL tail
# in the canonical project. The command and its shell-special/multiline output
# remain data, and successful checks do not create durable failure chatter.
EVIDENCE_ROOT="$TEST_TMPDIR/accept-evidence"; mkdir -p "$EVIDENCE_ROOT"
E="$TEST_TMPDIR/accept-evidence-state.json"
"$MEM" "$E" init g >/dev/null; "$MEM" "$E" add-milestone m1 M >/dev/null
"$MEM" "$E" add-subgoal m1 s1 A >/dev/null
"$MEM" "$E" add-accept s1 "printf '%s\\n%s\\n' 'literal \$(touch never-run)' 'second line' >&2; exit 7" >/dev/null
POLYLANE_ACCEPT_FAILURE_ROOT="$EVIDENCE_ROOT" \
POLYLANE_ACCEPT_FAILURE_RUN_ID="accept-current" \
POLYLANE_ACCEPT_FAILURE_PHASE="terminal" \
  "$MEM" "$E" check-accept >/dev/null 2>&1 || true
EVIDENCE="$EVIDENCE_ROOT/docs/polylane/host-gate-failures/accept-current.acceptance.jsonl"
assert_ok "accept-failure-tail-is-retained" test -f "$EVIDENCE"
assert_ok "accept-failure-tail-is-current-run-data" jq -e '
  length == 1
  and .[0].run == "accept-current"
  and .[0].phase == "terminal"
  and .[0].return_code == 7
  and (. [0].command | contains("$(touch never-run)"))
  and (. [0].output_tail | contains("second line"))
' "$EVIDENCE"
assert_fail "accept-failure-tail-never-executes-output" test -e never-run
SUCCESS_ROOT="$TEST_TMPDIR/accept-success"; mkdir -p "$SUCCESS_ROOT"
PASS_E="$TEST_TMPDIR/accept-success-state.json"
"$MEM" "$PASS_E" init g >/dev/null; "$MEM" "$PASS_E" add-milestone m1 M >/dev/null
"$MEM" "$PASS_E" add-subgoal m1 s1 A >/dev/null
"$MEM" "$PASS_E" add-accept s1 true >/dev/null
POLYLANE_ACCEPT_FAILURE_ROOT="$SUCCESS_ROOT" \
POLYLANE_ACCEPT_FAILURE_RUN_ID="accept-success" \
POLYLANE_ACCEPT_FAILURE_PHASE="focused" \
  "$MEM" "$PASS_E" check-accept >/dev/null 2>&1
assert_fail "accept-success-creates-no-durable-chatter" \
  test -e "$SUCCESS_ROOT/docs/polylane/host-gate-failures/accept-success.acceptance.jsonl"
# flip the grader to pass -> check + met both clear
B="$TEST_TMPDIR/accept-ok.json"
"$MEM" "$B" init g >/dev/null; "$MEM" "$B" add-criterion c1 x >/dev/null
"$MEM" "$B" add-milestone m1 M >/dev/null; "$MEM" "$B" add-subgoal m1 s1 A >/dev/null
"$MEM" "$B" add-accept s1 "true" >/dev/null
"$MEM" "$B" set-status s1 done >/dev/null; "$MEM" "$B" set-status c1 done >/dev/null
assert_ok   "accept-check-passes"   "$MEM" "$B" check-accept
assert_ok   "met-when-accept-pass"  "$MEM" "$B" met

# --- fast cadence: target-focused checks now, terminal checks only at close ---
T="$TEST_TMPDIR/tiered.json"
"$MEM" "$T" init g >/dev/null; "$MEM" "$T" add-criterion c1 x >/dev/null
"$MEM" "$T" add-milestone m1 M >/dev/null
"$MEM" "$T" add-subgoal m1 s1 A >/dev/null; "$MEM" "$T" add-subgoal m1 s2 B >/dev/null
"$MEM" "$T" add-accept s1 "true" >/dev/null
"$MEM" "$T" add-accept s1 "true" --tier terminal >/dev/null
"$MEM" "$T" add-accept s2 "true" >/dev/null
assert_ok "accept-targeted-focused" "$MEM" "$T" check-accept --targets s1 --focused
assert_eq "accept-target-pass" "pass" "$(jq -r '.accept[0].status' "$T")"
assert_eq "accept-terminal-deferred" "unchecked" "$(jq -r '.accept[1].status' "$T")"
assert_eq "accept-other-deferred" "unchecked" "$(jq -r '.accept[2].status' "$T")"
assert_ok "accept-terminal-only" "$MEM" "$T" check-accept --only-terminal
assert_eq "accept-terminal-pass" "pass" "$(jq -r '.accept[1].status' "$T")"

# --- temporal regression guard (#3) -----------------------------------------
RS="$TEST_TMPDIR/regstate.json"
"$MEM" "$RS" init "goal" >/dev/null
"$MEM" "$RS" add-milestone m1 "m" >/dev/null
"$MEM" "$RS" add-subgoal m1 g1 "sub" >/dev/null
FLAG="$TEST_TMPDIR/ok"; : > "$FLAG"
"$MEM" "$RS" add-accept g1 "test -f '$FLAG'" >/dev/null
# cycle 5: passes -> no regression
"$MEM" "$RS" check-accept --cycle 5 >/dev/null
assert_eq "reg-none-when-pass" "" "$("$MEM" "$RS" regressions)"
# cycle 6: dep removed -> fail -> regressed_cycle stamped 6
rm -f "$FLAG"
"$MEM" "$RS" check-accept --cycle 6 >/dev/null 2>&1 || true
assert_contains "reg-stamps-cycle" "REGRESSED c6" "$("$MEM" "$RS" regressions)"
# restore + re-pass clears it
: > "$FLAG"
"$MEM" "$RS" check-accept --cycle 7 >/dev/null
assert_eq "reg-clears-on-repass" "" "$("$MEM" "$RS" regressions)"

# --- acceptance memoization (#4, OPT-IN via POLYLANE_ACCEPT_MEMO=1) ----------
export POLYLANE_ACCEPT_MEMO=1
MD="$TEST_TMPDIR/memo"; mkdir -p "$MD"; ( cd "$MD" && git init -q . )
MS="$MD/state.json"; "$MEM" "$MS" init g >/dev/null
"$MEM" "$MS" add-milestone m1 m >/dev/null
"$MEM" "$MS" add-subgoal m1 g1 s >/dev/null
( cd "$MD" && echo "v1" > graded.txt )
# a check that WRITES a side-effect marker each time it actually runs
"$MEM" "$MS" add-accept g1 "test -f graded.txt && echo ran >> ran.log" "graded.txt" >/dev/null
( cd "$MD" && "$MEM" "$MS" check-accept >/dev/null )        # run 1 (no fp yet) -> runs
( cd "$MD" && "$MEM" "$MS" check-accept >/dev/null )        # run 2: deps unchanged -> CACHED
assert_eq "memo-skips-when-unchanged" "1" "$(wc -l < "$MD/ran.log" | tr -d ' ')"
# change a dep byte -> re-runs
( cd "$MD" && echo "v2" > graded.txt && "$MEM" "$MS" check-accept >/dev/null )
assert_eq "memo-reruns-on-change" "2" "$(wc -l < "$MD/ran.log" | tr -d ' ')"
# a no-op touch (mtime only, same content) must NOT invalidate
( cd "$MD" && touch graded.txt && "$MEM" "$MS" check-accept >/dev/null )
assert_eq "memo-content-not-mtime" "2" "$(wc -l < "$MD/ran.log" | tr -d ' ')"
# DEFAULT (memo off): a check ALWAYS re-runs even with unchanged deps (B5 correctness)
unset POLYLANE_ACCEPT_MEMO
( cd "$MD" && "$MEM" "$MS" check-accept >/dev/null )
assert_eq "memo-off-by-default-reruns" "3" "$(wc -l < "$MD/ran.log" | tr -d ' ')"

# unknown command exits 2
assert_rc   "unknown-cmd-rc2" 2 "$MEM" "$S" bogus

# brief: compact resume string carrying the essentials (context-compaction primitive)
B=$("$MEM" "$S" brief)
assert_contains "brief-goal"     "GOAL: Publish polylane" "$B"
assert_contains "brief-progress" "PROGRESS: subgoals"     "$B"
assert_contains "brief-next"     "NEXT:"                  "$B"

# resume: full rehydration packet to continue the loop from disk after a dead convo
"$MEM" "$S" log 4 decision "d" "" >/dev/null
R=$("$MEM" "$S" resume)
assert_contains "resume-header"   "POLYLANE-MAX RESUME" "$R"
assert_contains "resume-goal"     "GOAL: Publish polylane" "$R"
assert_contains "resume-cycle"    "CYCLE: 4"            "$R"     # max cycle seen in log
assert_contains "resume-open-cr"  "OPEN CRITERIA:"      "$R"
assert_contains "resume-next"     "NEXT ACTION: resume at cycle 5" "$R"

# guards: mutating a nonexistent id/milestone must FAIL loud, not silently no-op
assert_fail "set-status-bad-id"   "$MEM" "$S" set-status NOSUCH done
assert_fail "add-subgoal-bad-mid" "$MEM" "$S" add-subgoal NOSUCHM sX "text"

# corrupt/truncated state → clean error, not a raw jq dump
BAD="$TEST_TMPDIR/corrupt.json"; printf '{trunc' > "$BAD"
assert_fail "corrupt-state-fails" "$MEM" "$BAD" next
assert_contains "corrupt-state-msg" "not valid JSON" "$("$MEM" "$BAD" next 2>&1)"

# concurrent writers must not lose updates (mkdir lock serializes RMW)
C="$TEST_TMPDIR/conc.json"; "$MEM" "$C" init "x" >/dev/null; "$MEM" "$C" add-milestone m1 M >/dev/null
i=1; while [ "$i" -le 12 ]; do "$MEM" "$C" add-subgoal m1 "s$i" "sg$i" & i=$((i+1)); done; wait 2>/dev/null
assert_eq "concurrent-no-lost-update" "12" "$(jq '.milestones[0].subgoals | length' "$C")"

finish
