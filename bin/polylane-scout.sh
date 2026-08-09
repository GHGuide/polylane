#!/usr/bin/env bash
# polylane-scout.sh — the MECHANICAL half of the per-lane skill scout. The doc
# (references/skill-scout.md) was pure LLM discretion: nothing inferred a lane's
# domain, checked a skill was installed, wrote lane-skills.json, or verified the
# picked skill actually landed in the prompt. This does all four deterministically;
# the orchestrator still makes the final call + handles GitHub discovery.
#   domain <glob>...            -> ui|api|data|mobile|report|test|unknown (from globs)
#   suggest <domain>            -> curated INSTALLED skills for that domain (space-sep)
#   installed <skill>           -> exit 0 iff the skill/plugin is installed
#   bake <file> <lane> <skill>. -> legacy flat kit (only installed skills)
#   arm-role <file> <lane> <predefined|specific> <skill>...
#   migrate <file>             -> resolve historical v2 name lists into typed v3 records
#   github <file> <lane> <repo-or-skill> <why> -> informational suggestion
#   github-suggest <activity> [limit] -> read-only ranked GitHub candidates
#   catalog-index <output> -> trusted metadata-only skill catalog
#   catalog-recommend <catalog> <lane.json> <outcomes.jsonl> -> explained matches
#   use-audit <kit> <lane> <verify> <domain> <outcomes.jsonl> -> evidence-led outcomes
#   acquire <project> <candidate> <source.json> <benchmark.json> -> authorized admission
#   arm-admitted <project> <file> <lane> <role> <skill> -> arm only a locked project skill
#   armed <file> <lane>         -> print every executable skill in a lane's kit
#   validate <file> <manifest>  -> require 1-2 selected installed skills per role
#   lint <file> <lane> <prompt> -> exit 5 iff a baked skill is missing from the prompt
# bash-3.2 + jq (jq only for the json verbs); main-guarded.
set -euo pipefail

