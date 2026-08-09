#!/usr/bin/env bash
# Focused executable contract checks for the domain runtime.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DOMAIN="$ROOT/bin/polylane-domain.sh"
PREVIEW="$ROOT/bin/polylane-action-preview.sh"
DISCOVERY="$ROOT/bin/polylane-discovery.sh"
FIXTURES="$ROOT/benchmarks/domain-runtime"

pass=0
fail=0
ok() { printf 'ok - %s\n' "$1"; pass=$((pass + 1)); }
not_ok() { printf 'not ok - %s\n' "$1" >&2; fail=$((fail + 1)); }
assert_ok() { local name="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$name"; else not_ok "$name"; fi; }
assert_eq() { if [ "$2" = "$3" ]; then ok "$1"; else not_ok "$1 expected [$2] got [$3]"; fi; }

for kind in software trading research operations content data custom mixed; do
  assert_ok "contract exists for $kind" "$DOMAIN" contract "$kind"
  if "$DOMAIN" contract "$kind" >"${TMPDIR:-/tmp}/polylane-domain-contract.$$" 2>/dev/null; then
    assert_eq "contract version for $kind" "domain-runtime/v1" "$(jq -r '.version' "${TMPDIR:-/tmp}/polylane-domain-contract.$$")"
    assert_eq "contract declares required runtime fields for $kind" "true" "$(jq -r '([.kind, .capabilities, .dependencies, .side_effect_class, .input, .offline, .provenance, .grader, .question_tree, .deliverable_requirements] | all(. != null))' "${TMPDIR:-/tmp}/polylane-domain-contract.$$")"
  fi
done
rm -f "${TMPDIR:-/tmp}/polylane-domain-contract.$$"

assert_ok "questions use JSON when requested" "$DOMAIN" questions trading --json
"$DOMAIN" questions trading --json >"${TMPDIR:-/tmp}/polylane-domain-questions.$$" 2>/dev/null || true
assert_eq "trading questions are bounded and adaptive" "true" "$(jq -r 'length >= 4 and length <= 8 and all(.[]; (.paths.recommended and .paths.deep and .paths.bold and .paths.custom) and (.stopping.deliverable_change or .stopping.evidence_change or .stopping.risk_change or .stopping.action_boundary_change))' "${TMPDIR:-/tmp}/polylane-domain-questions.$$" 2>/dev/null || printf false)"
assert_eq "trading has deep-specific follow-up" "true" "$(jq -r 'any(.[]; .id == "trading-evaluation" and (.paths.deep.follow_up | type == "object"))' "${TMPDIR:-/tmp}/polylane-domain-questions.$$" 2>/dev/null || printf false)"
rm -f "${TMPDIR:-/tmp}/polylane-domain-questions.$$"
for kind in research operations content data; do
  "$DOMAIN" questions "$kind" --json > "${TMPDIR:-/tmp}/polylane-domain-$kind.$$"
  assert_eq "$kind questions have relevant deep follow-up" "true" "$(jq -r 'all(.[]; .paths.deep.follow_up.question != null and .paths.bold.follow_up.question != null)' "${TMPDIR:-/tmp}/polylane-domain-$kind.$$")"
  rm -f "${TMPDIR:-/tmp}/polylane-domain-$kind.$$"
done

STATE=$(mktemp "${TMPDIR:-/tmp}/polylane-domain-discovery.XXXXXX")
rm -f "$STATE"
assert_ok "typed discovery init accepts kind" "$DISCOVERY" init "$STATE" "Evaluate a trading strategy" trading
assert_eq "typed discovery persists domain kind" "trading" "$(jq -r '.domain.kind' "$STATE" 2>/dev/null || printf missing)"
assert_eq "typed discovery seeds adaptive runtime nodes" "true" "$(jq -r '[.nodes[] | select(.domain_kind == "trading")] | length >= 4 and all(.[]; .options.recommended and .options.deep and .options.bold and .options.custom and .stopping)' "$STATE" 2>/dev/null || printf false)"
assert_ok "typed discovery accepts a domain deep answer" "$DISCOVERY" answer "$STATE" q-domain-trading-evaluation deep
assert_eq "typed discovery preserves domain-specific deep follow-up" "What evidence would change this decision?" "$(jq -r '.nodes[] | select(.id == "q-domain-trading-evaluation-deep") | .question' "$STATE" 2>/dev/null || true)"
rm -f "$STATE"

