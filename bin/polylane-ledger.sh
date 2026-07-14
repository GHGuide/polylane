#!/usr/bin/env bash
# polylane-ledger.sh — append-only per-cycle spend ledger + three mechanical money
# gates the council cannot rationalize past. One JSONL row per cycle:
#   {cycle,ts,verdict,tokens,cost,subgoals_done,subgoals_total,nogo,lanes,wall_s}
# Default path: docs/polylane/spend-ledger.jsonl (durable; survives cleanup).
#
#   record --cycle N --verdict V --tokens T --cost C --subdone D --subtotal S \
#          --nogo K --lanes L --wall W [--file F]
#   trend  [--file F]   : Δcost ÷ Δsubgoals_done + IMPROVING|FLAT|REGRESSING;
#                         exit 3 iff spend>0 with zero subgoal progress (stall breaker)
#   roi <next_weight> <open_weight_sum> <budget> [--file F]
#                       : marginal value vs empirical cost/subgoal; prints
#                         continue | stop:diminishing ; exit 4 on stop
#   fit <budget> <n_requested> [--file F]
#                       : affordable lane ceiling from cost/lane; prints an integer
# Pure bash-3.2 + jq; main-guarded.
set -euo pipefail
command -v jq >/dev/null 2>&1 || { echo "polylane-ledger: jq required" >&2; exit 1; }

DEFAULT_F="docs/polylane/spend-ledger.jsonl"

# reject non-numeric AND multi-dot garbage (1.2.3 / ..) to 0 — else --argjson crashes
# jq and drops the whole cycle row under set -e. "1." still passes (jq accepts it).
_num() { case "${1:-}" in ''|.|*[!0-9.]*|*.*.*) printf '0' ;; *) printf '%s' "$1" ;; esac; }

record() {
  local f="$DEFAULT_F" cycle=0 verdict="?" tokens=0 cost=0 subdone=0 subtotal=0 nogo=0 lanes=0 wall=0 ts row
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --file) f="$2"; shift 2 ;;
      --cycle) cycle="$2"; shift 2 ;;      --verdict) verdict="$2"; shift 2 ;;
      --tokens) tokens="$2"; shift 2 ;;    --cost) cost="$2"; shift 2 ;;
      --subdone) subdone="$2"; shift 2 ;;  --subtotal) subtotal="$2"; shift 2 ;;
      --nogo) nogo="$2"; shift 2 ;;        --lanes) lanes="$2"; shift 2 ;;
      --wall) wall="$2"; shift 2 ;;
      *) echo "polylane-ledger record: unknown arg '$1'" >&2; return 2 ;;
    esac
  done
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo "?")
  mkdir -p "$(dirname "$f")" 2>/dev/null || true
  row=$(jq -cn \
    --argjson cycle "$(_num "$cycle")" --arg ts "$ts" --arg verdict "$verdict" \
    --argjson tokens "$(_num "$tokens")" --argjson cost "$(_num "$cost")" \
    --argjson sd "$(_num "$subdone")" --argjson st "$(_num "$subtotal")" \
    --argjson nogo "$(_num "$nogo")" --argjson lanes "$(_num "$lanes")" \
    --argjson wall "$(_num "$wall")" \
    '{cycle:$cycle,ts:$ts,verdict:$verdict,tokens:$tokens,cost:$cost,
      subgoals_done:$sd,subgoals_total:$st,nogo:$nogo,lanes:$lanes,wall_s:$wall}')
  printf '%s\n' "$row" >> "$f"
}

# slurp the JSONL, keeping only the LAST row per distinct cycle. run.sh appends a
# stub row (subdone 0) and the orchestrator re-stamps via a second append, so raw
# rows are two-per-cycle -> .[-1] vs .[-2] compares a cycle to its own stub (Δ=0,
# stall never fires). Collapsing per cycle makes trend/roi/fit see one true row each.
_rows() { local f="$1"; [ -s "$f" ] && jq -s 'group_by(.cycle) | map(.[-1])' "$f" || printf '[]'; }

trend() {
  local f="$DEFAULT_F"; [ "${1:-}" = "--file" ] && { f="$2"; shift 2; }
  local rows; rows=$(_rows "$f")
  local n; n=$(printf '%s' "$rows" | jq 'length')
  if [ "$n" -lt 2 ]; then echo "FLAT (insufficient history)"; return 0; fi
  local dcost dsub label
  dcost=$(printf '%s' "$rows" | jq '.[-1].cost - .[-2].cost')
  dsub=$(printf '%s'  "$rows" | jq '.[-1].subgoals_done - .[-2].subgoals_done')
  if   [ "$(awk -v d="$dsub" 'BEGIN{print (d>0)}')" = 1 ]; then label=IMPROVING
  elif [ "$(awk -v d="$dsub" 'BEGIN{print (d<0)}')" = 1 ]; then label=REGRESSING
  else label=FLAT; fi
  printf 'TREND: Δcost=%s Δsubgoals=%s -> %s\n' "$dcost" "$dsub" "$label"
  if [ "$(awk -v c="$dcost" -v s="$dsub" 'BEGIN{print (c>0 && s<=0)}')" = 1 ]; then
    echo "STALL: spend with no subgoal progress" >&2; return 3
  fi
  return 0
}

