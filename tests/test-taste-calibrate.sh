#!/usr/bin/env bash
# Regression tests for held-out judge eligibility compilation.
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
TMPDIR_TEST=$(mktemp -d "${TMPDIR:-/tmp}/polylane-taste-calibrate.XXXXXX")
trap 'rm -rf "$TMPDIR_TEST"' EXIT HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

make_input() {
  INPUT_PATH=$1
  CORRECT_COUNT=$2
  UNIT_COUNT=${3:-24}
  jq -n --argjson correct "$CORRECT_COUNT" --argjson units "$UNIT_COUNT" '
    {
      schema_version: 1,
      calibration: {dataset_id: "human-ui-holdout-v1", partition: "held_out", label_provenance: "human-labeled", holdout_corpus_receipt_sha256: ("f" * 64)},
      judge: {id: "judge-example-001", provider: "example-provider", model: "example-model", model_version: "2026.08", system_prompt_sha256: ("1" * 64), sampling_sha256: ("2" * 64)},
      units: [range(0; $units) | . as $index | (if ($index % 2) == 0 then 1 else 2 end) as $gold | {
        prompt: ("prompt-" + ($index | tostring)),
        brief: ("brief-" + ($index | tostring)),
        gold_vote: $gold,
        primary: {
          provider: "example-provider", model: "example-model", vote: (if $index < $correct then $gold else (3 - $gold) end),
          request: {prompt: ("prompt-" + ($index | tostring)), brief: ("brief-" + ($index | tostring))}
        },
        mirror: {
          provider: "example-provider", model: "example-model", vote: (if $index < $correct then (3 - $gold) else $gold end),
          request: {prompt: ("prompt-" + ($index | tostring)), brief: ("brief-" + ($index | tostring))}
        }
      }]
    }' > "$INPUT_PATH"
}

test_eligible_receipt_uses_mirrored_prompt_brief_units() {
  INPUT_PATH="$TMPDIR_TEST/eligible.json"
  OUTPUT_PATH="$TMPDIR_TEST/eligibility.json"
  make_input "$INPUT_PATH" 17
  "$ROOT/bin/polylane-taste-calibrate.sh" "$INPUT_PATH" "$OUTPUT_PATH"
  test "$(jq -r '.eligible' "$OUTPUT_PATH")" = true || fail '17/24 must be eligible'
  test "$(jq -r '.schema_version' "$OUTPUT_PATH")" = taste-calibration/v1 || fail 'receipt must have the consumer schema version'
  test "$(jq -r '.result' "$OUTPUT_PATH")" = eligible || fail 'receipt must expose computed eligibility'
  test "$(jq -r '.sample_units' "$OUTPUT_PATH")" = 24 || fail 'receipt must count prompt/brief units'
  test "$(jq -r '.correct_units' "$OUTPUT_PATH")" = 17 || fail 'receipt must recompute correct units'
  test "$(jq -r '.human_labelled_pairs' "$OUTPUT_PATH")" = 24 || fail 'consumer pair count must be present'
  test "$(jq -r '.side_probe_n >= 12 and .mirror_probe_n >= 8 and .mirror_contradictions < 2' "$OUTPUT_PATH")" = true || fail 'receipt must include passing side and mirror probes'
  awk -v value="$(jq -r '.wilson_lower_bound' "$OUTPUT_PATH")" 'BEGIN { exit !(value >= 0.50) }' || fail 'Wilson lower bound must be at least 0.50'
  test "$(jq -r '.judge.provider + "/" + .judge.model' "$OUTPUT_PATH")" = example-provider/example-model || fail 'receipt must bind provider/model identity'
  test "$(jq -r '.judge_id' "$OUTPUT_PATH")" = judge-example-001 || fail 'receipt must bind the ballot judge id'
  # Cycle 39 bindings: corpus/holdout receipt, full judge configuration, accuracy,
  # classification, and validator fingerprint.
  test "$(jq -r '.classification' "$OUTPUT_PATH")" = fixture || fail 'receipt must be validator-classified fixture'
  test "$(jq -r '.corpus_holdout_receipt_sha256' "$OUTPUT_PATH")" = ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff || fail 'receipt must bind the held-out corpus receipt'
  test "$(jq -r '.judge_configuration.model_version' "$OUTPUT_PATH")" = 2026.08 || fail 'receipt must bind judge model version'
  test "$(jq -r '.judge_configuration.system_prompt_sha256' "$OUTPUT_PATH")" = 1111111111111111111111111111111111111111111111111111111111111111 || fail 'receipt must bind system prompt hash'
  test "$(jq -r '.judge_configuration.sampling_sha256' "$OUTPUT_PATH")" = 2222222222222222222222222222222222222222222222222222222222222222 || fail 'receipt must bind sampling hash'
  awk -v value="$(jq -r '.accuracy' "$OUTPUT_PATH")" 'BEGIN { exit !(value > 0.70 && value < 0.71) }' || fail 'receipt must record accuracy 17/24'
  test "$(jq -r '.validator.id' "$OUTPUT_PATH")" = polylane-taste-calibrate || fail 'receipt must name the validator'
  test "$(jq -r '.validator.fingerprint' "$OUTPUT_PATH")" = "$(shasum -a 256 "$ROOT/bin/polylane-taste-calibrate.sh" | awk '{print $1}')" || fail 'receipt must fingerprint the validator'
  test "$(jq -r '.input_sha256' "$OUTPUT_PATH")" = "$(shasum -a 256 "$INPUT_PATH" | awk '{print $1}')" || fail 'receipt must bind the exact input hash'
  test "$(jq -r '.reason_codes | length' "$OUTPUT_PATH")" = 0 || fail 'eligible receipt has no reason codes'
}

