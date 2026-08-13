#!/usr/bin/env bash
# Reflexion repair-loop helpers: build_repair_prompt (pure) + the lane prompt /
# repair-count accessors that let a lane respawn with a reflect-then-fix prompt
# before it is marked failed.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

make_tmpdir
seed="$TEST_TMPDIR/x.txt"
printf 'ORIGINAL GOAL: build widget X to DONE' > "$seed"
REPO_ROOT="$TEST_TMPDIR/canonical root"

out=$(build_repair_prompt "$seed" x 2)
assert_contains "repair-keeps-original"    "ORIGINAL GOAL: build widget X" "$out"
assert_contains "repair-attempt-number"    "REPAIR ATTEMPT 2"              "$out"
assert_contains "repair-points-canonical-transcript" \
  "$REPO_ROOT/docs/lane-logs/x.log" "$out"
assert_contains "repair-demands-different" "DIFFERENT"                     "$out"
assert_contains "repair-keeps-goal-locked" "locked goal is unchanged"      "$out"

# lane prompt + repair-count accessors (indexed, bash-3.2 safe)
LANE_NAMES=(x y); LANE_PROMPTS=("$seed" "/p/y"); LANE_REPAIRS=(0 0)
LANE_PANE_IDX=(0 1); INT_NAME="int"; INT_PROMPT="/p/int"

assert_eq "prompt-get-lane"    "$seed"  "$(lane_prompt_get x)"
assert_eq "prompt-get-int"     "/p/int" "$(lane_prompt_get int)"
lane_prompt_set x "$TEST_TMPDIR/x.repair.txt"
assert_eq "prompt-set-lane"    "$TEST_TMPDIR/x.repair.txt" "$(lane_prompt_get x)"
lane_prompt_set int "/p/int.repair"
assert_eq "prompt-set-int"     "/p/int.repair" "$(lane_prompt_get int)"

assert_eq "repairs-default-0"  "0" "$(repairs_get y)"
repairs_set y 3
assert_eq "repairs-set-get"    "3" "$(repairs_get y)"

# Regression: a second Reflexion wave reuses <lane>.repair.txt as both the
# current source and destination.  Recovery must publish through a separate
# candidate so it cannot truncate the immutable goal while reading it.
strict="$TEST_TMPDIR/strict.txt"
cat > "$strict" <<'EOF'
ULTIMATE-GOAL: Ship a verified product without losing the goal during recovery.
CURRENT-SUBGOAL: Keep every strict block through repeated repair attempts.
GOAL: repair the same lane twice.
OWN: tests/**.
FORBIDDEN: everything else.
PREDEFINED-SKILLS: engineering:testing-strategy
LANE-SPECIFIC-SKILLS: engineering:debug
Read only the named kit once.
TEST-CADENCE: focused first; full suite at integration.
DELEGATION: forbidden.
CHECK-CACHE: use the lane cache.
EXTERNAL-EVIDENCE: none.
VERIFY: finish STATUS: x DONE run=repair-run.
EOF
REPO_ROOT="$TEST_TMPDIR/repeated"
mkdir -p "$REPO_ROOT/.polylane/lanes"
LANE_NAMES=(x); LANE_PROMPTS=("$strict"); LANE_REPAIRS=(0); LANE_PANE_IDX=(0)
LANE_RETRIES=(0); LANE_WHASH=(""); LANE_WCNT=(0); LANE_PHASH=(""); LANE_PCNT=(0)
notify_event() { :; }
respawn_lane() { :; }

if reflect_and_repair x "$TEST_TMPDIR/wt" 0 >/dev/null 2>&1; then
  pass "repair-first-wave"
else
  fail "repair-first-wave" "expected rc 0"
fi
assert_ok "repair-first-wave-strict" \
  "$SCRIPT_DIR/../bin/polylane-promptopt.sh" check "$(lane_prompt_get x)"
if reflect_and_repair x "$TEST_TMPDIR/wt" 0 >/dev/null 2>&1; then
  pass "repair-second-wave"
else
  fail "repair-second-wave" "expected rc 0"
fi
assert_ok "repair-second-wave-keeps-strict-goal" \
  "$SCRIPT_DIR/../bin/polylane-promptopt.sh" check "$(lane_prompt_get x)"
assert_eq "repair-second-wave-one-ultimate-goal" "1" \
  "$(grep -c '^ULTIMATE-GOAL:' "$(lane_prompt_get x)")"
assert_contains "repair-second-wave-retains-first-reflection" "REPAIR ATTEMPT 1" \
  "$(cat "$(lane_prompt_get x)")"
assert_contains "repair-second-wave-adds-second-reflection" "REPAIR ATTEMPT 2" \
  "$(cat "$(lane_prompt_get x)")"

finish
