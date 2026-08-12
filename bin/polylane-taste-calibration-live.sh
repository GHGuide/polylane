#!/usr/bin/env bash
# polylane-taste-calibration-live.sh
#
# Production judge-eligibility receipt v2 (taste-calibration/v2).
#
# Unlike the fixture-grade v1 compiler (bin/polylane-taste-calibrate.sh), this
# validator does not trust any self-declared gold, vote, score, eligible,
# fixture, or hash field.  It recomputes every one of them:
#
#   * gold (the correct stimulus) comes from a bound, human-labelled held-out
#     labels file, joined by unit_id and image digest -- never from the unit;
#   * each judge vote is re-parsed from a hash-verified raw model-response
#     artifact with a pinned deterministic parser -- never from a vote field;
#   * eligibility is recomputed from the frozen thresholds;
#   * the fixture/production classification is derived from whether every image
#     and response is a real, safe, hash-matched file on disk -- never declared.
#
# A record whose bindings all resolve to hash-matched files over frozen source
# images is classified "production"; anything using inline responses or
# image-by-digest stays "fixture_only" and can never be represented as a
# production, human-calibrated machine ballot.  A record that CLAIMS a file
# binding (declares a path) but cannot produce the matching bytes is a
# shape-compatible synthetic receipt and is rejected -- no success receipt is
# ever emitted after a failed link.
#
# The eligible claim is HUMAN_CALIBRATED_MACHINE: a machine judge matched human
# holdout labels.  It is never a human ballot and never human_certified.
#
# Pure bash 3.2 + jq.  All LLM invocation happens upstream; this script only
# validates and content-addresses already-captured evidence.
set -euo pipefail

# --------------------------------------------------------------------------
# Pinned response parser.  Its exact text is the frozen contract; its digest is
# recomputed at runtime and every ballot's invocation must declare the same one.
# --------------------------------------------------------------------------
PARSER_SPEC='polylane.taste.response-parser/v1
Read the raw judge response as UTF-8 text.
Consider only lines that exactly match the regular expression: ^FINAL: (FIRST|SECOND|ABSTAIN)$
The parsed verdict is the token from the LAST such matching line.
FIRST maps to position 1, SECOND maps to position 2, ABSTAIN maps to position 0 (abstention).
If no line matches, the response is unparseable and the unit is rejected.'

sha256_stdin() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'
  else return 1; fi
}
sha256_file() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else return 1; fi
}

parser_sha() { printf '%s' "$PARSER_SPEC" | sha256_stdin; }

usage() {
  printf 'usage: %s <calibration-input.json> <eligibility-receipt.json> [artifact-root]\n' "${0##*/}" >&2
  printf '       %s parser-sha\n' "${0##*/}" >&2
}

# Parse a raw response file into a FINAL verdict token using the pinned rule.
parse_final() {
  awk '
    /^FINAL: FIRST$/   { t = "FIRST" }
    /^FINAL: SECOND$/  { t = "SECOND" }
    /^FINAL: ABSTAIN$/ { t = "ABSTAIN" }
    END { print (t == "" ? "NONE" : t) }
  ' "$1"
}

