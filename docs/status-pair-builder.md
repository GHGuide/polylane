STATUS: pair-builder DONE run=c41-source-calibration-20260812-a1

## Delivered

- `bin/polylane-taste-pairs.sh` — deterministic held-out mirrored calibration
  pair compiler: `build INPUT.json SEED OUTDIR` + structural `verify OUTDIR`.
- `tests/test-taste-pair-builder.sh` — 46 hermetic assertions in the mandated
  cadence (ambiguity, leakage, pair reuse, cross-domain, side imbalance,
  answer exposure, determinism, quotas), plus input validation, receipt
  bindings, and tamper detection.
- `docs/verify-pair-builder.md` — contract, verification steps, risk register,
  skill receipts.

## Frozen contract enforced

Exactly 24 mirrored same-domain pairs from held-out items only; unique source
images; delta ≥ 1.00 on the native human scale; seeded 1000-resample 95%
bootstrap interval of the mean difference excluding zero; balanced 12/12
gold-left/gold-right sides; side_probe_n=24 (≥ 12) and mirror_probe_n=24 (≥ 8);
side assignment and answer key sealed in two separate hash-bound files; the
judge-visible manifest carries only opaque stimulus ids and asset digests with
a fail-closed judge/provider-identity gate; `human_certified:false` throughout.
The compiler never invokes or scores a judge (EXTERNAL-EVIDENCE respected).

## Verification observed

- `bash tests/test-taste-pair-builder.sh` → `46 pass, 0 fail`.
- `shellcheck -S warning bin/polylane-taste-pairs.sh` → clean (test file too).
- Determinism: same input + seed rebuilds byte-identical artifacts; different
  seed diverges.

## Seams for the integrator

- Input `taste-pair-input/v1` binds `corpus_receipt_sha256`; wire the
  corpus-select lane's held-out selection (72 items, 24/domain) into it.
- Ship only `pair-manifest.json` to judge harnesses; `*.sealed.json` stay with
  calibration-audit.

## Skill evidence

- SKILL-EVIDENCE: superpowers:test-driven-development — helped: tests written
  first and observed failing (rc 127 sweep, then a real `awk -v` defect caught
  before any green claim).
- SKILL-EVIDENCE: engineering:testing-strategy — helped: shaped the pyramid
  (many unit-level contract assertions, one full build/verify integration
  path, no E2E judge dependency).
- SKILL-EVIDENCE: engineering:debug — helped: reproduce-isolate-fix loop on
  the build failure (isolated `awk: invalid -v option argument: n` with a
  minimal fixture before patching).
- SKILL-EVIDENCE: operations:risk-assessment — helped: produced the residual
  risk register in docs/verify-pair-builder.md (integrator seam, jq float
  portability, sealed-file handling).
