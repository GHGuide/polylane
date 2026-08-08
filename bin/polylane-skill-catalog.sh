#!/usr/bin/env bash
# polylane-skill-catalog.sh — deterministic, metadata-only local skill catalog.
# It indexes YAML frontmatter plus a content fingerprint; it never emits SKILL
# bodies for prompt assembly. Bash 3.2 + jq only.
set -euo pipefail

usage() {
  echo "usage: polylane-skill-catalog.sh index OUTPUT | recommend CATALOG LANE_JSON OUTCOMES_JSONL | use-audit KIT LANE VERIFY DOMAIN OUTCOMES_JSONL" >&2
}

skill_roots() {
  local roots="${POLYLANE_SKILLS_DIRS:-}" old_ifs root
  [ -n "${CODEX_SKILLS_DIR:-}" ] && roots="${roots}${roots:+:}${CODEX_SKILLS_DIR}"
  [ -n "${CLAUDE_SKILLS_DIR:-}" ] && roots="${roots}${roots:+:}${CLAUDE_SKILLS_DIR}"
  if [ -z "$roots" ]; then
    roots="${HOME}/.codex/skills:${HOME}/.agents/skills:${HOME}/.claude/skills"
  fi
  old_ifs=$IFS; IFS=:
  for root in $roots; do [ -d "$root" ] && printf '%s\n' "$root"; done
  IFS=$old_ifs
}

frontmatter() {
  awk '
    NR == 1 { if ($0 != "---") exit 1; next }
    $0 == "---" { found = 1; exit }
    { print }
    END { if (!found) exit 1 }
  ' "$1"
}

yaml_scalar() {
  local key="$1" file="$2"
  awk -v key="$key" '
    $0 ~ "^[[:space:]]*" key "[[:space:]]*:" {
      sub("^[[:space:]]*" key "[[:space:]]*:[[:space:]]*", "")
      gsub(/^[[:space:]]+|[[:space:]]+$/, "")
      gsub(/^"|"$|^\047|\047$/, "")
      print; exit
    }
  ' "$file"
}

yaml_list() {
  local key="$1" file="$2" scalar
  scalar=$(yaml_scalar "$key" "$file")
  case "$scalar" in
    \[*\])
      scalar=${scalar#\[}; scalar=${scalar%\]}
      printf '%s' "$scalar" | tr ',' '\n' | sed "s/^[[:space:]]*//;s/[[:space:]]*$//;s/^['\"]//;s/['\"]$//" | sed '/^$/d'
      ;;
    ?*)
      printf '%s\n' "$scalar" | tr ',' '\n' | sed "s/^[[:space:]]*//;s/[[:space:]]*$//;s/^['\"]//;s/['\"]$//" | sed '/^$/d'
      ;;
    *)
      awk -v key="$key" '
        $0 ~ "^[[:space:]]*" key "[[:space:]]*:[[:space:]]*$" { found=1; next }
        found && $0 ~ "^[[:space:]]*-[[:space:]]+" {
          sub("^[[:space:]]*-[[:space:]]+", ""); gsub(/^"|"$|^\047|\047$/, ""); print; next
        }
        found && $0 !~ "^[[:space:]]*($|#)" { exit }
      ' "$file"
      ;;
  esac
}

append_metadata() {
  local id="$1" path="$2" source="$3" priority="$4" fm name description compatibility allowed fingerprint
  fm=$(mktemp "${TMPDIR:-/tmp}/polylane-frontmatter.XXXXXX") || return 1
  frontmatter "$path" > "$fm" || { rm -f "$fm"; return 0; }
  name=$(yaml_scalar name "$fm")
  description=$(yaml_scalar description "$fm")
  compatibility=$(yaml_list compatibility "$fm" | jq -R . | jq -cs '.')
  allowed=$(yaml_list allowed-tools "$fm" | jq -R . | jq -cs '.')
  fingerprint=$(cksum "$path" | awk '{print $1 "-" $2}')
  jq -cn --arg id "$id" --arg path "$path" --arg name "$name" --arg description "$description" \
    --arg source "$source" --argjson priority "$priority" --arg fingerprint "$fingerprint" \
    --argjson compatibility "$compatibility" --argjson allowed_tools "$allowed" \
    '{id:$id,path:$path,name:$name,description:$description,compatibility:$compatibility,allowed_tools:$allowed_tools,source:$source,fingerprint:$fingerprint,priority:$priority}'
  rm -f "$fm"
}

index_root() {
  local root="$1" path rel id segments
  find "$root" -type f -name SKILL.md -print 2>/dev/null | LC_ALL=C sort | while IFS= read -r path; do
    rel=${path#"$root"/}
    segments=$(printf '%s' "$rel" | awk -F/ '{print NF}')
    case "$segments" in
      2) id=${rel%/SKILL.md} ;;
      3) id=$(printf '%s' "${rel%/SKILL.md}" | awk -F/ '{print $1 ":" $2}') ;;
      *) continue ;;
    esac
    append_metadata "$id" "$path" trusted-root 0
  done
}

