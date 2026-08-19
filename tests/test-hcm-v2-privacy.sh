#!/usr/bin/env bash
# HCM-v2 consent record + privacy boundary regression test.
#
# Proves, against bin/polylane-taste-consent.sh:
#   1. a consent record carries only what a preregistered study needs
#      (opaque participant id, consent version, timestamp, withdrawal path)
#      and no personally identifying data reaches any emitted artifact;
#   2. holdout labels are unreachable from every participant-facing artifact
#      (stimulus, ballot, receipt);
#   3. the ethics review that approves consent stays an OPEN EXTERNAL
#      dependency and can never be emitted as satisfied.
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
CONSENT="$ROOT/bin/polylane-taste-consent.sh"
LOCK="$ROOT/docs/polylane/taste-certification/contracts/CONTRACT-LOCK.v3.json"
REGISTRY="$ROOT/docs/polylane/taste-certification/contracts/EVIDENCE-CLAIM-REGISTRY.v3.json"
TMPDIR_PRIVACY=$(mktemp -d "${TMPDIR:-/tmp}/polylane-hcm-privacy.XXXXXX")
trap 'rm -rf "$TMPDIR_PRIVACY"' EXIT HUP INT TERM
ASSERTIONS=0

assert_ok() {
  "$@" >/dev/null
  ASSERTIONS=$((ASSERTIONS + 1))
}

assert_fail() {
  if "$@" >/dev/null 2>&1; then
    echo "expected failure: $*" >&2
    exit 1
  fi
  ASSERTIONS=$((ASSERTIONS + 1))
}

expect_eq() {
  if [ "$1" = "$2" ]; then
    ASSERTIONS=$((ASSERTIONS + 1))
  else
    echo "FAIL ${3:-assertion}: expected [$1] got [$2]" >&2
    exit 1
  fi
}

NONCE=1111111111111111111111111111111111111111111111111111111111111111
STUDY_ID=$(jq -r '.source_calibration.hcm_v2.source_id' "$LOCK")

write_spec() {
  jq -n --arg study "$STUDY_ID" --arg nonce "$NONCE" "$1" \
    >"$2"
}

# --- consent record: minimum viable preregistered fields, nothing else ------
SPEC="$TMPDIR_PRIVACY/spec.json"
write_spec '{
  study_id: $study,
  consent_version: "2026-08-19.1",
  enrolment_nonce: $nonce,
  consented_at: "2026-08-19T09:00:00Z",
  withdrawal_path: "https://study.example/hcm-v2/withdraw"
}' "$SPEC"

RECORD="$TMPDIR_PRIVACY/consent.json"
assert_ok "$CONSENT" record "$SPEC" "$RECORD"

expect_eq "hcm-v2-consent/v1" "$(jq -r '.schema' "$RECORD")" "consent schema"
expect_eq "$STUDY_ID" "$(jq -r '.study_id' "$RECORD")" "consent study id"
expect_eq "2026-08-19.1" "$(jq -r '.consent_version' "$RECORD")" "consent version"
expect_eq "2026-08-19T09:00:00Z" "$(jq -r '.consented_at' "$RECORD")" "consent timestamp"
expect_eq "https://study.example/hcm-v2/withdraw" \
  "$(jq -r '.withdrawal.path' "$RECORD")" "withdrawal path"
expect_eq "true" "$(jq -r '.withdrawal.revocable' "$RECORD")" "withdrawal revocable"
expect_eq "false" "$(jq -r '.contains_personal_data' "$RECORD")" "no personal data flag"

# The participant id is opaque: a 64-hex digest, and the enrolment nonce that
# produced it never reaches the record.
PARTICIPANT_ID=$(jq -r '.participant_id' "$RECORD")
case "$PARTICIPANT_ID" in
  [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*) ;;
  *) echo "FAIL participant_id not an opaque digest: $PARTICIPANT_ID" >&2; exit 1 ;;
