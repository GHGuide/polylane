#!/usr/bin/env bash
# polylane-workers.sh — durable, bounded worker continuity state.
# Bash 3.2 + jq only. State is always rooted under the supplied canonical project.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: polylane-workers.sh <operation> <project> [arguments]
  capsule      PROJECT NAME EXPECTED_VERSION ROLE CYCLE STATUS SUMMARY CONTEXT EVIDENCE
  show         PROJECT NAME
  send         PROJECT FROM TO CYCLE MESSAGE
  inbox        PROJECT RECIPIENT
  ack          PROJECT RECIPIENT MESSAGE_ID
  import-relay PROJECT RELAY_JSONL CYCLE
  resume       PROJECT NAME MAX_BYTES
EOF
  exit 2
}

die() { printf 'polylane-workers: %s\n' "$*" >&2; exit 2; }
missing() { printf 'polylane-workers: %s\n' "$*" >&2; exit 4; }
stale() { printf 'polylane-workers: %s\n' "$*" >&2; exit 75; }
require_jq() { command -v jq >/dev/null 2>&1 || die 'jq is required'; }

LOCK_DIR=''
LOCK_TOKEN=''

now_epoch() { date +%s; }
now_iso() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
lock_ttl() { printf '%s' "${POLYLANE_WORKER_LOCK_TTL:-120}"; }

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
  local state="$1" now recorded stale moved
  LOCK_DIR="$state/.lock"
  LOCK_TOKEN="$$.${RANDOM:-0}.$(now_epoch)"
  while :; do
    if mkdir "$LOCK_DIR" 2>/dev/null; then
      printf '%s\n' "$LOCK_TOKEN" > "$LOCK_DIR/owner"
      now_epoch > "$LOCK_DIR/created_at"
      return 0
    fi
    now=$(now_epoch)
    recorded=$(cat "$LOCK_DIR/created_at" 2>/dev/null || printf 0)
    case "$recorded" in *[!0-9]*|'') recorded=0 ;; esac
    stale=$((now - recorded))
    if [ "$stale" -gt "$(lock_ttl)" ] 2>/dev/null; then
      moved="${LOCK_DIR}.stale.${LOCK_TOKEN}"
      if mv "$LOCK_DIR" "$moved" 2>/dev/null; then
        rm -rf "$moved"
      fi
      continue
    fi
    sleep 1
  done
}

