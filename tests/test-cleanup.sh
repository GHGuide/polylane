#!/usr/bin/env bash
# Cleanup is post-promotion maintenance. An unmerged late lane tip must be kept
# for recovery without aborting the verified run before its report is written.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

command -v git >/dev/null 2>&1 || { pass "cleanup-skipped-no-git"; finish; exit 0; }
. "$RUNNER"

make_tmpdir
TEST_ROOT=$(cd "$TEST_TMPDIR" && pwd -P)
G="$TEST_ROOT/repo"; mkdir -p "$G"
BUILDER_WT="$TEST_ROOT/builder-wt"
INTEGRATOR_WT="$TEST_ROOT/integrator-wt"
setup_log="$TEST_ROOT/setup.log"
setup_rc=0
(
  set -e
  cd "$G"
  git init -q; git config user.email t@t; git config user.name t
  echo base > base.txt; git add base.txt; git commit -qm base
  base_branch=$(git rev-parse --abbrev-ref HEAD)

  git branch lane/builder
  git worktree add -q "$BUILDER_WT" lane/builder
  echo late > "$BUILDER_WT/late.txt"
  git -C "$BUILDER_WT" add late.txt
  git -C "$BUILDER_WT" commit -qm "late unintegrated builder tip"

  git branch lane/integrator "$base_branch"
  git worktree add -q "$INTEGRATOR_WT" lane/integrator
  echo integrated > "$INTEGRATOR_WT/integrated.txt"
  git -C "$INTEGRATOR_WT" add integrated.txt
  git -C "$INTEGRATOR_WT" commit -qm integrated
  git merge -q --ff-only lane/integrator

  mkdir -p .polylane docs
  echo scratch > .polylane/transient
  echo done > docs/status-builder.md
  echo done > docs/status-integrator.md
  git add docs/status-builder.md docs/status-integrator.md
  git commit -qm "runtime status markers"
) >"$setup_log" 2>&1 || setup_rc=$?

if [ "$setup_rc" -ne 0 ]; then
  fail "cleanup-fixture-setup" "git fixture failed: $(tail -n 1 "$setup_log" 2>/dev/null)"
  finish
  exit 1
fi

REPO_ROOT="$G"; DRY_RUN=0; YES=1; TMUX_SESSION="polylane-cleanup-fixture-$$"
LANE_NAMES=(builder)
LANE_WORKTREES=("$BUILDER_WT")
LANE_BRANCHES=(lane/builder)
INT_NAME=integrator
INT_WORKTREE="$INTEGRATOR_WT"
INT_BRANCH=lane/integrator

cleanup_out=""
cleanup_rc=0
cleanup_out=$(( set -e; cd "$G"; cleanup ) 2>&1) || cleanup_rc=$?

assert_eq "cleanup-unmerged-tip-nonfatal" "0" "$cleanup_rc"
assert_ok "cleanup-unmerged-tip-preserved" git -C "$G" show-ref --verify --quiet refs/heads/lane/builder
assert_fail "cleanup-merged-integrator-deleted" git -C "$G" show-ref --verify --quiet refs/heads/lane/integrator
assert_fail "cleanup-builder-worktree-removed" test -e "$BUILDER_WT"
assert_fail "cleanup-integrator-worktree-removed" test -e "$INTEGRATOR_WT"
assert_fail "cleanup-scratch-removed" test -e "$G/.polylane/transient"
assert_contains "cleanup-preservation-explained" "preserving unmerged branch lane/builder" "$cleanup_out"
assert_eq "cleanup-removes-tracked-status-markers" "" "$(git -C "$G" status --porcelain)"
assert_fail "cleanup-builder-status-marker-removed" test -e "$G/docs/status-builder.md"
assert_fail "cleanup-integrator-status-marker-removed" test -e "$G/docs/status-integrator.md"

cleanup_again_rc=0
( set -e; cd "$G"; cleanup ) >/dev/null 2>&1 || cleanup_again_rc=$?
assert_eq "cleanup-post-promotion-recovery-idempotent" "0" "$cleanup_again_rc"
assert_eq "cleanup-recovery-keeps-base-clean" "" "$(git -C "$G" status --porcelain)"

finish