esac
expect_eq 64 "${#PARTICIPANT_ID}" "participant id length"
assert_fail grep -q "$NONCE" "$RECORD"
# Same nonce, same id: the study can honour a withdrawal without storing PII.
RECORD_AGAIN="$TMPDIR_PRIVACY/consent-again.json"
assert_ok "$CONSENT" record "$SPEC" "$RECORD_AGAIN"
expect_eq "$PARTICIPANT_ID" "$(jq -r '.participant_id' "$RECORD_AGAIN")" "id is stable"

# --- PII cannot enter through the spec ------------------------------------
for pii_field in \
  '{email: "participant@example.com"}' \
  '{full_name: "A Participant"}' \
  '{phone: "+44 7700 900123"}' \
  '{ip_address: "203.0.113.7"}' \
  '{postcode: "SW1A 1AA"}'
do
  BAD_SPEC="$TMPDIR_PRIVACY/spec-bad.json"
  jq -n --arg study "$STUDY_ID" --arg nonce "$NONCE" \
    '{study_id: $study, consent_version: "2026-08-19.1", enrolment_nonce: $nonce,
      consented_at: "2026-08-19T09:00:00Z",
      withdrawal_path: "https://study.example/hcm-v2/withdraw"} + '"$pii_field" \
    >"$BAD_SPEC"
  assert_fail "$CONSENT" record "$BAD_SPEC" "$TMPDIR_PRIVACY/out-bad.json"
done

# A PII-shaped value smuggled into an accepted field is rejected too.
BAD_VALUE_SPEC="$TMPDIR_PRIVACY/spec-bad-value.json"
write_spec '{
  study_id: $study,
  consent_version: "2026-08-19.1",
  enrolment_nonce: $nonce,
  consented_at: "2026-08-19T09:00:00Z",
  withdrawal_path: "mailto:participant@example.com"
}' "$BAD_VALUE_SPEC"
assert_fail "$CONSENT" record "$BAD_VALUE_SPEC" "$TMPDIR_PRIVACY/out-bad-value.json"

# A non-opaque enrolment reference (an identifier rather than a nonce) is rejected.
BAD_NONCE_SPEC="$TMPDIR_PRIVACY/spec-bad-nonce.json"
jq -n --arg study "$STUDY_ID" \
  '{study_id: $study, consent_version: "2026-08-19.1",
    enrolment_nonce: "participant@example.com",
    consented_at: "2026-08-19T09:00:00Z",
    withdrawal_path: "https://study.example/hcm-v2/withdraw"}' >"$BAD_NONCE_SPEC"
assert_fail "$CONSENT" record "$BAD_NONCE_SPEC" "$TMPDIR_PRIVACY/out-bad-nonce.json"

# A sequential enrolment identifier carries no PII pattern but is still not
# opaque: it links back to the recruiting roster, so it is rejected too.
SEQUENTIAL_SPEC="$TMPDIR_PRIVACY/spec-sequential.json"
jq '.enrolment_nonce = "participant-0007"' "$SPEC" >"$SEQUENTIAL_SPEC"
assert_fail "$CONSENT" record "$SEQUENTIAL_SPEC" "$TMPDIR_PRIVACY/out-sequential.json"

# --- the emitted record itself is PII-free, and a poisoned one is caught ---
assert_ok "$CONSENT" pii-scan "$RECORD"
POISONED="$TMPDIR_PRIVACY/consent-poisoned.json"
jq '. + {email: "participant@example.com"}' "$RECORD" >"$POISONED"
assert_fail "$CONSENT" pii-scan "$POISONED"
POISONED_NESTED="$TMPDIR_PRIVACY/consent-poisoned-nested.json"
jq '.withdrawal += {contact: "participant@example.com"}' "$RECORD" >"$POISONED_NESTED"
assert_fail "$CONSENT" pii-scan "$POISONED_NESTED"

