#!/usr/bin/env bash
# Emit and verify a bounded-autonomy certificate from durable runner telemetry.
# bash 3.2 + jq; the proof is written even on failure so a stopped run is diagnosable.
set -euo pipefail

usage() {
  echo "usage: polylane-efficiency.sh capture --manifest FILE --stats FILE --proof FILE --phase gate|final | verify --proof FILE [--phase gate|final] [--run-id ID]" >&2
  exit 2
}

capture() {
  local manifest="" stats="" proof="" phase="" expected actual max_restarts restarts
  local max_wall wall gates expected_gates cleanup tokens token_state manifest_run stats_run status="PASS" reasons="" tmp
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --manifest) manifest="${2:-}"; shift 2 ;;
      --stats) stats="${2:-}"; shift 2 ;;
      --proof) proof="${2:-}"; shift 2 ;;
      --phase) phase="${2:-}"; shift 2 ;;
      *) usage ;;
    esac
  done
  [ -s "$manifest" ] && [ -s "$stats" ] && [ -n "$proof" ] || usage
  case "$phase" in gate|final) ;; *) usage ;; esac
  jq -e '.efficiency_canary | type == "object"' "$manifest" >/dev/null 2>&1 || {
    echo "polylane-efficiency: manifest has no efficiency_canary contract" >&2; return 2;
  }
  jq -e . "$stats" >/dev/null 2>&1 || {
    echo "polylane-efficiency: invalid run stats" >&2; return 2;
  }

  expected=$(jq -r '(.efficiency_canary.expected_launches // ((.lanes | length) + 1))' "$manifest")
  max_restarts=$(jq -r '(.efficiency_canary.max_restarts // 0)' "$manifest")
  max_wall=$(jq -r '(.efficiency_canary.max_wall_s // 1800)' "$manifest")
  expected_gates=$(jq -er '
    (if (.efficiency_canary | has("expected_terminal_gates"))
     then .efficiency_canary.expected_terminal_gates
     else 1
     end)
    | select(type == "number" and . >= 0 and floor == .)
  ' "$manifest") || {
    echo "polylane-efficiency: invalid expected_terminal_gates" >&2; return 2;
  }
  actual=$(jq -r '[.lanes[]?.launches] | add // 0' "$stats")
  restarts=$(jq -r '(([.lanes[]?.restarts] | add // 0) + (.supervisor_restarts // 0))' "$stats")
  wall=$(jq -r '.wall_s // 0' "$stats")
  gates=$(jq -r '.terminal_gates // 0' "$stats")
  cleanup=$(jq -r '.cleanup // "unknown"' "$stats")
  tokens=$(jq -r 'if .tokens == null then "unknown" else (.tokens|tostring) end' "$stats")
  token_state=$(jq -r '.token_state // "unknown"' "$stats")
  manifest_run=$(jq -r '.run_id // ""' "$manifest")
  stats_run=$(jq -r '.run_id // ""' "$stats")

  if [ -z "$manifest_run" ] || [ "$stats_run" != "$manifest_run" ]; then
    status="FAIL"; reasons="$reasons run_id=$stats_run/$manifest_run"
  fi
  if [ "$actual" -ne "$expected" ] 2>/dev/null; then
    status="FAIL"; reasons="$reasons launches=$actual/$expected"
  fi
  if [ "$restarts" -gt "$max_restarts" ] 2>/dev/null; then
    status="FAIL"; reasons="$reasons restarts=$restarts>$max_restarts"
  fi
  if [ "$gates" -ne "$expected_gates" ] 2>/dev/null; then
    status="FAIL"; reasons="$reasons terminal_gates=$gates/$expected_gates"
  fi
  if [ "$wall" -gt "$max_wall" ] 2>/dev/null; then
    status="FAIL"; reasons="$reasons wall_s=$wall>$max_wall"
  fi
  case "$tokens:$token_state" in
    unknown:unknown|*[0-9]:known) ;;
    *) status="FAIL"; reasons="$reasons token_truth=$tokens/$token_state" ;;
  esac
  if [ "$phase" = gate ] && [ "$cleanup" != pending ]; then
    status="FAIL"; reasons="$reasons cleanup_at_gate=$cleanup"
  elif [ "$phase" = final ] && [ "$cleanup" != complete ]; then
    status="FAIL"; reasons="$reasons cleanup_at_final=$cleanup"
  fi

  mkdir -p "$(dirname "$proof")"
  tmp="$proof.tmp.$$"
  {
    echo "# polylane efficiency proof"
    echo
    echo "- Run: $(jq -r '.run_id' "$manifest")"
    echo "- Phase: $phase"
    echo "- Status: $status"
    echo "- Wall seconds: $wall / $max_wall"
    echo "- Launches: $actual / $expected"
    echo "- Restarts: $restarts / $max_restarts"
    echo "- Terminal gates: $gates / $expected_gates"
    echo "- Cleanup: $cleanup"
    if [ "$tokens" = unknown ]; then
      echo "- Tokens: unknown"
    else
      echo "- Tokens: $tokens ($token_state)"
    fi
    echo "- Unexpected launches: $((actual - expected))"
    echo "- Manual intervention policy: forbidden"
    [ -z "$reasons" ] || echo "- Failures:${reasons}"
  } > "$tmp"
  mv "$tmp" "$proof"
  [ "$status" = PASS ]
}

verify() {
  local proof="" phase="" run_id="" gate_lines gate_contract
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --proof) proof="${2:-}"; shift 2 ;;
      --phase) phase="${2:-}"; shift 2 ;;
      --run-id) run_id="${2:-}"; shift 2 ;;
      *) usage ;;
    esac
  done
  [ -s "$proof" ] || return 1
  grep -qF -- '- Status: PASS' "$proof" || return 1
  gate_lines=$(grep -c '^\- Terminal gates:' "$proof" || true)
  [ "$gate_lines" = 1 ] || return 1
  if grep -qxF -- '- Terminal gates: 1' "$proof"; then
    : # Backward-compatible terminal proof format.
  elif grep -qxE -- '- Terminal gates: [0-9]+ / [0-9]+' "$proof"; then
    gate_contract=$(sed -n 's/^- Terminal gates: \([0-9][0-9]*\) \/ \([0-9][0-9]*\)$/\1 \2/p' "$proof")
    set -- $gate_contract
    [ "$#" = 2 ] && [ "$1" -eq "$2" ] 2>/dev/null || return 1
  else
    return 1
  fi
  grep -qF -- '- Unexpected launches: 0' "$proof" || return 1
  [ -z "$run_id" ] || grep -qF -- "- Run: $run_id" "$proof" || return 1
  [ -z "$phase" ] || grep -qF -- "- Phase: $phase" "$proof"
}

case "${1:-}" in
  capture) shift; capture "$@" ;;
  verify) shift; verify "$@" ;;
  *) usage ;;
esac
