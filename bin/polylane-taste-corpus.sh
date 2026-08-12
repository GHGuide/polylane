#!/usr/bin/env bash
# Validate and deterministically sample a local, pinned UI taste corpus.
set -euo pipefail

usage() {
  cat <<'USAGE'
usage:
  polylane-taste-corpus.sh validate MANIFEST.json
  polylane-taste-corpus.sh sample MANIFEST.json calibration|holdout COUNT SEED
  polylane-taste-corpus.sh receipt MANIFEST.json calibration|holdout COUNT SEED OUT.json
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

regular_json_without_duplicate_keys() {
  duplicate_paths=$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("")' "$1" 2>/dev/null | LC_ALL=C sort | uniq -d)
  [ -z "$duplicate_paths" ]
}

validate_manifest() {
  manifest=$1
  [ -f "$manifest" ] && [ ! -L "$manifest" ] || fail "manifest is not a regular file"
  jq -e . "$manifest" >/dev/null 2>&1 || fail "manifest is not valid JSON"
  regular_json_without_duplicate_keys "$manifest" || fail "manifest has duplicate JSON keys"

  jq -e '
    def hash: type == "string" and test("^[0-9a-f]{64}$");
    def stable_id: type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]*$");
    def receipt:
      type == "object"
      and ((keys - ["sha256", "spdx", "url"]) == [])
      and (.spdx as $spdx | ($spdx | type == "string") and (["CC0-1.0", "CC-BY-4.0", "CC-BY-SA-4.0", "MIT", "Apache-2.0"] | index($spdx) != null))
      and (.url | type == "string" and test("^https://[^[:space:]]+$"))
      and (.sha256 | hash);
    . as $manifest
    | type == "object"
    and ((keys - ["format_version", "records", "sources"]) == [])
    and .format_version == 1
    and (.sources | type == "array" and length > 0)
    and (.records | type == "array" and length > 0)
    and all(.sources[];
      type == "object"
      and ((keys - ["id", "license_receipt", "source_ref", "source_sha256", "url"]) == [])
      and (.id | stable_id)
      and (.url | type == "string" and test("^https://[^[:space:]]+$"))
      and (.source_ref | type == "string" and length > 0)
      and (.source_sha256 | hash)
      and (.license_receipt | receipt))
    and ([.sources[].id] | length == (unique | length))
    and all(.records[];
      type == "object"
      and ((keys - ["asset_sha256", "domain", "human_rating", "id", "source_id", "split"]) == [])
      and (.id | stable_id)
      and (.source_id | stable_id)
      and (.domain | stable_id)
      and (.split == "calibration" or .split == "holdout")
      and (.asset_sha256 | hash)
      and (.human_rating | type == "number" and . >= 1 and . <= 5))
    and ([.records[].id] | length == (unique | length))
    and ([.records[].asset_sha256] | length == (unique | length))
    and all(.records[]; .source_id as $source_id | any($manifest.sources[]; .id == $source_id))
    and (([.records[].domain] | unique) as $domains
      | ($domains | length >= 3)
      and all($domains[];
        . as $domain
        | ([$manifest.records[] | select(.domain == $domain and .split == "calibration")] | length) as $calibration
        | ([$manifest.records[] | select(.domain == $domain and .split == "holdout")] | length) as $holdout
        | $calibration > 0 and $calibration == $holdout))
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

# Emit an atomic, hash-bound corpus receipt.  Validation runs first, so an
# invalid corpus produces no partial output (fail-closed).  classification is
# validator-derived "fixture": a real production corpus needs verifiable
# acquisition/access receipts this hermetic cycle does not authorize; a missing
# fetch is external but can never be a production PASS.
receipt_manifest() {
  manifest=$1; split=$2; count=$3; seed=$4; out=$5
  case "$split" in calibration|holdout) ;; *) fail "split must be calibration or holdout" ;; esac
  case "$count" in ''|*[!0-9]*) fail "count must be a positive integer" ;; esac
  [ "$count" -gt 0 ] || fail "count must be a positive integer"
  [ -n "$seed" ] || fail "seed must not be empty"
  [ -n "$out" ] || fail "output path is required"

  validate_manifest "$manifest"

  sample_ids=$(sample_manifest "$manifest" "$split" "$count" "$seed")
  sample_sha256=$(printf '%s' "$sample_ids" | shasum -a 256 | awk '{print $1}')
  manifest_sha=$(shasum -a 256 "$manifest" | awk '{print $1}')
  validator_fp=$(shasum -a 256 "$0" | awk '{print $1}')
  now=${TASTE_NOW:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}
  ids_json=$(printf '%s\n' "$sample_ids" | jq -R . | jq -s 'map(select(length > 0))')

  tmp=$(mktemp "${out}.tmp.XXXXXX") || fail "mktemp failed"
  jq -n \
    --arg schema taste-corpus-receipt/v1 \
    --arg vid polylane-taste-corpus --arg vfp "$validator_fp" \
    --arg now "$now" --arg manifest_sha "$manifest_sha" \
    --arg split "$split" --argjson count "$count" --arg seed "$seed" \
    --arg sample_sha256 "$sample_sha256" --argjson ids "$ids_json" \
    --slurpfile manifest "$manifest" '
    ($manifest[0]) as $m
    | ($m.records | group_by(.domain)
        | map({key:.[0].domain, value:{calibration:([.[]|select(.split=="calibration")]|length), holdout:([.[]|select(.split=="holdout")]|length)}})
        | from_entries) as $per_domain
    | ($m.records | group_by(.domain)
        | all(([.[]|select(.split=="calibration")]|length) == ([.[]|select(.split=="holdout")]|length))) as $balanced
    | ($ids | map(. as $id | ($m.records[] | select(.id == $id) | .asset_sha256))) as $asset_hashes
    | {
      schema_version:$schema,
      receipt_version:"polylane.taste.corpus-receipt.v1",
      status:"VALIDATED",
      classification:"fixture",
      validator:{id:$vid, fingerprint:$vfp},
      executed_at:$now,
      input_sha256:$manifest_sha,
      inputs:{corpus_manifest_sha256:$manifest_sha},
      subject:{format_version:$m.format_version},
      provenance:{sources:[$m.sources[] | {id, source_ref, source_sha256, spdx:.license_receipt.spdx, license_url:.license_receipt.url, license_sha256:.license_receipt.sha256}]},
      separation:{domains:($m.records|map(.domain)|unique), per_domain:$per_domain, balanced:$balanced},
      human_labels:{records:($m.records|length), rating_min:($m.records|map(.human_rating)|min), rating_max:($m.records|map(.human_rating)|max)},
      sample:{split:$split, count:$count, seed:$seed, ids:$ids, asset_sha256:$asset_hashes, sample_sha256:$sample_sha256},
      output:{record_count:($m.records|length), source_count:($m.sources|length)},
      reason_codes:[]
    }' > "$tmp" || { rm -f "$tmp"; fail "receipt render failed"; }
  mv -f "$tmp" "$out"
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
    receipt)
      [ "$#" -eq 6 ] || { usage >&2; exit 2; }
      receipt_manifest "$2" "$3" "$4" "$5" "$6"
      ;;
    *) usage >&2; exit 2 ;;
  esac
}

main "$@"
