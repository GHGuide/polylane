#!/usr/bin/env bash
# polylane-harness.sh — durable, typed, compare-and-swap harness entries.
set -euo pipefail

command -v jq >/dev/null 2>&1 || { echo "harness: jq required" >&2; exit 1; }

usage() {
  cat >&2 <<'EOF'
usage: polylane-harness.sh init <store>
       polylane-harness.sh create <store> <local|global> <prompt|memory|skill|subagent> <id> <content> <cycle>
       polylane-harness.sh update <store> <scope> <id> <expected-version> <content> <cycle>
       polylane-harness.sh delete <store> <scope> <id> <expected-version> <cycle>
       polylane-harness.sh read <store> <scope> <id> --json
       polylane-harness.sh list <store> [scope] [kind] --json
       polylane-harness.sh history <store> <scope> <id> --json
       polylane-harness.sh rollback <store> <scope> <id> <expected-version> <target-version> <cycle>
EOF
  exit 2
}

safe_id() { case "$1" in ''|*[!A-Za-z0-9._-]*) return 1 ;; *) return 0 ;; esac; }
valid_scope() { [ "$1" = local ] || [ "$1" = global ]; }
valid_kind() { case "$1" in prompt|memory|skill|subagent) return 0 ;; *) return 1 ;; esac; }
valid_cycle() { case "$1" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }
protected_id() { case "$1" in base|system|base-skill|system-instructions) return 0 ;; *) return 1 ;; esac; }
state_file() { printf '%s/state.json\n' "$1"; }
history_file() { printf '%s/history.jsonl\n' "$1"; }
snapshot_file() { printf '%s/versions/%s/%s/v%06d.json\n' "$1" "$2" "$3" "$4"; }

atomic_write() {
  local file="$1" dir base tmp
  dir=$(dirname "$file"); base=$(basename "$file")
  mkdir -p "$dir"
  tmp="$dir/.${base}.tmp.$$"
  cat > "$tmp"
  mv "$tmp" "$file"
}

lock_acquire() {
  local store="$1" lock tries=0 pid
  lock="$store/.lock"
  while ! mkdir "$lock" 2>/dev/null; do
    tries=$((tries + 1))
    if [ -f "$lock/pid" ]; then
      pid=$(sed -n '1p' "$lock/pid" 2>/dev/null || true)
      case "$pid" in ''|*[!0-9]*) pid=0 ;; esac
      if [ "$pid" -gt 1 ] && ! kill -0 "$pid" 2>/dev/null; then
        rm -f "$lock/pid" 2>/dev/null || true
        rmdir "$lock" 2>/dev/null || true
      fi
    fi
    [ "$tries" -lt 100 ] || { echo "harness: store lock timed out" >&2; return 9; }
    sleep 0.05
  done
  printf '%s\n' "$$" > "$lock/pid"
}

lock_release() {
  local lock="$1/.lock"
  rm -f "$lock/pid" 2>/dev/null || true
  rmdir "$lock" 2>/dev/null || true
}

require_store() {
  [ -f "$(state_file "$1")" ] || { echo "harness: store is not initialized: $1" >&2; return 2; }
}

entry_json() { jq -c --arg scope "$2" --arg id "$3" '.entries[$scope][$id] // empty' "$(state_file "$1")"; }

write_snapshot() { printf '%s\n' "$5" | atomic_write "$(snapshot_file "$1" "$2" "$3" "$4")"; }

write_state_entry() {
  local store="$1" scope="$2" id="$3" entry="$4"
  jq --arg scope "$scope" --arg id "$id" --argjson entry "$entry" \
    '.entries[$scope][$id] = $entry' "$(state_file "$store")" | atomic_write "$(state_file "$store")"
}

append_history() {
  local store="$1" action="$2" scope="$3" id="$4" before="$5" after="$6" cycle="$7"
  jq -cn --arg action "$action" --arg scope "$scope" --arg id "$id" --argjson before "$before" \
    --argjson after "$after" --argjson cycle "$cycle" \
    '{action:$action,scope:$scope,id:$id,before:$before,after:$after,cycle:$cycle}' >> "$(history_file "$store")"
}

