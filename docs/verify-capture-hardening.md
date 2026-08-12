# Verify — capture-hardening (Cycle 39, run c39-visual-loop-20260812-a1)

Lane goal: production visual evidence comes from **pinned browser/decoder
identities, complete replayable state matrices, independently decoded pixels,
and tamper-evident receipts** — never from an arbitrary project adapter that
merely claims to be trusted.

Owned files (only these were changed):
`bin/polylane-visual-capture.sh`, `tests/test-visual-capture.sh`,
`docs/verify-capture-hardening.md`, `docs/status-capture-hardening.md`.

## Commands + outputs

```
$ bash tests/test-visual-capture.sh
test-visual-capture.sh: 35 pass, 0 fail
$ shellcheck -S warning bin/polylane-visual-capture.sh
SHELLCHECK-CLEAN
$ git diff --check
DIFF-CHECK-CLEAN
```

Full assertion list (35 PASS):

```
capture-missing-adapter-fails-closed                    capture-rejects-ihdr-only-png
capture-hermetic-adapter-completes-matrix               capture-rejects-text-masquerading-as-png
capture-has-four-locked-viewport-state-entries          capture-rejects-screenshot-rgba-mismatch
capture-records-source-revision                         capture-rejects-metadata-distinct-duplicate
capture-records-native-desktop-dimensions               capture-rejects-one-pixel-near-duplicate
capture-records-native-mobile-dimensions                capture-rejects-decoder-sha-drift
capture-emits-per-entry-and-aggregate-receipts          capture-rejects-future-adapter-output
capture-manifest-hashes-are-real                        capture-rejects-stale-adapter-output
capture-manifest-locates-each-screenshot                capture-rejects-failed-navigation
capture-emits-pixel-verifier-manifest-fields            capture-rejects-wrong-receipted-dimensions
capture-marks-fixture-authorization                     capture-rejects-fabricated-artifact-receipt
capture-browser-receipt-chains-brief-and-locks          capture-rejects-aliased-artifact-receipt
capture-output-passes-independent-pixel-verifier        capture-rejects-symlinked-plan
capture-authorized-production-completes-full-state-matrix  capture-rejects-symlinked-output
capture-authorized-production-is-allowlist-bound        capture-rejects-partial-declared-matrix
capture-blocks-production-without-allowlist             capture-atomic-failure-preserves-existing-output
capture-blocks-arbitrary-adapter
capture-blocks-source-revision-drift
capture-blocks-production-missing-required-state
```

TDD ledger: 9 assertions were written first and observed **RED** against the
pre-hardening producer (`marks-fixture-authorization`,
`browser-receipt-chains-brief-and-locks`, `rejects-screenshot-rgba-mismatch`,
`rejects-metadata-distinct-duplicate`, `rejects-one-pixel-near-duplicate`,
`rejects-decoder-sha-drift`, `rejects-future-adapter-output`,
`authorized-production-completes-full-state-matrix`,
`authorized-production-is-allowlist-bound`), then driven to **GREEN**.

## Trust boundary

A caller cannot self-promote: `fixture_only:false` without a matching
coordinator allowlist entry **BLOCKS** (exit 2). It never falls back to the
fixture path or to exact-hash-only comparison.

| Identity element | Source | Fixture (`fixture_only:true`/absent) | Production (`fixture_only:false`) |
|---|---|---|---|
| Canonical adapter path | `realpath` of the `--` executable | resolved, must be regular non-symlink executable | must equal an allowlist `adapter_path` |
| Adapter version | `plan.browser.adapter_version` | recorded | must equal allowlist `adapter_version` |
| Adapter command SHA-256 | `sha256(adapter)` | recorded | must equal allowlist `command_sha256` |
| Browser profile SHA-256 | `plan.browser.profile_sha256` | recorded | must equal allowlist `profile_sha256` |
| Decoder identity/hash | `plan.decoder.command_path` + on-disk `sha256` | pinned: on-disk sha must equal declared | pinned **and** must equal allowlist `decoder_command_sha256` |
| Environment | `plan.environment` (locale/timezone/color/scale) | recorded | must equal allowlist `environment` |
| Source revision | `candidate.source_revision` | recorded | must equal allowlist `source_revision` |
| Rendered state lock | `plan.states` | any declared states | must ⊇ `default,empty,loading,error,hover,focus` **and** carry ≥1 real-flow state |
| Allowlist source | — | none (`allowlist_entry_sha256:null`) | env `POLYLANE_CAPTURE_ALLOWLIST`, `taste-capture-allowlist/v1`; `allowlist_entry_sha256` = SHA-256 of the matched entry |

