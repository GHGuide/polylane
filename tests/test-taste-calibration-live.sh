#!/usr/bin/env bash
# Regression tests for the production judge-eligibility receipt v2
# (bin/polylane-taste-calibration-live.sh).  Trust-boundary negative tests
# dominate: every reject class in the lane contract has a red-first case.
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
BIN="$ROOT/bin/polylane-taste-calibration-live.sh"
TMPDIR_TEST=$(mktemp -d "${TMPDIR:-/tmp}/polylane-taste-calibration-live.XXXXXX")
trap 'rm -rf "$TMPDIR_TEST"' EXIT HUP INT TERM
PARSER_SHA=$("$BIN" parser-sha)

fail() { printf 'FAIL %s\n' "$*" >&2; exit 1; }
h()  { printf '%s' "$1" | shasum -a 256 | awk '{print $1}'; }         # hash a string
hf() { shasum -a 256 "$1" | awk '{print $1}'; }                        # hash a file
rep64() { printf '%*s' 64 '' | tr ' ' "$1"; }                          # 64 copies of a char
tok() { case "$1" in 1) printf FIRST;; 2) printf SECOND;; 0) printf ABSTAIN;; esac; }
mk() { local d="$TMPDIR_TEST/$1"; rm -rf "$d"; mkdir -p "$d"; printf '%s' "$d"; }

SP=$(rep64 1); SAMP=$(rep64 2); SRC=$(rep64 3); ADAPTER=$(rep64 4)
CORPUS=$(rep64 a); TUNING=$(rep64 b)
PROV=example-provider; MODEL=example-model; MV=2026.08

