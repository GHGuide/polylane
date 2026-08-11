#!/usr/bin/env bash
# Blind-ballot contract: fixture-only validation, never a real-judge claim.
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

BALLOT="$(cd "$(dirname "$0")/.." && pwd)/bin/polylane-taste-ballot.sh"
make_tmpdir
POINTWISE="$TEST_TMPDIR/pointwise"; mkdir -p "$POINTWISE"
CALIBRATION="$TEST_TMPDIR/calibration.json"; GROUP="$TEST_TMPDIR/group.json"; OUT="$TEST_TMPDIR/result.json"

sha256() { shasum -a 256 "$1" | awk '{print $1}'; }

write_pointwise() { # ballot-id judge-id stimulus-id path
  local ballot_id="$1" judge_id="$2" stimulus_id="$3" path="$4" body digest
  jq -n --arg ballot_id "$ballot_id" --arg judge_id "$judge_id" --arg stimulus_id "$stimulus_id" '
    {schema_version:"taste-pointwise/v1",ballot_id:$ballot_id,judge_id:$judge_id,
     candidate_id:$stimulus_id,brief_sha256:("a" * 64),capture_manifest_sha256:("b" * 64),
     scores_1_to_7:{product_fit:5,hierarchy:5,typography:5,color:5,spatial_rhythm:5,craftsmanship:5,originality:5,state_coherence:5},
     observations:(["product_fit","hierarchy","typography","color","spatial_rhythm","craftsmanship","originality","state_coherence"] | map({criterion:.,capture_id:"cap-001",region_or_state:"header",brief_clause:"task-1",reason:"observable brief-specific evidence"})),
     identity_visible:false,prior_ballots_visible:false,injection_detected:false,judge_discussion:false,
     sealed_at:"2026-08-11T00:00:00Z"}' > "$path"
  body=$(jq -cS . "$path")
  digest=$(printf '%s' "$body" | shasum -a 256 | awk '{print $1}')
  jq --arg digest "$digest" '. + {record_sha256:$digest}' "$path" > "$path.tmp" && mv "$path.tmp" "$path"
}

write_pointwise pointwise-a judge-001 stim-a1b2c3d4e5f6 "$POINTWISE/pointwise-a.json"
write_pointwise pointwise-b judge-002 stim-0f1e2d3c4b5a "$POINTWISE/pointwise-b.json"

cat > "$CALIBRATION" <<'JSON'
{"schema_version":"taste-ballot-calibration/v1","judge_eligibility":[
 {"judge_id":"judge-001","eligible":true,"abstention_policy":"pass","independent":true,"no_candidate_identity":true,"no_shared_ballot_channel":true},
 {"judge_id":"judge-002","eligible":true,"abstention_policy":"pass","independent":true,"no_candidate_identity":true,"no_shared_ballot_channel":true}]}
JSON

write_group() {
  local hash_a hash_b
  hash_a=$(sha256 "$POINTWISE/pointwise-a.json"); hash_b=$(sha256 "$POINTWISE/pointwise-b.json")
  jq -n --arg hash_a "$hash_a" --arg hash_b "$hash_b" '
    {schema_version:"taste-mirrored-group/v1",mirror_group_id:"mg-001",brief_sha256:("a" * 64),candidate_ids:["stim-a1b2c3d4e5f6","stim-0f1e2d3c4b5a"],candidate_ids_escrow_sha256:("c" * 64),
     pointwise_ballot_ids:["pointwise-a","pointwise-b"],pointwise_sha256:{"pointwise-a":$hash_a,"pointwise-b":$hash_b},
     exposures:[
      {schema_version:"taste-pairwise/v1",ballot_id:"pair-001",judge_id:"judge-001",display_order:"A/B",choice:"A",canonical_choice:"stim-a1b2c3d4e5f6",sealed_at:"2026-08-11T00:01:00Z",response_sha256:("d" * 64),identity_visible:false,prior_ballots_visible:false,injection_detected:false,judge_discussion:false,abstain_reason:null},
      {schema_version:"taste-pairwise/v1",ballot_id:"pair-002",judge_id:"judge-002",display_order:"B/A",choice:"B",canonical_choice:"stim-a1b2c3d4e5f6",sealed_at:"2026-08-11T00:01:01Z",response_sha256:("e" * 64),identity_visible:false,prior_ballots_visible:false,injection_detected:false,judge_discussion:false,abstain_reason:null}],
     outcome:"resolved-stim-a1b2c3d4e5f6"}' > "$GROUP"
}
write_group

validate_rc=0; validate_output=$("$BALLOT" validate "$GROUP" "$POINTWISE" "$CALIBRATION" "$OUT" 2>&1) || validate_rc=$?
[ "$validate_rc" = 0 ] || printf '%s\n' "$validate_output" >&2
assert_eq "ballot-accepts-complete-opaque-mirror" "0" "$validate_rc"
assert_eq "ballot-emits-fixture-only-eligibility" "eligible" "$(jq -r .status "$OUT")"
assert_eq "ballot-preserves-mirrored-winner" "stim-a1b2c3d4e5f6" "$(jq -r .winner "$OUT")"
assert_eq "ballot-emits-opaque-brief-key" "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" "$(jq -r .brief_sha256 "$OUT")"
assert_eq "ballot-never-claims-human-panel" "false" "$(jq -r .human_certified "$OUT")"

jq '.exposures[1].canonical_choice="stim-0f1e2d3c4b5a"' "$GROUP" > "$GROUP.tmp" && mv "$GROUP.tmp" "$GROUP"
assert_fail "ballot-rejects-order-contradiction" "$BALLOT" validate "$GROUP" "$POINTWISE" "$CALIBRATION" "$OUT"
write_group

jq '.exposures[1].judge_id="judge-001"' "$GROUP" > "$GROUP.tmp" && mv "$GROUP.tmp" "$GROUP"
assert_fail "ballot-rejects-same-judge-mirror" "$BALLOT" validate "$GROUP" "$POINTWISE" "$CALIBRATION" "$OUT"
write_group

jq '.exposures[0].identity_visible=true' "$GROUP" > "$GROUP.tmp" && mv "$GROUP.tmp" "$GROUP"
assert_fail "ballot-rejects-identity-leakage" "$BALLOT" validate "$GROUP" "$POINTWISE" "$CALIBRATION" "$OUT"
write_group

jq '.exposures[0].injection_detected=true' "$GROUP" > "$GROUP.tmp" && mv "$GROUP.tmp" "$GROUP"
assert_fail "ballot-rejects-prompt-injection" "$BALLOT" validate "$GROUP" "$POINTWISE" "$CALIBRATION" "$OUT"
write_group

jq '.scores_1_to_7.product_fit=8' "$POINTWISE/pointwise-a.json" > "$POINTWISE/pointwise-a.tmp" && mv "$POINTWISE/pointwise-a.tmp" "$POINTWISE/pointwise-a.json"
assert_fail "ballot-rejects-incomplete-pointwise-scale" "$BALLOT" validate "$GROUP" "$POINTWISE" "$CALIBRATION" "$OUT"
write_pointwise pointwise-a judge-001 stim-a1b2c3d4e5f6 "$POINTWISE/pointwise-a.json"; write_group

jq '.judge_eligibility[0].abstention_policy="fail"' "$CALIBRATION" > "$CALIBRATION.tmp" && mv "$CALIBRATION.tmp" "$CALIBRATION"
assert_fail "ballot-requires-calibrated-abstention" "$BALLOT" validate "$GROUP" "$POINTWISE" "$CALIBRATION" "$OUT"
finish