index_plugin_cache() {
  local cache="${HOME}/.codex/plugins/cache" path id
  [ -d "$cache" ] || return 0
  find "$cache" -type f -name SKILL.md -print 2>/dev/null | LC_ALL=C sort | while IFS= read -r path; do
    id=$(printf '%s' "$path" | awk -F/ '{ for (i = 1; i <= NF; i++) if ($i == "skills" && i > 2 && i < NF - 1) { print $(i-2) ":" $(i+1); exit } }')
    [ -n "$id" ] || continue
    append_metadata "$id" "$path" plugin-cache 1
  done
}

index_catalog() {
  local output="$1" temp root
  command -v jq >/dev/null 2>&1 || { echo "SKILL-CATALOG: jq required" >&2; return 2; }
  temp=$(mktemp "${TMPDIR:-/tmp}/polylane-skill-catalog.XXXXXX") || return 1
  while IFS= read -r root; do index_root "$root" >> "$temp"; done < <(skill_roots)
  index_plugin_cache >> "$temp"
  mkdir -p "$(dirname "$output")"
  jq -s '{schema:1,skills:(sort_by(.priority, .id, .path) | group_by(.id) | map(.[0] | del(.priority)) | sort_by(.id))}' "$temp" > "$output"
  rm -f "$temp"
}

