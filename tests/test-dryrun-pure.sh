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
printf 'index\n' > "$R/docs/polylane/INDEX.md"

# A real contract-v2 preview needs a complete builder kit, but never an
# integrator kit. Keep every selected record inside this test's trusted root.
export POLYLANE_SKILLS_DIRS="$TEST_TMPDIR/skills"
for skill in s1 s2 s3 s4; do
  mkdir -p "$POLYLANE_SKILLS_DIRS/$skill"
  printf '%s\n' '---' "name: $skill" > "$POLYLANE_SKILLS_DIRS/$skill/SKILL.md"
done

MEMH="$BIN/polylane-memory.sh"; ST="$R/docs/polylane/max-state.json"
"$MEMH" "$ST" init g >/dev/null
"$MEMH" "$ST" add-criterion c1 x >/dev/null
"$MEMH" "$ST" add-milestone m1 M >/dev/null
"$MEMH" "$ST" add-subgoal m1 t1 sub 5 >/dev/null
"$MEMH" "$ST" add-accept t1 'true' >/dev/null

# minimal contract-v2 prompt set (satisfies the strict lint)
P="$R/.polylane/lanes/a.txt"
cat > "$P" <<EOF
ULTIMATE-GOAL: preview remains safe and complete.
CURRENT-SUBGOAL: launch one virtual builder pane.
GOAL: prove the dry-run preview completes.
OWN: a/** docs/status-a.md. FORBIDDEN: rest.
PREDEFINED-SKILLS: s1 s2
LANE-SPECIFIC-SKILLS: s3 s4
Read only the named kit once; do not enumerate or rediscover skills.
TEST-CADENCE: focused first.
DELEGATION: forbidden; do not spawn subagents or fan-out.
CHECK-CACHE: use \$PWD/.polylane/check-cache/a with polylane-check.sh for repeat checks.
EXTERNAL-EVIDENCE: none.
VERIFY: write docs/verify-a.md before DONE.
Finish STATUS: a DONE run=r1.
EOF
IP="$R/.polylane/lanes/i.txt"
cat > "$IP" <<EOF
ULTIMATE-GOAL: preview remains safe and complete.
CURRENT-SUBGOAL: launch one virtual builder pane.
GOAL: prove the dry-run preview completes.
OWN: integrator branch. FORBIDDEN: base branch.
PREDEFINED-SKILLS: s1 s2
LANE-SPECIFIC-SKILLS: s3 s4
Read only the named kit once; do not enumerate or rediscover skills.
TEST-CADENCE: focused first.
DELEGATION: forbidden; do not spawn subagents or fan-out.
CHECK-CACHE: use \$PWD/.polylane/check-cache/i with polylane-check.sh for repeat checks.
EXTERNAL-EVIDENCE: none.
VERIFY: write docs/verify-integration.md before DONE.
Finish STATUS: i DONE run=r1.
POLYLANE-VERDICT: GO run=r1
EOF
"$BIN/polylane-scout.sh" arm-role "$R/.polylane/lane-skills.json" a predefined s1 s2
"$BIN/polylane-scout.sh" arm-role "$R/.polylane/lane-skills.json" a specific s3 s4
printf 'plan\n' > "$R/.polylane/cycle-plan.md"
cat > "$R/.polylane/run.json" <<EOF
{"base":"main","run_id":"r1","cycle":1,"orchestration_contract":2,"session":"plt","agent":"claude",
 "state_file":"docs/polylane/max-state.json","lane_skills_file":".polylane/lane-skills.json",
 "cycle_plan_file":".polylane/cycle-plan.md","target_subgoals":["t1"],"target_criteria":["c1"],
 "integrator":{"name":"i","model":"m","effort":"x","branch":"l/i","worktree":"$R/wt-i","prompt_file":".polylane/lanes/i.txt"},
 "lanes":[{"name":"a","model":"m","effort":"h","branch":"l/a","worktree":"$R/wt-a","prompt_file":".polylane/lanes/a.txt","own_globs":["a/**","docs/status-a.md"],"target_subgoals":["t1"]}]}
EOF

before=$(jq -S . "$ST")
DRYOUT="$TEST_TMPDIR/dry-run.out"
( cd "$R" && POLYLANE_MIN_DISK_GB=0 POLYLANE_AGENT_CMD='true {model} {prompt}' POLYLANE_SESSION=pltdry "$RUNNER" .polylane/run.json --dry-run ) >"$DRYOUT" 2>&1
dry_rc=$?
[ "$dry_rc" = 0 ] || sed -n '1,160p' "$DRYOUT" >&2
assert_eq "dryrun-preview-completes" "0" "$dry_rc"
assert_contains "dryrun-preview-reaches-launch-completion" "Dry-run preview complete" "$(cat "$DRYOUT")"
assert_fail "dryrun-creates-no-tmux-session" tmux has-session -t pltdry
tmux kill-session -t pltdry 2>/dev/null || true
after=$(jq -S . "$ST")
assert_eq "dryrun-state-unchanged" "$before" "$after"
# and the target is still open (the exact corruption that bit)
assert_contains "dryrun-target-still-open" '"status": "open"' "$(jq -S '.milestones[].subgoals[] | select(.id=="t1")' "$ST")"
assert_eq "dryrun-target-criterion-still-open" "open" "$(jq -r '.criteria[] | select(.id=="c1") | .status' "$ST")"
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