# --- withdrawal is a first-class governance artifact -----------------------
WITHDRAWAL="$TMPDIR_PRIVACY/withdrawal.json"
assert_ok "$CONSENT" withdraw "$RECORD" "2026-08-20T10:30:00Z" "$WITHDRAWAL"
expect_eq "hcm-v2-withdrawal/v1" "$(jq -r '.schema' "$WITHDRAWAL")" "withdrawal schema"
expect_eq "$PARTICIPANT_ID" "$(jq -r '.participant_id' "$WITHDRAWAL")" "withdrawal id"
expect_eq "2026-08-20T10:30:00Z" "$(jq -r '.withdrawn_at' "$WITHDRAWAL")" "withdrawn at"
expect_eq "https://study.example/hcm-v2/withdraw" \
  "$(jq -r '.path' "$WITHDRAWAL")" "withdrawal path carried"
assert_ok "$CONSENT" pii-scan "$WITHDRAWAL"
assert_fail "$CONSENT" withdraw "$POISONED" "2026-08-20T10:30:00Z" \
  "$TMPDIR_PRIVACY/withdrawal-bad.json"

# --- participant-facing artifacts must not expose holdout labels ----------
STIMULUS="$TMPDIR_PRIVACY/stimulus.json"
cat >"$STIMULUS" <<JSON
{"schema":"hcm-v2-stimulus/v1","pair_id":"pair-0007","viewport":"1440x900",
 "options":[{"option_id":"A","asset_sha256":"$(printf 'a%.0s' $(seq 64))"},
            {"option_id":"B","asset_sha256":"$(printf 'b%.0s' $(seq 64))"}]}
JSON
BALLOT="$TMPDIR_PRIVACY/ballot.json"
cat >"$BALLOT" <<JSON
{"schema":"hcm-v2-ballot/v1","participant_id":"$PARTICIPANT_ID",
 "pair_id":"pair-0007","viewport":"390x844","choice":"A"}
JSON
RECEIPT="$TMPDIR_PRIVACY/receipt.json"
cat >"$RECEIPT" <<JSON
{"schema":"hcm-v2-receipt/v1","participant_id":"$PARTICIPANT_ID",
 "ballots_recorded":8,"withdrawal":{"path":"https://study.example/hcm-v2/withdraw"}}
JSON

for artifact in "$STIMULUS" "$BALLOT" "$RECEIPT"; do
  assert_ok "$CONSENT" blind-check "$artifact"
done

# Every shape of holdout-label leak is rejected: an explicit label key, a gold
# answer, a split assignment, and a bare "holdout" value.
LEAK="$TMPDIR_PRIVACY/leak.json"
for leak in \
  '{holdout_label: "A"}' \
  '{gold_label: "B"}' \
  '{ground_truth: "A"}' \
  '{human_rating: 4}' \
  '{split: "confirmatory"}' \
  '{answer_key: "B"}' \
  '{expected_winner: "A"}' \
  '{provenance: {split: "holdout"}}' \
  '{options: [{option_id: "A", holdout: true}]}'
do
  jq '. + '"$leak" "$STIMULUS" >"$LEAK"
  assert_fail "$CONSENT" blind-check "$LEAK"
done

# The machine panel is qualified from the same blinded artifacts: a ballot that
# carries the holdout label is rejected before it can reach qualification.
LEAKY_BALLOT="$TMPDIR_PRIVACY/ballot-leaky.json"
jq '. + {gold_label: "A"}' "$BALLOT" >"$LEAKY_BALLOT"
assert_fail "$CONSENT" blind-check "$LEAKY_BALLOT"
LEAKY_RECEIPT="$TMPDIR_PRIVACY/receipt-leaky.json"
jq '. + {split: "validation"}' "$RECEIPT" >"$LEAKY_RECEIPT"
assert_fail "$CONSENT" blind-check "$LEAKY_RECEIPT"

# blind-check also refuses PII in a participant-facing artifact.
PII_BALLOT="$TMPDIR_PRIVACY/ballot-pii.json"
jq '. + {email: "participant@example.com"}' "$BALLOT" >"$PII_BALLOT"
assert_fail "$CONSENT" blind-check "$PII_BALLOT"

