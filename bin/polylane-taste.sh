#!/usr/bin/env bash
# Compile a fail-closed taste certificate from versioned receipt files.
set -euo pipefail

usage() { printf '%s\n' 'usage: polylane-taste.sh certify MANIFEST CERTIFICATE' >&2; }
reasons=''
add_reason() { case "|$reasons|" in *"|$1|"*) ;; *) reasons="${reasons:+$reasons|}$1" ;; esac; }
seen_add() { local name=$1 value=$2 current; eval "current=\${$name}"; case "|$current|" in *"|$value|"*) return 1;; *) eval "$name=\${$name:+\${$name}|}$value";; esac; }
is_sha() { [[ $1 =~ ^[0-9a-f]{64}$ ]]; }

safe_receipt() {
  local rel=$1 expected=$2 path
  case "$rel" in ''|/*|*'..'*|*'//'*) return 1;; esac
  path="$manifest_dir/$rel"
  [ -f "$path" ] && [ ! -L "$path" ] || return 1
  jq -e --arg expected "$expected" 'type == "object" and .schema_version == $expected' "$path" >/dev/null 2>&1 || return 1
  jq -c . "$path"
}

write_certificate() {
  local status=$1 calibrated=$2 human=$3 label=$4 tmp manifest_sha code_json
  manifest_sha=$(shasum -a 256 "$manifest" | awk '{print $1}')
  code_json=$(printf '%s' "$reasons" | tr '|' '\n' | sed '/^$/d' | jq -R . | jq -s .)
  tmp=$(mktemp "${certificate}.tmp.XXXXXX") || return 1
  jq -n --arg run_id "$run_id" --arg protocol "$protocol_version" --arg manifest_sha "$manifest_sha" --arg status "$status" --arg label "$label" --arg repair "$repair_sha" --argjson calibrated "$calibrated" --argjson human "$human" --argjson briefs "$brief_count" --argjson wins "$brief_wins" --argjson preference "$preference" --argjson confidence "$confidence" --argjson groups "$groups_per_brief" --argjson codes "$code_json" '
    {schema_version:"taste-certificate/v1",run_id:$run_id,protocol_version:$protocol,evidence_manifest_sha256:$manifest_sha,status:$status,claim_label:$label,human_calibrated:$calibrated,human_certified:$human,briefs:$briefs,eligible_human_mirrored_groups_per_brief:$groups,brief_wins:$wins,preference_rate:$preference,confidence_lower:$confidence,accessibility_regressions:0,repair_ledger_sha256:$repair,external_limitations:["panel identity and host assurance remain externally scoped"],verdict_reason_codes:$codes}' >"$tmp" && mv -f "$tmp" "$certificate" || { rm -f "$tmp"; return 1; }
}

if [ "$#" -ne 3 ] || [ "$1" != certify ]; then usage; exit 64; fi
manifest=$2; certificate=$3
manifest_dir=$(CDPATH='' cd -- "$(dirname -- "$manifest")" 2>/dev/null && pwd) || exit 64
manifest="$manifest_dir/$(basename -- "$manifest")"
run_id=unknown; protocol_version=taste-protocol/v1; brief_count=0; brief_wins=0; preference=0; confidence=0; groups_per_brief='{}'; repair_sha=''
if [ -L "$manifest" ] || ! jq -e 'type == "object" and ([keys[]] | all(. == "schema_version" or . == "run_id" or . == "protocol_version" or . == "candidate_id" or . == "briefs" or . == "calibrations" or . == "threat_report" or . == "repair_ledger")) and .schema_version == "taste-evidence-manifest/v1" and (.run_id|type == "string" and length > 0) and .protocol_version == "taste-protocol/v1" and (.candidate_id|type == "string" and length > 0) and (.briefs|type == "array") and (.calibrations|type == "array") and (.threat_report|type == "string") and (.repair_ledger|type == "string")' "$manifest" >/dev/null 2>&1; then
  add_reason MANIFEST_INVALID; write_certificate NOT-CERTIFIED false false NOT-CERTIFIED || true; exit 1
fi
run_id=$(jq -r .run_id "$manifest"); protocol_version=$(jq -r .protocol_version "$manifest"); candidate_id=$(jq -r .candidate_id "$manifest"); brief_count=$(jq '.briefs|length' "$manifest")
[ "$brief_count" -ge 10 ] && [ "$brief_count" -le 100 ] || add_reason BRIEF_QUORUM
# shellcheck disable=SC2034 # seen_add accesses these Bash 3.2 scalar sets indirectly.
brief_ids=''; categories=''; tasks=''; revisions=''; pixels=''; judges=''; all_human=true; total_groups=0; total_wins=0; index=0
: "$brief_ids" "$categories" "$tasks" "$revisions" "$pixels" "$judges"
while [ "$index" -lt "$brief_count" ]; do
  brief=$(jq -c ".briefs[$index]" "$manifest")
  if ! jq -e 'type == "object" and (.groups|type == "array") and (.brief_lock|type == "string") and (.candidate|type == "string") and (.capture|type == "string") and (.hard_gate|type == "string") and (.review|type == "string")' >/dev/null <<<"$brief"; then add_reason BRIEF_INDEX_INVALID; index=$((index + 1)); continue; fi
  lock=$(safe_receipt "$(jq -r .brief_lock <<<"$brief")" taste-brief/v1) || { add_reason BRIEF_LOCK_INVALID; index=$((index + 1)); continue; }
  brief_id=$(jq -r '.brief_id // empty' <<<"$lock"); brief_sha=$(jq -r '.brief_sha256 // empty' <<<"$lock"); category=$(jq -r '.target_population.category // .target_population.role // empty' <<<"$lock"); task=$(jq -r '.core_task.id // empty' <<<"$lock")
  if [ -z "$brief_id" ] || ! is_sha "$brief_sha" || [ -z "$category" ] || [ -z "$task" ] || ! seen_add brief_ids "$brief_id" || ! seen_add categories "$category" || ! seen_add tasks "$task"; then add_reason BRIEF_VARIETY; fi
  candidate=$(safe_receipt "$(jq -r .candidate <<<"$brief")" taste-candidate/v1) || { add_reason CANDIDATE_INVALID; index=$((index + 1)); continue; }
  revision=$(jq -r '.source_revision // empty' <<<"$candidate")
  if [ "$(jq -r '.candidate_id // empty' <<<"$candidate")" != "$candidate_id" ] || [ "$(jq -r '.brief_sha256 // empty' <<<"$candidate")" != "$brief_sha" ] || [ -z "$revision" ] || ! seen_add revisions "$revision"; then add_reason CANDIDATE_PROVENANCE; fi
  capture=$(safe_receipt "$(jq -r .capture <<<"$brief")" taste-capture-manifest/v1) || { add_reason CAPTURE_INVALID; index=$((index + 1)); continue; }
  if [ "$(jq -r '.candidate_id // empty' <<<"$capture")" != "$candidate_id" ] || [ "$(jq -r '.candidate_source_revision // empty' <<<"$capture")" != "$revision" ] || ! jq -e '.captures|type == "array" and length > 0 and all(.[]; (.decoded_pixel_sha256|type == "string" and length > 0) and (.decoded_width|type == "number") and (.decoded_height|type == "number"))' >/dev/null <<<"$capture"; then add_reason CAPTURE_INVALID; fi
  while IFS= read -r pixel; do seen_add pixels "$pixel" || add_reason DUPLICATE_RENDER; done < <(jq -r '.captures[].decoded_pixel_sha256' <<<"$capture" 2>/dev/null || true)
  hard=$(safe_receipt "$(jq -r .hard_gate <<<"$brief")" taste-hard-gate/v1) || { add_reason HARD_GATE_MISSING; index=$((index + 1)); continue; }
  if ! jq -e --arg c "$candidate_id" '.candidate_id == $c and .overall == "PASS" and (.task_results|type == "array" and length > 0 and all(.[]; .status == "pass")) and (.accessibility|type == "array" and length > 0 and all(.[]; .status == "pass")) and (.state_coverage|type == "array" and length > 0 and all(.[]; .status == "pass"))' >/dev/null <<<"$hard"; then add_reason FUNCTION_OR_ACCESSIBILITY_VETO; fi
  group_count=0; target_wins=0; group_index=0; group_total=$(jq '.groups|length' <<<"$brief")
  while [ "$group_index" -lt "$group_total" ]; do
    group=$(safe_receipt "$(jq -r ".groups[$group_index]" <<<"$brief")" taste-mirrored-group/v1) || { add_reason BALLOT_INVALID; group_index=$((group_index + 1)); continue; }
    if ! jq -e --arg sha "$brief_sha" '.brief_sha256 == $sha and (.exposures|type == "array" and length == 2) and ([.exposures[].display_order]|sort == ["A/B","B/A"]) and (.exposures[0].judge_id != .exposures[1].judge_id) and all(.exposures[]; (.judge_id|type == "string" and length > 0) and (.canonical_choice|type == "string" and length > 0) and (.independence_attestation_sha256|type == "string" and length > 0)) and (.exposures[0].canonical_choice == .exposures[1].canonical_choice) and (.outcome == ("resolved-" + .exposures[0].canonical_choice))' >/dev/null <<<"$group"; then add_reason BALLOT_INVALID; else
      winner=$(jq -r '.exposures[0].canonical_choice' <<<"$group"); group_count=$((group_count + 1)); total_groups=$((total_groups + 1)); [ "$winner" = "$candidate_id" ] && { target_wins=$((target_wins + 1)); total_wins=$((total_wins + 1)); }
      while IFS= read -r judge; do seen_add judges "$judge" || add_reason JUDGE_NOT_INDEPENDENT; done < <(jq -r '.exposures[].judge_id' <<<"$group")
    fi
    group_index=$((group_index + 1))
  done
  [ "$group_count" -ge 5 ] || add_reason BALLOT_QUORUM
  [ "$target_wins" -gt $((group_count - target_wins)) ] && brief_wins=$((brief_wins + 1)) || add_reason BRIEF_NOT_WON
  groups_per_brief=$(jq -c --arg id "$brief_id" --argjson count "$group_count" '. + {($id):$count}' <<<"$groups_per_brief")
  review=$(safe_receipt "$(jq -r .review <<<"$brief")" taste-cross-brief-review/v1) || add_reason CROSS_BRIEF_REVIEW
  if [ -n "${review:-}" ] && ! jq -e --arg id "$brief_id" '.brief_id == $id and .status == "resolved" and .determination == "clear"' >/dev/null <<<"$review"; then add_reason CROSS_BRIEF_REVIEW; fi
  index=$((index + 1))
done
[ "$brief_wins" -ge 7 ] || add_reason BRIEF_WIN_FLOOR
if [ "$total_groups" -gt 0 ]; then preference=$(awk -v w="$total_wins" -v n="$total_groups" 'BEGIN{printf "%.8f",w/n}'); confidence=$(awk -v w="$total_wins" -v n="$total_groups" 'BEGIN{z=1.959964;p=w/n;d=1+z*z/n;c=(p+z*z/(2*n))/d;m=z*sqrt((p*(1-p)+z*z/(4*n))/n)/d;printf "%.8f",c-m}'); else add_reason NO_RESOLVED_GROUPS; fi
awk -v p="$preference" 'BEGIN{exit !(p>=.70)}' || add_reason PREFERENCE_FLOOR
awk -v l="$confidence" 'BEGIN{exit !(l>.50)}' || add_reason WILSON_FLOOR

calibrated_judges=''; cal_index=0; cal_total=$(jq '.calibrations|length' "$manifest")
while [ "$cal_index" -lt "$cal_total" ]; do
  cal=$(safe_receipt "$(jq -r ".calibrations[$cal_index]" "$manifest")" taste-calibration/v1) || { add_reason CALIBRATION_INVALID; cal_index=$((cal_index + 1)); continue; }
  judge=$(jq -r '.judge_id // empty' <<<"$cal")
  if [ -z "$judge" ] || ! seen_add calibrated_judges "$judge" || ! jq -e '.result == "eligible" and .human_labelled_pairs == 24 and .correct >= 17 and .wilson_lcb_95 >= .50 and .side_probe_n >= 12 and .side_probe_exact_binomial_p >= .05 and .mirror_probe_n >= 8 and .mirror_contradictions < 2 and (.judge_configuration.kind == "human" or .judge_configuration.kind == "machine")' >/dev/null <<<"$cal"; then add_reason CALIBRATION_INVALID; fi
  [ "$(jq -r '.judge_configuration.kind // empty' <<<"$cal")" = human ] || all_human=false
  cal_index=$((cal_index + 1))
done
OLDIFS=$IFS; IFS='|'; for judge in $judges; do case "|$calibrated_judges|" in *"|$judge|"*) ;; *) add_reason JUDGE_NOT_CALIBRATED;; esac; done; IFS=$OLDIFS
threat=$(safe_receipt "$(jq -r .threat_report "$manifest")" taste-threat-receipt/v1) || add_reason THREAT_GATE
if [ -n "${threat:-}" ] && ! jq -e '.status == "clean" and .prompt_injection == "clean" and .receipt_integrity == "clean" and .provenance == "clean" and .axis_results.genericness_review != "unknown" and .axis_results.quality_risk == "pass" and .axis_results.context_fit == "pass" and .axis_results.provenance_integrity != "unknown"' >/dev/null <<<"$threat"; then add_reason THREAT_GATE; fi
repair=$(safe_receipt "$(jq -r .repair_ledger "$manifest")" taste-repair-ledger/v1) || add_reason REPAIR_LEDGER
if [ -n "${repair:-}" ] && jq -e '.status == "valid" and (.sha256|type == "string" and length > 0)' >/dev/null <<<"$repair"; then repair_sha=$(jq -r .sha256 <<<"$repair"); else add_reason REPAIR_LEDGER; fi
if [ -n "$reasons" ]; then write_certificate NOT-CERTIFIED false false NOT-CERTIFIED || true; exit 1; fi
if [ "$all_human" = true ]; then write_certificate TASTE-CERTIFIED true true HUMAN_CERTIFIED; else write_certificate TASTE-CERTIFIED true false HUMAN_CALIBRATED_MACHINE; fi
