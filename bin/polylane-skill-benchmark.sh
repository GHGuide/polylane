#!/usr/bin/env bash
# polylane-skill-benchmark.sh — lane-shaped admission evidence for skill candidates.
set -euo pipefail
command -v jq >/dev/null 2>&1 || { echo "polylane-skill-benchmark: jq required" >&2; exit 1; }
usage() { echo "usage: polylane-skill-benchmark.sh validate RECEIPT | record LEDGER RECEIPT | gate LEDGER CANDIDATE_JSON" >&2; }

validate() {
  jq -e '
    .schema == "polylane-skill-benchmark/v1"
    and ([.receipt_id,.lane_shape,.domain,.acceptance_status,.verdict,.skill.id,.skill.fingerprint] | all(type == "string" and length > 0))
    and (.quality_adjusted_delta | type == "number") and (.hard_checks | type == "boolean") and (.hurt | type == "boolean")
    and (if (.synthetic // false) then (.synthetic_label | type == "string" and length > 0) else true end)
  ' "$1" >/dev/null || { echo "SKILL-BENCHMARK: malformed receipt" >&2; return 2; }
}

record() {
  local ledger="$1" receipt="$2" id lock tries=0
  validate "$receipt" || return $?
  id=$(jq -r .receipt_id "$receipt")
  mkdir -p "$(dirname "$ledger")"; lock="${ledger}.lock"
  while ! mkdir "$lock" 2>/dev/null; do tries=$((tries+1)); [ "$tries" -lt 100 ] || return 75; sleep 0.05; done
  trap 'rmdir "$lock" 2>/dev/null || true' RETURN
  if [ -s "$ledger" ] && jq -e --arg id "$id" 'select(.receipt_id == $id)' "$ledger" >/dev/null 2>&1; then echo "SKILL-BENCHMARK: duplicate $id ignored"; return; fi
  jq -c . "$receipt" >> "$ledger"; echo "SKILL-BENCHMARK: recorded $id"
}

gate() {
  local ledger="$1" candidate="$2" min
  jq -e '([.id,.fingerprint,.domain,.lane_shape] | all(type == "string" and length > 0))' "$candidate" >/dev/null || { echo "SKILL-BENCHMARK: invalid candidate" >&2; return 2; }
  min="${POLYLANE_SKILL_BENCHMARK_MIN_SAMPLES:-3}"; case "$min" in ''|*[!0-9]*) return 2 ;; esac; [ "$min" -ge 3 ] || min=3
  [ -f "$ledger" ] || : > "$ledger"
  jq -s --slurpfile candidate "$candidate" --argjson minimum "$min" '
    $candidate[0] as $c |
    [ .[] | select(.skill.id == $c.id and .skill.fingerprint == $c.fingerprint and .domain == $c.domain and .lane_shape == $c.lane_shape) ] as $same |
    ([ .[] | select(.skill.id == $c.id and .skill.fingerprint != $c.fingerprint) ] | length) as $stale |
    ($same | length) as $samples |
    ($same | map(select(.acceptance_status == "accepted" and .verdict == "GO" and .hard_checks and (.hurt|not) and .quality_adjusted_delta > 0)) | length) as $passes |
    ($same | map(select(.acceptance_status != "accepted" or .verdict != "GO" or (.hard_checks|not) or .hurt or .quality_adjusted_delta <= 0)) | length) as $bad |
    {id:$c.id,fingerprint:$c.fingerprint,samples:$samples,confidence:{strength:(if $samples >= $minimum then "measured" else "thin" end),percent:($samples * 100 / ($samples + 2) | floor)},safe_to_apply:($samples >= $minimum and $passes == $samples and $bad == 0),status:(if $samples >= $minimum and $passes == $samples and $bad == 0 then "recommended" else "candidate" end),reason:(if $stale > 0 and $samples == 0 then "fingerprint changed; old benchmark admission is invalid" elif $bad > 0 then "failed, hurt, NO-GO, or non-positive benchmark evidence blocks admission" elif $samples < $minimum then "minimum lane-shaped benchmark samples not met" else "hard-passing accepted lane-shaped benchmark evidence" end)}
  ' "$ledger"
}

case "${1:-}" in
  validate) [ "$#" = 2 ] || { usage; exit 2; }; validate "$2" ;;
  record) [ "$#" = 3 ] || { usage; exit 2; }; record "$2" "$3" ;;
  gate|recommend) [ "$#" = 3 ] || { usage; exit 2; }; gate "$2" "$3" ;;
  *) usage; exit 2 ;;
esac
