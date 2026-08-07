#!/usr/bin/env bash
# polylane-seams.sh — DOM-id dangler detection with dynamic-id false-positive guard.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
SEAMS="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-seams.sh"

make_tmpdir
printf "const b=document.getElementById('export-btn');\nconst d=document.getElementById('btn-'+idx);\nconst q=document.querySelector('#panel');\n" > "$TEST_TMPDIR/app.js"
printf '<div id="main"></div>\n<div id="panel"></div>\n' > "$TEST_TMPDIR/index.html"
mkdir -p "$TEST_TMPDIR/node_modules/pkg" "$TEST_TMPDIR/.next-cap/static" "$TEST_TMPDIR/out-ios/static"
printf "document.getElementById('framework-owned');\n" > "$TEST_TMPDIR/node_modules/pkg/index.js"
printf "document.getElementById('generated-next');\n" > "$TEST_TMPDIR/.next-cap/static/chunk.js"
printf "document.getElementById('generated-export');\n" > "$TEST_TMPDIR/out-ios/static/chunk.js"

out=$("$SEAMS" scan "$TEST_TMPDIR" 2>&1) && rc=0 || rc=$?
assert_contains "seam-flags-missing"   "SEAM-DANGLING: dom-id export-btn" "$out"
assert_eq       "seam-nonzero-on-dangler" "1" "$rc"
# dynamic id 'btn-'+idx must NOT be flagged (false-positive guard)
if printf '%s\n' "$out" | grep -q 'btn-'; then fail "seam-ignores-dynamic" "dynamic id flagged"; else pass "seam-ignores-dynamic"; fi
# dependency and generated-framework IDs must not poison the source seam gate
if printf '%s\n' "$out" | grep -Eq 'framework-owned|generated-next|generated-export'; then fail "seam-ignores-derived" "derived id flagged"; else pass "seam-ignores-derived"; fi
# querySelector('#panel') with a producer is clean
if printf '%s\n' "$out" | grep -q 'panel'; then fail "seam-matched-clean" "matched id flagged"; else pass "seam-matched-clean"; fi

# add the missing producer -> clean, exit 0
printf '<button id="export-btn">x</button>\n' >> "$TEST_TMPDIR/index.html"
assert_ok "seam-clean-after-fix" "$SEAMS" scan "$TEST_TMPDIR"
finish
