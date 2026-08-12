#!/usr/bin/env bash
# polylane-taste-a11y.sh — trusted accessibility evidence runner.
#
# Consumes a verified capture manifest and a coordinator-pinned, receipted
# accessibility adapter, then recomputes a PASS/FAIL/EXTERNAL verdict from exact
# per-capture/per-criterion evidence. It never trusts a caller-authored pass
# boolean: every criterion must carry measured evidence, coverage is recomputed
# against the full capture matrix, the challenger is compared to a baseline
# receipt, and any new regression is a hard veto. Manual screen-reader,
# cognitive, and localization judgments stay external and can never be
# auto-passed.
#
# Usage:
#   polylane-taste-a11y.sh audit <project-root> <capture-manifest.json> \
#       <a11y-plan.json> <receipt-out.json> -- <adapter> [args...]
#
# The adapter is invoked once with POLYLANE_A11Y_REQUEST (a request file this
# runner writes) and POLYLANE_A11Y_OUTPUT (a directory) in its environment; it
# must emit result.json (taste-a11y-adapter-result/v1) and receipt.json
# (taste-adapter-receipt/v1). This file is intentionally executable at a
# declared adapter boundary; its main is guarded so sourcing runs nothing.
set -euo pipefail

# Canonical automatable WCAG 2.1 AA criteria audited on every captured state.
# Manual criteria are judged by humans and can never be auto-passed here.
A11Y_CRITERIA="semantics-name-role-value labels-instructions error-identification heading-landmark-structure keyboard-reachable focus-order no-keyboard-trap keyboard-escape focus-visible target-size contrast non-color-state reflow-zoom-overflow reduced-motion status-announcements"
A11Y_MANUAL="screen-reader-usability cognitive-accessibility localization-rtl"

A11Y_TEMP=""

usage() {
  echo "usage: polylane-taste-a11y.sh audit <project-root> <capture-manifest.json> <a11y-plan.json> <receipt-out.json> -- <adapter> [args...]" >&2
}

reject() { printf 'TASTE-A11Y: %s\n' "$1" >&2; return 2; }

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else return 1; fi
}

sha256_text() {
  if command -v shasum >/dev/null 2>&1; then printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then printf '%s' "$1" | sha256sum | awk '{print $1}'
  else return 1; fi
}

rfc3339_utc() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

utc_epoch() {
  case "$1" in ????-??-??T??:??:??Z) ;; *) return 1 ;; esac
  date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$1" '+%s' 2>/dev/null ||
    date -u -d "$1" '+%s' 2>/dev/null
}

