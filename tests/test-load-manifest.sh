#!/usr/bin/env bash
# load_manifest — fixture .polylane/run.json -> globals. Covers every frozen
# manifest key: base, integrator{name,model,branch,worktree,prompt_file,effort},
# lanes[]{...}, available_models, plus prompt anchoring and LANE_POLLSPEC.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

MANIFEST="$FIXTURES/project/.polylane/run.json"
load_manifest

PROJ="$FIXTURES/project"

assert_eq "manifest-base"          "main" "$BASE"
assert_eq "manifest-project-root"  "$PROJ" "$PROJECT_ROOT"

# integrator block
assert_eq "int-name"     "integrator"            "$INT_NAME"
assert_eq "int-model"    "claude-opus-4-8"       "$INT_MODEL"
assert_eq "int-branch"   "lane/integration"      "$INT_BRANCH"
assert_eq "int-worktree" ".polylane/wt/integration" "$INT_WORKTREE"
assert_eq "int-effort"   "high"                  "$INT_EFFORT"
# absolute prompt_file passes through untouched
assert_eq "int-prompt-abs" "/abs/prompts/integrator.txt" "$INT_PROMPT"

# available_models
assert_eq "models-count" "3" "${#AVAILABLE_MODELS[@]}"
assert_eq "models-0" "claude-haiku-4-5" "${AVAILABLE_MODELS[0]}"
assert_eq "models-2" "claude-opus-4-8"  "${AVAILABLE_MODELS[2]}"

# lanes
assert_eq "lanes-count"    "2"     "${#LANE_NAMES[@]}"
assert_eq "lane0-name"     "alpha" "${LANE_NAMES[0]}"
assert_eq "lane1-name"     "beta"  "${LANE_NAMES[1]}"
assert_eq "lane0-model"    "claude-sonnet-5"  "${LANE_MODELS[0]}"
assert_eq "lane1-model"    "claude-haiku-4-5" "${LANE_MODELS[1]}"
assert_eq "lane0-branch"   "lane/alpha" "${LANE_BRANCHES[0]}"
assert_eq "lane0-worktree" ".polylane/wt/alpha" "${LANE_WORKTREES[0]}"

# effort: present -> value; absent -> empty string (optional key contract)
assert_eq "lane0-effort-present" "medium" "${LANE_EFFORTS[0]}"
assert_eq "lane1-effort-absent"  ""       "${LANE_EFFORTS[1]}"

# relative prompt_file anchored at PROJECT_ROOT (absolute after load)
assert_eq "lane0-prompt-anchored" "$PROJ/.polylane/lanes/alpha.txt" "${LANE_PROMPTS[0]}"
assert_eq "lane1-prompt-anchored" "$PROJ/.polylane/lanes/beta.txt"  "${LANE_PROMPTS[1]}"

# poll spec "name:worktree"
assert_eq "lane0-pollspec" "alpha:.polylane/wt/alpha" "${LANE_POLLSPEC[0]}"
assert_eq "lane1-pollspec" "beta:.polylane/wt/beta"   "${LANE_POLLSPEC[1]}"

# effort null in JSON also maps to "" (// "" contract)
make_tmpdir
sed 's/"effort": "high"/"effort": null/' "$MANIFEST" > "$TEST_TMPDIR/run.json"
MANIFEST="$TEST_TMPDIR/run.json"
load_manifest
assert_eq "int-effort-null-maps-empty" "" "$INT_EFFORT"

# manifest without available_models -> empty array
sed '/available_models/d' "$FIXTURES/project/.polylane/run.json" > "$TEST_TMPDIR/run2.json"
MANIFEST="$TEST_TMPDIR/run2.json"
load_manifest
assert_eq "models-absent-empty" "0" "${#AVAILABLE_MODELS[@]}"

finish
