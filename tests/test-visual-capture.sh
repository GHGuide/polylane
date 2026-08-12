#!/usr/bin/env bash
# Live visual capture: pinned browser/decoder identity trust boundary,
# independently decoded pixels, replayable state matrices, tamper-evident
# receipts. This whole harness is FIXTURE-ONLY: it exercises the adapter
# contract with a hermetic sips renderer and a stand-in decoder. It can never
# authorize production promotion — the coordinator-owned allowlist does.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

CAPTURE="$(cd "$(dirname "$0")/.." && pwd)/bin/polylane-visual-capture.sh"
PIXELS="$(cd "$(dirname "$0")/.." && pwd)/bin/polylane-taste-pixels.sh"
make_tmpdir
FIXTURE="$TEST_TMPDIR/fixture"; mkdir -p "$FIXTURE/tools"
CANDIDATE="$FIXTURE/candidate.json"; PLAN="$FIXTURE/plan.json"; ADAPTER="$FIXTURE/browser-adapter.sh"
OUT="$TEST_TMPDIR/capture-out"
hex() { printf '%064d' "$1" | tr ' ' '0'; }

# --- pinned decoder: a stand-in that binds the screenshot's sibling RGBA ------
# A real deployment ships a true PNG decompressor; this hermetic stand-in is
# hash-pinned exactly like one and returns the same receipt shape.
cat > "$FIXTURE/tools/decode-png" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
image=$1
pixels="$(dirname "$image")/pixels.rgba"
width=$(sips -g pixelWidth "$image" | awk '/pixelWidth:/{print $2}')
height=$(sips -g pixelHeight "$image" | awk '/pixelHeight:/{print $2}')
image_sha=$(shasum -a 256 "$image" | awk '{print $1}')
pixels_sha=$(shasum -a 256 "$pixels" | awk '{print $1}')
pixels_bytes=$(wc -c < "$pixels" | tr -d ' ')
command_sha=$(shasum -a 256 "$0" | awk '{print $1}')
jq -n --arg image_sha "$image_sha" --arg pixels_sha "$pixels_sha" --arg command_sha "$command_sha" --arg now "$TASTE_NOW" --argjson width "$width" --argjson height "$height" --argjson bytes "$pixels_bytes" \
  '{schema_version:"taste-png-decoder/v1",decoded_width:$width,decoded_height:$height,decoded_pixel_sha256:$pixels_sha,pixel_payload_bytes:$bytes,distinct_pixel_values:2,non_background_pixel_count:1,adapter_receipt:{schema_version:"taste-adapter-receipt/v1",adapter_id:"png-decoder",adapter_version:"fixture",command_sha256:$command_sha,input_sha256:[$image_sha],output_sha256:[$pixels_sha],exit_status:0,executed_at:$now}}'
EOF
chmod +x "$FIXTURE/tools/decode-png"
DECODER_SHA=$(shasum -a 256 "$FIXTURE/tools/decode-png" | awk '{print $1}')

# --- source revision (git) for identity + pixel-consumer verification --------
git -C "$FIXTURE" init -q
git -C "$FIXTURE" config user.email capture@example.test
git -C "$FIXTURE" config user.name capture
printf 'fixture source\n' > "$FIXTURE/app.txt"
git -C "$FIXTURE" add app.txt tools/decode-png
git -C "$FIXTURE" commit -qm source
REVISION=$(git -C "$FIXTURE" rev-parse HEAD)

# --- hermetic browser adapter: distinct colour + whole-buffer RGBA per state --
cat > "$ADAPTER" <<'EOF'
#!/usr/bin/env bash
set -eu
request="$POLYLANE_CAPTURE_REQUEST"; out="$POLYLANE_CAPTURE_OUTPUT"
route=$(jq -r .route "$request"); state=$(jq -r .state "$request")
width=$(jq -r .viewport_css_px.width "$request"); height=$(jq -r .viewport_css_px.height "$request")
mkdir -p "$out"
case "$state" in
  default)          color='0 0 255';     fill=001 ;;
  validation-error) color='255 0 0';     fill=002 ;;
  empty)            color='0 255 0';     fill=003 ;;
  loading)          color='255 255 0';   fill=004 ;;
  error)            color='255 0 255';   fill=005 ;;
  hover)            color='0 255 255';   fill=006 ;;
  focus)            color='128 128 128'; fill=007 ;;
  *)                color='64 64 64';    fill=010 ;;