make_tmpdir() { BUNDLE_TMP=$(mktemp -d "${TMPDIR:-/tmp}/polylane-domain-bundle.XXXXXX"); }
make_tmpdir
cp -R "$FIXTURES/trading-artifacts" "$BUNDLE_TMP/artifacts" 2>/dev/null || true
assert_ok "bundle records declared files and checksums" "$DOMAIN" bundle "$FIXTURES/trading-profile.json" "$BUNDLE_TMP/artifacts" "$BUNDLE_TMP/bundle.json"
assert_eq "bundle has immutable provenance and entries" "true" "$(jq -r '.version == "domain-runtime/bundle-v1" and (.provenance | length == 5) and (.entries | length == 2) and all(.entries[]; .checksum != "")' "$BUNDLE_TMP/bundle.json" 2>/dev/null || printf false)"
assert_ok "trading grade accepts complete paper-only evidence" "$DOMAIN" grade "$FIXTURES/trading-profile.json" "$BUNDLE_TMP/bundle.json" --json
assert_eq "trading grade emits PASS verdict" "PASS" "$("$DOMAIN" grade "$FIXTURES/trading-profile.json" "$BUNDLE_TMP/bundle.json" --json 2>/dev/null | jq -r '.verdict' || true)"
assert_fail() { local name="$1"; shift; if "$@" >/dev/null 2>&1; then not_ok "$name"; else ok "$name"; fi; }
assert_fail "grader rejects missing trading provenance" "$DOMAIN" grade "$FIXTURES/trading-missing-provenance.json" "$BUNDLE_TMP/bundle.json" --json
printf 'changed artifact\n' >> "$BUNDLE_TMP/artifacts/strategy.md"
assert_fail "grader detects artifact tampering" "$DOMAIN" grade "$FIXTURES/trading-profile.json" "$BUNDLE_TMP/bundle.json" --json
rm -rf "$BUNDLE_TMP"

ACTION_TMP=$(mktemp -d "${TMPDIR:-/tmp}/polylane-action-preview.XXXXXX")
printf '%s\n' '{"strategy":"fixture","capital":"none"}' > "$ACTION_TMP/payload.json"
assert_ok "prepare creates a simulation receipt" "$PREVIEW" prepare "$FIXTURES/trading-profile.json" paper-review "$ACTION_TMP/payload.json" "$ACTION_TMP/receipt.json"
assert_eq "receipt identifies exact payload and safe boundary" "true" "$(jq -r '.version == "domain-runtime/action-receipt-v1" and (.payload_hash | length > 0) and .approval_required == true and .side_effect_class == "simulation" and (.redacted_preview | type == "object")' "$ACTION_TMP/receipt.json" 2>/dev/null || printf false)"
assert_ok "receipt verifies before approval" "$PREVIEW" verify "$ACTION_TMP/receipt.json"
assert_ok "receipt verifies its exact original payload" "$PREVIEW" verify "$ACTION_TMP/receipt.json" "$ACTION_TMP/payload.json"
printf '%s\n' '{"strategy":"changed","capital":"none"}' > "$ACTION_TMP/changed-payload.json"
assert_fail "receipt rejects a changed payload" "$PREVIEW" verify "$ACTION_TMP/receipt.json" "$ACTION_TMP/changed-payload.json"
printf '%s\n' '{"receipt_id":"wrong","approved_by":"fixture-reviewer"}' > "$ACTION_TMP/wrong-approval.json"
assert_fail "approval rejects a different receipt identity" "$PREVIEW" approve "$ACTION_TMP/receipt.json" "$ACTION_TMP/wrong-approval.json"
assert_fail "prepare rejects live trading action" "$PREVIEW" prepare "$FIXTURES/trading-profile.json" live-trade "$ACTION_TMP/payload.json" "$ACTION_TMP/live.json"
printf '%s\n' '{"api_token":"do-not-preview"}' > "$ACTION_TMP/secret.json"
assert_fail "prepare refuses secrets in previews" "$PREVIEW" prepare "$FIXTURES/trading-profile.json" paper-review "$ACTION_TMP/secret.json" "$ACTION_TMP/secret-receipt.json"
printf '%s\n' '{"receipt_id":"REPLACE","approved_by":"fixture-reviewer"}' > "$ACTION_TMP/approval.json"
receipt_id=$(jq -r '.receipt_id' "$ACTION_TMP/receipt.json" 2>/dev/null || true)
jq --arg receipt_id "$receipt_id" '.receipt_id = $receipt_id' "$ACTION_TMP/approval.json" > "$ACTION_TMP/approval-next.json" && mv "$ACTION_TMP/approval-next.json" "$ACTION_TMP/approval.json"
assert_ok "approval records only exact receipt identity" "$PREVIEW" approve "$ACTION_TMP/receipt.json" "$ACTION_TMP/approval.json"
assert_ok "approved receipt still verifies" "$PREVIEW" verify "$ACTION_TMP/receipt.json"
assert_fail "receipt verification detects tampering" sh -c 'jq ".worst_credible_impact = \"changed\"" "$1" > "$1.next" && mv "$1.next" "$1" && "$2" verify "$1"' sh "$ACTION_TMP/receipt.json" "$PREVIEW"
assert_fail "helper refuses execute verb" "$PREVIEW" execute
rm -rf "$ACTION_TMP"

