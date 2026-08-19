#!/usr/bin/env bash
# test-hcm-v2-exposure.sh — the frozen HCM-v2 stimulus exposure rules.
#
# `bin/polylane-taste-study.sh hcm-exposure PLAN [OTHER_PLAN]` must bind an
# exposure ALLOCATION PLAN (who would be shown which pair, at which viewport) to
# the frozen `source_calibration.hcm_v2` block of CONTRACT-LOCK.v3.json:
#
#   target_users : viewports exactly {1440x900, 390x844}; <=8 natural pairs and
#                  <=2 anchors per participant; pair_repeat_exposures 0;
#                  80 judgments per natural pair; >=3200 participants
#   designers    : <=40 pairs per designer; 12 judgments per pair;
#                  >=96 credentialed designers; ballots separate from target users
#
# A plan is an allocation, never a result: it carries no judgment, no consent, no
# recruited human.  Every violation is a hard failure (non-zero exit,
# EXPOSURE-NOT-BOUND), never a warning.
#
# Bash 3.2 + jq.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STUDY="$ROOT/bin/polylane-taste-study.sh"
LOCK="$ROOT/docs/polylane/taste-certification/contracts/CONTRACT-LOCK.v3.json"

if ! command -v jq >/dev/null 2>&1; then
  pass "hcm-v2-exposure-skipped-no-jq"; finish; exit 0
fi

make_tmpdir
W="$TEST_TMPDIR"

# --- the frozen numbers this lane binds -------------------------------------
# Drift guard: if the lock moves, these fail first so no inlined number rots.
lockv() { jq -r "$1" "$LOCK"; }
assert_eq "lock-viewports" '["1440x900","390x844"]' \
  "$(jq -c '.source_calibration.hcm_v2.target_users.viewports' "$LOCK")"
assert_eq "lock-max-natural-pairs-per-participant" 8 \
  "$(lockv '.source_calibration.hcm_v2.target_users.max_natural_pairs_per_participant')"
assert_eq "lock-max-anchors-per-participant" 2 \
  "$(lockv '.source_calibration.hcm_v2.target_users.max_anchors_per_participant')"
assert_eq "lock-pair-repeat-exposures-0" 0 \
  "$(lockv '.source_calibration.hcm_v2.target_users.pair_repeat_exposures')"
assert_eq "lock-target-judgments-per-pair-80" 80 \
  "$(lockv '.source_calibration.hcm_v2.target_users.judgments_per_pair')"
assert_eq "lock-min-completed-participants-3200" 3200 \
  "$(lockv '.source_calibration.hcm_v2.target_users.min_completed_participants')"
assert_eq "lock-max-pairs-per-designer-40" 40 \
  "$(lockv '.source_calibration.hcm_v2.designers.max_pairs_per_designer')"
assert_eq "lock-designer-judgments-per-pair-12" 12 \
  "$(lockv '.source_calibration.hcm_v2.designers.judgments_per_pair')"
assert_eq "lock-min-credentialed-designers-96" 96 \
  "$(lockv '.source_calibration.hcm_v2.designers.min_credentialed_designers')"
assert_eq "lock-designer-ballots-separate" true \
  "$(lockv '.source_calibration.hcm_v2.designers.separate_from_target_user_ballots')"

# --- fixtures ---------------------------------------------------------------
# 3200 participants x 8 natural pairs = 25600 = 320 pairs x 80 judgments, and
# 96 designers x 40 pairs = 3840 = 320 pairs x 12: the frozen numbers close.

# mk_target OUT [JQ_MUTATION]
mk_target() {
  local out="$1" mutation="${2:-.}"
  jq -n '
    def pad4: ("0000" + tostring) | .[-4:];
    def pad5: ("00000" + tostring) | .[-5:];
    {schema_version: "hcm-v2-exposure-plan/v1",
     ballot_stream: "target_users",
     participants: [range(3200) | . as $i |
       {participant_id: ("tu-" + (($i + 1) | pad5)),
        exposures: ([range(8) | . as $k |
            {pair_id: ("hcm-v2-n" + (((($i * 8) + $k) % 320) + 1 | pad4)),
             kind: "natural",
             viewport: (if (($i + $k) % 2) == 0 then "1440x900" else "390x844" end)}]
          + [range(2) | . as $k |
            {pair_id: ("hcm-v2-a" + (((($i * 2) + $k) % 32) + 1 | pad4)),
             kind: "anchor",
             viewport: "1440x900"}])}]}' | jq -c "$mutation" >"$out"
}

