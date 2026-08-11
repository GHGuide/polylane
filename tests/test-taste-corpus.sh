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

echo "PASS test-taste-corpus assertions=$ASSERTIONS"
