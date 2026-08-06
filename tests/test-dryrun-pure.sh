#!/usr/bin/env bash
# REGRESSION: --dry-run must NEVER mutate durable state. finalize_cycle_state ran on
# the stubbed GO path and stamped contract-v2 target subgoals done in state_file — a
# preview corrupted the tree and every later REAL launch died at "target must be open"
# (bit a real marathon launch).
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
BIN="$(cd "$(dirname "$RUNNER")" && pwd)"
. "$RUNNER"
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
 "quality_judges":["judge-a"],
 "integrator":{"name":"i","model":"m","effort":"x","branch":"l/i","worktree":"$R/wt-i","prompt_file":".polylane/lanes/i.txt"},
 "lanes":[{"name":"a","model":"m","effort":"h","branch":"l/a","worktree":"$R/wt-a","prompt_file":".polylane/lanes/a.txt","own_globs":["a/**"],"target_subgoals":["t1"]}]}
EOF

before=$(jq -S . "$ST")
DRYOUT="$TEST_TMPDIR/dry-run.out"
( cd "$R" && POLYLANE_MIN_DISK_GB=0 POLYLANE_SESSION=pltdry "$RUNNER" .polylane/run.json --dry-run ) >"$DRYOUT" 2>&1 || true
tmux kill-session -t pltdry 2>/dev/null || true
after=$(jq -S . "$ST")
assert_eq "dryrun-state-unchanged" "$before" "$after"
# and the target is still open (the exact corruption that bit)
assert_contains "dryrun-target-still-open" '"status": "open"' "$(jq -S '.milestones[].subgoals[] | select(.id=="t1")' "$ST")"
# Dry-run is a preview: judges cannot inspect missing dry-run worktrees, and no
# advanced-runtime outcome ledger may be created or record a false NO-GO.
if grep -q 'polylane-judges.sh' "$DRYOUT"; then fail "dryrun-no-quality-judge" "judge helper executed during preview"; else pass "dryrun-no-quality-judge"; fi
assert_ok "dryrun-no-outcome-ledger" test ! -e "$R/docs/polylane/outcomes.jsonl"
if grep -q 'false NO-GO\|Halt: quality judges failed' "$DRYOUT"; then fail "dryrun-no-false-judge-nogo" "preview treated missing worktree as judge failure"; else pass "dryrun-no-false-judge-nogo"; fi

# The gate itself must be preview-pure even when the surrounding run reaches it.
JUDGE_MARKER="$TEST_TMPDIR/judge-ran"
cat > "$TEST_TMPDIR/polylane-judges.sh" <<EOF
#!/usr/bin/env bash
touch "$JUDGE_MARKER"
exit 1
EOF
chmod +x "$TEST_TMPDIR/polylane-judges.sh"
SCRIPT_DIR="$TEST_TMPDIR"; DRY_RUN=1; INT_WORKTREE="$R/missing-integrator"; MANIFEST="$R/.polylane/run.json"
assert_ok "dryrun-quality-gate-skipped" quality_judge_gate
assert_ok "dryrun-quality-helper-not-executed" test ! -e "$JUDGE_MARKER"

finish
