#!/usr/bin/env bash
# Validate and run the versioned product-brief benchmark corpus.
set -euo pipefail

usage() {
  echo "usage: polylane-product-benchmark.sh validate <corpus-dir> | run <corpus-dir> <out-dir> -- <adapter command...> | summarize <out-dir> [--json]" >&2
  exit 2
}

case_files() {
  local corpus="$1" file
  [ -d "$corpus" ] || { echo "benchmark: corpus directory not found: $corpus" >&2; return 1; }
  set -- "$corpus"/*.json
  [ -f "$1" ] || { echo "benchmark: corpus has no JSON cases" >&2; return 1; }
  for file in "$corpus"/*.json; do
    [ -f "$file" ] || continue
    printf '%s\n' "$file"
  done | LC_ALL=C sort
}

valid_case() {
  jq -e '
    type == "object" and .schema == "schema-v1" and
    (.id | type == "string" and test("^[a-z0-9][a-z0-9-]*$")) and
    (.title | type == "string" and length > 0) and
    (.brief | type == "string" and length > 0) and
    (.product_shape | type == "string" and length > 0) and
    (.feasibility == "feasible") and
    (.rubric | type == "array" and length > 0 and all(.[]; type == "string" and length > 0))
  ' "$1" >/dev/null
}

cmd_validate() {
  local corpus="$1" file ids id rc=0
  ids=$(mktemp "${TMPDIR:-/tmp}/polylane-benchmark-ids.XXXXXX")
  while IFS= read -r file; do
    if ! jq -e . "$file" >/dev/null 2>&1; then
      echo "benchmark: malformed JSON: $file" >&2; rc=1; continue
    fi
    if ! valid_case "$file"; then
      echo "benchmark: invalid schema-v1 case: $file" >&2; rc=1; continue
    fi
    id=$(jq -r '.id' "$file")
    printf '%s\n' "$id" >> "$ids"
  done <<EOF
$(case_files "$corpus")
EOF
  if [ -s "$ids" ] && LC_ALL=C sort "$ids" | uniq -d | grep -q .; then
    echo "benchmark: duplicate case id: $(LC_ALL=C sort "$ids" | uniq -d | head -1)" >&2
    rc=1
  fi
  if [ "$rc" -ne 0 ]; then
    rm -f "$ids"
    return "$rc"
  fi
  echo "benchmark: validated $(wc -l < "$ids" | tr -d ' ') cases"
  rm -f "$ids"
}

json_metric() {
  local result="$1" metric="$2"
  if [ -f "$result" ] && jq -e . "$result" >/dev/null 2>&1; then
    jq -c --arg metric "$metric" '
      if .[$metric] == null then null
      elif .[$metric] | type == "number" then .[$metric]
      elif .metrics[$metric] | type == "number" then .metrics[$metric]
      else null end
    ' "$result"
  else
    printf 'null\n'
  fi
}

cmd_run() {
  local corpus="$1" out="$2"; shift 2
  [ "${1:-}" = "--" ] || usage
  shift
  [ "$#" -gt 0 ] || usage
  cmd_validate "$corpus" >/dev/null
  mkdir -p "$out/cases"
  : > "$out/results.jsonl"
  local case_file id work result start end rc tokens interventions score any_failure=0
  while IFS= read -r case_file; do
    id=$(jq -r '.id' "$case_file")
    work="$out/cases/$id"
    result="$work/result.json"
    mkdir -p "$work"
    rm -f "$result"
    start=$(date +%s)
    POLYLANE_BENCH_CASE="$case_file" POLYLANE_BENCH_WORKDIR="$work" POLYLANE_BENCH_RESULT="$result" "$@" || rc=$?
    rc=${rc:-0}
    end=$(date +%s)
    tokens=$(json_metric "$result" tokens)
    interventions=$(json_metric "$result" interventions)
    score=$(json_metric "$result" score)
    jq -cn --arg id "$id" --arg case "$case_file" --arg workdir "$work" \
      --argjson adapter_rc "$rc" --argjson wall_time_s "$((end - start))" \
      --argjson tokens "$tokens" --argjson interventions "$interventions" --argjson score "$score" \
      '{schema:"schema-v1", id:$id, case:$case, workdir:$workdir, adapter_rc:$adapter_rc, wall_time_s:$wall_time_s, tokens:$tokens, interventions:$interventions, score:$score}' \
      >> "$out/results.jsonl"
    [ "$rc" -eq 0 ] || any_failure=1
    unset rc
  done <<EOF
$(case_files "$corpus")
EOF
  [ "$any_failure" -eq 0 ]
}

summary_json() {
  local results="$1"
  [ -f "$results" ] || { echo "benchmark: no results at $results" >&2; return 1; }
  jq -s '
    def complete_mean($field):
      if any(.[]; .[$field] == null) then null
      else ([.[].[$field]] | if length == 0 then null else add / length end) end;
    {schema:"schema-v1", cases:length,
     adapter_failures: ([.[] | select(.adapter_rc != 0)] | length),
     mean_wall_time_s: complete_mean("wall_time_s"),
     mean_tokens: complete_mean("tokens"),
     mean_interventions: complete_mean("interventions"),
     mean_score: complete_mean("score")}
  ' "$results"
}

cmd_summarize() {
  local out="$1" mode="${2:-}" summary
  [ -z "$mode" ] || [ "$mode" = "--json" ] || usage
  summary=$(summary_json "$out/results.jsonl")
  if [ "$mode" = "--json" ]; then
    printf '%s\n' "$summary"
  else
    printf 'Cases: %s\nAdapter failures: %s\nMean wall time (s): %s\nMean tokens: %s\nMean interventions: %s\nMean score: %s\n' \
      "$(printf '%s' "$summary" | jq -r '.cases')" \
      "$(printf '%s' "$summary" | jq -r '.adapter_failures')" \
      "$(printf '%s' "$summary" | jq -r '.mean_wall_time_s')" \
      "$(printf '%s' "$summary" | jq -r '.mean_tokens')" \
      "$(printf '%s' "$summary" | jq -r '.mean_interventions')" \
      "$(printf '%s' "$summary" | jq -r '.mean_score')"
  fi
}

case "${1:-}" in
  validate) [ "$#" = 2 ] || usage; cmd_validate "$2" ;;
  run) [ "$#" -ge 5 ] || usage; shift; cmd_run "$@" ;;
  summarize) [ "$#" -ge 2 ] && [ "$#" -le 3 ] || usage; cmd_summarize "$2" "${3:-}" ;;
  *) usage ;;
esac
