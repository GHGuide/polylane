#!/usr/bin/env bash
# Prepare and verify safety-gated external-action previews; never execute actions.
set -euo pipefail

usage() {
  echo "usage: polylane-action-preview.sh prepare <profile.json> <action-name> <payload.json> <receipt.json> | verify <receipt.json> [payload.json] | approve <receipt.json> <approval.json>" >&2
  exit 2
}

die() { echo "polylane-action-preview: $*" >&2; exit 2; }

need_jq() { command -v jq >/dev/null 2>&1 || die "jq is required"; }

canonical_hash() { jq -S -c . "$1" | cksum | awk '{print $1 ":" $2}'; }

payload_has_secret() {
  jq -e '.. | objects | keys[]? | ascii_downcase | test("secret|token|password|credential|api[_-]?key")' "$1" >/dev/null
}

project_validate() {
  local profile="$1" project
  project="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/polylane-project.sh"
  "$project" validate "$profile" >/dev/null
}

safe_action() {
  local profile="$1" action="$2"
  jq -e --arg action "$action" '
    (.external_action_policy.actions[]? | select(.name == $action)) as $declared |
    (.domain_runtime.actions[]? | select(.name == $action)) as $runtime |
    $declared.approval_required == true and
    ($declared.execution | test("^(read-only|simulation|paper-simulation)$")) and
    ($runtime.side_effect_class | IN("read-only", "simulation")) and
    ($runtime.affected_systems | type == "array") and
    ($runtime.affected_people | type == "array") and
    ($runtime.reversibility | type == "string" and length > 0) and
    ($runtime.worst_credible_impact | type == "string" and length > 0) and
    ($runtime.simulation_evidence | type == "string" and length > 0)
  ' "$profile" >/dev/null
}

cmd_prepare() {
  local profile="$1" action="$2" payload="$3" receipt="$4" profile_hash payload_hash action_json body tmp id
  project_validate "$profile"
  [ -f "$payload" ] || die "payload does not exist: $payload"
  jq empty "$payload" >/dev/null 2>&1 || die "payload is not valid JSON: $payload"
  case "$action" in *execute*|*live*) die "execute/live verbs are forbidden; this helper only prepares previews" ;; esac
  safe_action "$profile" "$action" || die "unknown, consequential, or unsafe action: $action"
  payload_has_secret "$payload" && die "payload contains a secret and cannot be previewed"
  profile_hash=$(canonical_hash "$profile")
  payload_hash=$(canonical_hash "$payload")
  action_json=$(jq -c --arg action "$action" '.domain_runtime.actions[] | select(.name == $action)' "$profile")
  body=$(jq -n --arg action "$action" --arg profile_hash "$profile_hash" --arg payload_hash "$payload_hash" --argjson action_meta "$action_json" --slurpfile payload "$payload" '
    {version:"domain-runtime/action-receipt-v1", action_name:$action,
     profile_hash:$profile_hash, payload_hash:$payload_hash,
     redacted_preview:{payload:$payload[0]}, affected_systems:$action_meta.affected_systems,
     affected_people:$action_meta.affected_people, reversibility:$action_meta.reversibility,
     worst_credible_impact:$action_meta.worst_credible_impact,
     simulation_evidence:$action_meta.simulation_evidence,
     side_effect_class:$action_meta.side_effect_class, approval_required:true,
     execution:"not-performed"}
  ')
  tmp=$(mktemp "${receipt}.tmp.XXXXXX")
  printf '%s\n' "$body" | jq -S . > "$tmp"
  id="receipt-$(canonical_hash "$tmp")"
  jq --arg id "$id" '. + {receipt_id:$id}' "$tmp" | jq -S . > "${tmp}.next"
  mv "${tmp}.next" "$tmp"
  mv "$tmp" "$receipt"
}

cmd_verify() {
  local receipt="$1" payload="${2:-}" expected actual tmp
  [ -f "$receipt" ] || die "receipt does not exist: $receipt"
  jq empty "$receipt" >/dev/null 2>&1 || die "receipt is not valid JSON: $receipt"
  jq -e '
    .version == "domain-runtime/action-receipt-v1" and
    (.action_name | type == "string" and length > 0) and
    (.payload_hash | type == "string" and length > 0) and
    (.profile_hash | type == "string" and length > 0) and
    (.redacted_preview | type == "object") and
    (.affected_systems | type == "array") and (.affected_people | type == "array") and
    .approval_required == true and .execution == "not-performed" and
    (.side_effect_class | IN("read-only", "simulation"))
  ' "$receipt" >/dev/null || die "receipt lacks required safety fields"
  if jq -e '.. | objects | keys[]? | ascii_downcase | test("secret|token|password|credential|api[_-]?key")' "$receipt" >/dev/null; then
    die "receipt preview contains secret-shaped fields"
  fi
  tmp=$(mktemp "${TMPDIR:-/tmp}/polylane-action-receipt.XXXXXX")
  jq 'del(.receipt_id, .approval)' "$receipt" | jq -S . > "$tmp"
  expected="receipt-$(canonical_hash "$tmp")"
  actual=$(jq -r '.receipt_id // empty' "$receipt")
  rm -f "$tmp"
  [ "$actual" = "$expected" ] || die "receipt identity does not match its exact preview"
  if [ -n "$payload" ]; then
    [ -f "$payload" ] || die "payload does not exist: $payload"
    jq empty "$payload" >/dev/null 2>&1 || die "payload is not valid JSON: $payload"
    [ "$(canonical_hash "$payload")" = "$(jq -r '.payload_hash' "$receipt")" ] ||
      die "payload does not match the exact prepared receipt"
  fi
  if jq -e '.approval? != null and (.approval.receipt_id != .receipt_id)' "$receipt" >/dev/null; then
    die "approval is not bound to this exact receipt"
  fi
  printf 'action receipt valid: %s\n' "$actual"
}

cmd_approve() {
  local receipt="$1" approval="$2" tmp id
  cmd_verify "$receipt" >/dev/null
  [ -f "$approval" ] || die "approval does not exist: $approval"
  jq empty "$approval" >/dev/null 2>&1 || die "approval is not valid JSON: $approval"
  id=$(jq -r '.receipt_id' "$receipt")
  jq -e --arg id "$id" '.receipt_id == $id and (.approved_by | type == "string" and length > 0)' "$approval" >/dev/null || die "approval must bind to this exact receipt identity"
  tmp=$(mktemp "${receipt}.tmp.XXXXXX")
  jq --slurpfile approval "$approval" '.approval = $approval[0]' "$receipt" | jq -S . > "$tmp"
  mv "$tmp" "$receipt"
  cmd_verify "$receipt" >/dev/null
  printf 'approval recorded for receipt: %s\n' "$id"
}

main() {
  need_jq
  case "${1:-}" in
    prepare) [ "$#" = 5 ] || usage; cmd_prepare "$2" "$3" "$4" "$5" ;;
    verify) [ "$#" = 2 ] || [ "$#" = 3 ] || usage; cmd_verify "$2" "${3:-}" ;;
    approve) [ "$#" = 3 ] || usage; cmd_approve "$2" "$3" ;;
    *execute*|*live*) die "execute/live verbs are forbidden; this helper never performs actions" ;;
    *) usage ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
