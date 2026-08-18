#!/usr/bin/env bash
# Deterministic frozen-domain corpus selection for the taste calibration campaign.
# Selects exactly 60 calibration + 24 holdout images per frozen domain (180+72 total)
# from a frozen source manifest and normalized human ratings, bound to a seed.
# Quota failure is CORPUS-SELECT-UNAVAILABLE, never rebalancing. `verify` re-derives
# the outputs from the bound inputs and rejects any post-result replacement.
set -euo pipefail

CAL_PER_DOMAIN=60
HOLD_PER_DOMAIN=24
SUPPORT_MIN=5
AMBIGUITY_MAX_SD=1.5
FROZEN_DOMAINS='["e-commerce","universities","commercial-banks"]'

usage() {
  cat <<'USAGE'
usage:
  polylane-taste-corpus-select.sh select SOURCE_MANIFEST RATINGS SEED OUT_DIR
  polylane-taste-corpus-select.sh verify SOURCE_MANIFEST RATINGS SEED OUT_DIR
USAGE
}

invalid() { echo "CORPUS-SELECT-INVALID: $*" >&2; exit 1; }
unavailable() { echo "CORPUS-SELECT-UNAVAILABLE: $*" >&2; exit 2; }
replaced() { echo "CORPUS-SELECT-REPLACED: $*" >&2; exit 3; }

sha_file() { shasum -a 256 "$1" | awk '{print $1}'; }

no_duplicate_json_keys() {
  dup=$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("/")' "$1" 2>/dev/null \
    | LC_ALL=C sort | uniq -d)
  [ -z "$dup" ]
}

validate_inputs() {
  src=$1 rat=$2 seed=$3
  command -v jq >/dev/null 2>&1 || invalid "jq is required"
  command -v shasum >/dev/null 2>&1 || invalid "shasum is required"
  printf '%s' "$seed" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*$' || invalid "malformed seed"
  for f in "$src" "$rat"; do
    [ -f "$f" ] && [ ! -L "$f" ] || invalid "$f is not a regular file"
    jq -e . "$f" >/dev/null 2>&1 || invalid "$f is not valid JSON"
    no_duplicate_json_keys "$f" || invalid "$f has duplicate JSON keys"
  done

  jq -e --argjson domains "$FROZEN_DOMAINS" '
    type == "object"
    and ((keys - ["format_version", "images", "source_revision"]) == [])
    and .format_version == 1
    and (.source_revision | type == "string" and length > 0)
    and (.images | type == "array" and length > 0)
    and all(.images[];
      type == "object"
      and ((keys - ["domain", "id", "sha256"]) == [])
      and (.id | type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]*$"))
      and (.domain as $d | $domains | index($d) != null)
      and (.sha256 | type == "string" and test("^[0-9a-f]{64}$")))
    and ([.images[].id] | length == (unique | length))
    and ([.images[].sha256] | length == (unique | length))
  ' "$src" >/dev/null \
    || invalid "source manifest must be frozen-domain images with unique ids and digests"

  jq -e '
    .scale as $s
    | type == "object"
    and ((keys - ["format_version", "ratings", "scale"]) == [])
    and .format_version == 1
    and (.scale | type == "object" and ((keys - ["max", "min"]) == [])
      and (.min | type == "number") and (.max | type == "number") and .min < .max)
    and (.ratings | type == "array" and length > 0)
    and all(.ratings[];
      type == "object"
      and ((keys - ["id", "mean", "sd", "support"]) == [])
      and (.id | type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]*$"))
      and (.mean | type == "number" and . >= $s.min and . <= $s.max)
      and (.sd | type == "number" and . >= 0)
      and (.support | type == "number" and . == floor and . >= 0))
    and ([.ratings[].id] | length == (unique | length))
  ' "$rat" >/dev/null \
    || invalid "ratings must be native-scale entries with unique ids, sd, and support"
}

