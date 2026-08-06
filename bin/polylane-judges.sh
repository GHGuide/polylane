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
      and (.timeout_s | type == "number" and floor == . and . >= 1 and . <= 300))
    and ([.[].name] | unique | length == 3)
    and ([.[].lens] | unique | length == 3)
  ' "$1" >/dev/null 2>&1
}

run_one() {
  local tree="$1" command="$2" evidence="$3" timeout_s="$4" pid rc=0 status ticks=0 max_ticks timed_out=0
  max_ticks=$((timeout_s * 10))
  ( cd "$tree" && exec sh -c "$command" ) > "$evidence" 2>&1 & pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$ticks" -ge "$max_ticks" ]; then
      timed_out=1
      kill -TERM "$pid" 2>/dev/null || true
      break
    fi
    sleep 0.1
    ticks=$((ticks + 1))
  done
  wait "$pid" || rc=$?
  if [ "$timed_out" = 1 ]; then status=timeout; else status=passed; [ "$rc" -eq 0 ] || status=failed; fi
  printf '%s\t%s\n' "$status" "$rc"
}

run_judges() {
  local manifest="$1" tree="$2" out_dir="$3" private_dir i=0 name lens command timeout_s evidence published result status rc failed=0
  [ -d "$tree" ] || { echo "JUDGES: tree does not exist: $tree" >&2; return 2; }
  validate_manifest "$manifest" || { echo 'JUDGES: quality_judges must contain exactly three unique named lenses with bounded commands' >&2; return 2; }
  mkdir -p "$out_dir"
  rm -f "$out_dir/1.evidence" "$out_dir/2.evidence" "$out_dir/3.evidence" "$out_dir/judges.json" "$out_dir/judges.json.tmp"
  private_dir=$(mktemp -d "${TMPDIR:-/tmp}/polylane-judges.XXXXXX") || return 1
  jq -n '{schema:1,status:"passed",judges:[]}' > "$private_dir/judges.json"
  while IFS=$'\t' read -r name lens command timeout_s; do
    i=$((i + 1)); evidence="$private_dir/$i.evidence"; published="$out_dir/$i.evidence"
    result=$(run_one "$tree" "$command" "$evidence" "$timeout_s")
    status=${result%%$'\t'*}; rc=${result#*$'\t'}
    jq --arg name "$name" --arg lens "$lens" --arg command "$command" --arg status "$status" --arg evidence "$published" --argjson timeout_s "$timeout_s" --argjson rc "$rc" \
      '.judges += [{name:$name,lens:$lens,command:$command,timeout_s:$timeout_s,status:$status,evidence:$evidence,exit_code:$rc}] | if $status == "passed" then . else .status="failed" end' \
      "$private_dir/judges.json" > "$private_dir/judges.json.tmp" && mv "$private_dir/judges.json.tmp" "$private_dir/judges.json"
    if [ "$status" != passed ]; then
      printf 'JUDGES: %s (%s) %s; inspect %s\n' "$name" "$lens" "$status" "$published" >&2
      failed=1
    fi
  done < <(jq -r '.quality_judges[] | [.name,.lens,.command,(.timeout_s|tostring)] | @tsv' "$manifest")
  for i in 1 2 3; do mv "$private_dir/$i.evidence" "$out_dir/$i.evidence"; done
  mv "$private_dir/judges.json" "$out_dir/judges.json"
  rmdir "$private_dir"
  [ "$failed" = 0 ]
}

main() {
  [ "${1:-}" = run ] && [ $# -eq 4 ] || { usage; return 2; }
  run_judges "$2" "$3" "$4"
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
