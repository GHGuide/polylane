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

# arm_role FILE LANE ROLE SKILL... : write a strict, role-separated kit. Builders
# receive both a stable base kit and skills chosen specifically for their lane.
arm_role() {
  local f="$1" lane="$2" role="$3" arr tmp
  shift 3
  case "$role" in predefined|specific) ;; *)
    echo "polylane-scout: role must be predefined or specific" >&2; return 2 ;;
  esac
  command -v jq >/dev/null 2>&1 || { echo "polylane-scout: jq required" >&2; return 2; }
  arr=$(_installed_array "$@")
  mkdir -p "$(dirname "$f")" 2>/dev/null || true
  [ -f "$f" ] || echo '{"version":2,"lanes":{}}' > "$f"
  tmp="$f.tmp.$$"
  jq --arg l "$lane" --arg r "$role" --argjson v "$arr" '
    .version = 2
    | .lanes = (.lanes // {})
    | .lanes[$l] = (.lanes[$l] // {
        predefined: [], specific: [], github_suggestions: []
      })
    | .lanes[$l][$r] = $v
    | .lanes[$l].github_suggestions = (.lanes[$l].github_suggestions // [])
  ' "$f" > "$tmp" && mv "$tmp" "$f"
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

# validate_kits FILE MANIFEST : a strict orchestration contract for builders.
# GitHub suggestions are advisory metadata and never count as installed kit skills.
validate_kits() {
  local f="$1" manifest="$2" lane role count skill
  if [ ! -f "$f" ] ||
     ! jq -e '.version == 2 and (.lanes | type == "object")' "$f" >/dev/null 2>&1; then
    echo "SCOUT-KIT: missing or invalid structured lane kit: $f" >&2; return 7
  fi
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
    done
    count=$(jq -r --arg l "$lane" '((.lanes[$l].predefined // []) + (.lanes[$l].specific // [])) | unique | length' "$f")
    if [ "$count" -gt 4 ]; then
      echo "SCOUT-KIT: lane '$lane' has inventory-dump kit ($count unique skills; max 4)" >&2
      return 7
    fi
    jq -e --arg l "$lane" '(.lanes[$l].github_suggestions // []) | type == "array"' "$f" >/dev/null || {
      echo "SCOUT-KIT: lane '$lane' has invalid GitHub suggestion metadata" >&2; return 7
    }
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
    *) echo "usage: polylane-scout.sh domain|suggest|installed|resolve|recommend|record-outcome|bake|arm-role|armed-role|github|github-suggest|catalog-index|catalog-recommend|use-audit|acquire|arm-admitted|validate|armed|lint ..." >&2; exit 2 ;;
  esac
fi
