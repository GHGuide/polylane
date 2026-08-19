# Cycle 45 digest — the HCM-v2 pipeline exists and is proven; the study stays external

Cycle 45 built the offline-provable half of m32.8: the pipeline that would run
the HCM-v2 human calibration study, bound to the frozen numbers in the contract
lock, with fixtures and synthetic data standing in for machinery — never for a
human.

Three lanes, disjoint ownership, all test-driven:

| lane | delivered | proving tests |
|---|---|---|
| `hcm-corpus` | `bin/polylane-taste-study.sh` now binds the frozen split (320 natural pairs = 120 development + 40 validation + 160 confirmatory, 32 anchors excluded) against `split_sha256`, plus exposure caps (≤8 natural pairs and ≤2 anchors per participant, 0 repeat exposures), both viewports, and designer/target-user ballot separation | `test-hcm-v2-split.sh`, `test-hcm-v2-exposure.sh` |
| `hcm-privacy` | new `bin/polylane-taste-consent.sh`: PII-free consent records, holdout labels unreachable from every participant-facing artifact, and `TASTE-CERTIFIED`/`HUMAN_CERTIFIED`/`human_certified: true` provably unreachable from any code path | `test-hcm-v2-privacy.sh`, `test-hcm-v2-claim-safety.sh` |
| `hcm-stats` | new `bin/polylane-taste-qualify.sh`: Brier skill, Wilson bounds, 10,000-replicate bootstrap CAPA, Holm correction, position bias (480 calls / 240 mirrored pairs / ≤6 reversals) and equivalence bias (300 probes, acceptance [135,165]), every gate tested at its exact boundary value | `test-hcm-v2-analysis.sh`, `test-hcm-v2-qualification.sh` |

Outcome `EXTERNAL-EVIDENCE-OPEN`, rc 0, **zero coordinator interventions** — the
first fully hands-off cycle since the harness fixes landed. All seven frozen
m32.8 accepts, six focused plus the terminal host gate, then passed fresh on the
promoted tree; only then did m32.8 close. Suite: 4340 passing.

The evidence worth keeping: the integrator's verification carries a 62-row table
binding every frozen parameter to its lock value, enforcing lane and proving
test, and the external boundary was *demonstrated* rather than asserted — an
attempt to bypass the frozen `split_sha256` gate returns rc 1, and the privacy
lane emits all 14 governance requirements as open external dependencies instead
of quietly treating them as satisfied.

**Still external (m32.8a):** ethics and privacy review, recruiting and
compensating 3,200 target users and 96 credentialed designers, collecting sealed
ballots, and qualifying the machine panel against them. None of it was
simulated; synthetic data existed only to test the maths.

Next: m32.9 — the 12-brief smoke, the 192-brief adaptive prompt-development
bank, and one 300-brief one-bit sealed promotion test before every prompt and
policy freezes. Note this one consumes real provider calls at scale, so its
cost and budget should be settled before launch.
