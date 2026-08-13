#!/usr/bin/env bash
# polylane-taste-a11y-live.sh — trusted LIVE accessibility evidence runner.
#
# The production/live sibling of the v1 accessibility runner. It consumes a
# verified live capture manifest (bound browser provenance + per-state DOM and
# scripted keyboard/action + reflow/motion evidence) and a coordinator-pinned
# accessibility ENGINE, then recomputes a PASS/FAIL/EXTERNAL/UNKNOWN verdict from
# exact per-capture/per-criterion rule outcomes. It never trusts a caller verdict:
#   * the engine is pinned by package + version + source-hash and re-hashed here;
#   * every DOM and action input is bound to its digest (forged inputs rejected);
#   * every required criterion must carry measured evidence on every capture;
#   * a rule the engine could not measure ("skipped") is an evidence gap that
#     forces UNKNOWN and can NEVER become PASS (mirrors an unavailable engine or a
#     required manual review — automation is scoped evidence, not a11y proof);
#   * the challenger is compared to an eligible baseline and any NEW required
#     violation (or regression, or un-waived pre-existing violation) is a veto;
#   * manual exceptions must be pre-registered (frozen id, rationale, scope,
#     reviewer boundary, and a pre-study timestamp) — automation never approves
#     one, and a drifted (post-study) exception is rejected.
#
# Usage:
#   polylane-taste-a11y-live.sh audit <project-root> <live-capture-manifest.json> \
#       <a11y-live-plan.json> <receipt-out.json> -- <engine-cmd> [args...]
#
# The engine command is invoked once with POLYLANE_A11Y_REQUEST (a request file
# this runner writes) and POLYLANE_A11Y_OUTPUT (a directory) in its environment;
# it must emit result.json (taste-a11y-live-result/v1) and receipt.json
# (taste-live-engine-receipt/v1). Main is guarded so sourcing runs nothing.
set -euo pipefail

# Canonical automatable WCAG 2.1 AA criteria audited on every captured state.
# Manual criteria are judged by humans and can never be auto-scored here.
A11Y_CRITERIA="semantics-name-role-value labels-instructions error-identification heading-landmark-structure keyboard-reachable focus-order no-keyboard-trap keyboard-escape focus-visible target-size contrast non-color-state reflow-zoom-overflow reduced-motion status-announcements"
A11Y_MANUAL="screen-reader-usability cognitive-accessibility localization-rtl"

A11Y_TEMP=""

usage() {
  echo "usage: polylane-taste-a11y-live.sh audit <project-root> <live-capture-manifest.json> <a11y-live-plan.json> <receipt-out.json> -- <engine-cmd> [args...]" >&2
}

reject() { printf 'TASTE-A11Y-LIVE: %s\n' "$1" >&2; return 2; }

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else return 1; fi
}

sha256_stdin() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'
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
  duplicates=$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("")' "$file" 2>/dev/null | LC_ALL=C sort | uniq -d)
  [ -z "$duplicates" ]
}

