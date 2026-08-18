#!/usr/bin/env bash
# Hermetic tests for deterministic 60/24-per-domain corpus selection (lane corpus-select).
# Covers determinism, exact quota, leakage, duplicates, filters, insufficient-domain
# unavailability, changed-seed divergence, and post-result replacement attacks.
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
TOOL="$ROOT/bin/polylane-taste-corpus-select.sh"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/corpus-select-test.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
ASSERTIONS=0
SEED="c41-frozen-seed-20260812"
DOMAINS="e-commerce universities commercial-banks"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { ASSERTIONS=$((ASSERTIONS + 1)); }

[ -f "$TOOL" ] || fail "missing $TOOL"
[ -x "$TOOL" ] || fail "$TOOL not executable"
pass

fake_sha() { printf '%s' "$1" | shasum -a 256 | awk '{print $1}'; }

# make_fixture DIR PER_DOMAIN — writes source.json + ratings.json with PER_DOMAIN
# eligible images per frozen domain (support 12, sd 0.6) plus, always, one
# low-support item and one high-ambiguity item per domain that must be filtered out.
make_fixture() {
  dir=$1 per=$2
  mkdir -p "$dir"
  {
    printf '{"format_version":1,"source_revision":"harvard-dvn-v4-test","images":['
    first=1
    for dom in $DOMAINS; do
      i=0
      while [ "$i" -lt "$per" ]; do
        [ "$first" -eq 1 ] || printf ','
        first=0
        printf '{"id":"%s-img-%03d","domain":"%s","sha256":"%s"}' \
          "$dom" "$i" "$dom" "$(fake_sha "$dir-$dom-$i")"
        i=$((i + 1))
      done
      printf ',{"id":"%s-lowsup","domain":"%s","sha256":"%s"}' "$dom" "$dom" "$(fake_sha "$dir-$dom-lowsup")"
      printf ',{"id":"%s-ambig","domain":"%s","sha256":"%s"}' "$dom" "$dom" "$(fake_sha "$dir-$dom-ambig")"
    done
    printf ']}'
  } > "$dir/source.json"
  {
    printf '{"format_version":1,"scale":{"min":1,"max":7},"ratings":['
    first=1
    for dom in $DOMAINS; do
      i=0
      while [ "$i" -lt "$per" ]; do
        [ "$first" -eq 1 ] || printf ','
        first=0
        printf '{"id":"%s-img-%03d","mean":4.1,"sd":0.6,"support":12}' "$dom" "$i"
        i=$((i + 1))
      done
      printf ',{"id":"%s-lowsup","mean":4.0,"sd":0.5,"support":4}' "$dom"
      printf ',{"id":"%s-ambig","mean":4.0,"sd":1.6,"support":12}' "$dom"
    done
    printf ']}'
  } > "$dir/ratings.json"
}

sha_file() { shasum -a 256 "$1" | awk '{print $1}'; }

expect_fail() { # marker message -- cmd...
  marker=$1 msg=$2; shift 2
  if out=$("$@" 2>&1); then
    fail "$msg: expected failure, got success"
  fi
  case "$out" in
    *"$marker"*) pass ;;
    *) fail "$msg: expected marker $marker, got: $out" ;;
  esac
}

# --- happy path: quota, determinism, filters ------------------------------
make_fixture "$WORK/fix" 90
run1="$WORK/run1"; run2="$WORK/run2"
"$TOOL" select "$WORK/fix/source.json" "$WORK/fix/ratings.json" "$SEED" "$run1" \
  || fail "select failed on valid fixture"
pass
MAN="$run1/corpus-select-manifest.json"
REC="$run1/corpus-select-receipt.json"
[ -f "$MAN" ] && [ -f "$REC" ] || fail "manifest and receipt must both exist"
pass

jq -e '.records | length == 252' "$MAN" >/dev/null || fail "manifest must hold exactly 252 records"
pass
jq -e '[.records[] | select(.split == "calibration")] | length == 180' "$MAN" >/dev/null \
  || fail "exactly 180 calibration records"
pass
jq -e '[.records[] | select(.split == "holdout")] | length == 72' "$MAN" >/dev/null \
  || fail "exactly 72 holdout records"