Authorization is published as `authorization.json`
(`taste-capture-authorization/v1`) alongside the manifest; the capture-manifest
consumed by the pixel/a11y/stimulus lanes is **byte-compatible with the prior
schema** (no new keys), so those consumers are unaffected.

## Artifact chain (per capture and aggregate)

Every screenshot is bound to independently decoded pixels before it is trusted:

```
candidate.source_revision ─┐
brief_sha256, design_lock_sha256 ─┤
plan(browser.profile, decoder.command_sha256, environment) ─┤        input_sha256[]
candidate_sha, plan_sha ─┤  ──► adapter-receipts/<cap>.json ─────────►│
request-<cap>.json (route,state,viewport) ─┘                          │
                                                                      ▼
adapter render ─► screenshot.png ──(png_structure: sig+IHDR+IDAT≥64+IEND)──► decoded_width×height
                     │                                                       ║ pinned decoder(screenshot)
                     ├─► pixels.rgba ──(size == w*h*4)                        ║ decoded_pixel_sha256
                     │        ▲──────────── must equal ─────────────────────╝  == sha256(pixels.rgba)
                     ├─► dom.html
                     └─► action-trace.json (route/state, actions[])
```

- Per-capture receipt `input_sha256` chains: candidate, brief, design lock,
  plan, decoder, profile, source revision, request. `output_sha256` chains:
  screenshot, pixels, DOM, action-trace, result.
- Aggregate `adapter-receipts/browser.json` chains the same identity inputs and
  every capture's screenshot/pixel/DOM/action SHA in `output_sha256` (keeping
  the pixel-lane's per-screenshot binding intact).
- Atomic publish: staged in a sibling temp dir; existing output moved aside and
  restored on any failure (trap on `EXIT/HUP/INT/TERM`).

The published tree is re-verified end-to-end by the independent pixel consumer
`bin/polylane-taste-pixels.sh` (asserted green:
`TASTE-PIXELS: VERIFIED captures=4`).

## Attack matrix

| Attack | Gate | Test |
|---|---|---|
| Arbitrary adapter posing as production | allowlist path/sha/version match required | `capture-blocks-arbitrary-adapter` |
| Caller flips `fixture_only:false` w/o allowlist | env+file required, block (no fallback) | `capture-blocks-production-without-allowlist` |
| Malicious/changed decoder | on-disk decoder sha ≠ pinned → block | `capture-rejects-decoder-sha-drift` |
| Malicious/changed browser | command SHA in receipt + allowlist match | `capture-blocks-arbitrary-adapter` |
| Text masquerading as PNG | full `png_structure` walk | `capture-rejects-text-masquerading-as-png` |
| IHDR-only / magic-header PNG | IDAT≥64 + IEND-at-EOF required | `capture-rejects-ihdr-only-png` |
| Screenshot/RGBA mismatch | decoder(screenshot) sha == declared pixels sha | `capture-rejects-screenshot-rgba-mismatch` |
| Metadata-only duplicate | decoded-pixel SHA uniqueness | `capture-rejects-metadata-distinct-duplicate` |
| One-pixel near-duplicate | frozen ≥5 differing bytes (>1 RGBA pixel) | `capture-rejects-one-pixel-near-duplicate` |
| Matrix / state omission | Cartesian completeness + prod required-states | `capture-rejects-partial-declared-matrix`, `capture-blocks-production-missing-required-state` |
| Stale output | captured_at ≥ candidate.created_at | `capture-rejects-stale-adapter-output` |
| Future output | captured_at ≤ now | `capture-rejects-future-adapter-output` |
| Source/lock drift | allowlist source_revision + chained brief/design SHAs | `capture-blocks-source-revision-drift`, `capture-browser-receipt-chains-brief-and-locks` |
| Symlink / traversal | non-symlink regular files, single-seg artifact refs | `capture-rejects-symlinked-plan`, `capture-rejects-symlinked-output`, `capture-rejects-aliased-artifact-receipt` |
| Fabricated receipt (alias screenshot→json) | screenshot must decode as PNG | `capture-rejects-fabricated-artifact-receipt` |
| Wrong receipted dimensions | result viewport == request == PNG == decoder | `capture-rejects-wrong-receipted-dimensions` |
| Failed navigation dressed as pass | `navigation_status=="ok"` required | `capture-rejects-failed-navigation` |
| Partial refresh on failure | atomic staging + rollback | `capture-atomic-failure-preserves-existing-output` |
| Positive real native-sized flow | full matrix → independent pixel consumer | `capture-output-passes-independent-pixel-verifier`, `capture-authorized-production-*` |

