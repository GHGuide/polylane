# Verify — decode-live (Cycle 40)

Lane **decode-live**, run `c40-live-harness-20260812-a3`.

**Goal.** A real, declared PNG→RGBA decoder adapter + provenance wrapper that
re-derives exact dimensions, RGBA pixel payload, source/tool provenance, and
corruption/duplicate evidence — consumed unchanged by the frozen pixel
validator `bin/polylane-taste-pixels.sh`.

Owned artifacts:

| Path | Role |
|---|---|
| `benchmarks/taste-live/tools/png-decode.sh` | decoder adapter (validator-invoked) |
| `bin/polylane-taste-decode.sh` | provenance wrapper (`decode`/`provenance`/`manifest-decoder`/`selftest`) |
| `tests/test-taste-decode-live.sh` | red-first proof (36 assertions) |
| `docs/verify-decode-live.md` | this file |
| `docs/status-decode-live.md` | run marker |

No forbidden path (capture, pixel validator, a11y, ballots, certificate) was
edited. The adapter shares only the schema the validator already declares.

---

## 1. Decoder selection — declared, pinned, receipted

The decode is performed by **ffmpeg**, an already-available explicit decoder on
this host (contract preference). It is not a hand-rolled unfilter, so the RGBA
payload carries ffmpeg's provenance. An **unavailable ffmpeg makes the decoder
UNKNOWN**: the adapter exits non-zero and emits no receipt (never a synthetic
PASS); the test skips its live assertions.

Binary + version + adapter-command receipt (real output of
`polylane-taste-decode.sh provenance`, `schema=taste-decode-provenance/v1`):

```json
{
  "decoder": {
    "tool": "ffmpeg",
    "binary_path": "/opt/homebrew/bin/ffmpeg",
    "binary_sha256": "00d01197255300c02122c783dd0126a9e7f47d6c6a19faafae2e6610efd071d3",
    "version": "8.1.1",
    "invocation": "ffmpeg -v error -nostdin -threads 1 -i <image> -f rawvideo -pix_fmt rgba -frames:v 1 -"
  },
  "adapter": {
    "adapter_id": "png-decoder",
    "adapter_version": "png-decode/1.0.0+ffmpeg-8.1.1",
    "command_path": "benchmarks/taste-live/tools/png-decode.sh",
    "command_sha256": "037bcdbffe0648925a646212bd1a5d5c10ce51aee5d239e13718372ec6816945"
  }
}
```

`command_sha256` equals `shasum -a256` of the adapter file byte-for-byte, so any
edit to the tool (tool drift) changes the digest and the validator's
`DECODER_RECEIPT` binding fails closed until the manifest is re-pinned.

The `binary_sha256`/`version` are host-specific: this receipt is *this* host's
evidence. A different host must re-run `provenance` to attest its own ffmpeg.

---

## 2. Contract consumed by the pixel validator

`png-decode.sh <image.png>` (env `TASTE_NOW=<RFC3339 UTC>`, optional) emits one
sorted `taste-png-decoder/v1` object; exit 0 only on a fully verified decode.
The validator (`polylane-taste-pixels.sh` L295–L314) re-runs the adapter, and
requires the exact keys `adapter_receipt, decoded_height, decoded_pixel_sha256,
decoded_width, distinct_pixel_values, non_background_pixel_count,
pixel_payload_bytes, schema_version`, plus a nested `taste-adapter-receipt/v1`
whose `command_sha256`/`input_sha256`/`output_sha256`/`executed_at` are bound to
the decoder command, PNG bytes, decoded pixels, and freshness window.

Real decode of an 8×8 fixture (`input_sha256` = PNG SHA, `output_sha256` =
`decoded_pixel_sha256`, `command_sha256` = adapter file SHA):

```json
{
  "adapter_receipt": {
    "adapter_id": "png-decoder",
    "adapter_version": "png-decode/1.0.0+ffmpeg-8.1.1",
    "command_sha256": "037bcdbffe0648925a646212bd1a5d5c10ce51aee5d239e13718372ec6816945",
    "executed_at": "2026-08-12T00:00:00Z",
    "exit_status": 0,
    "input_sha256": ["6d8a7d9af34e76480cf7e1d1278dc002e361fbd3427e7aec36989bda3d80422d"],
    "output_sha256": ["eaeb779142e5ca0699394a6b1789cfa39593af7cd6fb80d38d88baae883938ad"],
    "schema_version": "taste-adapter-receipt/v1"
  },
  "decoded_height": 8,
  "decoded_width": 8,
  "decoded_pixel_sha256": "eaeb779142e5ca0699394a6b1789cfa39593af7cd6fb80d38d88baae883938ad",
  "pixel_payload_bytes": 256,
  "distinct_pixel_values": 64,
  "non_background_pixel_count": 64,
  "schema_version": "taste-png-decoder/v1"
}
```

`pixel_payload_bytes = 256 = 8·8·4` (RGBA). The adapter trusts **no
caller-supplied dimension or hash** — its only input is a path; width/height
come from the PNG IHDR, and the decoded byte count must equal `w·h·4` exactly or
the decode is rejected (`PAYLOAD_SIZE_MISMATCH`).

---

## 3. Fixture generation provenance

Every fixture is generated in-repo (`tests/test-taste-decode-live.sh`,
`gen_*`/`gen_corrupt` PY blocks) — nothing downloaded, no caller bytes:

| Fixture | Colortype / flag | Purpose |
|---|---|---|
| `gen_rgb` | 2 (truecolor) | valid RGBA decode, dimensions, diagnostics |
| `gen_rgba` | 6 (truecolor+alpha) | alpha channel present in `w·h·4` payload |
| `gen_palette` | 3 (indexed) | palette expanded to RGBA by ffmpeg |
| `gen_interlace` | 2, interlace=1 (Adam7) | de-interlaced to RGBA by ffmpeg |
| `gen_corrupt nonpng` | — | non-PNG bytes |
| `gen_corrupt header-only` | signature+IHDR only | no IDAT/IEND |
| `gen_corrupt truncation` | good PNG minus tail | truncated stream |
| `gen_corrupt bad-crc` | flipped IDAT body byte | chunk CRC mismatch |
| `gen_corrupt decompression-failure` | valid-CRC garbage IDAT | broken deflate |
| `gen_corrupt oversized` | IHDR 100000×100000, tiny file | dimension bomb |

The live matrix uses `gen_rgb` at exactly `1440×900` (desktop) and `390×844`
(mobile) with four distinct seeds, matching the validator's viewport gate.

---

## 4. Deterministic replay

Identical bytes + identical `TASTE_NOW` → byte-identical receipt. Proven two
ways: ffmpeg `rawvideo` output is byte-stable across runs (verified: same SHA
twice), and the test asserts `decode(NOW,png) == decode(NOW,png)`
(`decode-live-deterministic`) and `wrapper selftest` re-decodes and compares
(`SELFTEST_NONDETERMINISTIC` guard). `executed_at` is pinned from `TASTE_NOW`
so the coordinator's run time replays exactly; `decoded_pixel_sha256` depends
only on pixels, never on the timestamp.

---

## 5. Corruption / abuse attacks — all fail closed

Integrity is enforced *before* ffmpeg: the adapter parses the container,
verifies **every chunk CRC**, and bounded-decompresses the deflate stream, then
caps dimensions/bytes before any allocation. ffmpeg's own PNG CRC leniency is
therefore irrelevant.

| Attack | Adapter reason | Test assertion | Result |
|---|---|---|---|
| non-PNG bytes | `BAD_SIGNATURE` | `decode-live-rejects-nonpng` | reject |
| header-only | `BAD_STRUCTURE`/`NO_PIXEL_DATA` | `decode-live-rejects-header-only` | reject |
| truncation | `TRUNCATED_CHUNK`/`INCOMPLETE_DEFLATE_STREAM` | `decode-live-rejects-truncation` | reject |
| bad CRC | `BAD_CRC` | `decode-live-rejects-bad-crc` | reject |
| decompression failure | `DECOMPRESSION_FAILURE` | `decode-live-rejects-decompression-failure` | reject |
| oversized dimensions | `OVERSIZED_DIMENSIONS` (pre-decode cap) | `decode-live-rejects-oversized` | reject, no alloc |
| symlinked evidence | `SYMLINK_INPUT` | `decode-live-rejects-symlink` | reject |
| forged decoded digest | validator `DECODED_HASH_MISMATCH` | `decode-live-rejects-digest-drift` | reject |
| duplicate render | validator `DUPLICATE_RENDER` | `decode-live-rejects-duplicate-render` | reject |

Caps: `MAX_DIM=8192`, `MAX_BYTES=128 MiB`, applied to the on-disk file size, the
IHDR dimensions (`w·h·4`), and the bounded deflate output — dwarfing every real
capture (1440×900 = 5.2 MiB) while bounding the worst-case allocation and the
O(pixels) distinct-value set.

---

## 6. Live pixel-validator consumption (decisive)

`tests/test-taste-decode-live.sh` §6 builds a real git-rooted project, copies
the adapter to `tools/png-decode.sh`, generates the four real captures, decodes
them with the live adapter to fill the manifest, and runs the **frozen**
`polylane-taste-pixels.sh verify`:

- `decode-live-pixels-verify-accepts-real-matrix` → rc 0
- `decode-live-pixels-verify-print` → `TASTE-PIXELS: VERIFIED captures=4`
- `decode-live-pixels-receipt-schema` → `taste-pixels-receipt/v1`
- `decode-live-pixels-binds-decoder-command` → receipt `inputs.decoder_command_sha256` = adapter SHA

## 7. Gates

- `bash tests/test-taste-decode-live.sh` → **36 pass, 0 fail** (red-first: 26
  fail before the adapter/wrapper existed).
- `shellcheck -S warning` on all three owned scripts → clean (rc 0).
- Both run through `bin/polylane-check.sh "$PWD/.polylane/check-cache/decode-live"`.

---

## Skill receipts

- SKILL-READ: caveman:surgical-patch | /Users/leonardo/.codex/plugins/cache/caveman/caveman/local/skills/surgical-patch/SKILL.md | 3430237396-664
- SKILL-READ: engineering:code-review | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/code-review/SKILL.md | 936987158-4285

- SKILL-EVIDENCE: caveman:surgical-patch — helped: kept the change to two new
  narrow tools plus one test at the responsible layer (the declared decoder
  seam), added only task-relevant regression proof, and touched no forbidden
  path or existing module.
- SKILL-EVIDENCE: engineering:code-review — helped: its correctness/security
  lens drove the adversarial matrix (malformed PNG, dimension/payload bounds,
  digest drift) and caught the pre-read file-size gap — a whole-file
  `open().read()` before the dimension cap — fixed by an on-disk `OVERSIZED_FILE`
  cap before allocation.