esac
printf 'P3\n1 1\n255\n%s\n' "$color" > "$out/source.ppm"
sips -s format png -z "$height" "$width" "$out/source.ppm" --out "$out/screenshot.png" >/dev/null
dd if=/dev/zero bs=4 count=$((width * height)) 2>/dev/null | LC_ALL=C tr '\000' "\\$fill" > "$out/pixels.rgba"
printf '<main data-route="%s" data-state="%s"></main>\n' "$route" "$state" > "$out/dom.html"
printf '{"route":%s,"state":%s,"actions":["navigate","settle"]}\n' "$(printf '%s' "$route" | jq -R .)" "$(printf '%s' "$state" | jq -R .)" > "$out/action-trace.json"
jq -n --arg route "$route" --arg state "$state" --arg captured "${POLYLANE_CAPTURE_NOW:-2026-08-11T00:00:01Z}" --argjson width "$width" --argjson height "$height" \
  '{schema_version:"taste-browser-capture-result/v1",route:$route,state:$state,navigation_status:"ok",viewport_css_px:{width:$width,height:$height},screenshot:"screenshot.png",decoded_pixels:"pixels.rgba",dom:"dom.html",action_trace:"action-trace.json",captured_at:$captured}' > "$out/result.json"
EOF
chmod +x "$ADAPTER"
ADAPTER_SHA=$(shasum -a 256 "$ADAPTER" | awk '{print $1}')
CANON_ADAPTER="$(cd "$(dirname "$ADAPTER")" && pwd -P)/$(basename "$ADAPTER")"

cat > "$CANDIDATE" <<EOF
{"schema_version":"taste-candidate/v1","candidate_id":"cand-opaque-a","brief_sha256":"$(hex 1)","design_lock_sha256":"$(hex 2)","direction_id":"d1","source_revision":"$REVISION","dependency_lock_sha256":"$(hex 4)","build_receipt_sha256":"$(hex 5)","created_at":"2026-08-11T00:00:00Z"}
EOF
cat > "$PLAN" <<EOF
{"schema_version":"taste-capture-plan/v1","run_id":"capture-test","browser":{"adapter_id":"browser-capture","adapter_version":"1.0.0","command":"fixture-browser --capture","profile_sha256":"$(hex 6)"},"decoder":{"adapter_id":"png-decoder","adapter_version":"fixture","command_path":"tools/decode-png","command_sha256":"$DECODER_SHA"},"environment":{"locale":"en-US","timezone":"UTC","color_scheme":"light","device_scale_factor":1},"routes":["/checkout"],"states":[{"id":"default"},{"id":"validation-error"}]}
EOF