lane_domain() {
  local all="$*"
  case "$all" in
    *.tsx*|*.jsx*|*.vue*|*.svelte*|*components/*|*/ui/*|*.css*) echo ui ;;
    *routes/*|*api/*|*/handlers/*|*controllers/*|*.openapi*) echo api ;;
    *.sql*|*migrations/*|*.prisma*|*schema*) echo data ;;
    *.swift*|*.kt*|*android/*|*ios/*|*.xcodeproj*) echo mobile ;;
    *test*|*spec*) echo test ;;
    *.md*|*report*|*.docx*|*.pdf*|*.pptx*|*.xlsx*) echo report ;;
    *) echo unknown ;;
  esac
}

recommend_catalog() {
  local catalog="$1" lane_file="$2" ledger="$3" lane domain outcomes
  [ -f "$catalog" ] && [ -f "$lane_file" ] || { echo "SKILL-CATALOG: catalog and lane JSON are required" >&2; return 2; }
  jq -e '.schema == 1 and (.skills | type == "array")' "$catalog" >/dev/null || { echo "SKILL-CATALOG: invalid catalog" >&2; return 2; }
  jq -e '(.role | type == "string") and (.goal | type == "string") and (.activities | type == "array") and (.own_globs | type == "array") and (.agent | type == "string") and (.required_tools | type == "array")' "$lane_file" >/dev/null || { echo "SKILL-CATALOG: invalid lane specification" >&2; return 2; }
  lane=$(jq -c . "$lane_file")
  domain=$(lane_domain "$(jq -r '.own_globs | join(" ")' "$lane_file")")
  outcomes='[]'
  if [ -f "$ledger" ]; then outcomes=$(jq -cs '.' "$ledger" 2>/dev/null) || outcomes='[]'; fi
  jq --argjson lane "$lane" --argjson outcomes "$outcomes" --arg domain "$domain" '
    def tokens($s): ($s | tostring | ascii_downcase | gsub("[^a-z0-9]+"; " ") | split(" ") | map(select(length >= 4 and . != "with" and . != "that" and . != "from" and . != "into")) | unique);
    def domain_terms($d): if $d == "ui" then ["ui", "browser", "screenshot", "visual", "render"] elif $d == "api" then ["api", "route", "endpoint", "http"] elif $d == "data" then ["data", "sql", "schema", "migration"] elif $d == "mobile" then ["mobile", "ios", "android"] elif $d == "test" then ["test", "verify", "assert"] elif $d == "report" then ["report", "document", "markdown"] else [] end;
    .skills | map(. as $skill | (($skill.id + " " + $skill.name + " " + $skill.description) | ascii_downcase) as $hay
      | ([ $lane.activities[]? as $activity | ($activity | tokens(.)) as $terms | select(any($terms[]?; . as $term | $hay | contains($term))) | $activity ]) as $activity_matches
      | ([($lane.goal | tokens(.))[] as $term | select($hay | contains($term))] | unique) as $goal_matches
      | ([domain_terms($domain)[] as $term | select($hay | contains($term))] | unique) as $domain_matches
      | ([ $lane.required_tools[]? | ascii_downcase as $tool | select(($skill.allowed_tools | map(ascii_downcase) | index($tool))) ]) as $tool_matches
      | ($outcomes | map(select(.skill == $skill.id))) as $history
      | ([ $history[] | select(.outcome == "helped") ] | length) as $helped | ([ $history[] | select(.outcome == "unused") ] | length) as $unused | ([ $history[] | select(.outcome == "hurt") ] | length) as $hurt
      | select($hurt == 0) | select(($skill.compatibility | length) == 0 or ($skill.compatibility | map(ascii_downcase) | index($lane.agent | ascii_downcase))) | select(($lane.required_tools | length) == ($tool_matches | length)) | select(($activity_matches | length) > 0 or (($goal_matches | length) >= 2 and ($domain_matches | length) > 0))
      | {id:$skill.id,path:$skill.path,source:$skill.source,score:(($activity_matches | length) * 30 + ($goal_matches | length) * 4 + ($domain_matches | length) * 6 + ($tool_matches | length) * 5 + $helped * 10 - $unused * 3),helped:$helped,unused:$unused,reason:("activities:" + ($activity_matches | join(",")) + "; globs:" + $domain + "; agent:" + $lane.agent + "; tools:" + ($tool_matches | join(",")) + " — capability: " + $skill.description)}
    ) | sort_by(-.score, .id, .path) | .[0:3] | {schema:1,role:$lane.role,domain:$domain,candidates:.}
  ' "$catalog"
}

append_outcome() {
  local ledger="$1" lane="$2" domain="$3" skill="$4" outcome="$5" why="$6"
  mkdir -p "$(dirname "$ledger")"
  jq -cn --arg lane "$lane" --arg domain "$domain" --arg skill "$skill" --arg outcome "$outcome" --arg why "$why" '{lane:$lane,domain:$domain,skill:$skill,outcome:$outcome,why:$why}' >> "$ledger"
  printf '\n' >> "$ledger"
}

use_audit() {
  local kit="$1" lane="$2" verify="$3" domain="$4" ledger="$5" skill effect outcome why helped='[]' unused='[]' hurt='[]'
  [ -f "$kit" ] || { echo "SKILL-CATALOG: kit is required" >&2; return 2; }
  jq -e '.version == 2 and (.lanes | type == "object")' "$kit" >/dev/null || { echo "SKILL-CATALOG: invalid kit" >&2; return 2; }
  while IFS= read -r skill; do
    effect=''
    [ -f "$verify" ] && effect=$(awk -v prefix="SKILL-EVIDENCE: $skill — " 'index($0, prefix) == 1 { print substr($0, length(prefix) + 1); exit }' "$verify")
    if [ -z "$effect" ]; then
      unused=$(jq --arg id "$skill" '. + [$id]' <<<"$unused")
      append_outcome "$ledger" "$lane" "$domain" "$skill" unused "missing SKILL-EVIDENCE record in $verify"
      continue
    fi
    # Evidence is a scored observation, not a flattering free-form claim.
    # Existing unprefixed evidence remains compatible and means helped; new
    # lanes can report `unused:` or `hurt:` without being misclassified.
    outcome=helped; why="$effect"
    case "$effect" in
      unused:*) outcome=unused; why=${effect#unused:} ;;
      hurt:*) outcome=hurt; why=${effect#hurt:} ;;
      helped:*) outcome=helped; why=${effect#helped:} ;;
    esac
    case "$outcome" in
      helped) helped=$(jq --arg id "$skill" --arg effect "$why" '. + [{id:$id,effect:$effect}]' <<<"$helped") ;;
      unused) unused=$(jq --arg id "$skill" '. + [$id]' <<<"$unused") ;;
      hurt) hurt=$(jq --arg id "$skill" --arg effect "$why" '. + [{id:$id,effect:$effect}]' <<<"$hurt") ;;
    esac
    append_outcome "$ledger" "$lane" "$domain" "$skill" "$outcome" "$why"
  done < <(jq -r --arg lane "$lane" '((.lanes[$lane].predefined // []) + (.lanes[$lane].specific // [])) | unique[]' "$kit")
  jq -n --arg lane "$lane" --arg verify "$verify" --argjson helped "$helped" --argjson unused "$unused" --argjson hurt "$hurt" '{schema:1,lane:$lane,verify_file:$verify,helped:$helped,unused:$unused,hurt:$hurt}'
}

main() {
  case "${1:-}" in
    index) [ $# -eq 2 ] || { usage; return 2; }; index_catalog "$2" ;;
    recommend) [ $# -eq 4 ] || { usage; return 2; }; recommend_catalog "$2" "$3" "$4" ;;
    use-audit) [ $# -eq 6 ] || { usage; return 2; }; use_audit "$2" "$3" "$4" "$5" "$6" ;;
    *) usage; return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
