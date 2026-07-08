#!/usr/bin/env bash
# promote_to_main: on GO the runner advances the base branch to the integrator's
# OWN branch (which holds base + lanes + evidence). The integrator never touches
# base, so a NO-GO — which never calls promote — leaves base untouched. Verified
# on a throwaway git repo.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

if ! command -v git >/dev/null 2>&1; then pass "promote-skipped-no-git"; finish; exit 0; fi

. "$RUNNER"

make_tmpdir
G="$TEST_TMPDIR/repo"; mkdir -p "$G"
(
  cd "$G"
  git init -q; git config user.email t@t; git config user.name t
  echo base > f; git add f; git commit -qm base
  git branch lane/int
  git checkout -q lane/int
  echo more >> f; git commit -qam lanework
  echo ev > verify.md; git add verify.md; git commit -qm evidence
  git checkout -q "$(git rev-parse --abbrev-ref master 2>/dev/null || echo main)" 2>/dev/null \
    || git checkout -q main 2>/dev/null || git checkout -q master
) >/dev/null 2>&1

BASE=$(cd "$G" && git rev-parse --abbrev-ref HEAD)
REPO_ROOT="$G"; INT_BRANCH="lane/int"; DRY_RUN=0
base_before=$(cd "$G" && git rev-parse HEAD)

# GO path: promote fast-forwards base to the integrator branch
promote_to_main >/dev/null 2>&1
assert_eq "promote-base-eq-int" "$(cd "$G" && git rev-parse lane/int)" "$(cd "$G" && git rev-parse HEAD)"
assert_ok "promote-evidence-on-base" test -f "$G/verify.md"
assert_ok "promote-linear-ff" git -C "$G" merge-base --is-ancestor lane/int HEAD

# dry-run must NOT move base (preview only)
G2="$TEST_TMPDIR/repo2"; cp -R "$G" "$G2"
# reset base to before-promote in the copy
(cd "$G2" && git reset -q --hard "$base_before") >/dev/null 2>&1
REPO_ROOT="$G2"; DRY_RUN=1
promote_to_main >/dev/null 2>&1
assert_eq "promote-dryrun-no-move" "$base_before" "$(cd "$G2" && git rev-parse HEAD)"

finish
