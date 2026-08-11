#!/usr/bin/env bash
# Validate and deterministically sample a local, pinned UI taste corpus.
set -euo pipefail

usage() {
  cat <<'USAGE'
usage:
  polylane-taste-corpus.sh validate MANIFEST.json
  polylane-taste-corpus.sh sample MANIFEST.json calibration|holdout COUNT SEED
USAGE
}

fail() {
  echo "TASTE-CORPUS-INVALID: $*" >&2
  exit 1
}

require_tools() {
  command -v jq >/dev/null 2>&1 || fail "jq is required"
  command -v shasum >/dev/null 2>&1 || fail "shasum is required"
}

validate_manifest() {
  manifest=$1
  [ -f "$manifest" ] || fail "manifest is not a file"

  jq -e '
    def hash: type == "string" and test("^[0-9a-f]{64}$");
    def stable_id: type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]*$");
    def receipt:
      type == "object"
      and (.spdx as $spdx | ($spdx | type == "string") and (["CC0-1.0", "CC-BY-4.0", "CC-BY-SA-4.0", "MIT", "Apache-2.0"] | index($spdx) != null))
      and (.url | type == "string" and test("^https://[^[:space:]]+$"))
      and (.sha256 | hash);
    . as $manifest
    | type == "object"
    and .format_version == 1
    and (.sources | type == "array" and length > 0)
    and (.records | type == "array" and length > 0)
    and all(.sources[];
      type == "object"
      and (.id | stable_id)
      and (.url | type == "string" and test("^https://[^[:space:]]+$"))
      and (.source_ref | type == "string" and length > 0)
      and (.source_sha256 | hash)
      and (.license_receipt | receipt))
    and ([.sources[].id] | length == (unique | length))
    and all(.records[];
      type == "object"
      and (.id | stable_id)
      and (.source_id | stable_id)
      and (.domain | stable_id)
      and (.split == "calibration" or .split == "holdout")
      and (.asset_sha256 | hash)
      and (.human_rating | type == "number" and . >= 1 and . <= 5))
    and ([.records[].id] | length == (unique | length))
    and ([.records[].asset_sha256] | length == (unique | length))
    and all(.records[]; .source_id as $source_id | any($manifest.sources[]; .id == $source_id))
    and ([.records[].domain] | unique) as $domains
    | ($domains | length >= 3)
    and all($domains[];
      . as $domain
      | ([$manifest.records[] | select(.domain == $domain and .split == "calibration")] | length) as $calibration
      | ([$manifest.records[] | select(.domain == $domain and .split == "holdout")] | length) as $holdout
      | $calibration > 0 and $calibration == $holdout)
    and ([paths(type == "boolean")] | length == 0)
  ' "$manifest" >/dev/null || fail "manifest must contain pinned, licensed, balanced records without trust booleans"
}

sample_manifest() {
  manifest=$1
  split=$2
  count=$3
  seed=$4

  case "$split" in calibration|holdout) ;; *) fail "split must be calibration or holdout" ;; esac
  case "$count" in ''|*[!0-9]*) fail "count must be a positive integer" ;; esac
  [ "$count" -gt 0 ] || fail "count must be a positive integer"
  [ -n "$seed" ] || fail "seed must not be empty"

  validate_manifest "$manifest"
  available=$(jq -r --arg split "$split" '[.records[] | select(.split == $split)] | length' "$manifest")
  [ "$count" -le "$available" ] || fail "count exceeds available records"

  jq -r --arg split "$split" '.records[] | select(.split == $split) | .id' "$manifest" |
    while IFS= read -r record_id; do
      digest=$(printf '%s\n' "$seed|$record_id" | shasum -a 256 | awk '{print $1}')
      printf '%s\t%s\n' "$digest" "$record_id"
    done |
    LC_ALL=C sort -k1,1 -k2,2 |
    awk -F '\t' -v limit="$count" 'NR <= limit { print $2 }'
}

main() {
  require_tools
  [ "$#" -ge 2 ] || { usage >&2; exit 2; }
  case "$1" in
    validate)
      [ "$#" -eq 2 ] || { usage >&2; exit 2; }
      validate_manifest "$2"
      ;;
    sample)
      [ "$#" -eq 5 ] || { usage >&2; exit 2; }
      sample_manifest "$2" "$3" "$4" "$5"
      ;;
    *) usage >&2; exit 2 ;;
  esac
}

main "$@"