GRADE_TMP=$(mktemp -d "${TMPDIR:-/tmp}/polylane-domain-grades.XXXXXX")
cp -R "$FIXTURES/trading-artifacts" "$GRADE_TMP/artifacts"
grade_kind() {
  local kind="$1" checks="$2" broken="$3"
  jq --arg kind "$kind" --argjson checks "$checks" '.kind = $kind | .domain_runtime.checks = $checks' "$FIXTURES/trading-profile.json" > "$GRADE_TMP/$kind.json"
  assert_ok "bundle supports $kind profile" "$DOMAIN" bundle "$GRADE_TMP/$kind.json" "$GRADE_TMP/artifacts" "$GRADE_TMP/$kind.bundle.json"
  assert_ok "$kind grade accepts required evidence" "$DOMAIN" grade "$GRADE_TMP/$kind.json" "$GRADE_TMP/$kind.bundle.json" --json
  jq --argjson checks "$broken" '.domain_runtime.checks = $checks' "$GRADE_TMP/$kind.json" > "$GRADE_TMP/$kind.fail.json"
  assert_fail "$kind grade rejects an omitted required check" "$DOMAIN" grade "$GRADE_TMP/$kind.fail.json" "$GRADE_TMP/$kind.bundle.json" --json
}
grade_kind research '{"query_source_ledger":true,"inclusion_exclusion":true,"citation_coverage":true,"synthesis":true,"uncertainty_limitations":true}' '{"query_source_ledger":false,"inclusion_exclusion":true,"citation_coverage":true,"synthesis":true,"uncertainty_limitations":true}'
grade_kind operations '{"owner":true,"controls":true,"tabletop_or_dry_run":true,"kpi":true,"rollback_recovery":true,"approval_boundaries":true}' '{"owner":false,"controls":true,"tabletop_or_dry_run":true,"kpi":true,"rollback_recovery":true,"approval_boundaries":true}'
grade_kind content '{"audience":true,"factual_source_audit":true,"editorial_brand_rubric":true,"declared_variants":true,"publication_approval":true}' '{"audience":true,"factual_source_audit":false,"editorial_brand_rubric":true,"declared_variants":true,"publication_approval":true}'
grade_kind data '{"schema":true,"provenance":true,"quality_report":true,"deterministic_transform":true,"idempotence":true,"sample_output":true,"monitoring":true,"rollback":true}' '{"schema":true,"provenance":true,"quality_report":true,"deterministic_transform":false,"idempotence":true,"sample_output":true,"monitoring":true,"rollback":true}'
grade_kind software '{"build_evidence":true,"test_evidence":true,"user_path_evidence":true}' '{"build_evidence":true,"test_evidence":false,"user_path_evidence":true}'
grade_kind custom '{"declared_artifacts":true,"declared_evidence_modes":true,"risk_action_policy":true}' '{"declared_artifacts":true,"declared_evidence_modes":false,"risk_action_policy":true}'
grade_kind mixed '{"declared_artifacts":true,"declared_evidence_modes":true,"risk_action_policy":true}' '{"declared_artifacts":true,"declared_evidence_modes":true,"risk_action_policy":false}'
rm -rf "$GRADE_TMP"

printf '1..%s\n' "$((pass + fail))"
[ "$fail" -eq 0 ]
