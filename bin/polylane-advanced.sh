#!/usr/bin/env bash
# polylane-advanced.sh — runner-facing admission, optional routing, and outcome adapter.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)

usage() {
  echo "usage: polylane-advanced.sh preflight|select|salvage|seams|record|domain-grade|economy-plan|accepted-receipt <manifest> [args]" >&2
}

manifest_ok() { [ -f "$1" ] && jq -e 'type == "object" and (.lanes | type == "array")' "$1" >/dev/null 2>&1; }

derive_outcome_paths() { # MANIFEST -> canonical outcome/hub paths
  local manifest="$1" manifest_dir project
  manifest_dir=$(cd "$(dirname "$manifest")" && pwd -P)
  project=$(cd "$manifest_dir/.." && pwd -P)
  OUTCOME_PATH="${POLYLANE_OUTCOMES:-$project/docs/polylane/outcomes.jsonl}"
  HUB_PATH="${POLYLANE_HUBS:-$project/docs/polylane/hubs.txt}"
}

project_root() {
  local manifest="$1" dir
  dir=$(cd "$(dirname "$manifest")" && pwd -P) || return 1
  cd "$dir/.." && pwd -P
}

safe_relative_path() {
  local path="$1" part old_ifs
  case "$path" in ''|/*|*'//'*) return 1 ;; esac
  old_ifs=$IFS; IFS=/
  for part in $path; do
    [ -n "$part" ] && [ "$part" != . ] && [ "$part" != .. ] || { IFS=$old_ifs; return 1; }
  done
  IFS=$old_ifs
}

domain_requested() {
  jq -e '.domain_runtime? | type == "object" and ((.enabled // true) == true)' "$1" >/dev/null 2>&1
}

domain_value() { # MANIFEST FIELD DEFAULT
  jq -r --arg field "$2" --arg fallback "$3" '.domain_runtime[$field] // $fallback' "$1"
}

domain_paths() { # MANIFEST ROOT -> sets DOMAIN_PROFILE/BUNDLE/GRADE/REGISTRATION
  local manifest="$1" root="$2" profile bundle grade registration
  profile=$(domain_value "$manifest" profile 'docs/polylane/PROJECT_PROFILE.json')
  bundle=$(domain_value "$manifest" bundle 'docs/polylane/domain-runtime/bundle.json')
  grade=$(domain_value "$manifest" grade 'docs/polylane/domain-runtime/grade.json')
  registration=$(domain_value "$manifest" registration '.polylane/domain-runtime/grader-registration.json')
  for path in "$profile" "$bundle" "$grade" "$registration"; do
    safe_relative_path "$path" || { echo "ADVANCED: unsafe domain runtime path: $path" >&2; return 2; }
  done
  case "$registration" in .polylane/*) ;; *) echo "ADVANCED: domain grader registration must remain runner scratch" >&2; return 2 ;; esac
  case "$bundle" in docs/polylane/domain-runtime/*) ;; *) echo "ADVANCED: domain bundle must remain durable domain evidence" >&2; return 2 ;; esac
  case "$grade" in docs/polylane/domain-runtime/*) ;; *) echo "ADVANCED: domain grade must remain durable domain evidence" >&2; return 2 ;; esac
  DOMAIN_PROFILE="$root/$profile"
  DOMAIN_BUNDLE="$root/$bundle"
  DOMAIN_GRADE="$root/$grade"
  DOMAIN_REGISTRATION="$root/$registration"
}

domain_helper() { printf '%s/polylane-domain.sh\n' "$SCRIPT_DIR"; }

domain_register() { # MANIFEST — pre-builder executable grader registration
  local manifest="$1" root helper kind tmp
  domain_requested "$manifest" || { printf 'ADVANCED: domain-grader=not-requested\n'; return 0; }
  root=$(project_root "$manifest") || return 1
  domain_paths "$manifest" "$root" || return $?
  helper=$(domain_helper)
  [ -x "$helper" ] || { echo 'ADVANCED: domain grader helper is missing' >&2; return 1; }
  "$SCRIPT_DIR/polylane-project.sh" validate "$DOMAIN_PROFILE" >/dev/null || return 1
  kind=$(jq -r .kind "$DOMAIN_PROFILE")
  mkdir -p "$(dirname "$DOMAIN_REGISTRATION")" || return 1
  tmp=$(mktemp "${DOMAIN_REGISTRATION}.tmp.XXXXXX") || return 1
  "$helper" contract "$kind" | jq -S --arg profile "${DOMAIN_PROFILE#$root/}" \
    --arg bundle "${DOMAIN_BUNDLE#$root/}" --arg grade "${DOMAIN_GRADE#$root/}" \
    '{schema:"polylane-domain-grader-registration/v1",profile:$profile,bundle:$bundle,grade:$grade,contract:.}' > "$tmp" || {
      rm -f "$tmp"; return 1;
    }
  mv "$tmp" "$DOMAIN_REGISTRATION"
  printf 'ADVANCED: domain-grader=registered profile=%s bundle=%s grade=%s\n' \
    "${DOMAIN_PROFILE#$root/}" "${DOMAIN_BUNDLE#$root/}" "${DOMAIN_GRADE#$root/}"
}

domain_grade() { # MANIFEST INTEGRATION_WORKTREE — final bundle + profile-specific grade
  local manifest="$1" worktree="$2" root helper tmp rc=0
  domain_requested "$manifest" || { printf 'ADVANCED: domain-grader=not-requested\n'; return 0; }
  [ -d "$worktree" ] && [ ! -L "$worktree" ] || { echo 'ADVANCED: integration worktree is missing or symlinked' >&2; return 2; }
  root=$(cd "$worktree" && pwd -P) || return 1
  domain_paths "$manifest" "$root" || return $?
  helper=$(domain_helper)
  [ -x "$helper" ] || { echo 'ADVANCED: domain grader helper is missing' >&2; return 1; }
  mkdir -p "$(dirname "$DOMAIN_BUNDLE")" "$(dirname "$DOMAIN_GRADE")" || return 1
  "$helper" bundle "$DOMAIN_PROFILE" "$root" "$DOMAIN_BUNDLE" || return 1
  tmp=$(mktemp "${DOMAIN_GRADE}.tmp.XXXXXX") || return 1
  "$helper" grade "$DOMAIN_PROFILE" "$DOMAIN_BUNDLE" --json > "$tmp" || rc=$?
  mv "$tmp" "$DOMAIN_GRADE"
  if [ "$rc" -eq 0 ] && jq -e '.verdict == "PASS"' "$DOMAIN_GRADE" >/dev/null; then
    printf 'ADVANCED: domain-grader=passed bundle=%s grade=%s\n' \
      "${DOMAIN_BUNDLE#$root/}" "${DOMAIN_GRADE#$root/}"
    return 0
  fi
  printf 'ADVANCED: domain-grader=failed bundle=%s grade=%s\n' \
    "${DOMAIN_BUNDLE#$root/}" "${DOMAIN_GRADE#$root/}" >&2
  return 1
}

economy_requested() {
  jq -e '.outcome_learning? | type == "object" and ((.enabled // true) == true)' "$1" >/dev/null 2>&1
}

economy_plan() { # MANIFEST LANE MODEL EFFORT ROLE LANE_COUNT CONTEXT_TOKENS
  local manifest="$1" lane="$2" model="$3" effort="$4" role="$5" lanes="$6" context="$7" root ledger domain shape min policy tmp
  economy_requested "$manifest" || { jq -n '{schema:"polylane-economy/v1",requested:false,safe_to_apply:false,reason:"outcome learning not requested",changed_fields:[]}' ; return 0; }
  root=$(project_root "$manifest") || return 1
  ledger=$(jq -r '.outcome_learning.ledger // "docs/polylane/accepted-outcomes.jsonl"' "$manifest")
  safe_relative_path "$ledger" || { echo "ADVANCED: unsafe outcome ledger path: $ledger" >&2; return 2; }
  ledger="$root/$ledger"
  domain=$(jq -r '.outcome_learning.domain // "custom"' "$manifest")
  shape=$(jq -r --arg lane "$lane" '.outcome_learning.lane_shapes[$lane] // $lane' "$manifest")
  min=$(jq -r '.outcome_learning.minimum_samples // 3' "$manifest")
  case "$min" in ''|*[!0-9]*) echo 'ADVANCED: outcome learning minimum_samples must be an integer' >&2; return 2 ;; esac
  policy=$(mktemp "${TMPDIR:-/tmp}/polylane-economy-policy.XXXXXX") || return 1
  trap 'rm -f "$policy"' RETURN
  jq -n --arg domain "$domain" --arg shape "$shape" --arg model "$model" --arg effort "$effort" --arg role "$role" \
    --argjson lanes "$lanes" --argjson context "$context" --argjson available "$(jq -c '.available_models // []' "$manifest")" --argjson min "$min" \
    '{schema:"polylane-policy/v1",domain:$domain,lane_shape:$shape,model:$model,effort:$effort,role:$role,lane_count:$lanes,context_tokens:$context,available_models:$available,minimum_samples:$min,bounds:{lane_count:{min:$lanes,max:$lanes},context_tokens:{min:$context,max:$context}}}' > "$policy" || return 1
  "$SCRIPT_DIR/polylane-optimize.sh" recommend "$ledger" "$policy" --json
  rm -f "$policy"
  trap - RETURN
}

accepted_receipt() { # MANIFEST RUN_ID CYCLE VERDICT
  local manifest="$1" run_id="$2" cycle="$3" verdict="$4" root out tmp stats commit stats_json
  economy_requested "$manifest" || { printf 'ADVANCED: accepted-outcome=not-requested\n'; return 0; }
  case "$verdict" in GO|EXTERNAL-EVIDENCE-OPEN) ;; *) printf 'ADVANCED: accepted-outcome=not-recorded verdict=%s\n' "$verdict"; return 0 ;; esac
  root=$(project_root "$manifest") || return 1
  out="docs/polylane/outcome-receipts/$run_id.json"
  safe_relative_path "$out" || return 2
  out="$root/$out"; mkdir -p "$(dirname "$out")" || return 1
  stats="$root/docs/polylane/run-stats.json"
  if [ -s "$stats" ] && jq -e . "$stats" >/dev/null 2>&1; then
    stats_json=$(jq -c . "$stats")
  else
    stats_json='null'
  fi
  commit=$(git -C "$root" rev-parse HEAD 2>/dev/null || printf unknown)
  tmp=$(mktemp "${out}.tmp.XXXXXX") || return 1
  jq -n --arg run "$run_id" --argjson cycle "$cycle" --arg verdict "$verdict" --arg commit "$commit" \
    --argjson stats "$stats_json" '{schema:"polylane-accepted-outcome-receipt/v1",run:$run,cycle:$cycle,acceptance_status:"accepted",verdict:$verdict,commit:$commit,evidence:"docs/verify-integration.md",measurements:(if $stats != null then {tokens:$stats.tokens,token_state:$stats.token_state,wall_seconds:$stats.wall_s} else {tokens:null,token_state:"unknown",wall_seconds:null} end),optimizer_eligibility:(if $stats != null and $stats.tokens != null and $stats.wall_s > 0 then "requires lane-shaped receipt attribution" else "measurements unavailable; not supplied to optimizer" end)}' > "$tmp" || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$out"
  printf 'ADVANCED: accepted-outcome=recorded receipt=%s\n' "${out#$root/}"
}

outcomes() { # OP ... — explicit paths make calls independent of observer cwd
  POLYLANE_OUTCOMES="$OUTCOME_PATH" POLYLANE_HUBS="$HUB_PATH" \
    "$SCRIPT_DIR/polylane-outcomes.sh" "$@"
}

preflight() {
  local manifest="$1" risk_rc=0
  outcomes predict "$manifest" || risk_rc=$?
  case "$risk_rc" in 0) printf 'ADVANCED: risk=admitted\n' ;; 5) printf 'ADVANCED: risk=flagged-admitted\n' ;; *) return "$risk_rc" ;; esac
  if jq -e '.champion_candidates | type == "array" and length > 0' "$manifest" >/dev/null 2>&1; then
    printf 'ADVANCED: selection=requested\n'
  else
    printf 'ADVANCED: selection=not-requested\n'
  fi
  if jq -e '(.salvage_verify_cmd | type == "string" and length > 0)' "$manifest" >/dev/null 2>&1; then
    printf 'ADVANCED: salvage=requested\n'
  else
    printf 'ADVANCED: salvage=not-requested\n'
  fi
  domain_register "$manifest"
}

select_champion() {
  local manifest="$1" candidates winner
  if ! jq -e '.champion_candidates | type == "array" and length > 0 and all(.[]; type == "string")' "$manifest" >/dev/null 2>&1; then
    printf 'ADVANCED: selection=not-requested\n'; return 0
  fi
  candidates=$(jq -r '.champion_candidates[]' "$manifest")
  # shellcheck disable=SC2086 # candidates are manifest-delimited argv specs.
  winner=$("$SCRIPT_DIR/polylane-select.sh" pick $candidates)
  printf 'ADVANCED: selection=%s\n' "${winner:-none}"
}

salvage() {
  local manifest="$1" verify lanes count
  if ! jq -e '(.salvage_verify_cmd | type == "string" and length > 0)' "$manifest" >/dev/null 2>&1; then
    printf 'ADVANCED: salvage=not-requested\n'; return 0
  fi
  verify=$(jq -r '.salvage_verify_cmd' "$manifest")
  lanes=$(jq -r '.salvage_lanes // [.lanes[].name] | .[]' "$manifest")
  count=$(printf '%s\n' "$lanes" | sed '/^$/d' | wc -l | tr -d ' ')
  [ "$count" -ge 3 ] || { echo 'ADVANCED: salvage requires at least three lanes' >&2; return 2; }
  # shellcheck disable=SC2086 # configured verifier is intentionally a command name.
  POLYLANE_VERIFY_CMD="$verify" "$SCRIPT_DIR/polylane-bisect.sh" salvage $lanes
}

seams() { # MANIFEST TREE EVIDENCE — preserve mechanical evidence for the gate
  local manifest="$1" tree="$2" evidence="$3" output rc=0
  [ -d "$tree" ] || { echo "ADVANCED: seam tree does not exist: $tree" >&2; return 2; }
  output=$("$SCRIPT_DIR/polylane-seams.sh" scan "$tree" 2>&1) || rc=$?
  if [ "$rc" -eq 0 ]; then
    printf 'ADVANCED: seams=passed evidence=%s\n' "$evidence"
  else
    mkdir -p "$(dirname "$evidence")"
    printf '\n%s\n' "$output" >> "$evidence"
    printf '%s\n' "$output" >&2
    printf 'ADVANCED: seams=failed evidence=%s\n' "$evidence" >&2
  fi
  return "$rc"
}

record() {
  local manifest="$1" verdict="$2" lane model globs sig
  while IFS=$'\t' read -r lane model globs; do
    [ -n "$lane" ] || continue
    set -f
    # shellcheck disable=SC2086 # own_globs are patterns, not filesystem globs.
    sig=$(outcomes signature $globs)
    set +f
    outcomes record "$lane" "$sig" "$model" "$verdict"
  done < <(jq -r '.lanes[] | [.name, .model, (.own_globs | join(" "))] | @tsv' "$manifest")
  printf 'ADVANCED: outcomes=recorded verdict=%s\n' "$verdict"
}

main() {
  [ $# -ge 2 ] || { usage; return 2; }
  local cmd="$1" manifest="$2"
  manifest_ok "$manifest" || { echo "ADVANCED: invalid manifest" >&2; return 2; }
  derive_outcome_paths "$manifest"
  case "$cmd" in
    preflight) [ $# -eq 2 ] || { usage; return 2; }; preflight "$manifest" ;;
    select) [ $# -eq 2 ] || { usage; return 2; }; select_champion "$manifest" ;;
    salvage) [ $# -eq 2 ] || { usage; return 2; }; salvage "$manifest" ;;
    seams) [ $# -eq 4 ] || { usage; return 2; }; seams "$manifest" "$3" "$4" ;;
    record) [ $# -eq 3 ] || { usage; return 2; }; record "$manifest" "$3" ;;
    domain-grade) [ $# -eq 3 ] || { usage; return 2; }; domain_grade "$manifest" "$3" ;;
    economy-plan) [ $# -eq 8 ] || { usage; return 2; }; economy_plan "$manifest" "$3" "$4" "$5" "$6" "$7" "$8" ;;
    accepted-receipt) [ $# -eq 5 ] || { usage; return 2; }; accepted_receipt "$manifest" "$3" "$4" "$5" ;;
    *) usage; return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