# mk_designers OUT [JQ_MUTATION]
mk_designers() {
  local out="$1" mutation="${2:-.}"
  jq -n '
    def pad4: ("0000" + tostring) | .[-4:];
    {schema_version: "hcm-v2-exposure-plan/v1",
     ballot_stream: "designers",
     participants: [range(96) | . as $i |
       {participant_id: ("dz-" + (($i + 1) | pad4)),
        exposures: [range(40) | . as $k |
          {pair_id: ("hcm-v2-n" + (((($i * 40) + $k) % 320) + 1 | pad4)),
           kind: "natural",
           viewport: (if (($i + $k) % 2) == 0 then "1440x900" else "390x844" end)}]}]}' |
    jq -c "$mutation" >"$out"
}

# Every run is appended to $ALL so the external-boundary sweep at the bottom
# inspects real output without re-running the whole 3200-participant fixture set.
ALL=''
run_exposure() { OUT=$("$STUDY" hcm-exposure "$@" 2>&1); RC=$?; ALL="$ALL$OUT"; return 0; }

# --- a faithful target-user plan binds --------------------------------------
mk_target "$W/target.json"
run_exposure "$W/target.json"
assert_eq "faithful-target-plan-rc0" 0 "$RC"
assert_contains "faithful-target-plan-bound" "EXPOSURE-BOUND" "$OUT"

# --- a faithful designer plan binds -----------------------------------------
mk_designers "$W/designers.json"
run_exposure "$W/designers.json"
assert_eq "faithful-designer-plan-rc0" 0 "$RC"
assert_contains "faithful-designer-plan-bound" "EXPOSURE-BOUND" "$OUT"

# --- no participant sees more than 8 natural pairs --------------------------
mk_target "$W/natcap.json" \
  '.participants[0].exposures += [{pair_id: "hcm-v2-n0300", kind: "natural", viewport: "1440x900"}]'
run_exposure "$W/natcap.json"
assert_eq "natural-cap-rc1" 1 "$RC"
assert_contains "natural-cap-code" "HCM_EXPOSURE_NATURAL_CAP" "$OUT"

# --- no participant sees more than 2 anchors --------------------------------
mk_target "$W/anchorcap.json" \
  '.participants[0].exposures += [{pair_id: "hcm-v2-a0031", kind: "anchor", viewport: "1440x900"}]'
run_exposure "$W/anchorcap.json"
assert_eq "anchor-cap-rc1" 1 "$RC"
assert_contains "anchor-cap-code" "HCM_EXPOSURE_ANCHOR_CAP" "$OUT"

# --- pair_repeat_exposures is 0: no participant sees a pair twice ------------
mk_target "$W/repeat.json" \
  '.participants[0].exposures[7].pair_id = .participants[0].exposures[0].pair_id'
run_exposure "$W/repeat.json"
assert_eq "repeat-exposure-rc1" 1 "$RC"
assert_contains "repeat-exposure-code" "HCM_EXPOSURE_REPEAT" "$OUT"

# --- only the two frozen viewports may be used ------------------------------
mk_target "$W/viewport.json" '.participants[0].exposures[0].viewport = "1280x720"'
run_exposure "$W/viewport.json"
assert_eq "unknown-viewport-rc1" 1 "$RC"
assert_contains "unknown-viewport-code" "HCM_EXPOSURE_VIEWPORT" "$OUT"

# --- and BOTH frozen viewports must actually be covered ---------------------
mk_target "$W/onevp.json" '.participants[].exposures[].viewport = "1440x900"'
run_exposure "$W/onevp.json"
assert_eq "viewport-coverage-rc1" 1 "$RC"
assert_contains "viewport-coverage-code" "HCM_EXPOSURE_VIEWPORT_COVERAGE" "$OUT"

# --- the target-user participant floor is 3200 ------------------------------
mk_target "$W/floor.json" '.participants |= .[0:3199]'
run_exposure "$W/floor.json"
assert_eq "participant-floor-rc1" 1 "$RC"
assert_contains "participant-floor-code" "HCM_EXPOSURE_PARTICIPANT_FLOOR" "$OUT"

# --- every natural pair is allocated exactly 80 target-user judgments --------
mk_target "$W/judgments.json" '.participants[0].exposures[0].pair_id = "hcm-v2-n0002"'
run_exposure "$W/judgments.json"
assert_eq "target-judgment-count-rc1" 1 "$RC"
assert_contains "target-judgment-count-code" "HCM_EXPOSURE_JUDGMENT_COUNT" "$OUT"