# Reject symlinks and traversal; only a plain regular file under $root is safe.
safe_regular_file() {
  local root=$1 rel=$2 part prefix old_ifs
  case "$rel" in ''|/*|*'//'*|*'\'*) return 1;; esac
  prefix="$root"; old_ifs=$IFS; IFS='/'
  for part in $rel; do
    if [ -z "$part" ] || [ "$part" = . ] || [ "$part" = .. ]; then IFS=$old_ifs; return 1; fi
    prefix="$prefix/$part"
    if [ -L "$prefix" ]; then IFS=$old_ifs; return 1; fi
  done
  IFS=$old_ifs
  [ -f "$root/$rel" ]
}

regular_json_without_duplicate_keys() {
  local file=$1 duplicates
  [ -f "$file" ] && [ ! -L "$file" ] || return 1
  jq -e . "$file" >/dev/null 2>&1 || return 1
  duplicates=$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("")' "$file" 2>/dev/null | LC_ALL=C sort | uniq -d)
  [ -z "$duplicates" ]
}

# --------------------------------------------------------------------------
# argument handling
# --------------------------------------------------------------------------
if [ "${1:-}" = parser-sha ] && [ "$#" -eq 1 ]; then
  parser_sha
  exit 0
fi
if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then usage; exit 64; fi
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 64; }

INPUT_PATH=$1
OUTPUT_PATH=$2
ARTIFACT_ROOT=${3:-$(CDPATH='' cd -- "$(dirname -- "$INPUT_PATH")" 2>/dev/null && pwd)}
VALIDATOR_FP=$(sha256_file "$0")
PINNED_PARSER_SHA=$(parser_sha)
SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/polylane-calibration-live.XXXXXX") || exit 1
RECEIPT_TMP=
umask 077
cleanup() {
  [ -z "$SCRATCH" ] || rm -rf "$SCRATCH"
  if [ -n "$RECEIPT_TMP" ] && [ -f "$RECEIPT_TMP" ]; then rm -f "$RECEIPT_TMP"; fi
}
trap cleanup EXIT HUP INT TERM

# --------------------------------------------------------------------------
# receipt emission.  reason_codes/classification/counts are all validator-derived.
# --------------------------------------------------------------------------
emit_receipt() {
  # $1 eligible(bool) $2 reason $3 classification $4 codes(json array)
  # $5 units $6 correct $7 wilson $8 side_n $9 side_p $10 mirror_n $11 mirror_contra
  # $12 input_sha $13 provider $14 model $15 all_file(bool)
  local eligible=$1 reason=$2 classification=$3 codes=$4 units=$5 correct=$6 \
        wilson=$7 side_n=$8 side_p=$9 mirror_n=${10} mirror_contra=${11} \
        input_sha=${12} provider=${13} model=${14} all_file=${15} accuracy production
  accuracy=$(awk -v c="$correct" -v n="$units" 'BEGIN{ if (n+0 > 0) printf "%.6f", c/n; else printf "0" }')
  production=false
  if [ "$eligible" = true ] && [ "$classification" = production ]; then production=true; fi
  RECEIPT_TMP=$(mktemp "${OUTPUT_PATH}.tmp.XXXXXX")
  jq -n \
    --arg version 'taste-calibration/v2' \
    --argjson eligible "$eligible" \
    --arg reason "$reason" \
    --arg classification "$classification" \
    --argjson production "$production" \
    --argjson codes "$codes" \
    --argjson units "$units" \
    --argjson correct "$correct" \
    --argjson accuracy "$accuracy" \
    --argjson wilson "$wilson" \
    --arg provider "$provider" \
    --arg model "$model" \
    --arg model_version "$JUDGE_MODEL_VERSION" \
    --arg system_prompt_sha256 "$JUDGE_SYSTEM_PROMPT_SHA" \
    --arg sampling_sha256 "$JUDGE_SAMPLING_SHA" \
    --arg corpus_receipt "$HOLDOUT_CORPUS_RECEIPT" \
    --arg tuning_receipt "$TUNING_CORPUS_RECEIPT" \
    --arg labels_sha "$HOLDOUT_LABELS_SHA" \
    --arg source_snapshot "$SOURCE_SNAPSHOT" \
    --arg parser_sha "$PINNED_PARSER_SHA" \
    --arg adapter_sha "$INVOCATION_ADAPTER_SHA" \
    --arg judge_id "$JUDGE_ID" \
    --arg validator_fp "$VALIDATOR_FP" \
    --arg input_sha256 "$input_sha" \
    --argjson bound_units "$all_file" \
    --argjson side_probe_n "$side_n" \
    --argjson side_probe_exact_binomial_p "$side_p" \
    --argjson mirror_probe_n "$mirror_n" \
    --argjson mirror_contradictions "$mirror_contra" \
    '{
      schema_version: $version,
      receipt_version: "polylane.taste.judge-eligibility.v2",
      status: (if $eligible then "eligible" else "ineligible" end),
      classification: $classification,
      production: $production,
      fixture_only: ($classification != "production"),
      eligible: $eligible,
      result: (if $eligible then "eligible" else "ineligible" end),
      reason: $reason,
      reason_codes: $codes,
      human_certified: false,
      machine_not_human: true,
      machine_panel_claim: "HUMAN_CALIBRATED_MACHINE",
      claim_semantics: "Eligibility means this machine judge reproduced human held-out labels; it is not a human ballot and can never be represented as human certification.",
      sample_unit: "held-out mirrored image pair",
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
      tuning_corpus_receipt_sha256: $tuning_receipt,
      holdout_labels_sha256: $labels_sha,
      source_snapshot_sha256: $source_snapshot,
      response_parser_sha256: $parser_sha,
      invocation_adapter_sha256: $adapter_sha,
      bound_response_units: $bound_units,
      judge_configuration: {kind: "machine", provider: $provider, model: $model, model_version: $model_version, system_prompt_sha256: $system_prompt_sha256, sampling_sha256: $sampling_sha256},
      judge: {id: $judge_id, provider: $provider, model: $model},
      judge_id: $judge_id,
      validator: {id: "polylane-taste-calibration-live", fingerprint: $validator_fp},
      inputs: {calibration_input_sha256: $input_sha256, holdout_corpus_receipt_sha256: $corpus_receipt, holdout_labels_sha256: $labels_sha},
      input_sha256: $input_sha256,
      external_limitations: [
        "production classification proves hash-bound raw responses over frozen source images; it does not by itself prove those bytes are live Dataverse renders or live model calls",
        "corpus liveness and panel identity are attested by the source-live corpus receipt and the integrator live-smoke receipt in the declared evidence closure"
      ]
    }' > "$RECEIPT_TMP"
  mv -f "$RECEIPT_TMP" "$OUTPUT_PATH"
  RECEIPT_TMP=
}

# Fields surfaced in the receipt; recomputed/overwritten below, "" until known.
JUDGE_ID=''; JUDGE_MODEL_VERSION=''; JUDGE_SYSTEM_PROMPT_SHA=''; JUDGE_SAMPLING_SHA=''
HOLDOUT_CORPUS_RECEIPT=''; TUNING_CORPUS_RECEIPT=''; HOLDOUT_LABELS_SHA=''
SOURCE_SNAPSHOT=''; INVOCATION_ADAPTER_SHA=''
JUDGE_PROVIDER=''; JUDGE_MODEL=''

fail_closed() { # reason classification codes-json input-sha
  emit_receipt false "$1" "$2" "$3" 0 0 0 0 0 0 0 "$4" "$JUDGE_PROVIDER" "$JUDGE_MODEL" false
  exit 1
}

# --------------------------------------------------------------------------
# stage 0: input is a real, regular, duplicate-key-free JSON document
# --------------------------------------------------------------------------
if ! regular_json_without_duplicate_keys "$INPUT_PATH"; then
  fail_closed 'invalid JSON calibration input' fixture_only '["JSON_INVALID"]' ''
fi
INPUT_HASH=$(sha256_file "$INPUT_PATH")

# Pull the few identity fields for the receipt even on early rejection.
JUDGE_PROVIDER=$(jq -r '.judge.provider // ""' "$INPUT_PATH")
JUDGE_MODEL=$(jq -r '.judge.model // ""' "$INPUT_PATH")
JUDGE_ID=$(jq -r '.judge.id // ""' "$INPUT_PATH")
JUDGE_MODEL_VERSION=$(jq -r '.judge.model_version // ""' "$INPUT_PATH")
JUDGE_SYSTEM_PROMPT_SHA=$(jq -r '.judge.system_prompt_sha256 // ""' "$INPUT_PATH")
JUDGE_SAMPLING_SHA=$(jq -r '.judge.sampling_sha256 // ""' "$INPUT_PATH")
HOLDOUT_CORPUS_RECEIPT=$(jq -r '.calibration.holdout_corpus_receipt_sha256 // ""' "$INPUT_PATH")
TUNING_CORPUS_RECEIPT=$(jq -r '.calibration.tuning_corpus_receipt_sha256 // ""' "$INPUT_PATH")
SOURCE_SNAPSHOT=$(jq -r '.freeze.source_snapshot_sha256 // ""' "$INPUT_PATH")
INVOCATION_ADAPTER_SHA=$(jq -r '.freeze.invocation_adapter_sha256 // ""' "$INPUT_PATH")

# --------------------------------------------------------------------------
# stage 1: bind the human-labelled held-out labels file (a real file on disk)
# --------------------------------------------------------------------------
LABELS_REL=$(jq -r '.calibration.holdout_labels.path // ""' "$INPUT_PATH")
LABELS_DECL=$(jq -r '.calibration.holdout_labels.sha256 // ""' "$INPUT_PATH")
if [ -z "$LABELS_REL" ] || ! safe_regular_file "$ARTIFACT_ROOT" "$LABELS_REL"; then
  fail_closed 'rejected: held-out labels file is missing or unsafe' fixture_only '["LABELS_INVALID"]' "$INPUT_HASH"
fi
LABELS_PATH="$ARTIFACT_ROOT/$LABELS_REL"
if ! regular_json_without_duplicate_keys "$LABELS_PATH"; then
  fail_closed 'rejected: held-out labels file is not clean JSON' fixture_only '["LABELS_INVALID"]' "$INPUT_HASH"
fi
HOLDOUT_LABELS_SHA=$(sha256_file "$LABELS_PATH")
if [ "$HOLDOUT_LABELS_SHA" != "$LABELS_DECL" ]; then
  fail_closed 'rejected: held-out labels digest does not match the declared binding' fixture_only '["LABELS_INVALID"]' "$INPUT_HASH"
fi

# --------------------------------------------------------------------------
# stage 2: resolve every image and raw-response artifact, recompute digests,
#          and re-parse each verdict.  Emit a resolved-artifact table.
# --------------------------------------------------------------------------
UNIT_COUNT=$(jq '(.units | if type == "array" then length else 0 end)' "$INPUT_PATH")
: >"$SCRATCH/resolved.tsv"

resolve_response() { # unit-index side
  local i=$1 side=$2 path inline decl src actual final cfile
  path=$(jq -r ".units[$i].$side.raw_response.path // \"\"" "$INPUT_PATH")
  inline=$(jq -r "if (.units[$i].$side.raw_response | type) == \"object\" and (.units[$i].$side.raw_response | has(\"inline\")) then \"yes\" else \"no\" end" "$INPUT_PATH")
  decl=$(jq -r ".units[$i].$side.raw_response.sha256 // \"\"" "$INPUT_PATH")
  cfile="$SCRATCH/resp.$i.$side"
  if [ -n "$path" ]; then
    if safe_regular_file "$ARTIFACT_ROOT" "$path"; then
      src="file"; actual=$(sha256_file "$ARTIFACT_ROOT/$path"); final=$(parse_final "$ARTIFACT_ROOT/$path")
    else
      src=badpath; actual=''; final=NONE
    fi
  elif [ "$inline" = yes ]; then
    jq -j ".units[$i].$side.raw_response.inline" "$INPUT_PATH" >"$cfile"
    src=inline; actual=$(sha256_file "$cfile"); final=$(parse_final "$cfile")
  else
    src=none; actual=''; final=NONE
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$i:$side" "$src" "$decl" "$actual" "$final" >>"$SCRATCH/resolved.tsv"
}

resolve_image() { # unit-index
  local i=$1 path decl src actual
  path=$(jq -r ".units[$i].image.path // \"\"" "$INPUT_PATH")
  decl=$(jq -r ".units[$i].image.sha256 // \"\"" "$INPUT_PATH")
  if [ -n "$path" ]; then
    if safe_regular_file "$ARTIFACT_ROOT" "$path"; then
      src="file"; actual=$(sha256_file "$ARTIFACT_ROOT/$path")
    else
      src=badpath; actual=''
    fi
  else
    src=sha_only; actual=''
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$i:image" "$src" "$decl" "$actual" '' >>"$SCRATCH/resolved.tsv"
}

if [ "$UNIT_COUNT" -gt 0 ]; then
  i=0
  while [ "$i" -lt "$UNIT_COUNT" ]; do
    resolve_response "$i" primary
    resolve_response "$i" mirror
    resolve_image "$i"
    i=$((i + 1))
  done
fi

# resolved.tsv -> resolved.json keyed by "i:side" / "i:image"
jq -R -s '
  split("\n") | map(select(length > 0) | split("\t"))
  | map({key: .[0], value: {src: .[1], decl: .[2], actual: .[3], final: .[4]}})
  | from_entries
' "$SCRATCH/resolved.tsv" >"$SCRATCH/resolved.json"

# --------------------------------------------------------------------------
# stage 3: closed-schema validation + per-unit recompute (structural codes).
#          Trust nothing: gold from labels, vote from parsed verdict, digests
#          from the resolved table.  Aggregate counts come back to bash.
# --------------------------------------------------------------------------
STRUCT=$(jq -n \
  --slurpfile input "$INPUT_PATH" \
  --slurpfile labels "$LABELS_PATH" \
  --slurpfile resolved "$SCRATCH/resolved.json" \
  --arg pinned_parser "$PINNED_PARSER_SHA" '
  def hex64: type == "string" and test("^[0-9a-f]{64}$");
  def nonempty: type == "string" and length > 0;
  def stimid: type == "string" and test("^stim-[a-z0-9-]{3,}$");
  def pos($tok): if $tok == "FIRST" then 1 elif $tok == "SECOND" then 2 elif $tok == "ABSTAIN" then 0 else -1 end;
  def ballot_shape($b): ($b | type) == "object"
      and (($b | keys) - ["abstain_reason"] | sort) == ["identity_visible","injection_detected","invocation","judge_discussion","orientation","prior_ballots_visible","raw_response"]
      and ($b.orientation | type == "array" and length == 2 and (unique | length) == 2 and all(.[]; stimid))
      and ($b.raw_response | type == "object")
      and ($b.invocation | type == "object" and (keys | sort) == ["adapter_sha256","model","model_version","parser_sha256","provider","sampling_sha256","system_prompt_sha256"]);
  def raw_shape($b): ($b.raw_response | (keys | sort) as $k | ($k == ["inline","sha256"]) or ($k == ["path","sha256"]));
  def blind($b): ($b.identity_visible == false and $b.prior_ballots_visible == false and $b.injection_detected == false and $b.judge_discussion == false);
  def inv_ok($b; $fz): ($b.invocation.provider == $fz.provider and $b.invocation.model == $fz.model
      and $b.invocation.model_version == $fz.model_version
      and $b.invocation.system_prompt_sha256 == $fz.system_prompt_sha256
      and $b.invocation.sampling_sha256 == $fz.sampling_sha256
      and $b.invocation.parser_sha256 == $pinned_parser
      and $b.invocation.adapter_sha256 == $fz.invocation_adapter_sha256);
  def resp_code($r):
      if $r == null then ["SCHEMA_REJECTED"]
      elif $r.src == "badpath" then ["SYNTHETIC_RECEIPT"]
      elif $r.src == "none" then ["SCHEMA_REJECTED"]
      elif ($r.actual != $r.decl) then ["RESPONSE_HASH_MISMATCH"]
      elif ($r.final == "NONE") then ["RESPONSE_UNPARSEABLE"]
      else [] end;
  ($input[0]) as $in
  | ($labels[0]) as $lab
  | ($resolved[0]) as $res

  # ---- freeze block ----
  | ($in.freeze) as $fz
  | ([ if ($fz | type) != "object"
         or (($fz | keys | sort) != ["image_orientation_frozen","invocation_adapter_sha256","model","model_version","provider","response_parser_sha256","sampling_sha256","source_snapshot_sha256","system_prompt_sha256"])
       then "SCHEMA_REJECTED" else empty end,
       if ($fz | type) == "object" and $fz.image_orientation_frozen != true then "SCHEMA_REJECTED" else empty end,
       if ($fz | type) == "object" and (($fz.provider | nonempty) and ($fz.model | nonempty) and ($fz.model_version | nonempty) | not) then "SCHEMA_REJECTED" else empty end,
       if ($fz | type) == "object" and ([$fz.system_prompt_sha256,$fz.sampling_sha256,$fz.source_snapshot_sha256,$fz.invocation_adapter_sha256] | all(hex64) | not) then "SCHEMA_REJECTED" else empty end,
       if ($fz | type) == "object" and ($fz.response_parser_sha256 | hex64 | not) then "SCHEMA_REJECTED" else empty end,
       if ($fz | type) == "object" and $fz.response_parser_sha256 != $pinned_parser then "PARSER_CHANGED" else empty end
     ]) as $freeze_codes

  # ---- top level + calibration + judge ----
  | ([ if ($in | type) != "object" or (($in | keys | sort) != ["calibration","freeze","judge","schema_version","units"]) then "SCHEMA_REJECTED" else empty end,
       if $in.schema_version != 2 then "SCHEMA_REJECTED" else empty end,
       if ($in.calibration | type) != "object"
          or (($in.calibration | keys | sort) != ["dataset_id","holdout_corpus_receipt_sha256","holdout_labels","label_provenance","partition","tuning_corpus_receipt_sha256"])
          then "SCHEMA_REJECTED" else empty end,
       if ($in.calibration | type) == "object" and $in.calibration.partition != "held_out" then "SCHEMA_REJECTED" else empty end,
       if ($in.calibration | type) == "object" and $in.calibration.label_provenance != "human-labeled" then "SCHEMA_REJECTED" else empty end,
       if ($in.calibration | type) == "object" and ($in.calibration.dataset_id | nonempty | not) then "SCHEMA_REJECTED" else empty end,
       if ($in.calibration | type) == "object" and ([$in.calibration.holdout_corpus_receipt_sha256,$in.calibration.tuning_corpus_receipt_sha256] | all(hex64) | not) then "SCHEMA_REJECTED" else empty end,
       if ($in.calibration | type) == "object" and ($in.calibration.holdout_labels | type != "object" or (keys | sort) != ["path","sha256"] or (.path | nonempty | not) or (.sha256 | hex64 | not)) then "SCHEMA_REJECTED" else empty end,
       if ($in.calibration | type) == "object" and $in.calibration.tuning_corpus_receipt_sha256 == $in.calibration.holdout_corpus_receipt_sha256 then "TUNING_HOLDOUT_OVERLAP" else empty end,
       if ($in.judge | type) != "object" or (($in.judge | keys | sort) != ["id","model","model_version","provider","sampling_sha256","system_prompt_sha256"]) then "SCHEMA_REJECTED" else empty end,
       if ($in.judge | type) == "object" and ($in.judge.id | type != "string" or (test("^judge-[a-z0-9-]{3,}$") | not)) then "SCHEMA_REJECTED" else empty end,
       if ($in.judge | type) == "object" and (has("eligible") or has("eligibility") or has("eligibility_receipt") or has("result")) then "SCHEMA_REJECTED" else empty end
     ]) as $head_codes

  # ---- judge bound to freeze ----
  | (if ($in.judge | type) == "object" and ($fz | type) == "object"
        and ($in.judge.provider == $fz.provider and $in.judge.model == $fz.model
             and $in.judge.model_version == $fz.model_version
             and $in.judge.system_prompt_sha256 == $fz.system_prompt_sha256
             and $in.judge.sampling_sha256 == $fz.sampling_sha256)
     then [] else ["INVOCATION_DRIFT"] end) as $judge_bind_codes

  # ---- labels file ----
  | ([ if ($lab | type) != "object" or (($lab | keys | sort) != ["dataset_id","labels","partition","schema_version","source_snapshot_sha256","tuning_image_shas"]) then "LABELS_INVALID" else empty end,
       if ($lab | type) == "object" and $lab.schema_version != "taste-holdout-labels/v1" then "LABELS_INVALID" else empty end,
       if ($lab | type) == "object" and $lab.partition != "held_out" then "LABELS_INVALID" else empty end,
       if ($lab | type) == "object" and ($lab.source_snapshot_sha256 | hex64 | not) then "LABELS_INVALID" else empty end,
       if ($lab | type) == "object" and ($lab.tuning_image_shas | type != "array" or (all(.[]; hex64) | not)) then "LABELS_INVALID" else empty end,
       if ($lab | type) == "object" and ($lab.labels | type != "array" or length == 0) then "LABELS_INVALID"
       elif ($lab | type) == "object" and ($lab.labels | all(.[];
              type == "object" and (keys | sort) == ["correct_stimulus","image_sha256","stimulus_ids","unit_id"]
              and (.unit_id | nonempty) and (.image_sha256 | hex64)
              and (.stimulus_ids | type == "array" and length == 2 and (unique | length) == 2 and all(.[]; stimid))
              and (.correct_stimulus as $c | .stimulus_ids | index($c) != null)) | not)
         then "LABELS_INVALID" else empty end,
       if ($lab | type) == "object" and ($fz | type) == "object" and ($fz.source_snapshot_sha256 | hex64)
          and $lab.source_snapshot_sha256 != $fz.source_snapshot_sha256 then "STALE_SOURCE" else empty end
     ]) as $labels_codes

  | (if ($lab | type) == "object" and ($lab.labels | type) == "array"
     then (reduce $lab.labels[] as $l ({}; . + {($l.unit_id): $l})) else {} end) as $lmap
  | (if ($lab | type) == "object" and ($lab.tuning_image_shas | type) == "array" then $lab.tuning_image_shas else [] end) as $tun

  # ---- units array ----
  | ([ if ($in.units | type) != "array" then "SCHEMA_REJECTED" else empty end,
       if ($in.units | type) == "array" and (($in.units | length) < 24) then "ACCURACY_FLOOR" else empty end,
       if ($in.units | type) == "array" and (($in.units | map([(.prompt? // null), (.image?.sha256? // null)]) | unique | length) != ($in.units | length)) then "DUPLICATE_UNIT" else empty end,
       if ($in.units | type) == "array" and (($in.units | map(.unit_id? // null) | unique | length) != ($in.units | length)) then "DUPLICATE_UNIT" else empty end
     ]) as $units_codes

  # ---- per-unit recompute ----
  | (if ($in.units | type) == "array" then $in.units else [] end) as $units
  | ([ range(0; ($units | length)) as $i
       | $units[$i] as $u
       | ($res["\($i):primary"]) as $rp
       | ($res["\($i):mirror"]) as $rm
       | ($res["\($i):image"]) as $ri
       | ($lmap[$u.unit_id] // null) as $L
       | ($u | type == "object" and ((keys | sort) == ["brief","image","mirror","primary","prompt","unit_id"])) as $ushape
       | (if $ushape
          then ([ (if ($u.unit_id | nonempty) then [] else ["SCHEMA_REJECTED"] end),
                  (if ($u.prompt | nonempty) then [] else ["SCHEMA_REJECTED"] end),
                  (if ($u.brief | nonempty) then [] else ["SCHEMA_REJECTED"] end),
                  (if ($u.image | type == "object" and (((keys | sort) == ["sha256"]) or ((keys | sort) == ["path","sha256"])) and (.sha256 | hex64)) then [] else ["SCHEMA_REJECTED"] end),
                  (if ballot_shape($u.primary) and raw_shape($u.primary) then [] else ["SCHEMA_REJECTED"] end),
                  (if ballot_shape($u.mirror) and raw_shape($u.mirror) then [] else ["SCHEMA_REJECTED"] end)
                ] | add)
          else ["SCHEMA_REJECTED"] end) as $shape_codes
       | (if ($shape_codes | length) > 0
          then {codes: $shape_codes, correct: false, abstain: false, scored: false, side: 0}
          else
            ($L) as $L
            | ($u.primary) as $bp | ($u.mirror) as $bm
            | (pos($rp.final)) as $pp | (pos($rm.final)) as $pm
            | (if $pp == 1 then $bp.orientation[0] elif $pp == 2 then $bp.orientation[1] else "abstain" end) as $cp
            | (if $pm == 1 then $bm.orientation[0] elif $pm == 2 then $bm.orientation[1] else "abstain" end) as $cm
            | ([ resp_code($rp), resp_code($rm),
                 (if ($ri == null) or ($ri.src == "badpath") then ["SYNTHETIC_RECEIPT"]
                  elif ($ri.src == "file") and ($ri.actual != $ri.decl) then ["IMAGE_BINDING"]
                  else [] end),
                 (if $L == null then ["IMAGE_BINDING"]
                  elif $L.image_sha256 != $u.image.sha256 then ["IMAGE_BINDING"] else [] end),
                 (if ($L != null) and ($tun | index($u.image.sha256)) != null then ["TUNING_HOLDOUT_OVERLAP"] else [] end),
                 (if blind($bp) and blind($bm) then [] else ["IDENTITY_LEAK"] end),
                 (if inv_ok($bp; $fz) and inv_ok($bm; $fz) then [] else ["INVOCATION_DRIFT"] end),
                 (if ($bm.orientation == [$bp.orientation[1], $bp.orientation[0]]) then [] else ["ORIENTATION_NOT_MIRRORED"] end),
                 (if ($L != null) and (($bp.orientation | sort) == ($L.stimulus_ids | sort)) then [] else ["IMAGE_BINDING"] end),
                 # abstention must be paired and documented
                 (if ($pp == 0) or ($pm == 0)
                  then (if ($pp == 0 and $pm == 0
                            and ($bp.abstain_reason | type == "string" and length > 0)
                            and ($bm.abstain_reason | type == "string" and length > 0))
                        then [] else ["INVALID_ABSTENTION"] end)
                  else (if ($bp | has("abstain_reason")) or ($bm | has("abstain_reason")) then ["INVALID_ABSTENTION"] else [] end)
                  end)
               ] | add) as $ucodes
            | (($pp == 0) and ($pm == 0)) as $abstain
            | (($abstain | not) and ($pp > 0) and ($pm > 0)) as $scored
            | (if $L == null then false else ($cp == $L.correct_stimulus and $cm == $L.correct_stimulus) end) as $is_correct
            | {codes: $ucodes,
               correct: ($is_correct and ($ucodes | length) == 0),
               abstain: $abstain,
               scored: $scored,
               side_left: (if $scored and ($pp == 1) then 1 else 0 end),
               contradiction: (if $scored and ($cp != $cm) then 1 else 0 end)}
          end)
     ]) as $per

  # ---- classification: every image + both responses are hash-matched files ----
  | (($units | length) > 0
     and ([ range(0; ($units | length)) as $i
            | ($res["\($i):image"].src == "file")
              and ($res["\($i):primary"].src == "file")
              and ($res["\($i):mirror"].src == "file") ] | all)) as $all_file

  | {codes: (($freeze_codes + $head_codes + $judge_bind_codes + $labels_codes + $units_codes + [$per[].codes[]]) | unique),
     units: ($units | length),
     correct: ([$per[] | select(.correct)] | length),
     scored: ([$per[] | select(.scored)] | length),
     side_left: ([$per[] | select(.scored) | .side_left] | add // 0),
     contradictions: ([$per[] | select(.scored) | .contradiction] | add // 0),
     all_file: $all_file}
')

STRUCT_CODES=$(printf '%s' "$STRUCT" | jq -c '.codes')
UNITS=$(printf '%s' "$STRUCT" | jq '.units')
CORRECT=$(printf '%s' "$STRUCT" | jq '.correct')
SCORED=$(printf '%s' "$STRUCT" | jq '.scored')
SIDE_LEFT=$(printf '%s' "$STRUCT" | jq '.side_left')
CONTRA=$(printf '%s' "$STRUCT" | jq '.contradictions')
ALL_FILE=$(printf '%s' "$STRUCT" | jq '.all_file')

CLASSIFICATION=fixture_only
if [ "$ALL_FILE" = true ]; then CLASSIFICATION=production; fi

# --------------------------------------------------------------------------
# stage 4: recomputed statistics (Wilson lower bound + two-sided exact binomial)
# --------------------------------------------------------------------------
if [ "$UNITS" -gt 0 ]; then
  WILSON=$(awk -v correct="$CORRECT" -v total="$UNITS" 'BEGIN {
    z = 1.959963984540054
    p = correct / total
    z2 = z * z
    lower = (p + z2 / (2 * total) - z * sqrt((p * (1 - p) + z2 / (4 * total)) / total)) / (1 + z2 / total)
    printf "%.6f", lower
  }')
else
  WILSON=0
fi
SIDE_PROBE_N=$SCORED
MIRROR_PROBE_N=$SCORED
if [ "$SIDE_PROBE_N" -gt 0 ]; then
  SIDE_PROBE_P=$(awk -v left="$SIDE_LEFT" -v total="$SIDE_PROBE_N" 'BEGIN {
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
else
  SIDE_PROBE_P=0.000000
fi

# --------------------------------------------------------------------------
# stage 5: threshold gates.  Any structural code or floor breach => ineligible.
# --------------------------------------------------------------------------
THRESHOLD_CODES=''
add_threshold() { THRESHOLD_CODES="$THRESHOLD_CODES $1"; }

[ "$UNITS" -ge 24 ] || add_threshold ACCURACY_FLOOR
[ "$CORRECT" -ge 17 ] || add_threshold ACCURACY_FLOOR
awk -v v="$WILSON" 'BEGIN { exit !(v >= 0.50) }' || add_threshold WILSON_FLOOR
[ "$SIDE_PROBE_N" -ge 12 ] || add_threshold SIDE_BIAS
awk -v v="$SIDE_PROBE_P" 'BEGIN { exit !(v >= 0.05) }' || add_threshold SIDE_BIAS
[ "$MIRROR_PROBE_N" -ge 8 ] || add_threshold MIRROR_INSTABILITY
[ "$CONTRA" -lt 2 ] || add_threshold MIRROR_INSTABILITY

# Merge structural + threshold codes, dedupe, and stable-sort.
ALL_CODES=$(jq -cn --argjson s "$STRUCT_CODES" --arg t "$THRESHOLD_CODES" '
  ($t | split(" ") | map(select(length > 0))) as $tc
  | ($s + $tc) | unique')

CODE_COUNT=$(printf '%s' "$ALL_CODES" | jq 'length')

if [ "$CODE_COUNT" -eq 0 ]; then
  emit_receipt true 'eligible: held-out human-labelled mirrored calibration recomputed and bound' \
    "$CLASSIFICATION" '[]' "$UNITS" "$CORRECT" "$WILSON" "$SIDE_PROBE_N" "$SIDE_PROBE_P" \
    "$MIRROR_PROBE_N" "$CONTRA" "$INPUT_HASH" "$JUDGE_PROVIDER" "$JUDGE_MODEL" "$ALL_FILE"
  exit 0
fi

FIRST_CODE=$(printf '%s' "$ALL_CODES" | jq -r '.[0]')
emit_receipt false "ineligible: $FIRST_CODE" "$CLASSIFICATION" "$ALL_CODES" \
  "$UNITS" "$CORRECT" "$WILSON" "$SIDE_PROBE_N" "$SIDE_PROBE_P" \
  "$MIRROR_PROBE_N" "$CONTRA" "$INPUT_HASH" "$JUDGE_PROVIDER" "$JUDGE_MODEL" "$ALL_FILE"
exit 1
