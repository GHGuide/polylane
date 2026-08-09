#!/usr/bin/env bash
# Isolated, resumable fault experiment. It never addresses tmux, git, home, or network.
set -euo pipefail

usage() {
  echo "usage: polylane-soak.sh configure <run-dir> --hours <6|12|24> [--seed N] | run <run-dir> --accelerated --iterations N [--seed N] [--stop-after N] [--max-recovery-attempts N] | run <run-dir> --hours <6|12|24> [--seed N] [--max-recovery-attempts N]" >&2
  exit 2
}

state_file() { printf '%s/state.json\n' "$1"; }
backup_file() { printf '%s/state.json.bak\n' "$1"; }
events_file() { printf '%s/events.jsonl\n' "$1"; }

valid_state() {
  jq -e '.schema == "polylane-soak-state/v1" and (.mode == "accelerated" or .mode == "wall-clock") and (.status as $status | ["configured","running","interrupted","passed","failed"] | index($status) != null) and (.nonce | type == "string" and length > 0) and (.iteration | type == "number" and . >= 0) and (.fault_order | type == "array" and length == 6)' "$1" >/dev/null 2>&1
}

event() {
  local run="$1" kind="$2" payload="$3" now
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  jq -cn --arg at "$now" --arg kind "$kind" --argjson payload "$payload" '{at:$at,event:$kind,payload:$payload}' >> "$(events_file "$run")"
}

write_state() {
  local run="$1" json="$2" state backup temp
  state=$(state_file "$run"); backup=$(backup_file "$run")
  temp=$(mktemp "$run/.state.XXXXXX")
  printf '%s\n' "$json" > "$temp"
  jq -e . "$temp" >/dev/null || { rm -f "$temp"; return 1; }
  if [ -f "$state" ] && valid_state "$state"; then cp "$state" "$backup"; fi
  mv "$temp" "$state"
}

state_json() { cat "$(state_file "$1")"; }

fault_order() {
  local seed="$1" offset
  offset=$((seed % 6)); [ "$offset" -ge 0 ] || offset=$((offset + 6))
  jq -cn --argjson offset "$offset" '["worker-death","stale-nonce-marker","malformed-state","interrupted-atomic-write","lost-session","resume"] as $f | [range(0;6) | $f[(. + $offset) % 6]]'
}

new_state() {
  local mode="$1" target="$2" seed="$3" now nonce order
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ); nonce="soak-${now}-${$}-${seed}"; order=$(fault_order "$seed")
  jq -cn --arg mode "$mode" --arg nonce "$nonce" --arg at "$now" --argjson target "$target" --argjson seed "$seed" --argjson order "$order" \
    '{schema:"polylane-soak-state/v1",mode:$mode,status:"configured",nonce:$nonce,seed:$seed,target:$target,iteration:0,started_at:$at,last_checkpoint_at:$at,fault_order:$order,completed_faults:[],steady_state:{expected:"isolated-fixture-ready",restored:true,last_result:"initial"},recovery:{max_attempts:1,attempts:0,last_result:"not-needed",last_seconds:0},driver:"isolated-fixture"}'
}

load_or_recover_state() {
  local run="$1" state backup
  state=$(state_file "$run"); backup=$(backup_file "$run")
  if [ -f "$state" ] && valid_state "$state"; then return 0; fi
  if [ -f "$backup" ] && valid_state "$backup"; then
    cp "$backup" "$state"; event "$run" checkpoint-recovered '{"from":"atomic-backup"}'; return 0
  fi
  echo "soak: state is malformed and no valid atomic backup exists" >&2
  return 1
}

write_summary() {
  local run="$1" terminal="$2" reason="$3" state faults sleeps
  state=$(state_json "$run"); faults=$(find "$run/faults" -name '*.json' -type f 2>/dev/null | wc -l | tr -d ' ')
  sleeps=$(printf '%s' "$state" | jq -r '.sleep_seconds // 0')
  printf '%s\n' "$state" | jq --arg terminal "$terminal" --arg reason "$reason" --argjson faults "$faults" --argjson sleeps "$sleeps" \
    '{schema:"polylane-soak-summary/v1",terminal_status:$terminal,reason:$reason,run_nonce:.nonce,mode:.mode,iteration:.iteration,target:.target,elapsed_seconds:((now - (.started_at | fromdateiso8601)) | floor),remaining_seconds:(if .mode == "wall-clock" then (.target - ((now - (.started_at | fromdateiso8601)) | floor) | if . < 0 then 0 else . end) else 0 end),sleep_seconds:$sleeps,steady_state:.steady_state,recovery:.recovery,completed_faults:.completed_faults,fault_receipts:$faults}' > "$run/summary.json"
}

