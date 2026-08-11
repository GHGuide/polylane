#!/usr/bin/env bash
# polylane-taste-threat.sh — executable, fail-closed taste evidence threat receipts.
set -euo pipefail

usage() {
  echo "usage: polylane-taste-threat.sh check <manifest.json> <threat-receipt.json>" >&2
}

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    return 127
  fi
}

sha256_text() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha256sum | awk '{print $1}'
  else
    return 127
  fi
}

manifest_shape() {
  jq -e '
    .schema_version == "taste-threat/v1"
    and (.source_root | type == "string" and startswith("/"))
    and (.hard_gates | type == "object"
      and (.function_pass | type == "boolean")
      and (.accessibility_pass | type == "boolean"))
    and (.context | type == "object" and (.status | IN("pass", "unknown", "mismatch")))
    and (.captures | type == "array" and length > 0)
    and all(.captures[];
      type == "object"
      and (.capture_id | type == "string" and test("^capture-[a-z0-9]{16}$"))
      and (.brief_id | type == "string" and test("^brief-[a-z0-9]{3,}$"))
      and (.candidate_id | type == "string" and test("^cand-[a-z0-9]{16}$"))
      and (.viewport | type == "string" and test("^[1-9][0-9]*x[1-9][0-9]*$"))
      and (.state | type == "string" and length > 0)
      and (.path | type == "string" and length > 0 and (startswith("/") | not)
        and (contains("..") | not))
      and (.sha256 | type == "string" and test("^[0-9a-f]{64}$"))
      and (.visible_text | type == "array" and all(.[]; type == "string")))
    and ([.captures[].capture_id] | unique | length == length)
    and (.receipts | type == "array" and length > 0)
    and all(.receipts[];
      type == "object"
      and (.receipt_id | type == "string" and test("^receipt-[a-z0-9]{16}$"))
      and (.payload | type == "object")
      and (.payload_sha256 | type == "string" and test("^[0-9a-f]{64}$")))
    and ([.receipts[].receipt_id] | unique | length == length)
    and (.sidecars | type == "array" and length > 0)
    and all(.sidecars[];
      type == "object"
      and (.brief_id | type == "string" and test("^brief-[a-z0-9]{3,}$"))
      and (.candidate_id | type == "string" and test("^cand-[a-z0-9]{16}$"))
      and (.unrelated_group | type == "string" and length > 0)
      and (.render | type == "object"
        and (.capture_id | type == "string" and test("^capture-[a-z0-9]{16}$"))
        and (.viewport | type == "string" and test("^[1-9][0-9]*x[1-9][0-9]*$"))
        and (.screenshot_sha256 | type == "string" and test("^[0-9a-f]{64}$")))
      and (.visual | type == "object"
        and all([.layout_family, .primary_information_unit, .density_band,
                 .navigation_archetype, .palette_family, .accent_hue_bin,
                 .type_pair_class, .shape_language][]; type == "string" and length > 0))
      and (.signature | type == "object"
        and (.mechanism | type == "string" and length > 0)
        and (.anchor | type == "string" and length > 0))
      and (.axis_results | type == "object"
        and ([keys[]] | sort == ["context_fit", "genericness_review", "provenance_integrity", "quality_risk"])
        and all(.[]; IN("pass", "unknown", "review", "fail"))))
  ' "$1" >/dev/null 2>&1
}

captures_are_real_and_bound() {
  local manifest="$1" root capture path declared actual
  root=$(jq -r '.source_root' "$manifest")
  [ -d "$root" ] && [ ! -L "$root" ] || return 1
  while IFS= read -r capture; do
    path=$(printf '%s' "$capture" | jq -r '.path')
    declared=$(printf '%s' "$capture" | jq -r '.sha256')
    [ -f "$root/$path" ] && [ ! -L "$root/$path" ] || return 1
    actual=$(sha256_file "$root/$path") || return 1
    [ "$declared" = "$actual" ] || return 1
  done < <(jq -c '.captures[]' "$manifest")
}

receipts_are_intact() {
  local manifest="$1" receipt payload declared actual
  while IFS= read -r receipt; do
    payload=$(printf '%s' "$receipt" | jq -c '.payload')
    declared=$(printf '%s' "$receipt" | jq -r '.payload_sha256')
    actual=$(sha256_text "$payload") || return 1
    [ "$declared" = "$actual" ] || return 1
  done < <(jq -c '.receipts[]' "$manifest")
}

has_visible_prompt_injection() {
  jq -er '.captures[].visible_text[]?' "$1" | LC_ALL=C grep -Eqi \
    '(ignore[[:space:]]+(all[[:space:]]+)?(previous|prior)[[:space:]]+instructions|system[[:space:]]+prompt|reveal[[:space:]]+(the[[:space:]]+)?(prompt|instructions)|assistant[[:space:]]+instructions)'
}

