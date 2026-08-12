#!/usr/bin/env bash
# Focused test for the source-live lane: browser-backed Dataverse acquisition,
# raw/aggregate/image join, content-addressed cache verification, deterministic
# split, receipt binding, guarded live canary, and fail-closed rejections.
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
SRC="$ROOT/bin/polylane-taste-source.sh"
CORPUS="$ROOT/bin/polylane-taste-corpus.sh"
ADAPTER="$ROOT/benchmarks/taste-live/tools/dataverse-acquire.mjs"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/polylane-taste-source.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
ASSERTIONS=0

assert_ok() { "$@" >/dev/null; ASSERTIONS=$((ASSERTIONS + 1)); }
assert_fail() {
  if "$@" >/dev/null 2>&1; then echo "expected failure: $*" >&2; exit 1; fi
  ASSERTIONS=$((ASSERTIONS + 1))
}
expect_eq() {
  if [ "$1" = "$2" ]; then ASSERTIONS=$((ASSERTIONS + 1));
  else echo "FAIL ${3:-assertion}: expected [$1] got [$2]" >&2; exit 1; fi
}

CACHE="$TMP/cache"
mkdir -p "$CACHE/objects"

# Store bytes content-addressed; echo the sha256.
mk_obj() {
  printf '%s' "$1" >"$TMP/blob"
  s=$(shasum -a 256 "$TMP/blob" | awk '{print $1}')
  d="$CACHE/objects/${s:0:2}"; mkdir -p "$d"; cp "$TMP/blob" "$d/$s"
  printf '%s' "$s"
}

SRC_ID="miniukovich-9fksqi"
PID="doi:10.7910/DVN/9FKSQI"
VER="2.0"
DS_URL="https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/9FKSQI"
LIC_URL="https://creativecommons.org/publicdomain/zero/1.0/legalcode"
LIC_SHA=$(printf 'CC0-1.0 legalcode' | shasum -a 256 | awk '{print $1}')

# --- aggregate + raw acquired assets (normalized JSON, as the adapter emits) ---
AGG_JSON='{
  "cons-1":{"domain":"consumer","mean_rating":4.0},
  "cons-2":{"domain":"consumer","mean_rating":3.0},
  "cons-3":{"domain":"consumer","mean_rating":5.0},
  "cons-4":{"domain":"consumer","mean_rating":2.0},
  "coll-1":{"domain":"collaboration","mean_rating":4.0},
  "coll-2":{"domain":"collaboration","mean_rating":2.0},
  "coll-3":{"domain":"collaboration","mean_rating":3.0},
  "coll-4":{"domain":"collaboration","mean_rating":5.0},
  "ops-1":{"domain":"operations","mean_rating":4.0},
  "ops-2":{"domain":"operations","mean_rating":5.0},
  "ops-3":{"domain":"operations","mean_rating":3.0},
  "ops-4":{"domain":"operations","mean_rating":2.0}
}'
RAW_JSON='{
  "cons-1":[4,4,4,4,4],"cons-2":[3,3,3,3,3],"cons-3":[5,5,5,5,5],"cons-4":[2,2,2,2,2],
  "coll-1":[4,4,4,4,4],"coll-2":[2,2,2,2,2],"coll-3":[3,3,3,3,3],"coll-4":[5,5,5,5,5],
  "ops-1":[4,4,4,4,4],"ops-2":[5,5,5,5,5],"ops-3":[3,3,3,3,3],"ops-4":[2,2,2,2,2]
}'
AGG_SHA=$(mk_obj "$AGG_JSON")
RAW_SHA=$(mk_obj "$RAW_JSON")
META_SHA=$(mk_obj "{\"pid\":\"$PID\",\"version\":\"$VER\"}")

# --- 12 distinct images, one per stimulus ---
: >"$TMP/images.tsv"
for stim in cons-1 cons-2 cons-3 cons-4 coll-1 coll-2 coll-3 coll-4 ops-1 ops-2 ops-3 ops-4; do
  isha=$(mk_obj "image-bytes-$stim")
  printf '%s\t%s\n' "$stim" "$isha" >>"$TMP/images.tsv"
done
IMAGES=$(jq -Rn --arg src "$SRC_ID" '[inputs|split("\t")|{stimulus_id:.[0],source_id:$src,sha256:.[1]}]' "$TMP/images.tsv")

write_plan() { # out classification
  jq -n \
    --arg cls "$2" --arg src "$SRC_ID" --arg pid "$PID" --arg ver "$VER" \
    --arg dsurl "$DS_URL" --arg licurl "$LIC_URL" --arg licsha "$LIC_SHA" \
    --arg meta "$META_SHA" --arg agg "$AGG_SHA" --arg raw "$RAW_SHA" \
    --argjson images "$IMAGES" '
    {
      plan_version:"taste-source-plan/v1",
      classification:$cls,
      reproduction:"bin/polylane-taste-source.sh build <cache> <plan> <manifest>",
      split:{seed:"c40-seed", calibration_per_domain:2, holdout_per_domain:2},
      domains:["consumer","collaboration","operations"],
      sources:[{
        id:$src, dataset_pid:$pid, dataset_version:$ver, url:$dsurl,
        license:{spdx:"CC0-1.0", url:$licurl, sha256:$licsha},
        metadata:{sha256:$meta}, aggregate:{sha256:$agg}, raw:{sha256:$raw}
      }],
      images:$images
    }' >"$1"
}

