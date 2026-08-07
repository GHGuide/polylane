#!/usr/bin/env bash
# polylane-refine.sh — evidence-triggered, next-cycle validation and rollback.
set -euo pipefail

command -v jq >/dev/null 2>&1 || { echo "refine: jq required" >&2; exit 1; }
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARNESS="$ROOT/bin/polylane-harness.sh"

usage() {
  cat >&2 <<'EOF'
usage: polylane-refine.sh observe <store> <cycle> <failure|stall|no-go|compaction> <subject> <evidence>
       polylane-refine.sh eligible <store> <subject>
       polylane-refine.sh propose <store> <proposal-id> <created-cycle> <deadline-cycle> <scope> <kind> <entry-id> <expected-version> <content> <evidence> -- <bounded-check> [arg...]
       polylane-refine.sh validate <store> <current-cycle> <proposal-id>
EOF
  exit 2
}

safe_id() { case "$1" in ''|*[!A-Za-z0-9._-]*) return 1 ;; *) return 0 ;; esac; }
valid_cycle() { case "$1" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }
refine_file() { printf '%s/refinements.json\n' "$1"; }
observations_file() { printf '%s/refinement-observations.jsonl\n' "$1"; }
decisions_file() { printf '%s/refinement-decisions.jsonl\n' "$1"; }

atomic_write() {
  local file="$1" dir base tmp
  dir=$(dirname "$file"); base=$(basename "$file"); mkdir -p "$dir"
  tmp="$dir/.${base}.tmp.$$"; cat > "$tmp"; mv "$tmp" "$file"
}

ensure_store() {
  [ -f "$1/state.json" ] || { echo "refine: harness store is not initialized: $1" >&2; return 2; }
  if [ ! -f "$(refine_file "$1")" ]; then
    jq -n '{schema:"polylane-refinements/v1",proposals:{}}' | atomic_write "$(refine_file "$1")"
    : > "$(observations_file "$1")"; : > "$(decisions_file "$1")"
  fi
}

append_decision() {
  jq -cn --arg id "$2" --arg outcome "$3" --argjson cycle "$4" --arg reason "$5" \
    '{proposal_id:$id,outcome:$outcome,cycle:$cycle,reason:$reason}' >> "$(decisions_file "$1")"
}

run_bounded() {
  local seconds="$1"; shift
  local pid ticks=0 max_ticks rc=0
  "$@" & pid=$!
  max_ticks=$((seconds * 10))
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$ticks" -ge "$max_ticks" ]; then
      kill -TERM "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; return 124
    fi
    sleep 0.1; ticks=$((ticks + 1))
  done
  wait "$pid" || rc=$?
  return "$rc"
}

is_eligible() {
  local store="$1" subject="$2" count
  count=$(jq -s --arg subject "$subject" '[.[] | select(.subject == $subject)] | group_by(.kind) | map(select(length >= 2)) | length' "$(observations_file "$store")")
  [ "$count" -gt 0 ]
}

cmd_observe() {
  local store="$1" cycle="$2" kind="$3" subject="$4" evidence="$5"
  ensure_store "$store"; valid_cycle "$cycle" && safe_id "$subject" && [ -n "$evidence" ] || usage
  case "$kind" in failure|stall|no-go|compaction) ;; *) usage ;; esac
  jq -cn --argjson cycle "$cycle" --arg kind "$kind" --arg subject "$subject" --arg evidence "$evidence" \
    '{cycle:$cycle,kind:$kind,subject:$subject,evidence:$evidence}' >> "$(observations_file "$store")"
  printf 'refine: observed %s for %s\n' "$kind" "$subject"
}

cmd_eligible() {
  local store="$1" subject="$2"
  ensure_store "$store"; safe_id "$subject" || usage
  is_eligible "$store" "$subject" || return 3
  printf 'refine: eligible %s\n' "$subject"
}

