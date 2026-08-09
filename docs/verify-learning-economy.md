# Learning economy verification

## Decision and policy flow

The decision is whether to change one current policy field (model, effort, lane count,
or context budget). Evidence is comparable only when accepted GO receipts have the same
domain and lane shape. The current flow used textual skill relevance and legacy outcome
notes; it could rank a capability match without proving that the exact skill file helped.
The future flow is: validate acceptance/fingerprint → atomically deduplicate ledger →
compute conservative medians → require comparable samples and bounds → emit either one
safe policy step or the unchanged safe default. A catalog match is always a `candidate`
until the benchmark gate observes the same fingerprint on the same lane shape.

## Metrics and worked fixture

For a receipt, `progress = quality_score × (verified_criteria_delta +
verified_subgoal_delta)`. The optimizer reports median `progress × 1000 / tokens` and
median `progress × 60 / wall_seconds`; its selection score is the minimum of those two
medians. This makes a cheap but slow or low-quality result unable to dominate.

In the focused fixture, the Terra baseline has quality 2, two verified criteria, 1,000
tokens, and 60 seconds: progress 4, 4 progress/1K tokens, and 4 progress/minute. Three
accepted Luna receipts have quality 5 and three verified criteria at the same cost: 15,
15, and 15. The recommendation changes only `model` to Luna. A zero-delta receipt has
quality 9 but progress 0, therefore value 0. The confidence percentage is
`samples / (samples + 2)`; three samples produce 60% measured confidence.

## Guardrails and safe fallbacks

- Malformed, pending/unaccepted, NO-GO, quality-regression, unlabeled synthetic, and
  duplicate receipts never enter the optimizer ledger.
- Fewer than three samples, missing current baseline samples, unavailable models,
  unmatched domain/lane shapes, lane/context bound violations, and terminal/integrator
  safety roles return the unchanged safe default.
- The optimizer compares a median, requires a strictly better score before applying a
  change, and emits at most one changed field. Exact ties are deterministic but not safe
  to apply.
- A benchmark requires accepted GO, all hard checks, no hurt/failure, positive quality
  delta, three samples, and an exact skill fingerprint. Changed fingerprints invalidate
  prior admission; failures remain visible as blocked candidates.
- The catalog test proves the false-positive class: the high lexical API candidate stays
  `candidate`, while the lower textual match with three valid lane-shaped benchmark
  receipts becomes the first `recommended` result.

## Test pyramid and TDD evidence

Unit coverage validates receipt schemas, duplicate identity, outcome value, benchmark
fingerprint invalidation, confidence, and clamps. The focused integration coverage joins
catalog ranking to the benchmark ledger and preserves the old outcome/catalog APIs.

Red-before-green proof: before implementation,
`bin/polylane-check.sh "$PWD/.polylane/check-cache/learning-economy" -- bash
tests/test-learning-economy.sh` reported 5 pass / 51 fail because the two binaries were
absent and the catalog selected `skill:lexical`. After implementation the same focused
check reported 56 pass / 0 fail.

## Verification commands

Focused: `bin/polylane-check.sh "$PWD/.polylane/check-cache/learning-economy" -- bash tests/test-learning-economy.sh`.

Adjacent compatibility: outcome rooting, scout catalog/outcomes, and model policy tests;
ShellCheck covers the modified scripts.

## Coordination

The canonical refinement queue was handled with bounded declines for renewed `context`
compaction (12 observations) and `integrator` NO-GO (6 observations): neither exposed a
new lane-local defect with a distinct bounded check. Relay message `message:98` asks the
integrator-owned arming seam to reject catalog candidates unless status is `recommended`
and `safe_to_apply` is true.

SKILL-EVIDENCE: data-analytics:product-business-analysis — helped: defined acceptance-qualified progress, comparable cohorts, confidence, and the decision-ready safe default before implementing formulas.
SKILL-EVIDENCE: engineering:testing-strategy — helped: split validation and economy math into fast unit cases, then added the catalog/benchmark integration regression.
SKILL-EVIDENCE: operations:process-optimization — helped: mapped the old lexical-to-arm flow against the gated evidence flow and isolated the remaining arming seam for relay.
SKILL-EVIDENCE: superpowers:test-driven-development — helped: the new focused suite failed with 51 expected failures before either implementation binary existed, then guided the green implementation.

## DEFERRED

DEFERRED: integrator-owned `polylane-scout.sh` arming enforcement, relayed as message:98 because this lane is forbidden to edit that seam.
