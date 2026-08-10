#!/usr/bin/env bash
# A finished lane may commit the exact nonce-bound DONE line under one wrong
# status filename. The runner may repair that single, unambiguous rename before
# charging a restart; every stale, dirty, ambiguous, or uncommitted case stays
# rejected.
# shellcheck disable=SC1090,SC2034
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

make_tmpdir
RUN_ID=normalize-run
ORCHESTRATION_CONTRACT=2
BASE=main
MANIFEST="$TEST_TMPDIR/manifest.json"
printf '%s\n' '{"lanes":[{"name":"restart-accounting-audit","own_globs":["docs/status-restart-accounting-audit.md"]}]}' > "$MANIFEST"

new_repo() {
  local dir="$1"
  mkdir -p "$dir/docs"
  git -C "$dir" init -q -b main
  git -C "$dir" config user.email test@example.invalid
  git -C "$dir" config user.name test
  printf 'base\n' > "$dir/base.txt"
  git -C "$dir" add base.txt
  git -C "$dir" commit -qm base
  BASE=$(git -C "$dir" rev-parse HEAD)
}

commit_marker() {
  local dir="$1" rel="$2" line="$3"
  printf '%s\n' "$line" > "$dir/$rel"
  git -C "$dir" add "$rel"
  git -C "$dir" commit -qm marker
}

GOOD="$TEST_TMPDIR/good"
new_repo "$GOOD"
commit_marker "$GOOD" docs/status-audit.md \
  'STATUS: restart-accounting-audit DONE run=normalize-run'
assert_ok "normalize-exact-committed-near-miss" \
  normalize_status_marker "$GOOD" restart-accounting-audit
assert_ok "normalize-writes-canonical-marker" \
  test -f "$GOOD/docs/status-restart-accounting-audit.md"
assert_fail "normalize-removes-near-miss-path" \
  test -e "$GOOD/docs/status-audit.md"
INT_NAME=integrator
LANE_NAMES=(restart-accounting-audit)
LANE_PROMPTS=("")
REPO_ROOT="$GOOD"
assert_ok "normalize-result-satisfies-done-contract" \
  lane_done "$GOOD" restart-accounting-audit
assert_contains "normalize-commit-is-auditable" \
  "polylane: normalize status marker for restart-accounting-audit" \
  "$(git -C "$GOOD" log -1 --format=%s)"
assert_eq "normalize-leaves-clean-tree" "" \
  "$(git -C "$GOOD" status --porcelain --untracked-files=all)"

STALE="$TEST_TMPDIR/stale"
new_repo "$STALE"
commit_marker "$STALE" docs/status-short.md \
  'STATUS: restart-accounting-audit DONE run=old-run'
assert_fail "normalize-rejects-stale-nonce" \
  normalize_status_marker "$STALE" restart-accounting-audit
assert_fail "normalize-stale-does-not-create-canonical" \
  test -e "$STALE/docs/status-restart-accounting-audit.md"

FOREIGN="$TEST_TMPDIR/foreign"
new_repo "$FOREIGN"
commit_marker "$FOREIGN" docs/status-short.md \
  'STATUS: another-lane DONE run=normalize-run'
assert_fail "normalize-rejects-foreign-lane" \
  normalize_status_marker "$FOREIGN" restart-accounting-audit

UNCOMMITTED="$TEST_TMPDIR/uncommitted"
new_repo "$UNCOMMITTED"
printf '%s\n' 'STATUS: restart-accounting-audit DONE run=normalize-run' \
  > "$UNCOMMITTED/docs/status-short.md"
assert_fail "normalize-rejects-uncommitted-candidate" \
  normalize_status_marker "$UNCOMMITTED" restart-accounting-audit

AMBIGUOUS="$TEST_TMPDIR/ambiguous"
new_repo "$AMBIGUOUS"
printf '%s\n' 'STATUS: restart-accounting-audit DONE run=normalize-run' \
  > "$AMBIGUOUS/docs/status-one.md"
cp "$AMBIGUOUS/docs/status-one.md" "$AMBIGUOUS/docs/status-two.md"
git -C "$AMBIGUOUS" add docs/status-one.md docs/status-two.md
git -C "$AMBIGUOUS" commit -qm markers
assert_fail "normalize-rejects-ambiguous-candidates" \
  normalize_status_marker "$AMBIGUOUS" restart-accounting-audit

