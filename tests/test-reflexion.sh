#!/usr/bin/env bash
# Reflexion repair-loop helpers: build_repair_prompt (pure) + the lane prompt /
# repair-count accessors that let a lane respawn with a reflect-then-fix prompt
# before it is marked failed.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

make_tmpdir
seed="$TEST_TMPDIR/x.txt"
cat > "$seed" <<'EOF'
ULTIMATE-GOAL: ship widget X.
CURRENT-SUBGOAL: repair widget X.
GOAL: build widget X to DONE.
OWN: widget files.
FORBIDDEN: unrelated files.
PREDEFINED-SKILLS: engineering:debug
LANE-SPECIFIC-SKILLS: engineering:debug
Read only the named kit once.
TEST-CADENCE: focused first.
DELEGATION: forbidden.
CHECK-CACHE: use $PWD/.polylane/check-cache/x.
EXTERNAL-EVIDENCE: none.
VERIFY: write evidence then STATUS: x DONE run=repair-run.
EOF
REPO_ROOT="$TEST_TMPDIR/canonical root"

out=$(build_repair_prompt "$seed" x 2)
assert_contains "repair-keeps-original"    "GOAL: build widget X to DONE." "$out"
assert_contains "repair-attempt-number"    "REPAIR ATTEMPT 2"              "$out"
assert_contains "repair-points-canonical-transcript" \
  "$REPO_ROOT/docs/lane-logs/x.log" "$out"
assert_contains "repair-demands-different" "DIFFERENT"                     "$out"
assert_contains "repair-keeps-goal-locked" "locked goal is unchanged"      "$out"
printf '%s\n' "$out" > "$TEST_TMPDIR/x.repair.prompt"
assert_ok "repair-preserves-strict-scalar-contract" \
  "$SCRIPT_DIR/../bin/polylane-promptopt.sh" check "$TEST_TMPDIR/x.repair.prompt"

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

finish
