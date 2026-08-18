#!/usr/bin/env bash
# polylane-taste-judge-parse.sh — deterministic, fail-closed parser for one exact
# visual-judge response schema (taste-judge-response/v1).
#
# It recomputes the raw-response hash and every request binding from the sealed
# work-unit manifest, rejects unknown keys / numeric coercion / identity leakage /
# injection flags, and emits pointwise plus pairwise records WITHOUT candidate
# provenance: the raw response only ever knows positions A and B; candidate
# identity is injected from the manifest, never read from the judge.
#
# It never infers a choice. A malformed response is `invalid`; a schema-valid
# `choice:"abstain"` is a substantive vote of no confidence, not a failure.
# It classifies nothing as live: live-vs-fixture is decided downstream.
set -euo pipefail

CRIT='["color","craftsmanship","hierarchy","originality","product_fit","spatial_rhythm","state_coherence","typography"]'
OBSKEYS='["brief_clause","capture_id","criterion","reason","region_or_state"]'
RESP_KEYS='["abstain_reason","choice","observations","positions","schema_version","work_unit_id"]'

usage() {
  echo "usage: polylane-taste-judge-parse.sh check EMIT <manifest> <response> [<out-dir>]" >&2
  echo "       check    <manifest> <response>            -> prints vote|abstain|invalid" >&2
  echo "       emit     <manifest> <response> <out-dir>  -> writes pointwise+pairwise records" >&2
}

die() { echo "TASTE-JUDGE-PARSE: $*" >&2; return 1; }

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else die "no SHA-256 command available"; fi
}

# A regular (non-symlink) JSON file with no duplicate object keys.
regular_json_without_duplicate_keys() {
  local file="$1" duplicates
  [ -f "$file" ] && [ ! -L "$file" ] || return 1
  jq -e . "$file" >/dev/null 2>&1 || return 1
  duplicates=$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("")' "$file" 2>/dev/null | sort | uniq -d)
  [ -z "$duplicates" ]
}

# validate_manifest_shape MANIFEST — the sealed work unit the parser binds to.
validate_manifest_shape() {
  regular_json_without_duplicate_keys "$1" || return 1
  jq -e '
    (keys) == ["adapter","brief_sha256","candidate_ids","capture_manifest_sha256","deadline_s","display_order","images","judge_id","mirror_group_id","prompt_sha256","response_schema","role","schema_version","session_id","work_unit_id"]
    and .schema_version == "taste-judge-workunit/v1"
    and (.work_unit_id | type == "string" and test("^wu-[a-z0-9-]{2,}$"))
    and (.mirror_group_id | type == "string" and test("^mg-[a-z0-9-]{2,}$"))
    and (.role | . == "primary" or . == "mirror")
    and (.session_id | type == "string" and test("^sess-[a-z0-9-]{2,}$"))
    and (.judge_id | type == "string" and test("^judge-[a-z0-9-]{2,}$"))
    and (.display_order | . == "A/B" or . == "B/A")
    and (.response_schema == "taste-judge-response/v1")
    and ([.brief_sha256,.capture_manifest_sha256,.prompt_sha256] | all(.[]; type == "string" and test("^[a-f0-9]{64}$")))
    and (.candidate_ids | (type == "array") and (length == 2) and ((unique | length) == 2) and all(.[]; type == "string" and test("^stim-[a-f0-9]{12}$")))
    and (.images | (keys) == ["A","B"] and all(.[]; type == "string" and length > 0))
    and (.adapter | (keys) == ["command","fingerprint"] and (.command | type == "array" and length >= 1 and all(.[]; type == "string")) and (.fingerprint | type == "string" and test("^[a-f0-9]{64}$")))
    and (.deadline_s | type == "number" and floor == . and . >= 1 and . <= 300)
  ' "$1" >/dev/null 2>&1
}

