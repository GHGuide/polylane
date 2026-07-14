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
#   met                             exit 0 iff every sub-goal AND criterion done AND every acceptance check passing
#   add-accept   <sid> <cmd> [dep-glob...]   register a FROZEN acceptance command for <sid>
#                                    (refused once done; dep-globs enable content-hash memoization)
#   check-accept [--cycle N]        run every registered command (cached if deps unchanged);
#                                    stamp pass|fail; --cycle records the cycle a pass->fail broke
#   unmet-accept                    list every acceptance check not currently "pass"
#   regressions                     list checks that went pass->fail, naming the cycle (temporal guard)
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
    if [ "$tries" -ge 50 ]; then
      # stale lock (crashed writer): reclaim, but break ONLY if THIS process actually
      # re-acquired it — else every waiter breaks together and races the RMW (lost
      # updates). The loser resets and keeps spinning until it wins the dir.
      rmdir "$lock" 2>/dev/null || true
      if mkdir "$lock" 2>/dev/null; then break; else tries=0; fi
    fi
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

# _accept_run CMD : run CMD (bash -c) in the CURRENT dir with a wall-clock cap.
# Uses timeout/gtimeout when present; otherwise runs uncapped (never wedges the
# verb — a hung check is the check author's bug, surfaced by the orchestrator).
_accept_run() {
  local cmd="$1" to="${POLYLANE_ACCEPT_TIMEOUT:-60}" t=""
  command -v timeout  >/dev/null 2>&1 && t=timeout
  [ -z "$t" ] && command -v gtimeout >/dev/null 2>&1 && t=gtimeout
  if [ -n "$t" ]; then "$t" "$to" bash -c "$cmd" >/dev/null 2>&1
  else bash -c "$cmd" >/dev/null 2>&1; fi
}

