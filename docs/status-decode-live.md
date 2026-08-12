STATUS: decode-live DONE run=c40-live-harness-20260812-a3

Lane: decode-live. Declared PNG->RGBA decoder adapter + provenance wrapper,
consumed unchanged by the frozen pixel validator (bin/polylane-taste-pixels.sh).

Delivered (owned only):
- benchmarks/taste-live/tools/png-decode.sh — pinned ffmpeg decode; re-derives
  PNG SHA, IHDR width/height, exact w*h*4 RGBA payload, pixel SHA, distinct /
  non-background diagnostics; taste-png-decoder/v1 + taste-adapter-receipt/v1;
  structure + per-chunk CRC + deflate integrity; file/dimension/byte caps before
  allocation; no caller-trusted dimension or hash; absent ffmpeg => UNKNOWN.
- bin/polylane-taste-decode.sh — decode / provenance (ffmpeg binary+version+
  invocation + adapter command hash) / manifest-decoder / live selftest.
- tests/test-taste-decode-live.sh — red-first, 36 pass / 0 fail.
- docs/verify-decode-live.md — receipts, fixture provenance, deterministic
  replay, corruption matrix, live consumption, skill evidence.

Evidence:
- test: 36 pass, 0 fail (red-first: 26 fail pre-implementation).
- shellcheck -S warning on all three owned scripts: clean.
- live: polylane-taste-pixels.sh verify => TASTE-PIXELS: VERIFIED captures=4;
  rejects digest drift (DECODED_HASH_MISMATCH) and duplicate render.
- decoder: ffmpeg 8.1.1, binary_sha256
  00d01197255300c02122c783dd0126a9e7f47d6c6a19faafae2e6610efd071d3;
  adapter command_sha256
  037bcdbffe0648925a646212bd1a5d5c10ce51aee5d239e13718372ec6816945.

Relay: start + final pending checked; no request addressed to decode-live
(open requests target task-live / generate-live / study-live); inbox empty.
Forbidden paths (capture, pixel validator, a11y, ballots, certificate)
untouched. Concurrent capture work preserved.

SKILL-EVIDENCE: caveman:surgical-patch — helped: narrowest-layer change (two new
tools + one test at the decoder seam), task-relevant regression proof only.
SKILL-EVIDENCE: engineering:code-review — helped: adversarial binary-format lens
drove the corruption matrix and caught the pre-read file-size gap (fixed via
OVERSIZED_FILE cap before allocation).
