#!/usr/bin/env bash
# test-taste-production-chain.sh — decisive cross-module production chain.
#
# This is the integrator's end-to-end negative/positive chain. It does NOT
# re-implement each module's internal attack matrix (those live in the frozen
# owner tests: test-taste-pixels/-certification/-tournament/-a11y/-stimulus/
# -memory/-visual-quality/-promptlint). It proves the SEAMS BETWEEN modules:
# a validator-produced receipt over REAL decoded PNG bytes flows through the
# real binaries, and mutating exactly one link at any trust boundary fails
# closed. No header-only image, caller-authored pass, forged label, prose
# verdict, or shape-only receipt may authorise anything.
#
# Everything is hermetic and offline. Optional adapters are declared, pinned,
# and receipted; an unavailable adapter is UNKNOWN, never PASS.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

if ! command -v jq >/dev/null 2>&1; then pass "taste-production-chain-skipped-no-jq"; finish; exit 0; fi
if ! command -v python3 >/dev/null 2>&1; then pass "taste-production-chain-skipped-no-python3"; finish; exit 0; fi

BIN="$(cd "$(dirname "$0")/.." && pwd)/bin"
PIXELS="$BIN/polylane-taste-pixels.sh"
TASTE="$BIN/polylane-taste.sh"
TOURN="$BIN/polylane-visual-tournament.sh"
QUALITY="$BIN/polylane-visual-quality.sh"
MEMORY="$BIN/polylane-taste-memory.sh"
PROMPTLINT="$BIN/polylane-promptlint.sh"
PROMPTOPT="$BIN/polylane-promptopt.sh"
HOOKS="$BIN/polylane-hooks.sh"
A11Y="$BIN/polylane-taste-a11y.sh"
STIMULUS="$BIN/polylane-taste-stimulus.sh"
pixels() { bash "$PIXELS" "$@"; }
sha() { shasum -a 256 "$1" | awk '{print $1}'; }

make_tmpdir
ROOT="$TEST_TMPDIR/project"
mkdir -p "$ROOT/evidence" "$ROOT/tools"
git -C "$ROOT" init -q
git -C "$ROOT" config user.email chain@example.test
git -C "$ROOT" config user.name chain
printf 'source revision\n' > "$ROOT/app.txt"
git -C "$ROOT" add app.txt
git -C "$ROOT" commit -qm source
REVISION=$(git -C "$ROOT" rev-parse HEAD)
SOURCE_INPUT_SHA=$(printf '%s' "$REVISION" | shasum -a 256 | awk '{print $1}')
COMMIT_EPOCH=$(git -C "$ROOT" log -1 --format=%ct HEAD)
iso_from_epoch() { date -u -r "$1" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -d "@$1" '+%Y-%m-%dT%H:%M:%SZ'; }

# --- real fixture pixels + a pinned, receipted decoder adapter ----------------
make_png() {
  python3 - "$1" "$2" "$3" "$4" <<'PY'
import binascii, struct, sys, zlib
path, width, height, seed = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
rows = []
for y in range(height):
    row = bytearray()
    for x in range(width):
        row.extend(((x + seed) % 251, (y * 3 + seed) % 251, (x + y + seed * 11) % 251))
    rows.append(b'\x00' + bytes(row))
raw = b''.join(rows)
def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', binascii.crc32(kind + data) & 0xffffffff)
png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
open(path, 'wb').write(png)
PY
}
make_solid_png() {
  python3 - "$1" "$2" "$3" <<'PY'
import binascii, struct, sys, zlib
path, width, height = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
raw = b''.join(b'\x00' + b'\xff\xff\xff' * width for _ in range(height))
def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', binascii.crc32(kind + data) & 0xffffffff)
open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))
PY
}
cat > "$ROOT/tools/decode-png" <<'PY'
#!/usr/bin/env python3
import binascii, hashlib, json, os, struct, sys, zlib
data = open(sys.argv[1], 'rb').read()
if data[:8] != b'\x89PNG\r\n\x1a\n': raise SystemExit('not png')
pos = 8; chunks = []
while pos < len(data):
    size = struct.unpack('>I', data[pos:pos+4])[0]; kind = data[pos+4:pos+8]; body = data[pos+8:pos+8+size]
    if len(kind) != 4 or len(body) != size or pos + 12 + size > len(data): raise SystemExit('bad chunk')
    if struct.unpack('>I', data[pos+8+size:pos+12+size])[0] != binascii.crc32(kind + body) & 0xffffffff: raise SystemExit('bad crc')
    chunks.append((kind, body)); pos += 12 + size