fault_receipted() { [ -f "$1/faults/$2.json" ]; }

inject_fixture_fault() {
  local run="$1" fault="$2" iteration="$3" attempts="$4" receipt now recovery seconds
  receipt="$run/faults/$fault.json"; now=$(date -u +%Y-%m-%dT%H:%M:%SZ); recovery="restored"; seconds=0
  if fault_receipted "$run" "$fault"; then return 0; fi
  mkdir -p "$run/faults" "$run/fixtures"
  case "$fault" in
    worker-death) printf 'fixture worker terminated\n' > "$run/fixtures/worker-death" ;;
    stale-nonce-marker) printf 'foreign-nonce\n' > "$run/fixtures/stale-nonce-marker" ;;
    malformed-state) printf '{malformed fixture state\n' > "$run/fixtures/malformed-state" ;;
    interrupted-atomic-write) printf 'interrupted atomic fixture\n' > "$run/fixtures/interrupted-atomic-write" ;;
    lost-session) printf 'fixture session lost\n' > "$run/fixtures/lost-session" ;;
    resume) printf 'fixture resume requested\n' > "$run/fixtures/resume" ;;
    *) echo "soak: unknown fixture fault: $fault" >&2; return 1 ;;
  esac
  if [ "$attempts" -le 0 ]; then recovery="recovery-exhausted"; seconds=0; fi
  jq -n --arg fault "$fault" --arg at "$now" --arg recovery "$recovery" --argjson iteration "$iteration" --argjson max "$attempts" --argjson seconds "$seconds" \
    '{schema:"polylane-soak-fault-receipt/v1",fault:$fault,injected_at:$at,iteration:$iteration,scope:"isolated-fixture",max_recovery_attempts:$max,recovery_result:$recovery,recovery_seconds:$seconds}' > "$receipt"
  event "$run" fault-injected "$(jq -cn --arg fault "$fault" --argjson iteration "$iteration" --arg recovery "$recovery" '{fault:$fault,iteration:$iteration,recovery:$recovery}')"
  [ "$recovery" = "restored" ]
}

checkpoint_iteration() {
  local run="$1" iteration="$2" fault="$3" state now completed
  state=$(state_json "$run"); now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  completed=$(printf '%s' "$state" | jq -c --arg fault "$fault" '(.completed_faults + [$fault] | unique)')
  state=$(printf '%s' "$state" | jq --arg at "$now" --argjson iteration "$iteration" --argjson completed "$completed" \
    '.status="running" | .iteration=$iteration | .last_checkpoint_at=$at | .completed_faults=$completed | .steady_state={expected:"isolated-fixture-ready",restored:true,last_result:"restored"} | .recovery.attempts=1 | .recovery.last_result="restored" | .recovery.last_seconds=0')
  write_state "$run" "$state"; event "$run" checkpoint "$(jq -cn --argjson iteration "$iteration" --arg fault "$fault" '{iteration:$iteration,fault:$fault,steady_state:"restored"}')"
}

configure() {
  local run="$1"; shift; local hours="" seed=1
  while [ "$#" -gt 0 ]; do case "$1" in --hours) shift; [ "$#" -gt 0 ] || usage; hours="$1" ;; --seed) shift; [ "$#" -gt 0 ] || usage; seed="$1" ;; *) usage ;; esac; shift; done
  case "$hours" in 6|12|24) ;; *) echo "soak: hours must be 6, 12, or 24" >&2; return 2 ;; esac
  case "$seed" in *[!0-9-]*|'') echo "soak: seed must be an integer" >&2; return 2 ;; esac
  mkdir -p "$run"; [ ! -e "$(state_file "$run")" ] || { echo "soak: run already configured; use run to resume" >&2; return 2; }
  : > "$(events_file "$run")"; write_state "$run" "$(new_state wall-clock "$((hours * 3600))" "$seed")"; event "$run" configured "$(jq -cn --argjson hours "$hours" '{mode:"wall-clock",hours:$hours,driver:"isolated-fixture"}')"
}

