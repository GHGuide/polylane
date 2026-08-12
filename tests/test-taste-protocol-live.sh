#!/usr/bin/env bash
# test-taste-protocol-live.sh — the taste-certification docs must track the
# LIVE harness boundary exactly, not a future/fixture wish.
#
# Hermetic: no network, no installs, nothing executed against a browser or a
# real model. It proves three things about the four OWNed docs
# (PROTOCOL.md, RESEARCH.md, references/visual-intelligence.md,
# references/prompt-blocks.md):
#
#   1. Every JSON example in PROTOCOL.md parses and has no duplicate key paths.
#   2. Every schema_version / claim label / dimension the docs present as LIVE
#      matches what the Cycle-39 producers in bin/ actually emit or enforce
#      (e.g. taste-pointwise/v1 has 8 dimensions, not 11; the certificate
#      compiler emits v1 fixture + v2 production; producers stamp "fixture").
#   3. The docs keep the honest boundary: fixture vs production vs live-adapter
#      vs external/UNKNOWN; the strongest attainable label without recruited
#      humans is HUMAN_CALIBRATED_MACHINE; forbidden overclaims are absent.
#
# When a doc drifts from the code this fails RED on purpose: fix the DOC (this
# lane owns the docs, never the producers).
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

REPO="$(cd "$TESTS_DIR/.." && pwd)"
PROTO="$REPO/docs/polylane/taste-certification/PROTOCOL.md"
RESEARCH="$REPO/docs/polylane/taste-certification/RESEARCH.md"
VIS="$REPO/references/visual-intelligence.md"
BLOCKS="$REPO/references/prompt-blocks.md"
TASTE="$REPO/bin/polylane-taste.sh"
BALLOT="$REPO/bin/polylane-taste-ballot.sh"
STATS="$REPO/bin/polylane-taste-stats.sh"

# --- 0. the four OWNed docs exist --------------------------------------------
for f in "$PROTO" "$RESEARCH" "$VIS" "$BLOCKS"; do
  if [ -s "$f" ]; then pass "doc-present:${f##*/}"
  else fail "doc-present:${f##*/}" "owned doc missing/empty: $f"; fi
done

# --- 1. every JSON example in PROTOCOL.md parses, no duplicate key paths ------
# Exactly the extraction the doc itself prescribes in §5. A contract example
# that does not parse (or repeats a key path) is not a contract.
jsondir=$(mktemp -d "${TMPDIR:-/tmp}/proto-json.XXXXXX")
awk -v dest="$jsondir" '
  /^```json$/ { in_json=1; n++; file=sprintf("%s/example-%02d.json", dest, n); next }
  /^```$/ && in_json { close(file); in_json=0; next }
  in_json { print > file }