# === positive fixture matrix =================================================
assert_fail "capture-missing-adapter-fails-closed" "$CAPTURE" capture "$CANDIDATE" "$PLAN" "$OUT" -- "$FIXTURE/no-browser"
assert_ok   "capture-hermetic-adapter-completes-matrix" "$CAPTURE" capture "$CANDIDATE" "$PLAN" "$OUT" -- "$ADAPTER"
assert_eq   "capture-has-four-locked-viewport-state-entries" "4" "$(jq '.captures | length' "$OUT/capture-manifest.json")"
assert_eq   "capture-records-source-revision" "$REVISION" "$(jq -r .candidate_source_revision "$OUT/capture-manifest.json")"
assert_eq   "capture-records-native-desktop-dimensions" "1440x900" "$(jq -r '.captures[] | select(.viewport_css_px.width == 1440) | "\(.decoded_width)x\(.decoded_height)"' "$OUT/capture-manifest.json" | head -n 1)"
assert_eq   "capture-records-native-mobile-dimensions" "390x844" "$(jq -r '.captures[] | select(.viewport_css_px.width == 390) | "\(.decoded_width)x\(.decoded_height)"' "$OUT/capture-manifest.json" | head -n 1)"
assert_eq   "capture-emits-per-entry-and-aggregate-receipts" "5" "$(find "$OUT/adapter-receipts" -type f -name '*.json' | wc -l | tr -d ' ')"
assert_ok   "capture-manifest-hashes-are-real" jq -e 'all(.captures[]; (.screenshot_png_sha256 | test("^[0-9a-f]{64}$")) and (.decoded_pixel_sha256 | test("^[0-9a-f]{64}$")) and (.action_trace_sha256 | test("^[0-9a-f]{64}$")) and (.dom_sha256 | test("^[0-9a-f]{64}$")))' "$OUT/capture-manifest.json"
assert_ok   "capture-manifest-locates-each-screenshot" jq -e 'all(.captures[]; .screenshot_path | test("^captures/cap-[0-9]{3}/screenshot\\.png$"))' "$OUT/capture-manifest.json"
assert_ok   "capture-emits-pixel-verifier-manifest-fields" jq -e '(.required_routes == ["/checkout"]) and (.required_states == ["default","validation-error"]) and (.mobile_only_states == []) and (.browser.adapter_receipt_path == "adapter-receipts/browser.json") and (.decoder.adapter_id == "png-decoder") and all(.captures[]; .viewport | IN("desktop","mobile"))' "$OUT/capture-manifest.json"

# fixture runs are marked fixture-only; they carry no allowlist authorization.
assert_ok   "capture-marks-fixture-authorization" jq -e '.schema_version=="taste-capture-authorization/v1" and .fixture_only==true and .allowlist_entry_sha256==null' "$OUT/authorization.json"
# aggregate receipt chains the full identity, not just the source revision.
assert_ok   "capture-browser-receipt-chains-brief-and-locks" jq -e --arg b "$(hex 1)" --arg d "$(hex 2)" --arg p "$(hex 6)" --arg dec "$DECODER_SHA" '(.input_sha256 | index($b)!=null) and (.input_sha256 | index($d)!=null) and (.input_sha256 | index($p)!=null) and (.input_sha256 | index($dec)!=null)' "$OUT/adapter-receipts/browser.json"

# === independent pixel consumer (positive real native-sized fixture) =========
LIVE_OUT="$FIXTURE/evidence"
POLYLANE_CAPTURE_NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ') "$CAPTURE" capture "$CANDIDATE" "$PLAN" "$LIVE_OUT" -- "$ADAPTER"
PIXEL_NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
pixel_output=$(env TASTE_NOW="$PIXEL_NOW" "$PIXELS" verify "$FIXTURE" "$LIVE_OUT/capture-manifest.json" "$PIXEL_NOW" 2>&1) || true
assert_eq   "capture-output-passes-independent-pixel-verifier" "TASTE-PIXELS: VERIFIED captures=4" "$pixel_output"

# === complete PNG structure, not a 24-byte header ============================
cp "$ADAPTER" "$FIXTURE/header-only.sh"
# replace the real render with a signature+IHDR-only stub (24+ bytes, no IDAT/IEND)
sed -i '' 's#sips -s format png.*#printf "\\211PNG\\r\\n\\032\\n\\000\\000\\000\\015IHDR\\000\\000\\005\\240\\000\\000\\003\\204" > "$out/screenshot.png"#' "$FIXTURE/header-only.sh"
chmod +x "$FIXTURE/header-only.sh"
assert_fail "capture-rejects-ihdr-only-png" "$CAPTURE" capture "$CANDIDATE" "$PLAN" "$TEST_TMPDIR/hdr" -- "$FIXTURE/header-only.sh"

cp "$ADAPTER" "$FIXTURE/text-png.sh"
sed -i '' 's#sips -s format png.*#printf "this is not a png at all, just text bytes here" > "$out/screenshot.png"#' "$FIXTURE/text-png.sh"
chmod +x "$FIXTURE/text-png.sh"
assert_fail "capture-rejects-text-masquerading-as-png" "$CAPTURE" capture "$CANDIDATE" "$PLAN" "$TEST_TMPDIR/txt" -- "$FIXTURE/text-png.sh"

