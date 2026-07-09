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
"$MEM" "$S" set-status m1.1 done "commit abc" 3 >/dev/null
"$MEM" "$S" set-status m1.2 done >/dev/null
"$MEM" "$S" set-status c1  done >/dev/null
assert_ok   "met-when-all-done"  "$MEM" "$S" met

# after m1.2 is done, next has no open sub-goal left
assert_eq   "next-empty-when-done" "" "$("$MEM" "$S" next)"

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

finish