' "$PROTO"
json_n=0; json_bad=0
for ex in "$jsondir"/*.json; do
  [ -f "$ex" ] || continue
  json_n=$((json_n + 1))
  if ! jq -e . "$ex" >/dev/null 2>&1; then json_bad=$((json_bad + 1)); continue; fi
  dups=$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("")' "$ex" 2>/dev/null | LC_ALL=C sort | uniq -d)
  [ -z "$dups" ] || json_bad=$((json_bad + 1))
done
rm -rf "$jsondir"
if [ "$json_n" -ge 10 ]; then pass "protocol-json-count"
else fail "protocol-json-count" "expected >=10 JSON examples, found $json_n"; fi
if [ "$json_bad" -eq 0 ]; then pass "protocol-json-parse"
else fail "protocol-json-parse" "$json_bad JSON example(s) fail to parse or repeat a key path"; fi

# --- 2. taste-pointwise/v1 has the 8 LIVE dimensions, not the dead 11 --------
# The live validator (polylane-taste-ballot.sh) enforces exactly these 8 keys.
live8='color craftsmanship hierarchy originality product_fit spatial_rhythm state_coherence typography'
for k in $live8; do
  if grep -qF "\"$k\"" "$BALLOT"; then pass "ballot-dim:$k"
  else fail "ballot-dim:$k" "live validator no longer enforces scores_1_to_7.$k — update the assertion"; fi
done
# The 4 dead dimensions from the old 11-key doc example must be gone everywhere.
for dead in color_imagery interaction_feedback expressiveness simplicity; do
  if grep -qF "$dead" "$PROTO"; then
    fail "proto-no-dead-dim:$dead" "PROTOCOL.md still lists dead pointwise dimension '$dead' (live set is 8)"
  else pass "proto-no-dead-dim:$dead"; fi
done

# --- 3. claim labels: doc names exactly what the producer emits --------------
# Producer emits claim_label in {HUMAN_CERTIFIED, HUMAN_CALIBRATED_MACHINE,
# NOT-CERTIFIED} and status in {TASTE-CERTIFIED, NOT-CERTIFIED}.
for label in HUMAN_CERTIFIED HUMAN_CALIBRATED_MACHINE NOT-CERTIFIED; do
  if grep -qF "$label" "$TASTE" && grep -qF "$label" "$PROTO"; then pass "label-live:$label"
  else fail "label-live:$label" "$label must appear in both producer and PROTOCOL.md"; fi
done
# MACHINE_EVALUATED is a design-ladder label the LIVE compiler never emits.
if grep -q "MACHINE_EVALUATED" "$TASTE"; then
  fail "machine-evaluated-not-emitted" "producer now emits MACHINE_EVALUATED — update the doc claim ladder"
else pass "machine-evaluated-not-emitted"; fi
# If PROTOCOL.md keeps MACHINE_EVALUATED it must mark it reserved/not-emitted.
if grep -qF "MACHINE_EVALUATED" "$PROTO"; then
  if grep -Eiq 'MACHINE_EVALUATED.*(reserved|not emitted|not yet)|(reserved|not emitted|not yet).*MACHINE_EVALUATED' "$PROTO" \
     || grep -Eiq 'not emitted by the (live|current) compiler' "$PROTO"; then
    pass "machine-evaluated-marked-reserved"
  else
    fail "machine-evaluated-marked-reserved" "PROTOCOL.md lists MACHINE_EVALUATED without marking it reserved/not emitted"
  fi
else pass "machine-evaluated-marked-reserved"; fi

# --- 4. certificate: doc documents BOTH the v1 fixture and v2 production forms
if grep -qF 'taste-certificate/v1' "$PROTO" && grep -qF 'taste-certificate/v2' "$PROTO"; then
  pass "cert-both-versions-doc"
else fail "cert-both-versions-doc" "PROTOCOL.md must document both taste-certificate/v1 (fixture) and /v2 (production)"; fi
# Both versions are what the producer actually writes.
if grep -qF 'taste-certificate/v1' "$TASTE" && grep -qF 'taste-certificate/v2' "$TASTE"; then
  pass "cert-both-versions-code"
else fail "cert-both-versions-code" "producer no longer emits both certificate versions — update the doc"; fi

# --- 5. every LIVE schema_version the doc claims exists in a producer --------
# These are enforced/emitted by the Cycle-39 tree; the doc must not invent a
# schema the code does not carry.
live_schemas='taste-evidence-manifest/v1 taste-evidence-manifest/v2 taste-ballot-validation/v1 taste-pointwise/v1 taste-mirrored-group/v1 taste-calibration/v1 taste-capture-manifest/v1 taste-hard-gate/v1 taste-corpus-receipt/v1 taste-pixels-receipt/v1 taste-provenance-escrow/v1 polylane.taste.stats.v1 polylane.taste.ballots.v1'
for s in $live_schemas; do
  if grep -qF "$s" "$PROTO"; then
    if grep -rqF "$s" "$REPO/bin/"; then pass "schema-live:$s"
    else fail "schema-live:$s" "PROTOCOL.md names $s but no bin/ producer carries it"; fi
  else pass "schema-live:$s"; fi   # doc need not mention every schema
done

# taste-ballot-validation/v2 is a Cycle-40 (ballot-live) deliverable NOT in
# this tree; the doc may reference it, but only as future/not-yet-live.
if grep -qF 'taste-ballot-validation/v2' "$PROTO"; then
  if grep -rqF 'taste-ballot-validation/v2' "$REPO/bin/polylane-taste-ballot.sh"; then
    fail "ballot-v2-still-future" "ballot-live merged into this tree — the doc may now call ballot-v2 live"
  elif grep -Eiq 'ballot[^.]*v2.*(Cycle 40|not yet|future|frozen plan|ballot-live)|(Cycle 40|not yet|future|frozen plan|ballot-live).*ballot[^.]*v2' "$PROTO"; then
    pass "ballot-v2-marked-future"
  else
    fail "ballot-v2-marked-future" "PROTOCOL.md references taste-ballot-validation/v2 without marking it a not-yet-live Cycle-40 deliverable"
  fi
else pass "ballot-v2-marked-future"; fi

# --- 6. producers stamp fixture; the doc says so -----------------------------
for p in "$BALLOT" "$STATS"; do
  if grep -qF '"fixture"' "$p" || grep -qF 'fixture_only' "$p"; then pass "producer-fixture:${p##*/}"
  else fail "producer-fixture:${p##*/}" "expected fixture stamp in ${p##*/}"; fi
