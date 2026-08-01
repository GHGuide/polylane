#!/usr/bin/env bash
# polylane-cycle.sh — deterministic guard for the boundary between build cycles.
# The LLM chooses product direction; this script prevents it from silently skipping
# state reconciliation, durable artifacts, the next executable route, or the exact
# 30-item post-goal suggestion contract.
#
#   route <state>
#   progress <state> <cycle> [output]
#   reconcile <state> <cycle>
#   artifacts <project-root> <cycle> <state>
#   suggestions <file>
#   runtime <manifest> [wait-seconds]
#
# Exit codes: 5 incomplete acceptance, 6 dead-end, 7 missing cycle artifact,
# 8 invalid suggestion packet, 9 runtime is not a live tmux-supervised run.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
MEM="$SCRIPT_DIR/polylane-memory.sh"

need_jq() { command -v jq >/dev/null 2>&1 || { echo "polylane-cycle: jq required" >&2; exit 2; }; }
need_state() {
  [ -f "$1" ] || { echo "polylane-cycle: state missing: $1" >&2; exit 2; }
  jq -e . "$1" >/dev/null 2>&1 || { echo "polylane-cycle: invalid state JSON: $1" >&2; exit 2; }
}

route() {
  local state="$1" next external blocked open_criteria
  need_state "$state"
  if "$MEM" "$state" met >/dev/null 2>&1; then
    echo "COMPLETE"
    return 0
  fi
  next=$("$MEM" "$state" next)
  if [ -n "$next" ]; then
    echo "CONTINUE $next"
    return 0
  fi
  external=$(jq -r '[.milestones[].subgoals[] | select(.status=="external") | "\(.id): \(.text)"] | join("; ")' "$state")
  blocked=$(jq -r '[.milestones[].subgoals[] | select(.status=="blocked") | "\(.id): \(.text)"] | join("; ")' "$state")
  open_criteria=$(jq '[.criteria[] | select(.status!="done")] | length' "$state")
  if [ -n "$external" ] || [ -n "$blocked" ]; then
    printf 'NEEDS-USER'
    [ -n "$external" ] && printf ' external=[%s]' "$external"
    [ -n "$blocked" ] && printf ' blocked=[%s]' "$blocked"
    printf '\n'
    return 0
  fi
  if [ "$open_criteria" -gt 0 ]; then
    echo "DEAD-END: criteria remain open but no autonomous or external subgoal is routable" >&2
    return 6
  fi
  echo "INCOMPLETE: statuses look done but frozen acceptance or shippability evidence is missing" >&2
  return 5
}

write_progress() {
  local state="$1" cycle="$2" out tmp route_text
  out="${3:-$(dirname "$state")/progress.md}"
  need_state "$state"
  route_text=$(route "$state" 2>&1 || true)
  tmp="$out.tmp.$$"
  mkdir -p "$(dirname "$out")"
  {
    echo "# Polylane progress"
    echo
    echo "Generated mechanically from \`max-state.json\`. Conversation summaries are not authoritative."
    echo
    echo "## Cycle $cycle"
    echo
    "$MEM" "$state" progress
    echo
    echo "**Route:** \`$route_text\`"
    echo
    echo "## Open autonomous work"
    echo
    jq -r '[.milestones[].subgoals[] | select(.status=="open" or .status=="doing")]
      | if length==0 then "- None" else .[] | "- `\(.id)` [\(.status), w\(.weight)] — \(.text)" end' "$state"
    echo
    echo "## External/user evidence"
    echo
    jq -r '[.milestones[].subgoals[] | select(.status=="external")]
      | if length==0 then "- None" else .[] | "- `\(.id)` — \(.text)\(if .evidence!="" then " — \(.evidence)" else "" end)" end' "$state"
    echo
    echo "## Blocked"
    echo
    jq -r '[.milestones[].subgoals[] | select(.status=="blocked")]
      | if length==0 then "- None" else .[] | "- `\(.id)` — \(.text)\(if .evidence!="" then " — \(.evidence)" else "" end)" end' "$state"
    echo
    echo "## Criteria"
    echo
    jq -r '.criteria[] | "- `\(.id)` [\(.status)] — \(.text)"' "$state"
    echo
    echo "## Acceptance checks"
    echo
    jq -r '(.accept // []) as $a
      | "- Total: \($a|length)",
        "- Pass: \([$a[]|select(.status=="pass")]|length)",
        "- Fail: \([$a[]|select(.status=="fail")]|length)",
        "- Unchecked: \([$a[]|select(.status=="unchecked")]|length)",
        ($a[] | select(.status!="pass") | "  - `\(.sid)` [\(.status)] — \(.cmd)")' "$state"
  } > "$tmp"
  mv "$tmp" "$out"
  echo "$out"
}

