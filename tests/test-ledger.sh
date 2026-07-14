#!/usr/bin/env bash
# polylane-ledger.sh — record + trend/roi/fit on seeded JSONL, pure numeric asserts.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
LED="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-ledger.sh"

command -v jq >/dev/null 2>&1 || { pass "ledger-skipped-no-jq"; finish; exit 0; }
make_tmpdir
F="$TEST_TMPDIR/ledger.jsonl"

# record appends a well-formed row
"$LED" record --file "$F" --cycle 1 --verdict GO --tokens 1000 --cost 2.50 \
  --subdone 2 --subtotal 6 --nogo 0 --lanes 3 --wall 42 >/dev/null
assert_eq "record-one-row" "1" "$(wc -l < "$F" | tr -d ' ')"
assert_eq "record-cost"    "2.5" "$(jq -r '.cost' "$F" | awk '{printf "%g", $1}')"   # %g: jq 1.7 keeps the 2.50 literal

# second cycle advances subgoals -> IMPROVING, rc 0
"$LED" record --file "$F" --cycle 2 --verdict GO --tokens 900 --cost 2.00 \
  --subdone 4 --subtotal 6 --nogo 0 --lanes 3 --wall 40 >/dev/null
out=$("$LED" trend --file "$F") && rc=0 || rc=$?
assert_contains "trend-improving" "IMPROVING" "$out"
assert_eq       "trend-rc-ok"     "0" "$rc"

# third cycle spends but no progress -> STALL, rc 3
"$LED" record --file "$F" --cycle 3 --verdict NO-GO --tokens 800 --cost 3.00 \
  --subdone 4 --subtotal 6 --nogo 1 --lanes 3 --wall 55 >/dev/null
assert_rc "trend-stall-rc3" "3" "$LED" trend --file "$F"

# roi: cheap history + big warrant -> continue; tiny warrant -> stop:diminishing
out=$("$LED" roi 5 10 100 --file "$F"); assert_contains "roi-continue" "continue" "$out"
assert_rc "roi-stop-rc4" "4" "$LED" roi 1 1000 1 --file "$F"

# fit: budget/cost-per-lane ceilings the request
# history total cost = 7.50 over 9 lane-slots -> ~0.833/lane; budget 2 -> ceil 2
assert_eq "fit-trims" "2" "$("$LED" fit 2 5 --file "$F")"
assert_eq "fit-passthru-when-affordable" "3" "$("$LED" fit 100 3 --file "$F")"
# B8: two rows per cycle (stub + re-stamp) must NOT fool trend — dedup to last-per-cycle
G="$TEST_TMPDIR/dedup.jsonl"
"$LED" record --file "$G" --cycle 1 --cost 1 --subdone 0 --lanes 2 >/dev/null
"$LED" record --file "$G" --cycle 1 --cost 1 --subdone 3 --lanes 2 >/dev/null   # re-stamp
"$LED" record --file "$G" --cycle 2 --cost 5 --subdone 0 --lanes 2 >/dev/null   # stub
"$LED" record --file "$G" --cycle 2 --cost 5 --subdone 3 --lanes 2 >/dev/null   # cost+4, sub flat vs c1
assert_rc "ledger-dedup-stall-rc3" 3 "$LED" trend --file "$G"

# I1: mechanical cap on cycle count + budget
assert_rc "ledger-cap-maxcycles" 5 env POLYLANE_MAX_CYCLES=2 "$LED" cap --file "$G"
assert_ok "ledger-cap-under"           env POLYLANE_MAX_CYCLES=9 "$LED" cap --file "$G"
assert_rc "ledger-cap-budget"     5 env POLYLANE_MAX_CYCLES=9 POLYLANE_BUDGET=3 "$LED" cap --file "$G"

# B2: dotty cost -> 0, row still written (no jq crash); comma-locale handled by LC_ALL=C at source
"$LED" record --file "$G" --cycle 9 --cost 1.2.3 >/dev/null
assert_ok "ledger-dotty-no-crash" test -s "$G"

finish