if pos != len(data) or chunks[0][0] != b'IHDR' or chunks[-1][0] != b'IEND': raise SystemExit('bad structure')
w,h,depth,kind,comp,flt,interlace = struct.unpack('>IIBBBBB', chunks[0][1])
if (depth,kind,comp,flt,interlace) != (8,2,0,0,0): raise SystemExit('unsupported fixture format')
raw = zlib.decompress(b''.join(body for tag, body in chunks if tag == b'IDAT'))
stride = w * 3
if len(raw) != h * (stride + 1) or any(raw[y * (stride + 1)] != 0 for y in range(h)): raise SystemExit('bad pixels')
pixels = b''.join(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)] for y in range(h))
colors = {pixels[i:i+3] for i in range(0, len(pixels), 3)}
receipt = {"schema_version":"taste-adapter-receipt/v1","adapter_id":"png-decoder","adapter_version":"fixture-v1","command_sha256":hashlib.sha256(open(sys.argv[0], 'rb').read()).hexdigest(),"input_sha256":[hashlib.sha256(data).hexdigest()],"output_sha256":[hashlib.sha256(pixels).hexdigest()],"exit_status":0,"executed_at":os.environ["TASTE_NOW"]}
print(json.dumps({"schema_version":"taste-png-decoder/v1","decoded_width":w,"decoded_height":h,"decoded_pixel_sha256":hashlib.sha256(pixels).hexdigest(),"pixel_payload_bytes":len(pixels),"distinct_pixel_values":len(colors),"non_background_pixel_count":sum(pixel != b'\xff\xff\xff' for pixel in colors),"adapter_receipt":receipt}, sort_keys=True))
PY
chmod +x "$ROOT/tools/decode-png"
DECODER_SHA=$(sha "$ROOT/tools/decode-png")

make_png "$ROOT/evidence/default-desktop.png" 1440 900 1
make_png "$ROOT/evidence/default-mobile.png" 390 844 2
make_png "$ROOT/evidence/loading-desktop.png" 1440 900 3
make_png "$ROOT/evidence/loading-mobile.png" 390 844 4
NOW=$(iso_from_epoch $((COMMIT_EPOCH + 3600)))
export TASTE_NOW="$NOW"

MANIFEST="$ROOT/evidence/captures.json"
capture_json() {
  local id="$1" route="$2" state="$3" viewport="$4" width="$5" height="$6" path="$7" result
  result=$("$ROOT/tools/decode-png" "$ROOT/evidence/$path")
  jq -n --arg id "$id" --arg route "$route" --arg state "$state" --arg viewport "$viewport" \
    --argjson width "$width" --argjson height "$height" --arg path "$path" --arg sha "$(sha "$ROOT/evidence/$path")" \
    --arg decoded "$(printf '%s' "$result" | jq -r .decoded_pixel_sha256)" --arg now "$NOW" \
    '{capture_id:$id,route:$route,state:$state,viewport:$viewport,viewport_css_px:{width:$width,height:$height},screenshot_path:$path,screenshot_png_sha256:$sha,decoded_pixel_sha256:$decoded,decoded_width:$width,decoded_height:$height,action_trace_sha256:("a" * 64),dom_sha256:("c" * 64),captured_at:$now}'
}
write_browser_receipt() {
  jq -n --arg now "$NOW" --arg source_input "$SOURCE_INPUT_SHA" --argjson outputs "$(jq '[.captures[].screenshot_png_sha256]' "$MANIFEST")" \
    '{schema_version:"taste-adapter-receipt/v1",adapter_id:"browser-capture",adapter_version:"fixture-v1",command_sha256:("b" * 64),input_sha256:[$source_input],output_sha256:$outputs,exit_status:0,executed_at:$now}' > "$ROOT/evidence/browser-receipt.json"
}
write_manifest() {
  local captures cand="${1:-cand-opaque-a}"
  captures=$(printf '%s\n' \
    "$(capture_json cap-default-desktop /declared default desktop 1440 900 default-desktop.png)" \
    "$(capture_json cap-default-mobile /declared default mobile 390 844 default-mobile.png)" \
    "$(capture_json cap-loading-desktop /declared loading desktop 1440 900 loading-desktop.png)" \
    "$(capture_json cap-loading-mobile /declared loading mobile 390 844 loading-mobile.png)" | jq -s .)
  jq -n --arg rev "$REVISION" --arg decoder "$DECODER_SHA" --argjson captures "$captures" --arg cand "$cand" '
    {schema_version:"taste-capture-manifest/v1",candidate_id:$cand,candidate_source_revision:$rev,
     required_routes:["/declared"],required_states:["default","loading"],mobile_only_states:[],
     browser:{adapter_id:"browser-capture",adapter_receipt_path:"browser-receipt.json"},
     decoder:{adapter_id:"png-decoder",adapter_version:"fixture-v1",command_path:"tools/decode-png",command_sha256:$decoder},
     captures:$captures}' > "$MANIFEST"
  write_browser_receipt
}
write_manifest
rejects() { pixels verify "$ROOT" "$MANIFEST" "$NOW" 2>&1 || true; }

