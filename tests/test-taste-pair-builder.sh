#!/usr/bin/env bash
# tests/test-taste-pair-builder.sh — deterministic held-out mirrored pair builder.
#
# Covers the frozen c41 pair contract: ambiguity floors (delta >= 1.00 and a
# 95% bootstrap interval excluding zero), stimulus leakage, source-image reuse,
# cross-domain pairing, side balance, sealed answer/side separation, byte-level
# determinism, and the 24-pair / 12-side-probe / 8-mirror-probe quotas.
set -u

source "$(dirname "$0")/helpers.sh"
PAIRS_BIN="$TESTS_DIR/../bin/polylane-taste-pairs.sh"

export TASTE_NOW="2026-08-12T00:00:00Z"
CORPUS_RECEIPT="1111111111111111111111111111111111111111111111111111111111111111"

# asset_sha TAG — unique deterministic 64-hex asset digest for a fixture item.
asset_sha() { printf 'asset|%s' "$1" | shasum -a 256 | awk '{print $1}'; }

# emit_item OUT_JSONL ID DOMAIN RATINGS_JSON
emit_item() {
  jq -nc --arg id "$2" --arg domain "$3" --arg asset "$(asset_sha "$2")" \
    --argjson ratings "$4" \
    '{id:$id, domain:$domain, asset_sha256:$asset, ratings:$ratings}' >> "$1"
}

HIGH_RATINGS='[5,4,5,4,5,4,5,5]'
LOW_RATINGS='[2,1,2,1,2,2,1,2]'

# mk_input OUT — full valid held-out selection: 3 domains x (8 high + 8 low).
mk_input() {
  local out="$1" items="$1.items.jsonl" d i
  : > "$items"
  for d in dom-shop dom-univ dom-bank; do
    for i in 1 2 3 4 5 6 7 8; do
      emit_item "$items" "img-$d-h$i" "$d" "$HIGH_RATINGS"
      emit_item "$items" "img-$d-l$i" "$d" "$LOW_RATINGS"
    done
  done
  jq -s --arg receipt "$CORPUS_RECEIPT" \
    '{schema_version:"taste-pair-input/v1", run_id:"c41-test",
      corpus_receipt_sha256:$receipt, partition:"held_out",
      scale:{min:1,max:7}, items:.}' "$items" > "$out"
  rm -f "$items"
}

# mk_small_input OUT ITEMS_JSONL — wrap arbitrary items into a valid envelope.
mk_wrap() {
  jq -s --arg receipt "$CORPUS_RECEIPT" \
    '{schema_version:"taste-pair-input/v1", run_id:"c41-test",
      corpus_receipt_sha256:$receipt, partition:"held_out",
      scale:{min:1,max:7}, items:.}' "$2" > "$1"
}

make_tmpdir; T="$TEST_TMPDIR"

# --- ambiguity: delta below 1.00 is never an eligible pair ------------------
: > "$T/small.jsonl"
emit_item "$T/small.jsonl" img-a dom-x '[4,4,4,4,4,4,4,4]'
emit_item "$T/small.jsonl" img-b dom-x '[4,3,4,3,4,3,4,3]'
mk_wrap "$T/ambig-delta.json" "$T/small.jsonl"
out=$(bash "$PAIRS_BIN" build "$T/ambig-delta.json" seed-1 "$T/out-ambig-delta" 2>&1) && rc=0 || rc=$?
assert_eq ambiguity-delta-floor-fails-closed 1 "$([ "$rc" -ne 0 ] && echo 1 || echo 0)"
assert_contains ambiguity-delta-floor-reason "quota" "$out"
assert_eq ambiguity-delta-floor-no-partial-output 0 "$([ -e "$T/out-ambig-delta" ] && echo 1 || echo 0)"

# --- ambiguity: delta >= 1.00 but bootstrap interval includes zero ----------
: > "$T/noisy.jsonl"
emit_item "$T/noisy.jsonl" img-na dom-x '[7,1,7,1,7,1,7,7]'
emit_item "$T/noisy.jsonl" img-nb dom-x '[1,7,1,7,1,7,1,1]'
mk_wrap "$T/ambig-ci.json" "$T/noisy.jsonl"
assert_fail ambiguity-bootstrap-zero-fails-closed bash "$PAIRS_BIN" build "$T/ambig-ci.json" seed-1 "$T/out-ambig-ci"

# --- cross-domain: unambiguous items in different domains never pair --------
: > "$T/cross.jsonl"
emit_item "$T/cross.jsonl" img-xa dom-x "$HIGH_RATINGS"
emit_item "$T/cross.jsonl" img-yb dom-y "$LOW_RATINGS"
mk_wrap "$T/cross.json" "$T/cross.jsonl"
out=$(bash "$PAIRS_BIN" build "$T/cross.json" seed-1 "$T/out-cross" 2>&1) && rc=0 || rc=$?
assert_eq cross-domain-never-paired 1 "$([ "$rc" -ne 0 ] && echo 1 || echo 0)"
assert_contains cross-domain-reason "quota" "$out"

