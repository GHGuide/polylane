#!/usr/bin/env bash
# Hermetic contract tests for the standalone durable run-statistics helper.
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
STATS="$ROOT/bin/polylane-run-stats.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/polylane-run-stats.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

fail() { echo "FAIL: $*" >&2; exit 1; }
assert_jq() {
  local file="$1" filter="$2" expected="$3" actual
  actual=$(jq -c "$filter" "$file")
  [ "$actual" = "$expected" ] || fail "$filter: expected $expected, got $actual"
}

state="$TMP/stats.json"
log="$TMP/codex.jsonl"

# RED: the helper does not exist yet. These assertions define its public contract.
"$STATS" init --file "$state" --now 100
"$STATS" init --file "$state" --now 150
assert_jq "$state" '.started_at' '100'
assert_jq "$state" '.wall_s' '50'
assert_jq "$state" '.tokens' 'null'
assert_jq "$state" '.token_state' '"unknown"'

"$STATS" lane-launch --file "$state" --now 160 --lane telemetry
"$STATS" lane-restart --file "$state" --now 170 --lane telemetry
"$STATS" supervisor-restart --file "$state" --now 180
"$STATS" terminal-gate --file "$state" --now 190
"$STATS" terminal-gate --file "$state" --now 200
"$STATS" cleanup --file "$state" --now 210 --state warning
assert_jq "$state" '.lanes.telemetry.launches' '1'
assert_jq "$state" '.lanes.telemetry.restarts' '1'
assert_jq "$state" '.supervisor_restarts' '1'
assert_jq "$state" '.terminal_gates' '2'
assert_jq "$state" '.cleanup' '"warning"'
assert_jq "$state" '.wall_s' '110'

printf '%s\n' \
  '{"type":"turn.completed","usage":{"input_tokens":3,"output_tokens":7}}' \
  '{"type":"turn.completed","usage":{"total_tokens":11}}' > "$log"
"$STATS" capture-usage --file "$state" --now 220 --lane telemetry --log "$log" --offset 0
assert_jq "$state" '.tokens' '21'
assert_jq "$state" '.token_state' '"known"'
assert_jq "$state" '.usage.input_tokens' '3'
assert_jq "$state" '.usage.output_tokens' '7'
assert_jq "$state" '.usage.cached_input_tokens' 'null'
assert_jq "$state" '.usage.uncached_input_tokens' 'null'
assert_jq "$state" '.usage.reasoning_output_tokens' 'null'
before=$(wc -c < "$log" | tr -d ' ')
"$STATS" capture-usage --file "$state" --now 230 --lane telemetry --log "$log" --offset 0
assert_jq "$state" '.tokens' '21'
assert_jq "$state" '.usage_offsets.telemetry' "$before"

# Codex reports cache and reasoning fields independently.  Preserve legacy
# total tokens while exposing truthful breakdowns and clamp malformed cache
# relationships at zero uncached input.
printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":100,"cached_input_tokens":80,"output_tokens":5,"reasoning_output_tokens":2}}' >> "$log"
"$STATS" capture-usage --file "$state" --now 245 --lane telemetry --log "$log" --offset "$before"
assert_jq "$state" '.tokens' '126'
assert_jq "$state" '.usage.input_tokens' '103'
assert_jq "$state" '.usage.cached_input_tokens' '80'
assert_jq "$state" '.usage.uncached_input_tokens' '20'
assert_jq "$state" '.usage.output_tokens' '12'
assert_jq "$state" '.usage.reasoning_output_tokens' '2'

printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":0,"output_tokens":0}}' >> "$log"
"$STATS" capture-usage --file "$state" --now 240 --lane telemetry --log "$log" --offset "$before"
assert_jq "$state" '.tokens' '126'

# Real Codex pane logs are append-only across cycles and contain warning/prompt
# lines around valid JSON events. A fresh run with one launch must ignore both
# that noise and an older turn.completed event for the same lane name.
noisy_state="$TMP/noisy-stats.json"
noisy_log="$TMP/noisy-codex.log"
"$STATS" init --file "$noisy_state" --now 10 --run-id noisy-run
"$STATS" lane-launch --file "$noisy_state" --now 11 --lane integrator
printf '%s\n' \
  '{"type":"turn.completed","usage":{"total_tokens":999}}' \
  'WARN marketplace refresh timed out' \
  '{"type":"turn.completed","usage":{"input_tokens":5,"output_tokens":6}}' \
  '(base) prompt %' > "$noisy_log"
"$STATS" capture-usage --file "$noisy_state" --now 12 --lane integrator --log "$noisy_log" --offset 0
assert_jq "$noisy_state" '.tokens' '11'
assert_jq "$noisy_state" '.token_state' '"known"'

"$STATS" snapshot --file "$state" --now 300 > "$TMP/snapshot.json"
assert_jq "$TMP/snapshot.json" '.started_at' '100'
assert_jq "$TMP/snapshot.json" '.wall_s' '205'
assert_jq "$TMP/snapshot.json" '.cleanup' '"warning"'
assert_jq "$TMP/snapshot.json" '.usage.uncached_input_tokens' '20'

# A new run ID starts a fresh accounting window; the same run ID resumes it.
fresh_run="$TMP/fresh-run.json"
"$STATS" init --file "$fresh_run" --now 10 --run-id run-a
"$STATS" lane-launch --file "$fresh_run" --now 20 --lane alpha
"$STATS" init --file "$fresh_run" --now 30 --run-id run-a
assert_jq "$fresh_run" '.run_id' '"run-a"'
assert_jq "$fresh_run" '.started_at' '10'
assert_jq "$fresh_run" '.lanes.alpha.launches' '1'
"$STATS" init --file "$fresh_run" --now 40 --run-id run-b
assert_jq "$fresh_run" '.run_id' '"run-b"'
assert_jq "$fresh_run" '.started_at' '40'
assert_jq "$fresh_run" '.wall_s' '0'
assert_jq "$fresh_run" '.lanes | length' '0'
assert_jq "$fresh_run" '.terminal_gates' '0'

# Concurrent lock contenders must preserve every event.
concurrent="$TMP/concurrent.json"
"$STATS" init --file "$concurrent" --now 1
i=1
while [ "$i" -le 12 ]; do
  "$STATS" terminal-gate --file "$concurrent" --now "$((i + 1))" &
  i=$((i + 1))
done
wait
assert_jq "$concurrent" '.terminal_gates' '12'

echo "PASS: run stats initialize, resume, usage, snapshot, and concurrency"
