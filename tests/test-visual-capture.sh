#!/usr/bin/env bash
# Live visual capture: hermetic adapter contract and fail-closed evidence gates.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

CAPTURE="$(cd "$(dirname "$0")/.." && pwd)/bin/polylane-visual-capture.sh"
make_tmpdir
FIXTURE="$TEST_TMPDIR/fixture"; mkdir -p "$FIXTURE"
CANDIDATE="$FIXTURE/candidate.json"; PLAN="$FIXTURE/plan.json"; ADAPTER="$FIXTURE/browser-adapter.sh"
OUT="$TEST_TMPDIR/capture-out"

hex() { printf '%064d' "$1" | tr ' ' '0'; }
cat > "$CANDIDATE" <<EOF
{"schema_version":"taste-candidate/v1","candidate_id":"cand-opaque-a","brief_sha256":"$(hex 1)","design_lock_sha256":"$(hex 2)","direction_id":"d1","source_revision":"$(hex 3)","dependency_lock_sha256":"$(hex 4)","build_receipt_sha256":"$(hex 5)","created_at":"2026-08-11T00:00:00Z"}
EOF
cat > "$PLAN" <<EOF
{"schema_version":"taste-capture-plan/v1","run_id":"capture-test","browser":{"adapter_id":"fixture-browser","adapter_version":"1.0.0","command":"fixture-browser --capture","profile_sha256":"$(hex 6)"},"environment":{"locale":"en-US","timezone":"UTC","color_scheme":"light","device_scale_factor":1},"routes":["/checkout"],"states":[{"id":"default"},{"id":"validation-error"}]}
EOF
cat > "$ADAPTER" <<'EOF'
#!/usr/bin/env bash
set -eu
request="$POLYLANE_CAPTURE_REQUEST"; out="$POLYLANE_CAPTURE_OUTPUT"
route=$(jq -r .route "$request"); state=$(jq -r .state "$request")
width=$(jq -r .viewport_css_px.width "$request"); height=$(jq -r .viewport_css_px.height "$request")
mkdir -p "$out"
# sips produces a real, native-sized PNG from its system fixture; no browser is
# implied by this hermetic adapter, only the harness contract is exercised.
base64 -D > "$out/source.png" <<'PNG'
iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=
PNG
sips -z "$height" "$width" "$out/source.png" --out "$out/screenshot.png" >/dev/null
dd if=/dev/zero of="$out/pixels.rgba" bs=4 count=$((width * height)) 2>/dev/null
printf '<main data-route="%s" data-state="%s"></main>\n' "$route" "$state" > "$out/dom.html"
printf '{"route":%s,"state":%s,"actions":["navigate","settle"]}\n' "$(printf '%s' "$route" | jq -R .)" "$(printf '%s' "$state" | jq -R .)" > "$out/action-trace.json"
jq -n --arg route "$route" --arg state "$state" --argjson width "$width" --argjson height "$height" \
  '{schema_version:"taste-browser-capture-result/v1",route:$route,state:$state,navigation_status:"ok",viewport_css_px:{width:$width,height:$height},screenshot:"screenshot.png",decoded_pixels:"pixels.rgba",dom:"dom.html",action_trace:"action-trace.json",captured_at:"2026-08-11T00:00:01Z"}' > "$out/result.json"
EOF
chmod +x "$ADAPTER"

assert_fail "capture-missing-adapter-fails-closed" "$CAPTURE" capture "$CANDIDATE" "$PLAN" "$OUT" -- "$FIXTURE/no-browser"
assert_ok "capture-hermetic-adapter-completes-matrix" "$CAPTURE" capture "$CANDIDATE" "$PLAN" "$OUT" -- "$ADAPTER"
assert_eq "capture-has-four-locked-viewport-state-entries" "4" "$(jq '.captures | length' "$OUT/capture-manifest.json")"
assert_eq "capture-records-source-revision" "$(hex 3)" "$(jq -r .candidate_source_revision "$OUT/capture-manifest.json")"
assert_eq "capture-records-native-desktop-dimensions" "1440x900" "$(jq -r '.captures[] | select(.viewport_css_px.width == 1440) | "\(.decoded_width)x\(.decoded_height)"' "$OUT/capture-manifest.json" | head -n 1)"
assert_eq "capture-records-native-mobile-dimensions" "390x844" "$(jq -r '.captures[] | select(.viewport_css_px.width == 390) | "\(.decoded_width)x\(.decoded_height)"' "$OUT/capture-manifest.json" | head -n 1)"
assert_eq "capture-emits-one-receipt-per-entry" "4" "$(find "$OUT/adapter-receipts" -type f -name '*.json' | wc -l | tr -d ' ')"
assert_ok "capture-manifest-hashes-are-real" jq -e 'all(.captures[]; (.screenshot_png_sha256 | test("^[0-9a-f]{64}$")) and (.decoded_pixel_sha256 | test("^[0-9a-f]{64}$")) and (.action_trace_sha256 | test("^[0-9a-f]{64}$")) and (.dom_sha256 | test("^[0-9a-f]{64}$")))' "$OUT/capture-manifest.json"
assert_ok "capture-manifest-locates-each-screenshot" jq -e 'all(.captures[]; .screenshot_path | test("^captures/cap-[0-9]{3}/screenshot\\.png$"))' "$OUT/capture-manifest.json"

