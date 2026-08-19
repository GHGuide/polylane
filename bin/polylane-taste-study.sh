#!/usr/bin/env bash
# Frozen live taste-study compiler.
#
#   freeze  SPEC OUT
#     Preregister a study: lock baseline/current revisions, corpus hash+order,
#     provider/model configs, calibration sources/splits, panel cohorts,
#     thresholds, repair budget, evidence prefixes, claim, and analysis BEFORE any
#     result exists.  Writes a write-once taste-study-freeze/v1 whose freeze_sha256
#     is the SHA-256 of the canonical frozen constants.  Refuses to overwrite.
#
#   compile FREEZE MANIFEST CERT SUBJECT_ROOT
#     Compile a production old-versus-new study certificate.  The evidence
#     manifest must match every frozen constant (no post-freeze drift), the
#     subject may only advance by declared-evidence-only linear commits, and the
#     underlying taste-certificate/v2 is compiled in LIVE mode so v1/fixture
#     calibration, ballot, and threat receipts are rejected.  It never executes a
#     live study: a compiler cannot create a browser run, a human label, or an
#     independent panel, so live_study_executed is always false and the real
#     prerequisites are recorded as external.
#
#   hcm-split SPLIT | hcm-split-digest SPLIT
#     Bind a produced HCM-v2 target-matched split to the frozen
#     source_calibration.hcm_v2 block of CONTRACT-LOCK.v3.json: stratum counts,
#     excluded anchors, a self-consistent canonical digest, and a digest equal to
#     the frozen split_sha256.  Fails closed with reason codes; a digest that is
#     not the frozen one is a hard failure, never a warning.
#
#   hcm-exposure PLAN [OTHER_PLAN]
#     Bind a stimulus exposure ALLOCATION plan to the same frozen block:
#     viewports, per-participant pair and anchor caps, zero repeat exposures,
#     judgments per pair, participant/designer floors, and — with two plans —
#     that designer ballots stay separate from target-user ballots.
#
#   The HCM-v2 study itself is external (ethics review, recruiting, sealed
#   ballots).  These verbs bind a split and a plan; they never carry a judgment,
#   a consent signature, a participant, or a study result, and they cannot emit a
#   certified or human claim.
set -euo pipefail

usage() {
  printf '%s\n' \
    'usage: polylane-taste-study.sh freeze SPEC OUT' \
    '       polylane-taste-study.sh compile FREEZE MANIFEST CERT SUBJECT_ROOT' \
    '       polylane-taste-study.sh hcm-split SPLIT' \
    '       polylane-taste-study.sh hcm-split-digest SPLIT' \
    '       polylane-taste-study.sh hcm-exposure PLAN [OTHER_PLAN]' >&2
}

HERE=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
TASTE="$HERE/polylane-taste.sh"

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" 2>/dev/null | awk '{print $1}'
  else return 1; fi
}
sha256_stdin() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'
  else return 1; fi
}

regular_json_without_duplicate_keys() {
  local file=$1 duplicates
  [ -f "$file" ] && [ ! -L "$file" ] || return 1
  jq -e . "$file" >/dev/null 2>&1 || return 1
  duplicates=$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("")' "$file" 2>/dev/null | LC_ALL=C sort | uniq -d)
  [ -z "$duplicates" ]
}