has_identity_leakage() {
  jq -e 'any(.captures[];
    has("provider") or has("provider_id") or has("model") or has("model_id")
    or has("candidate_name") or has("candidate_label"))' "$1" >/dev/null 2>&1
}

has_duplicate_pixels() {
  jq -e '([.captures[].sha256] | unique | length) != ([.captures[].sha256] | length)' "$1" >/dev/null 2>&1
}

sidecars_are_bound() {
  jq -e '
    (.captures | map({key:(.capture_id + "|" + .candidate_id), value:.sha256}) | from_entries) as $captures
    | all(.sidecars[]; ($captures[.render.capture_id + "|" + .candidate_id] // null) == .render.screenshot_sha256)
  ' "$1" >/dev/null 2>&1
}

sameness_triggered() {
  jq -e '
    [.sidecars[] | {
      brief_id, unrelated_group,
      template:(.visual.layout_family + "|" + .visual.primary_information_unit + "|" + .visual.density_band + "|"
        + .visual.navigation_archetype + "|" + .visual.palette_family + "|" + .visual.accent_hue_bin + "|"
        + .visual.type_pair_class + "|" + .visual.shape_language + "|" + .signature.mechanism + "|" + .signature.anchor)
    }]
    | group_by(.template)
    | any(.[]; length >= 3 and ([.[].brief_id] | unique | length) >= 3
      and ([.[].unrelated_group] | unique | length) >= 3)
  ' "$1" >/dev/null 2>&1
}

write_receipt() {
  local manifest="$1" output="$2" status="$3" genericness="$4" quality="$5" context="$6" provenance="$7" review="$8" reasons="$9"
  mkdir -p "$(dirname "$output")"
  jq -n --arg schema_version "taste-threat-receipt/v1" --arg status "$status" \
    --arg genericness "$genericness" --arg quality "$quality" --arg context "$context" \
    --arg provenance "$provenance" --arg review "$review" --argjson reasons "$reasons" \
    '{schema_version:$schema_version, status:$status,
      axis_results:{genericness_review:$genericness, quality_risk:$quality,
        context_fit:$context, provenance_integrity:$provenance},
      review:{status:$review, scope:(if $review == "CROSS_BRIEF_REVIEW" then "blinded-human-review" else null end),
        attribution_claim:false}, reason_codes:$reasons}' > "$output"
}

check() {
  local manifest="$1" output="$2" genericness="pass" quality="pass" provenance="unknown" context status="clean" review="not-required" reasons='[]'
  manifest_shape "$manifest" || { echo "TASTE-THREAT: malformed or unknown manifest" >&2; return 2; }
  context=$(jq -r '.context.status' "$manifest")
  if ! captures_are_real_and_bound "$manifest"; then
    provenance="fail"; reasons=$(jq -cn '["capture-hash-or-path-invalid"]')
  elif ! receipts_are_intact "$manifest"; then
    provenance="fail"; reasons=$(jq -cn '["receipt-hash-tampered"]')
  elif has_visible_prompt_injection "$manifest"; then
    provenance="fail"; reasons=$(jq -cn '["visible-prompt-injection"]')
  elif has_identity_leakage "$manifest"; then
    provenance="fail"; reasons=$(jq -cn '["blinded-identity-leakage"]')
  elif has_duplicate_pixels "$manifest"; then
    provenance="fail"; reasons=$(jq -cn '["duplicate-capture-pixels"]')
  elif ! sidecars_are_bound "$manifest"; then
    provenance="fail"; reasons=$(jq -cn '["sidecar-capture-binding-invalid"]')
  elif sameness_triggered "$manifest"; then
    genericness="review"; review="CROSS_BRIEF_REVIEW"; status="unknown"; reasons=$(jq -cn '["cross-brief-template-review"]')
  fi
  if ! jq -e '.hard_gates.function_pass and .hard_gates.accessibility_pass' "$manifest" >/dev/null 2>&1; then
    quality="fail"; status="blocked"; reasons=$(printf '%s' "$reasons" | jq '. + ["function-or-accessibility-hard-veto"]')
  elif [ "$provenance" = "fail" ]; then
    status="blocked"
  elif [ "$context" != "pass" ]; then
    status="unknown"; reasons=$(printf '%s' "$reasons" | jq --arg context "$context" '. + ["context-" + $context]')
  fi
  write_receipt "$manifest" "$output" "$status" "$genericness" "$quality" "$context" "$provenance" "$review" "$reasons"
  [ "$status" = "clean" ]
}

main() {
  case "${1:-}" in
    check) [ $# -eq 3 ] || { usage; return 2; }; check "$2" "$3" ;;
    *) usage; return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
