#!/usr/bin/env bash
# polylane-judges.sh — three isolated, bounded quality commands plus JSON evidence.
set -euo pipefail

usage() { echo "usage: polylane-judges.sh run <manifest> <tree> <out-dir>" >&2; }

validate_manifest() {
  jq -e '
    .quality_judges | type == "array" and length == 3
    and all(.[]; type == "object"
      and (.name | type == "string" and length > 0)
      and (.lens | type == "string" and length > 0)
      and (.command | type == "string" and length > 0)
      and (.timeout_s | type == "number" and floor == . and . >= 1))
    and ([.[].name] | unique | length == 3)
    and ([.[].lens] | unique | length == 3)
  ' "$1" >/dev/null 2>&1
}

run_one() {
  local tree="$1" command="$2" evidence="$3" timeout_s="$4" marker pid watch rc=0 status
  marker="$evidence.timeout"
  rm -f "$marker"
  ( cd "$tree" && exec sh -c "$command" ) > "$evidence" 2>&1 & pid=$!
  ( sleep "$timeout_s"; if kill -0 "$pid" 2>/dev/null; then printf 'timeout\n' > "$marker"; kill -TERM "$pid" 2>/dev/null || true; fi ) & watch=$!
  wait "$pid" || rc=$?
  kill "$watch" 2>/dev/null || true
  wait "$watch" 2>/dev/null || true
  if [ -f "$marker" ]; then status=timeout; else status=passed; [ "$rc" -eq 0 ] || status=failed; fi
  rm -f "$marker"
  printf '%s\t%s\n' "$status" "$rc"
}

run_judges() {
  local manifest="$1" tree="$2" out_dir="$3" i=0 name lens command timeout_s evidence result status rc failed=0
  [ -d "$tree" ] || { echo "JUDGES: tree does not exist: $tree" >&2; return 2; }
  validate_manifest "$manifest" || { echo 'JUDGES: quality_judges must contain exactly three unique named lenses with bounded commands' >&2; return 2; }
  mkdir -p "$out_dir"
  jq -n '{schema:1,status:"passed",judges:[]}' > "$out_dir/judges.json"
  while IFS=$'\t' read -r name lens command timeout_s; do
    i=$((i + 1)); evidence="$out_dir/$i.evidence"
    result=$(run_one "$tree" "$command" "$evidence" "$timeout_s")
    status=${result%%$'\t'*}; rc=${result#*$'\t'}
    jq --arg name "$name" --arg lens "$lens" --arg command "$command" --arg status "$status" --arg evidence "$evidence" --argjson timeout_s "$timeout_s" --argjson rc "$rc" \
      '.judges += [{name:$name,lens:$lens,command:$command,timeout_s:$timeout_s,status:$status,evidence:$evidence,exit_code:$rc}] | if $status == "passed" then . else .status="failed" end' \
      "$out_dir/judges.json" > "$out_dir/judges.json.tmp" && mv "$out_dir/judges.json.tmp" "$out_dir/judges.json"
    if [ "$status" != passed ]; then
      printf 'JUDGES: %s (%s) %s; inspect %s\n' "$name" "$lens" "$status" "$evidence" >&2
      failed=1
    fi
  done < <(jq -r '.quality_judges[] | [.name,.lens,.command,(.timeout_s|tostring)] | @tsv' "$manifest")
  [ "$failed" = 0 ]
}

[ "${1:-}" = run ] && [ $# -eq 4 ] || { usage; exit 2; }
run_judges "$2" "$3" "$4"