# --- leakage: provider identity in stimulus-visible text fails closed -------
: > "$T/leak.jsonl"
for d in claude-shop dom-u2 dom-b2; do
  for i in 1 2 3 4 5 6 7 8; do
    emit_item "$T/leak.jsonl" "img-$d-h$i" "$d" "$HIGH_RATINGS"
    emit_item "$T/leak.jsonl" "img-$d-l$i" "$d" "$LOW_RATINGS"
  done
done
mk_wrap "$T/leak.json" "$T/leak.jsonl"
out=$(bash "$PAIRS_BIN" build "$T/leak.json" seed-1 "$T/out-leak" 2>&1) && rc=0 || rc=$?
assert_eq leakage-provider-identity-fails-closed 1 "$([ "$rc" -ne 0 ] && echo 1 || echo 0)"
assert_contains leakage-provider-identity-reason "identity" "$out"
assert_eq leakage-no-partial-output 0 "$([ -e "$T/out-leak" ] && echo 1 || echo 0)"

# --- input validation: fail-closed schema floor ------------------------------
mk_input "$T/good.json"
jq '.items[1].asset_sha256 = .items[0].asset_sha256' "$T/good.json" > "$T/dup-asset.json"
assert_fail input-duplicate-asset-rejected bash "$PAIRS_BIN" build "$T/dup-asset.json" seed-1 "$T/out-dup"
jq '.items[1].id = .items[0].id' "$T/good.json" > "$T/dup-id.json"
assert_fail input-duplicate-id-rejected bash "$PAIRS_BIN" build "$T/dup-id.json" seed-1 "$T/out-dup2"
jq '.partition = "calibration"' "$T/good.json" > "$T/bad-part.json"
assert_fail input-non-heldout-partition-rejected bash "$PAIRS_BIN" build "$T/bad-part.json" seed-1 "$T/out-part"
jq '.items[0].ratings = [9,9,9,9,9,9,9,9]' "$T/good.json" > "$T/bad-scale.json"
assert_fail input-out-of-scale-rating-rejected bash "$PAIRS_BIN" build "$T/bad-scale.json" seed-1 "$T/out-scale"
jq '.items[0].ratings = [5,4,5,4]' "$T/good.json" > "$T/few-raters.json"
assert_fail input-under-five-raters-rejected bash "$PAIRS_BIN" build "$T/few-raters.json" seed-1 "$T/out-raters"
jq 'del(.corpus_receipt_sha256)' "$T/good.json" > "$T/no-receipt.json"
assert_fail input-missing-corpus-binding-rejected bash "$PAIRS_BIN" build "$T/no-receipt.json" seed-1 "$T/out-nr"

# --- happy path: one full deterministic build --------------------------------
assert_ok build-succeeds-on-valid-heldout-input \
  bash "$PAIRS_BIN" build "$T/good.json" seed-1 "$T/out"
M="$T/out/pair-manifest.json"
S="$T/out/side-assignment.sealed.json"
A="$T/out/answer-key.sealed.json"
R="$T/out/pair-receipt.json"
for f in "$M" "$S" "$A" "$R"; do
  [ -f "$f" ] || fail "artifact-exists-$(basename "$f")" "missing $f"
done
assert_eq quota-exactly-24-mirrored-pairs 24 "$(jq '.pairs | length' "$M")"
assert_eq quota-side-probes-at-least-12 1 \
  "$(jq '.counts.side_probe_n >= 12 | if . then 1 else 0 end' "$R")"
assert_eq quota-mirror-probes-at-least-8 1 \
  "$(jq '.counts.mirror_probe_n >= 8 | if . then 1 else 0 end' "$R")"

# pair reuse: every source image appears in at most one pair
assert_eq pair-reuse-48-unique-stimuli 48 \
  "$(jq '[.pairs[].primary.left, .pairs[].primary.right] | unique | length' "$M")"
assert_eq pair-reuse-48-unique-assets 48 \
  "$(jq '[.bindings[].asset_sha256] | unique | length' "$S")"
assert_eq pair-reuse-48-unique-items 48 \
  "$(jq '[.bindings[].item_id] | unique | length' "$S")"

# same-domain: both sides of every pair share one domain
assert_eq same-domain-every-pair 24 "$(jq '[.pairs[] | select(.domain | type == "string")] | length' "$M")"
assert_eq same-domain-bindings-agree 1 "$(
  jq -s '
    .[0] as $m | .[1] as $s |
    ($s.bindings | map({key:.stimulus_id, value:.domain}) | from_entries) as $dom |
    [$m.pairs[] | select($dom[.primary.left] == .domain and $dom[.primary.right] == .domain)]
    | if length == 24 then 1 else 0 end' "$M" "$S")"

