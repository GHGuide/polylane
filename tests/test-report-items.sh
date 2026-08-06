#!/usr/bin/env bash
# polylane-report-items.sh — emits only explicit current-run action bullets.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

REPORT_ITEMS="$(cd "$(dirname "$0")/../bin" && pwd)/polylane-report-items.sh"

make_tmpdir
cat > "$TEST_TMPDIR/verify-alpha.md" <<'EOF'
## Deferred
- Decide schema ownership
  after the next design review.
- STATUS: alpha DONE run=cycle-5
- POLYLANE-VERDICT: NO-GO run=cycle-5
- `tests/run.sh`
- $ git status
- git status --short
-

## Notes
- This noisy prose is not an item.

## External follow-up
- Near-match headings are not items.
EOF
cat > "$TEST_TMPDIR/verify-beta.md" <<'EOF'
## External
- Obtain production credentials

## Open items
- Re-run the canary

## DEFERRED
- Case-mismatched headings are not items.
EOF
cat > "$TEST_TMPDIR/verify-historical.md" <<'EOF'
## Deferred
- Historical item must not leak
EOF

expected='- Decide schema ownership
- Obtain production credentials
- Re-run the canary'
actual=$("$REPORT_ITEMS" "$TEST_TMPDIR/verify-alpha.md" "$TEST_TMPDIR/verify-beta.md")
assert_eq "cycle-5-pollution-excluded" "$expected" "$actual"

finish