# domain GLOB... : one domain label from the lane's own_globs (extensions + paths).
domain() {
  local all="$*"
  case "$all" in
    *.tsx*|*.jsx*|*.vue*|*.svelte*|*components/*|*/ui/*|*.css*) echo ui ;;
    *routes/*|*api/*|*/handlers/*|*controllers/*|*.openapi*)    echo api ;;
    *.sql*|*migrations/*|*.prisma*|*schema*)                    echo data ;;
    *.swift*|*.kt*|*android/*|*ios/*|*.xcodeproj*)              echo mobile ;;
    *test*|*spec*)                                             echo test ;;
    *.md*|*report*|*.docx*|*.pdf*|*.pptx*|*.xlsx*)             echo report ;;
    *) echo unknown ;;
  esac
}

# curated domain -> candidate skills (the DOMAIN layer; block 0 owns the base).
_candidates() {
  case "$1" in
    ui)     echo "design:design-critique dataviz" ;;
    api)    echo "42crunch-audit code-to-oas" ;;
    data)   echo "supabase" ;;
    mobile) echo "expo" ;;
    report) echo "docx pdf pptx xlsx" ;;
    test)   echo "playwright" ;;
    *)      echo "" ;;
  esac
}

# Print configured skill roots one per line. POLYLANE_SKILLS_DIRS is a colon-separated
# override for hermetic tests and unusual installations. Codex roots are first-class;
# Claude roots remain for the shared core package.
_skill_roots() {
  local roots="${POLYLANE_SKILLS_DIRS:-}" old_ifs root
  [ -n "${CODEX_SKILLS_DIR:-}" ] && roots="${roots}${roots:+:}${CODEX_SKILLS_DIR}"
  [ -n "${CLAUDE_SKILLS_DIR:-}" ] && roots="${roots}${roots:+:}${CLAUDE_SKILLS_DIR}"
  if [ -z "$roots" ]; then
    roots="${HOME}/.codex/skills:${HOME}/.agents/skills:${HOME}/.claude/skills"
  fi
  old_ifs=$IFS; IFS=:
  for root in $roots; do [ -n "$root" ] && printf '%s\n' "$root"; done
  IFS=$old_ifs
}

# canonical_skill_file PATH: a readable regular file with no final symlink.
# `cd -P` makes the root comparison below resistant to an alias in a parent path.
canonical_skill_file() {
  local path="$1" dir
  [ -f "$path" ] && [ -r "$path" ] && [ ! -L "$path" ] || return 1
  dir=$(cd -P "$(dirname "$path")" 2>/dev/null && pwd) || return 1
  printf '%s/%s\n' "$dir" "$(basename "$path")"
}

# trusted_skill_source PATH: print the configured trusted source which owns PATH.
# Plugin cache is a read-only installed source; project admission is distinguished
# from an ordinary configured root for receipt and incident evidence.
trusted_skill_source() {
  local path="$1" root canonical_root cache canonical_cache
  while IFS= read -r root; do
    canonical_root=$(cd -P "$root" 2>/dev/null && pwd) || continue
    case "$path" in
      "$canonical_root"/*)
        case "$canonical_root" in */.polylane/skills) echo project-admitted ;; *) echo trusted-root ;; esac
        return 0 ;;
    esac
  done < <(_skill_roots)
  cache="$HOME/.codex/plugins/cache"
  canonical_cache=$(cd -P "$cache" 2>/dev/null && pwd) || return 1
  case "$path" in "$canonical_cache"/*) echo plugin-cache; return 0 ;; esac
  return 1
}

skill_fingerprint() { cksum "$1" | awk '{print $1 "-" $2}'; }

reject_navigation_skill() {
  case "$1" in
    graphify|graphify-auto)
      echo "polylane-scout: '$1' is navigation infrastructure, not an executable selected skill; query graphify-out/q.py directly" >&2
      return 2 ;;
  esac
}

# selected_record ID REASON: metadata only. It never reads a skill body.
selected_record() {
  local id="$1" reason="$2" resolved path source fingerprint
  resolved=$(resolve "$id" 2>/dev/null) || {
    echo "polylane-scout: selected skill '$id' cannot be resolved" >&2; return 1;
  }
  path=$(canonical_skill_file "$resolved") || {
    echo "polylane-scout: selected skill '$id' has missing or unreadable path" >&2; return 1;
  }
  source=$(trusted_skill_source "$path") || {
    echo "polylane-scout: selected skill '$id' resolved outside trusted roots: $path" >&2; return 1;
  }
  fingerprint=$(skill_fingerprint "$path")
  jq -cn --arg id "$id" --arg path "$path" --arg reason "$reason" \
    --arg source "$source" --arg fingerprint "$fingerprint" \
    '{id:$id,path:$path,reason:$reason,source:$source,fingerprint:$fingerprint}'
}

# resolve SKILL : print the exact trusted local SKILL.md for a qualified or
# unqualified skill. Plugin cache entries are read-only metadata, never code.
resolve() {
  local skill="$1" namespace member root found
  case "$skill" in
    ''|*/*|*'..'*|:*|*:|*:*:*|*[!A-Za-z0-9._:-]*)
      echo "polylane-scout: invalid skill id: $skill" >&2
      return 2 ;;
  esac
  namespace="${skill%%:*}"
  member="${skill#*:}"
  while IFS= read -r root; do
    if [ "$namespace" = "$skill" ]; then
      [ -f "$root/$skill/SKILL.md" ] && { printf '%s\n' "$root/$skill/SKILL.md"; return 0; }
    else
      [ -f "$root/$namespace/$member/SKILL.md" ] && { printf '%s\n' "$root/$namespace/$member/SKILL.md"; return 0; }
    fi
  done < <(_skill_roots)
  if [ "$namespace" = "$skill" ]; then
    found=$(find "${HOME}/.codex/plugins/cache" -type f -path "*/skills/$skill/SKILL.md" -print 2>/dev/null | LC_ALL=C sort | head -n 1)
  else
    found=$(find "${HOME}/.codex/plugins/cache" -type f -path "*/$namespace/*/skills/$member/SKILL.md" -print 2>/dev/null | LC_ALL=C sort | head -n 1)
  fi
  [ -n "$found" ] || return 1
  printf '%s\n' "$found"
}