# --- ethics review stays an OPEN EXTERNAL dependency ----------------------
EXTERNAL="$TMPDIR_PRIVACY/external.json"
assert_ok "$CONSENT" external-open "$EXTERNAL"
expect_eq "hcm-v2-external-dependencies/v1" "$(jq -r '.schema' "$EXTERNAL")" "external schema"
expect_eq "false" "$(jq -r '.satisfied' "$EXTERNAL")" "external never satisfied"
expect_eq "EXTERNAL-EVIDENCE-OPEN" "$(jq -r '.status' "$EXTERNAL")" "external status"
expect_eq "EXTERNAL_TARGET_MATCHED" "$(jq -r '.authority' "$EXTERNAL")" "external authority"
expect_eq "true" "$(jq -r '.governance_requirements_are_external' "$EXTERNAL")" "governance external"

# Every requirement the registry lists is carried, open, and none is satisfied.
REQ_LOCK=$(jq -r '.private_hcm_v2_prerequisite.external_requirements | sort | join(",")' "$REGISTRY")
REQ_OUT=$(jq -r '[.requirements[].requirement] | sort | join(",")' "$EXTERNAL")
expect_eq "$REQ_LOCK" "$REQ_OUT" "external requirements bound to registry"
expect_eq "0" "$(jq '[.requirements[] | select(.satisfied != false)] | length' "$EXTERNAL")" \
  "no requirement satisfied"
for required in ethics_privacy_determination consent withdrawal retention governance_owner; do
  expect_eq "1" \
    "$(jq --arg r "$required" '[.requirements[] | select(.requirement == $r)] | length' "$EXTERNAL")" \
    "requirement $required present"
done

# --- the frozen values are read from the contract, not re-typed ------------
# A drifted contract must fail loudly rather than silently emit a stale record.
DRIFT_DIR="$TMPDIR_PRIVACY/drift"
mkdir -p "$DRIFT_DIR"
jq '.source_calibration.hcm_v2.governance_requirements_are_external = false' "$LOCK" \
  >"$DRIFT_DIR/CONTRACT-LOCK.v3.json"
cp "$REGISTRY" "$DRIFT_DIR/EVIDENCE-CLAIM-REGISTRY.v3.json"
assert_fail env POLYLANE_CONTRACT_LOCK="$DRIFT_DIR/CONTRACT-LOCK.v3.json" \
  POLYLANE_CLAIM_REGISTRY="$DRIFT_DIR/EVIDENCE-CLAIM-REGISTRY.v3.json" \
  "$CONSENT" external-open "$TMPDIR_PRIVACY/external-drift.json"

jq '.private_hcm_v2_prerequisite.status = "SATISFIED"' "$REGISTRY" \
  >"$DRIFT_DIR/EVIDENCE-CLAIM-REGISTRY.v3.json"
cp "$LOCK" "$DRIFT_DIR/CONTRACT-LOCK.v3.json"
assert_fail env POLYLANE_CONTRACT_LOCK="$DRIFT_DIR/CONTRACT-LOCK.v3.json" \
  POLYLANE_CLAIM_REGISTRY="$DRIFT_DIR/EVIDENCE-CLAIM-REGISTRY.v3.json" \
  "$CONSENT" external-open "$TMPDIR_PRIVACY/external-drift.json"

# A consent record for a study id the lock does not name is rejected.
WRONG_STUDY="$TMPDIR_PRIVACY/spec-wrong-study.json"
jq '.study_id = "HCM-v3"' "$SPEC" >"$WRONG_STUDY"
assert_fail "$CONSENT" record "$WRONG_STUDY" "$TMPDIR_PRIVACY/out-wrong-study.json"

# --- emitted artifacts are never overwritten -------------------------------
assert_fail "$CONSENT" record "$SPEC" "$RECORD"

echo "PASS test-hcm-v2-privacy.sh ($ASSERTIONS assertions)"
