#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
CORPUS="$ROOT/bin/polylane-taste-corpus.sh"
TMPDIR_CORPUS=$(mktemp -d "${TMPDIR:-/tmp}/polylane-taste-corpus.XXXXXX")
trap 'rm -rf "$TMPDIR_CORPUS"' EXIT HUP INT TERM
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

write_manifest() {
  manifest_path=$1
  cat >"$manifest_path" <<'JSON'
{
  "format_version": 1,
  "sources": [
    {"id":"source-a","url":"https://example.test/source-a","source_ref":"v1","source_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","license_receipt":{"spdx":"CC0-1.0","url":"https://creativecommons.org/publicdomain/zero/1.0/","sha256":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}},
    {"id":"source-b","url":"https://example.test/source-b","source_ref":"2026-08","source_sha256":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","license_receipt":{"spdx":"CC-BY-4.0","url":"https://creativecommons.org/licenses/by/4.0/","sha256":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"}}
  ],
  "records": [
    {"id":"analytics-cal-1","source_id":"source-a","domain":"analytics","split":"calibration","asset_sha256":"0000000000000000000000000000000000000000000000000000000000000001","human_rating":4},
    {"id":"analytics-hold-1","source_id":"source-a","domain":"analytics","split":"holdout","asset_sha256":"0000000000000000000000000000000000000000000000000000000000000002","human_rating":3},
    {"id":"commerce-cal-1","source_id":"source-a","domain":"commerce","split":"calibration","asset_sha256":"0000000000000000000000000000000000000000000000000000000000000003","human_rating":5},
    {"id":"commerce-hold-1","source_id":"source-a","domain":"commerce","split":"holdout","asset_sha256":"0000000000000000000000000000000000000000000000000000000000000004","human_rating":2},
    {"id":"productivity-cal-1","source_id":"source-b","domain":"productivity","split":"calibration","asset_sha256":"0000000000000000000000000000000000000000000000000000000000000005","human_rating":1},
    {"id":"productivity-hold-1","source_id":"source-b","domain":"productivity","split":"holdout","asset_sha256":"0000000000000000000000000000000000000000000000000000000000000006","human_rating":4}
  ]
}
JSON
}

MANIFEST="$TMPDIR_CORPUS/valid.json"
write_manifest "$MANIFEST"

assert_ok "$CORPUS" validate "$MANIFEST"

SAMPLE_ONE="$TMPDIR_CORPUS/sample-one.txt"
SAMPLE_TWO="$TMPDIR_CORPUS/sample-two.txt"
"$CORPUS" sample "$MANIFEST" calibration 2 fixed-seed >"$SAMPLE_ONE"
"$CORPUS" sample "$MANIFEST" calibration 2 fixed-seed >"$SAMPLE_TWO"
cmp -s "$SAMPLE_ONE" "$SAMPLE_TWO"
ASSERTIONS=$((ASSERTIONS + 1))
[ "$(wc -l <"$SAMPLE_ONE" | tr -d ' ')" = "2" ]
ASSERTIONS=$((ASSERTIONS + 1))

jq '.records[1].split = "calibration"' "$MANIFEST" >"$TMPDIR_CORPUS/unbalanced.json"
assert_fail "$CORPUS" validate "$TMPDIR_CORPUS/unbalanced.json"

jq '.records[1].asset_sha256 = .records[0].asset_sha256' "$MANIFEST" >"$TMPDIR_CORPUS/duplicate.json"
assert_fail "$CORPUS" validate "$TMPDIR_CORPUS/duplicate.json"

jq '.sources[0].license_receipt.spdx = "OPEN"' "$MANIFEST" >"$TMPDIR_CORPUS/ambiguous-rights.json"
assert_fail "$CORPUS" validate "$TMPDIR_CORPUS/ambiguous-rights.json"

jq '.records[0].trusted = true' "$MANIFEST" >"$TMPDIR_CORPUS/trust-boolean.json"
assert_fail "$CORPUS" validate "$TMPDIR_CORPUS/trust-boolean.json"

# --- Strict schema: unknown keys and duplicate keys fail closed ----------
jq '.injected_flag = "production"' "$MANIFEST" >"$TMPDIR_CORPUS/unknown-key.json"
assert_fail "$CORPUS" validate "$TMPDIR_CORPUS/unknown-key.json"
printf '%s\n' '{"format_version":1,"format_version":1,"sources":[],"records":[]}' >"$TMPDIR_CORPUS/dupkey.json"
assert_fail "$CORPUS" validate "$TMPDIR_CORPUS/dupkey.json"

# --- Receipt-producing mode (Cycle 39) -----------------------------------
RECEIPT="$TMPDIR_CORPUS/corpus-receipt.json"
RECEIPT2="$TMPDIR_CORPUS/corpus-receipt2.json"
CORPUS_FP=$(shasum -a 256 "$CORPUS" | awk '{print $1}')
MANIFEST_SHA=$(shasum -a 256 "$MANIFEST" | awk '{print $1}')
rm -f "$RECEIPT"
assert_ok "$CORPUS" receipt "$MANIFEST" holdout 2 fixed-seed "$RECEIPT"
expect_eq taste-corpus-receipt/v1 "$(jq -r .schema_version "$RECEIPT")" schema
expect_eq VALIDATED "$(jq -r .status "$RECEIPT")" status
expect_eq fixture "$(jq -r .classification "$RECEIPT")" classification
expect_eq "$MANIFEST_SHA" "$(jq -r .input_sha256 "$RECEIPT")" input-hash
expect_eq "$MANIFEST_SHA" "$(jq -r .inputs.corpus_manifest_sha256 "$RECEIPT")" manifest-hash-named
expect_eq polylane-taste-corpus "$(jq -r '.validator.id' "$RECEIPT")" validator-id
expect_eq "$CORPUS_FP" "$(jq -r '.validator.fingerprint' "$RECEIPT")" validator-fingerprint
expect_eq holdout "$(jq -r '.sample.split' "$RECEIPT")" sample-split
expect_eq 2 "$(jq -r '.sample.count' "$RECEIPT")" sample-count
expect_eq 2 "$(jq -r '.sample.ids | length' "$RECEIPT")" sample-ids
expect_eq 2 "$(jq -r '.sample.asset_sha256 | length' "$RECEIPT")" sample-hashes
expect_eq fixed-seed "$(jq -r '.sample.seed' "$RECEIPT")" sample-seed
expect_eq true "$(jq -r '.separation.balanced' "$RECEIPT")" separation-balanced
expect_eq 6 "$(jq -r '.human_labels.records' "$RECEIPT")" human-labels
expect_eq 2 "$(jq -r '.provenance.sources | length' "$RECEIPT")" provenance-sources
expect_eq 0 "$(jq -r '.reason_codes | length' "$RECEIPT")" reason-codes
expect_eq "" "$(jq --stream -r 'select(length==2)|.[0]|map(tostring)|join(".")' "$RECEIPT" | LC_ALL=C sort | uniq -d)" no-dup-keys

# Determinism: same split/count/seed → identical deterministic sample binding.
"$CORPUS" receipt "$MANIFEST" holdout 2 fixed-seed "$RECEIPT2"
expect_eq "$(jq -cS .sample.ids "$RECEIPT")" "$(jq -cS .sample.ids "$RECEIPT2")" deterministic-ids
expect_eq "$(jq -r .sample.sample_sha256 "$RECEIPT")" "$(jq -r .sample.sample_sha256 "$RECEIPT2")" deterministic-sample-hash

# Fail-closed: invalid corpus yields no receipt (no partial output).
rm -f "$RECEIPT"
assert_fail "$CORPUS" receipt "$TMPDIR_CORPUS/unbalanced.json" holdout 2 fixed-seed "$RECEIPT"
[ ! -e "$RECEIPT" ] || { echo "FAIL: partial receipt written on invalid corpus" >&2; exit 1; }
ASSERTIONS=$((ASSERTIONS + 1))
assert_fail "$CORPUS" receipt "$TMPDIR_CORPUS/unknown-key.json" holdout 2 fixed-seed "$RECEIPT"

echo "PASS test-taste-corpus assertions=$ASSERTIONS"
