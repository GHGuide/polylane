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
set -euo pipefail

usage() {
  printf '%s\n' \
    'usage: polylane-taste-study.sh freeze SPEC OUT' \
    '       polylane-taste-study.sh compile FREEZE MANIFEST CERT SUBJECT_ROOT' >&2
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
  *) usage; exit 64;;
esac