## Risk register (residual)

| Risk | Likelihood | Impact | Mitigation / status |
|---|---|---|---|
| Fixture decoder is a hermetic stand-in, not a real PNG decompressor | Medium | Medium | Contract: production decoder is a pinned, hash-bound adapter; fixture proves the binding/plumbing only. `EXTERNAL-EVIDENCE` forbids a real browser/decoder in this cycle. Open (later benchmark). |
| Near-dup threshold frozen at >1 pixel (≥5 bytes) | Low | Low | Targets exact one-pixel evasion per contract; larger perceptual deltas are the pixel/tournament lanes' concern. Frozen constant `NEAR_DUP_MIN_BYTES`. Accepted. |
| Certificate lane not yet binding `authorization.json` | Medium | Low | Relayed to certificate-v2 (seq20). See DEFERRED. |

## Skill receipts

```
SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.claude/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md | bf1b8216e523851a411e91d429a7c1c2a173e79d88957bc78e348218d50edd54
SKILL-READ: engineering:debug | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/debug/SKILL.md | e50bb92cbcb2715139f3a3cb9ff282a8f0f9ae794f8f35d81338654e2601d32a
SKILL-READ: operations:risk-assessment | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md | 82e29810a762c396a56f92bbd5c5afd252f7a07c6be69a246c28f7b82c4086d9
SKILL-READ: engineering:system-design | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/system-design/SKILL.md | 8f28eca99f2208872fc2483fcc93326b628f4f73116e91309a95e05da86a0ab5
```

SKILL-EVIDENCE: superpowers:test-driven-development — helped: wrote 9 attack
assertions first and confirmed RED against the un-hardened producer before any
implementation; the production-block RED assertions are exactly what exposed the
`jq '//'`-on-`false` downgrade bug (below) rather than shipping it silently.

SKILL-EVIDENCE: engineering:debug — helped: applied reproduce→isolate→diagnose
to the first GREEN run's timeout+FAIL. Isolated it by streaming output to a file,
then benchmarked `sips` (~56 ms) and the near-dup `cmp|head` (~9 ms) to rule out
performance, which pinned the true root cause: `.fixture_only // true` returns
`true` when the value is boolean `false` (jq treats `false` as empty for `//`),
so every production plan was silently downgraded to fixture. Fix: explicit
`if has("fixture_only") then .fixture_only else true end`.

SKILL-EVIDENCE: operations:risk-assessment — helped: the likelihood/impact matrix
shaped the attack-matrix ordering and the residual risk register, and made the
"fixture decoder is a stand-in" ceiling explicit rather than implied.

SKILL-EVIDENCE: engineering:system-design — helped: the fixed-consumer analysis
(pixel-lane `manifest_shape` demands an exact key set) drove the decision to put
all new trust evidence in a separate additive `authorization.json` and to enrich
`input_sha256` arrays (index-checked, not exact-array) instead of mutating the
shared manifest schema — preserving a clean adapter boundary for four consumer
lanes.

## DEFERRED

DEFERRED: certificate-v2 binding of the new `publish/authorization.json`
(`taste-capture-authorization/v1`) remains a consumer seam. The producer emits
and hash-binds it; whether promotion gates on `fixture_only:false` +
`allowlist_entry_sha256` is the certificate lane's decision. Relayed to
certificate-v2 (coordination seq20); awaiting confirm/counter. No producer change
is pending — the capture-manifest interface is unchanged, so this seam does not
block the pixel/a11y/stimulus consumers.
