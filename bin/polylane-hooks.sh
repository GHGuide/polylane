#!/usr/bin/env bash
# polylane-hooks.sh — project-scoped lifecycle context and completion guard.
#
# The supervisor remains the runtime authority.  This helper never changes
# policy, permissions, files, or scheduling; it only returns hook JSON.
# Bash 3.2 + jq only.
set -u
LC_ALL=C
export LC_ALL

usage() {
  echo "usage: polylane-hooks.sh codex|claude SessionStart|PreCompact|PostCompact|Stop [--project PROJECT]" >&2
  echo "       polylane-hooks.sh locate" >&2
  echo "       polylane-hooks.sh render codex|claude" >&2
  exit 2
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  else return 1; fi
}

# resolve_safe PATH — print the canonical absolute path of an installed regular
# file, or fail.  A missing file, a symlinked leaf, a non-regular or
# non-executable target, or a path carrying quote/backslash characters (which
# would break safe quoting in a rendered shell command) is rejected before use.
resolve_safe() {
  local path=$1 dir base canon
  [ -e "$path" ] || return 3
  [ ! -L "$path" ] || return 3
  [ -f "$path" ] || return 3
  [ -x "$path" ] || return 3
  case "$path" in *\'*|*\"*|*\\*) return 3 ;; esac
  dir=$(cd "$(dirname "$path")" 2>/dev/null && pwd -P) || return 3
  base=$(basename "$path")
  canon="$dir/$base"
  [ ! -L "$canon" ] || return 3
  printf '%s\n' "$canon"
}

# do_locate — resolve and print the actual installed helper (this script).  The
# supervisor and both provider fragments use this single locator; there is no
# duplicated per-hook path logic.
do_locate() {
  resolve_safe "$0"
}

# do_render PROVIDER — emit a project-scoped hook fragment whose commands invoke
# the exact installed helper by absolute path, with its sha256 recorded as
# provenance.  Reads the shipped template beside this helper; never edits global
# settings and never infers trust.  Fails safely when the helper or template is
# unsafe or absent.
do_render() {
  local provider=$1 self selfdir tpl field sum
  case "$provider" in claude) field=_comment ;; codex) field=description ;; *) usage ;; esac
  command -v jq >/dev/null 2>&1 || { echo "polylane-hooks: jq is required to render" >&2; return 3; }
  self=$(resolve_safe "$0") || { echo "polylane-hooks: cannot resolve a safe installed helper" >&2; return 3; }
  selfdir=$(dirname "$self")
  tpl="$selfdir/../assets/hooks/$provider-settings.json"
  [ "$provider" = codex ] && tpl="$selfdir/../assets/hooks/codex-hooks.json"
  [ -f "$tpl" ] || { echo "polylane-hooks: hook template missing: $tpl" >&2; return 3; }
  sum=$(sha256_of "$self") || { echo "polylane-hooks: no SHA-256 command available" >&2; return 3; }
  jq --arg h "$self" --arg c "$sum" --arg field "$field" '
    def subst: if type == "string" then gsub("__POLYLANE_HOOKS_HELPER__"; $h) else . end;
    walk(subst)
    | .[$field] = ((.[$field] // "")
        + " | POLYLANE-RENDERED helper=" + $h + " sha256=" + $c
        + " (review before trusting; global settings unchanged)")
  ' "$tpl"
}

case "${1:-}" in
  locate) do_locate; exit $? ;;
  render) do_render "${2:-}"; exit $? ;;
esac

provider=${1:-}
event=${2:-}
[ $# -ge 2 ] || usage
shift 2
project=${POLYLANE_PROJECT_ROOT:-.}
while [ $# -gt 0 ]; do
  case "$1" in
    --project) [ $# -ge 2 ] || usage; project=$2; shift 2 ;;
    *) usage ;;
  esac
done
case "$provider" in codex|claude) ;; *) usage ;; esac
case "$event" in SessionStart|PreCompact|PostCompact|Stop) ;; *) usage ;; esac

emit_restore() {
  local context=$1 diagnostic=${2:-} output
  if [ "$event" = SessionStart ]; then
    output=$(jq -cn --arg event "$event" --arg context "$context" --arg diagnostic "$diagnostic" \
      '{continue:true,hookSpecificOutput:{hookEventName:$event,additionalContext:$context}} + (if $diagnostic == "" then {} else {systemMessage:$diagnostic} end)')
  else
    output=$(jq -cn --arg context "$context" --arg diagnostic "$diagnostic" \
      '{continue:true} + (if $context == "" then {} else {systemMessage:$context} end) + (if $diagnostic == "" then {} else {systemMessage:$diagnostic} end)')
  fi
  printf '%s\n' "$output"
}

