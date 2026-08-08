#!/usr/bin/env bash
# polylane-project.sh — deterministic project-outcome profile validation.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: polylane-project.sh validate <profile.json>
       polylane-project.sh brief <profile.json>
       polylane-project.sh gate <PROJECT_PROFILE.md> <profile.json>

validate checks a versioned machine project outcome profile. brief prints the
validated, canonical JSON that planning and lane carving consume. gate requires
the durable human record and matching machine form before goal decomposition.
EOF
  exit 2
}

die() {
  printf 'polylane-project: %s\n' "$*" >&2
  exit 2
}

require_jq() {
  command -v jq >/dev/null 2>&1 || die "jq is required"
}

validate_profile() {
  local profile="$1"
  local kind risk mode

  [ -f "$profile" ] || die "profile does not exist: $profile"
  jq empty "$profile" >/dev/null 2>&1 || die "profile is not valid JSON: $profile"

  jq -e '.version == 1' "$profile" >/dev/null ||
    die "version must be 1"
  jq -e '.kind | type == "string" and length > 0' "$profile" >/dev/null ||
    die "kind must be a non-empty string"
  kind=$(jq -r '.kind' "$profile")
  case "$kind" in
    software|trading|research|operations|content|data|custom|mixed) ;;
    *) die "kind must be one of software, trading, research, operations, content, data, custom, or mixed (use custom or mixed for an unlisted industry)" ;;
  esac

  jq -e '.outcome | type == "string" and test("[^[:space:]]")' "$profile" >/dev/null ||
    die "outcome must be a non-empty string"
  jq -e '.deliverables | type == "array" and length > 0' "$profile" >/dev/null ||
    die "deliverables must be a non-empty array"
  jq -e '
    .deliverables | all(
      type == "object"
      and (.artifact | type == "string" and length > 0)
      and (.path | type == "string" and test("[^[:space:]]"))
      and (.description | type == "string" and test("[^[:space:]]"))
    )
  ' "$profile" >/dev/null ||
    die "each deliverable must declare non-empty artifact, path, and description fields"
  jq -e '
    .deliverables | all(
      .artifact | IN("source", "document", "documents", "dataset", "datasets", "notebook", "notebooks", "model", "models", "analysis", "analyses", "runbook", "runbooks", "media", "configuration", "configurations")
    )
  ' "$profile" >/dev/null ||
    die "deliverable artifact must be source, document, dataset, notebook, model, analysis, runbook, media, or configuration"

  jq -e '.evidence_modes | type == "array" and length > 0 and all(.[]; type == "string" and test("[^[:space:]]"))' "$profile" >/dev/null ||
    die "evidence_modes must be a non-empty array of non-empty strings"
  jq -e '.risk_tier | type == "string"' "$profile" >/dev/null ||
    die "risk_tier must be low, medium, high, or consequential"
  risk=$(jq -r '.risk_tier' "$profile")
  case "$risk" in low|medium|high|consequential) ;; *) die "risk_tier must be low, medium, high, or consequential" ;; esac

  jq -e '.external_action_policy | type == "object"' "$profile" >/dev/null ||
    die "external_action_policy must be an object"
  jq -e '.external_action_policy.mode | type == "string"' "$profile" >/dev/null ||
    die "external_action_policy.mode must be not-needed or approval-required"
  mode=$(jq -r '.external_action_policy.mode' "$profile")
  case "$mode" in not-needed|approval-required) ;; *) die "external_action_policy.mode must be not-needed or approval-required" ;; esac
  jq -e '.external_action_policy.actions | type == "array"' "$profile" >/dev/null ||
    die "external_action_policy.actions must be an array"
  jq -e '
    .external_action_policy.actions | all(
      type == "object"
      and (.name | type == "string" and test("[^[:space:]]"))
      and (.consequential | type == "boolean")
      and (.approval_required | type == "boolean")
      and (.execution | type == "string" and test("[^[:space:]]"))
    )
  ' "$profile" >/dev/null ||
    die "each external action must declare name, consequential, approval_required, and execution"

  if [ "$mode" = "not-needed" ] && [ "$(jq '.external_action_policy.actions | length' "$profile")" -ne 0 ]; then
    die "external_action_policy.mode not-needed requires no external actions"
  fi
  if jq -e '.external_action_policy.actions[]? | select(.consequential and (.approval_required != true))' "$profile" >/dev/null; then
    die "consequential external actions must be approval-required"
  fi
  if { [ "$risk" = "high" ] || [ "$risk" = "consequential" ]; } && ! jq -e '
      .external_action_policy.mode == "approval-required"
      and any(.external_action_policy.actions[]?; .consequential and .approval_required)
    ' "$profile" >/dev/null; then
    die "high-risk profiles require approval-required external actions"
  fi
  if [ "$kind" = "trading" ] && jq -e '.external_action_policy.actions[]? | select(.execution == "autonomous-live")' "$profile" >/dev/null; then
    die "trading profiles cannot declare autonomous live execution"
  fi
}

record_value() {
  local record="$1" field="$2"
  sed -n "s/^${field}:[[:space:]]*//p" "$record" | head -n 1
}

validate_record() {
  local record="$1" field

  [ -f "$record" ] || die "PROJECT_PROFILE.md does not exist: $record"
  for field in Outcome Profile Deliverables Stakeholders Constraints Evidence Risk \
    "External actions" "Finish conditions"; do
    if ! grep -Eq "^${field}:[[:space:]]*[^[:space:]]" "$record"; then
      die "PROJECT_PROFILE.md requires ${field}"
    fi
  done
}

validate_gate() {
  local record="$1" profile="$2" kind record_profile record_outcome profile_outcome

  validate_record "$record"
  validate_profile "$profile"
  kind=$(jq -r '.kind' "$profile")
  record_profile=$(record_value "$record" "Profile")
  record_outcome=$(record_value "$record" "Outcome")
  profile_outcome=$(jq -r '.outcome' "$profile")

  case "$record_profile" in
    *"$kind"*) ;;
    *) die "PROJECT_PROFILE.md Profile must identify machine profile kind: $kind" ;;
  esac
  [ "$record_outcome" = "$profile_outcome" ] ||
    die "PROJECT_PROFILE.md Outcome must match the machine profile outcome"
}

main() {
  local command profile record
  [ "$#" -ge 1 ] || usage
  command="$1"
  require_jq
  case "$command" in
    validate)
      [ "$#" -eq 2 ] || usage
      profile="$2"
      validate_profile "$profile"
      printf 'project profile valid: kind=%s\n' "$(jq -r '.kind' "$profile")"
      ;;
    brief)
      [ "$#" -eq 2 ] || usage
      profile="$2"
      validate_profile "$profile"
      jq -S . "$profile"
      ;;
    gate)
      [ "$#" -eq 3 ] || usage
      record="$2"
      profile="$3"
      validate_gate "$record" "$profile"
      printf 'project profile gate valid: kind=%s\n' "$(jq -r '.kind' "$profile")"
      ;;
    *) usage ;;
  esac
}

main "$@"