# safe_rel ROOT REL: REL is a relative, non-symlinked, regular path under ROOT.
safe_rel() {
  local root=$1 rel=$2 part prefix old_ifs
  case "$rel" in ''|/*|*'//'*|*'\'*|*'..'*) return 1;; esac
  prefix="$root"; old_ifs=$IFS; IFS='/'
  for part in $rel; do
    [ -n "$part" ] && [ "$part" != . ] && [ "$part" != .. ] || { IFS=$old_ifs; return 1; }
    prefix="$prefix/$part"
    [ ! -L "$prefix" ] || { IFS=$old_ifs; return 1; }
  done
  IFS=$old_ifs
  [ -f "$root/$rel" ]
}

# The frozen constants are a closed, fully typed object.  Any missing or
# malformed field is a preregistration failure, not a default.
SPEC_FILTER='
  def hex: type == "string" and test("^[0-9a-f]{64}$");
  def rev: type == "string" and test("^[0-9a-f]{40}([0-9a-f]{24})?$");
  def nonempty: type == "string" and length > 0;
  type == "object"
  and (keys | sort) == ["analysis","baseline_revision","brief_order","calibration_sources",
        "calibration_split","claim","corpus_sha256","current_revision","design_lock_sha256",
        "evidence_prefixes","frozen_at","goal_sha256","panel_cohorts","provider_configs",
        "repair_budget","run_id","schema_version","study_id","thresholds"]
  and .schema_version == "taste-study-spec/v1"
  and (.study_id | nonempty) and (.run_id | nonempty) and (.frozen_at | nonempty)
  and (.baseline_revision | rev) and (.current_revision | rev)
  and (.goal_sha256 | hex) and (.design_lock_sha256 | hex) and (.corpus_sha256 | hex)
  and (.brief_order | type == "array" and length >= 10
       and all(.[]; nonempty) and (length == (unique | length)))
  and (.provider_configs | type == "array" and length >= 2
       and all(.[]; type == "object" and (.provider | nonempty) and (.model | nonempty))
       and ([.[] | [.provider, .model]] | length == (unique | length)))
  and (.calibration_sources | type == "array" and length >= 1 and all(.[]; nonempty))
  and (.calibration_split | type == "object"
       and (.calibration | type == "number" and floor == . and . > 0)
       and (.holdout | type == "number" and floor == . and . > 0))
  and (.panel_cohorts | type == "array" and length >= 1 and all(.[]; nonempty))
  and (.thresholds | type == "object"
       and (.brief_floor | type == "number" and . >= 10)
       and (.brief_wins | type == "number" and . >= 7)
       and (.preference | type == "number" and . >= 0.70)
       and (.wilson | type == "number" and . >= 0.50)
       and (.groups_per_brief | type == "number" and . >= 5)
       and (.accessibility_regressions | type == "number" and . == 0))
  and (.repair_budget | type == "number" and floor == . and . >= 0 and . <= 2)
  and (.evidence_prefixes | type == "array" and length >= 1
       and all(.[]; nonempty and (startswith("/") | not) and (contains("..") | not)))
  and (.claim | IN("HUMAN_CALIBRATED_MACHINE","HUMAN_CERTIFIED"))
  and (.analysis | type == "object" and (.confirmatory | nonempty))
'

freeze() {
  local spec=$1 out=$2 constants freeze_sha tmp
  [ -e "$out" ] && { printf 'FREEZE_EXISTS: %s\n' "$out" >&2; return 1; }
  if ! regular_json_without_duplicate_keys "$spec" || ! jq -e "$SPEC_FILTER" "$spec" >/dev/null 2>&1; then
    printf 'FREEZE_INVALID: %s\n' "$spec" >&2; return 1
  fi
  # freeze_sha256 binds the canonical constants only (schema_version dropped so it
  # names the study, not the record wrapper); recomputed byte-for-byte at compile
  # via the identical `jq -cS | sha256` pipeline (including jq's trailing newline).
  constants=$(jq -cS 'del(.schema_version)' "$spec")
  freeze_sha=$(jq -cS 'del(.schema_version)' "$spec" | sha256_stdin)
  tmp=$(mktemp "${out}.tmp.XXXXXX") || return 1
  jq -n --argjson constants "$constants" --arg fsha "$freeze_sha" \
     '{schema_version: "taste-study-freeze/v1", freeze_sha256: $fsha, constants: $constants}' \
     >"$tmp" && mv -f "$tmp" "$out" || { rm -f "$tmp"; return 1; }
  printf 'FROZEN %s\n' "$freeze_sha"
}

# ---------------------------------------------------------------------------
STUDY_CODES=''
scode() { case "|$STUDY_CODES|" in *"|$1|"*) ;; *) STUDY_CODES="${STUDY_CODES:+$STUDY_CODES|}$1" ;; esac; }

write_study_cert() {
  local cert=$1 status=$2 claim=$3 human=$4 study_id=$5 run_id=$6 fsha=$7 subject=$8 csha=$9 codes=${10} tmp
  tmp=$(mktemp "${cert}.tmp.XXXXXX") || return 1
  jq -n --arg status "$status" --arg claim "$claim" --argjson human "$human" \
     --arg study "$study_id" --arg run "$run_id" --arg fsha "$fsha" \
     --arg subject "$subject" --arg csha "$csha" --argjson codes "$codes" '
    {schema_version: "taste-study-certificate/v1",
     study_id: $study, run_id: $run,
     freeze_sha256: $fsha, subject_revision: $subject,
     certificate_sha256: $csha,
     status: $status, claim_label: $claim,
     human_certified: $human,
     live_study_executed: false,
     external_prerequisites: [
       "a real browser/Playwright render of every required route/state/viewport",
       "pinned human calibration labels from the frozen source corpus",
       "an independent, isolated, human deciding panel",
       "an executed, evidence-passing live old-versus-new study"],
     verdict_reason_codes: ($codes | unique | sort)}' \
    >"$tmp" && mv -f "$tmp" "$cert" || { rm -f "$tmp"; return 1; }
}

compile() {
  local freeze_file=$1 manifest=$2 cert=$3 subject_root=$4
  local mdir constants freeze_sha recomputed study_id run_id claim inner status
  local codes_json inner_codes manifest_dir corpus_rel corpus_sha frozen_corpus
  STUDY_CODES=''

  if ! regular_json_without_duplicate_keys "$freeze_file" ||
     ! jq -e 'type == "object" and .schema_version == "taste-study-freeze/v1"
              and (.freeze_sha256 | type == "string" and test("^[0-9a-f]{64}$"))
              and (.constants | type == "object")' "$freeze_file" >/dev/null 2>&1; then
    write_study_cert "$cert" NOT-CERTIFIED NOT-CERTIFIED false '' '' '' '' '' '["FREEZE_INVALID"]' || true
    return 1
  fi
  # Re-validate the frozen constants against the same closed schema so a tampered
  # freeze that widened or dropped a locked field cannot compile.
  if ! jq -c '.constants + {schema_version: "taste-study-spec/v1"}' "$freeze_file" |
       jq -e "$SPEC_FILTER" >/dev/null 2>&1; then
    write_study_cert "$cert" NOT-CERTIFIED NOT-CERTIFIED false '' '' '' '' '' '["FREEZE_INVALID"]' || true
    return 1
  fi
  freeze_sha=$(jq -r '.freeze_sha256' "$freeze_file")
  recomputed=$(jq -cS '.constants' "$freeze_file" | sha256_stdin)
  [ "$recomputed" = "$freeze_sha" ] || scode FREEZE_BINDING
  constants=$(jq -c '.constants' "$freeze_file")
  study_id=$(jq -r '.study_id' <<<"$constants")
  run_id=$(jq -r '.run_id' <<<"$constants")
  claim=$(jq -r '.claim' <<<"$constants")

  # Manifest must be a readable production evidence manifest.
  manifest_dir=$(CDPATH='' cd -- "$(dirname -- "$manifest")" 2>/dev/null && pwd) || {
    write_study_cert "$cert" NOT-CERTIFIED NOT-CERTIFIED false "$study_id" "$run_id" "$freeze_sha" '' '' '["MANIFEST_INVALID"]' || true
    return 1
  }
  manifest="$manifest_dir/$(basename -- "$manifest")"
  if ! regular_json_without_duplicate_keys "$manifest" ||
     ! jq -e '.schema_version == "taste-evidence-manifest/v2"' "$manifest" >/dev/null 2>&1; then
    write_study_cert "$cert" NOT-CERTIFIED NOT-CERTIFIED false "$study_id" "$run_id" "$freeze_sha" '' '' '["MANIFEST_INVALID"]' || true
    return 1
  fi

  # --- no post-freeze drift: every frozen constant binds the manifest ---------
  jq -e --argjson c "$constants" '.subject_revision == $c.current_revision' "$manifest" >/dev/null 2>&1 || scode STUDY_SUBJECT_DRIFT
  jq -e --argjson c "$constants" '.goal_sha256 == $c.goal_sha256' "$manifest" >/dev/null 2>&1 || scode STUDY_GOAL_DRIFT
  jq -e --argjson c "$constants" '.design_lock_sha256 == $c.design_lock_sha256' "$manifest" >/dev/null 2>&1 || scode STUDY_DESIGN_DRIFT
  jq -e --argjson c "$constants" '.required_claim == $c.claim' "$manifest" >/dev/null 2>&1 || scode STUDY_CLAIM_DRIFT
  jq -e '.fixture == false' "$manifest" >/dev/null 2>&1 || scode STUDY_FIXTURE
  jq -e --argjson c "$constants" '(.declared_evidence_paths | sort) == ($c.evidence_prefixes | sort)' "$manifest" >/dev/null 2>&1 || scode STUDY_EVIDENCE_DRIFT

  # Frozen corpus hash+order: recompute the corpus manifest digest and compare
  # the brief-lock id order to the preregistered brief_order.
  corpus_rel=$(jq -r '.corpus.input.path' "$manifest")
  frozen_corpus=$(jq -r '.corpus_sha256' <<<"$constants")
  if safe_rel "$manifest_dir" "$corpus_rel"; then
    corpus_sha=$(sha256_file "$manifest_dir/$corpus_rel")
    [ "$corpus_sha" = "$frozen_corpus" ] || scode STUDY_CORPUS_DRIFT
  else
    scode STUDY_CORPUS_DRIFT
  fi
  if ! study_brief_order_matches "$manifest" "$manifest_dir" "$constants"; then scode STUDY_BRIEF_ORDER_DRIFT; fi

  # --- compile the underlying taste certificate in LIVE mode ------------------
  inner="$manifest_dir/.study-inner-cert.json"
  rm -f "$inner"
  if POLYLANE_TASTE_LIVE=1 "$TASTE" certify "$manifest" "$inner" "$subject_root"; then :; else :; fi
  if [ ! -f "$inner" ] || ! jq -e '.schema_version == "taste-certificate/v2"' "$inner" >/dev/null 2>&1; then
    scode STUDY_INNER_MISSING
    codes_json=$(printf '%s' "$STUDY_CODES" | tr '|' '\n' | sed '/^$/d' | jq -R . | jq -cs .)
    write_study_cert "$cert" NOT-CERTIFIED NOT-CERTIFIED false "$study_id" "$run_id" "$freeze_sha" "$(jq -r '.current_revision' <<<"$constants")" '' "$codes_json" || true
    rm -f "$inner"; return 1
  fi
  local csha; csha=$(sha256_file "$inner")

  # Inner certificate must be live-compiled, certified, and threshold-compliant.
  jq -e '.live_mode == true' "$inner" >/dev/null 2>&1 || scode STUDY_NOT_LIVE
  status=$(jq -r '.status' "$inner")
  if [ "$status" != TASTE-CERTIFIED ]; then
    scode STUDY_INNER_NOT_CERTIFIED
    inner_codes=$(jq -c '.verdict_reason_codes // []' "$inner")
  else
    inner_codes='[]'
  fi
  jq -e --argjson c "$constants" '.subject_revision == $c.current_revision' "$inner" >/dev/null 2>&1 || scode STUDY_SUBJECT_DRIFT
  jq -e --argjson c "$constants" '.required_claim == $c.claim' "$inner" >/dev/null 2>&1 || scode STUDY_CLAIM_DRIFT
  # Two or more provider/model configurations decided the corpus.
  jq -e '.unique_judge_configurations >= 2' "$inner" >/dev/null 2>&1 || scode STUDY_CONFIG_FLOOR
  # Inner claim label must be exactly the frozen claim (never silently stronger
  # or weaker); human_certified stays false unless the frozen claim is human.
  jq -e --argjson c "$constants" '.claim_label == $c.claim' "$inner" >/dev/null 2>&1 || scode STUDY_CLAIM_DRIFT
  if [ "$claim" != HUMAN_CERTIFIED ]; then
    jq -e '.human_certified == false' "$inner" >/dev/null 2>&1 || scode STUDY_HUMAN_OVERCLAIM
  fi
  # Inner results must clear the frozen thresholds (no post-freeze weakening).
  jq -e --argjson c "$constants" '
      .brief_wins >= $c.thresholds.brief_wins
      and .preference_rate >= $c.thresholds.preference
      and .wilson_lower_bound > $c.thresholds.wilson
      and .accessibility_regressions <= $c.thresholds.accessibility_regressions
      and .briefs >= $c.thresholds.brief_floor' "$inner" >/dev/null 2>&1 || scode STUDY_THRESHOLD_DRIFT

  local human; human=$(jq -r '.human_certified' "$inner")
  local subject; subject=$(jq -r '.subject_revision' "$inner")
  codes_json=$(printf '%s' "$STUDY_CODES" | tr '|' '\n' | sed '/^$/d' | jq -R . | jq -cs --argjson inner "$inner_codes" '. + $inner')
  rm -f "$inner"

  if [ "$(jq -r 'length' <<<"$codes_json")" -eq 0 ]; then
    write_study_cert "$cert" STUDY-CHAIN-VERIFIED "$claim" "$human" "$study_id" "$run_id" "$freeze_sha" "$subject" "$csha" "$codes_json" || return 1
    return 0
  fi
  write_study_cert "$cert" NOT-CERTIFIED NOT-CERTIFIED false "$study_id" "$run_id" "$freeze_sha" "$subject" "$csha" "$codes_json" || true
  return 1
}

# study_brief_order_matches MANIFEST MDIR CONSTANTS: the ordered brief-lock ids
# in the manifest equal the frozen brief_order.
study_brief_order_matches() {
  local manifest=$1 mdir=$2 constants=$3 rel bid i n order got=''
  n=$(jq '.briefs | length' "$manifest")
  order=$(jq -r '.brief_order[]' <<<"$constants")
  i=0
  while [ "$i" -lt "$n" ]; do
    rel=$(jq -r ".briefs[$i].brief_lock.path" "$manifest")
    safe_rel "$mdir" "$rel" || return 1
    bid=$(jq -r '.brief_id // ""' "$mdir/$rel" 2>/dev/null)
    [ -n "$bid" ] || return 1
    got="${got}${bid}"$'\n'
    i=$((i + 1))
  done
  [ "$(printf '%s' "$got")" = "$(printf '%s\n' "$order")" ]
}

# --- HCM-v2: frozen target-matched split + stimulus exposure rules ----------
#
# The authority is the frozen `source_calibration.hcm_v2` block of the v3
# contract lock, read at runtime: nothing about HCM-v2 is inlined below.  Both
# verbs fail closed — an explicit reason code and a non-zero exit, never a
# warning — and neither can emit a certified, human, or bound-by-default claim.
#
# The study these rules describe is EXTERNAL (m32.8a: ethics review, recruiting,
# sealed ballots).  These verbs bind an allocation PLAN and a produced SPLIT;
# they never carry a judgment, a consent signature, or a study result.
HCM_LOCK="$HERE/../docs/polylane/taste-certification/contracts/CONTRACT-LOCK.v3.json"

HCM_CODES=''
hcode() { case "|$HCM_CODES|" in *"|$1|"*) ;; *) HCM_CODES="${HCM_CODES:+$HCM_CODES|}$1" ;; esac; }

# hcm_verdict OK_LABEL BAD_LABEL DETAIL — one status line; rc 1 iff any code.
hcm_verdict() {
  if [ -z "$HCM_CODES" ]; then printf '%s%s\n' "$1" "${3:+ $3}"; return 0; fi
  printf '%s %s\n' "$2" "$(printf '%s' "$HCM_CODES" | tr '|' ' ')"
  return 1
}

# hcm_lock JQ_FILTER — a frozen value, or rc 1 when the lock is unreadable.
hcm_lock() { jq -er "$1" "$HCM_LOCK" 2>/dev/null; }

# hcm_split_digest SPLIT — the canonical content digest of a split.  Documented
# canonicalization: the schema line, then each excluded anchor id (sorted), then
# each natural pair id with its stratum (sorted by pair id), tab-separated,
# newline-terminated, SHA-256.  Order of the input arrays is irrelevant.
hcm_split_digest() {
  jq -er '"hcm-v2-split/v1",
          (.anchors | sort | .[] | "anchor\t" + .),
          (.assignments | sort_by(.pair_id) | .[] | "pair\t" + .pair_id + "\t" + .stratum)' "$1" |
    sha256_stdin
}

hcm_split() {
  local split=$1 vals digest declared
  local l_total l_dev l_val l_conf l_anchors l_sha l_src
  HCM_CODES=''

  if ! regular_json_without_duplicate_keys "$split" ||
     ! jq -e 'type == "object" and .schema_version == "hcm-v2-split/v1"
              and (.source_id | type == "string" and length > 0)
              and (.split_sha256 | type == "string" and test("^[0-9a-f]{64}$"))
              and (.natural_pairs | type == "object")
              and (.anchors | type == "array")
              and (.assignments | type == "array")
              and all(.anchors[]; type == "string" and length > 0)
              and all(.assignments[];
                    (.pair_id | type == "string" and length > 0)
                    and (.stratum | IN("development","validation","confirmatory")))' \
          "$split" >/dev/null 2>&1; then
    hcode HCM_SPLIT_INVALID
    hcm_verdict SPLIT-BOUND SPLIT-NOT-BOUND ''
    return 1
  fi

  vals=$(hcm_lock '.source_calibration.hcm_v2 |
           [.natural_pairs.total, .natural_pairs.development, .natural_pairs.validation,
            .natural_pairs.confirmatory, .anchors_excluded, .split_sha256, .source_id] | @tsv') || {
    hcode HCM_LOCK_UNREADABLE
    hcm_verdict SPLIT-BOUND SPLIT-NOT-BOUND ''
    return 1
  }
  IFS=$'\t' read -r l_total l_dev l_val l_conf l_anchors l_sha l_src <<<"$vals"

  # The lock must itself be internally consistent before it can bind anything.
  [ "$((l_dev + l_val + l_conf))" -eq "$l_total" ] || hcode HCM_LOCK_INCONSISTENT
  [ "$l_src" = HCM-v2 ] || hcode HCM_LOCK_INCONSISTENT

  jq -e --argjson t "$l_total" \
     '.natural_pairs.total == $t and (.assignments | length) == $t' "$split" >/dev/null 2>&1 ||
    hcode HCM_SPLIT_TOTAL
  jq -e --argjson d "$l_dev" --argjson v "$l_val" --argjson c "$l_conf" '
       .natural_pairs.development == $d and .natural_pairs.validation == $v
       and .natural_pairs.confirmatory == $c
       and ([.assignments[] | select(.stratum == "development")] | length) == $d
       and ([.assignments[] | select(.stratum == "validation")] | length) == $v
       and ([.assignments[] | select(.stratum == "confirmatory")] | length) == $c' \
     "$split" >/dev/null 2>&1 || hcode HCM_SPLIT_STRATUM_COUNT
  jq -e '([.assignments[].pair_id] | length) == ([.assignments[].pair_id] | unique | length)' \
     "$split" >/dev/null 2>&1 || hcode HCM_SPLIT_DUPLICATE_PAIR
  jq -e --argjson a "$l_anchors" \
     '(.anchors | length) == $a and (.anchors | unique | length) == $a' "$split" >/dev/null 2>&1 ||
    hcode HCM_SPLIT_ANCHOR_COUNT
  jq -e '((.anchors | unique) - [.assignments[].pair_id] | length) == (.anchors | unique | length)' \
     "$split" >/dev/null 2>&1 || hcode HCM_SPLIT_ANCHOR_OVERLAP

  digest=$(hcm_split_digest "$split" 2>/dev/null) || digest=''
  declared=$(jq -r '.split_sha256' "$split")
  [ -n "$digest" ] || hcode HCM_SPLIT_INVALID
  [ "$digest" = "$declared" ] || hcode HCM_SPLIT_DIGEST_MISMATCH
  # The frozen authority.  A produced split whose digest is not the frozen one
  # is not the target-matched corpus, and that is a hard failure: the real
  # HCM-v2 split is external evidence this repository cannot manufacture.
  [ "$digest" = "$l_sha" ] || hcode HCM_SPLIT_LOCK_MISMATCH

  hcm_verdict SPLIT-BOUND SPLIT-NOT-BOUND "$digest"
}

# hcm_plan_codes PLAN — accumulate exposure codes for one allocation plan.
hcm_plan_codes() {
  local plan=$1 stream vals viewports
  local l_nat l_anc l_repeat l_tjpp l_tfloor l_dcap l_djpp l_dfloor l_sep l_total l_anchors

  if ! regular_json_without_duplicate_keys "$plan" ||
     ! jq -e 'type == "object" and .schema_version == "hcm-v2-exposure-plan/v1"
              and (.ballot_stream | IN("target_users","designers"))
              and (.participants | type == "array" and length > 0)
              and ([.participants[].participant_id] | length == (unique | length))
              and all(.participants[];
                    (.participant_id | type == "string" and length > 0)
                    and (.exposures | type == "array" and length > 0)
                    and all(.exposures[];
                          (.pair_id | type == "string" and length > 0)
                          and (.kind | IN("natural","anchor"))
                          and (.viewport | type == "string" and length > 0)))' \
          "$plan" >/dev/null 2>&1; then
    hcode HCM_EXPOSURE_INVALID
    return 0
  fi

  vals=$(hcm_lock '.source_calibration.hcm_v2 |
           [.target_users.max_natural_pairs_per_participant,
            .target_users.max_anchors_per_participant,
            .target_users.pair_repeat_exposures,
            .target_users.judgments_per_pair,
            .target_users.min_completed_participants,
            .designers.max_pairs_per_designer,
            .designers.judgments_per_pair,
            .designers.min_credentialed_designers,
            (.designers.separate_from_target_user_ballots | tostring),
            .natural_pairs.total, .anchors_excluded] | @tsv') || {
    hcode HCM_LOCK_UNREADABLE
    return 0
  }
  IFS=$'\t' read -r l_nat l_anc l_repeat l_tjpp l_tfloor l_dcap l_djpp l_dfloor l_sep \
    l_total l_anchors <<<"$vals"
  viewports=$(jq -ce '.source_calibration.hcm_v2.target_users.viewports
                      | select(type == "array" and length > 0)' "$HCM_LOCK" 2>/dev/null) || {
    hcode HCM_LOCK_UNREADABLE
    return 0
  }
  # Both rules below are only meaningful under the frozen constants they name.
  [ "$l_repeat" = 0 ] || hcode HCM_LOCK_INCONSISTENT
  [ "$l_sep" = true ] || hcode HCM_LOCK_INCONSISTENT

  # --- rules that hold for every ballot stream ------------------------------
  jq -e --argjson vp "$viewports" \
     'all(.participants[].exposures[]; .viewport as $v | $vp | index($v) != null)' \
     "$plan" >/dev/null 2>&1 || hcode HCM_EXPOSURE_VIEWPORT
  jq -e --argjson vp "$viewports" \
     '([.participants[].exposures[].viewport] | unique) == ($vp | unique)' \
     "$plan" >/dev/null 2>&1 || hcode HCM_EXPOSURE_VIEWPORT_COVERAGE
  # pair_repeat_exposures is 0: no participant may meet the same pair twice.
  jq -e 'all(.participants[];
           ([.exposures[].pair_id] | length) == ([.exposures[].pair_id] | unique | length))' \
     "$plan" >/dev/null 2>&1 || hcode HCM_EXPOSURE_REPEAT
  jq -e --argjson t "$l_total" \
     '([.participants[].exposures[] | select(.kind == "natural") | .pair_id] | unique | length) == $t' \
     "$plan" >/dev/null 2>&1 || hcode HCM_EXPOSURE_PAIR_COVERAGE

  stream=$(jq -r '.ballot_stream' "$plan")
  if [ "$stream" = target_users ]; then
    jq -e --argjson n "$l_nat" \
       'all(.participants[]; ([.exposures[] | select(.kind == "natural")] | length) <= $n)' \
       "$plan" >/dev/null 2>&1 || hcode HCM_EXPOSURE_NATURAL_CAP
    jq -e --argjson a "$l_anc" \
       'all(.participants[]; ([.exposures[] | select(.kind == "anchor")] | length) <= $a)' \
       "$plan" >/dev/null 2>&1 || hcode HCM_EXPOSURE_ANCHOR_CAP
    jq -e --argjson a "$l_anchors" \
       '([.participants[].exposures[] | select(.kind == "anchor") | .pair_id] | unique | length) == $a' \
       "$plan" >/dev/null 2>&1 || hcode HCM_EXPOSURE_ANCHOR_COVERAGE
    jq -e --argjson f "$l_tfloor" '(.participants | length) >= $f' "$plan" >/dev/null 2>&1 ||
      hcode HCM_EXPOSURE_PARTICIPANT_FLOOR
    jq -e --argjson j "$l_tjpp" \
       '([.participants[].exposures[] | select(.kind == "natural") | .pair_id]
         | group_by(.) | map(length) | unique) == [$j]' "$plan" >/dev/null 2>&1 ||
      hcode HCM_EXPOSURE_JUDGMENT_COUNT
  else
    jq -e --argjson c "$l_dcap" \
       'all(.participants[]; ([.exposures[] | select(.kind == "natural")] | length) <= $c)' \
       "$plan" >/dev/null 2>&1 || hcode HCM_EXPOSURE_DESIGNER_PAIR_CAP
    jq -e --argjson f "$l_dfloor" '(.participants | length) >= $f' "$plan" >/dev/null 2>&1 ||
      hcode HCM_EXPOSURE_DESIGNER_FLOOR
    jq -e --argjson j "$l_djpp" \
       '([.participants[].exposures[] | select(.kind == "natural") | .pair_id]
         | group_by(.) | map(length) | unique) == [$j]' "$plan" >/dev/null 2>&1 ||
      hcode HCM_EXPOSURE_JUDGMENT_COUNT
  fi
}

hcm_exposure() {
  local plan=$1 other=${2:-}
  HCM_CODES=''
  hcm_plan_codes "$plan"
  if [ -n "$other" ]; then
    hcm_plan_codes "$other"
    # separate_from_target_user_ballots: the two streams are different streams,
    # and no person appears on both ballots.
    if jq -e --slurpfile o "$other" '.ballot_stream == $o[0].ballot_stream' \
         "$plan" >/dev/null 2>&1; then
      hcode HCM_EXPOSURE_STREAM_DUPLICATE
    fi
    jq -e --slurpfile o "$other" \
       '([.participants[].participant_id] - [$o[0].participants[].participant_id] | length)
        == ([.participants[].participant_id] | length)' "$plan" >/dev/null 2>&1 ||
      hcode HCM_EXPOSURE_BALLOT_OVERLAP
  fi
  hcm_verdict EXPOSURE-BOUND EXPOSURE-NOT-BOUND ''
}

# ---------------------------------------------------------------------------
case "${1:-}" in
  freeze)
    [ "$#" -eq 3 ] || { usage; exit 64; }
    freeze "$2" "$3"
    ;;
  compile)
    [ "$#" -eq 5 ] || { usage; exit 64; }
    compile "$2" "$3" "$4" "$5"
    ;;
  hcm-split)
    [ "$#" -eq 2 ] || { usage; exit 64; }
    hcm_split "$2"
    ;;
  hcm-split-digest)
    [ "$#" -eq 2 ] || { usage; exit 64; }
    hcm_split_digest "$2"
    ;;
  hcm-exposure)
    [ "$#" -ge 2 ] && [ "$#" -le 3 ] || { usage; exit 64; }
    hcm_exposure "$2" "${3:-}"
    ;;
  *) usage; exit 64;;
esac