emit_stop() {
  local decision=$1 reason=${2:-} diagnostic=${3:-} output
  if [ "$decision" = allow ]; then
    output=$(jq -cn --arg diagnostic "$diagnostic" \
      '{continue:true} + (if $diagnostic == "" then {} else {systemMessage:$diagnostic} end)')
  else
    output=$(jq -cn --arg reason "$reason" --arg diagnostic "$diagnostic" \
      '{decision:"block",reason:$reason} + (if $diagnostic == "" then {} else {systemMessage:$diagnostic} end)')
  fi
  printf '%s\n' "$output"
}

valid_name() {
  printf '%s' "$1" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*$'
}

valid_uint() {
  case "$1" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac
}

payload=$(cat 2>/dev/null || true)
if ! printf '%s' "$payload" | jq -e 'type == "object"' >/dev/null 2>&1; then
  if [ "$event" = Stop ]; then
    emit_stop allow '' 'polylane-hooks: invalid lifecycle JSON; failing open for supervisor recovery'
  else
    emit_restore '' 'polylane-hooks: invalid lifecycle JSON; no context restored'
  fi
  exit 0
fi

if [ ! -d "$project" ]; then
  if [ "$event" = Stop ]; then
    emit_stop allow '' 'polylane-hooks: project state unavailable; failing open for supervisor recovery'
  else
    emit_restore '' 'polylane-hooks: project state unavailable; no context restored'
  fi
  exit 0
fi
project=$(cd "$project" && pwd -P)

if [ "$event" = Stop ]; then
  run_id=$(printf '%s' "$payload" | jq -r '.run_id // ""')
  [ -n "$run_id" ] || run_id=$(jq -r '.run_id // ""' "$project/.polylane/run.json" 2>/dev/null || true)
  [ -n "$run_id" ] || run_id=$(jq -r '.run_id // ""' "$project/docs/polylane/run-stats.json" 2>/dev/null || true)
  lane=$(printf '%s' "$payload" | jq -r '.lane // .worker // ""')
  [ -n "$lane" ] || lane=${POLYLANE_WORKER_ID:-}
  active=$(printf '%s' "$payload" | jq -r '.stop_hook_active // false')
  if ! valid_name "$run_id" || ! valid_name "$lane"; then
    emit_stop allow '' 'polylane-hooks: run_id or lane unavailable; failing open for supervisor recovery'
    exit 0
  fi
  status="$project/docs/status-$lane.md"
  evidence="$project/docs/verify-$lane.md"
  [ "$lane" = integrator ] && evidence="$project/docs/verify-integration.md"
  marker="STATUS: $lane DONE run=$run_id"
  if [ -f "$status" ] && [ -s "$evidence" ] && \
     IFS= read -r first < "$status" && [ "$first" = "$marker" ] && \
     grep -qF "run=$run_id" "$evidence"; then
    emit_stop allow
    exit 0
  fi
  if [ "$active" = true ]; then
    emit_stop allow '' 'polylane-hooks: continuation already active; allow runner to recover without a stop loop'
    exit 0
  fi
  emit_stop block "Polylane completion evidence is incomplete: write the exact current-run marker '$marker' and run-tagged verification evidence before stopping. Request one focused continuation; the supervisor remains runtime authority."
  exit 0
fi

state="$project/.polylane/lifecycle-hooks.json"
if [ ! -s "$state" ] || ! jq -e '
  type == "object"
  and (.memory_brief | type == "string")
  and (.north_star | type == "string")
  and (.settled_decisions | type == "array" and all(.[]; type == "string"))
  and ((.byte_cap // 4096) | type == "number" and floor == . and . >= 64)
' "$state" >/dev/null 2>&1; then
  emit_restore '' 'polylane-hooks: lifecycle state unavailable or invalid; no context restored'
  exit 0
fi

state_cap=$(jq -r '.byte_cap // 4096' "$state")
configured_cap=${POLYLANE_HOOK_MAX_BYTES:-4096}
valid_uint "$configured_cap" || configured_cap=4096
[ "$configured_cap" -gt 0 ] || configured_cap=4096
cap=$state_cap
[ "$cap" -le "$configured_cap" ] || cap=$configured_cap
[ "$cap" -le 4096 ] || cap=4096

brief=$(jq -r '.memory_brief' "$state")
north=$(jq -r '.north_star' "$state")
decisions=$(jq -r '.settled_decisions[]' "$state" | awk 'BEGIN { ORS="" } { if (NR > 1) printf " | "; printf "%s", $0 }')
context="[memory-brief] $brief
[north-star] $north
[settled-decisions] $decisions"
bytes=$(printf '%s' "$context" | wc -c | tr -d ' ')
if [ "$bytes" -gt "$cap" ]; then
  context=$(printf '%s' "$context" | cut -c 1-"$cap")
fi
emit_restore "$context"
