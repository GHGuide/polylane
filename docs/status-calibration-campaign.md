STATUS: calibration-campaign DONE run=c41-source-calibration-20260812-a1

Lane: calibration-campaign (repair attempt 1 → DONE)

Delivered:
- bin/polylane-taste-calibration-campaign.sh — production calibration campaign
  controller over the Cycle 40 isolated judge runner and frozen
  taste-judge-workunit/v1 manifests. Enforces pointwise-before-pairwise (also
  across resumes), unique isolated sessions, blind candidate/provider/model
  identity, primary/mirror pairs with flipped orientations in distinct
  sessions, provider pinning by adapter fingerprint, bounded single infra
  retry with abstention as substantive, append-only hash-chained ledger
  binding manifest/adapter/raw-response/invocation hashes, idempotent
  partial resume, and no shared ballot channel. Executes configurations
  only; never decides eligibility (summary carries decides_eligibility:false).
- tests/test-taste-calibration-campaign.sh — 47 hermetic fake-provider
  assertions: order, isolation, duplicate session, retry class, timeout,
  malformed output, leak, partial resume, abstention, ledger tamper.
- docs/verify-calibration-campaign.md — repair reflection, verification
  evidence, SKILL-READ receipts, SKILL-EVIDENCE observations.

Verification:
- bash tests/test-taste-calibration-campaign.sh → 47 pass, 0 fail
- shellcheck -S warning bin/polylane-taste-calibration-campaign.sh → clean

External evidence: builder used fake providers only; real model calls are
owned by the integrator through this frozen controller.
