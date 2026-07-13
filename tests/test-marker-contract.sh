#!/usr/bin/env bash
# polylane-markers.sh — canonical wire-format + doc-consistency contract.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
BIN="$(cd "$(dirname "$RUNNER")" && pwd)"
MARK="$BIN/polylane-markers.sh"
REFS="$BIN/../references"

# --- constructor output ------------------------------------------------------
assert_eq "done-nonce"   "STATUS: foo DONE run=r123"        "$("$MARK" done foo r123)"
assert_eq "done-legacy"  "STATUS: foo DONE"                 "$("$MARK" done foo)"
assert_eq "verdict-nonce" "POLYLANE-VERDICT: GO run=r123"   "$("$MARK" verdict GO r123)"
assert_eq "verdict-nogo" "POLYLANE-VERDICT: NO-GO run=r123" "$("$MARK" verdict NO-GO r123)"

# --- run.sh literals still match the helper (the hot-path poll strings) -------
# lane_done builds "STATUS: $name DONE run=$RUN_ID"; assert that literal is present verbatim.
if grep -qF 'STATUS: $name DONE run=$RUN_ID' "$RUNNER"; then pass "runsh-done-literal"
else fail "runsh-done-literal" "lane_done literal drifted from markers"; fi
# parse_verdict's nonce pattern must carry the run= token
grep -q 'POLYLANE-VERDICT:.*run=' "$RUNNER" && pass "runsh-verdict-literal" \
  || fail "runsh-verdict-literal" "parse_verdict pattern drifted"

# --- every reference doc teaches the nonce form (regression guard for the bug) -
out=$("$MARK" check-docs "$REFS" 2>&1) && rc=0 || rc=$?
assert_eq "docs-consistent-rc" "0" "$rc"
if [ "$rc" != "0" ]; then printf '%s\n' "$out"; fi

# --- and prove the check BITES: a drifted temp doc must fail ------------------
make_tmpdir
printf 'write `STATUS: <lane> DONE` on completion.\n' > "$TEST_TMPDIR/bad.md"
assert_fail "docs-drift-detected" "$MARK" check-docs "$TEST_TMPDIR"
finish
