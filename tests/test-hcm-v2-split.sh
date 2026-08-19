#!/usr/bin/env bash
# test-hcm-v2-split.sh — the frozen HCM-v2 target-matched split binding.
#
# `bin/polylane-taste-study.sh hcm-split SPLIT` must bind a produced split to the
# frozen `source_calibration.hcm_v2` block of CONTRACT-LOCK.v3.json: 320 natural
# pairs (120 development / 40 validation / 160 confirmatory), 32 excluded anchors
# disjoint from the natural set, a self-consistent canonical digest, and a digest
# equal to the frozen `split_sha256`.
#
# A produced split whose digest differs from the lock is a HARD FAILURE (non-zero
# exit, NOT-BOUND status) and never a warning.  No synthetic split can hash to the
# frozen value — the real HCM-v2 corpus is external evidence (m32.8a), so the
# positive path stops exactly at the lock gate and the tests prove every earlier
# gate passed by asserting those codes are ABSENT.
#
# Bash 3.2 + jq.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STUDY="$ROOT/bin/polylane-taste-study.sh"
LOCK="$ROOT/docs/polylane/taste-certification/contracts/CONTRACT-LOCK.v3.json"

if ! command -v jq >/dev/null 2>&1; then
  pass "hcm-v2-split-skipped-no-jq"; finish; exit 0
fi

make_tmpdir
W="$TEST_TMPDIR"

# --- the frozen numbers this lane binds -------------------------------------
# Drift guard: these literals mirror the contract lock.  If the lock changes,
# these assertions fail first and loudly, so no inlined number can silently rot.
lockv() { jq -r "$1" "$LOCK"; }
assert_eq "lock-natural-total-320"        320 "$(lockv '.source_calibration.hcm_v2.natural_pairs.total')"
assert_eq "lock-development-120"          120 "$(lockv '.source_calibration.hcm_v2.natural_pairs.development')"
assert_eq "lock-validation-40"             40 "$(lockv '.source_calibration.hcm_v2.natural_pairs.validation')"
assert_eq "lock-confirmatory-160"         160 "$(lockv '.source_calibration.hcm_v2.natural_pairs.confirmatory')"
assert_eq "lock-anchors-excluded-32"       32 "$(lockv '.source_calibration.hcm_v2.anchors_excluded')"
assert_eq "lock-source-id-hcm-v2"    "HCM-v2" "$(lockv '.source_calibration.hcm_v2.source_id')"
assert_eq "lock-split-sha256" \
  5f24bec2b38727bb2d53611749fde593ee2d8c47cf7fc205deefe786cf0a2031 \
  "$(lockv '.source_calibration.hcm_v2.split_sha256')"
assert_eq "lock-status-external-evidence-open" \
  "EXTERNAL-EVIDENCE-OPEN" "$(lockv '.source_calibration.hcm_v2.status')"

# --- fixtures ---------------------------------------------------------------

# canon SPLIT — the documented canonical digest, reimplemented here so fixtures
# can be made self-consistent without trusting the code under test.
canon() {
  jq -r '"hcm-v2-split/v1",
         (.anchors | sort | .[] | "anchor\t" + .),
         (.assignments | sort_by(.pair_id) | .[] | "pair\t" + .pair_id + "\t" + .stratum)' "$1" |
    shasum -a 256 | awk '{print $1}'
}

# mk_split OUT [JQ_MUTATION] — a structurally faithful 320/32 split, mutated,
# then re-sealed with its own recomputed digest so each test isolates one defect.
mk_split() {
  local out="$1" mutation="${2:-.}"
  jq -n '
    def pad4: ("0000" + tostring) | .[-4:];
    {schema_version: "hcm-v2-split/v1",
     source_id: "HCM-v2",
     anchors: [range(32) | "hcm-v2-a" + ((. + 1) | pad4)],
     natural_pairs: {total: 320, development: 120, validation: 40, confirmatory: 160},
     assignments: [range(320) |
       {pair_id: ("hcm-v2-n" + ((. + 1) | pad4)),
        stratum: (if . < 120 then "development" elif . < 160 then "validation"
                  else "confirmatory" end)}],
     split_sha256: "0000000000000000000000000000000000000000000000000000000000000000"}' |
    jq -c "$mutation" >"$out"
  jq -c --arg s "$(canon "$out")" '.split_sha256 = $s' "$out" >"$out.sealed"
  mv -f "$out.sealed" "$out"
}

# run_split SPLIT — captures combined output in $OUT and exit code in $RC.
run_split() { OUT=$("$STUDY" hcm-split "$1" 2>&1); RC=$?; return 0; }

# --- the canonical digest is content-addressed, not order-dependent ----------
mk_split "$W/base.json"
mk_split "$W/shuffled.json" '.assignments |= reverse | .anchors |= reverse'
D1=$("$STUDY" hcm-split-digest "$W/base.json" 2>/dev/null)
D2=$("$STUDY" hcm-split-digest "$W/shuffled.json" 2>/dev/null)
assert_eq "digest-matches-documented-canonicalization" "$(canon "$W/base.json")" "$D1"
assert_eq "digest-is-order-independent" "$D1" "$D2"

