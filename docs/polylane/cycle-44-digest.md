# Cycle 44 digest — the five frozen v3 defect controls, implemented and promoted

Cycle 44 took m32.7's first slice: the `implementation_defect_registry` that
cycle 43 froze listed five OPEN defects, each with a `required_v3_control` and
the disposition "blocks affected evidence from promotion until repaired **and
regression-tested**". Acceptance was frozen from those controls *before* any
builder existed (`8d38d6c`), so the cycle could not grade its own homework.

Three disjoint lanes, all test-driven, contracts read-only:

| defect | control | lane | proving test | result |
|---|---|---|---|---|
| `c42b-unsafe-whole-document-prompt-dedupe` | dedupe restricted to typed sections, mandatory locked bytes untouchable | `prompt-chain` | `tests/test-taste-prompt-integrity.sh` | 34 pass |
| `c42b-optimized-prompt-deletion` | frozen finalist prompt bytes + source/compiled/delivered/consumed receipt chain immutable and addressable after promotion | `prompt-chain` | `tests/test-taste-artifact-retention.sh` | 42 pass |
| `c42b-missing-consumed-stdin-proof` | delivered and consumed stdin SHA-256 + byte count match, bound by adapter and request receipts | `execution-proof` | `tests/test-taste-delivery-provenance.sh` | 14 ok |
| `c42b-run-mode-vocabulary-mismatch` | one contract-v3 run-mode vocabulary at producer, validator, storage, lifecycle | `execution-proof` | `tests/test-taste-run-mode.sh` | 18 ok |
| `c42b-comparator-pseudo-win` | only a validated `win` increments wins; ties, abstentions, missing and invalid evidence stay non-wins in the fixed denominator | `comparator` | `tests/test-taste-comparator-outcome.sh` | 49 pass |

Outcome: `EXTERNAL-EVIDENCE-OPEN` — verified engineering promoted; the remaining
proof (human panels, live source campaigns) genuinely cannot be produced by the
system. All seven frozen m32.7 accepts, six focused plus the terminal host gate,
then passed fresh on the promoted tree, and only on that evidence did m32.7 close.

Scope discipline held: each lane touched exactly its OWN files — no contract
JSON, no v3 schema, no neighbour's code, no defect status flipped.

**Deliberately not done:** the registry's `status: OPEN` flags stay OPEN.
Flipping one re-freezes a hashed contract (`freeze_sha256`) and needs its own
decision about which cycle owns the transition and what re-certifies the lock.

Harness note: the same wrapped-path approval dialog parked all four lanes. The
fix (flatten and un-wrap before matching, secrets still refused) landed on main
mid-cycle at `3c475db`, but a running Bash process cannot reload its own script,
so this cycle still needed manual clears. The next launch carries it.

Next: m32.8 — public transfer diagnostics and the HCM-v2 study pipeline. Note
its sibling m32.8a is `external`: ethics review, panel recruitment and sealed
ballots need a human, so m32.8 must be scoped to what the repository can build
and prove offline.