# response_schema_ok RESPONSE WORK_UNIT_ID — one exact schema, no coercion.
response_schema_ok() {
  local file="$1" wu="$2"
  regular_json_without_duplicate_keys "$file" || return 1
  jq -e --arg wu "$wu" --argjson crit "$CRIT" --argjson obskeys "$OBSKEYS" --argjson respkeys "$RESP_KEYS" '
    (keys) == $respkeys
    and .schema_version == "taste-judge-response/v1"
    and .work_unit_id == $wu
    and (.positions | (keys) == ["A","B"])
    and (.positions.A | (keys) == $crit and all(.[]; type == "number" and floor == . and . >= 1 and . <= 7))
    and (.positions.B | (keys) == $crit and all(.[]; type == "number" and floor == . and . >= 1 and . <= 7))
    and (.observations | (keys) == ["A","B"])
    and (.observations.A | type == "array" and length == 8 and ([.[].criterion] | sort) == $crit and all(.[]; (keys) == $obskeys and all(.[]; type == "string" and length > 0)))
    and (.observations.B | type == "array" and length == 8 and ([.[].criterion] | sort) == $crit and all(.[]; (keys) == $obskeys and all(.[]; type == "string" and length > 0)))
    and (.choice | . == "A" or . == "B" or . == "abstain")
    and (if .choice == "abstain" then (.abstain_reason | type == "string" and length > 0) else .abstain_reason == null end)
  ' "$file" >/dev/null 2>&1
}

# no_identity_leak RESPONSE CAND_A CAND_B — reject candidate ids in any free text.
no_identity_leak() {
  local file="$1" a="$2" b="$3"
  ! grep -qF -e "$a" -e "$b" "$file"
}

# classify MANIFEST RESPONSE — echoes vote|abstain|invalid, rc 0 for a vote or a
# deliberate abstain, rc 2 for invalid. Binds the response to the sealed manifest.
classify() {
  local manifest="$1" response="$2" wu a b choice
  validate_manifest_shape "$manifest" || { echo invalid; return 2; }
  wu=$(jq -r .work_unit_id "$manifest")
  a=$(jq -r '.candidate_ids[0]' "$manifest"); b=$(jq -r '.candidate_ids[1]' "$manifest")
  if ! response_schema_ok "$response" "$wu" || ! no_identity_leak "$response" "$a" "$b"; then
    echo invalid; return 2
  fi
  choice=$(jq -r .choice "$response")
  if [ "$choice" = abstain ]; then echo abstain; else echo vote; fi
  return 0
}

# build_pointwise RESPONSE POS BALLOT_ID JUDGE CAND BRIEF CAP NOW OUT
build_pointwise() {
  local response="$1" pos="$2" ballot_id="$3" judge="$4" cand="$5" brief="$6" cap="$7" now="$8" out="$9"
  local body tmp digest
  tmp=$(mktemp "${out}.tmp.XXXXXX") || return 1
  jq --arg ballot_id "$ballot_id" --arg judge "$judge" --arg cand "$cand" --arg brief "$brief" \
     --arg cap "$cap" --arg now "$now" --arg pos "$pos" '
    {schema_version:"taste-pointwise/v1",
     ballot_id:$ballot_id,judge_id:$judge,candidate_id:$cand,
     brief_sha256:$brief,capture_manifest_sha256:$cap,
     scores_1_to_7:.positions[$pos],observations:.observations[$pos],
     identity_visible:false,prior_ballots_visible:false,injection_detected:false,judge_discussion:false,
     sealed_at:$now}' "$response" > "$tmp"
  body=$(jq -cS . "$tmp") || { rm -f "$tmp"; return 1; }
  digest=$(printf '%s' "$body" | shasum -a 256 | awk '{print $1}') || { rm -f "$tmp"; return 1; }
  jq --arg digest "$digest" '. + {record_sha256:$digest}' "$tmp" > "$out" && rm -f "$tmp"
}