# --- a faithful split still fails, and ONLY at the frozen lock gate ----------
run_split "$W/base.json"
assert_eq "faithful-split-is-hard-failure-rc1" 1 "$RC"
assert_contains "faithful-split-not-bound" "SPLIT-NOT-BOUND" "$OUT"
assert_contains "faithful-split-blocked-by-lock" "HCM_SPLIT_LOCK_MISMATCH" "$OUT"
# every earlier gate passed — proven by the absence of their codes
for code in HCM_SPLIT_INVALID HCM_SPLIT_TOTAL HCM_SPLIT_STRATUM_COUNT \
            HCM_SPLIT_DUPLICATE_PAIR HCM_SPLIT_ANCHOR_COUNT HCM_SPLIT_ANCHOR_OVERLAP \
            HCM_SPLIT_DIGEST_MISMATCH HCM_LOCK_INCONSISTENT HCM_LOCK_UNREADABLE; do
  if printf '%s' "$OUT" | grep -qF -- "$code"; then
    fail "faithful-split-clears-$code" "unexpected code in [$OUT]"
  else
    pass "faithful-split-clears-$code"
  fi
done

# --- a produced split may never claim a digest it does not have --------------
jq -c '.split_sha256 = "1111111111111111111111111111111111111111111111111111111111111111"' \
  "$W/base.json" >"$W/lying.json"
run_split "$W/lying.json"
assert_eq "lying-digest-rc1" 1 "$RC"
assert_contains "lying-digest-code" "HCM_SPLIT_DIGEST_MISMATCH" "$OUT"

# --- stratum counts are frozen ----------------------------------------------
mk_split "$W/stratum.json" \
  '(.assignments[119].stratum) = "confirmatory" | .natural_pairs.development = 119 | .natural_pairs.confirmatory = 161'
run_split "$W/stratum.json"
assert_eq "stratum-drift-rc1" 1 "$RC"
assert_contains "stratum-drift-code" "HCM_SPLIT_STRATUM_COUNT" "$OUT"

# --- the total is frozen at 320 ---------------------------------------------
mk_split "$W/total.json" '.assignments |= .[0:319] | .natural_pairs.total = 319'
run_split "$W/total.json"
assert_eq "total-drift-rc1" 1 "$RC"
assert_contains "total-drift-code" "HCM_SPLIT_TOTAL" "$OUT"

# --- no pair may be assigned to two strata ----------------------------------
mk_split "$W/dupe.json" '(.assignments[319].pair_id) = (.assignments[0].pair_id)'
run_split "$W/dupe.json"
assert_eq "duplicate-pair-rc1" 1 "$RC"
assert_contains "duplicate-pair-code" "HCM_SPLIT_DUPLICATE_PAIR" "$OUT"

# --- exactly 32 anchors are excluded ----------------------------------------
mk_split "$W/anchors.json" '.anchors |= .[0:31]'
run_split "$W/anchors.json"
assert_eq "anchor-count-rc1" 1 "$RC"
assert_contains "anchor-count-code" "HCM_SPLIT_ANCHOR_COUNT" "$OUT"

# --- an excluded anchor may never re-enter the natural set ------------------
mk_split "$W/overlap.json" '(.anchors[0]) = (.assignments[0].pair_id)'
run_split "$W/overlap.json"
assert_eq "anchor-overlap-rc1" 1 "$RC"
assert_contains "anchor-overlap-code" "HCM_SPLIT_ANCHOR_OVERLAP" "$OUT"

# --- malformed input fails closed -------------------------------------------
mk_split "$W/badschema.json" '.schema_version = "hcm-v2-split/v9"'
run_split "$W/badschema.json"
assert_eq "bad-schema-rc1" 1 "$RC"
assert_contains "bad-schema-code" "HCM_SPLIT_INVALID" "$OUT"

printf 'not json\n' >"$W/notjson.json"
run_split "$W/notjson.json"
assert_eq "non-json-rc1" 1 "$RC"
assert_contains "non-json-code" "HCM_SPLIT_INVALID" "$OUT"

run_split "$W/absent.json"
assert_eq "missing-file-rc1" 1 "$RC"
assert_contains "missing-file-code" "HCM_SPLIT_INVALID" "$OUT"

# --- the external boundary: no prohibited claim is reachable ----------------
ALL=''
for f in base lying stratum total dupe anchors overlap badschema notjson; do
  run_split "$W/$f.json"
  ALL="$ALL$OUT"
done
for banned in TASTE-CERTIFIED HUMAN_CERTIFIED human_certified SPLIT-BOUND WARN; do
  if printf '%s' "$ALL" | grep -qF -- "$banned"; then
    fail "no-prohibited-output-$banned" "split output leaked [$banned]"
  else
    pass "no-prohibited-output-$banned"
  fi
done

finish
