#!/usr/bin/env bash
# polylane-select.sh — best-of-N winner selection (score desc, loc asc, empty fallback).
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$(cd "$(dirname "$RUNNER")" && pwd)/polylane-select.sh"

make_tmpdir
printf 'POLYLANE-SCORE: 3\n' > "$TEST_TMPDIR/a"
printf 'POLYLANE-SCORE: 7\n' > "$TEST_TMPDIR/b"
printf 'POLYLANE-SCORE: 5\n' > "$TEST_TMPDIR/c"
assert_eq "select-highest" "vb" "$(pick_best_attempt "va|$TEST_TMPDIR/a|100" "vb|$TEST_TMPDIR/b|100" "vc|$TEST_TMPDIR/c|100")"
printf 'POLYLANE-SCORE: 7\n' > "$TEST_TMPDIR/d"
assert_eq "select-tie-fewer-loc" "vd" "$(pick_best_attempt "vb|$TEST_TMPDIR/b|200" "vd|$TEST_TMPDIR/d|50")"
printf 'no sentinel here\n' > "$TEST_TMPDIR/e"
assert_eq "select-garbled-never-wins" "vb" "$(pick_best_attempt "ve|$TEST_TMPDIR/e|10" "vb|$TEST_TMPDIR/b|999")"
assert_eq "select-all-unscored-empty" "" "$(pick_best_attempt "ve|$TEST_TMPDIR/e|10" "vf|$TEST_TMPDIR/missing|10")"
finish
