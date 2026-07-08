#!/usr/bin/env bash
#
# polylane-memory.sh <state-file> <cmd> [args...]
#
# The blackboard + HTN goal-tree for /polylane-max. One JSON state file persists
# across build cycles so the loop NEVER re-litigates a settled decision or repeats
# a failed approach, and always knows which sub-goal to attack next.
#
# State schema (.polylane/max-state.json):
#   { "ultimate": "<goal>",
#     "criteria":   [ {id,text,weight,status,score} ],           # success measures
#     "milestones": [ {id,text,subgoals:[ {id,text,weight,status,cycle,evidence} ]} ],
#     "log":        [ {cycle,kind,text,meta} ] }                  # decisions/learnings/attempts
#   status ∈ open | doing | done | blocked
#
# Commands:
#   init <ultimate>                 create the file (no-op if it already exists)
#   add-criterion  <id> <text> [w]  add a success criterion
#   add-milestone  <id> <text>      add a milestone
#   add-subgoal    <mid> <id> <text> [w]   add a sub-goal under milestone <mid>
#   set-status     <id> <status> [evidence] [cycle]   set a sub-goal OR criterion status
#   log <cycle> <kind> <text> [meta]   append to the blackboard (kind: decision|learning|attempt)
#   next                            print the highest-weight OPEN sub-goal ("<id>  <text>") or nothing
#   attempted <text>                exit 0 iff this approach is already in the log as an attempt
#   progress                        "subgoals: X/Y done · criteria: A/B done · N% "
#   met                             exit 0 iff every sub-goal AND criterion is done (goal reached)
#   dump                            human-readable state summary (for the digest / critic)
#
# bash-3.2 safe; all mutation via jq.

set -euo pipefail

F="${1:?usage: polylane-memory.sh <state-file> <cmd> [args]}"
CMD="${2:?usage: polylane-memory.sh <state-file> <cmd> [args]}"
shift 2

command -v jq >/dev/null 2>&1 || { echo "polylane-memory: jq required" >&2; exit 1; }

# _save : read jq program from stdin, apply to $F, write back atomically.
_save() { local tmp; tmp="$F.tmp.$$"; jq "$@" "$F" > "$tmp" && mv "$tmp" "$F"; }
_need() { [ -f "$F" ] || { echo "polylane-memory: no state at $F (run 'init' first)" >&2; exit 1; }; }

case "$CMD" in
  init)
    if [ -f "$F" ]; then echo "state exists: $F"; exit 0; fi
    mkdir -p "$(dirname "$F")" 2>/dev/null || true
    jq -n --arg u "${1:-}" '{ultimate:$u, criteria:[], milestones:[], log:[]}' > "$F"
    echo "initialized $F"
    ;;

  add-criterion)
    _need; _save --arg id "$1" --arg t "$2" --argjson w "${3:-1}" \
      '.criteria += [{id:$id,text:$t,weight:$w,status:"open",score:0}]'
    ;;

  add-milestone)
    _need; _save --arg id "$1" --arg t "$2" \
      '.milestones += [{id:$id,text:$t,subgoals:[]}]'
    ;;

  add-subgoal)
    _need; _save --arg mid "$1" --arg id "$2" --arg t "$3" --argjson w "${4:-1}" \
      '(.milestones[] | select(.id==$mid) | .subgoals) +=
         [{id:$id,text:$t,weight:$w,status:"open",cycle:null,evidence:""}]'
    ;;

  set-status)
    _need
    _save --arg id "$1" --arg s "$2" --arg ev "${3:-}" --argjson cy "${4:-null}" '
      (.milestones[].subgoals[] | select(.id==$id))
        |= (.status=$s | (if $ev!="" then .evidence=$ev else . end) | (if $cy!=null then .cycle=$cy else . end))
      | (.criteria[] | select(.id==$id)) |= (.status=$s)'
    ;;

  log)
    _need; _save --argjson cy "$1" --arg k "$2" --arg t "$3" --arg m "${4:-}" \
      '.log += [{cycle:$cy,kind:$k,text:$t,meta:$m}]'
    ;;

  next)
    _need
    jq -r '[.milestones[].subgoals[] | select(.status=="open")]
           | sort_by(-.weight) | .[0] // empty | "\(.id)  \(.text)"' "$F"
    ;;

  attempted)
    _need
    # exit 0 iff an attempt with this exact text already exists
    jq -e --arg t "$1" 'any(.log[]; .kind=="attempt" and .text==$t)' "$F" >/dev/null
    ;;

  progress)
    _need
    jq -r '
      ([.milestones[].subgoals[]] ) as $sg
      | ([.criteria[]]) as $cr
      | ($sg|length) as $sn | ($sg|map(select(.status=="done"))|length) as $sd
      | ($cr|length) as $cn | ($cr|map(select(.status=="done"))|length) as $cd
      | (if ($sn+$cn)==0 then 0 else (100*($sd+$cd)/($sn+$cn))|floor end) as $pct
      | "subgoals: \($sd)/\($sn) done · criteria: \($cd)/\($cn) done · \($pct)%"' "$F"
    ;;

  met)
    _need
    # goal reached iff there is at least one criterion AND every criterion + sub-goal is done
    jq -e '
      (([.criteria[]]|length) > 0)
      and (all(.criteria[]; .status=="done"))
      and (all(.milestones[].subgoals[]; .status=="done"))' "$F" >/dev/null
    ;;

  dump)
    _need
    jq -r '
      "ULTIMATE: \(.ultimate)\n",
      "CRITERIA:", (.criteria[] | "  [\(.status)] \(.id): \(.text)"),
      "\nGOAL TREE:",
      (.milestones[] | "  \(.id): \(.text)",
        (.subgoals[] | "    [\(.status)] \(.id) (w\(.weight)\(if .cycle then ", c\(.cycle)" else "" end)): \(.text)")),
      "\nRECENT LOG:", (.log[-8:][] | "  c\(.cycle) \(.kind): \(.text)")' "$F"
    ;;

  *)
    echo "polylane-memory: unknown command '$CMD'" >&2
    echo "  commands: init add-criterion add-milestone add-subgoal set-status log next attempted progress met dump" >&2
    exit 2
    ;;
esac
