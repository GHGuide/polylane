#!/usr/bin/env bash
# polylane-taste-source.sh — source-pinned, browser-backed acquisition and
# deterministic split for the taste calibration corpus.
#
# This Bash core is hermetic: it reads a caller-supplied content-addressed cache
# and a pinned acquisition plan, joins raw ratings, aggregate ratings, and images,
# and emits a corpus manifest (see bin/polylane-taste-corpus.sh) plus a receipt
# that binds source ids, versions, licences, checksums, split seed, raw-rating
# support, and the reproduction command. It never fetches. The network lives only
# in the explicit external adapter (benchmarks/taste-live/tools/dataverse-acquire.mjs),
# reached only through the guarded `canary` command: a missing Chrome, network, or
# real bytes is UNKNOWN, never a fixture PASS.
#
# Bash 3.2 safe: no associative arrays, no process substitution.
set -euo pipefail

usage() {
  cat <<'USAGE'
usage:
  polylane-taste-source.sh verify-cache CACHE_DIR PLAN.json
  polylane-taste-source.sh build        CACHE_DIR PLAN.json MANIFEST.json [RECEIPT.json]
  polylane-taste-source.sh secondary    CACHE_DIR PLAN.json MANIFEST.json [RECEIPT.json]
  polylane-taste-source.sh canary       CACHE_DIR PLAN.json [RECEIPT.json]
USAGE
}

fail() { echo "TASTE-SOURCE-INVALID: $*" >&2; exit 1; }

require_tools() {
  command -v jq >/dev/null 2>&1 || fail "jq is required"
  command -v shasum >/dev/null 2>&1 || fail "shasum is required"
}

# Content-addressed object path. The sha is hex-validated so it can never contain
# a path separator or a traversal segment.
obj_path() {
  case "$2" in
    *[!0-9a-f]* | "") fail "non-hex object id: $2" ;;
  esac
  [ "${#2}" -eq 64 ] || fail "object id is not a 64-hex sha256: $2"
  printf '%s/objects/%s/%s' "$1" "${2:0:2}" "$2"
}

# Reject symlink, missing, non-regular, empty, or checksum-mismatched (partial /
# tampered) cache objects. This is where "changed source metadata" and "partial
# cache" both surface: a byte that changed no longer matches its pinned name.
verify_object() {
  cache=$1; sha=$2
  path=$(obj_path "$cache" "$sha")
  [ ! -L "$path" ] || fail "cache object is a symlink: $sha"
  [ -e "$path" ] || fail "cache object missing: $sha"
  [ -f "$path" ] || fail "cache object is not a regular file: $sha"
  [ -s "$path" ] || fail "cache object is empty (partial): $sha"
  actual=$(shasum -a 256 "$path" | awk '{print $1}')
  [ "$actual" = "$sha" ] || fail "cache object checksum mismatch (partial/tampered): $sha"
}

# Structural gate: strict keys, pinned/licensed sources, three unique domains,
# valid split, and NO caller-authored eligibility (booleans or trust-key names).
validate_plan() {
  plan=$1
  [ -f "$plan" ] && [ ! -L "$plan" ] || fail "plan is not a regular file"
  jq -e . "$plan" >/dev/null 2>&1 || fail "plan is not valid JSON"
  jq -e '
    def hash: type == "string" and test("^[0-9a-f]{64}$");
    def stable: type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]*$");
    def posint: type == "number" and . > 0 and (floor == .);
    . as $p
    | type == "object"
    and ((keys - ["classification","domains","images","plan_version","reproduction","sources","split"]) == [])
    and .plan_version == "taste-source-plan/v1"
    and (.classification | type == "string" and (length > 0))
    and (.reproduction | type == "string" and (length > 0))
    # no caller-authored eligibility anywhere
    and ([paths(type == "boolean")] | length == 0)
    and ([.. | objects | keys[] | select(test("^(eligible|certified|trusted|verified|approved)$"))] | length == 0)
    and (.split | type == "object"
      and ((keys - ["calibration_per_domain","holdout_per_domain","seed"]) == [])
      and (.seed | type == "string" and (length > 0))
      and (.calibration_per_domain | posint) and (.holdout_per_domain | posint))
    and (.domains | type == "array" and length == 3
      and all(.[]; stable) and (length == (unique | length)))
    and (.sources | type == "array" and length > 0
      and all(.[];
        type == "object"
        and ((keys - ["aggregate","dataset_pid","dataset_version","id","license","metadata","raw","url"]) == [])
        and (.id | stable)
        and (.dataset_pid | type == "string" and (length > 0))
        and (.dataset_version | type == "string" and (length > 0))
        and (.url | type == "string" and test("^https://[^[:space:]]+$"))
        and (.license | type == "object"
          and ((keys - ["sha256","spdx","url"]) == [])
          and (.spdx as $s | (["CC0-1.0","CC-BY-4.0","CC-BY-SA-4.0","MIT","Apache-2.0"] | index($s) != null))
          and (.url | type == "string" and test("^https://[^[:space:]]+$"))
          and (.sha256 | hash))
        and (.metadata | type == "object" and ((keys - ["sha256"]) == []) and (.sha256 | hash))
        and (.aggregate | type == "object" and ((keys - ["sha256"]) == []) and (.sha256 | hash))
        and (.raw | type == "object" and ((keys - ["sha256"]) == []) and (.sha256 | hash)))
      and ([.[].id] | length == (unique | length)))
    and (.images | type == "array" and length > 0
      and all(.[];
        type == "object"
        and ((keys - ["sha256","source_id","stimulus_id"]) == [])
        and (.stimulus_id | stable)
        and (.source_id | stable)
        and (.sha256 | hash)
        and (.source_id as $sid | any($p.sources[]; .id == $sid))))
  ' "$plan" >/dev/null 2>&1 || fail "plan must be pinned, licensed, three-domain, and free of caller eligibility"
}