project_path() {
  [ $# -eq 1 ] || die 'project path is required'
  [ -d "$1" ] || die "project is not a directory: $1"
  (cd "$1" && pwd -P)
}

git_common_dir() {
  local project="$1" common
  common=$(git -C "$project" rev-parse --git-common-dir 2>/dev/null) || return 1
  case "$common" in
    /*) (cd "$common" && pwd -P) ;;
    *) (cd "$project/$common" && pwd -P) ;;
  esac
}

# A lane's positional project is its local checkout, not an authority for
# shared coordination.  The launcher provides an absolute canonical root to
# every lane.  Standalone callers deliberately retain the historical local
# project behavior when that explicit runtime contract is absent.
canonical_project_path() {
  local requested="$1" contract workers canonical expected_workers requested_git canonical_git
  requested=$(project_path "$requested")
  contract="${POLYLANE_PROJECT_ROOT:-}"
  workers="${POLYLANE_WORKERS_DIR:-}"
  # The paired exports are emitted together by polylane-run for a lane.  A
  # root alone is common in parent shells and is not sufficient to redirect a
  # standalone caller's durable state.
  if [ -z "$contract" ] || [ -z "$workers" ]; then
    printf '%s\n' "$requested"
    return 0
  fi
  case "$contract" in /*) ;; *) die 'POLYLANE_PROJECT_ROOT must be an absolute directory' ;; esac
  case "$workers" in /*) ;; *) die 'POLYLANE_WORKERS_DIR must be an absolute directory' ;; esac
  canonical=$(project_path "$contract")
  # Compare the paired exports in their launcher spelling before resolving the
  # root physically: /var may be a symlink to /private/var on macOS.
  expected_workers="$contract/docs/polylane/workers"
  [ "$workers" = "$expected_workers" ] || die 'POLYLANE_WORKERS_DIR does not match POLYLANE_PROJECT_ROOT'
  [ "$requested" = "$canonical" ] && { printf '%s\n' "$canonical"; return 0; }
  requested_git=$(git_common_dir "$requested" 2>/dev/null || true)
  # A plain directory is an ordinary standalone-project invocation, even when
  # a parent shell happens to export a lane contract for another project.
  [ -n "$requested_git" ] || { printf '%s\n' "$requested"; return 0; }
  canonical_git=$(git_common_dir "$canonical" 2>/dev/null || true)
  [ -n "$canonical_git" ] && [ "$requested_git" = "$canonical_git" ] ||
    die 'project is outside the declared canonical project'
  printf '%s\n' "$canonical"
}

safe_child_dir() {
  local name="$2" child="$1/$2"
  [ ! -L "$child" ] || die "refusing symlinked runtime path: $child"
  if [ ! -e "$child" ]; then mkdir "$child" || die "cannot create runtime path: $child"; fi
  [ -d "$child" ] || die "runtime path is not a directory: $child"
}

state_for_write() {
  local project="$1"
  safe_child_dir "$project" docs
  safe_child_dir "$project/docs" polylane
  safe_child_dir "$project/docs/polylane" workers
  safe_child_dir "$project/docs/polylane/workers" capsules
  printf '%s\n' "$project/docs/polylane/workers"
}

state_for_read() {
  local project="$1" state="$1/docs/polylane/workers"
  [ ! -L "$state" ] || die "refusing symlinked runtime path: $state"
  [ -d "$state" ] || missing 'worker runtime is absent'
  [ ! -L "$state/capsules" ] || die "refusing symlinked capsule path: $state/capsules"
  [ -d "$state/capsules" ] || missing 'worker runtime is absent'
  printf '%s\n' "$state"
}

valid_name() {
  printf '%s' "$1" | LC_ALL=C grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*$'
}

valid_uint() {
  case "$1" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac
}

# A run scope is optional for standalone compatibility, but when the launcher
# provides one it is an authority boundary rather than arbitrary JSON text.
worker_run_id() {
  local run_id="${POLYLANE_WORKER_RUN_ID:-}"
  [ -z "$run_id" ] && { printf '\n'; return 0; }
  valid_name "$run_id" || die 'POLYLANE_WORKER_RUN_ID must use only A-Za-z0-9._-'
  require_bounded POLYLANE_WORKER_RUN_ID "$run_id" "$(limit_value POLYLANE_WORKER_RUN_ID_MAX_BYTES 128)"
  printf '%s\n' "$run_id"
}

limit_value() {
  local value="${!1:-$2}"
  valid_uint "$value" && [ "$value" -gt 0 ] || die "invalid byte limit: $1"
  printf '%s\n' "$value"
}

within_bytes() {
  local value="$1" limit="$2" size
  size=$(LC_ALL=C printf '%s' "$value" | wc -c | tr -d ' ')
  [ "$size" -le "$limit" ]
}

require_bounded() {
  local label="$1" value="$2" limit="$3"
  within_bytes "$value" "$limit" || die "$label exceeds ${limit} bytes"
}

# Worker continuity state is durable project material, not a credential store.
# This deliberately recognizes only clear credential forms, avoiding a blanket
# ban on ordinary prose such as "token budget" or "secretary".
contains_credential() {
  LC_ALL=C printf '%s\n' "$1" | grep -Eiq \
    '(api[_-]?key|password|secret|access[_-]?token|token)[[:space:]]*[:=]|-----BEGIN( [A-Z]+)? PRIVATE KEY-----|(^|[^[:alnum:]_])sk-[A-Za-z0-9_-]{8,}($|[^[:alnum:]_-])'
}

reject_credential() {
  local label="$1" value="$2"
  if contains_credential "$value"; then
    die "$label contains credential-shaped content"
  fi
}

capsule_path() { printf '%s/capsules/%s.json\n' "$1" "$2"; }
history_path() { printf '%s/history.jsonl\n' "$1"; }

require_capsule() {
  local state="$1" name="$2" file
  valid_name "$name" || die "invalid worker name: $name"
  file=$(capsule_path "$state" "$name")
  [ ! -L "$file" ] || die "refusing symlinked capsule: $file"
  [ -f "$file" ] || missing "worker identity is absent: $name"
  jq -e 'type == "object" and (.name | type == "string") and (.version | type == "number")' "$file" >/dev/null || die "invalid capsule: $name"
}

append_history() {
  local state="$1" payload="$2" history seq line
  history=$(history_path "$state")
  [ ! -L "$history" ] || die "refusing symlinked history: $history"
  lock_owned || stale 'lost worker lock before history append'
  if [ -f "$history" ]; then seq=$(( $(wc -l < "$history") + 1 )); else seq=1; fi
  line=$(jq -cn --argjson seq "$seq" --arg at "${POLYLANE_WORKER_NOW:-$(now_iso)}" --argjson payload "$payload" '$payload + {seq:$seq,at:$at}')
  lock_owned || stale 'worker lock changed before history append'
  printf '%s\n' "$line" >> "$history"
  printf '%s\n' "$line"
}

capsule() {
  local project="$1" name="$2" expected="$3" role="$4" cycle="$5" status="$6" summary="$7" context="$8" evidence="$9"
  local state file current version tmp payload line
  valid_name "$name" || die "invalid worker name: $name"
  valid_uint "$expected" && valid_uint "$cycle" || die 'version and cycle must be non-negative integers'
  require_bounded role "$role" "$(limit_value POLYLANE_WORKER_ROLE_MAX_BYTES 256)"
  require_bounded status "$status" "$(limit_value POLYLANE_WORKER_STATUS_MAX_BYTES 64)"
  require_bounded summary "$summary" "$(limit_value POLYLANE_WORKER_SUMMARY_MAX_BYTES 4096)"
  require_bounded context "$context" "$(limit_value POLYLANE_WORKER_CONTEXT_MAX_BYTES 8192)"
  require_bounded evidence "$evidence" "$(limit_value POLYLANE_WORKER_EVIDENCE_MAX_BYTES 4096)"
  reject_credential role "$role"
  reject_credential status "$status"
  reject_credential summary "$summary"
  reject_credential context "$context"
  reject_credential evidence "$evidence"
  project=$(canonical_project_path "$project")
  state=$(state_for_write "$project")
  file=$(capsule_path "$state" "$name")
  acquire_lock "$state"; trap 'release_lock' EXIT HUP INT TERM
  [ ! -L "$file" ] || die "refusing symlinked capsule: $file"
  if [ -f "$file" ]; then
    current=$(jq -r .version "$file" 2>/dev/null) || die "invalid capsule: $name"
    [ "$current" = "$expected" ] || stale "stale capsule version for $name (expected $expected, current $current)"
    version=$((current + 1))
  else
    [ "$expected" = 0 ] || stale "worker identity is absent: $name"
    version=1
  fi
  tmp="$file.tmp.$$.${RANDOM:-0}"
  jq -cn --arg name "$name" --arg role "$role" --argjson last_cycle "$cycle" --arg status "$status" \
    --arg summary "$summary" --arg context "$context" --arg evidence "$evidence" --argjson version "$version" \
    '{name:$name,role:$role,last_cycle:$last_cycle,version:$version,status:$status,summary:$summary,context:$context,evidence:$evidence}' > "$tmp"
  mv "$tmp" "$file"
  payload=$(jq -cn --arg id "capsule:$name:$version" --arg worker "$name" --argjson version "$version" --argjson cycle "$cycle" '{event:"capsule",id:$id,worker:$worker,version:$version,cycle:$cycle}')
  append_history "$state" "$payload" >/dev/null
  release_lock; trap - EXIT HUP INT TERM
  jq -c . "$file"
}

send_message() {
  local project="$1" from="$2" to="$3" cycle="$4" message="$5" run_id
  local state history seq id payload line
  valid_name "$from" && valid_name "$to" || die 'invalid sender or recipient name'
  valid_uint "$cycle" || die 'cycle must be a non-negative integer'
  require_bounded message "$message" "$(limit_value POLYLANE_WORKER_MESSAGE_MAX_BYTES 4096)"
  reject_credential message "$message"
  run_id=$(worker_run_id)
  project=$(canonical_project_path "$project"); state=$(state_for_write "$project")
  acquire_lock "$state"; trap 'release_lock' EXIT HUP INT TERM
  require_capsule "$state" "$from"; require_capsule "$state" "$to"
  history=$(history_path "$state")
  if [ -f "$history" ]; then seq=$(( $(wc -l < "$history") + 1 )); else seq=1; fi
  id="message:$seq"
  payload=$(jq -cn --arg id "$id" --arg from "$from" --arg to "$to" --argjson cycle "$cycle" --arg message "$message" --arg run_id "$run_id" \
    '{event:"message",id:$id,from:$from,to:$to,cycle:$cycle,message:$message} + (if $run_id == "" then {} else {run_id:$run_id} end)')
  line=$(append_history "$state" "$payload")
  release_lock; trap - EXIT HUP INT TERM
  printf '%s\n' "$line" | jq -c '{id,from,to,cycle,message,run_id,seq,at} | with_entries(select(.value != null))'
}

inbox_json() {
  local project="$1" recipient="$2" state history run_id
  valid_name "$recipient" || die "invalid worker name: $recipient"
  run_id=$(worker_run_id)
  project=$(canonical_project_path "$project"); state=$(state_for_read "$project")
  require_capsule "$state" "$recipient"
  history=$(history_path "$state")
  if [ ! -s "$history" ]; then printf '%s\n' '[]'; return 0; fi
  jq -cs --arg recipient "$recipient" --arg run_id "$run_id" '
    . as $events
    | [$events[] | select(.event == "ack" and .recipient == $recipient and ($run_id == "" or .run_id == $run_id)) | .message_id] as $acks
    | [$events[]
       | select((.event == "message" and .to == $recipient) or
                (.event == "relay-import" and .relay.event == "request" and .relay.to == $recipient))
       | select($run_id == "" or .run_id == $run_id)
       | if .event == "message" then
           {id,from,to,cycle,message,run_id,source:"durable"}
         else
           {id,from:.relay.lane,to:.relay.to,cycle,message:.relay.message,run_id,source:"relay",relay:.relay}
         end
       | select(.id as $id | ($acks | index($id) | not))]
  ' "$history"
}

ack_message() {
  local project="$1" recipient="$2" message_id="$3" state history payload run_id
  valid_name "$recipient" || die "invalid worker name: $recipient"
  run_id=$(worker_run_id)
  project=$(canonical_project_path "$project"); state=$(state_for_write "$project")
  acquire_lock "$state"; trap 'release_lock' EXIT HUP INT TERM
  require_capsule "$state" "$recipient"; history=$(history_path "$state")
  [ -s "$history" ] || missing "message is absent for recipient: $recipient"
  jq -se --arg recipient "$recipient" --arg id "$message_id" --arg run_id "$run_id" '
    any(.[]; (((.event == "message" and .to == $recipient and .id == $id) or
               (.event == "relay-import" and .relay.event == "request" and .relay.to == $recipient and .id == $id))
              and ($run_id == "" or .run_id == $run_id)))
  ' "$history" >/dev/null || missing "message is absent for recipient: $recipient"
  if jq -se --arg recipient "$recipient" --arg id "$message_id" --arg run_id "$run_id" 'any(.[]; .event == "ack" and .recipient == $recipient and .message_id == $id and ($run_id == "" or .run_id == $run_id))' "$history" >/dev/null; then
    release_lock; trap - EXIT HUP INT TERM
    jq -cn --arg recipient "$recipient" --arg id "$message_id" '{recipient:$recipient,message_id:$id,idempotent:true}'
    return 0
  fi
  payload=$(jq -cn --arg id "ack:$recipient:$message_id" --arg recipient "$recipient" --arg message_id "$message_id" --arg run_id "$run_id" \
    '{event:"ack",id:$id,recipient:$recipient,message_id:$message_id} + (if $run_id == "" then {} else {run_id:$run_id} end)')
  append_history "$state" "$payload" >/dev/null
  release_lock; trap - EXIT HUP INT TERM
  jq -cn --arg recipient "$recipient" --arg id "$message_id" '{recipient:$recipient,message_id:$id,idempotent:false}'
}

canonical_relay_path() {
  local relay="$1" project="$2" absolute
  [ -f "$relay" ] && [ ! -L "$relay" ] || die "relay is not a regular file: $relay"
  absolute="$(cd "$(dirname "$relay")" && pwd -P)/$(basename "$relay")"
  case "$absolute" in "$project"/.polylane/*) ;; *) die 'relay must remain inside the canonical project .polylane directory' ;; esac
  printf '%s\n' "$absolute"
}

import_relay() {
  local project="$1" relay="$2" cycle="$3" state source history relay_line relay_seq raw_size id payload imported=0 run_id
  valid_uint "$cycle" || die 'cycle must be a non-negative integer'
  run_id=$(worker_run_id)
  project=$(canonical_project_path "$project"); source=$(canonical_relay_path "$relay" "$project")
  jq -e -n 'all(inputs; type == "object" and (.event | type == "string") and (.seq | type == "number") and (.at | type == "string"))' "$source" >/dev/null || die 'relay is not valid public JSONL'
  state=$(state_for_write "$project")
  acquire_lock "$state"; trap 'release_lock' EXIT HUP INT TERM
  history=$(history_path "$state")
  while IFS= read -r relay_line || [ -n "$relay_line" ]; do
    raw_size=$(LC_ALL=C printf '%s' "$relay_line" | wc -c | tr -d ' ')
    [ "$raw_size" -le "$(limit_value POLYLANE_WORKER_RELAY_EVENT_MAX_BYTES 8192)" ] || die 'relay event exceeds byte limit'
    reject_credential 'relay event' "$relay_line"
    relay_seq=$(printf '%s\n' "$relay_line" | jq -r .seq)
    if [ -s "$history" ] && jq -se --arg source "$source" --argjson relay_seq "$relay_seq" 'any(.[]; .event == "relay-import" and .relay_source == $source and .relay_seq == $relay_seq)' "$history" >/dev/null; then
      continue
    fi
    id="relay:$source:$relay_seq"
    payload=$(jq -cn --arg id "$id" --arg source "$source" --argjson relay_seq "$relay_seq" --argjson cycle "$cycle" --argjson relay "$relay_line" --arg run_id "$run_id" \
      '{event:"relay-import",id:$id,relay_source:$source,relay_seq:$relay_seq,cycle:$cycle,relay:$relay} + (if $run_id == "" then {} else {run_id:$run_id} end)')
    append_history "$state" "$payload" >/dev/null
    imported=$((imported + 1))
  done < "$source"
  release_lock; trap - EXIT HUP INT TERM
  jq -cn --argjson imported "$imported" '{imported:$imported}'
}

resume_packet() {
  local project="$1" name="$2" maximum="$3" state file capsule pending packet size truncated=false
  valid_name "$name" || die "invalid worker name: $name"
  valid_uint "$maximum" && [ "$maximum" -ge 256 ] || die 'resume MAX_BYTES must be an integer of at least 256'
  project=$(canonical_project_path "$project"); state=$(state_for_read "$project"); require_capsule "$state" "$name"
  file=$(capsule_path "$state" "$name")
  capsule=$(jq -c '.summary = (.summary[0:128]) | .context = (.context[0:128]) | .evidence = (.evidence[0:128])' "$file")
  pending=$(inbox_json "$project" "$name" | jq -c '[.[] | .message = (.message[0:256]) | del(.relay)]')
  while :; do
    packet=$(jq -cn --arg worker "$name" --argjson capsule "$capsule" --argjson pending "$pending" --argjson truncated "$truncated" \
      '{worker:$worker,sources:{capsule:"capsule",inbox:"durable-inbox"},truncated:$truncated,capsule:$capsule,pending:$pending}')
    size=$(LC_ALL=C printf '%s' "$packet" | wc -c | tr -d ' ')
    [ "$size" -le "$maximum" ] && { printf '%s\n' "$packet"; return 0; }
    if [ "$(printf '%s' "$capsule" | jq -r '(.summary | length) + (.context | length) + (.evidence | length)')" -gt 0 ]; then
      capsule=$(printf '%s' "$capsule" | jq -c '.summary="" | .context="" | .evidence=""')
      truncated=true
    elif [ "$(printf '%s' "$pending" | jq length)" -gt 0 ]; then
      pending=$(printf '%s' "$pending" | jq -c '.[1:]')
      truncated=true
    else
      die 'resume packet cannot fit requested byte limit'
    fi
  done
}

main() {
  local operation="${1:-}"
  [ -n "$operation" ] || usage
  shift
  require_jq
  case "$operation" in
    capsule) [ $# -eq 9 ] || usage; capsule "$@" ;;
    show) [ $# -eq 2 ] || usage; local_show "$@" ;;
    send) [ $# -eq 5 ] || usage; send_message "$@" ;;
    inbox) [ $# -eq 2 ] || usage; inbox_json "$@" ;;
    ack) [ $# -eq 3 ] || usage; ack_message "$@" ;;
    import-relay) [ $# -eq 3 ] || usage; import_relay "$@" ;;
    resume) [ $# -eq 3 ] || usage; resume_packet "$@" ;;
    *) usage ;;
  esac
}

local_show() {
  local project="$1" name="$2" state file
  valid_name "$name" || die "invalid worker name: $name"
  project=$(canonical_project_path "$project"); state=$(state_for_read "$project"); require_capsule "$state" "$name"
  file=$(capsule_path "$state" "$name")
  jq -c . "$file"
}

main "$@"
