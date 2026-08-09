# Domain runtime verification

## Decision

The runtime uses one `domain-runtime/v1` declarative contract rather than separate
per-domain scripts. It keeps Bash 3.2 + jq as the only runtime requirements, makes
offline fixtures the default, and separates preparation/approval evidence from action
execution. This adds a small shared schema while avoiding adapters that can silently
perform consequential work.

## Contract and provenance

`bin/polylane-domain.sh contract <kind>` emits sorted canonical JSON for software,
trading, research, operations, content, data, custom, and mixed. Every contract has
capabilities, jq dependency, side-effect class, public/local input declaration,
offline fallback, five provenance fields, grader requirements, adaptive question tree,
deliverable manifest requirements, and an action policy.

`bundle` validates the existing project profile, requires all five provenance fields,
and writes `domain-runtime/bundle-v1`: declared artifact paths, `cksum` checksums,
artifact root, kind, and matching provenance. `grade` validates the manifest against
the live artifact root and emits a `domain-runtime/grade-v1` object containing every
check and a `PASS` only when every check is true. The checks are profile-specific:
trading adds split/holdout/costs/leakage/robustness/drawdown/selection-bias/paper-only;
research, operations, content, data, software, custom, and mixed each require their
declared minimums.

## Discovery and action safety

`polylane-discovery.sh init <state> <brief> [kind]` preserves the old three-argument
CLI. With a kind it records `domain.kind`, inserts 4–8 high-impact nodes with
recommended/deep/bold/custom paths and stopping metadata, and carries the contract's
domain-specific deep/bold follow-up into the durable graph.

`bin/polylane-action-preview.sh` has only `prepare`, `verify`, and `approve`. A
prepared `domain-runtime/action-receipt-v1` includes canonical profile/payload hashes,
a redacted preview, affected systems/people, reversibility, worst credible impact,
simulation evidence, approval requirement, and an identity derived from its exact
contents. It rejects unknown actions, secret-shaped payload fields, unsafe/live/execute
verbs, mismatched approvals, and altered receipts. It has no execution path.

## Red → green evidence

1. `bin/polylane-check.sh "$PWD/.polylane/check-cache/domain-runtime" -- bash tests/test-domain-runtime.sh`
   initially failed with missing `polylane-domain.sh` contract/questions behavior.
   After the minimal contract/question implementation it passed 27 checks.
2. The same focused command then failed after typed discovery assertions were added:
   `init ... trading` was rejected and no `domain.kind` or seeded nodes existed. It
   passed after the optional kind bridge was added; the legacy discovery test remained
   green.
3. The focused command then failed for the missing bundle/grade behavior and fixtures.
   It passed after checksum manifests, provenance requirements, and trading checks were
   added. Missing provenance and altered artifacts are negative cases.
4. The focused command then failed for the absent action-preview helper. It passed after
   preview/verify/approval receipt behavior was implemented. The final focused result is
   `1..73`, all passing.
5. A final red assertion showed a typed deep answer generated the old generic question;
   it expected `What evidence would change this decision?`. It passed after discovery
   persisted the adapter follow-up rather than replacing it.

## Commands and results

```text
bin/polylane-check.sh "$PWD/.polylane/check-cache/domain-runtime" -- bash tests/test-domain-runtime.sh
# PASS: 73 focused checks

bin/polylane-check.sh "$PWD/.polylane/check-cache/domain-runtime" -- bash tests/test-discovery-graph.sh
# PASS: 25 checks

bin/polylane-check.sh "$PWD/.polylane/check-cache/domain-runtime" -- bash tests/test-project-generality.sh
# PASS: 35 checks

shellcheck -S warning bin/polylane-domain.sh bin/polylane-action-preview.sh bin/polylane-discovery.sh bin/polylane-project.sh
# PASS: no output
```

The focused fixture is entirely local. It proves PASS and meaningful FAIL paths for all
eight profiles, deep specificity for trading/research/operations/content/data,
provenance absence, artifact and receipt tampering, secret redaction refusal, exact
approval binding, and autonomous live-trading refusal. No internet fetch or external
action occurred.

## Risk register

| Risk | Likelihood | Impact | Mitigation | Status |
|---|---|---|---|---|
| A profile claims evidence without provenance | Medium | High | Five required fields in bundle and grader | Mitigated |
| A stale artifact is graded as current | Medium | High | Per-file checksum verification against artifact root | Mitigated |
| Trading research leaks or becomes live execution | Medium | Critical | Explicit leakage=false, paper-only grader, no execute helper | Mitigated |
| Preview exposes a credential or is altered | Medium | High | Reject secret-shaped keys; receipt identity and verify | Mitigated |
| Deep discovery loses domain context | Medium | Medium | Persist adapter follow-up nodes in durable graph | Mitigated |

## DEFERRED

DEFERRED: none

SKILL-EVIDENCE: deep-research — helped: the runtime requires source identity, method, fixture/public status, and input hashes rather than claiming uncited evidence.
SKILL-EVIDENCE: engineering:architecture — helped: selected a single versioned declarative contract over eight divergent adapter CLIs and documented the trade-off.
SKILL-EVIDENCE: operations:risk-assessment — helped: the register directly drove checksum, preview, approval, and simulation-only controls.
SKILL-EVIDENCE: superpowers:test-driven-development — helped: recorded red failures for missing contract, discovery, bundle, preview, and domain-follow-up behavior before their green implementations.
