# Verify — benchmark-preflight (deterministic generation-wave gate)

Run: `c41-source-calibration-20260812-a1` · Lane: `benchmark-preflight`

Subject under verification:

- `bin/polylane-taste-benchmark-preflight.sh` — the one deterministic gate that
  must emit `READY` before the expensive 20-brief generation wave may start.
- `tests/test-taste-benchmark-preflight.sh` — 34 red-first assertions: one
  happy fixture world plus one attack per omitted/tampered/unavailable
  boundary.

The gate validates evidence; it never generates or improves it. It performs no
network access and no model invocation.

---

## 1. Contract

```
polylane-taste-benchmark-preflight.sh run CONFIG.json RECEIPT_OUT.json
```

Exit 0 with stdout `READY <closure_sha256>` only when **every** check below
passes; exit 1 with stdout `NOT-READY <codes>` and a `NOT-READY` receipt
otherwise; exit 2 only for argv errors. There is no partial pass: all checks
run on every invocation, all failures are coded, and `closure_sha256` is
`null` on any failure.

The receipt (`taste-benchmark-preflight/v1`) carries `run_id`, `status`,
`ready`, sorted unique `reason_codes`, observed `checks` counts (records,
cache objects/bytes, pairs, eligible panel, CLIs, free disk),
`closure_sha256`, a constant `human_certified: false`, and the tool
fingerprint.

**Closure hash**: SHA-256 over the sorted `sha256  role` lines of every
verified artifact (config, source receipts, split manifest, pair manifests,
eligible panel receipts, frozen protocol/prompt/brief files). Content-only, so
identical evidence yields an identical hash on any host; rerunning unchanged
inputs reproduces the hash bit-for-bit (asserted by the test), and any input
change moves it.

## 2. Checks and reason codes

| # | Boundary | Codes |
|---|---|---|
| 0 | closed config schema (`taste-benchmark-preflight/v1`, no unknown keys) | `CONFIG_INVALID` |
| 1 | split manifest: 180+72 records, 60/24 per each of exactly 3 domains, unique ids and image digests | `SPLIT_INVALID`, `SPLIT_QUOTA` |
| 2 | live source receipts: `taste-source-acquisition/v1`, `classification: production`, no `fixture_only`, all three frozen DOIs (`10.7910/DVN/9FKSQI`, `XOI0HI`, `Z7KLIH`) covered, `manifest_sha256` byte-bound to this exact split manifest | `SOURCE_RECEIPT_INVALID`, `SOURCE_RECEIPT_FIXTURE`, `SOURCE_DOI_MISSING`, `SOURCE_SPLIT_UNBOUND` |
| 3 | cache bytes: every manifest image present in the content-addressed cache as a regular non-symlink non-empty file whose recomputed SHA-256 equals its address (batched shasum) | `CACHE_OBJECT_INVALID`, `CACHE_DIR_MISSING` |
| 4 | pair manifests: exactly 24 pairs, unique pair ids, sides distinct, both sides holdout records with exact digests, no duplicate pair in either orientation | `PAIRS_INVALID` |
| 5 | panel: ≥5 audited eligible unique `taste-calibration/v2` machine configurations; thresholds recomputed here (units == 24, correct ≥ 17, Wilson lower bound recomputed with the calibration-live z and matched within 0.0005 and ≥ 0.50, side probe p ≥ 0.05, mirror contradictions < 2); one shared holdout corpus + label binding | `PANEL_RECEIPT_INVALID`, `PANEL_AUDIT_MISMATCH`, `PANEL_DUPLICATE_CONFIG`, `PANEL_INCOHERENT`, `PANEL_INSUFFICIENT` |
| 6 | frozen hashes: protocol/prompt/brief files byte-exact against declared SHA-256; baseline revision must equal the script constant `0b802ad13ada13a0dc7cc702a526ed17d3348851` | `FROZEN_HASH_MISMATCH`, `BASELINE_REVISION_MISMATCH` |
| 7 | declared browser/build/provider CLIs resolve via `command -v` now | `CLI_MISSING` |
| 8 | free bytes on the cache filesystem ≥ `min_free_disk_bytes` | `DISK_BUDGET` |
| 9 | no configured JSON input anywhere claims `human_certified: true`; the receipt itself is constant `human_certified: false` | `HUMAN_OVERCLAIM` |

Frozen study constants (252 = 180+72, 60/24 per domain, 24 pairs, ≥17/24,
Wilson ≥ 0.50, p ≥ 0.05, < 2 contradictions, ≥5 judges, baseline revision) are
script constants, never configurable — a config cannot weaken the gate.

## 3. Seam contract for sibling lanes

The gate consumes, by path, artifacts owned by other cycle-41 lanes:

- split manifest — `corpus-select` (`records[]` with `id`, `domain`, `split`,
  `asset_sha256`; the `polylane-taste-source.sh build` manifest shape).
- source receipts — `source-freeze`/`download-campaign`
  (`taste-source-acquisition/v1` with `classification`, `sources[].dataset_pid`,
  `manifest_sha256`).
- pair manifests — `pair-builder` (`taste-pair-manifest/v1`:
  `pairs[] = {pair_id, a: {id, asset_sha256}, b: {id, asset_sha256}}`).
- panel receipts — `calibration-campaign`/`calibration-audit`
  (`taste-calibration/v2` as emitted by `polylane-taste-calibration-live.sh`).

Field mismatches surface as the corresponding `*_INVALID` code and are
integrator seam repairs, never silent acceptance.

## 4. How to verify

```bash
bash tests/test-taste-benchmark-preflight.sh
shellcheck -S warning bin/polylane-taste-benchmark-preflight.sh
```

Expected: `PASS test-taste-benchmark-preflight assertions=34` and a clean
ShellCheck. The suite covers: the happy READY world (receipt shape, counts,
closure format), closure determinism across reruns, closure movement on
evidence change, usage rc 2, config attacks (non-JSON, unknown key), source
attacks (fixture classification, missing DOI, unbound manifest, broken JSON),
split attacks (quota, duplicate id), cache attacks (missing, tampered,
symlink), pair attacks (short, calibration leakage, unknown id, digest
mismatch), panel attacks (insufficient, duplicate configuration, four audit
mismatches, human overclaim, incoherent binding, broken JSON), frozen-hash and
baseline drift, missing CLI, disk budget, and multi-failure accumulation
(codes accumulate; closure stays `null`; never a partial pass).
