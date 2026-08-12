#!/usr/bin/env bash
# png-decode.sh — declared PNG->RGBA decoder adapter (lane: decode-live).
#
# Contract (consumed verbatim by bin/polylane-taste-pixels.sh):
#   usage:  png-decode.sh <image.png>          [env TASTE_NOW=<RFC3339 UTC>]
#   stdout: one taste-png-decoder/v1 JSON object, keys sorted, on success.
#   exit:   0 on a fully verified decode; non-zero (no stdout JSON) otherwise.
#
# The decode itself is done by ffmpeg — an already-available explicit decoder,
# not a hand-rolled unfilter — so the RGBA payload carries ffmpeg's provenance.
# This adapter independently RE-DERIVES every number it reports from the image
# bytes: the PNG SHA, the width/height (from IHDR), the exact w*h*4 RGBA byte
# count, the pixel SHA, and the distinct / non-background diagnostics. It trusts
# no caller-supplied dimension or hash (there is no caller JSON: the sole input
# is a path), verifies container structure + every chunk CRC + the deflate
# stream before decoding, and caps dimensions and bytes BEFORE any allocation so
# an oversized-dimension or decompression-bomb image fails closed cheaply.
#
# An unavailable ffmpeg makes the decoder UNKNOWN: this adapter exits non-zero
# and emits no receipt (never a synthetic PASS).
set -euo pipefail

fail() { printf 'PNG-DECODE: %s\n' "$1" >&2; exit 1; }

[ $# -eq 1 ] || fail "usage: png-decode.sh <image.png>"
IMAGE="$1"
[ -e "$IMAGE" ] || fail "MISSING_INPUT"
[ ! -L "$IMAGE" ] || fail "SYMLINK_INPUT"        # refuse symlinked evidence
[ -f "$IMAGE" ] || fail "NOT_REGULAR_FILE"
[ -r "$IMAGE" ] || fail "UNREADABLE_INPUT"

command -v ffmpeg >/dev/null 2>&1 || fail "DECODER_UNKNOWN_NO_FFMPEG"
FFMPEG="$(command -v ffmpeg)"
FFVER="$(ffmpeg -version 2>/dev/null | awk 'NR==1{print $3; exit}')"
[ -n "$FFVER" ] || fail "DECODER_VERSION_UNKNOWN"
ADAPTER_VERSION="png-decode/1.0.0+ffmpeg-$FFVER"

# executed_at: the coordinator pins run time via TASTE_NOW so replay is exact;
# a standalone call stamps current UTC. Either way it must be RFC3339 UTC.
EXECUTED_AT="${TASTE_NOW:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
case "$EXECUTED_AT" in
  ????-??-??T??:??:??Z) ;;
  *) fail "BAD_EXECUTED_AT" ;;
esac

# Dimension / byte ceilings applied to IHDR BEFORE ffmpeg or zlib allocate.
# 8192px and 128 MiB dwarf every real capture (1440x900 = 5.2 MiB) yet bound the
# worst-case decode + diagnostic set. ponytail: distinct-value set is O(pixels)
# in memory; this cap is its ceiling. Raise both together if larger canvases land.
MAX_DIM=8192
MAX_BYTES=$((128 * 1024 * 1024))

python3 - "$IMAGE" "${BASH_SOURCE[0]}" "$FFMPEG" "$ADAPTER_VERSION" "$EXECUTED_AT" "$MAX_DIM" "$MAX_BYTES" <<'PY'
import binascii, hashlib, json, os, struct, subprocess, sys, zlib

image_path, script_path, ffmpeg, adapter_version, executed_at = sys.argv[1:6]
max_dim, max_bytes = int(sys.argv[6]), int(sys.argv[7])

def die(msg):
    sys.stderr.write("PNG-DECODE: %s\n" % msg)
    sys.exit(1)

# Cap the on-disk size before reading it into memory (cap bytes before alloc).
if os.path.getsize(image_path) > max_bytes:
    die("OVERSIZED_FILE")
