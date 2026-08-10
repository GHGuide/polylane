#!/usr/bin/env bash
# Durable atomic run telemetry. Every operation requires an explicit --file.
set -euo pipefail
command -v jq >/dev/null 2>&1 || { echo "polylane-run-stats: jq required" >&2; exit 1; }

usage() { echo "usage: polylane-run-stats.sh COMMAND --file FILE [options]" >&2; }
uint() { case "$1" in ''|*[!0-9]*) return 1;; *) return 0;; esac; }
fresh() { jq -cn --argjson n "$1" --arg run "${2:-}" '{version:1,run_id:(if $run=="" then null else $run end),started_at:$n,updated_at:$n,wall_s:0,lanes:{},supervisor_restarts:0,terminal_gates:0,tokens:null,token_state:"unknown",usage_offsets:{},cleanup:"pending",events:[]}'; }
lock() { local n=0; mkdir -p "$(dirname "$1")"; while ! mkdir "$1.lock" 2>/dev/null; do n=$((n+1)); [ "$n" -lt 1000 ] || return 1; sleep .01; done; }
unlock() { rmdir "$1.lock" 2>/dev/null || true; }
common() {
  FILE='' NOW=''
  while [ "$#" -gt 0 ]; do case "$1" in --file) FILE="$2"; shift 2;; --now) NOW="$2"; shift 2;; *) break;; esac; done
  [ -n "$FILE" ] || { usage; return 2; }
  [ -n "$NOW" ] || NOW=$(date -u +%s)
  uint "$NOW" || { echo "polylane-run-stats: invalid --now" >&2; return 2; }
  REST="$*"
}
# update FILE NOW FILTER [jq args...] while holding a mkdir lock and replacing atomically.
update() {
  local f="$1" n="$2" q="$3" s t; shift 3
  lock "$f" || { echo "polylane-run-stats: lock timeout" >&2; return 1; }
  if [ -s "$f" ]; then s=$(cat "$f"); else s=$(fresh "$n"); fi
  t="$f.tmp.$$"
  if ! printf '%s\n' "$s" | jq --argjson n "$n" "$@" 'def tick: (($n-.updated_at)|if .<0 then 0 else . end) as $d | .wall_s += $d | .updated_at=$n; tick | '"$q" > "$t"; then rm -f "$t"; unlock "$f"; return 1; fi
  mv "$t" "$f"; unlock "$f"
}
init() {
  common "$@"; set -- $REST
  local run_id="" s t current=""
  if [ "$#" -gt 0 ]; then
    [ "$#" = 2 ] && [ "$1" = --run-id ] && [ -n "$2" ] || { usage; return 2; }
    run_id="$2"
  fi
  lock "$FILE" || { echo "polylane-run-stats: lock timeout" >&2; return 1; }
  [ ! -s "$FILE" ] || current=$(jq -r '.run_id // ""' "$FILE" 2>/dev/null || true)
  if [ ! -s "$FILE" ] || { [ -n "$run_id" ] && [ "$current" != "$run_id" ]; }; then
    s=$(fresh "$NOW" "$run_id")
  else
    s=$(cat "$FILE")
  fi
  t="$FILE.tmp.$$"
  if ! printf '%s\n' "$s" | jq --argjson n "$NOW" --arg run "$run_id" '
      def tick: (($n-.updated_at)|if .<0 then 0 else . end) as $d
        | .wall_s += $d | .updated_at=$n;
      tick
      | if $run=="" then . else .run_id=$run end
      | .events += [{type:"initialized",at:$n}]' > "$t"; then
    rm -f "$t"; unlock "$FILE"; return 1
  fi
  mv "$t" "$FILE"; unlock "$FILE"
}
lane() {
  local key="$1"; shift; common "$@"; set -- $REST
  [ "$1" = --lane ] && [ -n "$2" ] && [ "$#" = 2 ] || { usage; return 2; }
  update "$FILE" "$NOW" '.lanes[$lane] = (.lanes[$lane] // {launches:0,restarts:0}) | .lanes[$lane].'"$key"' += 1 | .events += [{type:$event,lane:$lane,at:$n}]' --arg lane "$2" --arg event "$key"
}
supervisor() { common "$@"; [ -z "$REST" ] || return 2; update "$FILE" "$NOW" '.supervisor_restarts += 1 | .events += [{type:"supervisor_restart",at:$n}]'; }
gate() { common "$@"; [ -z "$REST" ] || return 2; update "$FILE" "$NOW" '.terminal_gates += 1 | .events += [{type:"terminal_gate",at:$n}]'; }
clean() {
  common "$@"; set -- $REST; [ "$1" = --state ] && [ "$#" = 2 ] || { usage; return 2; }
  case "$2" in complete|warning);; *) return 2;; esac
  update "$FILE" "$NOW" '.cleanup=$state | .events += [{type:"cleanup",state:$state,at:$n}]' --arg state "$2"
}
capture() {
  common "$@"; set -- $REST; local lane='' log='' off=''
  while [ "$#" -gt 0 ]; do case "$1" in --lane) lane="$2";shift 2;;--log)log="$2";shift 2;;--offset)off="$2";shift 2;;*)return 2;;esac; done
  [ -n "$lane" ] && [ -n "$log" ] && uint "$off" || { usage; return 2; }
  lock "$FILE" || return 1
  local s seen start bytes usage add t attempts limit
  if [ -s "$FILE" ]; then s=$(cat "$FILE"); else s=$(fresh "$NOW"); fi
  seen=$(printf '%s' "$s"|jq -r --arg l "$lane" '.usage_offsets[$l] // 0'); uint "$seen" || seen=0
  start="$off"; [ "$seen" -gt "$start" ] && start="$seen"
  attempts=$(printf '%s' "$s" | jq -r --arg l "$lane" '((.lanes[$l].launches // 0) + (.lanes[$l].restarts // 0))')
  uint "$attempts" || attempts=0
  # On the first capture of a fresh run, append-only logs may contain valid JSON
  # turns from older runs under the same lane name. Keep only as many trailing
  # completions as this run actually launched. Once an offset exists, every valid
  # completion in the unseen suffix belongs to the current run.
  limit=0
  [ "$seen" = 0 ] && [ "$off" = 0 ] && limit="$attempts"
  if [ -f "$log" ]; then
    bytes=$(wc -c < "$log"|tr -d ' '); [ "$start" -le "$bytes" ] || start=0
    usage=$(tail -c "+$((start+1))" "$log" 2>/dev/null | jq -Rrs --argjson limit "$limit" '
      [split("\n")[]
       | fromjson?
       | select(.type=="turn.completed")
       | .usage? | select(type=="object")]
      | if $limit > 0 then .[-$limit:] else . end
      | def sum_field($field): [ .[] | .[$field]? | select(type=="number") ] | if length == 0 then null else add end;
      def total: [ .[] | if (.total_tokens?|type)=="number" then .total_tokens elif ((.input_tokens?|type)=="number" and (.output_tokens?|type)=="number") then (.input_tokens + .output_tokens) else empty end ] | if length == 0 then null else add end;
      {total_tokens:total,input_tokens:sum_field("input_tokens"),cached_input_tokens:sum_field("cached_input_tokens"),output_tokens:sum_field("output_tokens"),reasoning_output_tokens:sum_field("reasoning_output_tokens"),uncached_input_tokens:([.[] | select((.input_tokens?|type)=="number" and (.cached_input_tokens?|type)=="number") | (.input_tokens - .cached_input_tokens | if . < 0 then 0 else . end)] | if length == 0 then null else add end)}' 2>/dev/null || true)
  else bytes="$start"; usage=; fi
  add=$(printf '%s' "$usage" | jq -r '.total_tokens // empty' 2>/dev/null || true)
  [ "$add" = null ] && add=
  [ -n "$add" ] || add=null
  t="$FILE.tmp.$$"
  if ! printf '%s\n' "$s"|jq --argjson n "$NOW" --arg l "$lane" --argjson o "$bytes" --argjson a "$add" --argjson u "${usage:-null}" 'def tick: (($n-.updated_at)|if .<0 then 0 else . end) as $d | .wall_s += $d | .updated_at=$n; tick | .usage_offsets[$l]=$o | if $a==null then . else .tokens=((.tokens//0)+$a)|.token_state="known" end | if $u==null then . else reduce ["input_tokens","cached_input_tokens","uncached_input_tokens","output_tokens","reasoning_output_tokens"][] as $key (.; if $u[$key]==null then . else .usage = (.usage // {}) | .usage[$key]=((.usage[$key]//0)+$u[$key]) end) end | .events += [{type:"usage_capture",lane:$l,at:$n,added:$a}]' > "$t"; then rm -f "$t";unlock "$FILE";return 1;fi
  mv "$t" "$FILE"; unlock "$FILE"
}
snapshot() {
  common "$@"; [ -z "$REST" ] || return 2
  if [ -s "$FILE" ]; then jq --argjson n "$NOW" '(.wall_s+(($n-.updated_at)|if .<0 then 0 else . end)) as $w|{run_id,started_at,wall_s:$w,lanes,supervisor_restarts,terminal_gates,tokens,token_state,usage,cleanup}' "$FILE"; else fresh "$NOW"|jq '{run_id,started_at,wall_s,lanes,supervisor_restarts,terminal_gates,tokens,token_state,usage,cleanup}';fi
}
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  cmd="$1"; shift || true
  case "$cmd" in init)init "$@";;lane-launch)lane launches "$@";;lane-restart)lane restarts "$@";;supervisor-restart)supervisor "$@";;terminal-gate)gate "$@";;capture-usage)capture "$@";;cleanup)clean "$@";;snapshot)snapshot "$@";;*)usage;exit 2;;esac
fi
