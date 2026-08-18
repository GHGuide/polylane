#!/usr/bin/env bash
# Compile a fail-closed eligibility receipt from blinded, human-labeled holdout ballots.
set -euo pipefail

usage() {
  printf 'usage: %s <calibration-input.json> <eligibility-receipt.json>\n' "${0##*/}" >&2
}

if [ "$#" -ne 2 ]; then
  usage
  exit 64
fi

INPUT_PATH=$1
OUTPUT_PATH=$2
RECEIPT_TMP=
JUDGE_ID=
JUDGE_MODEL_VERSION=
JUDGE_SYSTEM_PROMPT_SHA=
JUDGE_SAMPLING_SHA=
HOLDOUT_CORPUS_RECEIPT=
VALIDATOR_FP=$(shasum -a 256 "$0" | awk '{print $1}')
umask 077

cleanup() {
  if [ -n "$RECEIPT_TMP" ] && [ -f "$RECEIPT_TMP" ]; then
    rm -f "$RECEIPT_TMP"
  fi
}
trap cleanup EXIT HUP INT TERM

emit_receipt() {
  receipt_eligible=$1
  receipt_reason=$2
  receipt_units=$3
  receipt_correct=$4
  receipt_wilson=$5
  receipt_provider=$6
  receipt_model=$7
  receipt_hash=$8
  receipt_side_probe_n=$9
  receipt_side_p=${10}
  receipt_mirror_probe_n=${11}
  receipt_mirror_contradictions=${12}

  # Stable reason codes derived from the failure site, not caller text.
  case "$receipt_reason" in
    eligible*) receipt_codes='[]' ;;
    'invalid JSON'*) receipt_codes='["JSON_INVALID"]' ;;
    rejected:*) receipt_codes='["SCHEMA_REJECTED"]' ;;
    *correct_units*) receipt_codes='["ACCURACY_FLOOR"]' ;;
    *Wilson*) receipt_codes='["WILSON_FLOOR"]' ;;
    *'side probe'*) receipt_codes='["SIDE_BIAS"]' ;;
    *'mirror probe'*) receipt_codes='["MIRROR_INSTABILITY"]' ;;
    *) receipt_codes='["INELIGIBLE"]' ;;
  esac
  # accuracy is the recomputed correct/units rate (0 when no units validated).
  receipt_accuracy=$(awk -v c="$receipt_correct" -v n="$receipt_units" 'BEGIN{ if (n+0 > 0) printf "%.6f", c/n; else printf "0" }')

  RECEIPT_TMP=$(mktemp "${OUTPUT_PATH}.tmp.XXXXXX")
  jq -n \
    --arg version 'taste-calibration/v1' \
    --argjson eligible "$receipt_eligible" \
    --arg reason "$receipt_reason" \
    --argjson codes "$receipt_codes" \
    --argjson units "$receipt_units" \
    --argjson correct "$receipt_correct" \
    --argjson accuracy "$receipt_accuracy" \
    --argjson wilson "$receipt_wilson" \
    --arg provider "$receipt_provider" \
    --arg model "$receipt_model" \
    --arg model_version "$JUDGE_MODEL_VERSION" \
    --arg system_prompt_sha256 "$JUDGE_SYSTEM_PROMPT_SHA" \
    --arg sampling_sha256 "$JUDGE_SAMPLING_SHA" \
    --arg corpus_receipt "$HOLDOUT_CORPUS_RECEIPT" \
    --arg judge_id "$JUDGE_ID" \
    --arg validator_fp "$VALIDATOR_FP" \
    --arg input_sha256 "$receipt_hash" \
    --argjson side_probe_n "$receipt_side_probe_n" \
    --argjson side_probe_exact_binomial_p "$receipt_side_p" \
    --argjson mirror_probe_n "$receipt_mirror_probe_n" \
    --argjson mirror_contradictions "$receipt_mirror_contradictions" \
    '{
      schema_version: $version,
      receipt_version: "polylane.taste.judge-eligibility.v1",
      status: (if $eligible then "eligible" else "ineligible" end),
      classification: "fixture",
      eligible: $eligible,
      result: (if $eligible then "eligible" else "ineligible" end),
      reason: $reason,
      reason_codes: $codes,
      sample_unit: "prompt/brief mirrored pair",
      sample_units: $units,
      correct_units: $correct,
      accuracy: $accuracy,
      wilson_lower_bound: $wilson,
      human_labelled_pairs: $units,
      correct: $correct,
      wilson_lcb_95: $wilson,
      side_probe_n: $side_probe_n,
      side_probe_exact_binomial_p: $side_probe_exact_binomial_p,
      mirror_probe_n: $mirror_probe_n,
      mirror_contradictions: $mirror_contradictions,
      corpus_holdout_receipt_sha256: $corpus_receipt,
      judge_configuration: {kind: "machine", provider: $provider, model: $model, model_version: $model_version, system_prompt_sha256: $system_prompt_sha256, sampling_sha256: $sampling_sha256},
      judge: {id: $judge_id, provider: $provider, model: $model},
      judge_id: $judge_id,
      validator: {id: "polylane-taste-calibrate", fingerprint: $validator_fp},
      inputs: {calibration_input_sha256: $input_sha256, holdout_corpus_receipt_sha256: $corpus_receipt},
      input_sha256: $input_sha256
    }' > "$RECEIPT_TMP"
  mv -f "$RECEIPT_TMP" "$OUTPUT_PATH"
  RECEIPT_TMP=
}

