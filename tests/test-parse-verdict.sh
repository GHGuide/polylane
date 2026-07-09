#!/usr/bin/env bash
# parse_verdict FILE -> GO | NO-GO | UNKNOWN. FROZEN FAIL-SAFE contract:
#   * ONLY a `POLYLANE-VERDICT: GO|NO-GO` sentinel on its OWN line counts.
#   * ANY NO-GO sentinel => NO-GO, regardless of order (a later GO can't override).
#   * No sentinel (prose, crash, wrong format, missing file) => UNKNOWN — never a
#     prose-guessed GO, which risked merging unverified work.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

assert_eq "verdict-go"      "GO"      "$(parse_verdict "$FIXTURES/verdicts/go.md")"
assert_eq "verdict-no-go"   "NO-GO"   "$(parse_verdict "$FIXTURES/verdicts/no-go.md")"
assert_eq "verdict-unknown" "UNKNOWN" "$(parse_verdict "$FIXTURES/verdicts/unknown.md")"
assert_eq "verdict-missing-file" "UNKNOWN" "$(parse_verdict "$FIXTURES/verdicts/does-not-exist.md")"

make_tmpdir

# SAFETY: prose that merely says GO — NO sentinel — must NOT be a GO.
printf 'we should GO with this, looks great\n' > "$TEST_TMPDIR/prose-go.md"
assert_eq "verdict-prose-go-is-unknown" "UNKNOWN" "$(parse_verdict "$TEST_TMPDIR/prose-go.md")"

# SAFETY: sentinel must be on its OWN line — mid-line mention doesn't count.
printf 'text POLYLANE-VERDICT: GO more text\n' > "$TEST_TMPDIR/midline.md"
assert_eq "verdict-midline-is-unknown" "UNKNOWN" "$(parse_verdict "$TEST_TMPDIR/midline.md")"

# FAIL-SAFE: any NO-GO sentinel wins, EITHER order.
printf 'POLYLANE-VERDICT: GO\nPOLYLANE-VERDICT: NO-GO\n' > "$TEST_TMPDIR/go-then-nogo.md"
assert_eq "verdict-nogo-wins-after"  "NO-GO" "$(parse_verdict "$TEST_TMPDIR/go-then-nogo.md")"
printf 'POLYLANE-VERDICT: NO-GO\nPOLYLANE-VERDICT: GO\n' > "$TEST_TMPDIR/nogo-then-go.md"
assert_eq "verdict-nogo-wins-before" "NO-GO" "$(parse_verdict "$TEST_TMPDIR/nogo-then-go.md")"

# sentinel is authoritative over surrounding prose, both directions
printf 'discussion mentions NO-GO risks everywhere\nPOLYLANE-VERDICT: GO\n' > "$TEST_TMPDIR/sentinel-go.md"
assert_eq "verdict-sentinel-go"   "GO"    "$(parse_verdict "$TEST_TMPDIR/sentinel-go.md")"
printf 'everything is a GO, great GO, GO GO\nPOLYLANE-VERDICT: NO-GO\n' > "$TEST_TMPDIR/sentinel-nogo.md"
assert_eq "verdict-sentinel-nogo" "NO-GO" "$(parse_verdict "$TEST_TMPDIR/sentinel-nogo.md")"

# leading whitespace + trailing spaces on the sentinel line are tolerated
printf '   POLYLANE-VERDICT: GO   \n' > "$TEST_TMPDIR/ws.md"
assert_eq "verdict-whitespace-ok" "GO" "$(parse_verdict "$TEST_TMPDIR/ws.md")"

finish