test_accepts_more_than_twenty_four_units() {
  INPUT_PATH="$TMPDIR_TEST/twenty-six.json"
  OUTPUT_PATH="$TMPDIR_TEST/twenty-six-receipt.json"
  make_input "$INPUT_PATH" 26 26
  "$ROOT/bin/polylane-taste-calibrate.sh" "$INPUT_PATH" "$OUTPUT_PATH"
  test "$(jq -r '.eligible' "$OUTPUT_PATH")" = true || fail '26/26 must be eligible (not hardcoded to exactly 24)'
  test "$(jq -r '.human_labelled_pairs' "$OUTPUT_PATH")" = 26 || fail 'receipt must record the exact unit count, not a constant 24'
  test "$(jq -r '.sample_units' "$OUTPUT_PATH")" = 26 || fail 'sample_units must be the exact count'
}

assert_rejected() {
  INPUT_PATH=$1
  OUTPUT_PATH=$2
  if "$ROOT/bin/polylane-taste-calibrate.sh" "$INPUT_PATH" "$OUTPUT_PATH"; then
    fail 'invalid calibration input must fail closed'
  fi
  test "$(jq -r '.eligible' "$OUTPUT_PATH")" = false || fail 'rejected receipt must be ineligible'
}

test_rejects_insufficient_accuracy_even_with_a_valid_shape() {
  INPUT_PATH="$TMPDIR_TEST/too-few-correct.json"
  OUTPUT_PATH="$TMPDIR_TEST/too-few-correct-receipt.json"
  make_input "$INPUT_PATH" 16
  assert_rejected "$INPUT_PATH" "$OUTPUT_PATH"
}

test_rejects_identity_drift_and_invalid_abstention() {
  INPUT_PATH="$TMPDIR_TEST/identity-drift.json"
  OUTPUT_PATH="$TMPDIR_TEST/identity-drift-receipt.json"
  make_input "$INPUT_PATH" 17
  jq '.units[5].mirror.model = "other-model"' "$INPUT_PATH" > "$INPUT_PATH.next"
  mv "$INPUT_PATH.next" "$INPUT_PATH"
  assert_rejected "$INPUT_PATH" "$OUTPUT_PATH"

  make_input "$INPUT_PATH" 17
  jq '.units[5].primary.vote = 0' "$INPUT_PATH" > "$INPUT_PATH.next"
  mv "$INPUT_PATH.next" "$INPUT_PATH"
  assert_rejected "$INPUT_PATH" "$OUTPUT_PATH"
}

test_allows_explicit_paired_abstention_without_counting_it_correct() {
  INPUT_PATH="$TMPDIR_TEST/valid-abstention.json"
  OUTPUT_PATH="$TMPDIR_TEST/valid-abstention-receipt.json"
  make_input "$INPUT_PATH" 17
  jq '.units[17].primary = (.units[17].primary + {vote: 0, abstention_reason: "ambiguous"}) | .units[17].mirror = (.units[17].mirror + {vote: 0, abstention_reason: "ambiguous"})' "$INPUT_PATH" > "$INPUT_PATH.next"
  mv "$INPUT_PATH.next" "$INPUT_PATH"
  "$ROOT/bin/polylane-taste-calibrate.sh" "$INPUT_PATH" "$OUTPUT_PATH"
  test "$(jq -r '.eligible' "$OUTPUT_PATH")" = true || fail 'paired documented abstention must remain valid evidence'
}