# installed SKILL : 0 iff an executable local skill/plugin is present. A qualified
# name such as design:design-critique requires the plugin namespace ("design") and
# is not satisfied by an unrelated unqualified design-critique directory.
installed() { resolve "$1" >/dev/null 2>&1; }

_recommend_candidates() {
  local domain="$1" activity="$2"
  case "$domain:$activity" in
    ui:*critique*|ui:*review*) echo "design:design-critique" ;;
    test:*|*:test*|*:verify*) echo "superpowers:test-driven-development engineering:testing-strategy" ;;
    api:*) echo "42crunch-api-security-testing:42crunch-audit" ;;
    report:*) echo "anthropic-skills:docx anthropic-skills:pdf" ;;
    *) echo "$(_candidates "$domain")" ;;
  esac
}

record_outcome() {
  local ledger="$1" lane="$2" domain="$3" skill="$4" outcome="$5" why="${6:-}"
  case "$outcome" in helped|unused|hurt) ;; *)
    echo "polylane-scout: outcome must be helped, unused, or hurt" >&2; return 2 ;;
  esac
  mkdir -p "$(dirname "$ledger")"
  jq -cn --arg lane "$lane" --arg domain "$domain" --arg skill "$skill" \
    --arg outcome "$outcome" --arg why "$why" \
    '{lane:$lane,domain:$domain,skill:$skill,outcome:$outcome,why:$why}' >> "$ledger"
  printf '\n' >> "$ledger"
}

