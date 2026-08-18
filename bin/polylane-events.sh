#!/usr/bin/env bash
# polylane-events.sh — append-only, run-scoped graph execution event ledger.

usage() {
  cat <<'EOF'
USAGE:
  polylane-events.sh append <ledger> <run-id> <graph-id> <node> <from> <to> <attempt> <idempotency-key> [reason]
  polylane-events.sh replay <ledger> <run-id> <graph-id>
  polylane-events.sh verify <ledger> <run-id> <graph-id>
EOF
}

event_invalid() {
  printf 'EVENT-INVALID: %s\n' "$1" >&2
  return 2
}

valid_id() {
  case "$1" in
    ''|[!A-Za-z0-9]*|*[!A-Za-z0-9._:-]*) return 1 ;;
    *) return 0 ;;
  esac
}

valid_integer() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

# The writer's source of truth is append-only, so fail before any durable write
# when the host cannot provide the configured headroom.  Tests can inject a
# tiny probe; production uses df and never fills the real volume.
event_disk_guard() {
  local dir="$1" floor="${POLYLANE_MIN_DISK_GB:-2}" free
  if [ -n "${POLYLANE_DISK_PROBE:-}" ] && [ -x "$POLYLANE_DISK_PROBE" ]; then
    free=$("$POLYLANE_DISK_PROBE" "$dir" 2>/dev/null | sed -n '1p')
  else
    free=$(df -Pk "$dir" 2>/dev/null | awk 'NR==2 {print int($4/1024/1024)}')
  fi
  [ -n "$free" ] || return 0
  [ "$free" -ge "$floor" ] 2>/dev/null
}

allowed_transition() {
  case "$1:$2" in
    pending:ready|pending:blocked|pending:skipped|ready:running|ready:blocked|ready:skipped|running:succeeded|running:failed|running:blocked|failed:ready|failed:blocked)
      return 0 ;;
    *) return 1 ;;
  esac
}

