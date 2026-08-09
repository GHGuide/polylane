# Skill contracts verification — Cycle 17

Run: `c17-recovery-cert-20260809-a1`

## Red evidence

`bash tests/test-skill-delivery.sh` initially reported 20 passing assertions and
6 failures. The failing fixture created a recommendation with only an id, path,
source, fingerprint, and reason. It contained neither benchmark admission fields
nor receipts, so it was an obsolete benchmark-free fixture rather than valid
Cycle 17 delivery evidence.

Source review found a real contract seam as well: `arm-recommendation` checked
the recommendation's claimed `status` and `safe_to_apply` fields, but did not
re-run the public benchmark gate. A forged or later-invalid recommendation could
therefore look armed even without current ledger evidence.

## Repair

- Catalog recommendations now carry the computed domain and lane shape alongside
  their benchmark result.
- `arm-recommendation` re-resolves the trusted skill, then invokes
  `polylane-skill-benchmark.sh gate` against the configured
  `POLYLANE_SKILL_BENCHMARK_LEDGER`. It persists a selection only when that real
  gate returns `recommended` and `safe_to_apply` for the current fingerprint,
  domain, and lane shape.
- The delivery fixture records deterministic synthetic receipts exclusively through
  the public `record` CLI before trying to arm the recommendation.

## Green evidence

- `bash tests/test-skill-delivery.sh`: 31 pass, 0 fail (via the lane check cache).
- `bash tests/test-learning-economy.sh`: 57 pass, 0 fail; includes benchmark
  fingerprint and catalog admission coverage.
- `bash tests/test-cycle-16-contract.sh`: 29 pass, 0 fail; includes the scout
  rejection of an unbenchmarked candidate.
- `bash tests/test-cycle-14-contract.sh`: cached PASS after the focused repair.
- `shellcheck -S warning bin/polylane-scout.sh bin/polylane-skill-benchmark.sh bin/polylane-skill-catalog.sh`: PASS.
- `git diff --check`: PASS.

## Adversarial admission cases

- Two accepted GO hard-pass receipts are thin evidence and cannot arm a candidate.
- Three receipts for the old fingerprint do not arm the current changed fingerprint;
  the real gate marks the new candidate unsafe because no exact receipt set exists.
- An absent benchmark ledger cannot arm a recommendation.
- Existing delivery checks still reject missing, unreadable, and out-of-trusted-root
  selected skill paths.

SKILL-EVIDENCE: superpowers:test-driven-development — unused: no exact local kit path was exposed for this lane; the red-first fixture workflow was applied directly.
SKILL-EVIDENCE: engineering:code-review — unused: no exact local kit path was exposed for this lane; the admission boundary was reviewed against forged status, thin receipts, and stale fingerprints directly.
SKILL-EVIDENCE: operations:risk-assessment — unused: no exact local kit path was exposed for this lane; risk review identified the stale benchmark-status trust seam and its ledger revalidation control.
