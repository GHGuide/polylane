#!/usr/bin/env bash
# polylane-taste-task.sh — trusted functional-task evidence runner + hard gate.
#
# Consumes a verified capture manifest (taste-capture-manifest/v1) and a
# coordinator-pinned task plan (taste-task-plan/v1), invokes a pinned browser
# task adapter, then recomputes a PASS/FAIL/EXTERNAL verdict from exact replayed
# browser traces. It proves FUNCTIONAL success and PRODUCT SPECIFICITY, not
# prose:
#
#   * The success ORACLE (expected value) lives in the plan, never the adapter.
#     The adapter reports only OBSERVED measured evidence bound to the pinned
#     DOM. The validator DERIVES each assertion verdict by joining oracle with
#     evidence; it never trusts a caller-authored status/pass/verdict field.
#   * Every capture's replayed action_trace + DOM is content-addressed back to
#     the manifest pins (a re-render that does not reproduce the pinned bytes is
#     NONDETERMINISTIC).
#   * Only allowlisted actions/assertions with safe relative routes/selectors are
#     accepted — no eval, script, or network action can ride in from a brief.
#   * Every required task/state/assertion must resolve; missing/unknown/failing
#     vetoes. Product specificity is proven by a signature naming a brief-specific
#     mechanism, a rendered anchor assertion, a clause trace, an unrelated-brief
#     counterfactual that must be ABSENT, and a task proof.
#
# Usage:
#   polylane-taste-task.sh gate <project-root> <capture-manifest.json> \
#       <task-plan.json> <receipt-out.json> -- <adapter> [args...]
#
# The adapter is invoked once with POLYLANE_TASK_REQUEST (a request file this
# runner writes) and POLYLANE_TASK_OUTPUT (a directory) in its environment; it
# must emit result.json (taste-task-adapter-result/v1) and receipt.json
# (taste-adapter-receipt/v1). classification is hard-derived to "fixture": this
# hermetic replay can never mint a production PASS. This file is intentionally
# executable at a declared adapter boundary; main is guarded so sourcing runs
# nothing.
set -euo pipefail

# Frozen allowlists — identical to benchmarks/taste-live/task-schema.json.
# tests/test-taste-task-live.sh asserts the two never drift.
ALLOWED_ACTIONS="navigate click fill select press wait_for submit"
ALLOWED_ASSERTIONS="exists absent unique count text_equals text_present value_equals attr_equals state_is"

TASK_TEMP=""

usage() {
  echo "usage: polylane-taste-task.sh gate <project-root> <capture-manifest.json> <task-plan.json> <receipt-out.json> -- <adapter> [args...]" >&2
}

reject() { printf 'TASTE-TASK: %s\n' "$1" >&2; return 2; }

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
  duplicates=$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("")' "$file" 2>/dev/null | LC_ALL=C sort | uniq -d)
  [ -z "$duplicates" ]
}

# run_with_timeout SECONDS CMD... — kill CMD after SECONDS; rc 124 on timeout.
run_with_timeout() {
  local secs="$1"; shift
  "$@" & local pid=$!
  ( sleep "$secs"; kill -TERM "$pid" 2>/dev/null ) & local watcher=$!
  local rc=0
  wait "$pid" 2>/dev/null || rc=$?
  if kill -0 "$watcher" 2>/dev/null; then
    kill "$watcher" 2>/dev/null; wait "$watcher" 2>/dev/null || true
    return "$rc"
  fi
  wait "$watcher" 2>/dev/null || true
  return 124
}

# jq helper program: safe selector / safe route predicates, shared by guards.
JQ_SAFE='
  def safe_selector:
    type == "string" and (length > 0) and (length <= 200)
    and test("^[A-Za-z0-9 _.#=\":,()>*\\[\\]-]+$")
    and (contains("javascript:") | not) and (contains("<") | not)
    and (contains("`") | not) and (contains(";") | not)
    and (contains("{") | not) and (contains("}") | not) and (contains("$") | not);
  def safe_route:
    type == "string" and (length > 0) and (length <= 200)
    and test("^/[A-Za-z0-9/_-]*$") and (contains("//") | not) and (contains("..") | not);
'

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
    and ([.captures[].capture_id] | length == (unique | length))
  ' "$1" >/dev/null 2>&1
}

