#!/usr/bin/env bash
# polylane-visual.sh — deterministic visual-work detection and packet gates.
set -euo pipefail

usage() {
  echo "usage: polylane-visual.sh detect|prepare|validate <manifest> [references.json]" >&2
}

detect_ui() {
  local manifest="$1" evidence
  [ -f "$manifest" ] || { echo "VISUAL: manifest does not exist: $manifest" >&2; return 2; }
  command -v jq >/dev/null 2>&1 || { echo "VISUAL: jq required" >&2; return 2; }
  evidence=$(jq -r '[.lanes[]? | (.name // ""), (.activity // ""), (.own_globs[]? // "")] | join(" ")' "$manifest")
  case "$evidence" in
    *ui*|*UI*|*visual*|*Visual*|*.css*|*.tsx*|*.jsx*|*.vue*|*.svelte*|*component*) printf '%s\n' ui ;;
    *) printf '%s\n' non-ui ;;
  esac
}

project_root_for_manifest() {
  local manifest="$1" manifest_dir
  manifest_dir=$(cd "$(dirname "$manifest")" && pwd -P) || return 1
  case "$manifest_dir" in
    */.polylane) dirname "$manifest_dir" ;;
    *) printf '%s\n' "$manifest_dir" ;;
  esac
}

packet_path_for_manifest() {
  local root
  root=$(project_root_for_manifest "$1") || return 1
  printf '%s/docs/polylane/design/references.json\n' "$root"
}

valid_packet_shape() {
  local packet="$1" relevant_required
  jq -e '
    . as $packet
    | ($packet.references | map(.id)) as $reference_ids
    | ($packet.directions | map(.id)) as $direction_ids
    | $packet.winner as $winner
    | .schema == 1
    and (.intensity | IN("economy", "balanced", "max"))
    and (.references | type == "array")
    and ($reference_ids | length == (unique | length))
    and ([.references[] | select(.kind == "wildcard")] | length == 1)
    and (.directions | type == "array" and length == 3)
    and ($direction_ids | length == (unique | length))
    and (.council | type == "array" and length == 3)
    and ([.council[].direction] | sort == ($direction_ids | sort))
    and (.winner | type == "string" and ($direction_ids | index($winner)) != null)
    and all(.references[];
      (.id | type == "string" and length > 0)
      and (.kind == "relevant" or .kind == "wildcard")
      and (.source_url | type == "string" and test("^https?://[^[:space:]]+$"))
      and (.desktop_screenshot | type == "string" and length > 0 and (startswith("/") | not) and (contains("..") | not))
      and (.mobile_screenshot | type == "string" and length > 0 and (startswith("/") | not) and (contains("..") | not))
      and (.dimensions as $dimensions | ($dimensions | type == "object")
        and all(["hierarchy","typography","palette","spatial_rhythm","interaction","motion","signature_ideas"][];
          . as $key | ($dimensions[$key] | type == "string" and length > 0)))
      and all([.borrow, .transform, .avoid][]; type == "array" and length > 0 and all(.[]; type == "string" and length > 0)))
    and all(.directions[];
      (.id | type == "string" and length > 0)
      and (.summary | type == "string" and length > 0)
      and (.sources | type == "array" and length >= 2 and length == (unique | length))
      and all(.sources[]; . as $source | type == "string" and ($reference_ids | index($source)) != null))
    and all($reference_ids[];
      . as $source
      | ([$packet.directions[].sources[] | select(. == $source)] | length) < ($packet.directions | length))
    and all(.council[]; (.direction | type == "string") and (.score | type == "number"))
    and ([.council[] | select(.direction == $winner) | .score][0]
         == ([.council[].score] | max))
  ' "$packet" >/dev/null 2>&1 || return 1
  relevant_required=$(jq -r '.intensity | if . == "economy" then 3 elif . == "balanced" then 4 else 5 end' "$packet")
  [ "$(jq '[.references[] | select(.kind == "relevant")] | length' "$packet")" = "$relevant_required" ]
}

validate_packet() {
  local manifest="$1" root packet image winner sources summary decision
  root=$(project_root_for_manifest "$manifest") || return 1
  packet=$(packet_path_for_manifest "$manifest") || return 1
  [ -f "$packet" ] || { echo "VISUAL: missing reference packet: $packet" >&2; return 2; }
  valid_packet_shape "$packet" || { echo "VISUAL: invalid reference packet" >&2; return 2; }
  while IFS= read -r image; do
    [ -f "$root/$image" ] && [ ! -L "$root/$image" ] || {
      echo "VISUAL: missing or unsafe screenshot evidence: $image" >&2; return 2;
    }
  done < <(jq -r '.references[] | .desktop_screenshot, .mobile_screenshot' "$packet")
  [ -s "$root/docs/polylane/design/VISUAL-BRIEF.md" ] || {
    echo "VISUAL: missing VISUAL-BRIEF.md" >&2; return 2;
  }
  [ -s "$root/docs/polylane/design/DESIGN-DECISION.md" ] || {
    echo "VISUAL: missing DESIGN-DECISION.md" >&2; return 2;
  }
  winner=$(jq -r '.winner' "$packet")
  sources=$(jq -r --arg winner "$winner" '.directions[] | select(.id == $winner) | .sources | join(", ")' "$packet")
  summary=$(jq -r --arg winner "$winner" '.directions[] | select(.id == $winner) | .summary' "$packet")
  decision="$root/docs/polylane/design/DESIGN-DECISION.md"
  grep -Fqx "winner: $winner" "$decision" &&
    grep -Fqx "sources: $sources" "$decision" &&
    grep -Fqx "summary: $summary" "$decision" || {
      echo "VISUAL: frozen DESIGN-DECISION.md does not match reference packet" >&2; return 2;
    }
}

prepare_packet() {
  local manifest="$1" source="$2" root dest dir winner
  root=$(project_root_for_manifest "$manifest") || return 1
  [ -f "$source" ] || { echo "VISUAL: reference fixture does not exist: $source" >&2; return 2; }
  valid_packet_shape "$source" || { echo "VISUAL: invalid reference fixture" >&2; return 2; }
  dir="$root/docs/polylane/design"
  mkdir -p "$dir"
  dest="$dir/references.json"
  cp "$source" "$dest"
  winner=$(jq -r '.winner' "$dest")
  {
    printf '# Visual brief\n\n'
    printf 'intensity: %s\n' "$(jq -r '.intensity' "$dest")"
    printf 'winner: %s\n\n' "$winner"
    jq -r '.references[] | "- \(.id): borrow=\(.borrow | join(", ")); transform=\(.transform | join(", ")); avoid=\(.avoid | join(", "))"' "$dest"
  } > "$dir/VISUAL-BRIEF.md"
  {
    printf '# Frozen design decision\n\n'
    printf 'winner: %s\n' "$winner"
    jq -r --arg winner "$winner" '.directions[] | select(.id == $winner) | "sources: \(.sources | join(", "))\nsummary: \(.summary)"' "$dest"
  } > "$dir/DESIGN-DECISION.md"
  validate_packet "$manifest"
}

main() {
  case "${1:-}" in
    detect) [ $# -eq 2 ] || { usage; return 2; }; detect_ui "$2" ;;
    prepare) [ $# -eq 3 ] || { usage; return 2; }; prepare_packet "$2" "$3" ;;
    validate) [ $# -eq 2 ] || { usage; return 2; }; validate_packet "$2" ;;
    *) usage; return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
