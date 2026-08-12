#!/usr/bin/env bash
# End-to-end assembly test for the live taste-study harness.
#
# It assembles the COMPLETE production-shaped evidence chain, freezes it, and
# compiles a study certificate through the LIVE certificate compiler.  It then
# proves that fixture ancestry cannot cross the production boundary: a genuine
# hermetic receipt from the real calibrate producer (classification:fixture) and
# a Cycle-39 fixture ballot are both rejected in the deciding roles.
#
# This is engineering proof of chain shape and closure only.  It does NOT claim a
# live study occurred: the study certificate records live_study_executed:false
# and the still-external prerequisites (real renders, human labels, human panel).
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
# Reuse the study-live builder, hermetic repo, and helpers as a library.
TASTE_STUDY_LIB=1 . "$ROOT/tests/test-taste-study-live.sh"
CALIBRATE="$ROOT/bin/polylane-taste-calibrate.sh"

# --- 1. Complete production-shaped chain compiles a frozen study certificate ---
E="$WORK/e2e"
build_live "$E" "5 5 5 5 5 5 5 5 5 5"
freeze_spec "$E" "$WORK/e2e-spec.json"
"$STUDY" freeze "$WORK/e2e-spec.json" "$WORK/e2e-freeze.json" >/dev/null || fail "e2e freeze rejected valid spec"
STUDY_CERT="$WORK/e2e-study-cert.json"
"$STUDY" compile "$WORK/e2e-freeze.json" "$E/manifest.json" "$STUDY_CERT" "$REPO" \
  || fail "e2e study compile rejected the production-shaped chain: $(cat "$STUDY_CERT")"
assert_json "$STUDY_CERT" '.schema_version == "taste-study-certificate/v1" and .status == "STUDY-CHAIN-VERIFIED"'
assert_json "$STUDY_CERT" '.claim_label == "HUMAN_CALIBRATED_MACHINE" and .human_certified == false'
# The load-bearing honesty assertions: a compiler cannot execute a live study.
assert_json "$STUDY_CERT" '.live_study_executed == false'
assert_json "$STUDY_CERT" '(.external_prerequisites | length) >= 4 and (.verdict_reason_codes | length) == 0'

# Determinism: recompiling the frozen chain yields a byte-identical certificate.
"$STUDY" compile "$WORK/e2e-freeze.json" "$E/manifest.json" "$WORK/e2e-study-cert-2.json" "$REPO" \
  || fail "e2e recompile failed"
[ "$(jq -cS . "$STUDY_CERT")" = "$(jq -cS . "$WORK/e2e-study-cert-2.json")" ] \
  || fail "study certificate is not deterministic"

# --- 2. A REAL producer receipt is fixture-grade and cannot cross into a live
#        deciding role.  Drive the actual calibrate producer, then splice its
#        output into the chain's first calibration slot. -----------------------
CU=$(jq -nc '[range(0;24) | . as $u | (if $u % 2 == 0 then 1 else 2 end) as $g |
  {prompt:("p-"+($u|tostring)), brief:("b-"+($u|tostring)), gold_vote:$g,
   primary:{provider:"prov-claude", model:"m-one", vote:$g, request:{prompt:("p-"+($u|tostring)), brief:("b-"+($u|tostring))}},
   mirror:{provider:"prov-claude", model:"m-one", vote:(3-$g), request:{prompt:("p-"+($u|tostring)), brief:("b-"+($u|tostring))}}}]')
CAL_IN="$E/receipts/cal-judge-1-1-a-input.json"
write_json "$CAL_IN" "{\"schema_version\":1,\"calibration\":{\"partition\":\"held_out\",\"label_provenance\":\"human-labeled\",\"holdout_corpus_receipt_sha256\":\"$ZERO64\"},\"judge\":{\"id\":\"judge-1-1-a\",\"provider\":\"prov-claude\",\"model\":\"m-one\",\"model_version\":\"2026.08\",\"system_prompt_sha256\":\"$ZERO64\",\"sampling_sha256\":\"$ZERO64\"},\"units\":$CU}"
"$CALIBRATE" "$CAL_IN" "$E/receipts/cal-judge-1-1-a-receipt.json" || fail "real calibrate producer rejected valid input"
# The genuine producer receipt is v1 and NOT production-classified.
assert_json "$E/receipts/cal-judge-1-1-a-receipt.json" '.schema_version == "taste-calibration/v1" and .classification == "fixture" and .eligible == true'
# Re-declare the spliced input + receipt digests so the chain is hash-closed.
jqi "$E/manifest.json" --arg s "$(sha "$CAL_IN")" '(.calibrations[] | select(.input.path == "receipts/cal-judge-1-1-a-input.json") | .input.sha256) = $s'
jqi "$E/manifest.json" --arg s "$(sha "$E/receipts/cal-judge-1-1-a-receipt.json")" '(.calibrations[] | select(.receipt.path == "receipts/cal-judge-1-1-a-receipt.json") | .receipt.sha256) = $s'
# Non-live compat compiler still accepts it (fixture-grade evidence).
"$TASTE" certify "$E/manifest.json" "$WORK/e2e-compat-cert.json" "$REPO" \
  || fail "non-live compiler rejected a genuine producer receipt"
assert_json "$WORK/e2e-compat-cert.json" '.status == "TASTE-CERTIFIED" and .fixture_only == false and .live_mode == false'
# But the frozen LIVE study rejects the fixture producer receipt.
CROSS="$WORK/e2e-cross-cal.json"
printf 'prior' >"$CROSS"
if "$STUDY" compile "$WORK/e2e-freeze.json" "$E/manifest.json" "$CROSS" "$REPO"; then fail "live study accepted a fixture producer receipt"; fi
assert_json "$CROSS" '.status == "NOT-CERTIFIED" and (.verdict_reason_codes | index("CALIBRATION_NOT_PRODUCTION")) != null'
assert_json "$CROSS" '.live_study_executed == false'

# --- 3. A Cycle-39 fixture ballot cannot cross the production ballot boundary --
F="$WORK/e2e-fixture-ballot"; rm -rf "$F"; cp -R "$E" "$F"
# restore the production calibration receipt from a fresh build so only the
# ballot mutation is under test.
build_live "$F" "5 5 5 5 5 5 5 5 5 5"
freeze_spec "$F" "$WORK/f-spec.json"
"$STUDY" freeze "$WORK/f-spec.json" "$WORK/f-freeze.json" >/dev/null || fail "fixture-ballot freeze rejected"
jqi "$F/receipts/brief-1-group-1-receipt.json" \
  '.schema_version = "taste-ballot-validation/v1" | .fixture_only = true | del(.classification) | del(.session_ids)'
jqi "$F/manifest.json" --arg s "$(sha "$F/receipts/brief-1-group-1-receipt.json")" '.briefs[0].groups[0].receipt.sha256 = $s'
CROSS2="$WORK/e2e-cross-ballot.json"
printf 'prior' >"$CROSS2"
if "$STUDY" compile "$WORK/f-freeze.json" "$F/manifest.json" "$CROSS2" "$REPO"; then fail "live study accepted a Cycle-39 fixture ballot"; fi
assert_json "$CROSS2" '.status == "NOT-CERTIFIED" and (.verdict_reason_codes | index("FIXTURE_EVIDENCE")) != null'
assert_json "$CROSS2" '.live_study_executed == false'

printf 'PASS: taste live-harness e2e\n'