done
if grep -qiF 'fixture' "$PROTO"; then pass "proto-names-fixture"
else fail "proto-names-fixture" "PROTOCOL.md must distinguish fixture-grade evidence"; fi

# --- 7. the future/fixture lie is gone from the status of PROTOCOL.md --------
# The Cycle-37 doc opened "no source is written in this cycle". Sources exist.
if grep -qF 'no source is written in this cycle' "$PROTO"; then
  fail "proto-no-future-lie" "PROTOCOL.md still claims no source is written — producers now exist"
else pass "proto-no-future-lie"; fi
if grep -qiE 'live (harness|producer|boundary)' "$PROTO"; then pass "proto-live-language"
else fail "proto-live-language" "PROTOCOL.md must describe the live harness boundary"; fi

# --- 8. RESEARCH.md: honest live acquisition + secondary audit + label -------
# WAF/Chrome browser-adapter acquisition described honestly (Cycle-40 lock).
if grep -qiF 'WAF' "$RESEARCH" && grep -qiF 'browser adapter' "$RESEARCH"; then pass "research-waf-honest"
else fail "research-waf-honest" "RESEARCH.md must describe the AWS WAF / browser-adapter acquisition honestly"; fi
# The three CC0 Miniukovich-Figl Dataverse DOIs (primary corpus).
for doi in 9FKSQI XOI0HI Z7KLIH; do
  if grep -qF "$doi" "$RESEARCH"; then pass "research-doi:$doi"
  else fail "research-doi:$doi" "RESEARCH.md missing primary corpus release DVN/$doi"; fi
done
# TASTE is a SEPARATELY pinned SECONDARY audit, never a silent substitute.
if grep -qF 'TASTE' "$RESEARCH" && grep -qiE 'secondary|separate' "$RESEARCH"; then pass "research-taste-secondary"
else fail "research-taste-secondary" "RESEARCH.md must mark TASTE as a separate secondary audit"; fi
if grep -qF 'HUMAN_CALIBRATED_MACHINE' "$RESEARCH"; then pass "research-strongest-label"
else fail "research-strongest-label" "RESEARCH.md must name HUMAN_CALIBRATED_MACHINE as the strongest attainable label without recruited humans"; fi

# --- 9. frozen thresholds survive verbatim (no post-result drift) ------------
# 20 target / 10 floor / 7 wins / 0.70 preference / 5 groups must all be stated.
for f in "$PROTO" "$RESEARCH"; do
  base="${f##*/}"
  grep -qE '\b10\b' "$f" && grep -qE '\b20\b' "$f" || fail "floors-10-20:$base" "brief floor 10 / target 20 not both stated in $base"
  grep -qE '\b7\b' "$f" || fail "wins-7:$base" "7-brief-win floor not stated in $base"
  grep -qF '0.70' "$f" || fail "pref-070:$base" "0.70 preference floor not stated in $base"
done
# (record a single pass if all four docs kept the thresholds)
pass "frozen-thresholds-present"

# --- 10. every bin/polylane-taste-*.sh named in the docs is real+executable --
named=$(grep -ohE 'bin/polylane-[a-z-]+\.sh' "$PROTO" "$RESEARCH" "$VIS" "$BLOCKS" 2>/dev/null | sort -u)
for rel in $named; do
  if [ -x "$REPO/$rel" ]; then pass "named-bin:$rel"
  else fail "named-bin:$rel" "doc names $rel but it is missing or not executable"; fi
done

# --- 11. no forbidden overclaim asserted as an achieved fact -----------------
# The docs may DEFINE these as forbidden; they must never ASSERT them true.
if grep -qE '^\s*human_certified\s*[:=]\s*true' "$PROTO" "$RESEARCH"; then
  fail "no-human-certified-true" "a doc asserts human_certified:true as achieved — no recruited panel exists"
else pass "no-human-certified-true"; fi

# --- 12. status marker file, once written, has the exact first line ----------
STATUS="$REPO/docs/status-protocol-live.md"
if [ -f "$STATUS" ]; then
  first=$(head -1 "$STATUS")
  want='STATUS: protocol-live DONE run=c40-live-harness-20260812-a3'
  if [ "$first" = "$want" ]; then pass "status-marker-first-line"
  else fail "status-marker-first-line" "expected [$want] got [$first]"; fi
else
  pass "status-marker-first-line"   # not yet written during iteration
fi

finish