pass
for dom in $DOMAINS; do
  jq -e --arg d "$dom" \
    '([.records[] | select(.domain == $d and .split == "calibration")] | length == 60)
     and ([.records[] | select(.domain == $d and .split == "holdout")] | length == 24)' \
    "$MAN" >/dev/null || fail "domain $dom must have exactly 60+24"
  pass
done

# leakage: splits disjoint by id and by digest; digests unique overall
jq -e '
  ([.records[] | select(.split == "calibration") | .id]) as $ci
  | ([.records[] | select(.split == "holdout") | .id]) as $hi
  | ([.records[] | select(.split == "calibration") | .sha256]) as $cs
  | ([.records[] | select(.split == "holdout") | .sha256]) as $hs
  | (($ci - ($ci - $hi)) == []) and (($cs - ($cs - $hs)) == [])
  and ([.records[].id] | length == (unique | length))
  and ([.records[].sha256] | length == (unique | length))' "$MAN" >/dev/null \
  || fail "calibration/holdout must be disjoint by id and digest"
pass

# filters: low-support and high-ambiguity items never selected
jq -e '[.records[].id | select(test("lowsup|ambig"))] | length == 0' "$MAN" >/dev/null \
  || fail "support/ambiguity-filtered items must never be selected"
pass

# receipt bindings
jq -e --arg s "$SEED" --arg src "$(sha_file "$WORK/fix/source.json")" \
      --arg rat "$(sha_file "$WORK/fix/ratings.json")" --arg man "$(sha_file "$MAN")" '
  .seed == $s
  and .source_revision == "harvard-dvn-v4-test"
  and .source_manifest_sha256 == $src
  and .ratings_sha256 == $rat
  and .manifest_sha256 == $man
  and .filters.support_min == 5
  and .filters.ambiguity_max_sd == 1.5
  and (.domains | keys | length == 3)
  and all(.domains[]; .eligible == 90 and .calibration == 60 and .holdout == 24)' \
  "$REC" >/dev/null || fail "receipt must bind seed, revision, input digests, filters, counts, manifest digest"
pass

# determinism: identical bytes on re-run
"$TOOL" select "$WORK/fix/source.json" "$WORK/fix/ratings.json" "$SEED" "$run2" \
  || fail "second select failed"
cmp -s "$MAN" "$run2/corpus-select-manifest.json" || fail "manifest must be byte-identical across runs"
pass
cmp -s "$REC" "$run2/corpus-select-receipt.json" || fail "receipt must be byte-identical across runs"
pass

# changed seed → different selection
run3="$WORK/run3"
"$TOOL" select "$WORK/fix/source.json" "$WORK/fix/ratings.json" "other-seed-1" "$run3" \
  || fail "select with other seed failed"
cmp -s "$MAN" "$run3/corpus-select-manifest.json" && fail "changed seed must change the selection"
pass

# verify passes on untouched outputs
"$TOOL" verify "$WORK/fix/source.json" "$WORK/fix/ratings.json" "$SEED" "$run1" \
  || fail "verify must pass on untouched outputs"
pass

# --- replacement attacks --------------------------------------------------
attack="$WORK/attack"; mkdir -p "$attack"
cp "$MAN" "$attack/corpus-select-manifest.json"; cp "$REC" "$attack/corpus-select-receipt.json"
swap_id=$(jq -r '.records[0].id' "$attack/corpus-select-manifest.json")
jq --arg id "$swap_id" --arg sha "$(fake_sha "attacker-image")" \
  '(.records[] | select(.id == $id) | .sha256) = $sha' \
  "$attack/corpus-select-manifest.json" > "$attack/m.tmp" && mv "$attack/m.tmp" "$attack/corpus-select-manifest.json"
expect_fail "CORPUS-SELECT-REPLACED" "swapped digest in manifest must be rejected" \
  "$TOOL" verify "$WORK/fix/source.json" "$WORK/fix/ratings.json" "$SEED" "$attack"

cp "$MAN" "$attack/corpus-select-manifest.json"
jq '.domains["e-commerce"].eligible = 91' "$REC" > "$attack/corpus-select-receipt.json"
expect_fail "CORPUS-SELECT-REPLACED" "edited receipt must be rejected" \
  "$TOOL" verify "$WORK/fix/source.json" "$WORK/fix/ratings.json" "$SEED" "$attack"

