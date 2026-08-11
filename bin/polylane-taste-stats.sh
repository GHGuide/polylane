#!/usr/bin/env bash
# Deterministic aggregation for one blinded vote per independent brief.
set -euo pipefail
export LC_ALL=C

usage() {
  printf '%s\n' 'usage: polylane-taste-stats.sh aggregate < ballots.json' >&2
}

invalid() {
  printf '%s\n' '{"error":"invalid_ballots","schema":"polylane.taste.stats.v1","valid":false}'
  exit 1
}

aggregate() {
  local ballot_json duplicate_paths
  command -v jq >/dev/null 2>&1 || {
    printf '%s\n' 'polylane-taste-stats.sh: jq is required' >&2
    exit 127
  }

  ballot_json=$(cat) || invalid
  if ! duplicate_paths=$(printf '%s' "$ballot_json" | jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("\u001f")' 2>/dev/null | LC_ALL=C sort | uniq -d); then
    invalid
  fi
  [ -z "$duplicate_paths" ] || invalid

  if ! printf '%s' "$ballot_json" | jq -ceS '
    def reject: error("invalid ballots");
    if type != "object" then reject else . end
    | if (keys == ["ballots", "schema"]) then . else reject end
    | if .schema == "polylane.taste.ballots.v1" then . else reject end
    | if (.ballots | type == "array" and length > 0) then . else reject end
    | if all(.ballots[];
        type == "object"
        and (keys == ["brief_id", "vote"])
        and (.brief_id | type == "string" and length > 0)
        and (.vote | type == "string" and (. == "candidate" or . == "baseline" or . == "tie"))
      ) then . else reject end
    | (.ballots | map(.brief_id)) as $brief_ids
    | if ($brief_ids | length == (unique | length)) then . else reject end
    | (.ballots | length) as $n
    | (.ballots | map(select(.vote == "candidate")) | length) as $wins
    | (.ballots | map(select(.vote == "baseline")) | length) as $losses
    | (.ballots | map(select(.vote == "tie")) | length) as $ties
    | ($wins + ($ties / 2)) as $preference_successes
    | ($preference_successes / $n) as $preference_rate
    | 1.96 as $z
    | (1 + (($z * $z) / $n)) as $denominator
    | (($preference_rate + (($z * $z) / (2 * $n))
        - ($z * pow((($preference_rate * (1 - $preference_rate)) + (($z * $z) / (4 * $n))) / $n; 0.5)))
       / $denominator) as $wilson_lower_bound
    | {
        schema: "polylane.taste.stats.v1",
        valid: true,
        sample_unit: "brief",
        confidence_level: 0.95,
        z_score: $z,
        brief_count: $n,
        candidate_wins: $wins,
        baseline_wins: $losses,
        ties: $ties,
        preference_successes: $preference_successes,
        preference_rate: $preference_rate,
        wilson_lower_bound: $wilson_lower_bound,
        pass: ($preference_rate >= 0.70 and $wilson_lower_bound > 0.50)
      }
  '; then
    invalid
  fi
}

case "${1:-}" in
  aggregate)
    [ "$#" -eq 1 ] || { usage; exit 64; }
    aggregate
    ;;
  *)
    usage
    exit 64
    ;;
esac
