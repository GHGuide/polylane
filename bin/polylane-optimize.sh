#!/usr/bin/env bash
# polylane-optimize.sh — accepted-outcome evidence and conservative economy tuning.
set -euo pipefail
command -v jq >/dev/null 2>&1 || { echo "polylane-optimize: jq required" >&2; exit 1; }

usage() { echo "usage: polylane-optimize.sh validate RECEIPT | record LEDGER RECEIPT | recommend LEDGER POLICY [--json] | summarize LEDGER" >&2; }

validate() {
  local receipt="$1"
  [ -f "$receipt" ] || { echo "OPTIMIZE: receipt is missing" >&2; return 2; }
  jq -e '
    .schema == "polylane-evidence/v1"
    and ([.run,.lane,.lane_shape,.domain,.model,.effort,.acceptance_hash] | all(type == "string" and length > 0))
    and (.cycle | type == "number") and (.lane_count | type == "number" and . >= 1)
    and (.context_tokens | type == "number" and . >= 0) and (.tokens | type == "number" and . > 0)
    and (.wall_seconds | type == "number" and . > 0) and (.quality_score | type == "number" and . >= 0)
    and (.verified_criteria_delta | type == "number" and . >= 0)
    and (.verified_subgoal_delta | type == "number" and . >= 0)
    and (.selected_skills | type == "array")
    and (.acceptance_status == "accepted") and (.verdict == "GO")
    and ((.quality_regression // false) == false)
    and (if (.synthetic // false) then (.synthetic_label | type == "string" and length > 0) else true end)
  ' "$receipt" >/dev/null || { echo "OPTIMIZE: receipt is not an accepted, quality-safe evidence row" >&2; return 2; }
}

identity() { jq -r .acceptance_hash "$1"; }

record() {
  local ledger="$1" receipt="$2" lock tries=0 id normalized
  validate "$receipt" || return $?
  id=$(identity "$receipt")
  mkdir -p "$(dirname "$ledger")"
  lock="${ledger}.lock"
  while ! mkdir "$lock" 2>/dev/null; do
    tries=$((tries + 1)); [ "$tries" -lt 100 ] || { echo "OPTIMIZE: ledger lock timeout" >&2; return 75; }; sleep 0.05
  done
  trap 'rmdir "$lock" 2>/dev/null || true' RETURN
  if [ -s "$ledger" ] && jq -e --arg id "$id" 'select(.acceptance_hash == $id)' "$ledger" >/dev/null 2>&1; then
    echo "OPTIMIZE: duplicate receipt $id ignored"; return 0
  fi
  normalized=$(jq -c . "$receipt")
  printf '%s\n' "$normalized" >> "$ledger"
  echo "OPTIMIZE: recorded accepted receipt $id"
}

policy_valid() {
  jq -e '
    ([.domain,.lane_shape,.model,.effort,.role] | all(type == "string" and length > 0))
    and (.lane_count | type == "number" and . >= 1) and (.context_tokens | type == "number" and . >= 0)
    and (.available_models | type == "array" and all(.[]; type == "string"))
    and (.bounds.lane_count.min | type == "number") and (.bounds.lane_count.max | type == "number")
    and (.bounds.context_tokens.min | type == "number") and (.bounds.context_tokens.max | type == "number")
  ' "$1" >/dev/null
}

recommend() {
  local ledger="$1" policy="$2" json="${3:-}" min report
  [ -f "$ledger" ] || : > "$ledger"
  [ -f "$policy" ] && policy_valid "$policy" || { echo "OPTIMIZE: invalid current policy" >&2; return 2; }
  case "$json" in ''|--json) ;; *) usage; return 2 ;; esac
  min=$(jq -r '.minimum_samples // env.POLYLANE_OPTIMIZE_MIN_SAMPLES // 3' "$policy")
  case "$min" in ''|*[!0-9]*) echo "OPTIMIZE: minimum_samples must be an integer" >&2; return 2 ;; esac
  [ "$min" -ge 3 ] || min=3
  report=$(jq -s --slurpfile policy "$policy" --argjson minimum "$min" '
    def median: sort as $v | $v[($v|length) / 2 | floor];
    def progress: .quality_score * (.verified_criteria_delta + .verified_subgoal_delta);
    def stat($rows):
      ($rows | map(progress)) as $p | ($rows | map((progress * 1000 / .tokens))) as $tok | ($rows | map((progress * 60 / .wall_seconds))) as $min |
      {samples:($rows|length), progress:($p|median), per_1k_tokens:($tok|median), per_minute:($min|median), score:([($tok|median),($min|median)]|min)};
    $policy[0] as $p |
    if ($p.role == "terminal" or $p.role == "integrator") then
      {schema:"polylane-economy/v1",safe_to_apply:false,reason:"terminal/integrator safety clamp preserves the current policy",score_definition:"min(median progress per 1K tokens, median progress per minute)",samples:{current:0,candidate:0},recommendation:$p,changed_fields:[],confidence:{strength:"safety-clamped",percent:0}}
    else
      [ .[] | select(.domain == $p.domain and .lane_shape == $p.lane_shape) ] as $rows |
      ([ $rows[] | select(.model == $p.model and .effort == $p.effort and .lane_count == $p.lane_count and .context_tokens == $p.context_tokens) ]) as $base |
      (stat($base)) as $base_stat |
      ($rows | group_by([.model,.effort,.lane_count,.context_tokens]) | map(
        . as $g | ($g[0]) as $r | (stat($g)) as $s |
        {model:$r.model,effort:$r.effort,lane_count:$r.lane_count,context_tokens:$r.context_tokens,stats:$s,
         changed_fields:(["model","effort","lane_count","context_tokens"] | map(select($r[.] != $p[.]))) }
      ) | map(select((.changed_fields|length) == 1))
        | map(select(.model as $m | $p.available_models | index($m)))
        | map(select(.lane_count >= $p.bounds.lane_count.min and .lane_count <= $p.bounds.lane_count.max))
        | map(select(.context_tokens >= $p.bounds.context_tokens.min and .context_tokens <= $p.bounds.context_tokens.max))
        | map(select(.stats.samples >= $minimum))
        | sort_by(-.stats.score,.model,.effort,.lane_count,.context_tokens)) as $candidates |
      if ($base_stat.samples < $minimum) then
        {schema:"polylane-economy/v1",safe_to_apply:false,reason:("minimum samples not met for current policy: " + ($base_stat.samples|tostring) + "/" + ($minimum|tostring)),score_definition:"min(median progress per 1K tokens, median progress per minute)",samples:{current:$base_stat.samples,candidate:0},recommendation:$p,changed_fields:[],confidence:{strength:"thin",percent:0}}
      elif ($candidates|length) == 0 then
        {schema:"polylane-economy/v1",safe_to_apply:false,reason:"no comparable candidate met minimum samples, availability, and lane/context bounds",score_definition:"min(median progress per 1K tokens, median progress per minute)",samples:{current:$base_stat.samples,candidate:0},recommendation:$p,changed_fields:[],confidence:{strength:"guarded",percent:($base_stat.samples * 100 / ($base_stat.samples + 2) | floor)}}
      else
        $candidates[0] as $winner |
        {schema:"polylane-economy/v1",safe_to_apply:($winner.stats.score > $base_stat.score),reason:(if $winner.stats.score > $base_stat.score then "accepted comparable evidence improves the conservative median efficiency score" else "deterministic tie or no improvement; keep current policy" end),score_definition:"min(median progress per 1K tokens, median progress per minute)",samples:{current:$base_stat.samples,candidate:$winner.stats.samples},baseline:$base_stat,recommendation:{model:$winner.model,effort:$winner.effort,lane_count:$winner.lane_count,context_tokens:$winner.context_tokens},changed_fields:$winner.changed_fields,candidate:$winner.stats,confidence:{strength:"measured",percent:($winner.stats.samples * 100 / ($winner.stats.samples + 2) | floor)}}
      end
    end
  ' "$ledger")
  printf '%s\n' "$report"
}

summarize() {
  local ledger="$1"
  [ -f "$ledger" ] || { jq -n '{accepted:0,rejected_or_ignored:0,measured_efficiency:null}'; return; }
  jq -s '
    def progress: .quality_score * (.verified_criteria_delta + .verified_subgoal_delta);
    {accepted:length,rejected_or_ignored:0,measured_efficiency:(if length == 0 then null else {progress_per_1k_tokens:([.[] | progress * 1000 / .tokens] | add / length),progress_per_minute:([.[] | progress * 60 / .wall_seconds] | add / length)} end)}
  ' "$ledger"
}

case "${1:-}" in
  validate) [ "$#" = 2 ] || { usage; exit 2; }; validate "$2" ;;
  record) [ "$#" = 3 ] || { usage; exit 2; }; record "$2" "$3" ;;
  recommend) [ "$#" -ge 3 ] && [ "$#" -le 4 ] || { usage; exit 2; }; recommend "$2" "$3" "${4:-}" ;;
  summarize) [ "$#" = 2 ] || { usage; exit 2; }; summarize "$2" ;;
  *) usage; exit 2 ;;
esac
