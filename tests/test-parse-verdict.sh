#!/usr/bin/env bash
# parse_verdict FILE -> GO | NO-GO | UNKNOWN (frozen contract: NO-GO wins,
# missing/none defaults UNKNOWN).

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

assert_eq "verdict-go"      "GO"      "$(parse_verdict "$FIXTURES/verdicts/go.md")"
assert_eq "verdict-no-go"   "NO-GO"   "$(parse_verdict "$FIXTURES/verdicts/no-go.md")"
assert_eq "verdict-unknown" "UNKNOWN" "$(parse_verdict "$FIXTURES/verdicts/unknown.md")"
assert_eq "verdict-missing-file" "UNKNOWN" "$(parse_verdict "$FIXTURES/verdicts/does-not-exist.md")"

# NO-GO wins over GO on the deciding (last matching) line
make_tmpdir
printf 'is it a GO? verdict: NO-GO\n' > "$TEST_TMPDIR/mixed.md"
assert_eq "verdict-no-go-wins-same-line" "NO-GO" "$(parse_verdict "$TEST_TMPDIR/mixed.md")"

# GO must be a whole word — "GOING" alone is not a verdict
printf 'GOING great, no verdict word here\n' > "$TEST_TMPDIR/going.md"
assert_eq "verdict-go-word-boundary" "UNKNOWN" "$(parse_verdict "$TEST_TMPDIR/going.md")"

# last matching line decides: earlier NO-GO overridden by later "GO" line
printf 'earlier: NO-GO\nfinal verdict: GO\n' > "$TEST_TMPDIR/last-wins.md"
assert_eq "verdict-last-line-wins" "GO" "$(parse_verdict "$TEST_TMPDIR/last-wins.md")"

finish
