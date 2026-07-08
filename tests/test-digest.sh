#!/usr/bin/env bash
# polylane-digest.sh <baseline-ref> [repo-root] — read-only change-inventory
# dumper. Exercised as a CLI (it runs on invocation), asserting output + exit
# codes. bash-3.2 safe.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
DIGEST="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-digest.sh"

# --- build a throwaway git repo fixture under $TEST_TMPDIR --------------------
make_tmpdir
REPO="$TEST_TMPDIR/repo"
mkdir -p "$REPO/docs"

git -C "$REPO" init -q
git -C "$REPO" config user.email test@polylane.test
git -C "$REPO" config user.name  "Polylane Test"
git -C "$REPO" config commit.gpgsign false

# baseline commit — captured as the <baseline-ref>
printf 'seed\n' > "$REPO/base.txt"
git -C "$REPO" add base.txt
git -C "$REPO" commit -qm "base commit"
BASELINE=$(git -C "$REPO" rev-parse HEAD)

# a later commit that adds a brand-new file (feeds Commits + diffstat + New files)
printf 'hello world\n' > "$REPO/added.txt"
git -C "$REPO" add added.txt
git -C "$REPO" commit -qm "add feature xyz"

# a per-lane verify doc the digest is meant to summarise (small: <=3 lines)
printf 'STATUS: foo DONE\nPASS added widget\n' > "$REPO/docs/verify-foo.md"
git -C "$REPO" add docs/verify-foo.md
git -C "$REPO" commit -qm "verify doc"

# --- one success run captured once, four content behaviors asserted on it -----
OUT=$("$DIGEST" "$BASELINE" "$REPO" 2>&1)

assert_contains "digest-commits"         "add feature xyz"           "$OUT"
assert_contains "digest-diffstat"        "insertion"                 "$OUT"
assert_contains "digest-new-files"       "+ added.txt"               "$OUT"
assert_contains "digest-verify-summary"  "### docs/verify-foo.md"    "$OUT"

# --- exit-code behaviors -----------------------------------------------------
# no args -> usage on stderr, exit 2
assert_rc "digest-usage-exit-2" 2 "$DIGEST"

# a ref git cannot resolve -> exit 1
assert_rc "digest-unknown-ref-exit-1" 1 "$DIGEST" "no-such-ref-xyz" "$REPO"

finish