recommend() {
  local domain="$1" activity="$2" ledger="${POLYLANE_OUTCOMES_FILE:-docs/polylane/skill-outcomes.jsonl}"
  local candidate path items="" score
  for candidate in $(_recommend_candidates "$domain" "$activity"); do
    path=$(resolve "$candidate" 2>/dev/null) || continue
    score='{"helped":0,"unused":0}'
    if [ -f "$ledger" ]; then
      score=$(jq -s --arg domain "$domain" --arg skill "$candidate" '
        map(select(.domain == $domain and .skill == $skill))
        | if any(.outcome == "hurt") then "hurt"
          else {helped: ([.[] | select(.outcome == "helped")] | length),
                unused: ([.[] | select(.outcome == "unused")] | length)} end
      ' "$ledger" 2>/dev/null) || score='{"helped":0,"unused":0}'
    fi
    [ "$score" = '"hurt"' ] && continue
    items="${items}${items:+,}{\"skill\":$(printf '%s' "$candidate" | jq -R .),\"path\":$(printf '%s' "$path" | jq -R .),\"helped\":$(printf '%s' "$score" | jq -r '.helped'),\"unused\":$(printf '%s' "$score" | jq -r '.unused')}"
  done
  printf '{"domain":%s,"activity":%s,"skills":[%s]}\n' \
    "$(printf '%s' "$domain" | jq -R .)" "$(printf '%s' "$activity" | jq -R .)" "$items" \
    | jq '.skills |= sort_by(-.helped, .unused, .skill)'
}

# suggest DOMAIN : the candidates for a domain that are ACTUALLY installed (bake-free).
suggest() {
  local c; for c in $(_candidates "$1"); do installed "$c" && printf '%s ' "$c"; done; echo
}

bake() {
  local f="$1" lane="$2"; shift 2
  command -v jq >/dev/null 2>&1 || { echo "polylane-scout: jq required" >&2; return 2; }
  local keep="" s
  for s in "$@"; do
    if installed "$s"; then keep="$keep $s"
    else echo "polylane-scout: skill '$s' not installed — NOT baked (needs explicit install)" >&2; fi
  done
  mkdir -p "$(dirname "$f")" 2>/dev/null || true
  [ -f "$f" ] || echo '{}' > "$f"
  local arr
  # shellcheck disable=SC2086  # keep is a deliberately space-separated skill list
  arr=$(printf '%s\n' $keep | jq -R . | jq -cs 'map(select(length>0))')
  local tmp="$f.tmp.$$"
  jq --arg l "$lane" --argjson v "$arr" '.[$l] = $v' "$f" > "$tmp" && mv "$tmp" "$f"
}

_installed_array() {
  local keep="" s
  for s in "$@"; do
    if installed "$s"; then
      keep="$keep $s"
    else
      echo "polylane-scout: skill '$s' not installed — NOT armed (GitHub suggestions stay informational)" >&2
    fi
  done
  # shellcheck disable=SC2086
  printf '%s\n' $keep | jq -R . | jq -cs '
    map(select(length>0))
    | reduce .[] as $x ([]; if index($x) then . else . + [$x] end)
  '
}

selected_array() {
  local role="$1" ids="$2"
  local records='[]' skill record
  while IFS= read -r skill; do
    record=$(selected_record "$skill" "$role role selection") || continue
    records=$(jq --argjson record "$record" '. + [$record]' <<<"$records")
  done < <(jq -r '.[]' <<<"$ids")
  printf '%s\n' "$records"
}

write_armed_role() {
  local f="$1" lane="$2" role="$3" ids="$4" selected="$5" tmp
  mkdir -p "$(dirname "$f")" 2>/dev/null || true
  [ -f "$f" ] || echo '{"version":3,"lanes":{}}' > "$f"
  tmp="$f.tmp.$$"
  jq --arg l "$lane" --arg r "$role" --argjson v "$ids" --argjson selected "$selected" '
    .version = 3
    | .lanes = (.lanes // {})
    | .lanes[$l] = (.lanes[$l] // {
        predefined: [], specific: [], selected: {predefined: [], specific: []}, github_suggestions: []
      })
    | .lanes[$l][$r] = $v
    | .lanes[$l].selected = (.lanes[$l].selected // {predefined: [], specific: []})
    | .lanes[$l].selected[$r] = $selected
    | .lanes[$l].github_suggestions = (.lanes[$l].github_suggestions // [])
  ' "$f" > "$tmp" && mv "$tmp" "$f"
}

# arm_role FILE LANE ROLE SKILL... : write a strict, role-separated kit. Builders
# receive both a stable base kit and skills chosen specifically for their lane.
arm_role() {
  local f="$1" lane="$2" role="$3" arr selected skill
  shift 3
  case "$role" in predefined|specific) ;; *)
    echo "polylane-scout: role must be predefined or specific" >&2; return 2 ;;
  esac
  command -v jq >/dev/null 2>&1 || { echo "polylane-scout: jq required" >&2; return 2; }
  for skill in "$@"; do reject_navigation_skill "$skill" || return $?; done
  arr=$(_installed_array "$@")
  selected=$(selected_array "$role" "$arr")
  [ "$(jq 'length' <<<"$selected")" -eq "$(jq 'length' <<<"$arr")" ] || {
    echo "polylane-scout: refusing to arm unresolved or untrusted selected skill" >&2; return 2;
  }
  write_armed_role "$f" "$lane" "$role" "$arr" "$selected"
}

# arm_recommendation FILE LANE ROLE RECOMMENDATION_JSON ID: preserve the exact
# candidate selected by the planner. The record is re-resolved before persistence
# so stale recommendation metadata cannot arm a changed or untrusted file.
arm_recommendation() {
  local f="$1" lane="$2" role="$3" recommendation="$4" id="$5" candidate candidate_path canonical_candidate current ids benchmark helper gate_file gate
  case "$role" in predefined|specific) ;; *) echo "polylane-scout: role must be predefined or specific" >&2; return 2 ;; esac
  [ -f "$recommendation" ] || { echo "polylane-scout: recommendation file is missing" >&2; return 2; }
  candidate=$(jq -c --arg id "$id" '(.candidates // [])[] | select(.id == $id)' "$recommendation" | head -n 1)
  reject_navigation_skill "$id" || return $?
  [ -n "$candidate" ] || { echo "polylane-scout: recommendation does not select '$id'" >&2; return 2; }
  jq -e '.status == "recommended" and .safe_to_apply == true' <<<"$candidate" >/dev/null || {
    echo "polylane-scout: candidate is not benchmark-recommended and safe to apply" >&2; return 2;
  }
  jq -e '(.id | type == "string") and (.path | type == "string") and (.reason | type == "string" and length > 0) and (.source | type == "string") and (.fingerprint | type == "string") and (.domain | type == "string" and length > 0) and (.lane_shape | type == "string" and length > 0)' <<<"$candidate" >/dev/null || {
    echo "polylane-scout: recommendation lacks typed selected-skill metadata" >&2; return 2;
  }
  candidate_path=$(jq -r '.path' <<<"$candidate")
  canonical_candidate=$(canonical_skill_file "$candidate_path" 2>/dev/null) || {
    echo "polylane-scout: recommendation path is missing or unreadable" >&2; return 2;
  }
  current=$(selected_record "$id" "$(jq -r '.reason' <<<"$candidate")") || return 2
  jq -e --arg path "$canonical_candidate" --argjson current "$current" '
    .id == $current.id and $path == $current.path and .source == $current.source and .fingerprint == $current.fingerprint
  ' <<<"$candidate" >/dev/null || {
    echo "polylane-scout: recommendation identity no longer matches trusted resolved skill" >&2; return 2;
  }
  benchmark="${POLYLANE_SKILL_BENCHMARK_LEDGER:-}"
  [ -n "$benchmark" ] || {
    echo "polylane-scout: benchmark ledger is required to arm a recommendation" >&2; return 2;
  }
  helper="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/polylane-skill-benchmark.sh"
  [ -x "$helper" ] || { echo "polylane-scout: benchmark helper missing" >&2; return 2; }
  gate_file=$(mktemp "${TMPDIR:-/tmp}/polylane-skill-arm-gate.XXXXXX") || return 1
  trap 'rm -f "$gate_file"' RETURN
  jq -n --argjson current "$current" --argjson candidate "$candidate" \
    '{id:$current.id,fingerprint:$current.fingerprint,domain:$candidate.domain,lane_shape:$candidate.lane_shape}' > "$gate_file"
  gate=$(bash "$helper" gate "$benchmark" "$gate_file") || return $?
  jq -e '.status == "recommended" and .safe_to_apply == true' <<<"$gate" >/dev/null || {
    echo "polylane-scout: real benchmark gate does not admit this candidate" >&2; return 2;
  }
  ids=$(jq -cn --arg id "$id" '[$id]')
  write_armed_role "$f" "$lane" "$role" "$ids" "[$current]"
}