# === independently decoded pixels: screenshot/RGBA binding ===================
# Adapter declares a decoded-pixel file whose bytes differ from what the pinned
# decoder produces from the screenshot's sibling. Must be rejected.
cp "$ADAPTER" "$FIXTURE/rgba-mismatch.sh"
sed -i '' 's#decoded_pixels:"pixels.rgba"#decoded_pixels:"claimed.rgba"#' "$FIXTURE/rgba-mismatch.sh"
sed -i '' '/> "\$out\/dom.html"/i\
dd if=/dev/zero bs=4 count=$((width * height)) 2>/dev/null | LC_ALL=C tr '"'"'\\000'"'"' '"'"'\\077'"'"' > "$out/claimed.rgba"
' "$FIXTURE/rgba-mismatch.sh"
chmod +x "$FIXTURE/rgba-mismatch.sh"
assert_fail "capture-rejects-screenshot-rgba-mismatch" "$CAPTURE" capture "$CANDIDATE" "$PLAN" "$TEST_TMPDIR/rgba" -- "$FIXTURE/rgba-mismatch.sh"

# === metadata-distinct duplicate: different PNG bytes, identical pixels =======
cp "$ADAPTER" "$FIXTURE/metadata-dup.sh"
sed -i '' 's/fill=00[0-9]/fill=001/g; s/fill=010/fill=001/g' "$FIXTURE/metadata-dup.sh"
chmod +x "$FIXTURE/metadata-dup.sh"
assert_fail "capture-rejects-metadata-distinct-duplicate" "$CAPTURE" capture "$CANDIDATE" "$PLAN" "$TEST_TMPDIR/metadup" -- "$FIXTURE/metadata-dup.sh"

# === one-pixel near-duplicate: pixel shas differ by a single pixel ===========
cp "$ADAPTER" "$FIXTURE/near-dup.sh"
sed -i '' 's/fill=00[0-9]/fill=001/g; s/fill=010/fill=001/g' "$FIXTURE/near-dup.sh"
# flip exactly one byte, keyed to the state, so the two states differ by 1 pixel
sed -i '' '/> "\$out\/dom.html"/i\
case "$state" in validation-error) printf '"'"'\\001'"'"' | dd of="$out/pixels.rgba" bs=1 seek=0 conv=notrunc 2>/dev/null ;; esac
' "$FIXTURE/near-dup.sh"
chmod +x "$FIXTURE/near-dup.sh"
assert_fail "capture-rejects-one-pixel-near-duplicate" "$CAPTURE" capture "$CANDIDATE" "$PLAN" "$TEST_TMPDIR/neardup" -- "$FIXTURE/near-dup.sh"

# === malicious decoder replacement: on-disk decoder != pinned sha ============
DRIFT_PLAN="$FIXTURE/decoder-drift-plan.json"
jq --arg s "$(hex 9)" '.decoder.command_sha256=$s' "$PLAN" > "$DRIFT_PLAN"
assert_fail "capture-rejects-decoder-sha-drift" "$CAPTURE" capture "$CANDIDATE" "$DRIFT_PLAN" "$TEST_TMPDIR/decdrift" -- "$ADAPTER"

# === future-dated adapter output =============================================
cp "$ADAPTER" "$FIXTURE/future-output.sh"
sed -i '' 's/2026-08-11T00:00:01Z/2099-08-11T00:00:01Z/' "$FIXTURE/future-output.sh"
chmod +x "$FIXTURE/future-output.sh"
assert_fail "capture-rejects-future-adapter-output" "$CAPTURE" capture "$CANDIDATE" "$PLAN" "$TEST_TMPDIR/future" -- "$FIXTURE/future-output.sh"

# === stale adapter output (existing gate) ====================================
cp "$ADAPTER" "$FIXTURE/stale-output.sh"
sed -i '' 's/2026-08-11T00:00:01Z/2025-08-11T00:00:01Z/' "$FIXTURE/stale-output.sh"
chmod +x "$FIXTURE/stale-output.sh"
assert_fail "capture-rejects-stale-adapter-output" "$CAPTURE" capture "$CANDIDATE" "$PLAN" "$TEST_TMPDIR/stale" -- "$FIXTURE/stale-output.sh"