cmd_propose() {
  local store="$1" proposal_id="$2" created="$3" deadline="$4" scope="$5" kind="$6" entry_id="$7" expected="$8" content="$9" evidence="${10}" before action after check_json proposal rc=0
  shift 10
  [ "${1:-}" = -- ] || usage; shift
  [ "$#" -gt 0 ] || usage
  ensure_store "$store"
  safe_id "$proposal_id" && safe_id "$entry_id" && valid_cycle "$created" && valid_cycle "$deadline" && valid_cycle "$expected" && [ -n "$evidence" ] || usage
  [ "$deadline" -gt "$created" ] || { echo "refine: deadline must be later than creation" >&2; return 2; }
  case "$scope:$kind" in local:prompt|local:memory|local:skill|local:subagent|global:prompt|global:memory|global:skill|global:subagent) ;; *) usage ;; esac
  is_eligible "$store" "$entry_id" || { echo "refine: one-off noise is not eligible" >&2; return 3; }
  jq -e --arg id "$proposal_id" '.proposals[$id] == null' "$(refine_file "$store")" >/dev/null || { echo "refine: proposal exists" >&2; return 5; }
  if before=$("$HARNESS" read "$store" "$scope" "$entry_id" --json 2>/dev/null); then
    action=update
    [ "$(printf '%s' "$before" | jq -r '.version')" = "$expected" ] || { echo "refine: stale expected version" >&2; return 6; }
    "$HARNESS" update "$store" "$scope" "$entry_id" "$expected" "$content" "$created" >/dev/null
  else
    rc=$?
    [ "$rc" = 4 ] && [ "$expected" = 0 ] || return "$rc"
    before=null; action=create
    "$HARNESS" create "$store" "$scope" "$kind" "$entry_id" "$content" "$created" >/dev/null
  fi
  after=$("$HARNESS" read "$store" "$scope" "$entry_id" --json)
  check_json=$(printf '%s\n' "$@" | jq -R . | jq -cs .)
  proposal=$(jq -cn --arg id "$proposal_id" --argjson created "$created" --argjson deadline "$deadline" --arg scope "$scope" --arg kind "$kind" --arg entry_id "$entry_id" --arg evidence "$evidence" --arg action "$action" --argjson before "$before" --argjson after "$after" --argjson check "$check_json" \
    '{id:$id,status:"pending",created_cycle:$created,deadline_cycle:$deadline,scope:$scope,kind:$kind,entry_id:$entry_id,evidence:$evidence,expected_check:$check,action:$action,before:$before,after:$after}')
  jq --arg id "$proposal_id" --argjson proposal "$proposal" '.proposals[$id]=$proposal' "$(refine_file "$store")" | atomic_write "$(refine_file "$store")"
  printf '%s\n' "$proposal"
}

rollback_proposal() {
  local store="$1" cycle="$2" proposal="$3" action scope entry_id after_version before_version
  action=$(printf '%s' "$proposal" | jq -r '.action'); scope=$(printf '%s' "$proposal" | jq -r '.scope'); entry_id=$(printf '%s' "$proposal" | jq -r '.entry_id')
  after_version=$(printf '%s' "$proposal" | jq -r '.after.version')
  if [ "$action" = create ]; then
    "$HARNESS" delete "$store" "$scope" "$entry_id" "$after_version" "$cycle" >/dev/null
  else
    before_version=$(printf '%s' "$proposal" | jq -r '.before.version')
    "$HARNESS" rollback "$store" "$scope" "$entry_id" "$after_version" "$before_version" "$cycle" >/dev/null
  fi
}

cmd_validate() {
  local store="$1" current="$2" proposal_id="$3" proposal created deadline status check=() value reason outcome rc=0 timeout="${POLYLANE_REFINE_TIMEOUT_S:-30}"
  ensure_store "$store"; valid_cycle "$current" && safe_id "$proposal_id" && valid_cycle "$timeout" || usage
  proposal=$(jq -c --arg id "$proposal_id" '.proposals[$id] // empty' "$(refine_file "$store")")
  [ -n "$proposal" ] || { echo "refine: proposal not found" >&2; return 4; }
  status=$(printf '%s' "$proposal" | jq -r '.status'); [ "$status" = pending ] || return 3
  created=$(printf '%s' "$proposal" | jq -r '.created_cycle'); deadline=$(printf '%s' "$proposal" | jq -r '.deadline_cycle')
  [ "$current" -gt "$created" ] || { echo "refine: validation must be in a later cycle" >&2; return 3; }
  if [ "$current" -gt "$deadline" ]; then
    reason=deadline_expired; outcome=rolled_back
  else
    while IFS= read -r value; do check[${#check[@]}]="$value"; done < <(printf '%s' "$proposal" | jq -r '.expected_check[]')
    if run_bounded "$timeout" "${check[@]}"; then reason=check_passed; outcome=validated; else reason=check_failed; outcome=rolled_back; fi
  fi
  if [ "$outcome" = rolled_back ]; then rollback_proposal "$store" "$current" "$proposal"; fi
  jq --arg id "$proposal_id" --arg status "$outcome" --arg reason "$reason" --argjson cycle "$current" \
    '.proposals[$id].status=$status | .proposals[$id].decision=$reason | .proposals[$id].validation_cycle=$cycle' "$(refine_file "$store")" | atomic_write "$(refine_file "$store")"
  append_decision "$store" "$proposal_id" "$outcome" "$current" "$reason"
  [ "$outcome" = validated ] || return 7
  printf 'refine: validated %s\n' "$proposal_id"
}

main() {
  [ "$#" -ge 1 ] || usage
  case "$1" in
    observe) [ "$#" = 6 ] || usage; cmd_observe "$2" "$3" "$4" "$5" "$6" ;;
    eligible) [ "$#" = 3 ] || usage; cmd_eligible "$2" "$3" ;;
    propose) shift; cmd_propose "$@" ;;
    validate) [ "$#" = 4 ] || usage; cmd_validate "$2" "$3" "$4" ;;
    *) usage ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then main "$@"; fi