emit() {
  local manifest="$1" response="$2" out="$3" class wu judge disp brief cap mirror role \
        a b posA posB winner choice reason rawsha now pair_now manifest_sha pfp
  class=$(classify "$manifest" "$response") || die "response is $class; refusing to emit"
  wu=$(jq -r .work_unit_id "$manifest")
  judge=$(jq -r .judge_id "$manifest")
  disp=$(jq -r .display_order "$manifest")
  brief=$(jq -r .brief_sha256 "$manifest")
  cap=$(jq -r .capture_manifest_sha256 "$manifest")
  mirror=$(jq -r .mirror_group_id "$manifest")
  role=$(jq -r .role "$manifest")
  a=$(jq -r '.candidate_ids[0]' "$manifest"); b=$(jq -r '.candidate_ids[1]' "$manifest")
  # Position -> candidate binding comes from the sealed display order only.
  if [ "$disp" = "A/B" ]; then posA="$a"; posB="$b"; else posA="$b"; posB="$a"; fi
  choice=$(jq -r .choice "$response")
  case "$choice" in
    A) winner="$posA" ;;
    B) winner="$posB" ;;
    abstain) winner="" ;;
  esac
  rawsha=$(sha256_file "$response") || return 1
  now=${POLYLANE_TASTE_NOW:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}
  pair_now=$(jq -rn --arg t "$now" '($t | fromdateiso8601) + 1 | todateiso8601') || return 1
  manifest_sha=$(sha256_file "$manifest") || return 1
  pfp=$(sha256_file "${BASH_SOURCE[0]}") || return 1

  # Validate everything, then write; a rejected response leaves no partial output.
  mkdir -p "$out"
  build_pointwise "$response" A "pointwise-$wu-a" "$judge" "$posA" "$brief" "$cap" "$now" "$out/pointwise-$wu-a.json" || return 1
  build_pointwise "$response" B "pointwise-$wu-b" "$judge" "$posB" "$brief" "$cap" "$now" "$out/pointwise-$wu-b.json" || return 1

  reason=$(jq -c '.abstain_reason' "$response")
  jq -n --arg wu "$wu" --arg judge "$judge" --arg disp "$disp" --arg choice "$choice" \
     --arg rawsha "$rawsha" --arg now "$pair_now" --argjson winner "$( [ -n "$winner" ] && printf '"%s"' "$winner" || echo null )" \
     --argjson reason "$reason" '
    {schema_version:"taste-pairwise/v1",
     ballot_id:("pair-"+$wu),judge_id:$judge,display_order:$disp,
     choice:$choice,canonical_choice:$winner,response_sha256:$rawsha,sealed_at:$now,
     identity_visible:false,prior_ballots_visible:false,injection_detected:false,judge_discussion:false,
     abstain_reason:$reason}' > "$out/pairwise-$wu.json"

  jq -n --arg pfp "$pfp" --arg wu "$wu" --arg judge "$judge" --arg mirror "$mirror" --arg role "$role" \
     --arg disp "$disp" --arg manifest_sha "$manifest_sha" --arg brief "$brief" --arg cap "$cap" \
     --arg prompt "$(jq -r .prompt_sha256 "$manifest")" --arg rawsha "$rawsha" --arg class "$class" \
     --argjson cands "$(jq -c .candidate_ids "$manifest")" '
    {schema_version:"taste-judge-parse-receipt/v1",
     parser:{id:"polylane-taste-judge-parse",fingerprint:$pfp},
     work_unit_id:$wu,judge_id:$judge,mirror_group_id:$mirror,role:$role,display_order:$disp,decision:$class,
     request_bindings:{manifest_sha256:$manifest_sha,brief_sha256:$brief,capture_manifest_sha256:$cap,prompt_sha256:$prompt,candidate_ids:$cands},
     raw_response_sha256:$rawsha,
     emitted:{pointwise:[("pointwise-"+$wu+"-a"),("pointwise-"+$wu+"-b")],pairwise:("pair-"+$wu)}}' > "$out/parse.json"
}

main() {
  local c rc=0
  command -v jq >/dev/null 2>&1 || die "jq is required"
  case "${1:-}" in
    check) [ $# -eq 3 ] || { usage; return 2; }; c=$(classify "$2" "$3") || rc=$?; printf '%s\n' "$c"; return "$rc" ;;
    emit)  [ $# -eq 4 ] || { usage; return 2; }; emit "$2" "$3" "$4" ;;
    *) usage; return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
