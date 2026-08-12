#!/usr/bin/env bash
# polylane-taste-decode.sh — provenance wrapper around the PNG->RGBA decoder.
#
# The decode adapter (benchmarks/taste-live/tools/png-decode.sh) owns the pinned
# ffmpeg invocation and the per-image receipt. This wrapper adds the pieces the
# adapter's tight schema has no room for and the harness needs around it:
#
#   decode <image.png>   thin passthrough to the adapter (honours TASTE_NOW).
#   provenance           taste-decode-provenance/v1: hashes the ffmpeg BINARY,
#                        its version, the pinned invocation, and the adapter
#                        command SHA — the tool identity behind every receipt.
#   manifest-decoder     the .decoder object a capture manifest embeds, bound to
#                        the live adapter's command_path + command_sha256.
#   selftest             live smoke: decode a generated PNG and assert the
#                        adapter's shape, w*h*4 payload, and deterministic replay.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
ADAPTER_REL="benchmarks/taste-live/tools/png-decode.sh"
ADAPTER="$ROOT/$ADAPTER_REL"
INVOCATION="ffmpeg -v error -nostdin -threads 1 -i <image> -f rawvideo -pix_fmt rgba -frames:v 1 -"

die() { printf 'taste-decode: %s\n' "$1" >&2; exit 1; }

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else return 1; fi
}

ffmpeg_version() { ffmpeg -version 2>/dev/null | awk 'NR==1{print $3; exit}'; }
adapter_version() { printf 'png-decode/1.0.0+ffmpeg-%s' "$(ffmpeg_version)"; }

require_adapter() { [ -f "$ADAPTER" ] || die "ADAPTER_MISSING $ADAPTER_REL"; }
require_ffmpeg() { command -v ffmpeg >/dev/null 2>&1 || die "DECODER_UNKNOWN_NO_FFMPEG"; }

cmd_decode() {
  [ $# -eq 1 ] || die "usage: decode <image.png>"
  require_adapter
  exec bash "$ADAPTER" "$1"
}

cmd_provenance() {
  require_adapter; require_ffmpeg
  local bin ver bin_sha cmd_sha
  bin="$(command -v ffmpeg)"
  ver="$(ffmpeg_version)"; [ -n "$ver" ] || die "DECODER_VERSION_UNKNOWN"
  bin_sha="$(sha256_file "$bin")" || die "SHA256_UNAVAILABLE"
  cmd_sha="$(sha256_file "$ADAPTER")" || die "SHA256_UNAVAILABLE"
  jq -n --arg now "${TASTE_NOW:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}" \
    --arg bin "$bin" --arg bin_sha "$bin_sha" --arg ver "$ver" --arg inv "$INVOCATION" \
    --arg av "$(adapter_version)" --arg cp "$ADAPTER_REL" --arg cs "$cmd_sha" '{
      schema_version:"taste-decode-provenance/v1",
      executed_at:$now,
      decoder:{tool:"ffmpeg",binary_path:$bin,binary_sha256:$bin_sha,version:$ver,invocation:$inv},
      adapter:{adapter_id:"png-decoder",adapter_version:$av,command_path:$cp,command_sha256:$cs}
    }'
}

cmd_manifest_decoder() {
  require_adapter; require_ffmpeg
  local cmd_sha
  cmd_sha="$(sha256_file "$ADAPTER")" || die "SHA256_UNAVAILABLE"
  jq -n --arg av "$(adapter_version)" --arg cp "$ADAPTER_REL" --arg cs "$cmd_sha" \
    '{adapter_id:"png-decoder",adapter_version:$av,command_path:$cp,command_sha256:$cs}'
}

cmd_selftest() {
  require_adapter; require_ffmpeg
  command -v python3 >/dev/null 2>&1 || die "PYTHON_UNAVAILABLE"
  command -v jq >/dev/null 2>&1 || die "JQ_UNAVAILABLE"
  local png out out2 payload distinct
  SELFTEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/taste-decode-selftest.XXXXXX")" || die "MKTEMP_FAILED"
  trap 'rm -rf "$SELFTEST_DIR"' EXIT
  png="$SELFTEST_DIR/smoke.png"
  python3 - "$png" <<'PY'
import binascii, struct, sys, zlib
path, w, h = sys.argv[1], 16, 12
raw = b''.join(b'\x00' + b''.join(bytes(((x*11)%256,(y*17)%256,(x+y)%256)) for x in range(w)) for y in range(h))
def ch(k, d): return struct.pack('>I', len(d)) + k + d + struct.pack('>I', binascii.crc32(k+d) & 0xffffffff)
open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + ch(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) + ch(b'IDAT', zlib.compress(raw, 9)) + ch(b'IEND', b''))
PY
  out="$(env TASTE_NOW=2026-01-01T00:00:00Z bash "$ADAPTER" "$png")" || die "SELFTEST_DECODE_FAILED"
  printf '%s' "$out" | jq -e '.schema_version=="taste-png-decoder/v1"' >/dev/null 2>&1 || die "SELFTEST_BAD_SCHEMA"
  payload="$(printf '%s' "$out" | jq -r .pixel_payload_bytes)"
  [ "$payload" = "$((16 * 12 * 4))" ] || die "SELFTEST_PAYLOAD_MISMATCH"
  distinct="$(printf '%s' "$out" | jq -r .distinct_pixel_values)"
  [ "$distinct" -ge 2 ] || die "SELFTEST_TOO_FEW_COLORS"
  out2="$(env TASTE_NOW=2026-01-01T00:00:00Z bash "$ADAPTER" "$png")" || die "SELFTEST_DECODE_FAILED"
  [ "$out" = "$out2" ] || die "SELFTEST_NONDETERMINISTIC"
  printf 'taste-decode: selftest OK payload=%s distinct=%s\n' "$payload" "$distinct"
}

main() {
  local sub="${1:-}"; shift || true
  case "$sub" in
    decode) cmd_decode "$@" ;;
    provenance) cmd_provenance "$@" ;;
    manifest-decoder) cmd_manifest_decoder "$@" ;;
    selftest) cmd_selftest "$@" ;;
    *) die "usage: polylane-taste-decode.sh {decode <png>|provenance|manifest-decoder|selftest}" ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