PLAN="$TMP/plan.json"
write_plan "$PLAN" fixture

# --- happy path: build a manifest + receipt ---------------------------------
MANIFEST="$TMP/manifest.json"
RECEIPT="$TMP/receipt.json"
assert_ok "$SRC" verify-cache "$CACHE" "$PLAN"
assert_ok "$SRC" build "$CACHE" "$PLAN" "$MANIFEST" "$RECEIPT"

expect_eq 1 "$(jq -r '.format_version' "$MANIFEST")" format-version
expect_eq 12 "$(jq -r '.records|length' "$MANIFEST")" record-count
expect_eq 3 "$(jq -r '[.records[].domain]|unique|length' "$MANIFEST")" domain-count
expect_eq 2 "$(jq -r '[.records[]|select(.domain=="consumer" and .split=="calibration")]|length' "$MANIFEST")" consumer-cal
expect_eq 2 "$(jq -r '[.records[]|select(.domain=="consumer" and .split=="holdout")]|length' "$MANIFEST")" consumer-hold

# The manifest must satisfy the frozen hermetic corpus validator (schema reuse).
assert_ok "$CORPUS" validate "$MANIFEST"

# Receipt binds source, licence, checksums, split seed, raw support, reproduction.
expect_eq taste-source-acquisition/v1 "$(jq -r '.schema_version' "$RECEIPT")" receipt-schema
expect_eq fixture "$(jq -r '.classification' "$RECEIPT")" receipt-classification
expect_eq "$PID" "$(jq -r '.sources[0].dataset_pid' "$RECEIPT")" receipt-pid
expect_eq "$VER" "$(jq -r '.sources[0].dataset_version' "$RECEIPT")" receipt-version
expect_eq CC0-1.0 "$(jq -r '.sources[0].spdx' "$RECEIPT")" receipt-spdx
expect_eq "$META_SHA" "$(jq -r '.sources[0].metadata_sha256' "$RECEIPT")" receipt-meta
expect_eq "$AGG_SHA" "$(jq -r '.sources[0].aggregate_sha256' "$RECEIPT")" receipt-agg
expect_eq "$RAW_SHA" "$(jq -r '.sources[0].raw_sha256' "$RECEIPT")" receipt-raw
expect_eq "c40-seed" "$(jq -r '.split.seed' "$RECEIPT")" receipt-seed
[ "$(jq -r '.raw_support.min' "$RECEIPT")" -ge 5 ] && ASSERTIONS=$((ASSERTIONS + 1)) || { echo "FAIL raw-support-min" >&2; exit 1; }
[ -n "$(jq -r '.reproduction' "$RECEIPT")" ] && ASSERTIONS=$((ASSERTIONS + 1)) || { echo "FAIL reproduction" >&2; exit 1; }
MSHA=$(shasum -a 256 "$MANIFEST" | awk '{print $1}')
expect_eq "$MSHA" "$(jq -r '.manifest_sha256' "$RECEIPT")" receipt-manifest-sha

# --- determinism: identical split for identical (plan, cache, seed) ---------
MANIFEST2="$TMP/manifest2.json"
"$SRC" build "$CACHE" "$PLAN" "$MANIFEST2" >/dev/null
expect_eq "$(jq -cS . "$MANIFEST")" "$(jq -cS . "$MANIFEST2")" deterministic-build

# --- rejections -------------------------------------------------------------
# missing image mapping
jq 'del(.images[0])' "$PLAN" >"$TMP/p_missing.json"
assert_fail "$SRC" build "$CACHE" "$TMP/p_missing.json" "$TMP/o.json"

# duplicate image sha across two stimuli
jq '.images[1].sha256 = .images[0].sha256' "$PLAN" >"$TMP/p_dup.json"
assert_fail "$SRC" build "$CACHE" "$TMP/p_dup.json" "$TMP/o.json"

# aggregate/raw disagreement (raw mean far from aggregate)
BADRAW=$(printf '%s' "$RAW_JSON" | jq '."cons-1"=[1,1,1,1,1]')
BADRAW_SHA=$(mk_obj "$BADRAW")
jq --arg s "$BADRAW_SHA" '.sources[0].raw.sha256=$s' "$PLAN" >"$TMP/p_disagree.json"
assert_fail "$SRC" build "$CACHE" "$TMP/p_disagree.json" "$TMP/o.json"

# fewer than five valid raw ratings
FEWRAW=$(printf '%s' "$RAW_JSON" | jq '."cons-1"=[4,4,4,4]')
FEWRAW_SHA=$(mk_obj "$FEWRAW")
jq --arg s "$FEWRAW_SHA" '.sources[0].raw.sha256=$s' "$PLAN" >"$TMP/p_few.json"
assert_fail "$SRC" build "$CACHE" "$TMP/p_few.json" "$TMP/o.json"

