#!/usr/bin/env bash
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

AGENT=codex; unset POLYLANE_AGENT_CMD CODEX_PROFILE POLYLANE_CODEX_PROFILE
assert_eq "codex-profile-defaults-lean" "lean" "$(codex_profile_selected)"
assert_contains "lean-adds-ephemeral" "--ephemeral" "$(agent_template)"
assert_contains "lean-ignores-user-config" "--ignore-user-config" "$(agent_template)"

CODEX_PROFILE=user
assert_eq "codex-profile-user-selected" "user" "$(codex_profile_selected)"
if printf '%s' "$(agent_template)" | grep -q -- '--ephemeral\|--ignore-user-config'; then
  fail "user-profile-has-no-lean-flags" "user profile inherited lean flags"
else
  pass "user-profile-has-no-lean-flags"
fi

CODEX_PROFILE=broken
INT_NAME=i INT_MODEL=m INT_BRANCH=b INT_WORKTREE=w
LANE_NAMES=(lane); LANE_MODELS=(m); LANE_BRANCHES=(b); LANE_WORKTREES=(w)
assert_rc "invalid-profile-fails-before-launch" 2 validate_manifest
finish