# =============================================================================
# LINK 1 — the validator-produced pixel receipt over REAL decoded PNG bytes.
# =============================================================================
RECEIPT="$ROOT/evidence/pixels-receipt.json"
prc=0; out=$(pixels verify "$ROOT" "$MANIFEST" "$NOW" "$RECEIPT" 2>&1) || prc=$?
assert_eq "chain-pixels-verify-accepts-real-matrix" 0 "$prc"
assert_eq "chain-pixels-print" "TASTE-PIXELS: VERIFIED captures=4" "$out"
assert_eq "chain-receipt-schema" "taste-pixels-receipt/v1" "$(jq -r .schema_version "$RECEIPT")"
assert_eq "chain-receipt-status-derived-not-caller" "VERIFIED" "$(jq -r .status "$RECEIPT")"
assert_eq "chain-receipt-binds-source-revision" "$REVISION" "$(jq -r .subject.candidate_source_revision "$RECEIPT")"
assert_eq "chain-receipt-binds-decoded-pixels" "4" "$(jq -r '[.captures[].decoded_pixel_sha256]|unique|length' "$RECEIPT")"
assert_eq "chain-receipt-manifest-hash-bound" "$(sha "$MANIFEST")" "$(jq -r .inputs.capture_manifest_sha256 "$RECEIPT")"

# =============================================================================
# LINK 2 — one mutation per capture/pixel trust boundary, each fails closed.
# =============================================================================
printf '\211PNG\r\n\032\n' > "$ROOT/evidence/default-desktop.png"
jq --arg s "$(sha "$ROOT/evidence/default-desktop.png")" '.captures[0].screenshot_png_sha256=$s' "$MANIFEST" > "$MANIFEST.t" && mv "$MANIFEST.t" "$MANIFEST"; write_browser_receipt
assert_contains "chain-rejects-header-only-png" "PNG_STRUCTURE" "$(rejects)"
make_png "$ROOT/evidence/default-desktop.png" 1440 900 1; write_manifest

rm "$ROOT/evidence/default-desktop.png"; ln -s default-mobile.png "$ROOT/evidence/default-desktop.png"
assert_contains "chain-rejects-symlink-evidence" "UNSAFE_PATH" "$(rejects)"
rm "$ROOT/evidence/default-desktop.png"; make_png "$ROOT/evidence/default-desktop.png" 1440 900 1; write_manifest

jq '.captures[0].screenshot_path="../outside.png"' "$MANIFEST" > "$MANIFEST.t" && mv "$MANIFEST.t" "$MANIFEST"
assert_contains "chain-rejects-path-traversal" "UNSAFE_PATH" "$(rejects)"; write_manifest

jq '.captures[2].screenshot_path=.captures[0].screenshot_path | .captures[2].screenshot_png_sha256=.captures[0].screenshot_png_sha256 | .captures[2].decoded_pixel_sha256=.captures[0].decoded_pixel_sha256' "$MANIFEST" > "$MANIFEST.t" && mv "$MANIFEST.t" "$MANIFEST"; write_browser_receipt
assert_contains "chain-rejects-duplicate-render-across-states" "DUPLICATE_RENDER" "$(rejects)"; write_manifest

jq '.captures[0].viewport_css_px.width=1439' "$MANIFEST" > "$MANIFEST.t" && mv "$MANIFEST.t" "$MANIFEST"
assert_contains "chain-rejects-wrong-viewport" "VIEWPORT_MISMATCH" "$(rejects)"; write_manifest

jq '.captures[0].captured_at="2000-01-01T00:00:00Z"' "$MANIFEST" > "$MANIFEST.t" && mv "$MANIFEST.t" "$MANIFEST"
assert_contains "chain-rejects-stale-capture-before-source" "STALE_CAPTURE" "$(rejects)"; write_manifest

make_solid_png "$ROOT/evidence/default-desktop.png" 1440 900
jq --arg s "$(sha "$ROOT/evidence/default-desktop.png")" --arg d "$("$ROOT/tools/decode-png" "$ROOT/evidence/default-desktop.png" | jq -r .decoded_pixel_sha256)" '.captures[0].screenshot_png_sha256=$s|.captures[0].decoded_pixel_sha256=$d' "$MANIFEST" > "$MANIFEST.t" && mv "$MANIFEST.t" "$MANIFEST"; write_browser_receipt
assert_eq "chain-rejects-synthetic-placeholder" "TASTE-PIXELS: SYNTHETIC_PLACEHOLDER" "$(rejects)"
make_png "$ROOT/evidence/default-desktop.png" 1440 900 1; write_manifest

