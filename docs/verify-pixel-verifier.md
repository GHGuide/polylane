# Pixel verifier verification

Run ID: `c38-taste-engine-20260811-a1`

## Scope

`bin/polylane-taste-pixels.sh verify PROJECT_ROOT CAPTURE_MANIFEST NOW_UTC`
accepts only a complete `taste-capture-manifest/v1` matrix. It requires regular
repository-relative evidence and adapter paths, the checked-out source revision,
fresh capture/browser-decoder receipt times, SHA-256 bindings, 1440×900 desktop
and 390×844 mobile pixels, and a complete route/state Cartesian matrix. The
verifier performs PNG chunk/dimension checks and invokes the manifest-declared
PNG decoder adapter. Its receipt must bind the actual adapter executable, image
digest, and decoded-pixel digest. Missing decoder evidence is a failure.

## Commands and results

```bash
bin/polylane-check.sh "$PWD/.polylane/check-cache/pixel-verifier" -- \
  bash tests/test-taste-pixels.sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/pixel-verifier" -- \
  shellcheck -S warning bin/polylane-taste-pixels.sh tests/test-taste-pixels.sh
```

Both passed. The focused test has 10 assertions: one accepted real PNG matrix,
one positive receipt assertion, and eight rejection assertions.

The accepted fixture generates four local, valid zlib-compressed RGB PNGs:
desktop/mobile × default/loading. Its declared fixture decoder fully decompresses
the PNG, verifies chunks/CRC/raw rows, derives the decoded-pixel SHA-256 and
reports 63,001 distinct RGB values. This is local fixture evidence only, not a
browser benchmark or certification claim.

## Rejection evidence

| Case | Verified rejection |
| --- | --- |
| Eight-byte PNG signature/header-only file | `PNG_STRUCTURE` |
| Symlinked screenshot | `UNSAFE_PATH` |
| `../` traversal | `UNSAFE_PATH` |
| Reused desktop pixels for another state | `DUPLICATE_RENDER` |
| CSS viewport disagrees with decoded dimensions | `VIEWPORT_MISMATCH` |
| Capture time predates the candidate source revision | `STALE_CAPTURE` |
| Valid but solid-white placeholder PNG | `SYNTHETIC_PLACEHOLDER` |
| Missing declared decoder adapter | `DECODER_UNAVAILABLE` |

The implementation also rejects an incomplete or extra route/state/viewport
matrix (`MATRIX_MISMATCH`), source revisions that are not the checked-out Git
revision (`STALE_SOURCE_REVISION`), digest mismatches, malformed receipt schemas,
adapter swaps, unsafe receipt/adapter paths, and decoder output that does not
bind the expected dimensions, payload, hashes, and execution time.

## Skill receipts

- SKILL-READ: engineering:debug | `/Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/debug/SKILL.md` | `e50bb92cbcb2715139f3a3cb9ff282a8f0f9ae794f8f35d81338654e2601d32a`
- SKILL-READ: engineering:testing-strategy | `/Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md` | `5c5e95830754bbdd838213fa05fc8f07523f591fd558fd3c86031ffd479f7a9e`
- SKILL-READ: operations:risk-assessment | `/Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md` | `82e29810a762c396a56f92bbd5c5afd252f7a07c6be69a246c28f7b82c4086d9`
- SKILL-READ: superpowers:test-driven-development | `/Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md` | `bf1b8216e523851a411e91d429a7c1c2a173e79d88957bc78e348218d50edd54`

SKILL-EVIDENCE: engineering:debug — helped: isolated the signature-only predecessor and the receipt/matrix failure codes.

SKILL-EVIDENCE: engineering:testing-strategy — helped: kept the fixture matrix positive path separate from adversarial boundary tests.

SKILL-EVIDENCE: operations:risk-assessment — helped: prioritized symlink, traversal, stale, adapter-swap, duplicate, and placeholder threats.

SKILL-EVIDENCE: superpowers:test-driven-development — helped: the first focused run failed because the verifier did not exist before minimal implementation was added.

## DEFERRED

No browser was installed or invoked, no external images were downloaded, and no
benchmark, human ballot, calibration result, or taste certificate is claimed.
Perceptual duplicate thresholds and browser-capture execution remain integration
responsibilities; this verifier blocks positive use when their declared evidence
is absent or malformed.