# derive SRC RAT SEED SCRATCH — writes SCRATCH/manifest.json + SCRATCH/receipt.json
derive() {
  src=$1 rat=$2 seed=$3 scratch=$4
  eligible="$scratch/eligible.json"

  jq -n --slurpfile s "$src" --slurpfile r "$rat" \
    --argjson smin "$SUPPORT_MIN" --argjson sdmax "$AMBIGUITY_MAX_SD" '
    ($r[0].ratings | map({key: .id, value: .}) | from_entries) as $by_id
    | [$s[0].images[]
       | . as $img
       | $by_id[$img.id]
       | select(. != null and .support >= $smin and .sd <= $sdmax)
       | $img]
  ' > "$eligible"

  need=$((CAL_PER_DOMAIN + HOLD_PER_DOMAIN))
  for dom in $(jq -rn --argjson d "$FROZEN_DOMAINS" '$d[]'); do
    n=$(jq --arg d "$dom" '[.[] | select(.domain == $d)] | length' "$eligible")
    [ "$n" -ge "$need" ] \
      || unavailable "domain $dom has only $n eligible items, quota needs $need"
  done

  jq -r '.[] | [.id, .domain, .sha256] | @tsv' "$eligible" \
    | while IFS=$'\t' read -r id dom sha; do
        h=$(printf '%s|%s|%s' "$seed" "$id" "$sha" | shasum -a 256 | awk '{print $1}')
        printf '%s\t%s\t%s\t%s\n' "$h" "$dom" "$id" "$sha"
      done | LC_ALL=C sort > "$scratch/ranked.tsv"

  awk -F'\t' -v cal="$CAL_PER_DOMAIN" -v hold="$HOLD_PER_DOMAIN" '
    { seen[$2]++
      if (seen[$2] <= cal) split_name = "calibration"
      else if (seen[$2] <= cal + hold) split_name = "holdout"
      else next
      print $2 "\t" $3 "\t" $4 "\t" split_name }
  ' "$scratch/ranked.tsv" > "$scratch/selected.tsv"

  rev=$(jq -r '.source_revision' "$src")
  jq -Rn --arg seed "$seed" --arg rev "$rev" '
    {format_version: 1,
     kind: "taste-corpus-select-manifest",
     seed: $seed,
     source_revision: $rev,
     records: ([inputs | split("\t") | {id: .[1], domain: .[0], sha256: .[2], split: .[3]}]
       | sort_by([.domain, .split, .id]))}
  ' < "$scratch/selected.tsv" > "$scratch/manifest.json"

  jq -n --arg seed "$seed" --arg rev "$rev" \
    --arg src_sha "$(sha_file "$src")" --arg rat_sha "$(sha_file "$rat")" \
    --arg man_sha "$(sha_file "$scratch/manifest.json")" \
    --argjson smin "$SUPPORT_MIN" --argjson sdmax "$AMBIGUITY_MAX_SD" \
    --argjson cal "$CAL_PER_DOMAIN" --argjson hold "$HOLD_PER_DOMAIN" \
    --argjson domains "$FROZEN_DOMAINS" --slurpfile el "$eligible" '
    {format_version: 1,
     kind: "taste-corpus-select-receipt",
     seed: $seed,
     source_revision: $rev,
     source_manifest_sha256: $src_sha,
     ratings_sha256: $rat_sha,
     filters: {support_min: $smin, ambiguity_max_sd: $sdmax},
     domains: ($domains | map(. as $d |
       {key: $d,
        value: {eligible: ([$el[0][] | select(.domain == $d)] | length),
                calibration: $cal, holdout: $hold}}) | from_entries),
     manifest_sha256: $man_sha}
  ' > "$scratch/receipt.json"
}

cmd_select() {
  src=$1 rat=$2 seed=$3 out=$4
  validate_inputs "$src" "$rat" "$seed"
  scratch=$(mktemp -d "${TMPDIR:-/tmp}/corpus-select.XXXXXX")
  trap 'rm -rf "$scratch"' EXIT
  derive "$src" "$rat" "$seed" "$scratch"
  mkdir -p "$out"
  mv "$scratch/manifest.json" "$out/corpus-select-manifest.json"
  mv "$scratch/receipt.json" "$out/corpus-select-receipt.json"
  echo "CORPUS-SELECT-OK: 180+72 records written to $out"
}

cmd_verify() {
  src=$1 rat=$2 seed=$3 out=$4
  validate_inputs "$src" "$rat" "$seed"
  man="$out/corpus-select-manifest.json"
  rec="$out/corpus-select-receipt.json"
  for f in "$man" "$rec"; do
    [ -f "$f" ] && [ ! -L "$f" ] || replaced "published $f is missing or not a regular file"
  done
  scratch=$(mktemp -d "${TMPDIR:-/tmp}/corpus-select.XXXXXX")
  trap 'rm -rf "$scratch"' EXIT
  derive "$src" "$rat" "$seed" "$scratch"
  cmp -s "$scratch/manifest.json" "$man" \
    || replaced "published manifest differs from deterministic re-derivation"
  cmp -s "$scratch/receipt.json" "$rec" \
    || replaced "published receipt differs from deterministic re-derivation"
  jq -e --argjson cal "$CAL_PER_DOMAIN" --argjson hold "$HOLD_PER_DOMAIN" \
    --argjson domains "$FROZEN_DOMAINS" '
    . as $m
    | ([.records[].id] | length == (unique | length))
    and ([.records[].sha256] | length == (unique | length))
    and all($domains[]; . as $d
      | ([$m.records[] | select(.domain == $d and .split == "calibration")] | length == $cal)
      and ([$m.records[] | select(.domain == $d and .split == "holdout")] | length == $hold))
    and ((.records | length) == (($domains | length) * ($cal + $hold)))
  ' "$man" >/dev/null \
    || replaced "published manifest violates quota or split disjointness"
  echo "CORPUS-SELECT-VERIFIED: $out matches its bound inputs"
}

[ $# -eq 5 ] || { usage >&2; invalid "expected: command SOURCE_MANIFEST RATINGS SEED OUT_DIR"; }
cmd=$1; shift
case "$cmd" in
  select) cmd_select "$@" ;;
  verify) cmd_verify "$@" ;;
  *) usage >&2; invalid "unknown command $cmd" ;;
esac