jq '.decoder.command_path="tools/missing-decoder"' "$MANIFEST" > "$MANIFEST.t" && mv "$MANIFEST.t" "$MANIFEST"
assert_contains "chain-unknown-adapter-is-unknown-not-pass" "DECODER_UNAVAILABLE" "$(rejects)"; write_manifest

# incomplete state matrix: required_states still lists loading, captures drop it.
jq '.captures = [.captures[] | select(.state=="default")]' "$MANIFEST" > "$MANIFEST.t" && mv "$MANIFEST.t" "$MANIFEST"; write_browser_receipt
imrc=0; pixels verify "$ROOT" "$MANIFEST" "$NOW" >/dev/null 2>&1 || imrc=$?
assert_eq "chain-rejects-incomplete-state-matrix" "2" "$imrc"; write_manifest

# =============================================================================
# LINK 3 — receipt values are inert DATA: nothing reaches eval / a shell.
# =============================================================================
rm -f "$ROOT/PWNED"
jq '.candidate_id="a; touch \"'"$ROOT"'/PWNED\" #"' "$MANIFEST" > "$MANIFEST.t" && mv "$MANIFEST.t" "$MANIFEST"; write_browser_receipt
pixels verify "$ROOT" "$MANIFEST" "$NOW" >/dev/null 2>&1 || true
assert_fail "chain-shell-metachar-id-never-executes" test -e "$ROOT/PWNED"; write_manifest

# duplicate JSON key anywhere in the manifest is rejected (no silent last-wins).
jq -c . "$MANIFEST" > "$ROOT/evidence/compact.json"
sed 's/^{"schema_version":"taste-capture-manifest\/v1"/{"schema_version":"taste-capture-manifest\/v1","schema_version":"forged"/' "$ROOT/evidence/compact.json" > "$ROOT/evidence/dup.json"
assert_rc "chain-rejects-duplicate-json-key" 2 pixels verify "$ROOT" "$ROOT/evidence/dup.json" "$NOW"

# fail-closed: a rejected verification writes NO receipt (no shape-only artifact).
jq '.captures[0].viewport_css_px.width=1439' "$MANIFEST" > "$MANIFEST.t" && mv "$MANIFEST.t" "$MANIFEST"
FCR="$ROOT/evidence/failclosed-receipt.json"; rm -f "$FCR"
pixels verify "$ROOT" "$MANIFEST" "$NOW" "$FCR" >/dev/null 2>&1 || true
assert_fail "chain-rejected-verify-writes-no-receipt" test -e "$FCR"; write_manifest

# =============================================================================
# LINK 4 — the certificate compiler rejects cross-run / duplicate-key evidence.
# =============================================================================
printf '{"schema_version":"taste-evidence-manifest/v2","run_id":"r1","run_id":"r2"}\n' > "$ROOT/dup-run.json"
assert_fail "chain-compiler-rejects-duplicate-run-id" bash "$TASTE" certify "$ROOT/dup-run.json" "$ROOT/dup-cert.json"
assert_fail "chain-compiler-rejects-garbage-manifest" bash "$TASTE" certify "$ROOT/nonexistent.json" "$ROOT/x.json"

# =============================================================================
# LINK 5 — prompt contract: a UI lane cannot omit the contract or self-certify.
# =============================================================================
GSHA=$(printf a | shasum -a256 | awk '{print $1}'); HEX64=$(printf b|shasum -a256|awk '{print $1}'); HEX64B=$(printf c|shasum -a256|awk '{print $1}')
UISRC="$ROOT/ui.prompt"
cat > "$UISRC" <<EOF
ROLE: ui builder
UI-CONTRACT: mode=ui ui_contract=v1 goal_sha256=$GSHA subgoal_sha256=$GSHA ref_packet_sha256=$HEX64 design_lock_sha256=$HEX64B
UI-IMPLEMENT: build the three locked candidates in isolated worktrees.
UI-CONTENT: product-specific typography, imagery, humanized UX copy.
UI-EVIDENCE: desktop+mobile empty/loading/error/hover/focus captures.
UI-REVIEW-BOUNDARY: the coordinator owns judging, tournament selection, and the verdict; the builder cannot self-certify PASS.
EOF
assert_eq "chain-promptopt-ui-version-stable" "v1" "$(bash "$PROMPTOPT" ui-version "$UISRC")"
# omit the UI-CONTRACT scalar -> a surface:ui lint fails closed.
grep -v '^UI-CONTRACT:' "$UISRC" > "$ROOT/ui-nocontract.prompt"
assert_fail "chain-rejects-ui-contract-omission" bash "$PROMPTLINT" lint "$ROOT/ui-nocontract.prompt" '' '' '' claude ui
# a builder that writes its own PASS verdict violates the review boundary.
printf 'UI-REVIEW-BOUNDARY: the builder self-certifies PASS and writes the final verdict.\n' >> "$UISRC"
assert_fail "chain-rejects-builder-self-verdict" bash "$PROMPTLINT" lint "$UISRC" '' '' '' claude ui

