#!/usr/bin/env bash
# polylane-coordinate.sh — canonical, append-only cross-lane relay.
# Bash 3.2 + jq only.  Every mutation holds a directory lock; readers replay JSONL.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: polylane-coordinate.sh <operation> <relay.jsonl> [arguments]
  request  FILE FROM TO MESSAGE
  decision FILE LANE DECISION RATIONALE
  claim    FILE LANE RESOURCE
  release  FILE LANE RESOURCE
  pending  FILE
  snapshot FILE
EOF
  exit 2
}

require_jq() { command -v jq >/dev/null 2>&1 || { echo "polylane-coordinate: jq is required" >&2; exit 2; }; }

lock_now() { date +%s; }
lock_ttl() { printf '%s' "${POLYLANE_COORDINATION_LOCK_TTL:-120}"; }
LOCK_DIR=""
LOCK_TOKEN=""

lock_owned() {
  [ -n "$LOCK_DIR" ] && [ -f "$LOCK_DIR/owner" ] &&
    [ "$(cat "$LOCK_DIR/owner" 2>/dev/null || true)" = "$LOCK_TOKEN" ]
}

release_lock() {
  lock_owned || return 0
  rm -f "$LOCK_DIR/owner" "$LOCK_DIR/created_at"
  rmdir "$LOCK_DIR" 2>/dev/null || true
}

acquire_lock() {
  local file="$1" now recorded_at stale moved
  LOCK_DIR="${file}.lock"
  LOCK_TOKEN="$$.${RANDOM:-0}.$(lock_now)"
  while :; do
    if mkdir "$LOCK_DIR" 2>/dev/null; then
      printf '%s\n' "$LOCK_TOKEN" > "$LOCK_DIR/owner"
      lock_now > "$LOCK_DIR/created_at"
      return 0
    fi
    now=$(lock_now)
    recorded_at=$(cat "$LOCK_DIR/created_at" 2>/dev/null || printf 0)
    case "$recorded_at" in *[!0-9]*|'') recorded_at=0 ;; esac
    stale=$((now - recorded_at))
    if [ "$stale" -gt "$(lock_ttl)" ] 2>/dev/null; then
      # Rename is atomic.  We still loop and win a NEW lock before writing; an
      # old owner verifies its token immediately before append and cannot write.
      moved="${LOCK_DIR}.stale.${LOCK_TOKEN}"
      if mv "$LOCK_DIR" "$moved" 2>/dev/null; then
        rm -rf "$moved"
      fi
      continue
    fi
    sleep 1
  done
}

snapshot_json() {
  local file="$1"
  if [ -s "$file" ]; then
    jq -cs '
      . as $events
      | (reduce $events[] as $event ({};
          if $event.event == "claim" then .[$event.resource] = $event
          elif $event.event == "release" and .[$event.resource].lane == $event.lane
          then del(.[$event.resource]) else . end)) as $claims
      | {events: $events, claims: $claims}
    ' "$file"
  else
    printf '%s\n' '{"events":[],"claims":{}}'
  fi
}

pending_json() {
  local file="$1"
  snapshot_json "$file" | jq -c '{requests: [.events[] | select(.event == "request")], claims: .claims}'
}

append_event() {
  local file="$1" payload="$2" seq line
  mkdir -p "$(dirname "$file")"
  acquire_lock "$file"
  trap 'release_lock' EXIT HUP INT TERM
  lock_owned || { echo "polylane-coordinate: lost relay lock before write" >&2; exit 75; }
  if [ -f "$file" ]; then seq=$(( $(wc -l < "$file") + 1 )); else seq=1; fi
  line=$(jq -cn --argjson seq "$seq" --arg at "${POLYLANE_COORDINATION_NOW:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}" --argjson payload "$payload" \
    '$payload + {seq: $seq, at: $at}')
  lock_owned || { echo "polylane-coordinate: relay lock changed before write" >&2; exit 75; }
  printf '%s\n' "$line" >> "$file"
  release_lock
  trap - EXIT HUP INT TERM
}

claim_resource() {
  local file="$1" lane="$2" resource="$3" owner payload
  mkdir -p "$(dirname "$file")"
  acquire_lock "$file"
  trap 'release_lock' EXIT HUP INT TERM
  lock_owned || { echo "polylane-coordinate: lost relay lock before claim" >&2; exit 75; }
  owner=$(snapshot_json "$file" | jq -r --arg resource "$resource" '.claims[$resource].lane // empty')
  if [ -n "$owner" ] && [ "$owner" != "$lane" ]; then
    echo "polylane-coordinate: resource '$resource' is claimed by '$owner'" >&2
    exit 75
  fi
  payload=$(jq -cn --arg event claim --arg lane "$lane" --arg resource "$resource" '{event:$event,lane:$lane,resource:$resource}')
  # append_event would attempt a second lock, so append directly under this lock.
  local seq line
  if [ -f "$file" ]; then seq=$(( $(wc -l < "$file") + 1 )); else seq=1; fi
  line=$(jq -cn --argjson seq "$seq" --arg at "${POLYLANE_COORDINATION_NOW:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}" --argjson payload "$payload" '$payload + {seq:$seq,at:$at}')
  lock_owned || { echo "polylane-coordinate: relay lock changed before claim write" >&2; exit 75; }
  printf '%s\n' "$line" >> "$file"
  release_lock
  trap - EXIT HUP INT TERM
}

main() {
  local op="${1:-}" file payload
  [ -n "$op" ] || usage
  shift
  require_jq
  case "$op" in
    request)
      [ $# -eq 4 ] || usage; file="$1"
      payload=$(jq -cn --arg event request --arg lane "$2" --arg to "$3" --arg message "$4" '{event:$event,lane:$lane,to:$to,message:$message}')
      append_event "$file" "$payload" ;;
    decision)
      [ $# -eq 4 ] || usage; file="$1"
      payload=$(jq -cn --arg event decision --arg lane "$2" --arg decision "$3" --arg rationale "$4" '{event:$event,lane:$lane,decision:$decision,rationale:$rationale}')
      append_event "$file" "$payload" ;;
    claim)
      [ $# -eq 3 ] || usage; claim_resource "$1" "$2" "$3" ;;
    release)
      [ $# -eq 3 ] || usage; file="$1"
      payload=$(jq -cn --arg event release --arg lane "$2" --arg resource "$3" '{event:$event,lane:$lane,resource:$resource}')
      append_event "$file" "$payload" ;;
    pending) [ $# -eq 1 ] || usage; pending_json "$1" ;;
    snapshot) [ $# -eq 1 ] || usage; snapshot_json "$1" ;;
    *) usage ;;
  esac
}

main "$@"
