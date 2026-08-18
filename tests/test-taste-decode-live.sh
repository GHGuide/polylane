#!/usr/bin/env bash
# test-taste-decode-live.sh — red-first proof of the live PNG->RGBA decoder.
#
# Lane: decode-live. Proves the declared, pinned decoder adapter
# (benchmarks/taste-live/tools/png-decode.sh) and its provenance wrapper
# (bin/polylane-taste-decode.sh) against REAL PNG fixtures, and that their
# output is consumed unchanged by the frozen pixel validator
# (bin/polylane-taste-pixels.sh) — no header-only image, forged digest,
# synthetic placeholder, or corrupt stream may authorise anything.
#
# The decoder is ffmpeg (an already-available explicit decoder). If it is
# absent the decoder is UNKNOWN, never PASS: the live assertions are skipped.
# Every fixture is generated here with recorded provenance (see the PY blocks);
# nothing is downloaded and no bytes come from the caller.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

if ! command -v jq >/dev/null 2>&1; then pass "decode-live-skipped-no-jq"; finish; exit 0; fi
if ! command -v python3 >/dev/null 2>&1; then pass "decode-live-skipped-no-python3"; finish; exit 0; fi
if ! command -v ffmpeg >/dev/null 2>&1; then pass "decode-live-skipped-no-ffmpeg-decoder-unknown"; finish; exit 0; fi

ROOTDIR="$(cd "$(dirname "$0")/.." && pwd)"
ADAPTER="$ROOTDIR/benchmarks/taste-live/tools/png-decode.sh"
WRAPPER="$ROOTDIR/bin/polylane-taste-decode.sh"
PIXELS="$ROOTDIR/bin/polylane-taste-pixels.sh"
sha() { shasum -a 256 "$1" | awk '{print $1}'; }
decode() { env TASTE_NOW="$1" bash "$ADAPTER" "$2" 2>/dev/null; }

make_tmpdir
W="$TEST_TMPDIR"
NOW="2026-08-12T00:00:00Z"