# Verify every cache object the plan pins: per-source metadata/aggregate/raw and
# every image.
verify_cache() {
  cache=$1; plan=$2
  validate_plan "$plan"
  [ -d "$cache" ] || fail "cache dir does not exist: $cache"
  jq -r '.sources[] | .metadata.sha256, .aggregate.sha256, .raw.sha256' "$plan" |
    while IFS= read -r sha; do verify_object "$cache" "$sha"; done
  jq -r '.images[].sha256' "$plan" |
    while IFS= read -r sha; do verify_object "$cache" "$sha"; done
}

# Join raw/aggregate/image records into a manifest and stats. All acquisition
# invariants are enforced here and fail closed via jq `error`.
build_manifest() {
  cache=$1; plan=$2; manifest_out=$3; receipt_out=${4:-}
  seed=$(jq -r '.split.seed' "$plan")
  cal=$(jq -r '.split.calibration_per_domain' "$plan")
  hold=$(jq -r '.split.holdout_per_domain' "$plan")

  work=$(mktemp -d "${manifest_out}.work.XXXXXX") || fail "mktemp failed"
  # shellcheck disable=SC2064
  trap "rm -rf '$work'" EXIT HUP INT TERM
  recs_dir="$work/recs"; mkdir -p "$recs_dir"

  images_json=$(jq -c '.images' "$plan")
  src_count=$(jq '.sources | length' "$plan")
  i=0
  while [ "$i" -lt "$src_count" ]; do
    src_id=$(jq -r ".sources[$i].id" "$plan")
    agg_sha=$(jq -r ".sources[$i].aggregate.sha256" "$plan")
    raw_sha=$(jq -r ".sources[$i].raw.sha256" "$plan")
    agg_path=$(obj_path "$cache" "$agg_sha")
    raw_path=$(obj_path "$cache" "$raw_sha")
    jq -n \
      --slurpfile agg "$agg_path" --slurpfile raw "$raw_path" \
      --argjson images "$images_json" --arg src "$src_id" '
      def absval: if . < 0 then -. else . end;
      ($agg[0]) as $A | ($raw[0]) as $R
      | ($A | type == "object") as $ok | if $ok then . else error("aggregate-not-object") end
      | [ $A | to_entries[]
          | .key as $sid | .value as $meta
          | ([$images[] | select(.stimulus_id == $sid and .source_id == $src)]) as $imgs
          | (if ($imgs | length) != 1 then error("image-join:" + $sid) else . end)
          | ($imgs[0].sha256) as $ash
          | (if ($meta | type == "object" and (.mean_rating | type == "number") and (.domain | type == "string"))
             then . else error("aggregate-shape:" + $sid) end)
          | (($R[$sid]) // null) as $rr
          | (if ($rr | type) == "array" then . else error("raw-missing:" + $sid) end)
          | ([$rr[] | select(type == "number")]) as $valid
          | (if ($valid | length) >= 5 then . else error("raw-support:" + $sid) end)
          | (if ($valid | any(. < 1 or . > 5)) then error("raw-range:" + $sid) else . end)
          | (($valid | add) / ($valid | length)) as $mean
          | (if (($mean - $meta.mean_rating) | absval) > 0.5 then error("disagree:" + $sid) else . end)
          | (if ($meta.mean_rating >= 1 and $meta.mean_rating <= 5) then . else error("aggregate-range:" + $sid) end)
          | { id: $sid, source_id: $src, domain: $meta.domain,
              asset_sha256: $ash, human_rating: $meta.mean_rating, raw_n: ($valid | length) }
        ]' >"$recs_dir/$i.json"
    i=$((i + 1))
  done

  jq -s 'add' "$recs_dir"/*.json >"$work/records.json"

  # Deterministic digest per record: sha256(seed|id), computed outside jq.
  : >"$work/digests.tsv"
  jq -r '.[].id' "$work/records.json" |
    while IFS= read -r rid; do
      [ -n "$rid" ] || continue
      d=$(printf '%s\n' "$seed|$rid" | shasum -a 256 | awk '{print $1}')
      printf '%s\t%s\n' "$rid" "$d" >>"$work/digests.tsv"
    done
  digests=$(jq -Rn '[inputs | split("\t") | {(.[0]): .[1]}] | add // {}' "$work/digests.tsv")

  # Quota + uniqueness + deterministic split → { manifest, stats }.
  jq -n \
    --slurpfile plan "$plan" --slurpfile records "$work/records.json" \
    --argjson digests "$digests" --argjson cal "$cal" --argjson hold "$hold" '
    ($plan[0]) as $p | ($records[0]) as $recs
    | ($cal + $hold) as $quota
    | (if ([$recs[].id] | length) == ([$recs[].id] | unique | length) then . else error("duplicate-record-id") end)
    | (if ([$recs[].asset_sha256] | length) == ([$recs[].asset_sha256] | unique | length) then . else error("duplicate-image") end)
    | (if (([$recs[].domain] | unique) == ($p.domains | sort)) then . else error("domain-mismatch") end)
    | ($recs | group_by(.domain)) as $groups
    | (if all($groups[]; length == $quota) then . else error("wrong-domain-quota") end)
    | ($groups
        | map( sort_by($digests[.id], .id)
               | to_entries
               | map(.value + {split: (if .key < $cal then "calibration" else "holdout" end)}) )
        | add) as $split
    | {
        manifest: {
          format_version: 1,
          sources: [ $p.sources[] | {
            id, url,
            source_ref: (.dataset_pid + "@" + .dataset_version),
            source_sha256: .metadata.sha256,
            license_receipt: { spdx: .license.spdx, url: .license.url, sha256: .license.sha256 }
          } ],
          records: [ $split[] | { id, source_id, domain, split, asset_sha256, human_rating } ]
        },
        stats: {
          records: ($recs | length),
          raw_min: ([$recs[].raw_n] | min),
          raw_max: ([$recs[].raw_n] | max),
          per_domain: ($groups | map({ key: .[0].domain,
            value: { calibration: $cal, holdout: $hold } }) | from_entries)
        }
      }' >"$work/combined.json" || fail "acquisition join rejected the corpus"

  tmp_manifest=$(mktemp "${manifest_out}.tmp.XXXXXX") || fail "mktemp failed"
  jq -S '.manifest' "$work/combined.json" >"$tmp_manifest" || { rm -f "$tmp_manifest"; fail "manifest render failed"; }
  mv -f "$tmp_manifest" "$manifest_out"

  if [ -n "$receipt_out" ]; then
    manifest_sha=$(shasum -a 256 "$manifest_out" | awk '{print $1}')
    tool_fp=$(shasum -a 256 "$0" | awk '{print $1}')
    now=${TASTE_NOW:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}
    classification=$(jq -r '.classification' "$plan")
    tmp_receipt=$(mktemp "${receipt_out}.tmp.XXXXXX") || fail "mktemp failed"
    jq -n \
      --slurpfile plan "$plan" --slurpfile combined "$work/combined.json" \
      --arg tool_fp "$tool_fp" --arg now "$now" --arg manifest_sha "$manifest_sha" \
      --arg classification "$classification" '
      ($plan[0]) as $p | ($combined[0].stats) as $s
      | {
          schema_version: "taste-source-acquisition/v1",
          status: "BUILT",
          classification: $classification,
          tool: { id: "polylane-taste-source", fingerprint: $tool_fp },
          executed_at: $now,
          reproduction: $p.reproduction,
          split: $p.split,
          domains: $p.domains,
          per_domain: $s.per_domain,
          raw_support: { min: $s.raw_min, max: $s.raw_max, records: $s.records },
          sources: [ $p.sources[] | {
            id, dataset_pid, dataset_version, url,
            spdx: .license.spdx, license_url: .license.url, license_sha256: .license.sha256,
            metadata_sha256: .metadata.sha256,
            aggregate_sha256: .aggregate.sha256,
            raw_sha256: .raw.sha256
          } ],
          manifest_sha256: $manifest_sha,
          records: $s.records,
          reason_codes: []
        }' >"$tmp_receipt" || { rm -f "$tmp_receipt"; fail "receipt render failed"; }
    mv -f "$tmp_receipt" "$receipt_out"
  fi

  rm -rf "$work"
  trap - EXIT HUP INT TERM
}

cmd_build() {
  cache=$1; plan=$2; manifest_out=$3; receipt_out=${4:-}
  validate_plan "$plan"
  cls=$(jq -r '.classification' "$plan")
  case "$cls" in
    fixture | primary) ;;
    secondary-audit) fail "refusing to build a secondary-audit plan as the primary corpus (no silent substitution)" ;;
    *) fail "unknown classification: $cls" ;;
  esac
  verify_cache "$cache" "$plan"
  build_manifest "$cache" "$plan" "$manifest_out" "$receipt_out"
}

cmd_secondary() {
  cache=$1; plan=$2; manifest_out=$3; receipt_out=${4:-}
  validate_plan "$plan"
  cls=$(jq -r '.classification' "$plan")
  [ "$cls" = "secondary-audit" ] || fail "secondary requires classification=secondary-audit, got: $cls"
  verify_cache "$cache" "$plan"
  build_manifest "$cache" "$plan" "$manifest_out" "$receipt_out"
}

# Guarded live canary. Real bytes from a warmed Chrome context, or UNKNOWN.
cmd_canary() {
  cache=$1; plan=$2; receipt_out=${3:-}
  validate_plan "$plan"
  open_unknown() {
    echo "EXTERNAL-EVIDENCE-OPEN: $1" >&2
    echo "UNKNOWN: no real Dataverse bytes were acquired; not a fixture PASS" >&2
    exit 3
  }
  [ "${POLYLANE_SOURCE_LIVE:-}" = "1" ] || open_unknown "live canary disabled (set POLYLANE_SOURCE_LIVE=1)"
  command -v node >/dev/null 2>&1 || open_unknown "node adapter runtime unavailable"
  adapter="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)/benchmarks/taste-live/tools/dataverse-acquire.mjs"
  [ -f "$adapter" ] || open_unknown "adapter not found: $adapter"
  file_id=${POLYLANE_SOURCE_CANARY_FILE:-}
  [ -n "$file_id" ] || open_unknown "no probe file id (set POLYLANE_SOURCE_CANARY_FILE)"
  pid=$(jq -r '.sources[0].dataset_pid' "$plan")
  out=$(node "$adapter" fetch --pid "$pid" --file "$file_id" --cache "$cache") || open_unknown "adapter fetch failed: $out"
  status=$(printf '%s' "$out" | jq -r '.status // "UNKNOWN"' 2>/dev/null || echo UNKNOWN)
  [ "$status" = "OK" ] || open_unknown "adapter returned non-OK: $out"
  if [ -n "$receipt_out" ]; then
    tool_fp=$(shasum -a 256 "$0" | awk '{print $1}')
    now=${TASTE_NOW:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}
    tmp=$(mktemp "${receipt_out}.tmp.XXXXXX") || fail "mktemp failed"
    printf '%s' "$out" | jq \
      --arg tool_fp "$tool_fp" --arg now "$now" --arg pid "$pid" '{
        schema_version: "taste-source-canary/v1",
        status: "LIVE",
        classification: "canary",
        tool: { id: "polylane-taste-source", fingerprint: $tool_fp },
        executed_at: $now,
        dataset_pid: $pid,
        file_id: .file_id,
        bytes: .bytes,
        sha256: .sha256
      }' >"$tmp" || { rm -f "$tmp"; fail "canary receipt render failed"; }
    mv -f "$tmp" "$receipt_out"
  fi
  printf '%s\n' "$out"
}

main() {
  require_tools
  [ "$#" -ge 1 ] || { usage >&2; exit 2; }
  sub=$1; shift
  case "$sub" in
    verify-cache) [ "$#" -eq 2 ] || { usage >&2; exit 2; }; verify_cache "$1" "$2" ;;
    build)        [ "$#" -ge 3 ] && [ "$#" -le 4 ] || { usage >&2; exit 2; }; cmd_build "$@" ;;
    secondary)    [ "$#" -ge 3 ] && [ "$#" -le 4 ] || { usage >&2; exit 2; }; cmd_secondary "$@" ;;
    canary)       [ "$#" -ge 2 ] && [ "$#" -le 3 ] || { usage >&2; exit 2; }; cmd_canary "$@" ;;
    *) usage >&2; exit 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
