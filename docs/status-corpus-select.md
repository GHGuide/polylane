STATUS: corpus-select DONE run=c41-source-calibration-20260812-a1

- Delivered `bin/polylane-taste-corpus-select.sh` (`select`/`verify`): deterministic
  60 calibration + 24 holdout per frozen domain (180+72 total), seeded rank by
  `sha256(seed|id|image_sha256)`, frozen support (`>=5`) and ambiguity (`sd<=1.5`)
  filters, fail-closed input validation, stage-then-move publication.
- Receipt binds seed, source revision, source-manifest and ratings SHA-256, filters,
  per-domain counts, and the manifest SHA-256; manifest and receipt are separate,
  timestamp-free, byte-stable files.
- Leakage/duplicates rejected at intake (duplicate ids, duplicate or cross-domain
  digests, unknown domains); splits provably disjoint by id and digest.
- Quota shortfall is `CORPUS-SELECT-UNAVAILABLE` naming the domain, with no
  rebalancing and no partial output. `verify` re-derives both outputs from bound
  inputs and byte-compares: any edit, digest swap, or input replacement is
  `CORPUS-SELECT-REPLACED`.
- Verification: `bash tests/test-taste-corpus-select.sh` → PASS (29 assertions,
  hermetic fixtures, RED observed before implementation);
  `shellcheck -S warning` clean on both scripts.
- Evidence: docs/verify-corpus-select.md (repair reflection, contract, skill receipts
  and SKILL-EVIDENCE lines). Relay and inbox checked at start and before completion:
  empty both times.
