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
#   status ∈ open | doing | done | external | blocked
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
#   add-accept   <sid> <cmd> [--tier focused|terminal] [--evidence-kind autonomous|external] [--key safe-id] [dep-glob...]
#                                    register a FROZEN acceptance command for <sid>
#                                    (refused once done; dep-globs enable content-hash memoization)
#   tag-accept   <sid> [--tier focused|terminal] --key <safe-id>
#                                    tag matching frozen checks without changing commands
#   check-accept [--cycle N] [--targets a,b --focused | --only-terminal]
#                                    run selected registered commands;
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

# _accept_failure_evidence CMD RC OUTPUT TAIL_LINES : write a bounded, atomic,
# nonce-scoped JSON record only when the runner supplied a canonical root. The
# command/output travel through jq as data, never through executable syntax.
_accept_failure_evidence() {
  local cmd="$1" rc="$2" out="$3" tail_lines="$4" root run phase dir f tmp record when
  root="${POLYLANE_ACCEPT_FAILURE_ROOT:-}"
  run="${POLYLANE_ACCEPT_FAILURE_RUN_ID:-}"
  phase="${POLYLANE_ACCEPT_FAILURE_PHASE:-}"
  case "$root" in /*) : ;; *) return 0 ;; esac
  case "$run" in ''|*[!A-Za-z0-9._-]*) return 0 ;; esac
  case "$phase" in ''|*[!A-Za-z0-9._-]*) return 0 ;; esac
  dir="$root/docs/polylane/host-gate-failures"
  mkdir -p "$dir" 2>/dev/null || return 0
  f="$dir/$run.acceptance.jsonl"
  [ ! -e "$f" ] || { [ -f "$f" ] && [ ! -L "$f" ]; } || return 0
  when=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo '?')
  record=$(tail -n "$tail_lines" "$out" | jq -Rsc \
    --arg run "$run" --arg phase "$phase" --arg command "$cmd" --arg when "$when" --argjson rc "$rc" \
    '{run:$run,phase:$phase,command:$command,return_code:$rc,timestamp:$when,output_tail:.}') || return 0
  tmp=$(mktemp "$dir/.$run.acceptance.XXXXXX") || return 0
  if [ -f "$f" ] && [ ! -L "$f" ] &&
     jq -e --arg run "$run" 'type == "array" and all(.[]; .run == $run)' "$f" >/dev/null 2>&1; then
    jq --argjson record "$record" '. + [$record]' "$f" > "$tmp" || { rm -f "$tmp"; return 0; }
  else
    jq -n --argjson record "$record" '[$record]' > "$tmp" || { rm -f "$tmp"; return 0; }
  fi
  mv "$tmp" "$f" 2>/dev/null || rm -f "$tmp"
}

# _accept_clear_failure_evidence : a fresh top-level phase supersedes only its
# own current-run diagnostics.  Preserve another phase's bounded record, and
# retain the existing fail-closed nonce, regular-file, and atomic-replace rules.
_accept_clear_failure_evidence() {
  local root run phase dir f tmp kept
  root="${POLYLANE_ACCEPT_FAILURE_ROOT:-}"
  run="${POLYLANE_ACCEPT_FAILURE_RUN_ID:-}"
  phase="${POLYLANE_ACCEPT_FAILURE_PHASE:-}"
  case "$root" in /*) : ;; *) return 0 ;; esac
  case "$run" in ''|*[!A-Za-z0-9._-]*) return 0 ;; esac
  case "$phase" in ''|*[!A-Za-z0-9._-]*) return 0 ;; esac
  dir="$root/docs/polylane/host-gate-failures"
  f="$dir/$run.acceptance.jsonl"
  [ -e "$f" ] || return 0
  [ -f "$f" ] && [ ! -L "$f" ] || return 0
  kept=$(jq --arg run "$run" --arg phase "$phase" \
    '[.[] | select(.run != $run or .phase != $phase)]' "$f") || return 0
  if [ "$kept" = '[]' ]; then
    rm -f "$f"
    return 0
  fi
  tmp=$(mktemp "$dir/.$run.acceptance.XXXXXX") || return 0
  printf '%s\n' "$kept" > "$tmp" || { rm -f "$tmp"; return 0; }
  mv "$tmp" "$f" 2>/dev/null || rm -f "$tmp"
}

# _accept_run CMD : run CMD (bash -c) in the CURRENT dir with a wall-clock cap.
# Uses timeout/gtimeout when present; otherwise runs uncapped (never wedges the
# verb — a hung check is the check author's bug, surfaced by the orchestrator).
_accept_run() {
  local cmd="$1" to="${POLYLANE_ACCEPT_TIMEOUT:-60}" t="" out rc tail_lines
  command -v timeout  >/dev/null 2>&1 && t=timeout
  [ -z "$t" ] && command -v gtimeout >/dev/null 2>&1 && t=gtimeout
  out=$(mktemp "${TMPDIR:-/tmp}/polylane-accept.XXXXXX") || return 1
  # Authority belongs to this checker, never to a command it invokes.  Nested
  # acceptance fixtures can fail intentionally; they must not write canonical
  # host evidence while this parent still records its own bounded failure.
  if [ -n "$t" ]; then
    if ( unset POLYLANE_ACCEPT_FAILURE_ROOT POLYLANE_ACCEPT_FAILURE_RUN_ID POLYLANE_ACCEPT_FAILURE_PHASE; "$t" "$to" bash -c "$cmd" ) >"$out" 2>&1; then rc=0; else rc=$?; fi
  else
    if ( unset POLYLANE_ACCEPT_FAILURE_ROOT POLYLANE_ACCEPT_FAILURE_RUN_ID POLYLANE_ACCEPT_FAILURE_PHASE; bash -c "$cmd" ) >"$out" 2>&1; then rc=0; else rc=$?; fi
  fi
  if [ "$rc" -ne 0 ]; then
    tail_lines="${POLYLANE_ACCEPT_TAIL_LINES:-80}"
    case "$tail_lines" in ''|*[!0-9]*) tail_lines=80 ;; esac
    printf 'ACCEPTANCE-COMMAND-FAILED rc=%s: %s\n' "$rc" "$cmd" >&2
    tail -n "$tail_lines" "$out" >&2
    _accept_failure_evidence "$cmd" "$rc" "$out" "$tail_lines"
  fi
  rm -f "$out"
  return "$rc"
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

# _accept_key_valid KEY : accept IDs that are safe to use in the invocation-local
# keyed-result map. A key is metadata, never a command, glob, or persisted cache key.
_accept_key_valid() {
  case "$1" in
    [A-Za-z0-9]*) case "$1" in *[!A-Za-z0-9._-]*) return 1 ;; esac ;;
    *) return 1 ;;
  esac
  return 0
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
    case "${2:-}" in
      open|doing|done|external|blocked) : ;;
      *) echo "polylane-memory: invalid status '${2:-}' (want open|doing|done|external|blocked)" >&2; exit 2 ;;
    esac
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
    # Finish committed work before switching focus: doing outranks open, then weight.
    jq -r '[.milestones[].subgoals[] | select(.status=="open" or .status=="doing")]
           | sort_by((if .status=="doing" then 0 else 1 end), -.weight)
           | .[0] // empty | "\(.id)  \(.text)"' "$F"
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
    # Goal reached iff >=1 criterion/subgoal, all statuses done, and EVERY subgoal
    # has at least one passing frozen grader. Missing .accept is never completion.
    jq -e '
      ([.milestones[].subgoals[]]) as $sg
      | ((.accept // [])) as $ac
      | (([.criteria[]]|length) > 0)
      and (($sg|length) > 0)
      and (all(.criteria[]; .status=="done"))
      and (all($sg[]; .status=="done"))
      and ([$sg[] | .id as $sid | any($ac[]; .sid==$sid and .status=="pass")] | all)
      and (all($ac[]; .status=="pass"))' "$F" >/dev/null
    ;;

  add-accept)
    _need
    _sid="${1:?usage: add-accept <sid> <cmd> [--tier focused|terminal] [--evidence-kind autonomous|external] [--key safe-id] [dep-glob...]}"
    _cmd="${2:?usage: add-accept <sid> <cmd> [--tier focused|terminal] [--evidence-kind autonomous|external] [--key safe-id] [dep-glob...]}"
    shift 2
    _tier="focused"; _kind="autonomous"; _key=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --tier) _tier="${2:?--tier needs focused or terminal}"; shift 2 ;;
        --evidence-kind) _kind="${2:?--evidence-kind needs autonomous or external}"; shift 2 ;;
        --key) _key="${2:?--key needs a safe id}"; shift 2 ;;
        --) shift; break ;;
        *) break ;;
      esac
    done
    [ -z "$_key" ] || _accept_key_valid "$_key" \
      || { echo "polylane-memory: acceptance key must be a safe id" >&2; exit 2; }
    jq -e --arg id "$_sid" 'any(.milestones[].subgoals[]; .id==$id)' "$F" >/dev/null \
      || { echo "polylane-memory: no sub-goal with id '$_sid'" >&2; exit 1; }
    # FROZEN-BEFORE-BUILD: the grader must be registered while the sub-goal is still
    # open, so the builder cannot author its own weaker success bar after the fact.
    jq -e --arg id "$_sid" 'any(.milestones[].subgoals[]; .id==$id and .status=="done")' "$F" >/dev/null \
      && { echo "polylane-memory: sub-goal '$_sid' already done — acceptance must be registered BEFORE the build" >&2; exit 1; }
    case "$_tier" in focused|terminal) : ;; *)
      echo "polylane-memory: acceptance tier must be focused or terminal" >&2; exit 2 ;;
    esac
    case "$_kind" in autonomous|external) : ;; *)
      echo "polylane-memory: acceptance evidence_kind must be autonomous or external" >&2; exit 2 ;;
    esac
    jq -e --arg id "$_sid" --arg kind "$_kind" '
      all((.accept // [])[] | select(.sid==$id); (.evidence_kind // "autonomous") == $kind)
    ' "$F" >/dev/null || {
      echo "polylane-memory: sub-goal '$_sid' cannot mix autonomous and external acceptance" >&2
      exit 1
    }
    [ "${1:-}" = "--" ] && shift
    # remaining args are dependency globs the check GRADES; content-hash of these
    # gates memoization. No deps -> always re-run (backward-compatible).
    _deps="[]"; if [ "$#" -gt 0 ]; then _deps=$(printf '%s\n' "$@" | jq -R . | jq -cs .); fi
    _save --arg sid "$_sid" --arg cmd "$_cmd" --arg tier "$_tier" --arg kind "$_kind" --arg key "$_key" --argjson deps "$_deps" \
      '.accept = ((.accept // []) + [{sid:$sid, cmd:$cmd, tier:$tier, evidence_kind:$kind, key:$key, status:"unchecked", deps:$deps, fp:"", regressed_cycle:null}])'
    ;;

  tag-accept)
    _need
    _sid="${1:?usage: tag-accept <sid> [--tier focused|terminal] --key <safe-id>}"
    shift
    _key=""; _tier=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --key) _key="${2:?--key needs a safe id}"; shift 2 ;;
        --tier) _tier="${2:?--tier needs focused or terminal}"; shift 2 ;;
        *) echo "polylane-memory: usage: tag-accept <sid> [--tier focused|terminal] --key <safe-id>" >&2; exit 2 ;;
      esac
    done
    [ -n "$_key" ] || { echo "polylane-memory: --key is required" >&2; exit 2; }
    case "$_tier" in ''|focused|terminal) : ;; *)
      echo "polylane-memory: acceptance tier must be focused or terminal" >&2; exit 2 ;;
    esac
    _accept_key_valid "$_key" \
      || { echo "polylane-memory: acceptance key must be a safe id" >&2; exit 2; }
    jq -e --arg id "$_sid" --arg tier "$_tier" \
      'any(.accept[]?; .sid==$id and ($tier=="" or (.tier // "focused")==$tier))' "$F" >/dev/null \
      || { echo "polylane-memory: no matching acceptance check for sub-goal '$_sid'" >&2; exit 1; }
    _save --arg sid "$_sid" --arg key "$_key" --arg tier "$_tier" \
      '.accept |= map(if .sid==$sid and ($tier=="" or (.tier // "focused")==$tier) then .key=$key else . end)'
    ;;

  check-accept)
    _need
    # Targeted focused checks keep inner cycles fast. Terminal checks are reserved
    # for final certification; a plain check-accept remains backward-compatible
    # and runs everything.
    _cyc="null"; _targets=""; _focused=0; _terminal_only=0; _evidence_kind=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --cycle) _cyc="${2:?--cycle needs N}"; shift 2 ;;
        --targets) _targets="${2:?--targets needs comma-separated ids}"; shift 2 ;;
        --focused) _focused=1; shift ;;
        --only-terminal) _terminal_only=1; shift ;;
        --evidence-kind) _evidence_kind="${2:?--evidence-kind needs autonomous or external}"; shift 2 ;;
        *) echo "polylane-memory: unknown check-accept option '$1'" >&2; exit 2 ;;
      esac
    done
    case "$_evidence_kind" in ''|autonomous|external) : ;; *)
      echo "polylane-memory: acceptance evidence_kind must be autonomous or external" >&2; exit 2 ;;
    esac
    _n=$(jq '.accept // [] | length' "$F")
    [ "$_n" = "0" ] && { echo "check-accept: no acceptance checks registered"; exit 0; }
    # A successful top-level invocation must not inherit an old failure for the
    # same nonce/phase.  A real failure below recreates one bounded record.
    _accept_clear_failure_evidence
    _rows="["; _i=0; _failed=0; _key_results="|"
    while [ "$_i" -lt "$_n" ]; do
      _cmd=$(jq -r ".accept[$_i].cmd" "$F")
      _sid=$(jq -r ".accept[$_i].sid" "$F")
      _tier=$(jq -r ".accept[$_i].tier // \"focused\"" "$F")
      _kind=$(jq -r ".accept[$_i].evidence_kind // \"autonomous\"" "$F")
      _key=$(jq -r ".accept[$_i].key // \"\"" "$F")
      _prev=$(jq -r ".accept[$_i].status // \"unchecked\"" "$F")
      _rc=$(jq -r ".accept[$_i].regressed_cycle // \"null\"" "$F")
      # --- #4 memoization: skip a passing check whose graded files are byte-identical
      _deps=$(jq -r ".accept[$_i].deps // [] | join(\" \")" "$F")
      _oldfp=$(jq -r ".accept[$_i].fp // \"\"" "$F")
      _newfp=""
      _selected=1
      if [ -n "$_targets" ]; then
        case ",$_targets," in *",$_sid,"*) : ;; *) _selected=0 ;; esac
      fi
      [ "$_focused" = "1" ] && [ "$_tier" = "terminal" ] && _selected=0
      [ "$_terminal_only" = "1" ] && [ "$_tier" != "terminal" ] && _selected=0
      [ -n "$_evidence_kind" ] && [ "$_kind" != "$_evidence_kind" ] && _selected=0
      if [ "$_selected" = "0" ]; then
        _st="$_prev"; _newfp="$_oldfp"
      else
        # shellcheck disable=SC2086  # dependency globs must expand into graded files
        _newfp="$_kind:"
        if [ -n "$_deps" ]; then _newfp="$_kind:$(_fingerprint $_deps)"; fi
      # memoization is OFF by default: a check often reads files outside its declared
      # deps, so a byte-identical dep-set can falsely cache a pass over now-broken work
      # (invisible to `met`). Correctness first; opt in with POLYLANE_ACCEPT_MEMO=1 only
      # when a check provably reads ONLY its deps and re-running is measurably costly.
        if [ -n "$_key" ]; then
          case "$_key_results" in
            *"|$_kind:$_key:pass|"*) _st="pass" ;;
            *"|$_kind:$_key:fail|"*) _st="fail" ;;
            *)
              if _accept_run "$_cmd"; then _st="pass"; else _st="fail"; fi
              _key_results="$_key_results$_kind:$_key:$_st|"
              ;;
          esac
        elif [ "${POLYLANE_ACCEPT_MEMO:-0}" = "1" ] && [ "$_prev" = "pass" ] && [ -n "$_deps" ] && [ -n "$_newfp" ] && [ "$_newfp" = "$_oldfp" ]; then
          _st="pass"                                   # cached: command never runs
          printf 'check-accept[%s]: pass (cached)\n' "$_i" >&2
        else
          if _accept_run "$_cmd"; then _st="pass"; else _st="fail"; fi
        fi
        [ "$_st" = "pass" ] || _failed=1
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
    [ "$_failed" = "0" ]
    ;;

  unmet-accept)
    _need
    jq -r '(.accept // []) | map(select(.status!="pass")) | .[] | "\(.sid): \(.cmd) [\(.evidence_kind // "autonomous")/\(.status)]"' "$F"
    ;;

  regressions)
    _need
    # every check currently failing that previously passed, naming the cycle it broke.
    # Non-empty output = a temporal seam the (spatial) seam scanner cannot see -> the
    # promote gate treats it as an auto-NO-GO / revert.
    jq -r '(.accept // [])
      | map(select(.status!="pass" and (.regressed_cycle // null) != null))
      | .[] | "REGRESSED c\(.regressed_cycle): \(.sid): \(.cmd) [\(.evidence_kind // "autonomous")]"' "$F"
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
      | ($sg|map(select(.status=="open" or .status=="doing"))
           | sort_by((if .status=="doing" then 0 else 1 end), -.weight)|.[0]) as $next
      | "GOAL: \(.ultimate)",
        "PROGRESS: subgoals \($sd)/\($sn) · criteria \($cd)/\($cn)",
        "NEXT: \(if $next then "\($next.id) — \($next.text)" else "(no open sub-goal)" end)",
        "OPEN CRITERIA:", (($cr[]|select(.status!="done")|"  - \(.id): \(.text)") // "  (none)"),
        "EXTERNAL / NEEDS USER:", (($sg[]|select(.status=="external")|"  - \(.id): \(.text)") // "  (none)"),
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
      | ($sg|map(select(.status=="open" or .status=="doing"))
           | sort_by((if .status=="doing" then 0 else 1 end), -.weight)) as $open
      | (([.log[].cycle]|max) // 0) as $cyc
      | "=== POLYLANE-MAX RESUME ===",
        "GOAL: \(.ultimate)",
        "CYCLE: \($cyc)",
        "PROGRESS: subgoals \($sd)/\($sn) · criteria \($cd)/\($cn)",
        "OPEN SUBGOALS (by weight):", (($open[]|"  - \(.id) (w\(.weight)): \(.text)") // "  (none — check criteria)"),
        "OPEN CRITERIA:", (([$cr[]|select(.status!="done")]|if length>0 then (.[]|"  - \(.id): \(.text)") else "  (none)" end)),
        "EXTERNAL / NEEDS USER:", (([$sg[]|select(.status=="external")]|if length>0 then (.[]|"  - \(.id): \(.text)") else "  (none)" end)),
        "BLOCKED:", (([$sg[]|select(.status=="blocked")]|if length>0 then (.[]|"  - \(.id): \(.text)") else "  (none)" end)),
        "RECENT LOG:", (.log[-8:][]|"  c\(.cycle) \(.kind): \(.text)"),
        "NEXT ACTION: resume at cycle \($cyc+1) — continue doing/open work; if only external items remain, request their exact inputs; STOP only after met + shippability."' "$F"
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
    echo "  commands: init add-criterion add-milestone add-subgoal set-status set-weight log next attempted progress met add-accept tag-accept check-accept unmet-accept regressions brief resume dump" >&2
    exit 2
    ;;
esac
