STATUS: calibration-audit DONE run=c41-source-calibration-20260812-a1

Lane: calibration-audit (repair attempt 1 — completed)

Delivered:
- bin/polylane-taste-calibration-audit.sh — independent panel calibration
  auditor (taste-calibration-audit/v1). Recomputes, per configuration, from
  raw hash-bound evidence: 24-pair correctness (gold from human holdout
  labels, votes re-parsed with the pinned parser), Wilson 95% lower bound,
  two-sided exact binomial side probe, mirror contradictions, raw-response
  closure, session uniqueness (in-ledger, per-unit mirrored, and
  cross-configuration), parser/invocation/config hash identity, holdout
  binding, and fixture/production classification. Cross-checks every emitted
  taste-calibration/v2 receipt (RECEIPT_MISMATCH / STALE_CONFIG /
  HUMAN_CLAIM). Eligibility requires every frozen gate (units>=24,
  correct>=17, Wilson>=0.50, side n>=12 p>=0.05, mirror n>=8 contra<=1).
  HUMAN_CALIBRATED_MACHINE is emitted only at panel level, only with >=5
  eligible production configurations, and the receipt is always
  human_certified:false / machine_not_human:true on every path.
- tests/test-taste-calibration-audit.sh — 21 red-first assertions:
  independent arithmetic (Wilson 17/24=0.508323, 24/24=0.862024, exact tie
  p=1.000000), boundary gates, panel floor/aggregation, duplicate and
  unbound sessions, cross-config session reuse, stale config, changed
  holdout, tampered receipt numbers, human-claim escalation, synthetic
  bindings, fixture-input ceiling, clean-JSON audit input.
- docs/verify-calibration-audit.md — repair reflection, registered gate
  table, exact formulas, claim ceiling, verification evidence, and
  SKILL-EVIDENCE receipts.

Verification:
- bash tests/test-taste-calibration-audit.sh -> PASS assertions=21 (exit 0)
- shellcheck -S warning bin/polylane-taste-calibration-audit.sh -> clean
- shellcheck -S warning tests/test-taste-calibration-audit.sh -> clean

Boundary: pure verifier; never invokes a model, never repairs evidence,
never re-runs a judge. No claim of human certification anywhere.