# --- fixture generators (real PNG bytes, recorded provenance) -----------------
# truecolor RGB gradient (colortype 2): many distinct colors, valid CRCs.
gen_rgb() {
  python3 - "$1" "$2" "$3" "$4" <<'PY'
import binascii, struct, sys, zlib
path, w, h, seed = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
raw = b''.join(b'\x00' + b''.join(bytes((((x+seed)%251),((y*3+seed)%251),((x+y+seed*11)%251))) for x in range(w)) for y in range(h))
def ch(k, d): return struct.pack('>I', len(d)) + k + d + struct.pack('>I', binascii.crc32(k+d) & 0xffffffff)
open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + ch(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) + ch(b'IDAT', zlib.compress(raw, 9)) + ch(b'IEND', b''))
PY
}
# truecolor + alpha (colortype 6): exercises the RGBA/alpha channel.
gen_rgba() {
  python3 - "$1" "$2" "$3" <<'PY'
import binascii, struct, sys, zlib
path, w, h = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
raw = b''.join(b'\x00' + b''.join(bytes(((x*20)%256,(y*20)%256,(x*7+y*13)%256,(x*y)%256)) for x in range(w)) for y in range(h))
def ch(k, d): return struct.pack('>I', len(d)) + k + d + struct.pack('>I', binascii.crc32(k+d) & 0xffffffff)
open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + ch(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) + ch(b'IDAT', zlib.compress(raw, 9)) + ch(b'IEND', b''))
PY
}
# indexed/palette (colortype 3): decoder must expand the palette to RGBA.
gen_palette() {
  python3 - "$1" "$2" "$3" <<'PY'
import binascii, struct, sys, zlib
path, w, h = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
plte = b''.join(bytes(((i*8)%256,(i*4)%256,(i*2)%256)) for i in range(8))
raw = b''.join(b'\x00' + bytes((x+y)%8 for x in range(w)) for y in range(h))
def ch(k, d): return struct.pack('>I', len(d)) + k + d + struct.pack('>I', binascii.crc32(k+d) & 0xffffffff)
open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + ch(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 3, 0, 0, 0)) + ch(b'PLTE', plte) + ch(b'IDAT', zlib.compress(raw, 9)) + ch(b'IEND', b''))
PY
}
# Adam7 interlaced truecolor (interlace=1): decoder must de-interlace.
gen_interlace() {
  python3 - "$1" "$2" "$3" <<'PY'
import binascii, struct, sys, zlib
path, w, h = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
def px(x, y): return bytes(((x*20)%256,(y*20)%256,(x*7+y*13)%256))
passes = [(0,0,8,8),(4,0,8,8),(0,4,4,8),(2,0,4,4),(0,2,2,4),(1,0,2,2),(0,1,1,2)]
stream = bytearray()
for sx, sy, dx, dy in passes:
    xs = list(range(sx, w, dx)); ys = list(range(sy, h, dy))
    if not xs or not ys: continue
    for y in ys:
        stream.append(0)
        for x in xs: stream += px(x, y)
def ch(k, d): return struct.pack('>I', len(d)) + k + d + struct.pack('>I', binascii.crc32(k+d) & 0xffffffff)
open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + ch(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 1)) + ch(b'IDAT', zlib.compress(bytes(stream), 9)) + ch(b'IEND', b''))
PY
}
# corruption fixtures: each isolates one malformation.
gen_corrupt() {
  python3 - "$1" "$2" <<'PY'
import binascii, struct, sys, zlib
kind, path = sys.argv[1], sys.argv[2]
w = h = 8
raw = b''.join(b'\x00' + b''.join(bytes(((x*30)%256,(y*30)%256,(x*y)%256)) for x in range(w)) for y in range(h))
def ch(k, d): return struct.pack('>I', len(d)) + k + d + struct.pack('>I', binascii.crc32(k+d) & 0xffffffff)
sig = b'\x89PNG\r\n\x1a\n'
ihdr = ch(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
idat = ch(b'IDAT', zlib.compress(raw, 9))
iend = ch(b'IEND', b'')
good = sig + ihdr + idat + iend
if kind == 'nonpng':
    data = b'this is definitely not a png file, just prose bytes' * 4
elif kind == 'header-only':
    data = sig + ihdr                      # no IDAT, no IEND
elif kind == 'truncation':
    data = good[:len(good)-20]             # cut IEND + tail of IDAT
elif kind == 'bad-crc':
    b = bytearray(good); b[len(sig)+len(ihdr)+8+4] ^= 0xff  # flip a byte inside IDAT body -> CRC no longer matches
    data = bytes(b)
elif kind == 'decompression-failure':
    body = b'\xde\xad\xbe\xef' * 8         # valid-CRC IDAT whose zlib stream is garbage
    idat_bad = ch(b'IDAT', body)
    data = sig + ihdr + idat_bad + iend
elif kind == 'oversized':
    big = ch(b'IHDR', struct.pack('>IIBBBBB', 100000, 100000, 8, 2, 0, 0, 0))
    data = sig + big + idat + iend         # tiny file, absurd declared dimensions
else:
    raise SystemExit('unknown corruption kind')
open(path, 'wb').write(data)
PY
}

# =============================================================================
# 0 — the declared tools exist and are executable (red until implemented).
# =============================================================================
assert_ok "decode-live-adapter-executable" test -x "$ADAPTER"
assert_ok "decode-live-wrapper-executable" test -x "$WRAPPER"

# =============================================================================
# 1 — valid RGB: exact dimensions, RGBA payload w*h*4, honest diagnostics,
#     and a provenance receipt binding source PNG + decoded pixels + tool.
# =============================================================================
gen_rgb "$W/rgb.png" 8 8 1
DEC=$(decode "$NOW" "$W/rgb.png"); drc=$?
assert_eq "decode-live-rgb-rc0" 0 "$drc"
printf '%s' "$DEC" | jq -e '
  (keys|sort) == ["adapter_receipt","decoded_height","decoded_pixel_sha256","decoded_width","distinct_pixel_values","non_background_pixel_count","pixel_payload_bytes","schema_version"]
  and .schema_version == "taste-png-decoder/v1"
  and (.decoded_width|type=="number" and floor==. and .>0)
  and (.decoded_height|type=="number" and floor==. and .>0)
  and (.decoded_pixel_sha256|test("^[0-9a-f]{64}$"))
  and (.pixel_payload_bytes|type=="number" and floor==. and .>0)
  and (.distinct_pixel_values|type=="number" and floor==. and .>0)
  and (.non_background_pixel_count|type=="number" and floor==. and .>=0)' >/dev/null 2>&1 \
  && pass "decode-live-rgb-schema" || fail "decode-live-rgb-schema" "bad top-level schema"
assert_eq "decode-live-rgb-width" 8 "$(printf '%s' "$DEC" | jq -r .decoded_width)"
assert_eq "decode-live-rgb-height" 8 "$(printf '%s' "$DEC" | jq -r .decoded_height)"
assert_eq "decode-live-rgb-payload-w-h-4" 256 "$(printf '%s' "$DEC" | jq -r .pixel_payload_bytes)"
assert_ok "decode-live-rgb-distinct-ge2" test "$(printf '%s' "$DEC" | jq -r .distinct_pixel_values)" -ge 2
assert_ok "decode-live-rgb-nonbg-gt0" test "$(printf '%s' "$DEC" | jq -r .non_background_pixel_count)" -gt 0
printf '%s' "$DEC" | jq -e --arg cmd "$(sha "$ADAPTER")" --arg png "$(sha "$W/rgb.png")" --arg now "$NOW" '
  .adapter_receipt as $r
  | ($r|keys|sort) == ["adapter_id","adapter_version","command_sha256","executed_at","exit_status","input_sha256","output_sha256","schema_version"]
  and $r.schema_version == "taste-adapter-receipt/v1"
  and $r.adapter_id == "png-decoder"
  and ($r.adapter_version|type=="string" and length>0)
  and $r.command_sha256 == $cmd
  and $r.input_sha256 == [$png]
  and $r.output_sha256 == [.decoded_pixel_sha256]
  and $r.exit_status == 0
  and $r.executed_at == $now' >/dev/null 2>&1 \
  && pass "decode-live-rgb-receipt-binds-source-tool-payload" || fail "decode-live-rgb-receipt-binds-source-tool-payload" "receipt not bound"

# =============================================================================
# 2 — alpha, palette, interlace: all decode to exact w*h*4 RGBA.
# =============================================================================
gen_rgba "$W/rgba.png" 6 5
DEC=$(decode "$NOW" "$W/rgba.png"); assert_eq "decode-live-rgba-rc0" 0 "$?"
assert_eq "decode-live-rgba-payload" 120 "$(printf '%s' "$DEC" | jq -r .pixel_payload_bytes)"
assert_eq "decode-live-rgba-width" 6 "$(printf '%s' "$DEC" | jq -r .decoded_width)"

gen_palette "$W/pal.png" 6 5
DEC=$(decode "$NOW" "$W/pal.png"); assert_eq "decode-live-palette-rc0" 0 "$?"
assert_eq "decode-live-palette-payload" 120 "$(printf '%s' "$DEC" | jq -r .pixel_payload_bytes)"

gen_interlace "$W/inter.png" 12 10
DEC=$(decode "$NOW" "$W/inter.png"); assert_eq "decode-live-interlace-rc0" 0 "$?"
assert_eq "decode-live-interlace-payload" 480 "$(printf '%s' "$DEC" | jq -r .pixel_payload_bytes)"
assert_eq "decode-live-interlace-width" 12 "$(printf '%s' "$DEC" | jq -r .decoded_width)"

# =============================================================================
# 3 — deterministic replay: identical bytes in, identical receipt out.
# =============================================================================
A=$(decode "$NOW" "$W/rgb.png"); B=$(decode "$NOW" "$W/rgb.png")
assert_eq "decode-live-deterministic" "$A" "$B"

# =============================================================================
# 4 — corruption matrix: every malformation fails closed (non-zero, no JSON).
# =============================================================================
for k in nonpng header-only truncation bad-crc decompression-failure oversized; do
  gen_corrupt "$k" "$W/c-$k.png"
  assert_fail "decode-live-rejects-$k" bash "$ADAPTER" "$W/c-$k.png"
done
# oversized must fail fast without allocating: guarded by the pre-decode cap.
ln -sf rgb.png "$W/link.png"
assert_fail "decode-live-rejects-symlink" bash "$ADAPTER" "$W/link.png"

# =============================================================================
# 5 — wrapper: thin decode passthrough + tool/source provenance + selftest.
# =============================================================================
WD=$(env TASTE_NOW="$NOW" bash "$WRAPPER" decode "$W/rgb.png" 2>/dev/null)
assert_eq "decode-live-wrapper-decode-matches-adapter" "$(decode "$NOW" "$W/rgb.png")" "$WD"
bash "$WRAPPER" provenance 2>/dev/null | jq -e --arg cmd "$(sha "$ADAPTER")" '
  .schema_version == "taste-decode-provenance/v1"
  and .decoder.tool == "ffmpeg"
  and (.decoder.binary_sha256|test("^[0-9a-f]{64}$"))
  and (.decoder.version|type=="string" and length>0)
  and (.decoder.invocation|type=="string" and (contains("rgba")))
  and .adapter.adapter_id == "png-decoder"
  and .adapter.command_sha256 == $cmd' >/dev/null 2>&1 \
  && pass "decode-live-wrapper-provenance-binds-binary-and-command" || fail "decode-live-wrapper-provenance-binds-binary-and-command" "bad provenance"
bash "$WRAPPER" manifest-decoder 2>/dev/null | jq -e --arg cmd "$(sha "$ADAPTER")" '
  (keys|sort) == ["adapter_id","adapter_version","command_path","command_sha256"]
  and .adapter_id == "png-decoder"
  and (.adapter_version|type=="string" and length>0)
  and (.command_path|type=="string" and length>0)
  and .command_sha256 == $cmd' >/dev/null 2>&1 \
  && pass "decode-live-wrapper-manifest-decoder-block" || fail "decode-live-wrapper-manifest-decoder-block" "bad decoder block"
assert_ok "decode-live-wrapper-selftest" bash "$WRAPPER" selftest

# =============================================================================
# 6 — LIVE: the frozen pixel validator consumes real decoder output unchanged.
# =============================================================================
ROOT="$W/project"
mkdir -p "$ROOT/evidence" "$ROOT/tools"
cp "$ADAPTER" "$ROOT/tools/png-decode.sh"; chmod +x "$ROOT/tools/png-decode.sh"
DECODER_SHA=$(sha "$ROOT/tools/png-decode.sh")
git -C "$ROOT" init -q
git -C "$ROOT" config user.email decode@example.test
git -C "$ROOT" config user.name decode
printf 'source revision\n' > "$ROOT/app.txt"
git -C "$ROOT" add app.txt
git -C "$ROOT" commit -qm source
REVISION=$(git -C "$ROOT" rev-parse HEAD)
SOURCE_INPUT_SHA=$(printf '%s' "$REVISION" | shasum -a 256 | awk '{print $1}')
COMMIT_EPOCH=$(git -C "$ROOT" log -1 --format=%ct HEAD)
LNOW=$(date -u -r $((COMMIT_EPOCH + 3600)) '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -d "@$((COMMIT_EPOCH + 3600))" '+%Y-%m-%dT%H:%M:%SZ')
export TASTE_NOW="$LNOW"

gen_rgb "$ROOT/evidence/default-desktop.png" 1440 900 1
gen_rgb "$ROOT/evidence/default-mobile.png" 390 844 2
gen_rgb "$ROOT/evidence/loading-desktop.png" 1440 900 3
gen_rgb "$ROOT/evidence/loading-mobile.png" 390 844 4

MANIFEST="$ROOT/evidence/captures.json"
capture_json() {
  local id="$1" route="$2" state="$3" viewport="$4" width="$5" height="$6" path="$7" result
  result=$(bash "$ROOT/tools/png-decode.sh" "$ROOT/evidence/$path")
  jq -n --arg id "$id" --arg route "$route" --arg state "$state" --arg viewport "$viewport" \
    --argjson width "$width" --argjson height "$height" --arg path "$path" --arg sha "$(sha "$ROOT/evidence/$path")" \
    --arg decoded "$(printf '%s' "$result" | jq -r .decoded_pixel_sha256)" --arg now "$LNOW" \
    '{capture_id:$id,route:$route,state:$state,viewport:$viewport,viewport_css_px:{width:$width,height:$height},screenshot_path:$path,screenshot_png_sha256:$sha,decoded_pixel_sha256:$decoded,decoded_width:$width,decoded_height:$height,action_trace_sha256:("a"*64),dom_sha256:("c"*64),captured_at:$now}'
}
write_browser_receipt() {
  jq -n --arg now "$LNOW" --arg src "$SOURCE_INPUT_SHA" --argjson outputs "$(jq '[.captures[].screenshot_png_sha256]' "$MANIFEST")" \
    '{schema_version:"taste-adapter-receipt/v1",adapter_id:"browser-capture",adapter_version:"fixture-v1",command_sha256:("b"*64),input_sha256:[$src],output_sha256:$outputs,exit_status:0,executed_at:$now}' > "$ROOT/evidence/browser-receipt.json"
}
write_manifest() {
  local captures
  captures=$(printf '%s\n' \
    "$(capture_json cap-default-desktop /declared default desktop 1440 900 default-desktop.png)" \
    "$(capture_json cap-default-mobile /declared default mobile 390 844 default-mobile.png)" \
    "$(capture_json cap-loading-desktop /declared loading desktop 1440 900 loading-desktop.png)" \
    "$(capture_json cap-loading-mobile /declared loading mobile 390 844 loading-mobile.png)" | jq -s .)
  jq -n --arg rev "$REVISION" --arg decoder "$DECODER_SHA" --argjson captures "$captures" '
    {schema_version:"taste-capture-manifest/v1",candidate_id:"cand-decode-live",candidate_source_revision:$rev,
     required_routes:["/declared"],required_states:["default","loading"],mobile_only_states:[],
     browser:{adapter_id:"browser-capture",adapter_receipt_path:"browser-receipt.json"},
     decoder:{adapter_id:"png-decoder",adapter_version:"live-v1",command_path:"tools/png-decode.sh",command_sha256:$decoder},
     captures:$captures}' > "$MANIFEST"
  write_browser_receipt
}
write_manifest

RECEIPT="$ROOT/evidence/pixels-receipt.json"
prc=0; out=$(bash "$PIXELS" verify "$ROOT" "$MANIFEST" "$LNOW" "$RECEIPT" 2>&1) || prc=$?
assert_eq "decode-live-pixels-verify-accepts-real-matrix" 0 "$prc"
assert_eq "decode-live-pixels-verify-print" "TASTE-PIXELS: VERIFIED captures=4" "$out"
assert_eq "decode-live-pixels-receipt-schema" "taste-pixels-receipt/v1" "$(jq -r .schema_version "$RECEIPT" 2>/dev/null)"
assert_eq "decode-live-pixels-binds-decoder-command" "$DECODER_SHA" "$(jq -r .inputs.decoder_command_sha256 "$RECEIPT" 2>/dev/null)"

# digest drift: a forged decoded hash no longer matches the real decode.
jq '.captures[0].decoded_pixel_sha256="0000000000000000000000000000000000000000000000000000000000000000"' "$MANIFEST" > "$MANIFEST.t" && mv "$MANIFEST.t" "$MANIFEST"
assert_contains "decode-live-rejects-digest-drift" "DECODED_HASH_MISMATCH" "$(bash "$PIXELS" verify "$ROOT" "$MANIFEST" "$LNOW" 2>&1 || true)"
write_manifest

# duplicate render: two states share one image -> not distinct evidence.
jq '.captures[2].screenshot_path=.captures[0].screenshot_path | .captures[2].screenshot_png_sha256=.captures[0].screenshot_png_sha256 | .captures[2].decoded_pixel_sha256=.captures[0].decoded_pixel_sha256' "$MANIFEST" > "$MANIFEST.t" && mv "$MANIFEST.t" "$MANIFEST"; write_browser_receipt
assert_contains "decode-live-rejects-duplicate-render" "DUPLICATE_RENDER" "$(bash "$PIXELS" verify "$ROOT" "$MANIFEST" "$LNOW" 2>&1 || true)"

finish
