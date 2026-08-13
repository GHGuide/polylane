#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT/bin/polylane-taste-execution-contract.sh"
SCHEMA="$ROOT/docs/polylane/taste-certification/contracts/execution-v3.schema.json"
EXAMPLE="$ROOT/docs/polylane/taste-certification/contracts/execution-v3.example.json"
TMP=${TMPDIR:-/tmp}/polylane-execution-v3-test.$$
PASS=0
FAIL=0

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT HUP INT TERM
mkdir -p "$TMP"

sha_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

ok() { PASS=$((PASS + 1)); printf 'ok %d - %s\n' "$PASS" "$1"; }
not_ok() { FAIL=$((FAIL + 1)); printf 'not ok - %s: %s\n' "$1" "$2" >&2; }

assert_valid() {
  name=$1 file=$2
  if output=$("$SCRIPT" validate "$file" 2>&1); then
    case $output in
      VALID\ execution-v3\ *) ok "$name" ;;
      *) not_ok "$name" "unexpected output: $output" ;;
    esac
  else
    not_ok "$name" "$output"
  fi
}

mutate() {
  filter=$1 out=$2
  jq -S -c "$filter" "$EXAMPLE" > "$out"
}

assert_invalid() {
  name=$1 filter=$2 code=$3
  file="$TMP/$name.json"
  mutate "$filter" "$file"
  if output=$("$SCRIPT" validate "$file" 2>&1); then
    not_ok "$name" "accepted invalid contract"
  elif printf '%s' "$output" | grep -F "$code" >/dev/null; then
    ok "$name"
  else
    not_ok "$name" "expected $code, got: $output"
  fi
}

# A missing validator/schema/example is the intended first RED failure. Once present,
# every assertion below names a concrete trust-boundary mutation it must catch.
assert_valid "normative-example-validates" "$EXAMPLE"

if bash -c '. "$1"; command -v validate >/dev/null' _ "$SCRIPT" >/dev/null 2>&1; then
  ok "validator-is-safe-to-source"
else
  not_ok "validator-is-safe-to-source" "top-level CLI executed while sourced"
fi

if [ -f "$SCHEMA" ] && jq -e '."$schema" == "https://json-schema.org/draft/2020-12/schema" and .additionalProperties == false' "$SCHEMA" >/dev/null 2>&1; then
  ok "schema-is-strict-draft-2020-12"
else
  not_ok "schema-is-strict-draft-2020-12" "missing or permissive schema"
fi

if [ -f "$SCHEMA" ] && jq -e '[.. | objects | select(has("properties")) | .additionalProperties] | all(. == false)' "$SCHEMA" >/dev/null 2>&1; then
  ok "schema-closes-unknown-keys-at-every-object"
else
  not_ok "schema-closes-unknown-keys-at-every-object" "nested object permits unknown keys"
fi

if [ -f "$EXAMPLE" ] && cmp -s "$EXAMPLE" <(jq -S -c . "$EXAMPLE"); then
  ok "example-is-canonical-json"
else
  not_ok "example-is-canonical-json" "example bytes are not jq -S -c canonical"
fi

if [ -x "$SCRIPT" ] && fingerprint=$("$SCRIPT" fingerprint "$EXAMPLE" 2>/dev/null) && [ "$fingerprint" = "$(sha_file "$EXAMPLE")" ]; then
  ok "fingerprint-binds-exact-canonical-bytes"
else
  not_ok "fingerprint-binds-exact-canonical-bytes" "fingerprint mismatch"
fi

