# Judge calibration verification

`bin/polylane-taste-calibrate.sh INPUT.json RECEIPT.json` recomputes one
judge's eligibility from raw, held-out mirrored prompt/brief ballot units. It
does not accept an `eligible`, `eligibility`, or `eligibility_receipt` claim
in its input.

## Commands

```bash
bin/polylane-check.sh "$PWD/.polylane/check-cache/judge-calibration" -- tests/test-taste-calibrate.sh
shellcheck -S warning bin/polylane-taste-calibrate.sh tests/test-taste-calibrate.sh
```

The focused test creates 24 unique prompt/brief units, invokes the real
compiler, and checks the emitted receipt rather than script text.

## Eligibility contract

The atomic receipt is written as a same-directory temporary file and renamed
only after complete JSON generation. It uses `schema_version:
"taste-calibration/v1"`, a computed `result`, and the fields required by the
certificate consumer:

- `human_labelled_pairs >= 24`, `correct >= 17`, and `wilson_lcb_95 >= 0.50`;
- `side_probe_n >= 12` and two-sided exact binomial
  `side_probe_exact_binomial_p >= 0.05`;
- `mirror_probe_n >= 8` and `mirror_contradictions < 2`;
- `judge_configuration.kind`, provider, and model, plus the matching `judge`
  identity.

Every ballot identity must exactly equal the top-level provider/model. A
vote must be a JSON number whose integral value is 0, 1, or 2; strings such as
`"1"` are rejected. An abstention is valid only when both sides abstain and
both supply a nonempty reason. Non-abstaining mirrors must be checked by the
mirror probe, so weak or side-biased judges cannot vote.

The judge-visible request must be exactly `{prompt, brief}` and match the
unit's prompt/brief values. Consequently the human `gold_vote` cannot be
passed through that request. Inputs also require `held_out` partition and
`human-labeled` provenance. These are compiler checks; they do not turn an
untrusted fixture into evidence of a real panel.

## Threshold edges

Using the 95% Wilson lower bound with `z = 1.959963984540054`:

| Correct / held-out units | Wilson lower bound | Outcome |
| --- | ---: | --- |
| 16 / 24 | 0.467063 | fail |
| 17 / 24 | 0.508323 | pass, subject to the independent probes |

The suite also rejects identity drift, an undocumented abstention, label
leakage in the judge request, self-attested eligibility, numeric strings,
two mirror contradictions, and a statistically significant side-biased
judge. It accepts a paired, documented abstention but does not count it as
correct.

## Skill receipts

SKILL-READ: data:statistical-analysis | /Users/leonardo/.codex/plugins/cache/claude-cowork/data/1.1.0/skills/statistical-analysis/SKILL.md | 91a15cfc144efffcd622b09827362a73993a3ff30e3a78114801832477c9f8a0

SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 5c5e95830754bbdd838213fa05fc8f07523f591fd558fd3c86031ffd479f7a9e

SKILL-READ: operations:risk-assessment | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md | 82e29810a762c396a56f92bbd5c5afd252f7a07c6be69a246c28f7b82c4086d9

SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md | bf1b8216e523851a411e91d429a7c1c2a173e79d88957bc78e348218d50edd54

SKILL-EVIDENCE: data:statistical-analysis — helped: Wilson threshold edges and the two-sided side-bias test are numeric, reproducible gates.

SKILL-EVIDENCE: engineering:testing-strategy — helped: focused tests cover the critical receipt path and integrity/error boundaries.

SKILL-EVIDENCE: operations:risk-assessment — helped: leakage, identity drift, and self-attestation are independently fail-closed.

SKILL-EVIDENCE: superpowers:test-driven-development — helped: the first focused command failed because the compiler was absent, then passed after the minimal implementation.

## DEFERRED

No real human-labeled panel is claimed here. The synthetic fixtures prove the
compiler only. A later integration must supply pinned, openly licensed,
human-labeled held-out pairs and live rendered blinded ballots, retain their
source evidence, and have the certificate consumer reject any absent,
malformed, or ineligible receipt.