# plan_shape PLAN ALLOWED_ASSERTIONS_JSON
plan_shape() {
  jq -e --argjson kinds "$2" "$JQ_SAFE"'
    . as $p
    | (keys | sort) == ["adapter","baseline_receipt_path","brief_sha256","candidate_id","design_lock_sha256","evidence_class","manual_external_tasks","product_signature","required_states","schema_version","source_revision","tasks"]
    and .schema_version == "taste-task-plan/v1"
    and (.candidate_id | type == "string" and length > 0)
    and (.source_revision | type == "string" and test("^[0-9a-f]{40,64}$"))
    and (.brief_sha256 | type == "string" and test("^[0-9a-f]{64}$"))
    and (.design_lock_sha256 | type == "string" and test("^[0-9a-f]{64}$"))
    and (.evidence_class | IN("fixture","production"))
    and (.baseline_receipt_path | type == "string")
    and (.adapter | type == "object" and (keys | sort) == ["adapter_id","adapter_version","command_path","command_sha256","profile_sha256"]
      and all([.adapter_id,.adapter_version,.command_path][]; type == "string" and length > 0)
      and all([.command_sha256,.profile_sha256][]; type == "string" and test("^[0-9a-f]{64}$")))
    and (.required_states | type == "array" and length > 0 and (length == (unique | length)) and all(.[]; type == "string" and test("^[a-z0-9][a-z0-9-]*$")))
    and (.manual_external_tasks | type == "array" and (length == (unique | length)) and all(.[]; type == "string" and test("^task-[a-z0-9][a-z0-9-]*$")))
    and (.tasks | type == "array" and length > 0
      and ([.[].task_id] | length == (unique | length))
      and all(.[];
        type == "object" and (keys | sort) == ["assertions","brief_clause","reaches_state","task_id"]
        and (.task_id | test("^task-[a-z0-9][a-z0-9-]*$"))
        and (.brief_clause | type == "string" and length > 0)
        and (.reaches_state | . as $s | $p.required_states | index($s) != null)
        and (.assertions | type == "array" and length > 0
          and ([.[].assertion_id] | length == (unique | length))
          and all(.[];
            type == "object" and (keys | sort) == ["assertion_id","expected","kind","selector"]
            and (.assertion_id | test("^assert-[a-z0-9][a-z0-9-]*$"))
            and (.kind | . as $k | $kinds | index($k) != null)
            and (.selector | safe_selector)
            and (if (.kind | IN("exists","absent","unique")) then .expected == null
                 elif .kind == "count" then (.expected | type == "number" and floor == . and . >= 0)
                 else (.expected | type == "string" and length > 0) end)))))
    and (.required_states as $rs | all($rs[]; . as $s | any($p.tasks[]; .reaches_state == $s)))
    and (.manual_external_tasks as $m | all($m[]; . as $t | any($p.tasks[]; .task_id == $t)))
    and (.product_signature | type == "object" and (keys | sort) == ["clause_trace","counterfactual","mechanism","rendered_anchor","task_proof"]
      and (.mechanism | type == "string" and length > 0)
      and (.clause_trace | type == "array" and length > 0 and all(.[]; . as $c | $p.tasks | any(.brief_clause == $c)))
      and (.task_proof | type == "array" and length > 0 and (length == (unique | length)) and all(.[]; . as $t | $p.tasks | any(.task_id == $t)))
      and (.rendered_anchor | type == "object" and (keys | sort) == ["assertion_id","capture_id","task_id"]
        and (.capture_id | type == "string" and length > 0)
        and (.task_id | . as $t | $p.tasks | any(.task_id == $t))
        and (.task_id as $t | .assertion_id as $a | $p.tasks | any(.task_id == $t and (.assertions | any(.assertion_id == $a)))))
      and (.counterfactual | type == "object" and (keys | sort) == ["selector","unrelated_brief_id"]
        and (.unrelated_brief_id | type == "string" and length > 0)
        and (.selector | safe_selector)))
  ' "$1" >/dev/null 2>&1
}

