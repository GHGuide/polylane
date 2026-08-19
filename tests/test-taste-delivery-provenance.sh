#!/usr/bin/env bash
# Regression test for defect c42b-missing-consumed-stdin-proof.
#
# Required v3 control (EVIDENCE-CLAIM-REGISTRY.v3.json, verbatim):
#   "Delivered and consumed stdin SHA-256 and byte count match and are bound by a
#    successful stdin adapter receipt and request receipt."
#
# The control has three limbs. Each limb below names the forgery it must refuse.
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT/bin/polylane-taste-execution-contract.sh"
EXAMPLE="$ROOT/docs/polylane/taste-certification/contracts/execution-v3.example.json"
TMP=${TMPDIR:-/tmp}/polylane-delivery-provenance-test.$$
PASS=0
FAIL=0

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT HUP INT TERM
mkdir -p "$TMP"

ok() { PASS=$((PASS + 1)); printf 'ok %d - %s\n' "$PASS" "$1"; }
not_ok() { FAIL=$((FAIL + 1)); printf 'not ok - %s: %s\n' "$1" "$2" >&2; }

mutate() {
  filter=$1 out=$2
  jq -S -c "$filter" "$EXAMPLE" > "$out"
}

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

assert_invalid() {
  name=$1 filter=$2 code=$3
  file="$TMP/$name.json"
  mutate "$filter" "$file"
  if output=$("$SCRIPT" validate "$file" 2>&1); then
    not_ok "$name" "accepted a manifest with no consumed-stdin proof"
  elif printf '%s' "$output" | grep -F "$code" >/dev/null; then
    ok "$name"
  else
    not_ok "$name" "expected $code, got: $output"
  fi
}

# The frozen example carries a complete, honest proof chain and stays admissible.
assert_valid "frozen-example-keeps-consumed-stdin-proof" "$EXAMPLE"

# Limb 1 - delivered and consumed stdin SHA-256 and byte count must match.
assert_invalid "delivered-and-consumed-digests-must-match" \
  '.prompts[0].consumed_stdin.sha256 = ("7" * 64)' "PROMPT_HASH_DISCONTINUITY"
assert_invalid "delivered-and-consumed-byte-counts-must-match" \
  '.prompts[0].consumed_stdin.byte_count = 99' "PROMPT_HASH_DISCONTINUITY"
assert_invalid "adapter-must-restate-the-consumed-byte-count" \
  '.prompts[0].stdin_adapter.stdin_byte_count = 99' "PROMPT_HASH_DISCONTINUITY"

# Limb 2 - the binding receipt must record a successful adapter invocation.
assert_invalid "failed-adapter-invocation-proves-nothing" \
  '.prompts[0].stdin_adapter.exit_status = 1' "FORGED_RECEIPT"
assert_invalid "adapter-proof-kind-is-pinned" \
  '.prompts[0].stdin_adapter.proof_kind = "assumed"' "STDIN_PROOF_REQUIRED"

# A receipt reused across two distinct deliveries attests neither of them: the
# second prompt is then promoted with no consumed-stdin proof of its own.
assert_invalid "one-delivery-cannot-reuse-another-adapter-invocation" \
  '.prompts[1].stdin_adapter.invocation_id = .prompts[0].stdin_adapter.invocation_id' \
  "CONSUMED_STDIN_PROOF"
assert_invalid "one-delivery-cannot-reuse-another-adapter-receipt" \
  '.prompts[1].stdin_adapter.receipt_sha256 = .prompts[0].stdin_adapter.receipt_sha256
   | .requests |= map(if .prompt_id == "prompt-current"
       then .stdin_adapter_receipt_sha256 = ("5" * 64) else . end)' \
  "CONSUMED_STDIN_PROOF"

# A receipt that merely restates what it attests is a tautology, not evidence.
assert_invalid "receipt-cannot-restate-the-delivered-payload" \
  '.prompts[0].stdin_adapter.receipt_sha256 = .prompts[0].delivered.sha256
   | .requests |= map(if .prompt_id == "prompt-baseline"
       then .stdin_adapter_receipt_sha256 = ("3" * 64) else . end)' \
  "CONSUMED_STDIN_PROOF"
assert_invalid "receipt-cannot-restate-the-request-receipt" \
  '.prompts[0].stdin_adapter.receipt_sha256 = .prompts[0].stdin_adapter.request_receipt_sha256
   | .requests |= map(if .prompt_id == "prompt-baseline"
       then .stdin_adapter_receipt_sha256 = ("d" * 64) else . end)' \
  "CONSUMED_STDIN_PROOF"
assert_invalid "receipt-cannot-restate-the-adapter-binary" \
  '.prompts[0].stdin_adapter.receipt_sha256 = .prompts[0].stdin_adapter.adapter_binary_sha256
   | .requests |= map(if .prompt_id == "prompt-baseline"
       then .stdin_adapter_receipt_sha256 = ("4" * 64) else . end)' \
  "CONSUMED_STDIN_PROOF"

# Limb 3 - the same receipt chain must bind the request that consumed the bytes.
assert_invalid "request-must-cite-the-adapter-receipt" \
  '.requests[0].stdin_adapter_receipt_sha256 = ("7" * 64)' "REQUEST_ADAPTER_MISMATCH"
assert_invalid "adapter-must-cite-the-request-receipt" \
  '.prompts[0].stdin_adapter.request_receipt_sha256 = ("7" * 64)' "REQUEST_ADAPTER_MISMATCH"
assert_invalid "request-must-cite-the-consumed-bytes" \
  '.requests[0].consumed_prompt_sha256 = ("7" * 64)' "REQUEST_PROMPT_MISMATCH"

printf '1..%d\n' $((PASS + FAIL))
if [ "$FAIL" -ne 0 ]; then
  printf '%d test(s) failed\n' "$FAIL" >&2
  exit 1
fi
