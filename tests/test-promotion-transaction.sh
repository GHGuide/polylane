#!/usr/bin/env bash
# shellcheck disable=SC1090,SC2034 # sourced runner consumes fixture globals
# Promotion is a transaction: runner-owned durable state may be committed
# narrowly before the verified merge, while user work is never staged or merged.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

promotion_fixture() {
  make_tmpdir
  REPO_ROOT="$TEST_TMPDIR/repo"
  PROJECT_ROOT="$REPO_ROOT"
  BASE=main
  INT_BRANCH=lane/integrator
  git init -q "$REPO_ROOT"
  git -C "$REPO_ROOT" config user.email polylane-test@example.invalid
  git -C "$REPO_ROOT" config user.name 'Polylane Test'
  git -C "$REPO_ROOT" checkout -q -b "$BASE"
  mkdir -p "$REPO_ROOT/docs/polylane/workers"
  printf 'base\n' > "$REPO_ROOT/README.md"
  printf '{"cycle":13}\n' > "$REPO_ROOT/docs/polylane/max-state.json"
  printf '{"seq":1}\n' > "$REPO_ROOT/docs/polylane/workers/history.jsonl"
  git -C "$REPO_ROOT" add README.md docs/polylane/max-state.json docs/polylane/workers/history.jsonl
  git -C "$REPO_ROOT" commit -qm base
  git -C "$REPO_ROOT" checkout -q -b "$INT_BRANCH"
  printf 'verified product\n' > "$REPO_ROOT/product.txt"
  git -C "$REPO_ROOT" add product.txt
  git -C "$REPO_ROOT" commit -qm verified
  git -C "$REPO_ROOT" checkout -q "$BASE"
}

# Cycle 13: pre-promotion telemetry/history writes dirtied an otherwise valid
# base, so git refused the verified merge. Those exact runner-owned paths are
# safe to stage explicitly and must not require staging the whole worktree.
promotion_fixture
printf '{"cycle":14}\n' > "$REPO_ROOT/docs/polylane/max-state.json"
printf '{"seq":2}\n' >> "$REPO_ROOT/docs/polylane/workers/history.jsonl"
promote_to_main; runner_owned_rc=$?
assert_eq "runner-owned-dirt-promotes" "0" "$runner_owned_rc"
assert_ok "runner-owned-dirt-merged-verified-tip" git -C "$REPO_ROOT" merge-base --is-ancestor "$INT_BRANCH" HEAD
assert_eq "runner-owned-dirt-clean-after-transaction" "" "$(git -C "$REPO_ROOT" status --porcelain)"
assert_contains "runner-owned-dirt-committed-narrowly" "polylane: record runner state before promotion" "$(git -C "$REPO_ROOT" log --format=%s -n 2)"

# A user edit is not runner state. It blocks promotion before the base moves,
# remains present and unstaged, and leaves the verified integration branch for
# a later deliberate resolution.
promotion_fixture
before=$(git -C "$REPO_ROOT" rev-parse HEAD)
printf 'user edit\n' >> "$REPO_ROOT/README.md"
promote_to_main; user_dirt_rc=$?
assert_eq "user-dirt-blocks-promotion" "1" "$user_dirt_rc"
assert_eq "user-dirt-base-unchanged" "$before" "$(git -C "$REPO_ROOT" rev-parse HEAD)"
assert_contains "user-dirt-survives-untouched" "user edit" "$(cat "$REPO_ROOT/README.md")"
assert_eq "user-dirt-not-implicitly-staged" " M README.md" "$(git -C "$REPO_ROOT" status --porcelain)"

# A non-fast-forward conflict is also a failed transaction: the base ref and
# index return to their pre-attempt state, and cleanup remains ineligible.
promotion_fixture
git -C "$REPO_ROOT" checkout -q "$INT_BRANCH"
printf 'integrator edit\n' > "$REPO_ROOT/README.md"
git -C "$REPO_ROOT" commit -am 'integrator conflict' -q
git -C "$REPO_ROOT" checkout -q "$BASE"
printf 'base edit\n' > "$REPO_ROOT/README.md"
git -C "$REPO_ROOT" commit -am 'base conflict' -q
conflict_before=$(git -C "$REPO_ROOT" rev-parse HEAD)
promote_to_main; conflict_rc=$?
assert_eq "merge-conflict-fails-transaction" "1" "$conflict_rc"
assert_eq "merge-conflict-base-ref-unchanged" "$conflict_before" "$(git -C "$REPO_ROOT" rev-parse HEAD)"
assert_eq "merge-conflict-index-clean" "" "$(git -C "$REPO_ROOT" ls-files --unmerged)"
assert_eq "merge-conflict-state-failed" "failed" "${PROMOTION_STATE:-}"

finish