armed_role() {
  jq -r --arg l "$2" --arg r "$3" \
    '(.lanes[$l][$r] // []) | join(" ")' "$1" 2>/dev/null
}

record_github() {
  local f="$1" lane="$2" skill="$3" why="$4" tmp
  command -v jq >/dev/null 2>&1 || { echo "polylane-scout: jq required" >&2; return 2; }
  mkdir -p "$(dirname "$f")" 2>/dev/null || true
  [ -f "$f" ] || echo '{"version":2,"lanes":{}}' > "$f"
  tmp="$f.tmp.$$"
  jq --arg l "$lane" --arg s "$skill" --arg w "$why" '
    .version = 2
    | .lanes = (.lanes // {})
    | .lanes[$l] = (.lanes[$l] // {
        predefined: [], specific: [], github_suggestions: []
      })
    | .lanes[$l].github_suggestions =
        ((.lanes[$l].github_suggestions // []) + [{skill:$s, why:$w}] | unique_by(.skill))
  ' "$f" > "$tmp" && mv "$tmp" "$f"
}

# acquire PROJECT CANDIDATE SOURCE BENCHMARK: discovery callers never receive a
# runnable path; the acquisition helper decides whether an inert quarantine can
# become project-local admitted content.
acquire() {
  local project="$1" candidate="$2" source="$3" benchmark="$4" helper
  helper="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/polylane-skill-acquire.sh"
  [ -x "$helper" ] || { echo "polylane-scout: acquisition helper missing" >&2; return 2; }
  "$helper" admit "$project" "$candidate" "$source" "$benchmark"
}

catalog_helper() {
  local helper
  helper="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/polylane-skill-catalog.sh"
  [ -x "$helper" ] || { echo "polylane-scout: skill catalog helper missing" >&2; return 2; }
  "$helper" "$@"
}

# arm_admitted PROJECT FILE LANE ROLE SKILL: do not trust a mere directory;
# require the durable lock's admitted status before temporarily resolving the
# project-scoped copy as the selected kit member.
arm_admitted() {
  local project="$1" file="$2" lane="$3" role="$4" skill="$5" lock
  lock="$project/docs/polylane/design/SKILL-LOCK.json"
  case "$skill" in ''|*[!A-Za-z0-9._-]*) echo "polylane-scout: invalid admitted skill id" >&2; return 2 ;; esac
  [ -f "$lock" ] && [ -f "$project/.polylane/skills/$skill/SKILL.md" ] || {
    echo "polylane-scout: skill '$skill' is not project-admitted" >&2; return 2;
  }
  jq -e --arg skill "$skill" 'any(.skills[]?; .id == $skill and .status == "admitted")' "$lock" >/dev/null 2>&1 || {
    echo "polylane-scout: skill '$skill' has no admitted lock evidence" >&2; return 2;
  }
  POLYLANE_SKILLS_DIRS="$project/.polylane/skills" arm_role "$file" "$lane" "$role" "$skill"
}

# github_suggest ACTIVITY [LIMIT] : informational discovery only. The output is
# deliberately not written into executable roles; record a reviewed candidate with
# `github` later. gh auth/network absence is explicit and never blocks builder work.
github_suggest() {
  local activity="$1" limit="${2:-5}" json
  command -v gh >/dev/null 2>&1 || {
    echo "polylane-scout: gh unavailable — GitHub suggestions skipped" >&2; return 3
  }
  case "$limit" in *[!0-9]*|"") echo "polylane-scout: limit must be an integer" >&2; return 2 ;; esac
  json=$(gh search repos "agent skill $activity" --limit "$limit" --sort stars \
    --json nameWithOwner,description,stargazersCount,updatedAt,url 2>/dev/null) || {
      echo "polylane-scout: GitHub search unavailable — suggestions skipped" >&2
      return 3
    }
  printf '%s' "$json" | jq -r '
    sort_by(-(.stargazersCount // 0), .nameWithOwner)
    | .[]
    | "\(.nameWithOwner)\t★\(.stargazersCount // 0)\t\(.updatedAt // "?")\t\(.description // "")\t\(.url // "")"
  '
}

armed() {
  jq -r --arg l "$2" '
    if (.lanes? | type) == "object"
    then (((.lanes[$l].predefined // []) + (.lanes[$l].specific // [])) | unique | join(" "))
    else ((.[$l] // []) | join(" "))
    end
  ' "$1" 2>/dev/null
}

# migrate FILE: v2 kits were only names, so they cannot prove what a builder
# read. Resolve them once now into the same v3 record that new arming writes.
migrate_kit() {
  local f="$1" version lane role ids records tmp
  [ -f "$f" ] || { echo "SCOUT-KIT: missing kit: $f" >&2; return 7; }
  version=$(jq -r '.version // 0' "$f" 2>/dev/null) || { echo "SCOUT-KIT: invalid kit: $f" >&2; return 7; }
  [ "$version" = 2 ] || [ "$version" = 3 ] || { echo "SCOUT-KIT: unsupported kit version: $version" >&2; return 7; }
  [ "$version" = 3 ] && return 0
  tmp="$f.tmp.$$"
  jq '.version = 3 | .lanes |= with_entries(.value.selected = {predefined: [], specific: []})' "$f" > "$tmp" && mv "$tmp" "$f"
  for lane in $(jq -r '.lanes | keys[]' "$f"); do
    for role in predefined specific; do
      ids=$(jq -r --arg l "$lane" --arg r "$role" '(.lanes[$l][$r] // [])[]' "$f")
      records='[]'
      for id in $ids; do
        records=$(jq --argjson record "$(selected_record "$id" "migrated legacy $role role selection")" '. + [$record]' <<<"$records") || return 7
      done
      tmp="$f.tmp.$$"
      jq --arg l "$lane" --arg r "$role" --argjson records "$records" '.lanes[$l].selected[$r] = $records' "$f" > "$tmp" && mv "$tmp" "$f"
    done
  done
}

validate_selected_record() {
  local record="$1" id path reason source fingerprint resolved actual_source
  id=$(jq -r '.id // empty' <<<"$record")
  reject_navigation_skill "$id" || return $?
  path=$(jq -r '.path // empty' <<<"$record")
  reason=$(jq -r '.reason // empty' <<<"$record")
  source=$(jq -r '.source // empty' <<<"$record")
  fingerprint=$(jq -r '.fingerprint // empty' <<<"$record")
  case "$id:$path:$reason:$source:$fingerprint" in *'::'*|:*|*:) return 1 ;; esac
  [ "${path#/}" != "$path" ] || return 1
  [ "$(canonical_skill_file "$path" 2>/dev/null || true)" = "$path" ] || return 1
  actual_source=$(trusted_skill_source "$path" 2>/dev/null) || return 1
  [ "$source" = "$actual_source" ] || return 1
  [ "$fingerprint" = "$(skill_fingerprint "$path")" ] || return 1
  resolved=$(resolve "$id" 2>/dev/null) || return 1
  [ "$(canonical_skill_file "$resolved" 2>/dev/null || true)" = "$path" ] || return 1
}

# validate_kits FILE MANIFEST : a strict orchestration contract for builders.
# GitHub suggestions are advisory metadata and never count as installed kit skills.
validate_kits() {
  local f="$1" manifest="$2" lane role count skill record paths duplicates
  if [ ! -f "$f" ] ||
     ! jq -e '(.version == 2 or .version == 3) and (.lanes | type == "object")' "$f" >/dev/null 2>&1; then
    echo "SCOUT-KIT: missing or invalid structured lane kit: $f" >&2; return 7
  fi
  migrate_kit "$f" || { echo "SCOUT-KIT: legacy v2 kit could not migrate to trusted selected-skill records" >&2; return 7; }
  if [ ! -f "$manifest" ] ||
     ! jq -e '.lanes | type == "array"' "$manifest" >/dev/null 2>&1; then
    echo "SCOUT-KIT: invalid manifest: $manifest" >&2; return 7
  fi
  for lane in $(jq -r '.lanes[].name' "$manifest"); do
    for role in predefined specific; do
      count=$(jq -r --arg l "$lane" --arg r "$role" \
        '(.lanes[$l][$r] // []) | unique | length' "$f")
      if [ "$count" -lt 1 ] || [ "$count" -gt 2 ]; then
        echo "SCOUT-KIT: lane '$lane' needs 1-2 $role skills; found $count" >&2
        return 7
      fi
      for skill in $(armed_role "$f" "$lane" "$role"); do
        installed "$skill" || {
          echo "SCOUT-KIT: lane '$lane' references uninstalled $role skill '$skill'" >&2
          return 7
        }
      done
      while IFS= read -r record; do
        validate_selected_record "$record" || {
          echo "SCOUT-KIT: lane '$lane' has missing, unreadable, changed, or out-of-root selected $role skill path" >&2
          return 7
        }
      done < <(jq -c --arg l "$lane" --arg r "$role" '(.lanes[$l].selected[$r] // [])[]' "$f")
      count=$(jq -r --arg l "$lane" --arg r "$role" '(.lanes[$l].selected[$r] // []) | length' "$f")
      [ "$count" -eq "$(jq -r --arg l "$lane" --arg r "$role" '(.lanes[$l][$r] // []) | length' "$f")" ] || {
        echo "SCOUT-KIT: lane '$lane' selected $role records do not match armed skill ids" >&2; return 7;
      }
    done
    count=$(jq -r --arg l "$lane" '((.lanes[$l].predefined // []) + (.lanes[$l].specific // [])) | unique | length' "$f")
    if [ "$count" -gt 4 ]; then
      echo "SCOUT-KIT: lane '$lane' has inventory-dump kit ($count unique skills; max 4)" >&2
      return 7
    fi
    jq -e --arg l "$lane" '(.lanes[$l].github_suggestions // []) | type == "array"' "$f" >/dev/null || {
      echo "SCOUT-KIT: lane '$lane' has invalid GitHub suggestion metadata" >&2; return 7
    }
    paths=$(jq -r --arg l "$lane" '((.lanes[$l].selected.predefined // []) + (.lanes[$l].selected.specific // [])) | .[]?.path' "$f")
    duplicates=$(printf '%s\n' "$paths" | sed '/^$/d' | LC_ALL=C sort | uniq -d)
    [ -z "$duplicates" ] || { echo "SCOUT-KIT: lane '$lane' repeats selected skill path" >&2; return 7; }
  done
}

# lint FILE LANE PROMPT : every baked skill for LANE must appear in the prompt text.
lint() {
  local f="$1" lane="$2" prompt="$3" s miss=""
  [ -f "$prompt" ] || { echo "polylane-scout: no prompt file $prompt" >&2; return 5; }
  for s in $(armed "$f" "$lane"); do
    grep -qF "$s" "$prompt" || miss="$miss $s"
  done
  [ -z "$miss" ] && return 0
  echo "SCOUT-LINT: lane '$lane' prompt missing baked skill(s):$miss" >&2; return 5
}

if [ "${BASH_SOURCE[0]:-}" = "${0}" ]; then
  case "${1:-}" in
    domain)    shift; domain "$@" ;;
    suggest)   shift; suggest "${1:?usage: suggest <domain>}" ;;
    installed) shift; installed "${1:?usage: installed <skill>}" ;;
    resolve)   shift; resolve "${1:?usage: resolve <skill>}" ;;
    recommend) shift; recommend "${1:?usage: recommend <domain> <activity>}" "${2:?usage: recommend <domain> <activity>}" ;;
    record-outcome) shift; record_outcome "${1:?}" "${2:?}" "${3:?}" "${4:?}" "${5:?}" "${6:-}" ;;
    bake)      shift; bake "$@" ;;
    arm-role)  shift; arm_role "$@" ;;
    arm-recommendation) shift; arm_recommendation "${1:?}" "${2:?}" "${3:?}" "${4:?}" "${5:?}" ;;
    migrate)   shift; migrate_kit "${1:?usage: migrate <kit>}" ;;
    armed-role) shift; armed_role "${1:?}" "${2:?}" "${3:?}" ;;
    github)    shift; record_github "${1:?}" "${2:?}" "${3:?}" "${4:?}" ;;
    github-suggest) shift; github_suggest "${1:?usage: github-suggest <activity> [limit]}" "${2:-5}" ;;
    catalog-index) shift; catalog_helper index "${1:?}" ;;
    catalog-recommend) shift; catalog_helper recommend "${1:?}" "${2:?}" "${3:?}" ;;
    use-audit) shift; catalog_helper use-audit "${1:?}" "${2:?}" "${3:?}" "${4:?}" "${5:?}" ;;
    acquire) shift; acquire "${1:?}" "${2:?}" "${3:?}" "${4:?}" ;;
    arm-admitted) shift; arm_admitted "${1:?}" "${2:?}" "${3:?}" "${4:?}" "${5:?}" ;;
    validate)  shift; validate_kits "${1:?}" "${2:?}" ;;
    armed)     shift; armed "${1:?}" "${2:?}" ;;
    lint)      shift; lint "${1:?}" "${2:?}" "${3:?}" ;;
    *) echo "usage: polylane-scout.sh domain|suggest|installed|resolve|recommend|record-outcome|bake|arm-role|arm-recommendation|migrate|armed-role|github|github-suggest|catalog-index|catalog-recommend|use-audit|acquire|arm-admitted|validate|armed|lint ..." >&2; exit 2 ;;
  esac
fi
