# Cycle 45 plan — the HCM-v2 pipeline, offline-provable half (m32.8)

RUN_ID: `c45-hcm-pipeline-20260819-a1` · target: `m32.8` · authority: the frozen
`source_calibration.hcm_v2` and `source_calibration.judge_qualification_thresholds`
blocks of `docs/polylane/taste-certification/contracts/CONTRACT-LOCK.v3.json`.

## The split this cycle depends on

m32.8 is implementable offline; its sibling **m32.8a is `external`** — ethics
review, recruiting 3,200 target users and 96 credentialed designers, and
collecting sealed ballots all need humans and money. The lock says so itself:
`governance_requirements_are_external: true`, `authority: EXTERNAL_TARGET_MATCHED`,
`status: EXTERNAL-EVIDENCE-OPEN`.

So this cycle builds and proves **the pipeline that would run that study**, with
fixtures and synthetic data. It must never simulate a human result, and the
registry's `prohibited_outputs` (`TASTE-CERTIFIED`, `HUMAN_CERTIFIED`,
`human_certified: true`) stay unreachable.

`bin/polylane-taste-study.sh` exists (freeze/compile) but encodes none of the
HCM-v2 frozen numbers — that is the gap.

## Lanes (disjoint ownership)

| lane | scope | frozen numbers it binds | owns |
|---|---|---|---|
| `hcm-corpus` | frozen target-matched split + stimulus exposure rules | 320 natural pairs = 120 development / 40 validation / 160 confirmatory; 32 anchors excluded; `split_sha256 = 5f24bec2…`; viewports 1440x900 and 390x844; ≤8 natural pairs and ≤2 anchors per participant; `pair_repeat_exposures: 0`; ≤40 pairs per designer; designer ballots separate from target-user ballots | `bin/polylane-taste-study.sh`, `tests/test-hcm-v2-split.sh`, `tests/test-hcm-v2-exposure.sh` |
| `hcm-privacy` | consent record, privacy boundary, claim safety | no holdout label reachable from any participant-facing artifact; no PII in emitted records; `human_certified` cannot become true; no prohibited status or label can be emitted | `bin/polylane-taste-consent.sh` (new), `tests/test-hcm-v2-privacy.sh`, `tests/test-hcm-v2-claim-safety.sh` |
| `hcm-stats` | analysis + judge qualification maths | Brier skill lower-95 > 0; calibration-in-large ≤0.05/class; weighted calibration error ≤0.08 (upper-95 ≤0.12); coverage ≥0.80; repeat stability ≥0.95; orientation effect ≤0.05; designer macro ≥0.70, stratum ≥0.60, Wilson lower-95 >0.60, both-mirror-correct ≥84 of 120 decisive; CAPA lower-95 ≥0.75 over 10,000 bootstrap replicates, Holm p ≤0.01, double-fault independence ×2; position bias 480 calls / 240 mirrored pairs / ≤6 reversals; equivalence bias 300 probes, acceptance [135,165] | `bin/polylane-taste-qualify.sh` (new), `tests/test-hcm-v2-analysis.sh`, `tests/test-hcm-v2-qualification.sh` |

Frozen cross-lane contract: no lane edits the contract JSON or v3 schemas, and
no lane flips a defect status. Every threshold is read from the lock at runtime
where practical, never re-typed as a magic number without a test that fails if
the lock changes.

## Integrator

Merges the three lanes, checks the pipeline composes end to end on fixtures,
runs the frozen m32.8 focused acceptance, then `READY-FOR-HOST-GATE`. Rejects
any lane that simulates a human outcome, weakens a frozen threshold, or makes a
prohibited claim reachable.