begin_locked() {
  lock_acquire "$1"
  HARNESS_LOCK_STORE="$1"
  trap 'lock_release "$HARNESS_LOCK_STORE"' EXIT
}

cmd_init() {
  local store="$1"
  mkdir -p "$store"
  lock_acquire "$store"
  HARNESS_LOCK_STORE="$store"
  trap 'lock_release "$HARNESS_LOCK_STORE"' EXIT
  if [ ! -f "$(state_file "$store")" ]; then
    jq -n '{schema:"polylane-harness/v1",entries:{local:{},global:{}}}' | atomic_write "$(state_file "$store")"
    : > "$(history_file "$store")"
  fi
  printf 'harness: initialized %s\n' "$store"
}

validate_mutation() {
  valid_scope "$1" && valid_kind "$2" && safe_id "$3" && ! protected_id "$3" && valid_cycle "$4" || {
    echo "harness: invalid scope, kind, id, or cycle" >&2; return 2; }
}

cmd_create() {
  local store="$1" scope="$2" kind="$3" id="$4" content="$5" cycle="$6" before entry
  require_store "$store"; validate_mutation "$scope" "$kind" "$id" "$cycle"; begin_locked "$store"
  before=$(entry_json "$store" "$scope" "$id")
  [ -z "$before" ] || { echo "harness: entry already exists: $scope/$id" >&2; return 5; }
  if [ "$scope" = global ] && { [ "$kind" = prompt ] || [ "$kind" = skill ]; }; then
    entry=$(jq -cn --arg scope "$scope" --arg kind "$kind" --arg id "$id" --arg content "$content" --argjson cycle "$cycle" \
      '{id:$id,scope:$scope,kind:$kind,version:1,content:$content,created_cycle:$cycle,updated_cycle:$cycle,active:false,activation:"proposal-only",handoff:"bin/polylane-skill-evolve.sh"}')
  else
    entry=$(jq -cn --arg scope "$scope" --arg kind "$kind" --arg id "$id" --arg content "$content" --argjson cycle "$cycle" \
      '{id:$id,scope:$scope,kind:$kind,version:1,content:$content,created_cycle:$cycle,updated_cycle:$cycle,active:true,activation:"active"}')
  fi
  write_snapshot "$store" "$scope" "$id" 1 "$entry"
  write_state_entry "$store" "$scope" "$id" "$entry"
  append_history "$store" create "$scope" "$id" null "$entry" "$cycle"
  printf '%s\n' "$entry"
}

cmd_update() {
  local store="$1" scope="$2" id="$3" expected="$4" content="$5" cycle="$6" before entry next
  require_store "$store"; valid_scope "$scope" && safe_id "$id" && ! protected_id "$id" && valid_cycle "$cycle" && valid_cycle "$expected" || usage
  begin_locked "$store"; before=$(entry_json "$store" "$scope" "$id")
  [ -n "$before" ] || { echo "harness: entry not found: $scope/$id" >&2; return 4; }
  [ "$(printf '%s' "$before" | jq -r '.version')" = "$expected" ] || { echo "harness: stale expected version" >&2; return 6; }
  next=$((expected + 1))
  entry=$(printf '%s' "$before" | jq -c --arg content "$content" --argjson cycle "$cycle" --argjson version "$next" '.content=$content | .updated_cycle=$cycle | .version=$version')
  write_snapshot "$store" "$scope" "$id" "$next" "$entry"
  write_state_entry "$store" "$scope" "$id" "$entry"
  append_history "$store" update "$scope" "$id" "$before" "$entry" "$cycle"
  printf '%s\n' "$entry"
}

cmd_delete() {
  local store="$1" scope="$2" id="$3" expected="$4" cycle="$5" before
  require_store "$store"; valid_scope "$scope" && safe_id "$id" && ! protected_id "$id" && valid_cycle "$cycle" && valid_cycle "$expected" || usage
  begin_locked "$store"; before=$(entry_json "$store" "$scope" "$id")
  [ -n "$before" ] || { echo "harness: entry not found: $scope/$id" >&2; return 4; }
  [ "$(printf '%s' "$before" | jq -r '.version')" = "$expected" ] || { echo "harness: stale expected version" >&2; return 6; }
  jq --arg scope "$scope" --arg id "$id" 'del(.entries[$scope][$id])' "$(state_file "$store")" | atomic_write "$(state_file "$store")"
  append_history "$store" delete "$scope" "$id" "$before" null "$cycle"
  printf 'harness: deleted %s/%s\n' "$scope" "$id"
}

