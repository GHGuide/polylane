#!/usr/bin/env bash
# polylane-scout.sh — the MECHANICAL half of the per-lane skill scout. The doc
# (references/skill-scout.md) was pure LLM discretion: nothing inferred a lane's
# domain, checked a skill was installed, wrote lane-skills.json, or verified the
# picked skill actually landed in the prompt. This does all four deterministically;
# the orchestrator still makes the final call + handles GitHub discovery.
#   domain <glob>...            -> ui|api|data|mobile|report|test|unknown (from globs)
#   suggest <domain>            -> curated INSTALLED skills for that domain (space-sep)
#   installed <skill>           -> exit 0 iff the skill/plugin is installed
#   bake <file> <lane> <skill>. -> write lane-skills.json[lane] (only installed skills)
#   armed <file> <lane>         -> print the lane's baked skills
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

# installed SKILL : 0 iff a skill dir OR a plugin of that name exists. Reads
# CLAUDE_SKILLS_DIR at CALL time (not source time) so tests can point it at a fixture.
installed() {
  local s="${1%%:*}" dir="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"   # design:x -> design
  [ -d "$dir/$s" ] && return 0
  [ -d "$dir/$1" ] && return 0
  ls -d "$HOME"/.claude/plugins/*/"$s" >/dev/null 2>&1 && return 0
  ls -d "$HOME"/.claude/plugins/marketplaces/*"$s"* >/dev/null 2>&1 && return 0
  return 1
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
  # shellcheck disable=SC2086
  local arr; arr=$(printf '%s\n' $keep | jq -R . | jq -cs 'map(select(length>0))')
  local tmp="$f.tmp.$$"
  jq --arg l "$lane" --argjson v "$arr" '.[$l] = $v' "$f" > "$tmp" && mv "$tmp" "$f"
}

armed() { jq -r --arg l "$2" '.[$l] // [] | join(" ")' "$1" 2>/dev/null; }

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
    bake)      shift; bake "$@" ;;
    armed)     shift; armed "${1:?}" "${2:?}" ;;
    lint)      shift; lint "${1:?}" "${2:?}" "${3:?}" ;;
    *) echo "usage: polylane-scout.sh domain <glob>... | suggest <domain> | installed <skill> | bake <file> <lane> <skill>... | armed <file> <lane> | lint <file> <lane> <prompt>" >&2; exit 2 ;;
  esac
fi