roi() {
  local nw="$1" ow="$2" budget="$3" f="$DEFAULT_F"; shift 3
  [ "${1:-}" = "--file" ] && { f="$2"; shift 2; }
  local rows cps totcost totdone
  rows=$(_rows "$f")
  totcost=$(printf '%s' "$rows" | jq '[.[].cost] | add // 0')
  totdone=$(printf '%s' "$rows" | jq '[.[].subgoals_done] | add // 0')
  if [ "$(awk -v d="$totdone" 'BEGIN{print (d<=0)}')" = 1 ]; then echo "continue (no history)"; return 0; fi
  cps=$(awk -v c="$totcost" -v d="$totdone" 'BEGIN{printf "%.4f", c/d}')
  local decision
  decision=$(awk -v nw="$nw" -v ow="$ow" -v b="$budget" -v cps="$cps" 'BEGIN{
    if (ow<=0){print "continue"; exit}
    share = nw/ow;
    warrant = share * b;
    if (cps > warrant) print "stop:diminishing"; else print "continue";
  }')
  printf '%s (cost/subgoal=%s warrant-share=%s/%s of %s)\n' "$decision" "$cps" "$nw" "$ow" "$budget"
  [ "$decision" = "stop:diminishing" ] && return 4 || return 0
}

fit() {
  local budget="$1" nreq="$2" f="$DEFAULT_F"; shift 2
  [ "${1:-}" = "--file" ] && { f="$2"; shift 2; }
  local rows cpl ceil out
  rows=$(_rows "$f")
  cpl=$(printf '%s' "$rows" | jq '
    ([.[].cost]|add // 0) as $c | ([.[].lanes]|add // 0) as $l
    | if $l>0 then ($c/$l) else 0 end')
  if [ "$(awk -v x="$cpl" 'BEGIN{print (x<=0)}')" = 1 ]; then printf '%s\n' "$nreq"; return 0; fi
  ceil=$(awk -v b="$budget" -v c="$cpl" 'BEGIN{printf "%d", (b/c)}')
  out=$(awk -v a="$nreq" -v b="$ceil" 'BEGIN{print (a<b)?a:b}')
  [ "$out" -lt 1 ] 2>/dev/null && out=1   # never trim below one lane
  printf '%s\n' "$out"
}

# cap [--file F] : the "never unbounded spend" hard stop. Exit 5 iff distinct cycles
# recorded >= POLYLANE_MAX_CYCLES (default 8) OR total cost >= POLYLANE_BUDGET (if set).
# Unlike trend/roi (progress-relative), this halts even a run that keeps making progress.
cap() {
  local f="$DEFAULT_F"; [ "${1:-}" = "--file" ] && { f="$2"; shift 2; }
  local rows n cost maxc="${POLYLANE_MAX_CYCLES:-8}" budget="${POLYLANE_BUDGET:-}"
  rows=$(_rows "$f")
  n=$(printf '%s' "$rows" | jq 'length')
  cost=$(printf '%s' "$rows" | jq '[.[].cost] | add // 0')
  if [ "$n" -ge "$maxc" ]; then echo "CAP: $n cycles >= POLYLANE_MAX_CYCLES=$maxc — STOP" >&2; return 5; fi
  if [ -n "$budget" ] && [ "$(awk -v c="$cost" -v b="$budget" 'BEGIN{print (c>=b)}')" = 1 ]; then
    echo "CAP: cost $cost >= POLYLANE_BUDGET=$budget — STOP" >&2; return 5
  fi
  return 0
}

if [ "${BASH_SOURCE[0]:-}" = "${0}" ]; then
  case "${1:-}" in
    record) shift; record "$@" ;;
    trend)  shift; trend  "$@" ;;
    roi)    shift; roi    "$@" ;;
    fit)    shift; fit    "$@" ;;
    cap)    shift; cap    "$@" ;;
    *) echo "usage: polylane-ledger.sh record …|trend|roi <nw> <ow> <budget>|fit <budget> <n>|cap" >&2; exit 2 ;;
  esac
fi
