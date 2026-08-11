#!/usr/bin/env bash
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

PIXELS="$(cd "$(dirname "$0")/.." && pwd)/bin/polylane-taste-pixels.sh"
pixels() { bash "$PIXELS" "$@"; }
make_tmpdir
ROOT="$TEST_TMPDIR/project"
mkdir -p "$ROOT/evidence" "$ROOT/tools"
git -C "$ROOT" init -q
git -C "$ROOT" config user.email pixels@example.test
git -C "$ROOT" config user.name pixels
printf 'source revision\n' > "$ROOT/app.txt"
git -C "$ROOT" add app.txt
git -C "$ROOT" commit -qm source
REVISION=$(git -C "$ROOT" rev-parse HEAD)
SOURCE_INPUT_SHA=$(printf '%s' "$REVISION" | shasum -a 256 | awk '{print $1}')

# These are local fixture pixels.  The production verifier has no Python
# dependency: it executes only the declared, receipted decoder adapter.
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
DECODER_SHA=$(shasum -a 256 "$ROOT/tools/decode-png" | awk '{print $1}')

make_png "$ROOT/evidence/default-desktop.png" 1440 900 1
make_png "$ROOT/evidence/default-mobile.png" 390 844 2
make_png "$ROOT/evidence/loading-desktop.png" 1440 900 3
make_png "$ROOT/evidence/loading-mobile.png" 390 844 4
NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
export TASTE_NOW="$NOW"

sha() { shasum -a 256 "$1" | awk '{print $1}'; }
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
  local captures
  captures=$(printf '%s\n' \
    "$(capture_json cap-default-desktop /declared default desktop 1440 900 default-desktop.png)" \
    "$(capture_json cap-default-mobile /declared default mobile 390 844 default-mobile.png)" \
    "$(capture_json cap-loading-desktop /declared loading desktop 1440 900 loading-desktop.png)" \
    "$(capture_json cap-loading-mobile /declared loading mobile 390 844 loading-mobile.png)" | jq -s .)
  jq -n --arg rev "$REVISION" --arg decoder "$DECODER_SHA" --arg now "$NOW" --argjson captures "$captures" '
    {schema_version:"taste-capture-manifest/v1",candidate_id:"cand-opaque-a",candidate_source_revision:$rev,
     required_routes:["/declared"],required_states:["default","loading"],mobile_only_states:[],
     browser:{adapter_id:"browser-capture",adapter_receipt_path:"browser-receipt.json"},
     decoder:{adapter_id:"png-decoder",adapter_version:"fixture-v1",command_path:"tools/decode-png",command_sha256:$decoder},
     captures:$captures}' > "$MANIFEST"
  write_browser_receipt
}

MANIFEST="$ROOT/evidence/captures.json"
write_manifest

# RED: the verifier did not exist when this adversarial acceptance test was added.
positive_rc=0
positive=$(pixels verify "$ROOT" "$MANIFEST" "$NOW" 2>&1) || positive_rc=$?
assert_eq "taste-pixels-accepts-complete-real-png-matrix" 0 "$positive_rc"
assert_eq "taste-pixels-prints-verification-receipt" "TASTE-PIXELS: VERIFIED captures=4" "$positive"

header_only() { printf '\211PNG\r\n\032\n' > "$ROOT/evidence/default-desktop.png"; }
update_hash() { local index="$1" path="$2"; jq --argjson i "$index" --arg sha "$(sha "$ROOT/$path")" '.captures[$i].screenshot_png_sha256=$sha' "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"; write_browser_receipt; }
rejects() { pixels verify "$ROOT" "$MANIFEST" "$NOW" 2>&1 || true; }

header_only
update_hash 0 evidence/default-desktop.png
assert_contains "taste-pixels-rejects-eight-byte-png" "PNG_STRUCTURE" "$(rejects)"
make_png "$ROOT/evidence/default-desktop.png" 1440 900 1
write_manifest

rm "$ROOT/evidence/default-desktop.png"
ln -s default-mobile.png "$ROOT/evidence/default-desktop.png"
assert_contains "taste-pixels-rejects-symlink-evidence" "UNSAFE_PATH" "$(rejects)"
rm "$ROOT/evidence/default-desktop.png"
make_png "$ROOT/evidence/default-desktop.png" 1440 900 1
write_manifest

jq '.captures[0].screenshot_path="../outside.png"' "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"
assert_contains "taste-pixels-rejects-traversal" "UNSAFE_PATH" "$(rejects)"
write_manifest

jq '.captures[2].screenshot_path=.captures[0].screenshot_path | .captures[2].screenshot_png_sha256=.captures[0].screenshot_png_sha256 | .captures[2].decoded_pixel_sha256=.captures[0].decoded_pixel_sha256' "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"
write_browser_receipt
assert_contains "taste-pixels-rejects-duplicate-state-pixels" "DUPLICATE_RENDER" "$(rejects)"
write_manifest

jq '.captures[0].viewport_css_px.width=1439' "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"
assert_contains "taste-pixels-rejects-wrong-viewport" "VIEWPORT_MISMATCH" "$(rejects)"
write_manifest

jq '.captures[0].captured_at="2000-01-01T00:00:00Z"' "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"
assert_contains "taste-pixels-rejects-stale-capture" "STALE_CAPTURE" "$(rejects)"
write_manifest

NOW=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
export TASTE_NOW="$NOW"
make_solid_png "$ROOT/evidence/default-desktop.png" 1440 900
update_hash 0 evidence/default-desktop.png
jq --arg decoded "$("$ROOT/tools/decode-png" "$ROOT/evidence/default-desktop.png" | jq -r .decoded_pixel_sha256)" '.captures[0].decoded_pixel_sha256=$decoded' "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"
write_browser_receipt
solid_rejection=$(rejects)
assert_eq "taste-pixels-rejects-solid-placeholder" "TASTE-PIXELS: SYNTHETIC_PLACEHOLDER" "$solid_rejection"
write_manifest

jq '.decoder.command_path="tools/missing-decoder"' "$MANIFEST" > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"
assert_contains "taste-pixels-requires-decoder-adapter" "DECODER_UNAVAILABLE" "$(rejects)"
finish
