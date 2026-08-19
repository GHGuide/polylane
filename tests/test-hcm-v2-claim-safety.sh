#!/usr/bin/env bash
# HCM-v2 claim-safety regression test.
#
# The evidence claim registry forbids the labels/statuses TASTE-CERTIFIED and
# HUMAN_CERTIFIED and forbids taste_certified/human_certified ever being true.
# This test proves no output of bin/polylane-taste-consent.sh can carry one, and
# that the scanner rejects any artifact that does.
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
CONSENT="$ROOT/bin/polylane-taste-consent.sh"
LOCK="$ROOT/docs/polylane/taste-certification/contracts/CONTRACT-LOCK.v3.json"
REGISTRY="$ROOT/docs/polylane/taste-certification/contracts/EVIDENCE-CLAIM-REGISTRY.v3.json"
TMPDIR_CLAIM=$(mktemp -d "${TMPDIR:-/tmp}/polylane-hcm-claim.XXXXXX")
trap 'rm -rf "$TMPDIR_CLAIM"' EXIT HUP INT TERM
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

NONCE=2222222222222222222222222222222222222222222222222222222222222222
STUDY_ID=$(jq -r '.source_calibration.hcm_v2.source_id' "$LOCK")

# --- emit every artifact the pipeline can produce --------------------------
SPEC="$TMPDIR_CLAIM/spec.json"
jq -n --arg study "$STUDY_ID" --arg nonce "$NONCE" \
  '{study_id: $study, consent_version: "2026-08-19.1", enrolment_nonce: $nonce,
    consented_at: "2026-08-19T09:00:00Z",
    withdrawal_path: "https://study.example/hcm-v2/withdraw"}' >"$SPEC"

RECORD="$TMPDIR_CLAIM/consent.json"
WITHDRAWAL="$TMPDIR_CLAIM/withdrawal.json"
EXTERNAL="$TMPDIR_CLAIM/external.json"
assert_ok "$CONSENT" record "$SPEC" "$RECORD"
assert_ok "$CONSENT" withdraw "$RECORD" "2026-08-20T10:30:00Z" "$WITHDRAWAL"
assert_ok "$CONSENT" external-open "$EXTERNAL"

# Every emitted artifact passes the scan.
assert_ok "$CONSENT" claim-scan "$RECORD" "$WITHDRAWAL" "$EXTERNAL"

# No emitted artifact asserts certification of any kind.
for artifact in "$RECORD" "$WITHDRAWAL" "$EXTERNAL"; do
  expect_eq "0" "$(jq '[paths(scalars) as $p | select(($p|last|tostring) as $k
      | $k == "human_certified" or $k == "taste_certified")
      | getpath($p) | select(. == true)] | length' "$artifact")" \
    "no certification flag true in $(basename "$artifact")"
done
expect_eq "NONE_IN_V3" "$(jq -r '.certification_mint_authority' "$RECORD")" \
  "consent record records that nothing here mints certification"

# --- the scanner rejects every prohibited token ----------------------------
POISON="$TMPDIR_CLAIM/poison.json"

jq '. + {claim_label: "TASTE-CERTIFIED"}' "$RECORD" >"$POISON"
assert_fail "$CONSENT" claim-scan "$POISON"

jq '. + {status: "HUMAN_CERTIFIED"}' "$RECORD" >"$POISON"
assert_fail "$CONSENT" claim-scan "$POISON"

jq '. + {human_certified: true}' "$RECORD" >"$POISON"
assert_fail "$CONSENT" claim-scan "$POISON"

jq '. + {taste_certified: true}' "$RECORD" >"$POISON"
assert_fail "$CONSENT" claim-scan "$POISON"

jq '.governance += {outcome: {human_certified: true}}' "$RECORD" >"$POISON"
assert_fail "$CONSENT" claim-scan "$POISON"

# Formatting cannot hide the claim: the flag and its value on separate lines
# still parses as a true certification flag.
printf '{\n  "human_certified":\n    true\n}\n' >"$TMPDIR_CLAIM/wrapped.json"
assert_fail "$CONSENT" claim-scan "$TMPDIR_CLAIM/wrapped.json"

# A prohibited label buried in prose is still caught.
printf 'the panel is TASTE-CERTIFIED for this corpus\n' >"$TMPDIR_CLAIM/prose.txt"
assert_fail "$CONSENT" claim-scan "$TMPDIR_CLAIM/prose.txt"

# So is a certification flag set true outside JSON: a report, a shell export, a
# YAML front matter block never parses as JSON but still makes the claim.
printf 'human_certified = true\n' >"$TMPDIR_CLAIM/report.md"
assert_fail "$CONSENT" claim-scan "$TMPDIR_CLAIM/report.md"
printf 'taste_certified: true\n' >"$TMPDIR_CLAIM/front-matter.yaml"
assert_fail "$CONSENT" claim-scan "$TMPDIR_CLAIM/front-matter.yaml"

# false is fine: recording that certification was NOT reached is the point.
jq '. + {human_certified: false, taste_certified: false}' "$RECORD" >"$POISON"
assert_ok "$CONSENT" claim-scan "$POISON"

# A batch fails if any member fails.
assert_fail "$CONSENT" claim-scan "$RECORD" "$TMPDIR_CLAIM/prose.txt" "$EXTERNAL"

# --- no code path in the pipeline can emit a prohibited token --------------
# The forbidden vocabulary is read from the registry at runtime, so the script
# itself never contains a prohibited label, status, or a true certification flag.
expect_eq "0" "$(grep -c -e 'TASTE-CERTIFIED' -e 'HUMAN_CERTIFIED' "$CONSENT" || true)" \
  "script source carries no prohibited claim label"
expect_eq "0" "$(grep -c -E '(human|taste)_certified["'"'"' ]*[:=][ ]*true' "$CONSENT" || true)" \
  "script source never sets a certification flag true"

# Whatever the pipeline writes is scanned before it lands: a spec that tries to
# smuggle a claim through an accepted field is refused at emit time.
CLAIM_SPEC="$TMPDIR_CLAIM/spec-claim.json"
jq '.consent_version = "TASTE-CERTIFIED"' "$SPEC" >"$CLAIM_SPEC"
assert_fail "$CONSENT" record "$CLAIM_SPEC" "$TMPDIR_CLAIM/out-claim.json"
assert_fail test -e "$TMPDIR_CLAIM/out-claim.json"

# --- the vocabulary is bound to the registry, not re-typed -----------------
DRIFT_REGISTRY="$TMPDIR_CLAIM/EVIDENCE-CLAIM-REGISTRY.v3.json"
jq '.prohibited_outputs.statuses += ["PANEL_CERTIFIED"]' "$REGISTRY" >"$DRIFT_REGISTRY"
printf '{"status":"PANEL_CERTIFIED"}\n' >"$TMPDIR_CLAIM/future.json"
assert_ok "$CONSENT" claim-scan "$TMPDIR_CLAIM/future.json"
assert_fail env POLYLANE_CLAIM_REGISTRY="$DRIFT_REGISTRY" \
  "$CONSENT" claim-scan "$TMPDIR_CLAIM/future.json"

# If the registry ever stopped forbidding the labels, the scanner must fail
# loudly rather than quietly permit them.
jq '.prohibited_outputs.human_certified_true_forbidden = false' "$REGISTRY" >"$DRIFT_REGISTRY"
assert_fail env POLYLANE_CLAIM_REGISTRY="$DRIFT_REGISTRY" \
  "$CONSENT" claim-scan "$RECORD"

echo "PASS test-hcm-v2-claim-safety.sh ($ASSERTIONS assertions)"