# result_shape RESULT ALLOWED_ASSERTIONS_JSON
result_shape() {
  jq -e --argjson kinds "$2" '
    (keys | sort) == ["adapter_id","adapter_version","captures","evidence_class","profile_sha256","schema_version","signature"]
    and .schema_version == "taste-task-adapter-result/v1"
    and all([.adapter_id,.adapter_version][]; type == "string" and length > 0)
    and (.profile_sha256 | type == "string" and test("^[0-9a-f]{64}$"))
    and (.evidence_class | IN("fixture","production"))
    and (.captures | type == "array" and length > 0)
    and all(.captures[];
      type == "object" and (keys | sort) == ["action_trace","action_trace_sha256","capture_id","dom_sha256","tasks"]
      and (.capture_id | type == "string" and length > 0)
      and all([.dom_sha256,.action_trace_sha256][]; type == "string" and test("^[0-9a-f]{64}$"))
      and (.action_trace | type == "array"
        and all(.[]; type == "object" and (.type | type == "string") and ((keys - ["route","selector","type","value"]) == [])))
      and (.tasks | type == "array" and length > 0
        and all(.[];
          type == "object" and (keys | sort) == ["assertions","reaches_state","task_id"]
          and (.task_id | test("^task-[a-z0-9][a-z0-9-]*$"))
          and (.reaches_state | type == "string" and length > 0)
          and (.assertions | type == "array" and length > 0
            and all(.[];
              type == "object" and (keys | sort) == ["assertion_id","kind","measured","selector"]
              and (.assertion_id | test("^assert-[a-z0-9][a-z0-9-]*$"))
              and (.kind | . as $k | $kinds | index($k) != null)
              and (.selector | type == "string" and length > 0)
              and (.measured | type == "object" and (.dom_sha256 | type == "string" and test("^[0-9a-f]{64}$"))))))))
    and (.signature | type == "object" and (keys | sort) == ["anchor","counterfactual"]
      and (.anchor | type == "object" and (keys | sort) == ["assertion_id","capture_id","task_id"])
      and (.counterfactual | type == "object" and (keys | sort) == ["measured","selector"]
        and (.selector | type == "string" and length > 0)
        and (.measured | type == "object" and (keys | sort) == ["dom_sha256","match_count"]
          and (.dom_sha256 | type == "string" and test("^[0-9a-f]{64}$"))
          and (.match_count | type == "number" and floor == . and . >= 0))))
  ' "$1" >/dev/null 2>&1
}

