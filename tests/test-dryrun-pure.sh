#!/usr/bin/env bash
# REGRESSION: --dry-run must NEVER mutate durable state. finalize_cycle_state ran on
# the stubbed GO path and stamped contract-v2 target subgoals done in state_file — a
# preview corrupted the tree and every later REAL launch died at "target must be open"
# (bit a real marathon launch).
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
BIN="$(cd "$(dirname "$RUNNER")" && pwd)"
command -v jq >/dev/null 2>&1 || { pass "dryrun-pure-skipped-no-jq"; finish; exit 0; }
make_tmpdir

R="$TEST_TMPDIR/proj"; mkdir -p "$R/.polylane/lanes" "$R/docs/polylane"
( cd "$R" && git init -q -b main . && git config user.email t@t && git config user.name t \
  && echo s > s.txt && git add -A && git commit -qm seed ) >/dev/null 2>&1

MEMH="$BIN/polylane-memory.sh"; ST="$R/docs/polylane/max-state.json"
"$MEMH" "$ST" init g >/dev/null
"$MEMH" "$ST" add-criterion c1 x >/dev/null
"$MEMH" "$ST" add-milestone m1 M >/dev/null
"$MEMH" "$ST" add-subgoal m1 t1 sub 5 >/dev/null
"$MEMH" "$ST" add-accept t1 'true' >/dev/null

# minimal contract-v2 prompt set (satisfies the strict lint)
P="$R/.polylane/lanes/a.txt"
cat > "$P" <<EOF
/goal x. OWN: a. FORBIDDEN: rest. PREDEFINED-SKILLS: s1 s2
LANE-SPECIFIC-SKILLS: s3 s4
TEST-CADENCE: x. DELEGATION: none. CHECK-CACHE: x. EXTERNAL-EVIDENCE: none.
STATUS: a DONE run=r1 · verify docs/verify-a.md
EOF
IP="$R/.polylane/lanes/i.txt"
cat > "$IP" <<EOF
/goal merge. OWN: docs. FORBIDDEN: rest. PREDEFINED-SKILLS: s1 s2
LANE-SPECIFIC-SKILLS: s3 s4
TEST-CADENCE: once. DELEGATION: verifiers only. CHECK-CACHE: x. EXTERNAL-EVIDENCE: none.
POLYLANE-VERDICT: GO run=r1 · verify
EOF
printf '{"a":["s1"],"lanes":{}}' > "$R/.polylane/lane-skills.json"
printf 'plan\n' > "$R/.polylane/cycle-plan.md"
cat > "$R/.polylane/run.json" <<EOF
{"base":"main","run_id":"r1","cycle":1,"orchestration_contract":2,"session":"plt","agent":"claude",
 "state_file":"docs/polylane/max-state.json","lane_skills_file":".polylane/lane-skills.json",
 "cycle_plan_file":".polylane/cycle-plan.md","target_subgoals":["t1"],
 "integrator":{"name":"i","model":"m","effort":"x","branch":"l/i","worktree":"$R/wt-i","prompt_file":".polylane/lanes/i.txt"},
 "lanes":[{"name":"a","model":"m","effort":"h","branch":"l/a","worktree":"$R/wt-a","prompt_file":".polylane/lanes/a.txt","own_globs":["a/**"],"target_subgoals":["t1"]}]}
EOF

before=$(jq -S . "$ST")
( cd "$R" && POLYLANE_MIN_DISK_GB=0 POLYLANE_SESSION=pltdry "$RUNNER" .polylane/run.json --dry-run ) >/dev/null 2>&1 || true
tmux kill-session -t pltdry 2>/dev/null || true
after=$(jq -S . "$ST")
assert_eq "dryrun-state-unchanged" "$before" "$after"
# and the target is still open (the exact corruption that bit)
assert_contains "dryrun-target-still-open" '"status": "open"' "$(jq -S '.milestones[].subgoals[] | select(.id=="t1")' "$ST")"

finish
