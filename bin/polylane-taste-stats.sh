#!/usr/bin/env bash
# Deterministic aggregation for one blinded vote per independent brief.
set -euo pipefail
export LC_ALL=C

usage() {
  printf '%s\n' 'usage: polylane-taste-stats.sh aggregate [receipt-out.json] < ballots.json' >&2
}

invalid() {
  printf '%s\n' '{"error":"invalid_ballots","schema":"polylane.taste.stats.v1","valid":false,"reason_codes":["INVALID_BALLOTS"]}'
  exit 1
}

# Emit an input-bound aggregation receipt.  The brief is the sample unit:
# abstentions leave the denominator, ties keep half credit, and repeated judges
# on one brief never pool as independent samples.  classification is
# validator-derived "fixture" this hermetic cycle.
aggregate() {
  local out="${1:-}" ballot_json duplicate_paths input_sha256 validator_fp receipt tmp
  command -v jq >/dev/null 2>&1 || {
    printf '%s\n' 'polylane-taste-stats.sh: jq is required' >&2
    exit 127
  }

  ballot_json=$(cat) || invalid
  if ! duplicate_paths=$(printf '%s' "$ballot_json" | jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("")' 2>/dev/null | LC_ALL=C sort | uniq -d); then
    invalid
  fi
  [ -z "$duplicate_paths" ] || invalid

  # Bind the canonical input (formatting-independent) and fingerprint the tool.
  input_sha256=$(printf '%s' "$ballot_json" | jq -cS . 2>/dev/null | shasum -a 256 | awk '{print $1}') || invalid
  [ -n "$input_sha256" ] || invalid
  validator_fp=$(shasum -a 256 "$0" | awk '{print $1}')

  if ! receipt=$(printf '%s' "$ballot_json" | jq -ceS \
      --arg input_sha256 "$input_sha256" --arg validator_fp "$validator_fp" '
    def reject: error("invalid ballots");
    if type != "object" then reject else . end
    | if (keys == ["ballots", "schema"]) then . else reject end
    | if .schema == "polylane.taste.ballots.v1" then . else reject end
    | if (.ballots | type == "array" and length > 0) then . else reject end
    | if all(.ballots[];
        type == "object"
        and ((keys - ["brief_id", "judge_ids", "vote"]) == [])
        and (has("brief_id") and has("vote"))
        and (.brief_id | type == "string" and length > 0)
        and (.vote | type == "string" and (. == "candidate" or . == "baseline" or . == "tie" or . == "abstain"))
        and (if has("judge_ids") then (.judge_ids | type == "array" and all(.[]; type == "string" and length > 0)) else true end)
      ) then . else reject end
    | (.ballots | map(.brief_id)) as $brief_ids
    | if ($brief_ids | length == (unique | length)) then . else reject end
    | (.ballots | length) as $briefs
    | (.ballots | map(select(.vote != "abstain")) | length) as $n
    | if $n > 0 then . else reject end
    | (.ballots | map(select(.vote == "candidate")) | length) as $wins
    | (.ballots | map(select(.vote == "baseline")) | length) as $losses
    | (.ballots | map(select(.vote == "tie")) | length) as $ties
    | (.ballots | map(select(.vote == "abstain")) | length) as $abstentions
    | ([.ballots[] | (.judge_ids // [])[]] | unique | length) as $judges
    | (.ballots | map({(.brief_id): .vote}) | add) as $per_brief
    | ($wins + ($ties / 2)) as $preference_successes
    | ($preference_successes / $n) as $preference_rate
    | 1.96 as $z
    | (1 + (($z * $z) / $n)) as $denominator
    | (($preference_rate + (($z * $z) / (2 * $n))
        - ($z * pow((($preference_rate * (1 - $preference_rate)) + (($z * $z) / (4 * $n))) / $n; 0.5)))
       / $denominator) as $wilson_lower_bound
    | {
        schema: "polylane.taste.stats.v1",
        receipt_version: "polylane.taste.stats-receipt.v1",
        valid: true,
        status: "AGGREGATED",
        classification: "fixture",
        validator: {id: "polylane-taste-stats", fingerprint: $validator_fp},
        input_sha256: $input_sha256,
        sample_unit: "brief",
        confidence_level: 0.95,
        z_score: $z,
        brief_count: $briefs,
        sample_units: $n,
        abstentions: $abstentions,
        eligible_judge_count: $judges,
        per_brief: $per_brief,
        candidate_wins: $wins,
        baseline_wins: $losses,
        ties: $ties,
        preference_successes: $preference_successes,
        preference_rate: $preference_rate,
        wilson_lower_bound: $wilson_lower_bound,
        pass: ($preference_rate >= 0.70 and $wilson_lower_bound > 0.50),
        reason_codes: []
      }
  '); then
    invalid
  fi

  if [ -n "$out" ]; then
    tmp=$(mktemp "${out}.tmp.XXXXXX") || invalid
    printf '%s\n' "$receipt" > "$tmp" && mv -f "$tmp" "$out" || { rm -f "$tmp"; invalid; }
  else
    printf '%s\n' "$receipt"
  fi
}

case "${1:-}" in
  aggregate)
    [ "$#" -eq 1 ] || [ "$#" -eq 2 ] || { usage; exit 64; }
    aggregate "${2:-}"
    ;;
  *)
    usage
    exit 64
    ;;
esac