# === navigation / dimensions / fabricated / aliased (existing gates) =========
cp "$ADAPTER" "$FIXTURE/bad-navigation.sh"
sed -i '' 's/navigation_status:"ok"/navigation_status:"failed"/' "$FIXTURE/bad-navigation.sh"
chmod +x "$FIXTURE/bad-navigation.sh"
assert_fail "capture-rejects-failed-navigation" "$CAPTURE" capture "$CANDIDATE" "$PLAN" "$TEST_TMPDIR/bad-nav" -- "$FIXTURE/bad-navigation.sh"

cp "$ADAPTER" "$FIXTURE/wrong-dimensions.sh"
sed -i '' 's/viewport_css_px:{width:$width,height:$height},screenshot/viewport_css_px:{width:1,height:1},screenshot/' "$FIXTURE/wrong-dimensions.sh"
chmod +x "$FIXTURE/wrong-dimensions.sh"
assert_fail "capture-rejects-wrong-receipted-dimensions" "$CAPTURE" capture "$CANDIDATE" "$PLAN" "$TEST_TMPDIR/wrong-dims" -- "$FIXTURE/wrong-dimensions.sh"

cp "$ADAPTER" "$FIXTURE/fabricated-receipt.sh"
sed -i '' 's/screenshot:"screenshot.png"/screenshot:"result.json"/' "$FIXTURE/fabricated-receipt.sh"
chmod +x "$FIXTURE/fabricated-receipt.sh"
assert_fail "capture-rejects-fabricated-artifact-receipt" "$CAPTURE" capture "$CANDIDATE" "$PLAN" "$TEST_TMPDIR/fake" -- "$FIXTURE/fabricated-receipt.sh"

cp "$ADAPTER" "$FIXTURE/aliased-artifacts.sh"
sed -i '' 's/dom:"dom.html"/dom:"action-trace.json"/' "$FIXTURE/aliased-artifacts.sh"
chmod +x "$FIXTURE/aliased-artifacts.sh"
assert_fail "capture-rejects-aliased-artifact-receipt" "$CAPTURE" capture "$CANDIDATE" "$PLAN" "$TEST_TMPDIR/aliased" -- "$FIXTURE/aliased-artifacts.sh"

# === symlink / traversal on inputs and output ================================
ln -s "$PLAN" "$FIXTURE/plan-symlink.json"
assert_fail "capture-rejects-symlinked-plan" "$CAPTURE" capture "$CANDIDATE" "$FIXTURE/plan-symlink.json" "$TEST_TMPDIR/symplan" -- "$ADAPTER"
mkdir -p "$TEST_TMPDIR/realout"; ln -s "$TEST_TMPDIR/realout" "$TEST_TMPDIR/out-symlink"
assert_fail "capture-rejects-symlinked-output" "$CAPTURE" capture "$CANDIDATE" "$PLAN" "$TEST_TMPDIR/out-symlink" -- "$ADAPTER"

# === matrix omission + atomic rollback =======================================
PARTIAL="$TEST_TMPDIR/partial"; mkdir -p "$PARTIAL"; printf 'preserve\n' > "$PARTIAL/sentinel"
cp "$ADAPTER" "$FIXTURE/partial-adapter.sh"
sed -i '' '/mkdir -p "\$out"/a\
[ "$state" != "validation-error" ] || exit 8
' "$FIXTURE/partial-adapter.sh"
chmod +x "$FIXTURE/partial-adapter.sh"
assert_fail "capture-rejects-partial-declared-matrix" "$CAPTURE" capture "$CANDIDATE" "$PLAN" "$PARTIAL" -- "$FIXTURE/partial-adapter.sh"
assert_eq   "capture-atomic-failure-preserves-existing-output" "preserve" "$(cat "$PARTIAL/sentinel")"