# mirror probes: mirror presentation is the exact flip of primary
assert_eq mirror-exact-flip-all-24 24 \
  "$(jq '[.pairs[] | select(.mirror.left == .primary.right and .mirror.right == .primary.left)] | length' "$M")"

# side balance: gold stimulus sits left in exactly 12 of 24 primaries
assert_eq side-balance-12-left-12-right 12 "$(
  jq -s '
    .[0] as $m | .[1] as $a |
    ($a.pairs | map({key:.pair_id, value:.gold_stimulus_id}) | from_entries) as $gold |
    [$m.pairs[] | select($gold[.pair_id] == .primary.left)] | length' "$M" "$A")"

# ambiguity floors recorded in the sealed answer key
assert_eq answer-delta-floor-all-pairs 24 \
  "$(jq '[.pairs[] | select(.delta >= 1.0)] | length' "$A")"
assert_eq answer-bootstrap-excludes-zero-all-pairs 24 \
  "$(jq '[.pairs[] | select(.bootstrap.ci_low > 0)] | length' "$A")"
assert_eq answer-bootstrap-n-frozen 24 \
  "$(jq '[.pairs[] | select(.bootstrap.n == 1000)] | length' "$A")"

# answer exposure: the judge-visible manifest carries no answers or identities
assert_eq answer-exposure-no-forbidden-keys 0 "$(
  jq '[paths | .[] | select(type == "string")
       | select(IN("gold_stimulus_id","gold","delta","ratings","mean","human_rating","item_id","answer"))] | length' "$M")"
leaked=0
while IFS= read -r item_id; do
  grep -qF -- "$item_id" "$M" && leaked=1
done < <(jq -r '.items[].id' "$T/good.json")
assert_eq answer-exposure-no-item-ids-in-stimuli 0 "$leaked"
assert_eq answer-exposure-sealed-files-distinct 3 \
  "$(shasum -a 256 "$M" "$S" "$A" | awk '{print $1}' | sort -u | wc -l | tr -d ' ')"

# receipt binds every artifact by content hash
for k in pair_manifest side_assignment answer_key; do
  case "$k" in
    pair_manifest) f="$M" ;;
    side_assignment) f="$S" ;;
    answer_key) f="$A" ;;
  esac
  assert_eq "receipt-binds-$k" "$(shasum -a 256 "$f" | awk '{print $1}')" \
    "$(jq -r ".outputs.${k}_sha256" "$R")"
done
assert_eq receipt-binds-input \
  "$(shasum -a 256 "$T/good.json" | awk '{print $1}')" "$(jq -r '.input_sha256' "$R")"
assert_eq receipt-binds-corpus "$CORPUS_RECEIPT" "$(jq -r '.inputs.corpus_receipt_sha256' "$R")"
assert_eq receipt-frozen-thresholds 1 "$(
  jq '.thresholds
      | if .pair_quota == 24 and .delta_min == 1.0 and .bootstrap_n == 1000
           and .side_probe_min == 12 and .mirror_probe_min == 8
        then 1 else 0 end' "$R")"
assert_eq receipt-not-human-certified 0 \
  "$(jq '[paths(. == true) | .[-1] | select(. == "human_certified")] | length' "$R")"

# --- determinism: same seed byte-identical, different seed diverges ---------
assert_ok determinism-rebuild-same-seed bash "$PAIRS_BIN" build "$T/good.json" seed-1 "$T/out-again"
same=1
for f in pair-manifest.json side-assignment.sealed.json answer-key.sealed.json pair-receipt.json; do
  cmp -s "$T/out/$f" "$T/out-again/$f" || same=0
done
assert_eq determinism-same-seed-byte-identical 1 "$same"
assert_ok determinism-build-other-seed bash "$PAIRS_BIN" build "$T/good.json" seed-2 "$T/out-seed2"
assert_eq determinism-different-seed-diverges 0 \
  "$(cmp -s "$T/out/pair-manifest.json" "$T/out-seed2/pair-manifest.json" && echo 1 || echo 0)"

# --- verify: structural re-check passes, tamper fails ------------------------
assert_ok verify-passes-on-fresh-bundle bash "$PAIRS_BIN" verify "$T/out"
cp -R "$T/out" "$T/tampered"
jq '.pairs[0].mirror.left = .pairs[0].primary.left' "$T/tampered/pair-manifest.json" > "$T/tampered/x" \
  && mv "$T/tampered/x" "$T/tampered/pair-manifest.json"
assert_fail verify-fails-on-tampered-manifest bash "$PAIRS_BIN" verify "$T/tampered"
cp -R "$T/out" "$T/tampered2"
jq '.pairs[0].delta = 0.5' "$T/tampered2/answer-key.sealed.json" > "$T/tampered2/x" \
  && mv "$T/tampered2/x" "$T/tampered2/answer-key.sealed.json"
assert_fail verify-fails-on-weakened-answer-key bash "$PAIRS_BIN" verify "$T/tampered2"

finish