regular_json_without_duplicate_keys() {
  local duplicate_paths
  [ -f "$1" ] && [ ! -L "$1" ] || return 1
  jq -e . "$1" >/dev/null 2>&1 || return 1
  duplicate_paths=$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("\u001f")' "$1" 2>/dev/null | LC_ALL=C sort | uniq -d)
  [ -z "$duplicate_paths" ]
}

if ! regular_json_without_duplicate_keys "$INPUT_PATH"; then
  emit_receipt false 'invalid JSON calibration input' 0 0 0 '' '' '' 0 0 0 0
  exit 1
fi

INPUT_HASH=$(shasum -a 256 "$INPUT_PATH" | awk '{print $1}')
JUDGE_PROVIDER=$(jq -r '.judge.provider // ""' "$INPUT_PATH")
JUDGE_MODEL=$(jq -r '.judge.model // ""' "$INPUT_PATH")
JUDGE_ID=$(jq -r '.judge.id // ""' "$INPUT_PATH")
JUDGE_MODEL_VERSION=$(jq -r '.judge.model_version // ""' "$INPUT_PATH")
JUDGE_SYSTEM_PROMPT_SHA=$(jq -r '.judge.system_prompt_sha256 // ""' "$INPUT_PATH")
JUDGE_SAMPLING_SHA=$(jq -r '.judge.sampling_sha256 // ""' "$INPUT_PATH")
HOLDOUT_CORPUS_RECEIPT=$(jq -r '.calibration.holdout_corpus_receipt_sha256 // ""' "$INPUT_PATH")