# safe_relative_regular_file ROOT PATH — repo-relative, no symlink component.
safe_relative_regular_file() {
  local root="$1" path="$2" part prefix old_ifs
  case "$path" in ""|/*|*'//'*) return 1 ;; esac
  prefix="$root"; old_ifs=$IFS; IFS='/'
  for part in $path; do
    [ -n "$part" ] && [ "$part" != . ] && [ "$part" != .. ] || { IFS=$old_ifs; return 1; }
    prefix="$prefix/$part"
    [ ! -L "$prefix" ] || { IFS=$old_ifs; return 1; }
  done
  IFS=$old_ifs
  [ -f "$root/$path" ] && [ ! -L "$root/$path" ]
}

regular_json_without_duplicate_keys() {
  local file="$1" duplicates
  [ -f "$file" ] && [ ! -L "$file" ] || return 1
  jq -e . "$file" >/dev/null 2>&1 || return 1
  duplicates=$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("")' "$file" 2>/dev/null | LC_ALL=C sort | uniq -d)
  [ -z "$duplicates" ]
}

manifest_shape() {
  jq -e '
    (keys | sort) == ["browser","candidate_id","candidate_source_revision","captures","decoder","mobile_only_states","required_routes","required_states","schema_version"]
    and .schema_version == "taste-capture-manifest/v1"
    and (.candidate_id | type == "string" and length > 0)
    and (.candidate_source_revision | type == "string" and test("^[0-9a-f]{40,64}$"))
    and (.captures | type == "array" and length > 0)
    and all(.captures[];
      type == "object"
      and (.capture_id | type == "string" and length > 0)
      and (.route | type == "string" and length > 0)
      and (.state | type == "string" and length > 0)
      and (.viewport | IN("desktop","mobile"))
      and all([.dom_sha256,.action_trace_sha256][]; type == "string" and test("^[0-9a-f]{64}$")))
  ' "$1" >/dev/null 2>&1
}

plan_shape() {
  local canon="$2" manual="$3"
  jq -e --argjson canon "$canon" --argjson manual "$manual" '
    (keys | sort) == ["adapter","baseline_receipt_path","candidate_id","design_lock_sha256","evidence_class","manual_external_criteria","schema_version","scoped_exceptions","source_revision"]
    and .schema_version == "taste-a11y-plan/v1"
    and (.candidate_id | type == "string" and length > 0)
    and (.source_revision | type == "string" and test("^[0-9a-f]{40,64}$"))
    and (.design_lock_sha256 | type == "string" and test("^[0-9a-f]{64}$"))
    and (.evidence_class | IN("fixture","production"))
    and (.baseline_receipt_path | type == "string")
    and (.adapter | type == "object" and (keys | sort) == ["adapter_id","adapter_version","command_path","command_sha256","profile_sha256"]
      and all([.adapter_id,.adapter_version,.command_path][]; type == "string" and length > 0)
      and all([.command_sha256,.profile_sha256][]; type == "string" and test("^[0-9a-f]{64}$")))
    and (.manual_external_criteria | type == "array" and (length == (unique | length)) and all(.[]; . as $c | $manual | index($c) != null))
    and (.scoped_exceptions | type == "array"
      and all(.[]; type == "object" and (keys | sort) == ["capture_id","criterion","manual_owner","reason","scope_sha256"]
        and (.criterion | . as $c | $canon | index($c) != null)
        and all([.capture_id,.manual_owner,.reason][]; type == "string" and length > 0)
        and (.scope_sha256 | type == "string" and test("^[0-9a-f]{64}$"))))
  ' "$1" >/dev/null 2>&1
}

result_shape() {
  jq -e '
    (keys | sort) == ["adapter_id","adapter_version","captures","evidence_class","profile_sha256","schema_version"]
    and .schema_version == "taste-a11y-adapter-result/v1"
    and all([.adapter_id,.adapter_version][]; type == "string" and length > 0)
    and (.profile_sha256 | type == "string" and test("^[0-9a-f]{64}$"))
    and (.evidence_class | IN("fixture","production"))
    and (.captures | type == "array" and length > 0)
    and all(.captures[];
      type == "object" and (keys | sort) == ["action_trace_sha256","capture_id","checks","dom_sha256"]
      and (.capture_id | type == "string" and length > 0)
      and all([.dom_sha256,.action_trace_sha256][]; type == "string" and test("^[0-9a-f]{64}$"))
      and (.checks | type == "array" and length > 0)
      and all(.checks[];
        type == "object" and (keys | sort) == ["check_id","criterion","measured","region","status"]
        and all([.criterion,.check_id,.region][]; type == "string" and length > 0)
        and (.status | IN("pass","fail","not-applicable"))
        and (.measured | type == "object")))
  ' "$1" >/dev/null 2>&1
}

# receipt_shape_and_binding RECEIPT ADAPTER_ID COMMAND_SHA INPUT_SHA OUTPUT_SHA SRC_EPOCH NOW_EPOCH
receipt_shape_and_binding() {
  local receipt="$1" adapter_id="$2" command_sha="$3" input_sha="$4" output_sha="$5" src_epoch="$6" now_epoch="$7" executed epoch dups
  regular_json_without_duplicate_keys "$receipt" || return 1
  dups=$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("")' "$receipt" 2>/dev/null | LC_ALL=C sort | uniq -d)
  [ -z "$dups" ] || return 1
  jq -e --arg id "$adapter_id" --arg command "$command_sha" --arg input "$input_sha" --arg output "$output_sha" '
    (keys | sort) == ["adapter_id","adapter_version","command_sha256","executed_at","exit_status","input_sha256","output_sha256","schema_version"]
    and .schema_version == "taste-adapter-receipt/v1"
    and .adapter_id == $id
    and (.adapter_version | type == "string" and length > 0)
    and .command_sha256 == $command
    and (.input_sha256 | type == "array" and all(.[]; type == "string" and test("^[0-9a-f]{64}$")) and index($input) != null)
    and (.output_sha256 | type == "array" and all(.[]; type == "string" and test("^[0-9a-f]{64}$")) and index($output) != null)
    and .exit_status == 0
    and (.executed_at | type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"))
  ' "$receipt" >/dev/null 2>&1 || return 1
  executed=$(jq -r '.executed_at' "$receipt") || return 1
  epoch=$(utc_epoch "$executed") || return 1
  [ "$epoch" -ge "$src_epoch" ] && [ "$epoch" -le "$now_epoch" ]
}

audit() {
  local root="$1" manifest="$2" plan="$3" receipt_out="$4"
  shift 4
  [ "${1:-}" = "--" ] || { usage; return 2; }
  shift
  [ "$#" -gt 0 ] || { die_no_adapter; return 2; }
  local adapter="$1"
  local canon manual now now_epoch manifest_dir head_rev src_epoch
  local adapter_sha request outdir result_json result_sha request_sha
  local plan_cmd_sha plan_adapter_id plan_profile plan_class base_path base_file

  command -v jq >/dev/null 2>&1 || reject JQ_UNAVAILABLE
  [ -d "$root" ] && [ ! -L "$root" ] || reject UNSAFE_ROOT
  [ -f "$manifest" ] && [ ! -L "$manifest" ] || reject MANIFEST_UNAVAILABLE
  [ -f "$plan" ] && [ ! -L "$plan" ] || reject PLAN_UNAVAILABLE
  manifest_dir=$(CDPATH='' cd -- "$(dirname -- "$manifest")" 2>/dev/null && pwd -P) || reject MANIFEST_UNAVAILABLE

  canon=$(printf '%s\n' $A11Y_CRITERIA | jq -R . | jq -sc .)
  manual=$(printf '%s\n' $A11Y_MANUAL | jq -R . | jq -sc .)

  regular_json_without_duplicate_keys "$manifest" || reject MANIFEST_SHAPE
  manifest_shape "$manifest" || reject MANIFEST_SHAPE
  regular_json_without_duplicate_keys "$plan" || reject PLAN_SHAPE
  plan_shape "$plan" "$canon" "$manual" || reject PLAN_SHAPE

  # Bind the exact subject revision: manifest, plan, and the live tree must agree.
  head_rev=$(git -C "$root" rev-parse HEAD 2>/dev/null) || reject SOURCE_REVISION_UNAVAILABLE
  [ "$head_rev" = "$(jq -r '.candidate_source_revision' "$manifest")" ] || reject STALE_SOURCE_REVISION
  [ "$head_rev" = "$(jq -r '.source_revision' "$plan")" ] || reject STALE_SOURCE_REVISION
  [ "$(jq -r '.candidate_id' "$manifest")" = "$(jq -r '.candidate_id' "$plan")" ] || reject CANDIDATE_MISMATCH
  src_epoch=$(git -C "$root" log -1 --format=%ct "$head_rev" 2>/dev/null) || reject SOURCE_TIME_UNAVAILABLE
  now=$(rfc3339_utc); now_epoch=$(utc_epoch "$now") || reject INVALID_NOW

  # Pin the adapter: recomputed digest must equal the plan's coordinator pin.
  plan_cmd_sha=$(jq -r '.adapter.command_sha256' "$plan")
  plan_adapter_id=$(jq -r '.adapter.adapter_id' "$plan")
  plan_profile=$(jq -r '.adapter.profile_sha256' "$plan")
  plan_class=$(jq -r '.evidence_class' "$plan")
  [ -e "$adapter" ] && [ ! -L "$adapter" ] && [ -x "$adapter" ] || reject ADAPTER_UNAVAILABLE
  adapter_sha=$(sha256_file "$adapter") || reject SHA256_UNAVAILABLE
  [ "$adapter_sha" = "$plan_cmd_sha" ] || reject ADAPTER_MISMATCH

  # Isolated, atomic workspace for the adapter request/output.
  A11Y_TEMP=$(mktemp -d "${TMPDIR:-/tmp}/polylane-a11y.XXXXXX") || reject WORKSPACE_UNAVAILABLE
  trap 'rm -rf "$A11Y_TEMP"' EXIT HUP INT TERM
  request="$A11Y_TEMP/request.json"; outdir="$A11Y_TEMP/adapter-out"; mkdir -p "$outdir"
  jq -n --slurpfile m "$manifest" --slurpfile p "$plan" --argjson canon "$canon" '
    {schema_version:"taste-a11y-request/v1",candidate_id:$m[0].candidate_id,source_revision:$m[0].candidate_source_revision,
     evidence_class:$p[0].evidence_class,
     adapter:{adapter_id:$p[0].adapter.adapter_id,adapter_version:$p[0].adapter.adapter_version,profile_sha256:$p[0].adapter.profile_sha256},
     required_criteria:$canon,
     captures:[$m[0].captures[]|{capture_id,route,state,viewport,dom_sha256,action_trace_sha256}]}' > "$request"
  request_sha=$(sha256_file "$request")

  if env POLYLANE_A11Y_REQUEST="$request" POLYLANE_A11Y_OUTPUT="$outdir" "$@" >/dev/null 2>&1; then :; else
    reject ADAPTER_FAILED
  fi
  result_json="$outdir/result.json"
  [ -f "$result_json" ] && [ ! -L "$result_json" ] || reject ADAPTER_RESULT_MISSING
  [ -f "$outdir/receipt.json" ] && [ ! -L "$outdir/receipt.json" ] || reject ADAPTER_RECEIPT
  regular_json_without_duplicate_keys "$result_json" || reject ADAPTER_RESULT_SHAPE

  # No caller-authored verdict may ride along in the adapter output.
  jq -e 'paths | .[-1] | if type=="string" then (ascii_downcase | IN("pass","verdict","promote","promoted","certified","authorized","overall_status")) else false end' "$result_json" >/dev/null 2>&1 && reject CALLER_PASS
  result_shape "$result_json" || reject ADAPTER_RESULT_SHAPE

  # Adapter identity, profile, and evidence class must match the pinned plan.
  [ "$(jq -r '.adapter_id' "$result_json")" = "$plan_adapter_id" ] || reject ADAPTER_MISMATCH
  [ "$(jq -r '.profile_sha256' "$result_json")" = "$plan_profile" ] || reject PROFILE_MISMATCH
  [ "$(jq -r '.evidence_class' "$result_json")" = "$plan_class" ] || reject FIXTURE_RELABELED

  # Exact capture set, and every DOM/action digest bound to the manifest.
  local m_ids r_ids
  m_ids=$(jq -r '[.captures[].capture_id]|sort|join(",")' "$manifest")
  r_ids=$(jq -r '[.captures[].capture_id]|sort|join(",")' "$result_json")
  [ "$m_ids" = "$r_ids" ] || reject MATRIX_MISMATCH
  jq -e --slurpfile m "$manifest" '
    ($m[0].captures | map({key:.capture_id,value:{d:.dom_sha256,a:.action_trace_sha256}}) | from_entries) as $x
    | all(.captures[]; ($x[.capture_id]) as $e | $e != null and .dom_sha256 == $e.d and .action_trace_sha256 == $e.a)
  ' "$result_json" >/dev/null 2>&1 || reject FORGED_CAPTURE

  # Every pass/fail check must carry measured evidence — never a bare pass.
  jq -e 'all(.captures[].checks[]; (.status == "not-applicable") or (.measured | length > 0))' "$result_json" >/dev/null 2>&1 || reject MISSING_MEASURED_EVIDENCE
  # Unknown criteria, auto-passed manual criteria, duplicates, and missing coverage.
  jq -e --argjson canon "$canon" --argjson manual "$manual" 'all(.captures[].checks[].criterion; . as $c | ($canon + $manual) | index($c) != null)' "$result_json" >/dev/null 2>&1 || reject UNKNOWN_CRITERION
  jq -e --argjson manual "$manual" 'all(.captures[].checks[].criterion; . as $c | ($manual | index($c)) == null)' "$result_json" >/dev/null 2>&1 || reject MANUAL_AUTO_PASS
  jq -e 'all(.captures[]; (.checks | map(.criterion)) | length == (unique | length))' "$result_json" >/dev/null 2>&1 || reject DUPLICATE_CHECK
  jq -e --argjson canon "$canon" 'all(.captures[]; (.checks | map(.criterion)) as $cs | ($canon - $cs | length) == 0)' "$result_json" >/dev/null 2>&1 || reject COVERAGE_INCOMPLETE

  # Adapter receipt binds command pin, request, and result within the run window.
  result_sha=$(sha256_file "$result_json")
  receipt_shape_and_binding "$outdir/receipt.json" "$plan_adapter_id" "$plan_cmd_sha" "$request_sha" "$result_sha" "$src_epoch" "$now_epoch" || reject STALE_RECEIPT

  # Baseline receipt (optional): compare challenger to the incumbent.
  base_path=$(jq -r '.baseline_receipt_path' "$plan")
  base_file=""
  if [ -n "$base_path" ]; then
    safe_relative_regular_file "$manifest_dir" "$base_path" || reject UNSAFE_PATH
    base_file="$manifest_dir/$base_path"
    regular_json_without_duplicate_keys "$base_file" || reject BASELINE_SHAPE
    jq -e '.schema_version == "taste-a11y-receipt/v1" and (.results | type == "array")' "$base_file" >/dev/null 2>&1 || reject BASELINE_SHAPE
  fi

  # Recompute violations, regressions, accepted exceptions, and the verdict.
  local manifest_sha plan_sha base_sha receipt_json tmp_receipt
  manifest_sha=$(sha256_file "$manifest"); plan_sha=$(sha256_file "$plan")
  base_sha=""; [ -n "$base_file" ] && base_sha=$(sha256_file "$base_file")
  receipt_json=$(jq -n \
    --slurpfile M "$manifest" --slurpfile R "$result_json" --slurpfile P "$plan" \
    --slurpfile B "${base_file:-/dev/null}" \
    --argjson canon "$canon" --arg manifest_sha "$manifest_sha" --arg plan_sha "$plan_sha" \
    --arg result_sha "$result_sha" --arg base_sha "$base_sha" --arg now "$now" \
    --arg cmd_sha "$plan_cmd_sha" '
    ($M[0]) as $m | ($R[0]) as $r | ($P[0]) as $p |
    (if ($B|length) > 0 then $B[0] else null end) as $b |
    ($m.captures | map({key:.capture_id,value:{route,state,viewport}}) | from_entries) as $meta |
    (if $b then ($b.results | map({key:(.route+""+.state+""+.viewport+""+.criterion),value:.status}) | from_entries) else {} end) as $base |
    ($p.scoped_exceptions | map({key:(.capture_id+""+.criterion),value:.}) | from_entries) as $exc |
    [ $r.captures[] as $c | $c.checks[] | . + {capture_id:$c.capture_id} + ($meta[$c.capture_id]) ] as $checks |
    ($checks | map({capture_id,route,state,viewport,criterion,check_id,region,status,measured})) as $results |
    [ $checks[] | select(.status == "fail")
      | (.route+""+.state+""+.viewport+""+.criterion) as $k
      | ($base[$k]) as $bs
      | (if ($b | not) then "NEW_VIOLATION"
         elif ($bs == "fail") then (if $exc[.capture_id+""+.criterion] then "ACCEPTED_EXCEPTION" else "PREEXISTING_VIOLATION" end)
         else "REGRESSION" end) as $rc
      | {capture_id,route,state,viewport,criterion,check_id,region,measured,reason_code:$rc} ] as $classified |
    ($classified | map(select(.reason_code == "REGRESSION"))) as $regressions |
    [ $classified[] | select(.reason_code == "ACCEPTED_EXCEPTION") | $exc[.capture_id+""+.criterion] ] as $accepted |
    ([ $classified[] | select(.reason_code | IN("REGRESSION","PREEXISTING_VIOLATION","NEW_VIOLATION")) ] | length > 0) as $veto |
    ($p.manual_external_criteria) as $man |
    (if $veto then "FAIL" elif ($man | length > 0) then "EXTERNAL" else "PASS" end) as $derived |
    (if $veto then ($classified | map(.reason_code) | map(select(. != "ACCEPTED_EXCEPTION")) | unique)
     else (( if ($accepted | length > 0) then ["ACCEPTED_EXCEPTION"] elif (($classified|length) == 0) then ["CLEAN"] else [] end )
           + ( if ($man | length > 0) then ["MANUAL_EXTERNAL"] else [] end )) end) as $reasons |
    {schema_version:"taste-a11y-receipt/v1",
     candidate_id:$p.candidate_id,source_revision:$p.source_revision,design_lock_sha256:$p.design_lock_sha256,
     evidence_class:$p.evidence_class,
     adapter:{adapter_id:$p.adapter.adapter_id,adapter_version:$p.adapter.adapter_version,command_sha256:$cmd_sha,profile_sha256:$p.adapter.profile_sha256},
     input_sha256:{capture_manifest:$manifest_sha,a11y_plan:$plan_sha,adapter_result:$result_sha,baseline_receipt:$base_sha},
     coverage:{required_criteria:$canon,captures:($r.captures|length),checks:($checks|length)},
     results:$results,violations:$classified,regressions:$regressions,accepted_exceptions:$accepted,
     manual_external:$man,derived_status:$derived,reason_codes:$reasons,generated_at:$now}
  ') || reject RECEIPT_BUILD_FAILED

  # Atomic write of the receipt beside its destination.
  local out_dir out_name
  case "$receipt_out" in ''|/) reject RECEIPT_PATH_UNSAFE ;; esac
  out_dir=$(CDPATH='' cd -- "$(dirname -- "$receipt_out")" 2>/dev/null && pwd -P) || reject RECEIPT_PATH_UNSAFE
  out_name=$(basename -- "$receipt_out")
  [ "$out_name" != . ] && [ "$out_name" != .. ] || reject RECEIPT_PATH_UNSAFE
  tmp_receipt=$(mktemp "$out_dir/.a11y-receipt.XXXXXX") || reject RECEIPT_PATH_UNSAFE
  printf '%s\n' "$receipt_json" > "$tmp_receipt"
  mv "$tmp_receipt" "$out_dir/$out_name"

  rm -rf "$A11Y_TEMP"; A11Y_TEMP=""; trap - EXIT HUP INT TERM
  printf 'TASTE-A11Y: %s captures=%s checks=%s\n' "$(printf '%s' "$receipt_json" | jq -r '.derived_status')" \
    "$(printf '%s' "$receipt_json" | jq -r '.coverage.captures')" "$(printf '%s' "$receipt_json" | jq -r '.coverage.checks')"
}

die_no_adapter() { reject ADAPTER_UNAVAILABLE; }

main() {
  case "${1:-}" in
    audit) [ "$#" -ge 6 ] || { usage; return 2; }; shift; audit "$@" ;;
    *) usage; return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