test_rejects_leakage_self_attestation_and_nonnumeric_votes() {
  INPUT_PATH="$TMPDIR_TEST/leakage.json"
  OUTPUT_PATH="$TMPDIR_TEST/leakage-receipt.json"
  make_input "$INPUT_PATH" 17
  jq '.units[0].primary.request.gold_vote = 1' "$INPUT_PATH" > "$INPUT_PATH.next"
  mv "$INPUT_PATH.next" "$INPUT_PATH"
  assert_rejected "$INPUT_PATH" "$OUTPUT_PATH"

  make_input "$INPUT_PATH" 17
  jq '.judge.eligible = true' "$INPUT_PATH" > "$INPUT_PATH.next"
  mv "$INPUT_PATH.next" "$INPUT_PATH"
  assert_rejected "$INPUT_PATH" "$OUTPUT_PATH"

  make_input "$INPUT_PATH" 17
  jq '.units[0].primary.vote = "1"' "$INPUT_PATH" > "$INPUT_PATH.next"
  mv "$INPUT_PATH.next" "$INPUT_PATH"
  assert_rejected "$INPUT_PATH" "$OUTPUT_PATH"
}

test_rejects_duplicate_prompt_brief_units_and_duplicate_keys() {
  INPUT_PATH="$TMPDIR_TEST/duplicate-units.json"
  OUTPUT_PATH="$TMPDIR_TEST/duplicate-units-receipt.json"
  make_input "$INPUT_PATH" 17
  jq '.units += [.units[0]]' "$INPUT_PATH" > "$INPUT_PATH.next"
  mv "$INPUT_PATH.next" "$INPUT_PATH"
  assert_rejected "$INPUT_PATH" "$OUTPUT_PATH"

  make_input "$INPUT_PATH" 17
  input_text=$(<"$INPUT_PATH")
  printf '%s\n' "${input_text/\"prompt-0\"/\"prompt-0\",\"prompt\":\"replayed\"}" > "$INPUT_PATH.next"
  mv "$INPUT_PATH.next" "$INPUT_PATH"
  assert_rejected "$INPUT_PATH" "$OUTPUT_PATH"
}

test_rejects_mirrors_that_do_not_reverse_the_side() {
  INPUT_PATH="$TMPDIR_TEST/side-inconsistent.json"
  OUTPUT_PATH="$TMPDIR_TEST/side-inconsistent-receipt.json"
  make_input "$INPUT_PATH" 17
  jq '.units[0].mirror.vote = 1 | .units[1].mirror.vote = 2' "$INPUT_PATH" > "$INPUT_PATH.next"
  mv "$INPUT_PATH.next" "$INPUT_PATH"
  assert_rejected "$INPUT_PATH" "$OUTPUT_PATH"
}

test_rejects_a_systematically_side_biased_judge() {
  INPUT_PATH="$TMPDIR_TEST/side-biased.json"
  OUTPUT_PATH="$TMPDIR_TEST/side-biased-receipt.json"
  make_input "$INPUT_PATH" 17
  jq '.units[].gold_vote = 1 | .units[0:17][].primary.vote = 1 | .units[0:17][].mirror.vote = 2 | .units[17:24][].primary.vote = 0 | .units[17:24][].mirror.vote = 0 | .units[17:24][].primary.abstention_reason = "ambiguous" | .units[17:24][].mirror.abstention_reason = "ambiguous"' "$INPUT_PATH" > "$INPUT_PATH.next"
  mv "$INPUT_PATH.next" "$INPUT_PATH"
  assert_rejected "$INPUT_PATH" "$OUTPUT_PATH"
}

test_eligible_receipt_uses_mirrored_prompt_brief_units
test_accepts_more_than_twenty_four_units
test_rejects_insufficient_accuracy_even_with_a_valid_shape
test_rejects_identity_drift_and_invalid_abstention
test_allows_explicit_paired_abstention_without_counting_it_correct
test_rejects_leakage_self_attestation_and_nonnumeric_votes
test_rejects_duplicate_prompt_brief_units_and_duplicate_keys
test_rejects_mirrors_that_do_not_reverse_the_side
test_rejects_a_systematically_side_biased_judge
printf 'PASS: test-taste-calibrate\n'
