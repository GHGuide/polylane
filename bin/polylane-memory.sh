#!/usr/bin/env bash
#
# polylane-memory.sh <state-file> <cmd> [args...]
#
# The blackboard + HTN goal-tree for /polylane (the loop). One JSON state file persists
# across build cycles so the loop NEVER re-litigates a settled decision or repeats
# a failed approach, and always knows which sub-goal to attack next.
#
# State schema (docs/polylane/max-state.json — durable, survives cleanup):
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
#   set-weight     <id> <w|top>     set a sub-goal's weight; "top" = current max + 1
#                                    (so `next` returns it — the Phase-4 council's focus lever)
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

# _save : apply a jq program to $F and write back. mkdir is atomic on all POSIX
# filesystems, so it serializes the read-modify-write against a concurrent writer
# (no lost updates); the final mv is atomic (no torn/corrupt file). A stale lock
# from a crashed writer is reclaimed after a short wait so a run never wedges.
_save() {
  local tmp lock="$F.lock" tries=0 rc
  while ! mkdir "$lock" 2>/dev/null; do
    tries=$((tries + 1))
    [ "$tries" -ge 50 ] && { rmdir "$lock" 2>/dev/null || true; mkdir "$lock" 2>/dev/null || true; break; }
    sleep 0.1 2>/dev/null || sleep 1
  done
  tmp="$F.tmp.$$"
  jq "$@" "$F" > "$tmp" && mv "$tmp" "$F"; rc=$?
  rmdir "$lock" 2>/dev/null || true
  return $rc
}
_need() {
  [ -f "$F" ] || { echo "polylane-memory: no state at $F (run 'init' first)" >&2; exit 1; }
  # a truncated/corrupt state file otherwise leaks a raw jq parse error mid-command;
  # catch it once, up front, with an actionable message.
  jq -e . "$F" >/dev/null 2>&1 || { echo "polylane-memory: state at $F is not valid JSON (corrupt/truncated) — restore from git or re-init" >&2; exit 1; }
}

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
    _need
    # fail loud if the milestone doesn't exist — else the sub-goal is silently dropped
    # and the loop mis-tracks progress (a typo'd milestone id = lost work).
    jq -e --arg mid "$1" 'any(.milestones[]; .id==$mid)' "$F" >/dev/null \
      || { echo "polylane-memory: no milestone '$1' (add-milestone first)" >&2; exit 1; }
    _save --arg mid "$1" --arg id "$2" --arg t "$3" --argjson w "${4:-1}" \
      '(.milestones[] | select(.id==$mid) | .subgoals) +=
         [{id:$id,text:$t,weight:$w,status:"open",cycle:null,evidence:""}]'
    ;;

  set-status)
    _need
    # fail loud if the id matches no sub-goal AND no criterion — a silent no-op here
    # means the tree never reaches `met` and the loop can't terminate (typo'd id).
    jq -e --arg id "$1" 'any(.milestones[].subgoals[]; .id==$id) or any(.criteria[]; .id==$id)' "$F" >/dev/null \
      || { echo "polylane-memory: no sub-goal or criterion with id '$1'" >&2; exit 1; }
    _save --arg id "$1" --arg s "$2" --arg ev "${3:-}" --argjson cy "${4:-null}" '
      (.milestones[].subgoals[] | select(.id==$id))
        |= (.status=$s | (if $ev!="" then .evidence=$ev else . end) | (if $cy!=null then .cycle=$cy else . end))
      | (.criteria[] | select(.id==$id)) |= (.status=$s)'
    ;;

  set-weight)
    _need
    # fail loud on a typo'd id — a silent no-op means the council's chosen focus never
    # gets elevated and `next` returns the wrong sub-goal (loop works the wrong thing).
    jq -e --arg id "$1" 'any(.milestones[].subgoals[]; .id==$id)' "$F" >/dev/null \
      || { echo "polylane-memory: no sub-goal with id '$1'" >&2; exit 1; }
    if [ "${2:-}" = "top" ]; then
      _save --arg id "$1" '
        ([.milestones[].subgoals[].weight] | max // 0) as $mx
        | (.milestones[].subgoals[] | select(.id==$id)) |= (.weight = ($mx + 1))'
    else
      _save --arg id "$1" --argjson w "${2:?usage: set-weight <id> <w|top>}" '
        (.milestones[].subgoals[] | select(.id==$id)) |= (.weight = $w)'
    fi
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

  brief)
    # Compact resume brief (~a few lines) — the CONTEXT-COMPACTION primitive. Each
    # cycle reads THIS from disk instead of carrying the whole conversation, so a
    # long loop stays context-bounded. Everything needed to resume: goal, progress,
    # next target, open criteria, blocked items, and the last few log entries.
    _need
    jq -r '
      ([.milestones[].subgoals[]]) as $sg
      | ([.criteria[]]) as $cr
      | ($sg|length) as $sn | ($sg|map(select(.status=="done"))|length) as $sd
      | ($cr|length) as $cn | ($cr|map(select(.status=="done"))|length) as $cd
      | ($sg|map(select(.status=="open"))|sort_by(-.weight)|.[0]) as $next
      | "GOAL: \(.ultimate)",
        "PROGRESS: subgoals \($sd)/\($sn) · criteria \($cd)/\($cn)",
        "NEXT: \(if $next then "\($next.id) — \($next.text)" else "(no open sub-goal)" end)",
        "OPEN CRITERIA:", (($cr[]|select(.status!="done")|"  - \(.id): \(.text)") // "  (none)"),
        "BLOCKED:", (($sg[]|select(.status=="blocked")|"  - \(.id): \(.text)") // "  (none)"),
        "RECENT:", (.log[-6:][]|"  c\(.cycle) \(.kind): \(.text)")' "$F"
    ;;

  resume)
    # Full rehydration packet — read after a dead/compacted conversation to CONTINUE
    # the loop from disk with zero prior context: which cycle, what's done, every open
    # sub-goal/criterion, blocked items, recent decisions, and the next action. This is
    # what makes the max loop durable — the conversation can die and resume from here.
    _need
    jq -r '
      ([.milestones[].subgoals[]]) as $sg
      | ([.criteria[]]) as $cr
      | ($sg|length) as $sn | ($sg|map(select(.status=="done"))|length) as $sd
      | ($cr|length) as $cn | ($cr|map(select(.status=="done"))|length) as $cd
      | ($sg|map(select(.status=="open"))|sort_by(-.weight)) as $open
      | (([.log[].cycle]|max) // 0) as $cyc
      | "=== POLYLANE-MAX RESUME ===",
        "GOAL: \(.ultimate)",
        "CYCLE: \($cyc)",
        "PROGRESS: subgoals \($sd)/\($sn) · criteria \($cd)/\($cn)",
        "OPEN SUBGOALS (by weight):", (($open[]|"  - \(.id) (w\(.weight)): \(.text)") // "  (none — check criteria)"),
        "OPEN CRITERIA:", (([$cr[]|select(.status!="done")]|if length>0 then (.[]|"  - \(.id): \(.text)") else "  (none)" end)),
        "BLOCKED:", (([$sg[]|select(.status=="blocked")]|if length>0 then (.[]|"  - \(.id): \(.text)") else "  (none)" end)),
        "RECENT LOG:", (.log[-8:][]|"  c\(.cycle) \(.kind): \(.text)"),
        "NEXT ACTION: resume at cycle \($cyc+1) — build the highest-weight open sub-goal; if none open and all criteria done, finalize and STOP."' "$F"
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
    echo "  commands: init add-criterion add-milestone add-subgoal set-status set-weight log next attempted progress met brief resume dump" >&2
    exit 2
    ;;
esac