reconcile() {
  local state="$1" cycle="$2" targets="${3:-}" rc=0 open_count
  need_state "$state"
  if [ -n "$targets" ]; then
    "$MEM" "$state" check-accept --cycle "$cycle" --targets "$targets" --focused || rc=$?
  else
    "$MEM" "$state" check-accept --cycle "$cycle" || rc=$?
  fi
  open_count=$(jq '[.milestones[].subgoals[] | select(.status=="open" or .status=="doing")] | length' "$state")
  if [ "$open_count" = "0" ]; then
    "$MEM" "$state" check-accept --cycle "$cycle" --only-terminal || rc=$?
  fi
  write_progress "$state" "$cycle" >/dev/null
  # A check may fail because the corresponding work remains open; that is a
  # continuation signal, but no check may remain silently unchecked after a
  # full reconciliation.
  if [ "$open_count" = "0" ] &&
     jq -e 'any((.accept // [])[]; .status=="unchecked")' "$state" >/dev/null; then
    echo "CYCLE-GATE: acceptance reconciliation left unchecked checks" >&2
    return 5
  fi
  if [ -n "$targets" ] &&
     jq -e --arg targets ",$targets," '
       any((.accept // [])[];
         (.tier // "focused")!="terminal"
         and (.sid as $sid | $targets | contains("," + $sid + ","))
         and .status=="unchecked")
     ' "$state" >/dev/null; then
    echo "CYCLE-GATE: targeted focused acceptance remained unchecked" >&2
    return 5
  fi
  return "$rc"
}

artifacts() {
  local root="$1" cycle="$2" state="$3" dir kind missing="" r next
  dir="$root/docs/polylane"
  need_state "$state"
  for kind in digest research council questions; do
    [ -s "$dir/cycle-$cycle-$kind.md" ] || missing="$missing cycle-$cycle-$kind.md"
  done
  [ -s "$dir/progress.md" ] || missing="$missing progress.md"
  [ -s "$dir/INDEX.md" ] || missing="$missing INDEX.md"
  r=$(route "$state" 2>&1 || true)
  case "$r" in
    CONTINUE*)
      next=$((cycle + 1))
      [ -s "$dir/cycle-$next-plan.md" ] || missing="$missing cycle-$next-plan.md"
      ;;
  esac
  if [ -n "$missing" ]; then
    echo "CYCLE-ARTIFACTS: missing:$missing" >&2
    return 7
  fi
  echo "CYCLE-ARTIFACTS: complete cycle=$cycle"
}

suggestions() {
  local f="$1" n
  [ -s "$f" ] || { echo "SUGGESTIONS: missing $f" >&2; return 8; }
  n=$(grep -cE '^[[:space:]]*[-*][[:space:]]+[^[:space:]]' "$f" || true)
  if [ "$n" -ne 30 ]; then
    echo "SUGGESTIONS: expected exactly 30 bullets, found $n" >&2
    return 8
  fi
  echo "SUGGESTIONS: exactly 30"
}

runtime() {
  local manifest="$1" wait_s="${2:-15}" start now json
  [ -f "$manifest" ] || { echo "RUNTIME: manifest missing: $manifest" >&2; return 9; }
  start=$(date +%s)
  while :; do
    json=$("$SCRIPT_DIR/polylane-state.sh" "$manifest" --json 2>/dev/null || echo '{}')
    if [ "$(printf '%s' "$json" | jq -r '.runner // "dead"')" = "alive" ] &&
       [ "$(printf '%s' "$json" | jq -r '.watch // "-"')" != "-" ]; then
      printf '%s\n' "$(printf '%s' "$json" | jq -r '.watch')"
      return 0
    fi
    now=$(date +%s)
    [ "$((now - start))" -lt "$wait_s" ] || break
    sleep 1
  done
  echo "RUNTIME: Polylane is not running through a live tmux-supervised CLI session" >&2
  return 9
}

need_jq
case "${1:-}" in
  route)       shift; route "${1:?usage: route <state>}" ;;
  progress)    shift; write_progress "${1:?state}" "${2:?cycle}" "${3:-}" ;;
  reconcile)   shift; reconcile "${1:?state}" "${2:?cycle}" "${3:-}" ;;
  artifacts)   shift; artifacts "${1:?project-root}" "${2:?cycle}" "${3:?state}" ;;
  suggestions) shift; suggestions "${1:?file}" ;;
  runtime)     shift; runtime "${1:?manifest}" "${2:-15}" ;;
  *) echo "usage: polylane-cycle.sh route|progress|reconcile|artifacts|suggestions|runtime ..." >&2; exit 2 ;;
esac
