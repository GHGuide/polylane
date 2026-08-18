STATUS: source-protocol DONE run=c41-source-calibration-20260812-a1

Reconciled RESEARCH.md/PROTOCOL.md with the shipped Cycle-40 harness (adapters
merged, shipped-as mapping, ballot-v2 live via bin/polylane-taste-ballot-live.sh)
and the frozen Cycle-41 acquisition design (marked not-in-tree). Added
SOURCE-AUDIT.md: canonical Harvard bytes vs DataONE immutable metadata,
observed WAF/readiness/redirect facts, verified primary citations, frozen
substitution and claim rules. No thresholds changed; no certificate claimed;
human_certified stays false. Evidence: docs/verify-source-protocol.md
(test-taste-protocol-live.sh 80 pass / 0 fail; five primary URLs verified
2026-08-13; uncertainty recorded).