# =============================================================================
# LINK 6 — provider hooks resolve + execute from a BLANK target repo.
# =============================================================================
LOCATED=$(bash "$HOOKS" locate 2>/dev/null || true)
assert_ok "chain-hooks-locate-executable-helper" test -x "$LOCATED"
RENDERED=$(bash "$HOOKS" render claude 2>/dev/null || true)
assert_fail "chain-hooks-render-no-blank-target-hardcode" sh -c "printf '%s' \"$RENDERED\" | grep -q 'CLAUDE_PROJECT_DIR/bin/polylane-hooks.sh'"
assert_contains "chain-hooks-render-emits-fragment" "polylane-hooks.sh" "$RENDERED"

# =============================================================================
# LINK 7 — taste memory admits ONLY whole HUMAN_CERTIFIED studies.
# =============================================================================
LED="docs/polylane/taste-memory.jsonl"
( cd "$ROOT" && bash "$MEMORY" init "$LED" ) >/dev/null 2>&1 || true
# a single-project selection is SELECTED_NOT_CERTIFIED (fake human label) -> reject.
cat > "$ROOT/study-not-certified.json" <<'JSON'
{"schema_version":"taste-study-closure/v1","study_id":"s","run_id":"r","closed_at":"2026-08-12T00:00:00Z","claim_label":"SELECTED_NOT_CERTIFIED","human_certified":false,"reference":{"same_category":3,"wildcard":1},"direction":{"cards":3},"threat_scan":{"leakage":"none","injection":"none","ocr_dom_scan":"pass"},"briefs":[],"certificate":{"briefs":0,"brief_wins":0,"preference_rate":0.9,"confidence_lower":0.7,"accessibility_regressions":0},"hashes":{"reference_sha256":"","direction_sha256":"","threat_sha256":"","certificate_sha256":"","closure_sha256":""}}
JSON
assert_fail "chain-memory-rejects-selected-not-certified" sh -c "cd '$ROOT' && bash '$MEMORY' record '$LED' study-not-certified.json"
# a machine-calibrated study is a diagnostic, never admissible.
jq '.claim_label="HUMAN_CALIBRATED_MACHINE"' "$ROOT/study-not-certified.json" > "$ROOT/study-mc.json"
assert_fail "chain-memory-rejects-machine-calibrated" sh -c "cd '$ROOT' && bash '$MEMORY' record '$LED' study-mc.json"
# ledger path traversal is rejected.
assert_fail "chain-memory-rejects-traversal-ledger" sh -c "cd '$ROOT' && bash '$MEMORY' init 'docs/polylane/../../etc/x.jsonl'"

# =============================================================================
# LINK 8 — authoritative quality/tournament/a11y/stimulus fail closed on
# untrusted or malformed input; owner tests carry the full internal matrices.
# =============================================================================
assert_fail "chain-quality-certify-failcloses-on-hostile-record" bash "$QUALITY" certify "$ROOT" "$ROOT/no-such-record.json" "$ROOT/qv.json"
assert_fail "chain-tournament-failcloses-on-missing-escrow" bash "$TOURN" aggregate-match "$ROOT/no-escrow.json" 4 "1-2" cand-a cand-b --
printf 'not json\n' > "$ROOT/bad-a11y-plan.json"
A11YR="$ROOT/a11y-receipt.json"; rm -f "$A11YR"
assert_fail "chain-a11y-failcloses-on-untrusted-input" bash "$A11Y" audit "$ROOT" "$MANIFEST" "$ROOT/bad-a11y-plan.json" "$A11YR" -- /bin/false
assert_fail "chain-a11y-no-receipt-on-untrusted-input" test -e "$A11YR"
assert_fail "chain-stimulus-failcloses-on-missing-spec" bash "$STIMULUS" build "$ROOT/no-spec.json" "$ROOT/stim-out" -- /bin/false

finish