DIRTY="$TEST_TMPDIR/dirty"
new_repo "$DIRTY"
printf 'tracked\n' > "$DIRTY/tracked.txt"
printf '%s\n' 'STATUS: restart-accounting-audit DONE run=normalize-run' \
  > "$DIRTY/docs/status-short.md"
git -C "$DIRTY" add tracked.txt docs/status-short.md
git -C "$DIRTY" commit -qm marker
printf 'dirty\n' >> "$DIRTY/tracked.txt"
assert_fail "normalize-rejects-dirty-tracked-tree" \
  normalize_status_marker "$DIRTY" restart-accounting-audit

SYMLINK="$TEST_TMPDIR/symlink"
new_repo "$SYMLINK"
printf '%s\n' 'STATUS: restart-accounting-audit DONE run=normalize-run' \
  > "$SYMLINK/target.txt"
ln -s ../target.txt "$SYMLINK/docs/status-short.md"
git -C "$SYMLINK" add target.txt docs/status-short.md
git -C "$SYMLINK" commit -qm marker
assert_fail "normalize-rejects-symlink-candidate" \
  normalize_status_marker "$SYMLINK" restart-accounting-audit

# Scope does not become a broad status-file exemption: an ordinary committed
# out-of-scope file remains blocked even when the runner can prove its own
# subsequent marker rename.
EXTRA="$TEST_TMPDIR/extra"
new_repo "$EXTRA"
printf '%s\n' 'STATUS: restart-accounting-audit DONE run=normalize-run' \
  > "$EXTRA/docs/status-short.md"
printf 'outside\n' > "$EXTRA/outside.txt"
git -C "$EXTRA" add docs/status-short.md outside.txt
git -C "$EXTRA" commit -qm marker-and-extra
assert_fail "normalize-rejects-extra-committed-path-from-completion" \
  normalize_status_marker "$EXTRA" restart-accounting-audit
assert_fail "normalize-extra-path-remains-out-of-scope" \
  lane_done "$EXTRA" restart-accounting-audit

# A hand-authored rename cannot claim the runner's narrow repair allowance.
FABRICATED="$TEST_TMPDIR/fabricated"
new_repo "$FABRICATED"
commit_marker "$FABRICATED" docs/status-short.md \
  'STATUS: restart-accounting-audit DONE run=normalize-run'
git -C "$FABRICATED" mv docs/status-short.md docs/status-restart-accounting-audit.md
git -C "$FABRICATED" commit -qm 'manual marker rename'
assert_fail "normalize-scope-rejects-fabricated-rename-commit" \
  lane_done "$FABRICATED" restart-accounting-audit

# Integration seam: a dead worker with the one safe near-miss is normalized
# before retry accounting and before respawn_lane can spend another model turn.
HEALTH="$TEST_TMPDIR/health"
new_repo "$HEALTH"
commit_marker "$HEALTH" docs/status-short.md \
  'STATUS: restart-accounting-audit DONE run=normalize-run'
REPO_ROOT="$HEALTH"
LANE_NAMES=(restart-accounting-audit)
LANE_WORKTREES=("$HEALTH")
LANE_PANE_IDX=(0)
LANE_PROMPTS=("")
LANE_RETRIES=(0)
FAILED_LANES=""
STALLED_LANES=""
RESPAWNS=0
resolve_stalls() { :; }
pane_for_worktree() { return 1; }
pane_exists() { return 0; }
material_progress_stalled() { return 1; }
pane_retryable_error() { return 1; }
pane_dead() { return 0; }
pane_wedged() { return 1; }
respawn_lane() { RESPAWNS=$((RESPAWNS + 1)); }
assert_ok "normalize-health-check-completes-without-restart" \
  health_check "restart-accounting-audit:$HEALTH"
assert_ok "normalize-health-created-canonical-marker" \
  lane_done "$HEALTH" restart-accounting-audit
assert_eq "normalize-health-charges-zero-retries" "0" "${LANE_RETRIES[0]:-0}"
assert_eq "normalize-health-spawns-zero-workers" "0" "$RESPAWNS"

finish