assert_invalid "unknown-top-level-key" '. + {surprise:true}' "UNKNOWN_KEYS"
assert_invalid "unsafe-artifact-path" '.builds[0] += {artifact_path:"../../escape"}' "UNKNOWN_KEYS"
assert_invalid "prompt-delivered-consumed-discontinuity" '.prompts[0].consumed_stdin.sha256 = ("0" * 64)' "PROMPT_HASH_DISCONTINUITY"
assert_invalid "prompt-path-only-is-not-consumption" '.prompts[0].stdin_adapter.proof_kind = "path-only"' "STDIN_PROOF_REQUIRED"
assert_invalid "request-does-not-bind-consumed-prompt" '.requests[0].consumed_prompt_sha256 = ("1" * 64)' "REQUEST_PROMPT_MISMATCH"
assert_invalid "request-does-not-bind-adapter-receipt" '.requests[0].stdin_adapter_receipt_sha256 = ("2" * 64)' "REQUEST_ADAPTER_MISMATCH"
assert_invalid "adapter-failed" '.prompts[0].stdin_adapter.exit_status = 1' "FORGED_RECEIPT"
assert_invalid "provider-substituted-request-receipt" '.requests[0].provider_receipt.provider_org_id = "provider-substitute"' "PROVIDER_SUBSTITUTION"
assert_invalid "provider-receipt-signature-missing" '.requests[0].provider_receipt.signature_sha256 = ""' "MISSING_HASH"
assert_invalid "unequal-arm-token-budget" '.arms[1].compute.token_budget += 1' "ARM_INEQUALITY"
assert_invalid "unequal-arm-replicates" '.arms[1].compute.build_replicates = 2' "ARM_INEQUALITY"
assert_invalid "wrong-build-cardinality" 'del(.builds[-1])' "BUILD_CARDINALITY"
assert_invalid "repeated-measures-cannot-inflate-n" '.preregistration.independent_brief_count = (.captures | length)' "INDEPENDENT_UNIT_COUNT"
assert_invalid "duplicate-brief-id" '.brief_units += [.brief_units[0]] | .preregistration.independent_brief_count = 2' "DUPLICATE_ID"
assert_invalid "split-family-leakage" '.brief_units += [(.brief_units[0] | .brief_id = "brief-ffffffffffffffff" | .brief_bytes_sha256 = ("f" * 64) | .split = "confirmatory")] | .preregistration.independent_brief_count = 2' "SPLIT_LEAKAGE"
assert_invalid "stale-source-revision" '.source_cohorts[0].immutable_revision = "changed-after-freeze"' "STALE_SOURCE_REVISION"
assert_invalid "source-revision-digest-binds-exact-revision-bytes" '.source_cohorts[0].immutable_revision = ("d" * 40) | .source_cohorts[0].revision_sha256 = ("0" * 64) | .brief_units[0].source_revision_sha256 = ("0" * 64) | .requests[].source_revision_sha256 = ("0" * 64)' "SOURCE_REVISION_DIGEST"
assert_invalid "stale-model-revision" '.model_configs[0].model_revision = "changed-after-freeze"' "STALE_MODEL_REVISION"
assert_invalid "model-fingerprint-binds-full-config" '.model_configs[0].model_revision = ("d" * 40) | .requests[].provider_receipt.model_revision = ("d" * 40)' "MODEL_CONFIG_FINGERPRINT"
assert_invalid "missing-candidate-tree-hash" '.builds[0].candidate_tree_sha256 = ""' "MISSING_HASH"
assert_invalid "duplicate-request-id" '.requests[1].request_id = .requests[0].request_id' "DUPLICATE_ID"
assert_invalid "dangling-direction-reference" '.requests[0].direction_lock_id = "direction-missing"' "REFERENCE_MISMATCH"
assert_invalid "request-source-revision-discontinuity" '.requests[0].source_revision_sha256 = ("7" * 64)' "SOURCE_REQUEST_MISMATCH"
assert_invalid "candidate-tree-chain-break" '.captures[0].candidate_tree_sha256 = ("3" * 64)' "ARTIFACT_CHAIN_MISMATCH"
assert_invalid "mirrored-orientation-copies-new-captures" '.stimuli[1].capture_a_ids[0] = .captures[-1].capture_id' "MIRROR_MISMATCH"
assert_invalid "stimulus-captures-cannot-cross-briefs" '.stimuli[0].brief_id = "brief-other"' "REFERENCE_MISMATCH"
assert_invalid "probabilities-must-sum-to-one" '.judge_responses[0].probabilities.a = 0.9' "PROBABILITY_SUM"
assert_invalid "judge-cannot-vote-on-own-lineage" '.model_configs[] |= if .role == "judge" then .base_lineage_id = "lineage-builder" else . end' "SELF_LINEAGE_JUDGE"
assert_invalid "repeated-judge-invocations-are-distinct" '.judge_responses[1].invocation_id = .judge_responses[0].invocation_id' "DUPLICATE_MEASUREMENT_ID"
assert_invalid "participant-sees-brief-only-once" '.human_ballots[1].participant_id = .human_ballots[0].participant_id' "DUPLICATE_PARTICIPANT_EXPOSURE"
assert_invalid "ballot-binds-stimulus-orientation" '.human_ballots[0].orientation = "BA"' "BALLOT_BINDING"
assert_invalid "human-ballot-requires-consent" 'del(.consents[0])' "CONSENT_REQUIRED"
assert_invalid "human-ballot-requires-governance" '.governance_receipts[0].approval_status = "pending"' "GOVERNANCE_REQUIRED"
assert_invalid "ancestry-must-be-complete" 'del(.ancestry.nodes[-1])' "INCOMPLETE_ANCESTRY"
assert_invalid "ancestry-must-include-direct-dependencies" 'del(.ancestry.edges[] | select(.parent_id == "prompt-baseline" and .child_id == "request-b-1"))' "INCOMPLETE_ANCESTRY"
assert_invalid "ancestry-must-be-acyclic" '.ancestry.edges += [{parent_id:.ancestry.nodes[-1],child_id:.ancestry.nodes[0]}]' "ANCESTRY_CYCLE"

pretty="$TMP/noncanonical.json"
jq . "$EXAMPLE" > "$pretty" 2>/dev/null || true
if output=$("$SCRIPT" validate "$pretty" 2>&1); then
  not_ok "noncanonical-json-rejected" "accepted pretty JSON"
elif printf '%s' "$output" | grep -F "NONCANONICAL_JSON" >/dev/null; then
  ok "noncanonical-json-rejected"
else
  not_ok "noncanonical-json-rejected" "unexpected output: $output"
fi

printf '1..%d\n' $((PASS + FAIL))
if [ "$FAIL" -ne 0 ]; then
  printf '%d test(s) failed\n' "$FAIL" >&2
  exit 1
fi