manifest_shape() {
  jq -e '
    (keys == (["browser","candidate_id","candidate_source_revision","captures","schema_version"]|sort))
    and .schema_version == "taste-a11y-live-capture/v1"
    and (.candidate_id | type == "string" and length > 0)
    and (.candidate_source_revision | type == "string" and test("^[0-9a-f]{40,64}$"))
    and (.browser | type == "object" and (keys == (["adapter_id","adapter_receipt_sha256"]|sort))
      and (.adapter_id | type == "string" and length > 0)
      and (.adapter_receipt_sha256 | type == "string" and test("^[0-9a-f]{64}$")))
    and (.captures | type == "array" and length > 0)
    and all(.captures[];
      type == "object"
      and (keys == (["action_trace_sha256","capture_id","captured_at","dom_sha256","payload","route","state","viewport"]|sort))
      and (.capture_id | type == "string" and length > 0)
      and (.route | type == "string" and length > 0)
      and (.state | type == "string" and length > 0)
      and (.viewport | IN("desktop","mobile"))
      and (.captured_at | type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"))
      and (.payload | type == "object")
      and all([.dom_sha256,.action_trace_sha256][]; type == "string" and test("^[0-9a-f]{64}$")))
    and ((.captures | map(.capture_id)) | length == (unique | length))
  ' "$1" >/dev/null 2>&1
}

plan_shape() {
  local canon="$2" manual="$3"
  jq -e --argjson canon "$canon" --argjson manual "$manual" '
    (keys == (["baseline_receipt_path","candidate_id","design_lock_sha256","engine","evidence_class","manual_external_criteria","schema_version","scoped_exceptions","source_revision","study_started_at"]|sort))
    and .schema_version == "taste-a11y-live-plan/v1"
    and (.candidate_id | type == "string" and length > 0)
    and (.source_revision | type == "string" and test("^[0-9a-f]{40,64}$"))
    and (.design_lock_sha256 | type == "string" and test("^[0-9a-f]{64}$"))
    and (.evidence_class | IN("fixture","production"))
    and (.study_started_at | type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"))
    and (.baseline_receipt_path | type == "string")
    and (.engine | type == "object" and (keys == (["engine_id","engine_package","engine_version","source_path","source_sha256"]|sort))
      and all([.engine_id,.engine_package,.engine_version,.source_path][]; type == "string" and length > 0)
      and (.source_sha256 | type == "string" and test("^[0-9a-f]{64}$")))
    and (.manual_external_criteria | type == "array" and (length == (unique | length)) and all(.[]; . as $c | $manual | index($c) != null))
    and (.scoped_exceptions | type == "array"
      and all(.[]; type == "object"
        and (keys == (["capture_id","created_at","criterion","frozen_id","rationale","reviewer_boundary","scope_sha256"]|sort))
        and (.criterion | . as $c | $canon | index($c) != null)
        and all([.capture_id,.frozen_id,.rationale,.reviewer_boundary][]; type == "string" and length > 0)
        and (.created_at | type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"))
        and (.scope_sha256 | type == "string" and test("^[0-9a-f]{64}$"))))
  ' "$1" >/dev/null 2>&1
}

result_shape() {
  jq -e '
    (keys == (["captures","engine_id","engine_package","engine_source_sha256","engine_version","evidence_class","schema_version"]|sort))
    and .schema_version == "taste-a11y-live-result/v1"
    and all([.engine_id,.engine_package,.engine_version][]; type == "string" and length > 0)
    and (.engine_source_sha256 | type == "string" and test("^[0-9a-f]{64}$"))
    and (.evidence_class | IN("fixture","production"))
    and (.captures | type == "array" and length > 0)
    and all(.captures[];
      type == "object" and (keys == (["action_trace_sha256","capture_id","checks","dom_sha256"]|sort))
      and (.capture_id | type == "string" and length > 0)
      and all([.dom_sha256,.action_trace_sha256][]; type == "string" and test("^[0-9a-f]{64}$"))
      and (.checks | type == "array" and length > 0)
      and all(.checks[];
        type == "object" and (keys == (["check_id","criterion","measured","region","status"]|sort))
        and all([.criterion,.check_id,.region][]; type == "string" and length > 0)
        and (.status | IN("pass","fail","not-applicable","skipped"))
        and (.measured | type == "object")))
  ' "$1" >/dev/null 2>&1
}

# receipt_shape_and_binding RECEIPT ENGINE_ID SOURCE_SHA INPUT_SHA OUTPUT_SHA SRC_EPOCH NOW_EPOCH
receipt_shape_and_binding() {
  local receipt="$1" engine_id="$2" source_sha="$3" input_sha="$4" output_sha="$5" src_epoch="$6" now_epoch="$7" executed epoch dups
  regular_json_without_duplicate_keys "$receipt" || return 1
  dups=$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("")' "$receipt" 2>/dev/null | LC_ALL=C sort | uniq -d)
  [ -z "$dups" ] || return 1
  jq -e --arg id "$engine_id" --arg source "$source_sha" --arg input "$input_sha" --arg output "$output_sha" '
    (keys == (["engine_id","engine_source_sha256","engine_version","executed_at","exit_status","input_sha256","output_sha256","schema_version"]|sort))
    and .schema_version == "taste-live-engine-receipt/v1"
    and .engine_id == $id
    and (.engine_version | type == "string" and length > 0)
    and .engine_source_sha256 == $source
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
  [ "$#" -gt 0 ] || { reject ENGINE_UNAVAILABLE; return 2; }
  local canon manual now now_epoch manifest_dir head_rev src_epoch study_epoch
  local engine_path engine_sha request outdir result_json result_sha request_sha
  local plan_engine_id plan_engine_pkg plan_engine_ver plan_engine_src plan_class base_path base_file cid

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

  # Study window: pre-registration cutoff must be valid and not in the future.
  study_epoch=$(utc_epoch "$(jq -r '.study_started_at' "$plan")") || reject INVALID_STUDY_WINDOW
  [ "$study_epoch" -le "$now_epoch" ] || reject INVALID_STUDY_WINDOW

  # Bind every DOM and action input to its declared digest, and reject a capture
  # that predates the source it claims or is dated in the future (stale capture).
  for cid in $(jq -r '.captures[].capture_id' "$manifest"); do
    local cap dom_declared act_declared dom_actual act_actual cap_at cap_epoch
    cap=$(jq -c --arg id "$cid" '.captures[]|select(.capture_id==$id)' "$manifest")
    dom_declared=$(printf '%s' "$cap" | jq -r '.dom_sha256')
    act_declared=$(printf '%s' "$cap" | jq -r '.action_trace_sha256')
    dom_actual=$(printf '%s' "$cap" | jq -Sc '.payload.dom' | sha256_stdin) || reject SHA256_UNAVAILABLE
    act_actual=$(printf '%s' "$cap" | jq -Sc '.payload.actions' | sha256_stdin) || reject SHA256_UNAVAILABLE
    [ "$dom_declared" = "$dom_actual" ] || reject DOM_BINDING
    [ "$act_declared" = "$act_actual" ] || reject ACTION_BINDING
    cap_at=$(printf '%s' "$cap" | jq -r '.captured_at')
    cap_epoch=$(utc_epoch "$cap_at") || reject STALE_CAPTURE
    { [ "$cap_epoch" -ge "$src_epoch" ] && [ "$cap_epoch" -le "$now_epoch" ]; } || reject STALE_CAPTURE
  done

  # Every scoped exception must be pre-registered before the study window.
  # A post-study ("drifted") exception can never be minted to hide a violation.
  for cid in $(jq -r '.scoped_exceptions[]?.frozen_id' "$plan"); do
    local exc_at exc_epoch
    exc_at=$(jq -r --arg f "$cid" '.scoped_exceptions[]|select(.frozen_id==$f)|.created_at' "$plan")
    exc_epoch=$(utc_epoch "$exc_at") || reject EXCEPTION_DRIFT
    [ "$exc_epoch" -le "$study_epoch" ] || reject EXCEPTION_DRIFT
  done

  # Pin the engine: the pinned source file's digest must equal the plan pin.
  plan_engine_id=$(jq -r '.engine.engine_id' "$plan")
  plan_engine_pkg=$(jq -r '.engine.engine_package' "$plan")
  plan_engine_ver=$(jq -r '.engine.engine_version' "$plan")
  plan_engine_src=$(jq -r '.engine.source_sha256' "$plan")
  plan_class=$(jq -r '.evidence_class' "$plan")
  safe_relative_regular_file "$root" "$(jq -r '.engine.source_path' "$plan")" || reject ENGINE_MISSING
  engine_path="$root/$(jq -r '.engine.source_path' "$plan")"
  engine_sha=$(sha256_file "$engine_path") || reject SHA256_UNAVAILABLE
  [ "$engine_sha" = "$plan_engine_src" ] || reject ENGINE_MISMATCH

  # Isolated, atomic workspace for the engine request/output.
  A11Y_TEMP=$(mktemp -d "${TMPDIR:-/tmp}/polylane-a11y-live.XXXXXX") || reject WORKSPACE_UNAVAILABLE
  trap 'rm -rf "$A11Y_TEMP"' EXIT HUP INT TERM
  request="$A11Y_TEMP/request.json"; outdir="$A11Y_TEMP/engine-out"; mkdir -p "$outdir"
  jq -n --slurpfile m "$manifest" --slurpfile p "$plan" --argjson canon "$canon" '
    {schema_version:"taste-a11y-live-request/v1",candidate_id:$m[0].candidate_id,source_revision:$m[0].candidate_source_revision,
     evidence_class:$p[0].evidence_class,
     engine:{engine_id:$p[0].engine.engine_id,engine_package:$p[0].engine.engine_package,engine_version:$p[0].engine.engine_version,source_sha256:$p[0].engine.source_sha256},
     required_criteria:$canon,
     captures:[$m[0].captures[]|{capture_id,route,state,viewport,dom_sha256,action_trace_sha256,payload}]}' > "$request"
  request_sha=$(sha256_file "$request")

  if env POLYLANE_A11Y_REQUEST="$request" POLYLANE_A11Y_OUTPUT="$outdir" POLYLANE_A11Y_NOW="$now" "$@" >/dev/null 2>&1; then :; else
    reject ENGINE_FAILED
  fi
  result_json="$outdir/result.json"
  [ -f "$result_json" ] && [ ! -L "$result_json" ] || reject ENGINE_RESULT_MISSING
  [ -f "$outdir/receipt.json" ] && [ ! -L "$outdir/receipt.json" ] || reject ENGINE_RECEIPT
  regular_json_without_duplicate_keys "$result_json" || reject ENGINE_RESULT_SHAPE

  # No caller-authored verdict may ride along in the engine output. Match ANY
  # path whose leaf key is a verdict word (a stream + `jq -e` would only test the
  # last emitted value, so a smuggled key not in final position would slip).
  jq -e 'any(paths; .[-1] as $k | ($k|type) == "string" and (($k|ascii_downcase) | IN("pass","verdict","promote","promoted","certified","authorized","overall_status")))' "$result_json" >/dev/null 2>&1 && reject CALLER_PASS
  result_shape "$result_json" || reject ENGINE_RESULT_SHAPE

  # Engine identity, package, version, source-hash, and evidence class must all
  # match the pinned plan (a different engine or a relabeled class is rejected).
  [ "$(jq -r '.engine_id' "$result_json")" = "$plan_engine_id" ] || reject ENGINE_IDENTITY_MISMATCH
  [ "$(jq -r '.engine_package' "$result_json")" = "$plan_engine_pkg" ] || reject ENGINE_IDENTITY_MISMATCH
  [ "$(jq -r '.engine_version' "$result_json")" = "$plan_engine_ver" ] || reject ENGINE_IDENTITY_MISMATCH
  [ "$(jq -r '.engine_source_sha256' "$result_json")" = "$plan_engine_src" ] || reject ENGINE_SOURCE_MISMATCH
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

  # Every check must carry measured evidence — never a bare pass/fail/skip.
  jq -e 'all(.captures[].checks[]; .measured | length > 0)' "$result_json" >/dev/null 2>&1 || reject MISSING_MEASURED_EVIDENCE
  # Unknown criteria, auto-scored manual criteria, duplicates, and missing coverage.
  jq -e --argjson canon "$canon" --argjson manual "$manual" 'all(.captures[].checks[].criterion; . as $c | ($canon + $manual) | index($c) != null)' "$result_json" >/dev/null 2>&1 || reject UNKNOWN_CRITERION
  jq -e --argjson manual "$manual" 'all(.captures[].checks[].criterion; . as $c | ($manual | index($c)) == null)' "$result_json" >/dev/null 2>&1 || reject MANUAL_AUTO_PASS
  jq -e 'all(.captures[]; (.checks | map(.criterion)) | length == (unique | length))' "$result_json" >/dev/null 2>&1 || reject DUPLICATE_CHECK
  jq -e --argjson canon "$canon" 'all(.captures[]; (.checks | map(.criterion)) as $cs | ($canon - $cs | length) == 0)' "$result_json" >/dev/null 2>&1 || reject COVERAGE_INCOMPLETE

  # Engine receipt binds source pin, request, and result within the run window.
  result_sha=$(sha256_file "$result_json")
  receipt_shape_and_binding "$outdir/receipt.json" "$plan_engine_id" "$plan_engine_src" "$request_sha" "$result_sha" "$src_epoch" "$now_epoch" || reject STALE_RECEIPT

  # Baseline receipt (optional): must be eligible (same schema + evidence class).
  base_path=$(jq -r '.baseline_receipt_path' "$plan")
  base_file=""
  if [ -n "$base_path" ]; then
    safe_relative_regular_file "$manifest_dir" "$base_path" || reject UNSAFE_PATH
    base_file="$manifest_dir/$base_path"
    regular_json_without_duplicate_keys "$base_file" || reject BASELINE_SHAPE
    jq -e '.schema_version == "taste-a11y-live-receipt/v1" and (.results | type == "array")' "$base_file" >/dev/null 2>&1 || reject BASELINE_SHAPE
    [ "$(jq -r '.evidence_class' "$base_file")" = "$plan_class" ] || reject BASELINE_INELIGIBLE
  fi

  # Recompute violations, regressions, evidence gaps, exceptions, and verdict.
  local manifest_sha plan_sha base_sha receipt_json tmp_receipt
  manifest_sha=$(sha256_file "$manifest"); plan_sha=$(sha256_file "$plan")
  base_sha=""; [ -n "$base_file" ] && base_sha=$(sha256_file "$base_file")
  receipt_json=$(jq -n \
    --slurpfile M "$manifest" --slurpfile R "$result_json" --slurpfile P "$plan" \
    --slurpfile B "${base_file:-/dev/null}" \
    --argjson canon "$canon" --arg manifest_sha "$manifest_sha" --arg plan_sha "$plan_sha" \
    --arg result_sha "$result_sha" --arg base_sha "$base_sha" --arg now "$now" \
    --arg engine_sha "$plan_engine_src" '
    ($M[0]) as $m | ($R[0]) as $r | ($P[0]) as $p |
    (if ($B|length) > 0 then $B[0] else null end) as $b |
    ($m.captures | map({key:.capture_id,value:{route,state,viewport}}) | from_entries) as $meta |
    (if $b then ($b.results | map({key:(.route+"\u0000"+.state+"\u0000"+.viewport+"\u0000"+.criterion),value:.status}) | from_entries) else {} end) as $base |
    ($p.scoped_exceptions | map({key:(.capture_id+"\u0000"+.criterion),value:.}) | from_entries) as $exc |
    [ $r.captures[] as $c | $c.checks[] | . + {capture_id:$c.capture_id} + ($meta[$c.capture_id]) ] as $checks |
    ($checks | map({capture_id,route,state,viewport,criterion,check_id,region,status,measured})) as $results |
    [ $checks[] | select(.status == "skipped")
      | {capture_id,route,state,viewport,criterion,check_id,region,measured,reason_code:"EVIDENCE_GAP"} ] as $gaps |
    [ $checks[] | select(.status == "fail")
      | (.route+"\u0000"+.state+"\u0000"+.viewport+"\u0000"+.criterion) as $k
      | ($base[$k]) as $bs
      | (if ($b | not) then "NEW_VIOLATION"
         elif ($bs == "fail") then (if $exc[.capture_id+"\u0000"+.criterion] then "ACCEPTED_EXCEPTION" else "PREEXISTING_VIOLATION" end)
         else "REGRESSION" end) as $rc
      | {capture_id,route,state,viewport,criterion,check_id,region,measured,reason_code:$rc} ] as $classified |
    ($classified | map(select(.reason_code == "REGRESSION"))) as $regressions |
    [ $classified[] | select(.reason_code == "ACCEPTED_EXCEPTION") | $exc[.capture_id+"\u0000"+.criterion] ] as $accepted |
    ([ $classified[] | select(.reason_code | IN("REGRESSION","PREEXISTING_VIOLATION","NEW_VIOLATION")) ] | length > 0) as $veto |
    ($gaps | length > 0) as $gap |
    ($p.manual_external_criteria) as $man |
    (if $veto then "FAIL" elif $gap then "UNKNOWN" elif ($man | length > 0) then "EXTERNAL" else "PASS" end) as $derived |
    (if $veto then ($classified | map(.reason_code) | map(select(. != "ACCEPTED_EXCEPTION")) | unique)
     else (( if ($accepted | length > 0) then ["ACCEPTED_EXCEPTION"]
             elif (($classified|length) == 0 and ($gaps|length) == 0) then ["CLEAN"] else [] end )
           + ( if $gap then ["EVIDENCE_GAP"] else [] end )
           + ( if ($man | length > 0) then ["MANUAL_EXTERNAL"] else [] end )) end) as $reasons |
    {schema_version:"taste-a11y-live-receipt/v1",
     candidate_id:$p.candidate_id,source_revision:$p.source_revision,design_lock_sha256:$p.design_lock_sha256,
     evidence_class:$p.evidence_class,study_started_at:$p.study_started_at,
     browser:{adapter_id:$m.browser.adapter_id,adapter_receipt_sha256:$m.browser.adapter_receipt_sha256},
     engine:{engine_id:$p.engine.engine_id,engine_package:$p.engine.engine_package,engine_version:$p.engine.engine_version,source_sha256:$engine_sha},
     input_sha256:{capture_manifest:$manifest_sha,a11y_plan:$plan_sha,engine_result:$result_sha,baseline_receipt:$base_sha},
     coverage:{required_criteria:$canon,captures:($r.captures|length),checks:($checks|length),evidence_gaps:($gaps|length)},
     results:$results,violations:$classified,regressions:$regressions,evidence_gaps:$gaps,accepted_exceptions:$accepted,
     manual_external:$man,derived_status:$derived,reason_codes:$reasons,generated_at:$now}
  ') || reject RECEIPT_BUILD_FAILED

  # Atomic write of the receipt beside its destination.
  local out_dir out_name
  case "$receipt_out" in ''|/) reject RECEIPT_PATH_UNSAFE ;; esac
  out_dir=$(CDPATH='' cd -- "$(dirname -- "$receipt_out")" 2>/dev/null && pwd -P) || reject RECEIPT_PATH_UNSAFE
  out_name=$(basename -- "$receipt_out")
  [ "$out_name" != . ] && [ "$out_name" != .. ] || reject RECEIPT_PATH_UNSAFE
  tmp_receipt=$(mktemp "$out_dir/.a11y-live-receipt.XXXXXX") || reject RECEIPT_PATH_UNSAFE
  printf '%s\n' "$receipt_json" > "$tmp_receipt"
  mv "$tmp_receipt" "$out_dir/$out_name"

  rm -rf "$A11Y_TEMP"; A11Y_TEMP=""; trap - EXIT HUP INT TERM
  printf 'TASTE-A11Y-LIVE: %s captures=%s checks=%s gaps=%s\n' \
    "$(printf '%s' "$receipt_json" | jq -r '.derived_status')" \
    "$(printf '%s' "$receipt_json" | jq -r '.coverage.captures')" \
    "$(printf '%s' "$receipt_json" | jq -r '.coverage.checks')" \
    "$(printf '%s' "$receipt_json" | jq -r '.coverage.evidence_gaps')"
}

main() {
  case "${1:-}" in
    audit) [ "$#" -ge 6 ] || { usage; return 2; }; shift; audit "$@" ;;
    *) usage; return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
