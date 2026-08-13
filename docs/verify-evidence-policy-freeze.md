# Verify — evidence-policy-freeze

Run: `c42a-taste-contracts-20260813-a2`

Subgoal: `m32.6`

Evidence class: deterministic fixture-grade contract verification; no live ballots

## Outcome

The evidence-policy v3 trust engine is executable and fail closed. It validates a
typed acyclic evidence graph, exact transitive input digests, immutable canonical node
revisions, a byte-frozen producer/schema policy, source classifications, disconnected
ancestry, claim prerequisites, and least-trusted-ancestor ceilings. Statistical study
commands derive `n` and wins from independent brief records; caller counts and repeated
measurements have no authority.

The strongest reachable autonomous claim is exactly:

```json
{
  "status": "MACHINE-EVALUATED",
  "claim_label": "HUMAN_CALIBRATED_MACHINE",
  "human_calibrated": true,
  "human_certified": false,
  "taste_certified": false,
  "calibration_scope": "exactly copied from the passing private HCM-v2 study"
}
```

That result requires one trust-rooted, private, sealed, target-matched, passing HCM-v2
study and a passing final-benchmark receipt in the same connected ancestry. Public or
machine-only ancestry keeps `human_calibrated:false`; fixture ancestry is absorbing.
No v3 producer can emit `HUMAN_CERTIFIED`, and every `human_certified:true` or
`taste_certified:true` vector is rejected.

## Trust lattice

| Rank | Effective grade | Scoped ceiling | Human calibrated |
|---:|---|---|---:|
| 0 | `fixture` | `FIXTURE_ONLY` / `EVIDENCE-ONLY` | false |
| 1 | `diagnostic_public` | `DIAGNOSTIC_ONLY` / `MACHINE-EVALUATED` | false |
| 2 | `machine_only` | `MACHINE_ONLY` / `MACHINE-EVALUATED` | false |
| 3 | `private_human_calibration` | `HUMAN_CALIBRATED_MACHINE` / `MACHINE-EVALUATED` | true, exact scope required |
| 4 | `released_artifact_human_ballot` | `HUMAN_CERTIFIED` | unreachable in v3 |

Effective rank is the minimum rank of the subject and every transitive ancestor. This
makes fixture grade absorbing and prevents a higher-grade producer from laundering a
lower-grade input.

## Exact statistical vectors

All gates compare frozen JSON doubles by exact equality and derive integer counts from
records. They do not compare rounded rates.

| Contract | Frozen design | Reject boundary | Accept boundary | Denominator |
|---|---|---:|---:|---:|
| Final benchmark | `H0:p<=0.70`, one-sided `greater`, exact `alpha=0.025` | 728 wins | 729 wins | exactly 1,000 |
| Prompt promotion | `H0:p<=0.55`, one-sided `greater`, exact `alpha=0.025` | 182 wins | 183 wins | exactly 300 |

The final benchmark requires exactly 1,000 unique brief IDs and 1,000 unique family
IDs, 100 briefs in each of ten frozen categories, one-shot closure, no optimizer
access, and zero task/accessibility regression. `tie`, `abstention`,
`missing_evidence`, and `invalid_evidence` remain non-wins in the 1,000 denominator.

Prompt promotion requires 12 unique smoke briefs, 192 unique adaptive-development
briefs, then one disjoint untouched 300-brief one-bit validation. It requires equal
compute, exactly three unique paired build replicates per arm, zero repairs, no
hard-gate regression, no final-benchmark access, and a finalist frozen before labels
open. Ties, abstentions, missing evidence, and invalid candidate builds remain
non-wins. Repeated mirrors, judges, build receipts, states, viewports, or ballots never
change the brief-derived `n` in either contract.

## Verification

TDD RED was observed before implementation:

```text
FAIL: v3 evidence engine is not implemented
```

Focused GREEN through the required check-cache semantics:

```text
ok - evidence-dag-v3 (95 assertions)
CHECK-CACHE: PASS
```

ShellCheck at warning severity:

```text
CHECK-CACHE: PASS
```

Commands:

```bash
bash tests/test-evidence-dag.sh
shellcheck -S warning bin/polylane-evidence-dag.sh
```

The runtime root did not contain `bin/polylane-check.sh`; the identical source-root
wrapper was therefore used with `$PWD/.polylane/check-cache/evidence-policy-freeze`.

Assertion total: **95**.

## Threat cases exercised

- fixture laundering and public-corpus-to-HCM laundering;
- machine-only attempts to set `human_calibrated:true`;
- unknown producer, unknown producer revision, unknown schema, and schema downgrade;
- missing parent, stale parent digest, malformed output digest, stale immutable node
  revision, and stale policy digest;