cp "$REC" "$attack/corpus-select-receipt.json"
jq '.ratings[0].mean = 1.0' "$WORK/fix/ratings.json" > "$attack/ratings.json"
expect_fail "CORPUS-SELECT-REPLACED" "replaced ratings input must be rejected" \
  "$TOOL" verify "$WORK/fix/source.json" "$attack/ratings.json" "$SEED" "$attack"

# --- insufficient domain: unavailable, no rebalancing, no partial publish --
short="$WORK/short"; make_fixture "$short" 90
jq '.images |= map(select((.id | startswith("universities-img-0")) | not))' \
  "$short/source.json" > "$short/s.tmp" && mv "$short/s.tmp" "$short/source.json"
runU="$WORK/runU"
expect_fail "CORPUS-SELECT-UNAVAILABLE" "83-eligible domain must be unavailable" \
  "$TOOL" select "$short/source.json" "$short/ratings.json" "$SEED" "$runU"
out=$("$TOOL" select "$short/source.json" "$short/ratings.json" "$SEED" "$runU" 2>&1) && fail "unavailable rc"
case "$out" in *universities*) pass ;; *) fail "unavailable message must name the failing domain" ;; esac
[ ! -e "$runU/corpus-select-manifest.json" ] && [ ! -e "$runU/corpus-select-receipt.json" ] \
  || fail "no partial output may be published on quota failure"
pass

# --- invalid inputs -------------------------------------------------------
bad="$WORK/bad"; runB="$WORK/runB"

make_fixture "$bad" 90
jq '.images += [.images[0]]' "$bad/source.json" > "$bad/s.tmp" && mv "$bad/s.tmp" "$bad/source.json"
expect_fail "CORPUS-SELECT-INVALID" "duplicate image id must be rejected" \
  "$TOOL" select "$bad/source.json" "$bad/ratings.json" "$SEED" "$runB"

make_fixture "$bad" 90
jq '.images[1].sha256 = .images[0].sha256' "$bad/source.json" > "$bad/s.tmp" && mv "$bad/s.tmp" "$bad/source.json"
expect_fail "CORPUS-SELECT-INVALID" "duplicate digest within a domain must be rejected" \
  "$TOOL" select "$bad/source.json" "$bad/ratings.json" "$SEED" "$runB"

make_fixture "$bad" 90
jq '(.images | map(select(.domain == "universities"))[0].sha256) as $x
    | (.images | map(.domain == "e-commerce") | index(true)) as $i
    | .images[$i].sha256 = $x' "$bad/source.json" > "$bad/s.tmp" && mv "$bad/s.tmp" "$bad/source.json"
expect_fail "CORPUS-SELECT-INVALID" "cross-domain digest leakage must be rejected" \
  "$TOOL" select "$bad/source.json" "$bad/ratings.json" "$SEED" "$runB"

make_fixture "$bad" 90
jq '.ratings += [.ratings[0]]' "$bad/ratings.json" > "$bad/r.tmp" && mv "$bad/r.tmp" "$bad/ratings.json"
expect_fail "CORPUS-SELECT-INVALID" "duplicate rating id must be rejected" \
  "$TOOL" select "$bad/source.json" "$bad/ratings.json" "$SEED" "$runB"

make_fixture "$bad" 90
jq '.images[0].domain = "fashion"' "$bad/source.json" > "$bad/s.tmp" && mv "$bad/s.tmp" "$bad/source.json"
expect_fail "CORPUS-SELECT-INVALID" "domain outside the frozen set must be rejected" \
  "$TOOL" select "$bad/source.json" "$bad/ratings.json" "$SEED" "$runB"

make_fixture "$bad" 90
expect_fail "CORPUS-SELECT-INVALID" "malformed seed must be rejected" \
  "$TOOL" select "$bad/source.json" "$bad/ratings.json" 'bad seed!' "$runB"

printf 'not json' > "$bad/source.json"
expect_fail "CORPUS-SELECT-INVALID" "invalid JSON must be rejected" \
  "$TOOL" select "$bad/source.json" "$bad/ratings.json" "$SEED" "$runB"

echo "PASS: test-taste-corpus-select ($ASSERTIONS assertions)"