cmd_read() {
  local store="$1" scope="$2" id="$3" format="$4" entry
  require_store "$store"; valid_scope "$scope" && safe_id "$id" && [ "$format" = --json ] || usage
  entry=$(entry_json "$store" "$scope" "$id")
  [ -n "$entry" ] || { echo "harness: entry not found: $scope/$id" >&2; return 4; }
  printf '%s\n' "$entry"
}

cmd_list() {
  local store="$1" scope="" kind="" format
  shift
  require_store "$store"
  case "$#" in
    1) format="$1" ;;
    2) scope="$1"; format="$2" ;;
    3) scope="$1"; kind="$2"; format="$3" ;;
    *) usage ;;
  esac
  [ "$format" = --json ] || usage
  [ -z "$scope" ] || valid_scope "$scope" || usage
  [ -z "$kind" ] || valid_kind "$kind" || usage
  jq -c --arg scope "$scope" --arg kind "$kind" '[.entries | to_entries[] | .value | to_entries[] | .value | select(($scope == "" or .scope == $scope) and ($kind == "" or .kind == $kind))] | sort_by(.scope,.id)' "$(state_file "$store")"
}

cmd_history() {
  local store="$1" scope="$2" id="$3" format="$4"
  require_store "$store"; valid_scope "$scope" && safe_id "$id" && [ "$format" = --json ] || usage
  jq -c --arg scope "$scope" --arg id "$id" 'select(.scope == $scope and .id == $id)' "$(history_file "$store")"
}

cmd_rollback() {
  local store="$1" scope="$2" id="$3" expected="$4" target="$5" cycle="$6" before snap entry next
  require_store "$store"; valid_scope "$scope" && safe_id "$id" && ! protected_id "$id" && valid_cycle "$expected" && valid_cycle "$target" && valid_cycle "$cycle" || usage
  begin_locked "$store"; before=$(entry_json "$store" "$scope" "$id")
  [ -n "$before" ] || { echo "harness: entry not found: $scope/$id" >&2; return 4; }
  [ "$(printf '%s' "$before" | jq -r '.version')" = "$expected" ] || { echo "harness: stale expected version" >&2; return 6; }
  snap=$(snapshot_file "$store" "$scope" "$id" "$target")
  [ -f "$snap" ] || { echo "harness: version snapshot not found: $target" >&2; return 4; }
  next=$((expected + 1))
  entry=$(jq -c --argjson cycle "$cycle" --argjson version "$next" '.updated_cycle=$cycle | .version=$version' "$snap")
  write_snapshot "$store" "$scope" "$id" "$next" "$entry"
  write_state_entry "$store" "$scope" "$id" "$entry"
  append_history "$store" rollback "$scope" "$id" "$before" "$entry" "$cycle"
  printf '%s\n' "$entry"
}

main() {
  [ "$#" -ge 1 ] || usage
  case "$1" in
    init) [ "$#" = 2 ] || usage; cmd_init "$2" ;;
    create) [ "$#" = 7 ] || usage; cmd_create "$2" "$3" "$4" "$5" "$6" "$7" ;;
    update) [ "$#" = 7 ] || usage; cmd_update "$2" "$3" "$4" "$5" "$6" "$7" ;;
    delete) [ "$#" = 6 ] || usage; cmd_delete "$2" "$3" "$4" "$5" "$6" ;;
    read) [ "$#" = 5 ] || usage; cmd_read "$2" "$3" "$4" "$5" ;;
    list) shift; cmd_list "$@" ;;
    history) [ "$#" = 5 ] || usage; cmd_history "$2" "$3" "$4" "$5" ;;
    rollback) [ "$#" = 7 ] || usage; cmd_rollback "$2" "$3" "$4" "$5" "$6" "$7" ;;
    *) usage ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then main "$@"; fi