data = open(image_path, 'rb').read()
input_sha = hashlib.sha256(data).hexdigest()

# --- structure + per-chunk CRC (rejects header-only / truncation / bad CRC) ---
if data[:8] != b'\x89PNG\r\n\x1a\n':
    die("BAD_SIGNATURE")
pos, chunks = 8, []
while pos + 12 <= len(data):
    (length,) = struct.unpack('>I', data[pos:pos+4])
    kind = data[pos+4:pos+8]
    if pos + 12 + length > len(data):
        die("TRUNCATED_CHUNK")
    body = data[pos+8:pos+8+length]
    (declared_crc,) = struct.unpack('>I', data[pos+8+length:pos+12+length])
    if declared_crc != (binascii.crc32(kind + body) & 0xffffffff):
        die("BAD_CRC")
    chunks.append((kind, body))
    pos += 12 + length
if pos != len(data):
    die("TRAILING_BYTES")
if not chunks or chunks[0][0] != b'IHDR' or len(chunks[0][1]) != 13 or chunks[-1][0] != b'IEND':
    die("BAD_STRUCTURE")

w, h, depth, ctype, comp, filt, interlace = struct.unpack('>IIBBBBB', chunks[0][1])
if comp != 0 or filt != 0 or interlace not in (0, 1):
    die("UNSUPPORTED_PNG_FLAGS")

# --- cap BEFORE decompressing or decoding (fail closed, no big allocation) ----
if w <= 0 or h <= 0 or w > max_dim or h > max_dim:
    die("OVERSIZED_DIMENSIONS")
rgba_bytes = w * h * 4
if rgba_bytes > max_bytes:
    die("OVERSIZED_PAYLOAD")

# --- deflate integrity: bounded decompress rejects bombs + broken streams -----
idat = b''.join(body for kind, body in chunks if kind == b'IDAT')
if not idat:
    die("NO_PIXEL_DATA")
limit = max_bytes + (1 << 20)
try:
    dobj = zlib.decompressobj()
    raw = dobj.decompress(idat, limit + 1)
    if len(raw) > limit:
        die("DECOMPRESSION_BOMB")
    raw += dobj.flush()
    if not dobj.eof:
        die("INCOMPLETE_DEFLATE_STREAM")
except zlib.error:
    die("DECOMPRESSION_FAILURE")

# --- pinned ffmpeg decode to raw RGBA (the declared decoder) -------------------
argv = [ffmpeg, '-v', 'error', '-nostdin', '-threads', '1', '-i', image_path,
        '-f', 'rawvideo', '-pix_fmt', 'rgba', '-frames:v', '1', '-']
proc = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
if proc.returncode != 0:
    die("DECODER_FAILED")
pixels = proc.stdout
if len(pixels) != rgba_bytes:
    die("PAYLOAD_SIZE_MISMATCH")   # decoded bytes must equal w*h*4 exactly

output_sha = hashlib.sha256(pixels).hexdigest()
distinct = len({pixels[i:i+4] for i in range(0, len(pixels), 4)})
non_background = sum(pixels[i:i+4] != b'\xff\xff\xff\xff' for i in range(0, len(pixels), 4))
command_sha = hashlib.sha256(open(script_path, 'rb').read()).hexdigest()

receipt = {
    "schema_version": "taste-adapter-receipt/v1",
    "adapter_id": "png-decoder",
    "adapter_version": adapter_version,
    "command_sha256": command_sha,
    "input_sha256": [input_sha],
    "output_sha256": [output_sha],
    "exit_status": 0,
    "executed_at": executed_at,
}
print(json.dumps({
    "schema_version": "taste-png-decoder/v1",
    "decoded_width": w,
    "decoded_height": h,
    "decoded_pixel_sha256": output_sha,
    "pixel_payload_bytes": len(pixels),
    "distinct_pixel_values": distinct,
    "non_background_pixel_count": non_background,
    "adapter_receipt": receipt,
}, sort_keys=True))
PY