# === production trust boundary: coordinator-owned allowlist ==================
PROD_PLAN="$FIXTURE/prod-plan.json"
jq '.fixture_only=false | .states=[{id:"default"},{id:"empty"},{id:"loading"},{id:"error"},{id:"hover"},{id:"focus"},{id:"checkout-flow"}]' "$PLAN" > "$PROD_PLAN"
ALLOWLIST="$FIXTURE/allowlist.json"
jq -n --arg path "$CANON_ADAPTER" --arg ver "1.0.0" --arg csha "$ADAPTER_SHA" --arg psha "$(hex 6)" --arg dsha "$DECODER_SHA" --arg rev "$REVISION" \
  '{schema_version:"taste-capture-allowlist/v1",entries:[{adapter_path:$path,adapter_version:$ver,command_sha256:$csha,profile_sha256:$psha,decoder_command_sha256:$dsha,environment:{locale:"en-US",timezone:"UTC",color_scheme:"light",device_scale_factor:1},source_revision:$rev}]}' > "$ALLOWLIST"

PROD_OUT="$FIXTURE/prod-evidence"
POLYLANE_CAPTURE_NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ') POLYLANE_CAPTURE_ALLOWLIST="$ALLOWLIST" \
  "$CAPTURE" capture "$CANDIDATE" "$PROD_PLAN" "$PROD_OUT" -- "$ADAPTER"
assert_eq   "capture-authorized-production-completes-full-state-matrix" "14" "$(jq '.captures | length' "$PROD_OUT/capture-manifest.json")"
assert_ok   "capture-authorized-production-is-allowlist-bound" jq -e '.fixture_only==false and (.allowlist_entry_sha256|test("^[0-9a-f]{64}$"))' "$PROD_OUT/authorization.json"

# A caller cannot flip fixture_only:false to become production without a matching
# coordinator-owned allowlist entry — it blocks, it does not fall back.
assert_fail "capture-blocks-production-without-allowlist" \
  env POLYLANE_CAPTURE_NOW="$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
  "$CAPTURE" capture "$CANDIDATE" "$PROD_PLAN" "$TEST_TMPDIR/noallow" -- "$ADAPTER"

# An arbitrary adapter not named by the allowlist cannot pose as authorized.
cp "$ADAPTER" "$FIXTURE/arbitrary-adapter.sh"; chmod +x "$FIXTURE/arbitrary-adapter.sh"
assert_fail "capture-blocks-arbitrary-adapter" \
  env POLYLANE_CAPTURE_NOW="$(date -u '+%Y-%m-%dT%H:%M:%SZ')" POLYLANE_CAPTURE_ALLOWLIST="$ALLOWLIST" \
  "$CAPTURE" capture "$CANDIDATE" "$PROD_PLAN" "$TEST_TMPDIR/arb" -- "$FIXTURE/arbitrary-adapter.sh"

# Source-revision drift from the allowlisted identity blocks promotion.
DRIFT_CANDIDATE="$FIXTURE/drift-candidate.json"
jq --arg r "$(printf '%040d' 7)" '.source_revision=$r' "$CANDIDATE" > "$DRIFT_CANDIDATE"
assert_fail "capture-blocks-source-revision-drift" \
  env POLYLANE_CAPTURE_NOW="$(date -u '+%Y-%m-%dT%H:%M:%SZ')" POLYLANE_CAPTURE_ALLOWLIST="$ALLOWLIST" \
  "$CAPTURE" capture "$DRIFT_CANDIDATE" "$PROD_PLAN" "$TEST_TMPDIR/drift" -- "$ADAPTER"

# A production plan missing a required rendered state is rejected by the lock.
UNDER_PLAN="$FIXTURE/underspecified-plan.json"
jq '.states=[{id:"default"},{id:"empty"},{id:"loading"},{id:"error"},{id:"hover"},{id:"checkout-flow"}]' "$PROD_PLAN" > "$UNDER_PLAN"
assert_fail "capture-blocks-production-missing-required-state" \
  env POLYLANE_CAPTURE_NOW="$(date -u '+%Y-%m-%dT%H:%M:%SZ')" POLYLANE_CAPTURE_ALLOWLIST="$ALLOWLIST" \
  "$CAPTURE" capture "$CANDIDATE" "$UNDER_PLAN" "$TEST_TMPDIR/under" -- "$ADAPTER"

finish