# build_case DIR CORRECT [UNITS] [MODE(inline|file|sidebias)]
build_case() {
  local root=$1 correct=$2 units=${3:-24} mode=${4:-inline}
  local labels="$root/labels.json" input="$root/input.json"
  local labels_arr='[]' units_arr='[]' i
  for ((i = 0; i < units; i++)); do
    local A="stim-u${i}a" B="stim-u${i}b" gold_pos ppos mpos o0 o1 mo0 mo1
    gold_pos=$(( i % 2 == 0 ? 1 : 2 ))
    if [ "$i" -lt "$correct" ]; then ppos=$gold_pos; mpos=$((3 - gold_pos)); else ppos=$((3 - gold_pos)); mpos=$gold_pos; fi
    if [ "$gold_pos" -eq 1 ]; then o0=$A; o1=$B; else o0=$B; o1=$A; fi
    mo0=$o1; mo1=$o0
    if [ "$mode" = sidebias ]; then ppos=1; mpos=1; fi
    local praw mraw psha msha ppath mpath imgsha imgpath
    praw="Unit $i primary assessment of the pair."$'\n'"FINAL: $(tok "$ppos")"
    mraw="Unit $i mirror assessment of the pair."$'\n'"FINAL: $(tok "$mpos")"
    ppath=""; mpath=""; imgpath=""
    if [ "$mode" = file ]; then
      ppath="resp-$i-primary.txt"; mpath="resp-$i-mirror.txt"; imgpath="img-$i.png"
      printf '%s' "$praw" > "$root/$ppath"; printf '%s' "$mraw" > "$root/$mpath"
      printf 'PNGBYTES-unit-%s' "$i" > "$root/$imgpath"
      psha=$(hf "$root/$ppath"); msha=$(hf "$root/$mpath"); imgsha=$(hf "$root/$imgpath")
    else
      psha=$(h "$praw"); msha=$(h "$mraw"); imgsha=$(h "image-unit-$i")
    fi
    units_arr=$(jq -n --argjson acc "$units_arr" \
      --arg uid "unit-$i" --arg prompt "prompt-$i" --arg brief "brief-$i" \
      --arg imgsha "$imgsha" --arg imgpath "$imgpath" \
      --arg o0 "$o0" --arg o1 "$o1" --arg mo0 "$mo0" --arg mo1 "$mo1" \
      --arg praw "$praw" --arg psha "$psha" --arg ppath "$ppath" \
      --arg mraw "$mraw" --arg msha "$msha" --arg mpath "$mpath" \
      --arg prov "$PROV" --arg model "$MODEL" --arg mv "$MV" --arg sp "$SP" \
      --arg samp "$SAMP" --arg parser "$PARSER_SHA" --arg adapter "$ADAPTER" --arg mode "$mode" '
      def inv: {provider:$prov, model:$model, model_version:$mv, system_prompt_sha256:$sp, sampling_sha256:$samp, parser_sha256:$parser, adapter_sha256:$adapter};
      def img: if $mode == "file" then {path:$imgpath, sha256:$imgsha} else {sha256:$imgsha} end;
      def resp($raw; $sha; $path): if $mode == "file" then {path:$path, sha256:$sha} else {inline:$raw, sha256:$sha} end;
      $acc + [ {
        unit_id:$uid, prompt:$prompt, brief:$brief, image:img,
        primary:{orientation:[$o0,$o1], raw_response:resp($praw;$psha;$ppath), invocation:inv,
                 identity_visible:false, prior_ballots_visible:false, injection_detected:false, judge_discussion:false},
        mirror:{orientation:[$mo0,$mo1], raw_response:resp($mraw;$msha;$mpath), invocation:inv,
                identity_visible:false, prior_ballots_visible:false, injection_detected:false, judge_discussion:false}
      } ]')
    labels_arr=$(jq -n --argjson acc "$labels_arr" --arg uid "unit-$i" --arg imgsha "$imgsha" --arg A "$A" --arg B "$B" '
      $acc + [ {unit_id:$uid, image_sha256:$imgsha, stimulus_ids:[$A,$B], correct_stimulus:$A} ]')
  done
  jq -n --argjson labels "$labels_arr" --arg src "$SRC" '
    {schema_version:"taste-holdout-labels/v1", dataset_id:"human-ui-holdout-v1", partition:"held_out",
     source_snapshot_sha256:$src, tuning_image_shas:[], labels:$labels}' > "$labels"
  local labels_sha; labels_sha=$(hf "$labels")
  jq -n --argjson units "$units_arr" --arg labels_sha "$labels_sha" \
    --arg prov "$PROV" --arg model "$MODEL" --arg mv "$MV" --arg sp "$SP" --arg samp "$SAMP" \
    --arg parser "$PARSER_SHA" --arg adapter "$ADAPTER" --arg src "$SRC" \
    --arg corpus "$CORPUS" --arg tuning "$TUNING" '
    {schema_version:2,
     calibration:{dataset_id:"human-ui-holdout-v1", partition:"held_out", label_provenance:"human-labeled",
                  holdout_corpus_receipt_sha256:$corpus, tuning_corpus_receipt_sha256:$tuning,
                  holdout_labels:{path:"labels.json", sha256:$labels_sha}},
     freeze:{provider:$prov, model:$model, model_version:$mv, system_prompt_sha256:$sp, sampling_sha256:$samp,
             response_parser_sha256:$parser, invocation_adapter_sha256:$adapter, source_snapshot_sha256:$src,
             image_orientation_frozen:true},
     judge:{id:"judge-live-001", provider:$prov, model:$model, model_version:$mv, system_prompt_sha256:$sp, sampling_sha256:$samp},
     units:$units}' > "$input"
}

# Re-sha labels.json after an in-place edit and re-bind it in input.json.
rebind_labels() {
  local root=$1 s; s=$(hf "$root/labels.json")
  jq --arg s "$s" '.calibration.holdout_labels.sha256 = $s' "$root/input.json" > "$root/input.json.n"
  mv "$root/input.json.n" "$root/input.json"
}
edit() { # root jq-program
  jq "$2" "$1/input.json" > "$1/input.json.n" && mv "$1/input.json.n" "$1/input.json"
}
run()  { "$BIN" "$1/input.json" "$1/out.json"; }

assert_eligible() { # root name
  run "$1" || fail "$2: expected eligible exit 0"
  test "$(jq -r .eligible "$1/out.json")" = true || fail "$2: eligible must be true"
  test "$(jq -r '.reason_codes | length' "$1/out.json")" = 0 || fail "$2: eligible has no codes"
}
assert_rejected() { # root code name
  if run "$1"; then fail "$3: expected non-zero rejection"; fi
  test "$(jq -r .eligible "$1/out.json")" = false || fail "$3: eligible must be false"
  jq -e --arg c "$2" '.reason_codes | index($c) != null' "$1/out.json" >/dev/null \
    || fail "$3: expected code $2, got $(jq -c .reason_codes "$1/out.json")"
}

# ---------------------------------------------------------------- positive path
test_fixture_inline_eligible() {
  local d; d=$(mk eligible); build_case "$d" 17
  assert_eligible "$d" fixture_eligible
  test "$(jq -r .schema_version "$d/out.json")" = taste-calibration/v2 || fail 'schema_version v2'
  test "$(jq -r .classification "$d/out.json")" = fixture_only || fail 'inline record is fixture_only'
  test "$(jq -r .production "$d/out.json")" = false || fail 'inline record is not production'
  test "$(jq -r .fixture_only "$d/out.json")" = true || fail 'fixture_only true'
  test "$(jq -r .human_certified "$d/out.json")" = false || fail 'never human_certified'
  test "$(jq -r .machine_not_human "$d/out.json")" = true || fail 'machine_not_human'
  test "$(jq -r .machine_panel_claim "$d/out.json")" = HUMAN_CALIBRATED_MACHINE || fail 'claim label'
  test "$(jq -r .sample_units "$d/out.json")" = 24 || fail 'sample_units 24'
  test "$(jq -r .correct_units "$d/out.json")" = 17 || fail 'correct_units 17'
  test "$(jq -r .human_labelled_pairs "$d/out.json")" = 24 || fail 'human_labelled_pairs 24'
  test "$(jq -r '.side_probe_n >= 12 and .mirror_probe_n >= 8 and .mirror_contradictions < 2' "$d/out.json")" = true || fail 'probes pass'
  awk -v v="$(jq -r .wilson_lower_bound "$d/out.json")" 'BEGIN{exit !(v>=0.50)}' || fail 'wilson >= 0.50'
  awk -v v="$(jq -r .accuracy "$d/out.json")" 'BEGIN{exit !(v>0.70 && v<0.71)}' || fail 'accuracy 17/24'
  test "$(jq -r .response_parser_sha256 "$d/out.json")" = "$PARSER_SHA" || fail 'parser sha bound'
  test "$(jq -r .source_snapshot_sha256 "$d/out.json")" = "$SRC" || fail 'source snapshot bound'
  test "$(jq -r .judge_id "$d/out.json")" = judge-live-001 || fail 'judge id bound'
  test "$(jq -r '.judge_configuration.kind' "$d/out.json")" = machine || fail 'machine kind'
  test "$(jq -r .validator.id "$d/out.json")" = polylane-taste-calibration-live || fail 'validator id'
  test "$(jq -r .validator.fingerprint "$d/out.json")" = "$(hf "$BIN")" || fail 'validator fingerprint'
  test "$(jq -r .input_sha256 "$d/out.json")" = "$(hf "$d/input.json")" || fail 'input sha bound'
}

test_more_than_24_units() {
  local d; d=$(mk twentysix); build_case "$d" 26 26
  assert_eligible "$d" twentysix
  test "$(jq -r .sample_units "$d/out.json")" = 26 || fail 'exact 26 units, not constant 24'
  test "$(jq -r .correct_units "$d/out.json")" = 26 || fail 'exact 26 correct'
}

test_production_file_backed() {
  local d; d=$(mk production); build_case "$d" 17 24 file
  assert_eligible "$d" production
  test "$(jq -r .classification "$d/out.json")" = production || fail 'file-backed record is production'
  test "$(jq -r .production "$d/out.json")" = true || fail 'production true'
  test "$(jq -r .fixture_only "$d/out.json")" = false || fail 'not fixture_only'
  test "$(jq -r .bound_response_units "$d/out.json")" = true || fail 'bound responses'
}

test_paired_abstention_allowed() {
  local d; d=$(mk abstain); build_case "$d" 17
  local araw; araw="Unit 20 is genuinely ambiguous."$'\n'"FINAL: ABSTAIN"; local asha; asha=$(h "$araw")
  jq --arg r "$araw" --arg s "$asha" \
     '.units[20].primary.raw_response = {inline:$r, sha256:$s}
      | .units[20].primary.abstain_reason = "ambiguous pair"
      | .units[20].mirror.raw_response = {inline:$r, sha256:$s}
      | .units[20].mirror.abstain_reason = "ambiguous pair"' "$d/input.json" > "$d/input.json.n"
  mv "$d/input.json.n" "$d/input.json"
  assert_eligible "$d" abstain
  test "$(jq -r .side_probe_n "$d/out.json")" = 23 || fail 'abstained unit excluded from side probe'
}

# ---------------------------------------------------------------- reject matrix
test_reject_accuracy_floor()   { local d; d=$(mk acc);   build_case "$d" 16; assert_rejected "$d" ACCURACY_FLOOR acc; }
test_reject_wilson_floor()     { local d; d=$(mk wil);   build_case "$d" 24 40; assert_rejected "$d" WILSON_FLOOR wilson; }
test_reject_side_bias()        { local d; d=$(mk side);  build_case "$d" 17 24 sidebias; assert_rejected "$d" SIDE_BIAS side; }

test_reject_response_hash_mismatch() {
  local d; d=$(mk rhash); build_case "$d" 17
  edit "$d" '.units[0].primary.raw_response.sha256 = "'"$(rep64 c)"'"'
  assert_rejected "$d" RESPONSE_HASH_MISMATCH rhash
}
test_reject_parser_changed() {
  local d; d=$(mk parser); build_case "$d" 17
  edit "$d" '.freeze.response_parser_sha256 = "'"$(rep64 d)"'"'
  assert_rejected "$d" PARSER_CHANGED parser
}
test_reject_invocation_drift() {
  local d; d=$(mk inv); build_case "$d" 17
  edit "$d" '.units[0].primary.invocation.model = "other-model"'
  assert_rejected "$d" INVOCATION_DRIFT inv
}
test_reject_identity_leak() {
  local d; d=$(mk leak); build_case "$d" 17
  edit "$d" '.units[0].primary.identity_visible = true'
  assert_rejected "$d" IDENTITY_LEAK leak
}
test_reject_orientation_not_mirrored() {
  local d; d=$(mk orient); build_case "$d" 17
  edit "$d" '.units[0].mirror.orientation = .units[0].primary.orientation'
  assert_rejected "$d" ORIENTATION_NOT_MIRRORED orient
}
test_reject_invalid_abstention() {
  local d; d=$(mk absbad); build_case "$d" 17
  local araw; araw="Ambiguous."$'\n'"FINAL: ABSTAIN"; local asha; asha=$(h "$araw")
  jq --arg r "$araw" --arg s "$asha" \
     '.units[19].primary.raw_response = {inline:$r, sha256:$s} | .units[19].primary.abstain_reason = "ambiguous"' \
     "$d/input.json" > "$d/input.json.n"
  mv "$d/input.json.n" "$d/input.json"
  assert_rejected "$d" INVALID_ABSTENTION absbad
}
test_reject_stale_source() {
  local d; d=$(mk stale); build_case "$d" 17
  jq '.source_snapshot_sha256 = "'"$(rep64 e)"'"' "$d/labels.json" > "$d/labels.json.n"
  mv "$d/labels.json.n" "$d/labels.json"; rebind_labels "$d"
  assert_rejected "$d" STALE_SOURCE stale
}
test_reject_tuning_overlap() {
  local d; d=$(mk overlap); build_case "$d" 17
  local s0; s0=$(jq -r '.units[0].image.sha256' "$d/input.json")
  jq --arg s "$s0" '.tuning_image_shas = [$s]' "$d/labels.json" > "$d/labels.json.n"
  mv "$d/labels.json.n" "$d/labels.json"; rebind_labels "$d"
  assert_rejected "$d" TUNING_HOLDOUT_OVERLAP overlap
}
test_reject_receipt_level_tuning_overlap() {
  local d; d=$(mk overlap2); build_case "$d" 17
  edit "$d" '.calibration.tuning_corpus_receipt_sha256 = .calibration.holdout_corpus_receipt_sha256'
  assert_rejected "$d" TUNING_HOLDOUT_OVERLAP overlap2
}
test_reject_unknown_field() {
  local d; d=$(mk unk); build_case "$d" 17
  edit "$d" '.units[0].extra = 1'
  assert_rejected "$d" SCHEMA_REJECTED unk
}
test_reject_self_attested_eligibility() {
  local d; d=$(mk selfatt); build_case "$d" 17
  edit "$d" '.judge.eligible = true'
  assert_rejected "$d" SCHEMA_REJECTED selfatt
}
test_reject_duplicate_unit() {
  local d; d=$(mk dup); build_case "$d" 17
  edit "$d" '.units += [.units[0]]'
  assert_rejected "$d" DUPLICATE_UNIT dup
}
test_reject_duplicate_keys() {
  local d; d=$(mk dupkey); build_case "$d" 17
  local txt; txt=$(cat "$d/input.json")
  printf '%s\n' "${txt/\"schema_version\": 2,/\"schema_version\": 2,\"schema_version\": 9,}" > "$d/input.json"
  assert_rejected "$d" JSON_INVALID dupkey
}
test_reject_synthetic_receipt() {
  local d; d=$(mk synth); build_case "$d" 17 24 file
  edit "$d" '.units[0].primary.raw_response.path = "does-not-exist.txt"'
  assert_rejected "$d" SYNTHETIC_RECEIPT synth
}
test_reject_labels_digest_tamper() {
  local d; d=$(mk labtamper); build_case "$d" 17
  jq '.dataset_id = "swapped-after-binding"' "$d/labels.json" > "$d/labels.json.n"
  mv "$d/labels.json.n" "$d/labels.json"   # change bytes but do NOT rebind
  assert_rejected "$d" LABELS_INVALID labtamper
}

test_fixture_inline_eligible
test_more_than_24_units
test_production_file_backed
test_paired_abstention_allowed
test_reject_accuracy_floor
test_reject_wilson_floor
test_reject_side_bias
test_reject_response_hash_mismatch
test_reject_parser_changed
test_reject_invocation_drift
test_reject_identity_leak
test_reject_orientation_not_mirrored
test_reject_invalid_abstention
test_reject_stale_source
test_reject_tuning_overlap
test_reject_receipt_level_tuning_overlap
test_reject_unknown_field
test_reject_self_attested_eligibility
test_reject_duplicate_unit
test_reject_duplicate_keys
test_reject_synthetic_receipt
test_reject_labels_digest_tamper

printf 'PASS test-taste-calibration-live assertions=22\n'