# strict_validate_ledger LEDGER RUN GRAPH checks every prior row before callers
# rely on it. A missing ledger is the canonical empty history.
strict_validate_ledger() {
  local ledger="$1" run_id="$2" graph_id="$3" last_byte static_check transition_check

  valid_id "$run_id" && valid_id "$graph_id" || {
    event_invalid 'run_id and graph_id must be well-formed identifiers'
    return 2
  }
  [ ! -e "$ledger" ] && return 0
  [ -f "$ledger" ] || {
    event_invalid 'ledger must be a regular JSONL file'
    return 2
  }
  if [ -s "$ledger" ]; then
    last_byte=$(tail -c 1 "$ledger" | od -An -t u1 | tr -d ' ')
    [ "$last_byte" = '10' ] || {
      event_invalid 'ledger ends with an incomplete JSONL row'
      return 2
    }
  fi

  static_check=$(jq -r -s --arg run_id "$run_id" --arg graph_id "$graph_id" '
    def valid_id:
      type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._:-]*$");
    def valid_state:
      . == "pending" or . == "ready" or . == "running" or . == "succeeded"
      or . == "failed" or . == "blocked" or . == "skipped";
    def integer: type == "number" and floor == .;
    def valid_row:
      type == "object"
      and keys == ["artifact_hash", "attempt", "event_schema", "from", "graph_id", "idempotency_key", "node", "reason", "run_id", "seq", "timestamp", "to"]
      and .event_schema == 1
      and (.seq | integer and . >= 1)
      and (.timestamp | integer)
      and (.attempt | integer and . >= 0)
      and (.run_id | valid_id)
      and (.graph_id | valid_id)
      and (.node | valid_id)
      and (.idempotency_key | valid_id)
      and (.from | type == "string" and valid_state)
      and (.to | type == "string" and valid_state)
      and (.reason | type == "string")
      and (.artifact_hash | type == "string")
      and .run_id == $run_id and .graph_id == $graph_id;
    if all(.[]; valid_row) then "ok" else "bad" end
  ' "$ledger" 2>/dev/null) || {
    event_invalid 'ledger contains malformed JSON or an invalid event row'
    return 2
  }
  [ "$static_check" = 'ok' ] || {
    event_invalid 'row schema, identifier, or run/graph scope is invalid'
    return 2
  }

  transition_check=$(jq -r -s '
    def allowed($from; $to):
      ($from == "pending" and ($to == "ready" or $to == "blocked" or $to == "skipped"))
      or ($from == "ready" and ($to == "running" or $to == "blocked" or $to == "skipped"))
      or ($from == "running" and ($to == "succeeded" or $to == "failed" or $to == "blocked"))
      or ($from == "failed" and ($to == "ready" or $to == "blocked"));
    reduce .[] as $event (
      {next_seq: 1, nodes: {}, idempotency_keys: {}, error: ""};
      if .error != "" then .
      elif $event.seq != .next_seq then
        .error = ("sequence " + ($event.seq | tostring) + " is not the expected next sequence " + (.next_seq | tostring))
      elif .idempotency_keys[$event.idempotency_key] != null then
        .error = ("idempotency key is reused: " + $event.idempotency_key)
      elif ((.nodes[$event.node].state // "pending") != $event.from) then
        .error = ("node " + $event.node + " has a mismatched from state")
      elif (allowed($event.from; $event.to) | not) then
        .error = ("node " + $event.node + " has an illegal transition")
      else
        .nodes[$event.node] = {state: $event.to, attempt: $event.attempt}
        | .idempotency_keys[$event.idempotency_key] = true
        | .next_seq += 1
      end
    ) | .error
  ' "$ledger" 2>/dev/null) || {
    event_invalid 'ledger transition replay failed'
    return 2
  }
  [ -z "$transition_check" ] || {
    event_invalid "$transition_check"
    return 2
  }
}

# The checkpoint is strictly disposable derived data.  It is accepted only
# when its run/graph scope and an exact identity, byte count, and content hash
# all match the current JSONL audit ledger.  A miss always falls back to the
# strict validator above; no caller may treat this as a source of truth.
checkpoint_path() {
  printf '%s.checkpoint\n' "$1"
}

ledger_inode() {
  ls -di "$1" | awk '{print $1}'
}

ledger_size() {
  wc -c < "$1" | tr -d ' '
}

ledger_hash() {
  cksum "$1" | awk '{print $1}'
}

checkpoint_matches() {
  local ledger="$1" run_id="$2" graph_id="$3" checkpoint inode size hash
  [ -f "$ledger" ] || return 1
  checkpoint=$(checkpoint_path "$ledger")
  [ -f "$checkpoint" ] || return 1
  inode=$(ledger_inode "$ledger") || return 1
  size=$(ledger_size "$ledger") || return 1
  hash=$(ledger_hash "$ledger") || return 1
  jq -e --arg run_id "$run_id" --arg graph_id "$graph_id" --arg inode "$inode" \
    --arg hash "$hash" --argjson size "$size" '
      .checkpoint_schema == 1
      and .run_id == $run_id and .graph_id == $graph_id
      and .ledger_inode == $inode and .ledger_size == $size and .ledger_hash == $hash
      and (.last_seq | type == "number" and floor == . and . >= 0)
      and (.nodes | type == "object"
           and all(.[]; type == "object"
             and (.state | type == "string")
             and (.attempt | type == "number" and floor == . and . >= 0)))
      and (.idempotency_keys | type == "object" and all(.[]; . == true))
    ' "$checkpoint" >/dev/null 2>&1
}

write_checkpoint_from_ledger() {
  local ledger="$1" run_id="$2" graph_id="$3" checkpoint tmp inode size hash
  [ -f "$ledger" ] || return 1
  checkpoint=$(checkpoint_path "$ledger")
  inode=$(ledger_inode "$ledger") || return 1
  size=$(ledger_size "$ledger") || return 1
  hash=$(ledger_hash "$ledger") || return 1
  tmp=$(mktemp "${checkpoint}.XXXXXX") || return 1
  jq -cs --arg run_id "$run_id" --arg graph_id "$graph_id" --arg inode "$inode" \
    --arg hash "$hash" --argjson size "$size" '
      reduce .[] as $event (
        {last_seq: 0, nodes: {}, idempotency_keys: {}};
        .last_seq = $event.seq
        | .nodes[$event.node] = {state: $event.to, attempt: $event.attempt}
        | .idempotency_keys[$event.idempotency_key] = true
      )
      | {checkpoint_schema: 1, run_id: $run_id, graph_id: $graph_id,
         ledger_inode: $inode, ledger_size: $size, ledger_hash: $hash,
         last_seq: .last_seq, nodes: .nodes, idempotency_keys: .idempotency_keys}
    ' "$ledger" > "$tmp" || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$checkpoint"
}

update_checkpoint_after_append() {
  local ledger="$1" run_id="$2" graph_id="$3" node="$4" to="$5" attempt="$6"
  local seq="$7" idempotency_key="$8" checkpoint tmp inode size hash
  checkpoint=$(checkpoint_path "$ledger")
  [ -f "$checkpoint" ] || return 1
  inode=$(ledger_inode "$ledger") || return 1
  size=$(ledger_size "$ledger") || return 1
  hash=$(ledger_hash "$ledger") || return 1
  tmp=$(mktemp "${checkpoint}.XXXXXX") || return 1
  jq -cS --arg run_id "$run_id" --arg graph_id "$graph_id" --arg inode "$inode" \
    --arg hash "$hash" --arg node "$node" --arg to "$to" --arg key "$idempotency_key" \
    --argjson size "$size" --argjson attempt "$attempt" --argjson seq "$seq" '
      .checkpoint_schema = 1
      | .run_id = $run_id | .graph_id = $graph_id
      | .ledger_inode = $inode | .ledger_size = $size | .ledger_hash = $hash
      | .last_seq = $seq
      | .nodes[$node] = {state: $to, attempt: $attempt}
      | .idempotency_keys[$key] = true
    ' "$checkpoint" > "$tmp" || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$checkpoint"
}

checkpoint_context() {
  local ledger="$1" node="$2" idempotency_key="$3"
  jq -r --arg node "$node" --arg key "$idempotency_key" '
    [.last_seq, (.idempotency_keys[$key] // false), (.nodes[$node].state // "pending")]
    | @tsv
  ' "$(checkpoint_path "$ledger")"
}

validate_ledger() {
  local ledger="$1" run_id="$2" graph_id="$3"
  checkpoint_matches "$ledger" "$run_id" "$graph_id" && return 0
  strict_validate_ledger "$ledger" "$run_id" "$graph_id"
}

LOCK_DIR=''

release_lock() {
  [ -n "$LOCK_DIR" ] || return 0
  rm -f "$LOCK_DIR/pid" "$LOCK_DIR/created_at"
  rmdir "$LOCK_DIR" 2>/dev/null || true
  LOCK_DIR=''
}

reclaim_stale_lock() {
  local lock_dir="$1" pid created_at now stale_after stale_dir
  [ -f "$lock_dir/pid" ] && [ -f "$lock_dir/created_at" ] || return 1
  pid=$(sed -n '1p' "$lock_dir/pid" 2>/dev/null) || return 1
  created_at=$(sed -n '1p' "$lock_dir/created_at" 2>/dev/null) || return 1
  valid_integer "$pid" && valid_integer "$created_at" || return 1
  now=$(date +%s)
  stale_after="${POLYLANE_EVENT_LOCK_STALE_SECONDS:-30}"
  valid_integer "$stale_after" || stale_after=30
  [ $((now - created_at)) -ge "$stale_after" ] || return 1
  kill -0 "$pid" 2>/dev/null && return 1
  stale_dir="${lock_dir}.stale.$$"
  mv "$lock_dir" "$stale_dir" 2>/dev/null || return 1
  rm -rf "$stale_dir"
  return 0
}

acquire_lock() {
  local ledger="$1" lock_dir retries=0
  lock_dir="${ledger}.lock"
  while ! mkdir "$lock_dir" 2>/dev/null; do
    reclaim_stale_lock "$lock_dir" || true
    retries=$((retries + 1))
    [ "$retries" -lt 400 ] || {
      event_invalid "could not acquire ledger lock: $lock_dir"
      return 2
    }
    sleep 0.05
  done
  LOCK_DIR="$lock_dir"
  printf '%s\n' "$$" > "$LOCK_DIR/pid"
  date +%s > "$LOCK_DIR/created_at"
}

append_event() {
  local ledger="$1" run_id="$2" graph_id="$3" node="$4" from="$5" to="$6"
  local attempt="$7" idempotency_key="$8" reason="${9:-}" current_state next_seq timestamp row has_key
  local checkpoint_ready=false checkpoint_data last_seq

  valid_id "$run_id" && valid_id "$graph_id" && valid_id "$node" && valid_id "$idempotency_key" || {
    event_invalid 'run_id, graph_id, node, and idempotency_key must be well-formed identifiers'
    return 2
  }
  valid_integer "$attempt" || {
    event_invalid 'attempt must be a non-negative integer'
    return 2
  }
  allowed_transition "$from" "$to" || {
    event_invalid "illegal transition: $from -> $to"
    return 2
  }
  mkdir -p "$(dirname "$ledger")" || return 1
  event_disk_guard "$(dirname "$ledger")" || return 1
  acquire_lock "$ledger" || return $?
  trap 'release_lock' EXIT HUP INT TERM
  validate_ledger "$ledger" "$run_id" "$graph_id" || return $?
  # The empty file is created only while holding the writer lock. This keeps a
  # first append on a new ledger from asking jq to open a non-existent input.
  [ -e "$ledger" ] || : > "$ledger"

  if ! checkpoint_matches "$ledger" "$run_id" "$graph_id"; then
    write_checkpoint_from_ledger "$ledger" "$run_id" "$graph_id" || true
  fi
  if checkpoint_matches "$ledger" "$run_id" "$graph_id"; then
    checkpoint_data=$(checkpoint_context "$ledger" "$node" "$idempotency_key") || checkpoint_data=''
    if [ -n "$checkpoint_data" ]; then
      IFS='	' read -r last_seq has_key current_state <<EOF
$checkpoint_data
EOF
      checkpoint_ready=true
    fi
  fi

  if [ "$checkpoint_ready" = true ]; then
    :
  else
    has_key=$(jq -r -s --arg key "$idempotency_key" 'any(.[]; .idempotency_key == $key)' "$ledger")
  fi
  if [ "$has_key" = 'true' ]; then
    jq -e --arg run_id "$run_id" --arg graph_id "$graph_id" --arg node "$node" \
      --arg from "$from" --arg to "$to" --argjson attempt "$attempt" --arg key "$idempotency_key" \
      --arg reason "$reason" '
        select(.idempotency_key == $key)
        | .run_id == $run_id and .graph_id == $graph_id and .node == $node
          and .from == $from and .to == $to and .attempt == $attempt
          and .reason == $reason and .artifact_hash == ""
      ' "$ledger" >/dev/null && return 0
    event_invalid "idempotency key conflicts with an existing event: $idempotency_key"
    return 2
  fi

  if [ "$checkpoint_ready" = true ]; then
    :
  else
    current_state=$(jq -r -s --arg node "$node" '
      [.[] | select(.node == $node)]
      | if length == 0 then "pending" else .[-1].to end
    ' "$ledger" 2>/dev/null)
  fi
  [ "$current_state" = "$from" ] || {
    event_invalid "node $node is $current_state, not $from"
    return 2
  }
  if [ "$checkpoint_ready" = true ]; then
    next_seq=$((last_seq + 1))
  else
    next_seq=$(( $(wc -l < "$ledger" | tr -d ' ') + 1 ))
  fi
  timestamp=$(date +%s)
  row=$(jq -cn --argjson seq "$next_seq" --argjson timestamp "$timestamp" \
    --arg run_id "$run_id" --arg graph_id "$graph_id" --arg node "$node" \
    --arg from "$from" --arg to "$to" --argjson attempt "$attempt" \
    --arg idempotency_key "$idempotency_key" --arg reason "$reason" '
      {event_schema: 1, seq: $seq, timestamp: $timestamp, run_id: $run_id,
       graph_id: $graph_id, node: $node, from: $from, to: $to, attempt: $attempt,
       idempotency_key: $idempotency_key, reason: $reason, artifact_hash: ""}
    ')
  # The row is a single bounded write under the lock.  A deterministic failure
  # is injected before that write, so a valid prior ledger is never modified.
  [ "${POLYLANE_TEST_EVENT_APPEND_FAIL:-0}" != 1 ] || return 1
  printf '%s\n' "$row" >> "$ledger" || return 1
  if [ "$checkpoint_ready" = true ]; then
    update_checkpoint_after_append "$ledger" "$run_id" "$graph_id" "$node" "$to" "$attempt" \
      "$next_seq" "$idempotency_key" || true
  fi
}

replay_ledger() {
  local ledger="$1" run_id="$2" graph_id="$3"
  validate_ledger "$ledger" "$run_id" "$graph_id" || return $?
  if [ ! -e "$ledger" ]; then
    jq -cnS --arg run_id "$run_id" --arg graph_id "$graph_id" \
      '{run_id: $run_id, graph_id: $graph_id, last_seq: 0, nodes: {}}'
    return 0
  fi
  if checkpoint_matches "$ledger" "$run_id" "$graph_id"; then
    jq -cS '{run_id: .run_id, graph_id: .graph_id, last_seq: .last_seq, nodes: .nodes}' \
      "$(checkpoint_path "$ledger")"
    return 0
  fi
  jq -cS -s --arg run_id "$run_id" --arg graph_id "$graph_id" '
    reduce .[] as $event (
      {next_seq: 1, nodes: {}};
      .nodes[$event.node] = {state: $event.to, attempt: $event.attempt}
      | .next_seq += 1
    )
    | {run_id: $run_id, graph_id: $graph_id, last_seq: (.next_seq - 1), nodes: .nodes}
  ' "$ledger"
}

main() {
  set -euo pipefail
  [ "$#" -ge 1 ] || { usage >&2; exit 2; }
  case "$1" in
    append)
      [ "$#" -ge 9 ] && [ "$#" -le 10 ] || { usage >&2; exit 2; }
      append_event "${2:-}" "${3:-}" "${4:-}" "${5:-}" "${6:-}" "${7:-}" "${8:-}" "${9:-}" "${10:-}"
      ;;
    replay)
      [ "$#" -eq 4 ] || { usage >&2; exit 2; }
      replay_ledger "$2" "$3" "$4"
      ;;
    verify)
      [ "$#" -eq 4 ] || { usage >&2; exit 2; }
      validate_ledger "$2" "$3" "$4"
      ;;
    -h|--help) usage ;;
    *) usage >&2; exit 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
