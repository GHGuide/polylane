#!/usr/bin/env bash
# Reflexion repair-loop helpers: build_repair_prompt (pure) + the lane prompt /
# repair-count accessors that let a lane respawn with a reflect-then-fix prompt
# before it is marked failed.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

make_tmpdir
seed="$TEST_TMPDIR/x.txt"
printf 'ORIGINAL GOAL: build widget X to DONE' > "$seed"

out=$(build_repair_prompt "$seed" x 2)
assert_contains "repair-keeps-original"    "ORIGINAL GOAL: build widget X" "$out"
assert_contains "repair-attempt-number"    "REPAIR ATTEMPT 2"              "$out"
assert_contains "repair-points-transcript" "docs/lane-logs/x.log"          "$out"
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

finish