cmd_run() {
  local run="$1"; shift; local accelerated=0 iterations="" hours="" seed="" stop_after="" max_attempts=1 mode target state next fault elapsed
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --accelerated) accelerated=1 ;;
      --iterations) shift; [ "$#" -gt 0 ] || usage; iterations="$1" ;;
      --hours) shift; [ "$#" -gt 0 ] || usage; hours="$1" ;;
      --seed) shift; [ "$#" -gt 0 ] || usage; seed="$1" ;;
      --stop-after) shift; [ "$#" -gt 0 ] || usage; stop_after="$1" ;;
      --max-recovery-attempts) shift; [ "$#" -gt 0 ] || usage; max_attempts="$1" ;;
      *) usage ;;
    esac; shift
  done
  case "$max_attempts" in *[!0-9]*|'') echo "soak: max recovery attempts must be a nonnegative integer" >&2; return 2 ;; esac
  if [ "$accelerated" -eq 1 ]; then
    [ -n "$iterations" ] && [ -z "$hours" ] || usage; mode="accelerated"; target="$iterations"
  else
    case "$hours" in 6|12|24) ;; *) echo "soak: wall-clock mode requires --hours 6, 12, or 24" >&2; return 2 ;; esac
    mode="wall-clock"; target="$((hours * 3600))"
  fi
  mkdir -p "$run"
  if [ ! -f "$(state_file "$run")" ]; then
    [ -n "$seed" ] || seed=1; : > "$(events_file "$run")"; write_state "$run" "$(new_state "$mode" "$target" "$seed")"; event "$run" started "$(jq -cn --arg mode "$mode" --argjson target "$target" '{mode:$mode,target:$target,driver:"isolated-fixture"}')"
  fi
  load_or_recover_state "$run"
  state=$(state_json "$run")
  [ "$(printf '%s' "$state" | jq -r .mode)" = "$mode" ] || { echo "soak: mode differs from checkpoint" >&2; return 2; }
  [ "$(printf '%s' "$state" | jq -r .target)" = "$target" ] || { echo "soak: target differs from checkpoint" >&2; return 2; }
  if [ -n "$seed" ] && [ "$(printf '%s' "$state" | jq -r .seed)" != "$seed" ]; then echo "soak: seed differs from checkpoint" >&2; return 2; fi
  if [ "$(printf '%s' "$state" | jq -r .status)" = "passed" ]; then write_summary "$run" passed "already complete"; return 0; fi
  if [ "$(printf '%s' "$state" | jq -r .status)" = "failed" ]; then write_summary "$run" failed "checkpoint already failed"; return 1; fi
  if [ "$(printf '%s' "$state" | jq -r .status)" = "configured" ]; then
    state=$(printf '%s' "$state" | jq --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.status="running" | .started_at=$at | .last_checkpoint_at=$at')
  fi
  state=$(printf '%s' "$state" | jq --argjson max "$max_attempts" '.recovery.max_attempts=$max')
  write_state "$run" "$state"
  while :; do
    state=$(state_json "$run"); next=$(( $(printf '%s' "$state" | jq -r .iteration) + 1 ))
    if [ "$mode" = "accelerated" ]; then [ "$next" -le "$target" ] || break
    else elapsed=$(( $(date +%s) - $(printf '%s' "$state" | jq -r '.started_at | fromdateiso8601') )); [ "$elapsed" -lt "$target" ] || break; fi
    fault=$(printf '%s' "$state" | jq -r --argjson n "$next" '.fault_order[($n - 1) % 6]')
    if ! fault_receipted "$run" "$fault"; then
      if ! inject_fixture_fault "$run" "$fault" "$next" "$max_attempts"; then
        state=$(state_json "$run" | jq --arg fault "$fault" '.status="failed" | .steady_state.restored=false | .recovery.max_attempts=(.recovery.max_attempts) | .recovery.last_result="recovery-exhausted"')
        write_state "$run" "$state"; write_summary "$run" failed "steady state was not restored after $fault"; return 1
      fi
    fi
    checkpoint_iteration "$run" "$next" "$fault"
    if [ -n "$stop_after" ] && [ "$next" -ge "$stop_after" ]; then
      state=$(state_json "$run" | jq '.status="interrupted"'); write_state "$run" "$state"; event "$run" interrupted "$(jq -cn --argjson iteration "$next" '{iteration:$iteration}')"; return 75
    fi
    if [ "$mode" = "wall-clock" ]; then
      state=$(state_json "$run" | jq '.sleep_seconds=((.sleep_seconds // 0) + 1)'); write_state "$run" "$state"; sleep 1
    fi
  done
  state=$(state_json "$run" | jq '.status="passed" | .steady_state={expected:"isolated-fixture-ready",restored:true,last_result:"restored"}')
  write_state "$run" "$state"; event "$run" completed "$(jq -cn --argjson iteration "$(printf '%s' "$state" | jq -r .iteration)" '{iteration:$iteration}')"; write_summary "$run" passed "steady state restored"
}

main() {
  case "${1:-}" in configure) [ "$#" -ge 2 ] || usage; shift; configure "$@" ;; run) [ "$#" -ge 2 ] || usage; shift; cmd_run "$@" ;; *) usage ;; esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