# _fingerprint GLOB... : deterministic content hash of every existing file matching
# the globs (sorted). git hash-object when available (content, not mtime — a no-op
# `touch` does NOT invalidate); falls back to a size+cksum digest. Empty match -> "".
_fingerprint() {
  local files f h out=""
  files=$(ls -1d "$@" 2>/dev/null | sort || true)
  [ -z "$files" ] && { printf ''; return 0; }
  if command -v git >/dev/null 2>&1 && git rev-parse >/dev/null 2>&1; then
    for f in $files; do [ -f "$f" ] && h=$(git hash-object "$f" 2>/dev/null) && out="$out$h"; done
  else
    for f in $files; do [ -f "$f" ] && out="$out$(cksum < "$f" 2>/dev/null)"; done
  fi
  printf '%s' "$out" | cksum | awk '{print $1}'
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
    # goal reached iff >=1 criterion AND every criterion + sub-goal done AND every
    # pre-registered acceptance check passing (absent .accept -> vacuously satisfied).
    jq -e '
      (([.criteria[]]|length) > 0)
      and (all(.criteria[]; .status=="done"))
      and (all(.milestones[].subgoals[]; .status=="done"))
      and (all((.accept // [])[]; .status=="pass"))' "$F" >/dev/null
    ;;

  add-accept)
    _need
    jq -e --arg id "$1" 'any(.milestones[].subgoals[]; .id==$id)' "$F" >/dev/null \
      || { echo "polylane-memory: no sub-goal with id '$1'" >&2; exit 1; }
    # FROZEN-BEFORE-BUILD: the grader must be registered while the sub-goal is still
    # open, so the builder cannot author its own weaker success bar after the fact.
    jq -e --arg id "$1" 'any(.milestones[].subgoals[]; .id==$id and .status=="done")' "$F" >/dev/null \
      && { echo "polylane-memory: sub-goal '$1' already done — acceptance must be registered BEFORE the build" >&2; exit 1; }
    _sid="$1"; _cmd="${2:?usage: add-accept <sid> <cmd> [dep-glob...]}"; shift 2
    # remaining args are dependency globs the check GRADES; content-hash of these
    # gates memoization. No deps -> always re-run (backward-compatible).
    _deps="[]"; if [ "$#" -gt 0 ]; then _deps=$(printf '%s\n' "$@" | jq -R . | jq -cs .); fi
    _save --arg sid "$_sid" --arg cmd "$_cmd" --argjson deps "$_deps" \
      '.accept = ((.accept // []) + [{sid:$sid, cmd:$cmd, status:"unchecked", deps:$deps, fp:"", regressed_cycle:null}])'
    ;;

  check-accept)
    _need
    # optional --cycle N stamps regressed_cycle on a pass->fail transition
    _cyc="null"
    [ "${1:-}" = "--cycle" ] && { _cyc="${2:?--cycle needs N}"; shift 2; }
    _n=$(jq '.accept // [] | length' "$F")
    [ "$_n" = "0" ] && { echo "check-accept: no acceptance checks registered"; exit 0; }
    _rows="["; _i=0
    while [ "$_i" -lt "$_n" ]; do
      _cmd=$(jq -r ".accept[$_i].cmd" "$F")
      _prev=$(jq -r ".accept[$_i].status // \"unchecked\"" "$F")
      _rc=$(jq -r ".accept[$_i].regressed_cycle // \"null\"" "$F")
      # --- #4 memoization: skip a passing check whose graded files are byte-identical
      _deps=$(jq -r ".accept[$_i].deps // [] | join(\" \")" "$F")
      _oldfp=$(jq -r ".accept[$_i].fp // \"\"" "$F")
      _newfp=""
      if [ -n "$_deps" ]; then _newfp=$(_fingerprint $_deps); fi
      # memoization is OFF by default: a check often reads files outside its declared
      # deps, so a byte-identical dep-set can falsely cache a pass over now-broken work
      # (invisible to `met`). Correctness first; opt in with POLYLANE_ACCEPT_MEMO=1 only
      # when a check provably reads ONLY its deps and re-running is measurably costly.
      if [ "${POLYLANE_ACCEPT_MEMO:-0}" = "1" ] && [ "$_prev" = "pass" ] && [ -n "$_deps" ] && [ -n "$_newfp" ] && [ "$_newfp" = "$_oldfp" ]; then
        _st="pass"                                   # cached: command never runs
        printf 'check-accept[%s]: pass (cached)\n' "$_i" >&2
      else
        if _accept_run "$_cmd"; then _st="pass"; else _st="fail"; fi
      fi
      # --- #3 temporal guard: first pass->fail flip records the cycle it broke. Stamp
      # even without --cycle (use "?") so a cycle-less call still surfaces the regression.
      if [ "$_prev" = "pass" ] && [ "$_st" = "fail" ] && [ "$_rc" = "null" ]; then
        [ "$_cyc" != "null" ] && _rc="$_cyc" || _rc="\"?\""
      fi
      [ "$_st" = "pass" ] && _rc="null"              # a re-pass clears the regression stamp
      [ "$_i" -gt 0 ] && _rows="$_rows,"
      _rows="$_rows{\"status\":\"$_st\",\"regressed_cycle\":$_rc,\"fp\":\"$_newfp\"}"
      _i=$((_i + 1))
    done
    _rows="$_rows]"
    # `$u[$i] // {}`: if a concurrent add-accept grew .accept past what we snapshotted,
    # the extra entries merge nothing (stay unchanged) instead of writing status:null.
    _save --argjson u "$_rows" \
      '.accept |= [ range(0; length) as $i | .[$i] + ($u[$i] // {}) ]'
    jq -e 'all((.accept // [])[]; .status=="pass")' "$F" >/dev/null
    ;;

  unmet-accept)
    _need
    jq -r '(.accept // []) | map(select(.status!="pass")) | .[] | "\(.sid): \(.cmd) [\(.status)]"' "$F"
    ;;

  regressions)
    _need
    # every check currently failing that previously passed, naming the cycle it broke.
    # Non-empty output = a temporal seam the (spatial) seam scanner cannot see -> the
    # promote gate treats it as an auto-NO-GO / revert.
    jq -r '(.accept // [])
      | map(select(.status!="pass" and (.regressed_cycle // null) != null))
      | .[] | "REGRESSED c\(.regressed_cycle): \(.sid): \(.cmd)"' "$F"
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
    echo "  commands: init add-criterion add-milestone add-subgoal set-status set-weight log next attempted progress met add-accept check-accept unmet-accept regressions brief resume dump" >&2
    exit 2
    ;;
esac
