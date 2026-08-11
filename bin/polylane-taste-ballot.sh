#!/usr/bin/env bash
# polylane-taste-ballot.sh — fail-closed validation of fixture ballot groups.
# Bash 3.2 + jq. This validates evidence records; it never certifies a panel.
set -euo pipefail

usage() {
  echo "usage: polylane-taste-ballot.sh validate GROUP POINTWISE_DIR CALIBRATION OUT" >&2
}

die() { echo "TASTE-BALLOT: $*" >&2; return 1; }

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else die "no SHA-256 command available"; fi
}

regular_json_without_duplicate_keys() {
  local file="$1" duplicates
  [ -f "$file" ] && [ ! -L "$file" ] || return 1
  jq -e . "$file" >/dev/null 2>&1 || return 1
  duplicates=$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("\u001f")' "$file" 2>/dev/null | sort | uniq -d)
  [ -z "$duplicates" ]
}

valid_timestamp() {
  jq -e 'type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")' >/dev/null
}

validate_pointwise() { # file expected-id expected-sha expected-brief candidates-json
  local file="$1" expected_id="$2" expected_sha="$3" brief="$4" candidates="$5" actual body body_hash
  regular_json_without_duplicate_keys "$file" || return 1
  actual=$(sha256_file "$file") || return 1
  [ "$actual" = "$expected_sha" ] || return 1
  body=$(jq -cS 'del(.record_sha256)' "$file") || return 1
  body_hash=$(printf '%s' "$body" | shasum -a 256 | awk '{print $1}') || return 1
  jq -e --arg id "$expected_id" --arg brief "$brief" --arg body_hash "$body_hash" --argjson candidates "$candidates" '
    (keys | sort) == ["ballot_id","brief_sha256","candidate_id","capture_manifest_sha256","identity_visible","injection_detected","judge_discussion","judge_id","observations","prior_ballots_visible","record_sha256","schema_version","scores_1_to_7","sealed_at"]
    and .schema_version == "taste-pointwise/v1"
    and .ballot_id == $id
    and (.judge_id | type == "string" and test("^judge-[a-z0-9-]{3,}$"))
    and (.candidate_id | IN($candidates[]))
    and .brief_sha256 == $brief
    and ([.brief_sha256,.capture_manifest_sha256,.record_sha256] | all(.[]; type == "string" and test("^[a-f0-9]{64}$")))
    and .record_sha256 == $body_hash
    and (.sealed_at | type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"))
    and (.identity_visible == false and .prior_ballots_visible == false and .injection_detected == false and .judge_discussion == false)
    and (.scores_1_to_7 | (type == "object") and (keys | sort) == ["color","craftsmanship","hierarchy","originality","product_fit","spatial_rhythm","state_coherence","typography"]
         and all(.[]; type == "number" and floor == . and . >= 1 and . <= 7))
    and (.observations | (type == "array") and (length == 8)
         and ([.[].criterion] | sort) == ["color","craftsmanship","hierarchy","originality","product_fit","spatial_rhythm","state_coherence","typography"]
         and all(.[]; (keys | sort) == ["brief_clause","capture_id","criterion","reason","region_or_state"]
                    and (.criterion | type == "string")
                    and ([.capture_id,.region_or_state,.brief_clause,.reason] | all(.[]; type == "string" and length > 0))))
  ' "$file" >/dev/null
}

validate_group_shape() {
  local group="$1"
  jq -e '. as $group |
    (keys | sort) == ["brief_sha256","candidate_ids","candidate_ids_escrow_sha256","exposures","mirror_group_id","outcome","pointwise_ballot_ids","pointwise_sha256","schema_version"]
    and .schema_version == "taste-mirrored-group/v1"
    and (.mirror_group_id | type == "string" and test("^mg-[a-z0-9-]{3,}$"))
    and ([.brief_sha256,.candidate_ids_escrow_sha256] | all(.[]; type == "string" and test("^[a-f0-9]{64}$")))
    and (.candidate_ids | (type == "array") and (length == 2) and ((unique | length) == 2) and all(.[]; type == "string" and test("^stim-[a-f0-9]{12}$")))
    and (.pointwise_ballot_ids | (type == "array") and (length == 2) and ((unique | length) == 2) and all(.[]; type == "string" and test("^pointwise-[a-z0-9-]{1,}$")))
    and (.pointwise_sha256 | (type == "object") and (keys | sort) == ($group.pointwise_ballot_ids | sort) and all(.[]; type == "string" and test("^[a-f0-9]{64}$")))
    and (.exposures | (type == "array") and (length == 2)
         and ([.[].display_order] | sort) == ["A/B","B/A"]
         and ([.[].judge_id] | unique | length == 2)
         and ([.[].ballot_id] | unique | length == 2))
  ' "$group" >/dev/null
}

validate_exposures() {
  local group="$1" pointwise_dir="$2" calibration="$3" earliest_pointwise winner outcome
  earliest_pointwise=$(jq -r '.pointwise_ballot_ids[]' "$group" | while IFS= read -r id; do jq -r .sealed_at "$pointwise_dir/$id.json"; done | sort | tail -1) || return 1
  winner=$(jq -r '.exposures[0].canonical_choice' "$group") || return 1
  outcome="resolved-$winner"
  jq -e --arg earliest "$earliest_pointwise" --arg winner "$winner" --arg outcome "$outcome" '
    .outcome == $outcome
    and all(.exposures[];
      (keys | sort) == ["abstain_reason","ballot_id","canonical_choice","choice","display_order","identity_visible","injection_detected","judge_discussion","judge_id","prior_ballots_visible","response_sha256","schema_version","sealed_at"]
      and .schema_version == "taste-pairwise/v1"
      and (.ballot_id | type == "string" and test("^pair-[a-z0-9-]{1,}$"))
      and (.judge_id | type == "string" and test("^judge-[a-z0-9-]{3,}$"))
      and (.choice | IN("A","B","abstain"))
      and (.canonical_choice | type == "string" and test("^stim-[a-f0-9]{12}$"))
      and (.response_sha256 | type == "string" and test("^[a-f0-9]{64}$"))
      and (.sealed_at | type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$") and . > $earliest)
      and (.identity_visible == false and .prior_ballots_visible == false and .injection_detected == false and .judge_discussion == false)
      and (if .choice == "abstain" then (.abstain_reason | type == "string" and length > 0) else .abstain_reason == null end)
    )
    and ([.exposures[].canonical_choice] | unique | length == 1 and .[0] == $winner)
    and ([.exposures[].choice] | all(.[]; . != "abstain"))
  ' "$group" >/dev/null || return 1
  jq -e --argjson judges "$(jq '[.exposures[].judge_id]' "$group")" '
    (keys | sort) == ["judge_eligibility","schema_version"]
    and .schema_version == "taste-ballot-calibration/v1"
    and (.judge_eligibility | (type == "array")
         and (([.[].judge_id] | length) == ([.[].judge_id] | unique | length))
         and all(.[]; (keys | sort) == ["abstention_policy","eligible","independent","judge_id","no_candidate_identity","no_shared_ballot_channel"]
                    and (.judge_id | type == "string" and test("^judge-[a-z0-9-]{3,}$"))))
    and (.judge_eligibility as $eligible | all($judges[]; . as $judge | any($eligible[]; .judge_id == $judge and .eligible == true and .abstention_policy == "pass" and .independent == true and .no_candidate_identity == true and .no_shared_ballot_channel == true)))
  ' "$calibration" >/dev/null
}

validate() {
  local group="$1" pointwise_dir="$2" calibration="$3" out="$4" id hash file candidates brief tmp
  regular_json_without_duplicate_keys "$group" || die "invalid group JSON"
  regular_json_without_duplicate_keys "$calibration" || die "invalid calibration JSON"
  [ -d "$pointwise_dir" ] && [ ! -L "$pointwise_dir" ] || die "invalid pointwise directory"
  validate_group_shape "$group" || die "malformed group"
  candidates=$(jq -c .candidate_ids "$group")
  brief=$(jq -r .brief_sha256 "$group")
  while IFS=$'\t' read -r id hash; do
    file="$pointwise_dir/$id.json"
    validate_pointwise "$file" "$id" "$hash" "$brief" "$candidates" || die "invalid pointwise ballot: $id"
  done < <(jq -r '.pointwise_ballot_ids[] as $id | [$id,.pointwise_sha256[$id]] | @tsv' "$group")
  validate_exposures "$group" "$pointwise_dir" "$calibration" || die "invalid mirrored exposures or calibration"
  mkdir -p "$(dirname "$out")"
  tmp=$(mktemp "${out}.tmp.XXXXXX") || return 1
  jq -n --arg group_sha256 "$(sha256_file "$group")" --arg group_id "$(jq -r .mirror_group_id "$group")" --arg brief_sha256 "$(jq -r .brief_sha256 "$group")" --arg winner "$(jq -r '.exposures[0].canonical_choice' "$group")" \
    '{schema_version:"taste-ballot-validation/v1",status:"eligible",fixture_only:true,human_certified:false,mirror_group_id:$group_id,brief_sha256:$brief_sha256,winner:$winner,group_sha256:$group_sha256}' > "$tmp" && mv "$tmp" "$out"
}

main() {
  [ "${1:-}" = validate ] && [ $# -eq 5 ] || { usage; return 2; }
  command -v jq >/dev/null 2>&1 || die "jq is required"
  validate "$2" "$3" "$4" "$5"
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