VALIDATION_ERRORS=$(jq -r '
  def valid_vote:
    type == "number" and floor == . and (. == 0 or . == 1 or . == 2);
  def valid_request($unit):
    type == "object"
    and (keys == ["brief", "prompt"])
    and .prompt == $unit.prompt
    and .brief == $unit.brief;
  def valid_ballot($unit; $judge):
    type == "object"
    and (.provider == $judge.provider)
    and (.model == $judge.model)
    and (.vote | valid_vote)
    and (.request | valid_request($unit));
  def valid_abstention:
    if .primary.vote == 0 or .mirror.vote == 0 then
      .primary.vote == 0
      and .mirror.vote == 0
      and (.primary.abstention_reason | type == "string" and length > 0)
      and (.mirror.abstention_reason | type == "string" and length > 0)
    else true end;
  def side_consistent:
    if .primary.vote == 0 and .mirror.vote == 0 then true
    else .primary.vote + .mirror.vote == 3 end;
  def hash: type == "string" and test("^[0-9a-f]{64}$");
  . as $root |
  [
    if (. | keys - ["calibration", "judge", "schema_version", "units"]) != [] then "unknown top-level field" else empty end,
    if .schema_version != 1 then "unsupported schema_version" else empty end,
    if (.calibration | type) != "object" then "missing calibration metadata" else empty end,
    if (.calibration | keys - ["dataset_id", "holdout_corpus_receipt_sha256", "label_provenance", "partition"]) != [] then "unknown calibration field" else empty end,
    if .calibration.partition != "held_out" then "calibration is not held_out" else empty end,
    if .calibration.label_provenance != "human-labeled" then "labels are not human-labeled" else empty end,
    if (.calibration.holdout_corpus_receipt_sha256 | hash | not) then "missing or malformed held-out corpus receipt binding" else empty end,
    if (.judge | type) != "object" or ((.judge | keys | sort) != ["id", "model", "model_version", "provider", "sampling_sha256", "system_prompt_sha256"]) then "missing or malformed judge identity" else empty end,
    if (.judge.id | type) != "string" or (.judge.id | test("^judge-[a-z0-9-]{3,}$") | not) then "missing judge id" else empty end,
    if (.judge.provider | type) != "string" or (.judge.provider | length) == 0 then "missing judge provider" else empty end,
    if (.judge.model | type) != "string" or (.judge.model | length) == 0 then "missing judge model" else empty end,
    if (.judge.model_version | type) != "string" or (.judge.model_version | length) == 0 then "missing judge model version" else empty end,
    if (.judge.system_prompt_sha256 | hash | not) then "missing or malformed system prompt hash" else empty end,
    if (.judge.sampling_sha256 | hash | not) then "missing or malformed sampling hash" else empty end,
    if (.judge | has("eligible") or has("eligibility") or has("eligibility_receipt")) then "self-attested eligibility is forbidden" else empty end,
    if (.units | type) != "array" then "units must be an array" else empty end,
    if (.units | length) < 24 then "fewer than 24 held-out mirrored units" else empty end,
    if (.units | type == "array" and (unique_by([.prompt, .brief]) | length) != length) then "duplicate prompt/brief sample unit" else empty end,
    (.units[]? as $unit |
      if ($unit | type) != "object" then "unit is not an object"
      elif ($unit.prompt | type) != "string" or ($unit.prompt | length) == 0 then "unit has no prompt"
      elif ($unit.brief | type) != "string" or ($unit.brief | length) == 0 then "unit has no brief"
      elif ($unit.gold_vote | valid_vote) | not or ($unit.gold_vote == 0) then "unit has invalid human label"
      elif ($unit.primary | valid_ballot($unit; $root.judge)) | not then "primary ballot violates stable identity, numeric vote, or blind request"
      elif ($unit.mirror | valid_ballot($unit; $root.judge)) | not then "mirror ballot violates stable identity, numeric vote, or blind request"
      elif ($unit | valid_abstention) | not then "invalid abstention"
      else empty end)
  ] | .[]
' "$INPUT_PATH")

if [ -n "$VALIDATION_ERRORS" ]; then
  FIRST_ERROR=$(printf '%s\n' "$VALIDATION_ERRORS" | awk 'NF {print; exit}')
  emit_receipt false "rejected: $FIRST_ERROR" 0 0 0 "$JUDGE_PROVIDER" "$JUDGE_MODEL" "$INPUT_HASH" 0 0 0 0
  exit 1
fi

SAMPLE_UNITS=$(jq '.units | length' "$INPUT_PATH")
CORRECT_UNITS=$(jq '[.units[] | select(.primary.vote == .gold_vote and .mirror.vote == (3 - .gold_vote))] | length' "$INPUT_PATH")
WILSON_LOWER_BOUND=$(awk -v correct="$CORRECT_UNITS" -v total="$SAMPLE_UNITS" 'BEGIN {
  z = 1.959963984540054
  p = correct / total
  z2 = z * z
  lower = (p + z2 / (2 * total) - z * sqrt((p * (1 - p) + z2 / (4 * total)) / total)) / (1 + z2 / total)
  printf "%.6f", lower
}')
SIDE_PROBE_N=$(jq '[.units[] | select(.primary.vote != 0 and .mirror.vote != 0)] | length' "$INPUT_PATH")
SIDE_LEFT=$(jq '[.units[] | select(.primary.vote != 0 and .mirror.vote != 0 and .primary.vote == 1)] | length' "$INPUT_PATH")
SIDE_PROBE_P=$(awk -v left="$SIDE_LEFT" -v total="$SIDE_PROBE_N" 'BEGIN {
  if (total == 0) { printf "0.000000"; exit }
  lower_tail = left
  if (total - left < lower_tail) lower_tail = total - left
  probability = 0
  for (i = 0; i <= lower_tail; i++) {
    combinations = 1
    for (j = 1; j <= i; j++) combinations = combinations * (total - j + 1) / j
    probability += combinations / (2 ^ total)
  }
  probability *= 2
  if (probability > 1) probability = 1
  printf "%.6f", probability
}')
MIRROR_PROBE_N=$SIDE_PROBE_N
MIRROR_CONTRADICTIONS=$(jq '[.units[] | select(.primary.vote != 0 and .mirror.vote != 0 and (.primary.vote + .mirror.vote != 3))] | length' "$INPUT_PATH")

if [ "$CORRECT_UNITS" -lt 17 ]; then
  emit_receipt false "ineligible: correct_units=$CORRECT_UNITS (<17)" "$SAMPLE_UNITS" "$CORRECT_UNITS" "$WILSON_LOWER_BOUND" "$JUDGE_PROVIDER" "$JUDGE_MODEL" "$INPUT_HASH" "$SIDE_PROBE_N" "$SIDE_PROBE_P" "$MIRROR_PROBE_N" "$MIRROR_CONTRADICTIONS"
  exit 1
fi

if ! awk -v value="$WILSON_LOWER_BOUND" 'BEGIN { exit !(value >= 0.50) }'; then
  emit_receipt false "ineligible: Wilson lower bound $WILSON_LOWER_BOUND is below 0.50" "$SAMPLE_UNITS" "$CORRECT_UNITS" "$WILSON_LOWER_BOUND" "$JUDGE_PROVIDER" "$JUDGE_MODEL" "$INPUT_HASH" "$SIDE_PROBE_N" "$SIDE_PROBE_P" "$MIRROR_PROBE_N" "$MIRROR_CONTRADICTIONS"
  exit 1
fi

if [ "$SIDE_PROBE_N" -lt 12 ] || ! awk -v value="$SIDE_PROBE_P" 'BEGIN { exit !(value >= 0.05) }'; then
  emit_receipt false "ineligible: side probe n=$SIDE_PROBE_N p=$SIDE_PROBE_P" "$SAMPLE_UNITS" "$CORRECT_UNITS" "$WILSON_LOWER_BOUND" "$JUDGE_PROVIDER" "$JUDGE_MODEL" "$INPUT_HASH" "$SIDE_PROBE_N" "$SIDE_PROBE_P" "$MIRROR_PROBE_N" "$MIRROR_CONTRADICTIONS"
  exit 1
fi

if [ "$MIRROR_PROBE_N" -lt 8 ] || [ "$MIRROR_CONTRADICTIONS" -ge 2 ]; then
  emit_receipt false "ineligible: mirror probe n=$MIRROR_PROBE_N contradictions=$MIRROR_CONTRADICTIONS" "$SAMPLE_UNITS" "$CORRECT_UNITS" "$WILSON_LOWER_BOUND" "$JUDGE_PROVIDER" "$JUDGE_MODEL" "$INPUT_HASH" "$SIDE_PROBE_N" "$SIDE_PROBE_P" "$MIRROR_PROBE_N" "$MIRROR_CONTRADICTIONS"
  exit 1
fi

emit_receipt true 'eligible: held-out human-labeled mirrored calibration passed' "$SAMPLE_UNITS" "$CORRECT_UNITS" "$WILSON_LOWER_BOUND" "$JUDGE_PROVIDER" "$JUDGE_MODEL" "$INPUT_HASH" "$SIDE_PROBE_N" "$SIDE_PROBE_P" "$MIRROR_PROBE_N" "$MIRROR_CONTRADICTIONS"