- cycle, duplicate node identity, disconnected receipt, wrong declared grade, source
  classification mismatch, and missing claim prerequisite;
- private HCM-v2 that is public, unsealed, not target-matched, non-confirmatory, failed,
  wrong-protocol, or scope-laundered;
- three provider aliases collapsing to one base-model lineage;
- every tested false human/taste-certified label, status, and boolean;
- 728/1,000 versus 729/1,000 and 182/300 versus 183/300;
- denominator shrinkage, category imbalance, repeated brief IDs, and repeated families;
- ties, abstentions, missing evidence, invalid evidence/builds, task regression, and
  accessibility regression;
- repeated mirror/build/judge/ballot/state/viewport inflation;
- exact-double drift in `p0` or alpha, final-set optimizer leakage, item-level prompt
  result leakage, repairs, unequal compute, and wrong replicate count;
- lifecycle reopening or timestamp reversal;
- genericness auto-verdicts (`GENERIC`, `NON_GENERIC`, `PASS`, `FAIL`) and unqualified
  claims of sealed human qualification.

## Risk register

| Risk | Likelihood | Impact | Level | Mitigation | Owner | Status |
|---|---|---|---|---|---|---|
| Lower-grade ancestry is relabeled by a downstream producer | High | High | Critical | minimum transitive rank; fixture absorbing; adversarial laundering tests | evidence-policy v3 | Mitigated |
| Repeated measurements inflate statistical `n` | High | High | Critical | derive `n` only from unique brief/family rows; repeated arrays are non-authoritative | evidence-policy v3 | Mitigated |
| Policy or node changes occur after outcomes | Medium | High | High | byte-frozen policy SHA, canonical node revision digests, closed lifecycle order | evidence-policy v3 | Mitigated |
| Public labels are misrepresented as target-human calibration | Medium | High | High | diagnostic-public ceiling and exact HCM-v2 private/target/scope prerequisites | evidence-policy v3 | Mitigated |
| Human or taste certification is implied by machine output | Medium | High | High | no registered deciding-ballot producer; both certification booleans forced false | evidence-policy v3 | Mitigated |
| Heuristic genericness becomes an automatic taste verdict | Medium | Medium | Medium | allow only `NO_REVIEW`, `REVIEW_REQUIRED`, or `UNKNOWN` while qualification is false | evidence-policy v3 | Mitigated |
| Fixture vectors are mistaken for live evidence | Low | High | Medium | verification labels all vectors fixture-grade; live receipts explicitly deferred | operator | Open |

## Artifact hashes

SHA-256 values after focused GREEN:

```text
66164a629b76ce42de17fab8764275d6d154ffba305a657c9d327c696aa11b4a  bin/polylane-evidence-dag.sh
b90e2148bc7cd1ee36d3f7dcf2b7b23eed63b9b5f2057943bb120cbb1c6438d2  docs/polylane/taste-certification/contracts/evidence-dag-v3.schema.json
8ff293fa72cc32ae52c3bf40a82fd4e67d06a2e24b534b0a323b97bd1cc5d7ee  docs/polylane/taste-certification/contracts/evidence-policy-v3.json
d09805179ff0def2f756b2b795a99f49a0456226ceb359692369565674e706b4  tests/test-evidence-dag.sh
```

## Skill receipts

SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279

SKILL-READ: operations:risk-assessment | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md | 3889652016-1630

SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/test-driven-development/SKILL.md | 1657109997-9015

SKILL-EVIDENCE: engineering:testing-strategy — helped: separated DAG contract,
statistical boundary, lifecycle, and review-authority tests while concentrating coverage
on integrity and claim-boundary failures.

SKILL-EVIDENCE: operations:risk-assessment — helped: prioritized laundering, sample
inflation, post-outcome mutation, and certification overclaim as the material risks and
mapped each to an executable mitigation.

SKILL-EVIDENCE: superpowers:test-driven-development — helped: the full adversarial suite
was written first, observed failing for the missing engine, and only then made GREEN
with 95 assertions.

## DEFERRED

- Live HCM-v2 recruitment, consent, compensation, ballots, study execution, and final
  1,000-brief outcomes remain external evidence; no fixture in this lane upgrades them.
- `HUMAN_CERTIFIED` remains unreachable until a future registered contract proves
  roster-bound deciding-human ballots on the exact released artifact.
- `taste_certified:true` remains unreachable in evidence-policy v3.
- Public TASTE and static-aesthetics corpora remain diagnostic-only.
- Genericness remains review-only until its separate sealed human qualification passes;
  that qualification is not simulated or claimed here.
