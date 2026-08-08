#!/usr/bin/env bash
# polylane-visual-quality.sh — screenshot evidence and promotion-blocking lenses.
set -euo pipefail

usage() {
  echo "usage: polylane-visual-quality.sh run <evidence.json> <contract.json> <verdict.json> [repair-attempt] | benchmark <corpus.json> <verdict.json>" >&2
}

evidence_shape() {
  jq -e '
    . as $e
    | .schema == 1
    and (.root | type == "string" and startswith("/"))
    and .anonymized == true
    and (.screenshots | type == "array")
    and all(.screenshots[]; (.surface | type == "string" and length > 0)
      and (.viewport | IN("desktop", "mobile"))
      and (.state | IN("default", "empty", "loading", "error", "hover", "focus"))
      and (.path | type == "string" and length > 0 and (startswith("/") | not) and (contains("..") | not)))
    and any(.screenshots[]; .viewport == "desktop" and .state == "default")
    and any(.screenshots[]; .viewport == "mobile" and .state == "default")
    and all(["empty","loading","error","hover","focus"][]; . as $state | any($e.screenshots[]; .state == $state))
    and (.flow | type == "array" and length > 0 and all(.[]; (.surface | type == "string") and (.action | type == "string") and (.result | type == "string")))
    and (.texts | type == "array" and all(.[]; type == "string"))
    and (.assets | type == "array" and all(.[]; type == "string"))
    and (.generic_patterns | type == "array" and all(.[]; type == "string"))
    and (.lenses | type == "array" and length == 3)
    and ([.lenses[].lens] | sort == ["accessibility","fit_polish","originality"])
    and all(.lenses[]; (.status | IN("passed", "failed"))
      and (.findings | type == "array")
      and all(.findings[]; (.surface | type == "string" and length > 0)
        and (.region | type == "string" and length > 0)
        and (.action | type == "string" and length > 0)))
  ' "$1" >/dev/null 2>&1
}

screenshot_has_image_signature() {
  local image="$1" signature
  [ -s "$image" ] || return 1
  signature=$(LC_ALL=C od -An -N 12 -t x1 "$image" | tr -d ' \n')
  case "$signature" in
    89504e470d0a1a0a*|ffd8ff*|52494646????????57454250*) return 0 ;;
    *) return 1 ;;
  esac
}

screenshots_exist() {
  local evidence="$1" root image
  root=$(jq -r '.root' "$evidence")
  while IFS= read -r image; do
    [ -f "$root/$image" ] && [ ! -L "$root/$image" ] &&
      screenshot_has_image_signature "$root/$image" || return 1
  done < <(jq -r '.screenshots[].path' "$evidence")
}

mechanical_failure() {
  local evidence="$1" contract="$2" generic copied
  generic=$(jq -r '.generic_patterns[]? | ascii_downcase' "$evidence" | grep -E '^(purple-gradient|centered-card|inter-font|generic-dashboard)$' || true)
  [ -z "$generic" ] || { printf 'generic:%s\n' "${generic%%$'\n'*}"; return; }
  copied=$(jq -r --slurpfile contract "$contract" '
    ((.texts // []) as $texts | ($contract[0].prohibited_text // [])[] | select(. as $x | $texts | index($x)) // empty),
    ((.assets // []) as $assets | ($contract[0].prohibited_assets // [])[] | select(. as $x | $assets | index($x)) // empty)
  ' "$evidence" | head -n 1)
  [ -z "$copied" ] || { printf 'copied:%s\n' "$copied"; return; }
  printf '%s\n' ''
}

run_quality() {
  local evidence="$1" contract="$2" verdict="$3" attempt="${4:-0}" reason status evidence_id
  case "$attempt" in *[!0-9]*|"") echo "VISUAL-QUALITY: repair attempt must be 0, 1, or 2" >&2; return 2 ;; esac
  [ "$attempt" -le 2 ] || { echo "VISUAL-QUALITY: repair budget exhausted" >&2; return 2; }
  evidence_shape "$evidence" || { echo "VISUAL-QUALITY: incomplete or malformed screenshot evidence" >&2; return 2; }
  jq -e '(.prohibited_text // []) | type == "array" and all(.[]; type == "string")' "$contract" >/dev/null 2>&1 || {
    echo "VISUAL-QUALITY: invalid frozen contract" >&2; return 2;
  }
  screenshots_exist "$evidence" || { echo "VISUAL-QUALITY: missing real screenshot evidence" >&2; return 2; }
  reason=$(mechanical_failure "$evidence" "$contract")
  evidence_id=$(cksum "$evidence" | awk '{print $1 "-" $2}')
  if [ -n "$reason" ]; then
    status=blocked
  elif jq -e 'all(.lenses[]; .status == "passed")' "$evidence" >/dev/null; then
    status=passed
  elif [ "$attempt" -ge 2 ]; then
    status=halted
  else
    status=repair
  fi
  mkdir -p "$(dirname "$verdict")"
  jq --arg status "$status" --argjson attempt "$attempt" --arg evidence_id "$evidence_id" --arg reason "$reason" '
    {schema:1,status:$status,repair_attempt:$attempt,evidence_id:$evidence_id,
     mechanical_reason:(if ($reason | length) > 0 then $reason else null end),
     lenses:[.lenses[] | {lens,status,findings}]}
  ' "$evidence" > "$verdict"
  [ "$status" = passed ]
}

benchmark_quality() {
  local corpus="$1" verdict="$2" status wins total
  jq -e '
    .schema == 1
    and (.prompts | type == "array" and length >= 10)
    and all(.prompts[];
      (.id | type == "string" and length > 0)
      and all([.old, .new][];
        type == "object"
        and (.distinction | type == "number")
        and (.polish | type == "number")
        and (.accessibility | type == "number")))
  ' "$corpus" >/dev/null 2>&1 || {
    echo "VISUAL-QUALITY: benchmark corpus must contain at least ten scored prompts" >&2; return 2;
  }
  wins=$(jq '[.prompts[] | select(.new.distinction > .old.distinction and .new.polish > .old.polish)] | length' "$corpus")
  total=$(jq '.prompts | length' "$corpus")
  if jq -e --argjson wins "$wins" --argjson total "$total" '
      ($wins * 100 >= $total * 70)
      and all(.prompts[]; .new.accessibility >= .old.accessibility)
    ' "$corpus" >/dev/null; then
    status=passed
  else
    status=blocked
  fi
  mkdir -p "$(dirname "$verdict")"
  jq --arg status "$status" --argjson wins "$wins" --argjson total "$total" '
    {schema:1,status:$status,prompts:$total,decisive_new_wins:$wins,
     decisive_win_rate:($wins / $total),
     accessibility_regressions:[.prompts[] | select(.new.accessibility < .old.accessibility) | .id]}
  ' "$corpus" > "$verdict"
  [ "$status" = passed ]
}

main() {
  case "${1:-}" in
    run) { [ $# -eq 4 ] || [ $# -eq 5 ]; } || { usage; return 2; }; run_quality "$2" "$3" "$4" "${5:-0}" ;;
    benchmark) [ $# -eq 3 ] || { usage; return 2; }; benchmark_quality "$2" "$3" ;;
    *) usage; return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
