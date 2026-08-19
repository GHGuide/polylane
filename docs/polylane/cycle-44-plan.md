# Cycle 44 plan — implement the five frozen v3 defect controls (m32.7)

RUN_ID: `c44-defect-controls-20260819-a1` · target: `m32.7` · authority: the
`implementation_defect_registry` in `docs/polylane/taste-certification/contracts/CONTRACT-LOCK.v3.json`
and the `implementation_defects` array in `EVIDENCE-CLAIM-REGISTRY.v3.json`,
both landed by cycle 43. Acceptance for m32.7 was frozen before this cycle
(`8d38d6c`): one focused check per control, plus the shipped example manifests
staying structurally valid, plus the terminal host gate.

Each defect carries a `required_v3_control` and the same disposition — the
affected evidence "blocks … from promotion until repaired **and regression
tested**". So every lane lands behaviour *and* the named regression test.

## Lanes (disjoint ownership, one boundary each)

| lane | defects | control to implement | owns |
|---|---|---|---|
| `prompt-chain` | `c42b-unsafe-whole-document-prompt-dedupe`, `c42b-optimized-prompt-deletion` | dedupe restricted to typed sections, never altering mandatory locked bytes; frozen finalist prompt bytes and their source/compiled/delivered/consumed receipt chain remain immutable and addressable after promotion | `bin/polylane-taste-prompts.sh`, `tests/test-taste-prompt-integrity.sh`, `tests/test-taste-artifact-retention.sh` |
| `execution-proof` | `c42b-missing-consumed-stdin-proof`, `c42b-run-mode-vocabulary-mismatch` | delivered and consumed stdin SHA-256 + byte count match, bound by a successful stdin adapter receipt and request receipt; one run-mode vocabulary across producer, validator, storage, lifecycle | `bin/polylane-taste-execution-contract.sh`, `tests/test-taste-delivery-provenance.sh`, `tests/test-taste-run-mode.sh` |
| `comparator` | `c42b-comparator-pseudo-win` | only a validated outcome equal to `win` increments wins; ties, abstentions, missing and invalid evidence stay non-wins inside the fixed denominator | `bin/polylane-taste-ballot.sh`, `tests/test-taste-comparator-outcome.sh` |

Frozen cross-lane contract: no lane edits `CONTRACT-LOCK.v3.json`,
`EVIDENCE-CLAIM-REGISTRY.v3.json`, the v3 schemas, or another lane's files. The
registry's `status: OPEN` flags stay OPEN this cycle — flipping them re-freezes
a hashed contract and is its own decision, taken only once every control is
implemented and the integrator has certified the set.

## Integrator

Merges the three lanes, checks seams (all five controls coexisting in one tree),
runs the frozen m32.7 focused acceptance, then `READY-FOR-HOST-GATE`.

## Risks

- The controls touch evidence-grading paths; a lane that weakens an existing
  check to make its own test pass is the failure mode to reject at integration.
- `bin/polylane-taste-prompts.sh` and `bin/polylane-taste-execution-contract.sh`
  are consumed by existing suites; each lane must keep its neighbours green.