# receipt_shape_and_binding RECEIPT ADAPTER_ID COMMAND_SHA INPUT_SHA OUTPUT_SHA SRC_EPOCH NOW_EPOCH
receipt_shape_and_binding() {
  local receipt="$1" adapter_id="$2" command_sha="$3" input_sha="$4" output_sha="$5" src_epoch="$6" now_epoch="$7" executed epoch dups
  regular_json_without_duplicate_keys "$receipt" || return 1
  dups=$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("")' "$receipt" 2>/dev/null | LC_ALL=C sort | uniq -d)
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

gate() {
  local root="$1" manifest="$2" plan="$3" receipt_out="$4"
  shift 4
  [ "${1:-}" = "--" ] || { usage; return 2; }
  shift
  [ "$#" -gt 0 ] || reject ADAPTER_UNAVAILABLE
  local adapter="$1"
  local kinds now now_epoch manifest_dir head_rev src_epoch timeout
  local adapter_sha request outdir result_json result_sha request_sha
  local plan_cmd_sha plan_adapter_id plan_profile plan_class base_path base_file
  local cid pin computed

  command -v jq >/dev/null 2>&1 || reject JQ_UNAVAILABLE
  [ -d "$root" ] && [ ! -L "$root" ] || reject UNSAFE_ROOT
  [ -f "$manifest" ] && [ ! -L "$manifest" ] || reject MANIFEST_UNAVAILABLE
  [ -f "$plan" ] && [ ! -L "$plan" ] || reject PLAN_UNAVAILABLE
  manifest_dir=$(CDPATH='' cd -- "$(dirname -- "$manifest")" 2>/dev/null && pwd -P) || reject MANIFEST_UNAVAILABLE

  kinds=$(printf '%s\n' $ALLOWED_ASSERTIONS | jq -R . | jq -sc .)

  regular_json_without_duplicate_keys "$manifest" || reject MANIFEST_SHAPE
  manifest_shape "$manifest" || reject MANIFEST_SHAPE
  regular_json_without_duplicate_keys "$plan" || reject PLAN_SHAPE
  plan_shape "$plan" "$kinds" || reject PLAN_SHAPE

  # Bind the exact subject revision: manifest, plan, and the live tree must agree.
  head_rev=$(git -C "$root" rev-parse HEAD 2>/dev/null) || reject SOURCE_REVISION_UNAVAILABLE
  [ "$head_rev" = "$(jq -r '.candidate_source_revision' "$manifest")" ] || reject STALE_SOURCE_REVISION
  [ "$head_rev" = "$(jq -r '.source_revision' "$plan")" ] || reject STALE_SOURCE_REVISION
  [ "$(jq -r '.candidate_id' "$manifest")" = "$(jq -r '.candidate_id' "$plan")" ] || reject CANDIDATE_MISMATCH
  src_epoch=$(git -C "$root" log -1 --format=%ct "$head_rev" 2>/dev/null) || reject SOURCE_TIME_UNAVAILABLE
  now=${POLYLANE_TASK_NOW:-$(rfc3339_utc)}; now_epoch=$(utc_epoch "$now") || reject INVALID_NOW

  # Pin the adapter: recomputed digest must equal the plan's coordinator pin.
  plan_cmd_sha=$(jq -r '.adapter.command_sha256' "$plan")
  plan_adapter_id=$(jq -r '.adapter.adapter_id' "$plan")
  plan_profile=$(jq -r '.adapter.profile_sha256' "$plan")
  plan_class=$(jq -r '.evidence_class' "$plan")
  [ -e "$adapter" ] && [ ! -L "$adapter" ] && [ -x "$adapter" ] || reject ADAPTER_UNAVAILABLE
  adapter_sha=$(sha256_file "$adapter") || reject SHA256_UNAVAILABLE
  [ "$adapter_sha" = "$plan_cmd_sha" ] || reject ADAPTER_MISMATCH

  # Isolated, atomic workspace for the adapter request/output.
  TASK_TEMP=$(mktemp -d "${TMPDIR:-/tmp}/polylane-task.XXXXXX") || reject WORKSPACE_UNAVAILABLE
  trap 'rm -rf "$TASK_TEMP"' EXIT HUP INT TERM
  request="$TASK_TEMP/request.json"; outdir="$TASK_TEMP/adapter-out"; mkdir -p "$outdir"
  jq -n --slurpfile m "$manifest" --slurpfile p "$plan" '
    {schema_version:"taste-task-request/v1",candidate_id:$m[0].candidate_id,source_revision:$m[0].candidate_source_revision,
     evidence_class:$p[0].evidence_class,
     adapter:{adapter_id:$p[0].adapter.adapter_id,adapter_version:$p[0].adapter.adapter_version,profile_sha256:$p[0].adapter.profile_sha256},
     required_states:$p[0].required_states,
     tasks:$p[0].tasks,
     product_signature:$p[0].product_signature,
     captures:[$m[0].captures[]|{capture_id,route,state,viewport,dom_sha256,action_trace_sha256}]}' > "$request"
  request_sha=$(sha256_file "$request")

  timeout=${POLYLANE_TASK_TIMEOUT:-60}
  export POLYLANE_TASK_REQUEST="$request" POLYLANE_TASK_OUTPUT="$outdir"
  local arc=0
  run_with_timeout "$timeout" "$@" >/dev/null 2>&1 || arc=$?
  [ "$arc" != 124 ] || reject ADAPTER_TIMEOUT
  [ "$arc" = 0 ] || reject ADAPTER_FAILED

  result_json="$outdir/result.json"
  [ -f "$result_json" ] && [ ! -L "$result_json" ] || reject ADAPTER_RESULT_MISSING
  [ -f "$outdir/receipt.json" ] && [ ! -L "$outdir/receipt.json" ] || reject ADAPTER_RECEIPT
  regular_json_without_duplicate_keys "$result_json" || reject ADAPTER_RESULT_SHAPE

  # No caller-authored verdict may ride along in the adapter output.
  jq -e 'any(paths; .[-1] | (type == "string") and (ascii_downcase | IN("pass","verdict","promote","promoted","certified","authorized","status","overall_status")))' "$result_json" >/dev/null 2>&1 && reject CALLER_PASS
  result_shape "$result_json" "$kinds" || reject ADAPTER_RESULT_SHAPE

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

  # Only allowlisted actions with safe relative routes/selectors. Content safety
  # is checked BEFORE the determinism recompute so an unsafe (mutated) trace
  # surfaces its real reason instead of a generic hash mismatch.
  local acts_json
  acts_json=$(printf '%s\n' $ALLOWED_ACTIONS | jq -R . | jq -sc .)
  jq -e --argjson acts "$acts_json" 'all(.captures[].action_trace[]; .type as $t | $acts | index($t) != null)' "$result_json" >/dev/null 2>&1 || reject ARBITRARY_ACTION
  jq -e "$JQ_SAFE"'all(.captures[].action_trace[]; if .type == "navigate" then (has("selector") | not) else true end and (if has("selector") then (.selector | safe_selector) else true end))' "$result_json" >/dev/null 2>&1 || reject UNSAFE_SELECTOR
  jq -e "$JQ_SAFE"'all(.captures[].action_trace[]; if .type == "navigate" then (.route | safe_route) else (has("route") | not) end)' "$result_json" >/dev/null 2>&1 || reject NETWORK_ACTION

  # Every assertion's selector safe; measured evidence bound to the pinned DOM
  # and non-empty for its kind.
  jq -e "$JQ_SAFE"'all(.captures[].tasks[].assertions[]; .selector | safe_selector)' "$result_json" >/dev/null 2>&1 || reject UNSAFE_SELECTOR
  jq -e 'all(.captures[]; .dom_sha256 as $d | .tasks[].assertions[] | .measured.dom_sha256 == $d)' "$result_json" >/dev/null 2>&1 || reject STALE_DOM
  jq -e '
    all(.captures[].tasks[].assertions[];
      (.measured | keys | length > 1)
      and (if (.kind | IN("exists","absent","unique","count")) then (.measured.match_count | type == "number")
           elif .kind == "text_present" then (.measured.text | type == "string")
           elif .kind == "state_is" then (.measured.state | type == "string")
           else (.measured.observed | type != "null" and . != null) end))
  ' "$result_json" >/dev/null 2>&1 || reject MISSING_MEASURED_EVIDENCE

  # Content-address the replayed trace: canonical hash of each (already
  # safety-checked) action_trace must reproduce the pinned digest, else the
  # replay is not deterministic.
  while IFS=$'\t' read -r cid pin; do
    computed=$(jq -cS --arg c "$cid" '.captures[]|select(.capture_id==$c)|.action_trace' "$result_json") || reject NONDETERMINISTIC
    [ "$(sha256_text "$computed")" = "$pin" ] || reject NONDETERMINISTIC
  done < <(jq -r '.captures[] | [.capture_id,.action_trace_sha256] | @tsv' "$result_json")

  # Coverage: exactly the planned tasks, each with exactly the planned
  # assertions; kind + selector must echo the plan (no easier-selector swap).
  jq -e --slurpfile p "$plan" '
    ($p[0].tasks | map(.task_id) | sort) as $want
    | ([.captures[].tasks[].task_id]) as $got
    | ($got | sort) == $want and ($got | length) == ($got | unique | length)
  ' "$result_json" >/dev/null 2>&1 || reject MISSING_TASK
  jq -e --slurpfile p "$plan" '
    ($p[0].tasks | map({key:.task_id,value:(.assertions | map(.assertion_id) | sort)}) | from_entries) as $want
    | all(.captures[].tasks[];
        ((.assertions | map(.assertion_id)) as $ids
         | ($ids | sort) == ($want[.task_id]) and ($ids | length) == ($ids | unique | length)))
  ' "$result_json" >/dev/null 2>&1 || reject COVERAGE_INCOMPLETE
  jq -e --slurpfile p "$plan" '
    ($p[0].tasks | map(.assertions[] + {task_id:.task_id} | {key:(.task_id+""+.assertion_id),value:{kind,selector}}) | from_entries) as $want
    | all(.captures[].tasks[];
        .task_id as $tid | .assertions[]
        | ($want[$tid+""+.assertion_id]) as $w
        | $w != null and .kind == $w.kind and .selector == $w.selector)
  ' "$result_json" >/dev/null 2>&1 || reject ASSERTION_TAMPERED

  # Reached states must be in the plan vocabulary and cover every required state.
  jq -e --slurpfile p "$plan" 'all(.captures[].tasks[].reaches_state; . as $s | $p[0].required_states | index($s) != null)' "$result_json" >/dev/null 2>&1 || reject UNKNOWN_STATE
  jq -e --slurpfile p "$plan" '([.captures[].tasks[].reaches_state] | unique) as $got | ($p[0].required_states - $got) == []' "$result_json" >/dev/null 2>&1 || reject MISSING_STATE

  # Product signature must bind to a real anchor capture/task/assertion and pin
  # the counterfactual selector + DOM the plan authored.
  jq -e --slurpfile p "$plan" '
    ($p[0].product_signature) as $sig
    | .signature as $s
    | ($s.anchor == $sig.rendered_anchor)
    and ($s.counterfactual.selector == $sig.counterfactual.selector)
    and (any(.captures[]; .capture_id == $s.anchor.capture_id))
    and (any(.captures[]; .capture_id == $s.anchor.capture_id and (.tasks[] | select(.task_id == $s.anchor.task_id) | .assertions | any(.assertion_id == $s.anchor.assertion_id))))
    and ($s.counterfactual.measured.dom_sha256 == first(.captures[] | select(.capture_id == $s.anchor.capture_id) | .dom_sha256))
  ' "$result_json" >/dev/null 2>&1 || reject SIGNATURE_UNBOUND

  # Adapter receipt binds command pin, request, and result within the run window.
  result_sha=$(sha256_file "$result_json")
  receipt_shape_and_binding "$outdir/receipt.json" "$plan_adapter_id" "$plan_cmd_sha" "$request_sha" "$result_sha" "$src_epoch" "$now_epoch" || reject STALE_RECEIPT

  # Baseline receipt (optional): must be a well-formed prior task receipt.
  base_path=$(jq -r '.baseline_receipt_path' "$plan")
  base_file=""
  if [ -n "$base_path" ]; then
    safe_relative_regular_file "$manifest_dir" "$base_path" || reject UNSAFE_PATH
    base_file="$manifest_dir/$base_path"
    regular_json_without_duplicate_keys "$base_file" || reject BASELINE_SHAPE
    jq -e '.schema_version == "taste-task-receipt/v1" and (.task_outcomes | type == "array")' "$base_file" >/dev/null 2>&1 || reject BASELINE_SHAPE
  fi

  # Recompute derived verdicts, veto reasons, and the receipt.
  local manifest_sha plan_sha base_sha receipt_json tmp_receipt validator_fp
  manifest_sha=$(sha256_file "$manifest"); plan_sha=$(sha256_file "$plan")
  base_sha=""; [ -n "$base_file" ] && base_sha=$(sha256_file "$base_file")
  validator_fp=$(sha256_file "${BASH_SOURCE[0]}") || reject SHA256_UNAVAILABLE
  receipt_json=$(jq -n \
    --slurpfile M "$manifest" --slurpfile R "$result_json" --slurpfile P "$plan" \
    --arg manifest_sha "$manifest_sha" --arg plan_sha "$plan_sha" \
    --arg result_sha "$result_sha" --arg base_sha "$base_sha" --arg now "$now" \
    --arg cmd_sha "$plan_cmd_sha" --arg vfp "$validator_fp" '
    ($M[0]) as $m | ($R[0]) as $r | ($P[0]) as $p |
    def verdict($kind; $expected; $mm):
      if $kind == "exists" then (($mm.match_count // -1) >= 1)
      elif $kind == "absent" then (($mm.match_count // -1) == 0)
      elif $kind == "unique" then (($mm.match_count // -1) == 1)
      elif $kind == "count" then (($mm.match_count // -1) == $expected)
      elif $kind == "text_present" then (($mm.text // "") | contains($expected))
      elif $kind == "text_equals" then ($mm.observed == $expected)
      elif $kind == "value_equals" then ($mm.observed == $expected)
      elif $kind == "attr_equals" then ($mm.observed == $expected)
      elif $kind == "state_is" then ($mm.state == $expected)
      else false end;
    ($p.tasks | map({key:.task_id,value:.}) | from_entries) as $ptask |
    ($p.tasks | map(.assertions[] + {task_id:.task_id} | {key:(.task_id+""+.assertion_id),value:.expected}) | from_entries) as $pexp |
    ($p.manual_external_tasks) as $manual |
    [ $r.captures[] as $c | $c.tasks[] as $t | $t.assertions[]
      | ($pexp[$t.task_id+""+.assertion_id]) as $expected
      | (verdict(.kind; $expected; .measured)) as $ok
      | {capture_id:$c.capture_id,task_id:$t.task_id,assertion_id,kind,selector,expected:$expected,measured,passed:$ok} ] as $results |
    [ $r.captures[].tasks[]
      | {task_id, reaches_state, expected_state:($ptask[.task_id].reaches_state),
         state_ok:(.reaches_state == $ptask[.task_id].reaches_state)} ] as $task_outcomes |
    ($results | map(select(.passed | not))) as $failed_assertions |
    ($task_outcomes | map(select(.state_ok | not))) as $state_misses |
    ($p.product_signature.rendered_anchor) as $anchor |
    ($results | map(select(.task_id == $anchor.task_id and .assertion_id == $anchor.assertion_id and .capture_id == $anchor.capture_id)) | first) as $anchor_res |
    ($anchor_res != null and $anchor_res.passed) as $mechanism_proven |
    ($r.signature.counterfactual.measured.match_count == 0) as $counterfactual_absent |
    ([ (if ($failed_assertions | length > 0) then "ASSERTION_FAILED" else empty end),
       (if ($state_misses | length > 0) then "STATE_NOT_REACHED" else empty end),
       (if ($mechanism_proven | not) then "SIGNATURE_UNPROVEN" else empty end),
       (if ($counterfactual_absent | not) then "SIGNATURE_GENERIC" else empty end) ] | unique) as $veto |
    (if ($veto | length > 0) then "FAIL" elif ($manual | length > 0) then "EXTERNAL" else "PASS" end) as $derived |
    (if ($veto | length > 0) then $veto
     else (["CLEAN"] + (if ($manual | length > 0) then ["MANUAL_EXTERNAL"] else [] end)) end) as $reasons |
    {schema_version:"taste-task-receipt/v1",
     receipt_version:"polylane.taste.task-receipt.v1",
     classification:"fixture", fixture_only:true, human_certified:false,
     candidate_id:$p.candidate_id, source_revision:$p.source_revision,
     brief_sha256:$p.brief_sha256, design_lock_sha256:$p.design_lock_sha256,
     evidence_class:$p.evidence_class,
     adapter:{adapter_id:$p.adapter.adapter_id,adapter_version:$p.adapter.adapter_version,command_sha256:$cmd_sha,profile_sha256:$p.adapter.profile_sha256},
     validator:{id:"polylane-taste-task",fingerprint:$vfp},
     input_sha256:{capture_manifest:$manifest_sha,task_plan:$plan_sha,adapter_result:$result_sha,baseline_receipt:$base_sha},
     coverage:{required_states:$p.required_states,captures:($r.captures|length),tasks:($task_outcomes|length),assertions:($results|length)},
     product_signature:{mechanism:$p.product_signature.mechanism,clause_trace:$p.product_signature.clause_trace,
       rendered_anchor:$anchor,task_proof:$p.product_signature.task_proof,
       unrelated_brief_id:$p.product_signature.counterfactual.unrelated_brief_id,
       mechanism_proven:$mechanism_proven,counterfactual_absent:$counterfactual_absent},
     results:$results, task_outcomes:$task_outcomes,
     failed_assertions:$failed_assertions, state_misses:$state_misses,
     manual_external:$manual, derived_status:$derived, reason_codes:$reasons, generated_at:$now}
  ') || reject RECEIPT_BUILD_FAILED

  # Atomic write of the receipt beside its destination.
  local out_dir out_name
  case "$receipt_out" in ''|/) reject RECEIPT_PATH_UNSAFE ;; esac
  out_dir=$(CDPATH='' cd -- "$(dirname -- "$receipt_out")" 2>/dev/null && pwd -P) || reject RECEIPT_PATH_UNSAFE
  out_name=$(basename -- "$receipt_out")
  [ "$out_name" != . ] && [ "$out_name" != .. ] || reject RECEIPT_PATH_UNSAFE
  tmp_receipt=$(mktemp "$out_dir/.task-receipt.XXXXXX") || reject RECEIPT_PATH_UNSAFE
  printf '%s\n' "$receipt_json" > "$tmp_receipt"
  mv "$tmp_receipt" "$out_dir/$out_name"

  rm -rf "$TASK_TEMP"; TASK_TEMP=""; trap - EXIT HUP INT TERM
  printf 'TASTE-TASK: %s tasks=%s assertions=%s\n' \
    "$(printf '%s' "$receipt_json" | jq -r '.derived_status')" \
    "$(printf '%s' "$receipt_json" | jq -r '.coverage.tasks')" \
    "$(printf '%s' "$receipt_json" | jq -r '.coverage.assertions')"
}

main() {
  case "${1:-}" in
    gate) [ "$#" -ge 6 ] || { usage; return 2; }; shift; gate "$@" ;;
    *) usage; return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