# --- all 320 natural pairs must be in the plan ------------------------------
mk_target "$W/coverage.json" '.participants[].exposures |= map(select(.kind == "anchor"))'
run_exposure "$W/coverage.json"
assert_eq "natural-coverage-rc1" 1 "$RC"
assert_contains "natural-coverage-code" "HCM_EXPOSURE_PAIR_COVERAGE" "$OUT"

# --- all 32 anchors must be in the target-user plan -------------------------
mk_target "$W/anchorcov.json" '.participants[].exposures |= map(select(.kind == "natural"))'
run_exposure "$W/anchorcov.json"
assert_eq "anchor-coverage-rc1" 1 "$RC"
assert_contains "anchor-coverage-code" "HCM_EXPOSURE_ANCHOR_COVERAGE" "$OUT"

# --- no designer sees more than 40 pairs ------------------------------------
mk_designers "$W/dcap.json" \
  '.participants[0].exposures += [{pair_id: "hcm-v2-n0100", kind: "natural", viewport: "390x844"}]'
run_exposure "$W/dcap.json"
assert_eq "designer-pair-cap-rc1" 1 "$RC"
assert_contains "designer-pair-cap-code" "HCM_EXPOSURE_DESIGNER_PAIR_CAP" "$OUT"

# --- the credentialed designer floor is 96 ----------------------------------
mk_designers "$W/dfloor.json" '.participants |= .[0:95]'
run_exposure "$W/dfloor.json"
assert_eq "designer-floor-rc1" 1 "$RC"
assert_contains "designer-floor-code" "HCM_EXPOSURE_DESIGNER_FLOOR" "$OUT"

# --- every natural pair is allocated exactly 12 designer judgments -----------
mk_designers "$W/djudge.json" '.participants[0].exposures[0].pair_id = "hcm-v2-n0002"'
run_exposure "$W/djudge.json"
assert_eq "designer-judgment-count-rc1" 1 "$RC"
assert_contains "designer-judgment-count-code" "HCM_EXPOSURE_JUDGMENT_COUNT" "$OUT"

# --- designer ballots stay separate from target-user ballots ----------------
run_exposure "$W/target.json" "$W/designers.json"
assert_eq "separate-ballot-streams-rc0" 0 "$RC"
assert_contains "separate-ballot-streams-bound" "EXPOSURE-BOUND" "$OUT"

mk_designers "$W/dshared.json" '.participants[0].participant_id = "tu-00001"'
run_exposure "$W/target.json" "$W/dshared.json"
assert_eq "shared-participant-rc1" 1 "$RC"
assert_contains "shared-participant-code" "HCM_EXPOSURE_BALLOT_OVERLAP" "$OUT"

mk_target "$W/target2.json" '.participants[].participant_id |= (. + "b")'
run_exposure "$W/target.json" "$W/target2.json"
assert_eq "same-stream-twice-rc1" 1 "$RC"
assert_contains "same-stream-twice-code" "HCM_EXPOSURE_STREAM_DUPLICATE" "$OUT"

# --- malformed input fails closed -------------------------------------------
mk_target "$W/badschema.json" '.schema_version = "hcm-v2-exposure-plan/v9"'
run_exposure "$W/badschema.json"
assert_eq "bad-schema-rc1" 1 "$RC"
assert_contains "bad-schema-code" "HCM_EXPOSURE_INVALID" "$OUT"

mk_target "$W/badstream.json" '.ballot_stream = "friends"'
run_exposure "$W/badstream.json"
assert_eq "bad-stream-rc1" 1 "$RC"
assert_contains "bad-stream-code" "HCM_EXPOSURE_INVALID" "$OUT"

printf 'not json\n' >"$W/notjson.json"
run_exposure "$W/notjson.json"
assert_eq "non-json-rc1" 1 "$RC"
assert_contains "non-json-code" "HCM_EXPOSURE_INVALID" "$OUT"

run_exposure "$W/absent.json"
assert_eq "missing-file-rc1" 1 "$RC"
assert_contains "missing-file-code" "HCM_EXPOSURE_INVALID" "$OUT"

# --- the external boundary: a plan is an allocation, never a human result ----
for banned in TASTE-CERTIFIED HUMAN_CERTIFIED human_certified WARN; do
  if printf '%s' "$ALL" | grep -qF -- "$banned"; then
    fail "no-prohibited-output-$banned" "exposure output leaked [$banned]"
  else
    pass "no-prohibited-output-$banned"
  fi
done

finish