# A missing member of the Cartesian matrix cannot leave a partly refreshed tree.
PARTIAL="$TEST_TMPDIR/partial"; mkdir -p "$PARTIAL"; printf 'preserve\n' > "$PARTIAL/sentinel"
cp "$ADAPTER" "$FIXTURE/partial-adapter.sh"
sed -i '' '/mkdir -p "\$out"/a\
[ "$state" != "validation-error" ] || exit 8
' "$FIXTURE/partial-adapter.sh"
chmod +x "$FIXTURE/partial-adapter.sh"
assert_fail "capture-rejects-partial-declared-matrix" "$CAPTURE" capture "$CANDIDATE" "$PLAN" "$PARTIAL" -- "$FIXTURE/partial-adapter.sh"
assert_eq "capture-atomic-failure-preserves-existing-output" "preserve" "$(cat "$PARTIAL/sentinel")"

# Receipts are not accepted just because an adapter says pass: navigation,
# dimensions and independently recomputed output hashes must agree.
cp "$ADAPTER" "$FIXTURE/bad-navigation.sh"
sed -i '' 's/navigation_status:"ok"/navigation_status:"failed"/' "$FIXTURE/bad-navigation.sh"
chmod +x "$FIXTURE/bad-navigation.sh"
assert_fail "capture-rejects-failed-navigation" "$CAPTURE" capture "$CANDIDATE" "$PLAN" "$TEST_TMPDIR/bad-nav" -- "$FIXTURE/bad-navigation.sh"

cp "$ADAPTER" "$FIXTURE/wrong-dimensions.sh"
sed -i '' 's/{width:$width,height:$height}/{width:1,height:1}/' "$FIXTURE/wrong-dimensions.sh"
chmod +x "$FIXTURE/wrong-dimensions.sh"
assert_fail "capture-rejects-wrong-receipted-dimensions" "$CAPTURE" capture "$CANDIDATE" "$PLAN" "$TEST_TMPDIR/wrong-dims" -- "$FIXTURE/wrong-dimensions.sh"

cp "$ADAPTER" "$FIXTURE/fabricated-receipt.sh"
sed -i '' 's/screenshot:"screenshot.png"/screenshot:"result.json"/' "$FIXTURE/fabricated-receipt.sh"
chmod +x "$FIXTURE/fabricated-receipt.sh"
assert_ok "capture-fixture-mutates-fabricated-screenshot-reference" grep -q 'screenshot:"result.json"' "$FIXTURE/fabricated-receipt.sh"
assert_fail "capture-rejects-fabricated-artifact-receipt" "$CAPTURE" capture "$CANDIDATE" "$PLAN" "$TEST_TMPDIR/fake" -- "$FIXTURE/fabricated-receipt.sh"

cp "$ADAPTER" "$FIXTURE/aliased-artifacts.sh"
sed -i '' 's/dom:"dom.html"/dom:"action-trace.json"/' "$FIXTURE/aliased-artifacts.sh"
chmod +x "$FIXTURE/aliased-artifacts.sh"
assert_fail "capture-rejects-aliased-artifact-receipt" "$CAPTURE" capture "$CANDIDATE" "$PLAN" "$TEST_TMPDIR/aliased" -- "$FIXTURE/aliased-artifacts.sh"

cp "$ADAPTER" "$FIXTURE/stale-output.sh"
sed -i '' 's/2026-08-11T00:00:01Z/2025-08-11T00:00:01Z/' "$FIXTURE/stale-output.sh"
chmod +x "$FIXTURE/stale-output.sh"
assert_fail "capture-rejects-stale-adapter-output" "$CAPTURE" capture "$CANDIDATE" "$PLAN" "$TEST_TMPDIR/stale" -- "$FIXTURE/stale-output.sh"

finish