# changed source metadata: tamper the cached object so it no longer matches its pin
META_PATH="$CACHE/objects/${META_SHA:0:2}/$META_SHA"
cp "$META_PATH" "$TMP/meta.bak"
printf 'tampered' >"$META_PATH"
assert_fail "$SRC" build "$CACHE" "$PLAN" "$TMP/o.json"
assert_fail "$SRC" verify-cache "$CACHE" "$PLAN"
cp "$TMP/meta.bak" "$META_PATH"   # restore

# partial cache: truncate an image object to empty
FIRST_IMG=$(jq -r '.images[0].sha256' "$PLAN")
IMG_PATH="$CACHE/objects/${FIRST_IMG:0:2}/$FIRST_IMG"
cp "$IMG_PATH" "$TMP/img.bak"
: >"$IMG_PATH"
assert_fail "$SRC" build "$CACHE" "$PLAN" "$TMP/o.json"
cp "$TMP/img.bak" "$IMG_PATH"     # restore

# path escape / non-hex sha
jq '.images[0].sha256="../../../etc/passwd"' "$PLAN" >"$TMP/p_escape.json"
assert_fail "$SRC" build "$CACHE" "$TMP/p_escape.json" "$TMP/o.json"

# symlink cache object (content matches, but the object is a symlink)
SECOND_IMG=$(jq -r '.images[1].sha256' "$PLAN")
SYM_PATH="$CACHE/objects/${SECOND_IMG:0:2}/$SECOND_IMG"
cp "$SYM_PATH" "$TMP/real_target"
rm "$SYM_PATH"
ln -s "$TMP/real_target" "$SYM_PATH"
assert_fail "$SRC" build "$CACHE" "$PLAN" "$TMP/o.json"
rm "$SYM_PATH"; cp "$TMP/real_target" "$SYM_PATH"   # restore real object

# wrong domain quotas: consumer has only 3 stimuli (< 4 required)
SHORT_AGG=$(printf '%s' "$AGG_JSON" | jq 'del(."cons-4")')
SHORT_AGG_SHA=$(mk_obj "$SHORT_AGG")
jq --arg s "$SHORT_AGG_SHA" '.sources[0].aggregate.sha256=$s | del(.images[3])' "$PLAN" >"$TMP/p_quota.json"
assert_fail "$SRC" build "$CACHE" "$TMP/p_quota.json" "$TMP/o.json"

# caller-authored eligibility (boolean / eligible key in plan)
jq '.sources[0].eligible=true' "$PLAN" >"$TMP/p_elig.json"
assert_fail "$SRC" build "$CACHE" "$TMP/p_elig.json" "$TMP/o.json"

# --- no silent dataset substitution -----------------------------------------
write_plan "$TMP/p_secondary.json" secondary-audit
assert_fail "$SRC" build "$CACHE" "$TMP/p_secondary.json" "$TMP/o.json"   # primary refuses secondary plan
assert_fail "$SRC" secondary "$CACHE" "$PLAN" "$TMP/o.json"               # secondary refuses fixture plan
SEC_MANIFEST="$TMP/sec_manifest.json"
SEC_RECEIPT="$TMP/sec_receipt.json"
assert_ok "$SRC" secondary "$CACHE" "$TMP/p_secondary.json" "$SEC_MANIFEST" "$SEC_RECEIPT"
expect_eq secondary-audit "$(jq -r '.classification' "$SEC_RECEIPT")" secondary-classification

# --- guarded live canary: no fixture PASS without real bytes ----------------
CANARY_OUT="$TMP/canary.json"
rm -f "$CANARY_OUT"
if env -u POLYLANE_SOURCE_LIVE "$SRC" canary "$CACHE" "$PLAN" "$CANARY_OUT" >"$TMP/canary.log" 2>&1; then
  echo "FAIL: canary must not PASS without the live guard" >&2; exit 1
fi
ASSERTIONS=$((ASSERTIONS + 1))
grep -q 'EXTERNAL-EVIDENCE-OPEN' "$TMP/canary.log" || { echo "FAIL: canary must report EXTERNAL-EVIDENCE-OPEN" >&2; exit 1; }
ASSERTIONS=$((ASSERTIONS + 1))
[ ! -e "$CANARY_OUT" ] || { echo "FAIL: canary wrote a receipt without real bytes" >&2; exit 1; }
ASSERTIONS=$((ASSERTIONS + 1))

# --- external adapter hermetic selftest -------------------------------------
SELFTEST=$(node "$ADAPTER" --selftest)
case "$SELFTEST" in SELFTEST-OK*) ASSERTIONS=$((ASSERTIONS + 1)) ;; *) echo "FAIL adapter selftest: $SELFTEST" >&2; exit 1 ;; esac

echo "PASS test-taste-source-live assertions=$ASSERTIONS"
