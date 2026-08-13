# Cycle 42A plan — freeze the taste-certification trust boundary

Run: `c42a-taste-contracts-20260813-a1`
Target: `m32.6`
Base: `codex/taste-certification`
Mode: autonomous maximum-assurance, four file-isolated Codex builders plus one
deferred Codex integrator

## Outcome

Produce one executable, content-hashed contract lock before any production source,
judge, prompt-optimizer, or UI implementation is allowed to proceed. The lock must
define the exact build/request/receipt chain, transitive evidence grades and claim
ceilings, source/calibration identities and statistics, and the worker finalization
state machine. It must also repair the Cycle 41 control-plane defect: external evidence
may remain open without turning a valid autonomous handoff into a mutable repair wave.

This is an implementation cycle, not a prose exercise. Every contract has a strict
validator and adversarial regression tests. The integrator alone creates the aggregate
claim registry and lock after merging the four independently authored contracts.

## Lane carve

1. `execution-contract-freeze` — canonical v3 brief, build, request, capture, judge,
   and receipt identities; exact-byte prompt delivery and deterministic fingerprints.
2. `evidence-policy-freeze` — verified evidence DAG, least-trusted-ancestor grading,
   fixture absorption, registered producer schemas, claim ceilings, and frozen
   exactly-20-brief statistical rules.
3. `source-contract-freeze` — metadata-first source selection, pair reservation,
   selected-byte acquisition, sessions receipts, checksums, duplicate policy, and
   calibration-panel eligibility.
4. `lifecycle-external-routing` — persisted worker finalization, immutable handoffs,
   progress watchdogs, explicit autonomous/external acceptance routing, and no
   runner-authored status or verdict repair.

The deferred `taste-contract-integrator` merges all four current tips, resolves only
cross-contract seams, creates `CONTRACT-LOCK.v3.json` and
`EVIDENCE-CLAIM-REGISTRY.v3.json`, runs focused and full verification, and emits the
sole nonce-bound verdict.

## Frozen contract decisions

- Certification label is `HUMAN_CALIBRATED_MACHINE`; status is machine-evaluated.
  `human_calibrated:true` never implies `human_certified:true`.
- `HUMAN_CERTIFIED` is unreachable without roster-bound deciding human ballots and a
  trust-rooted human-study receipt.
- A claim's effective evidence grade is the least trusted transitive ancestor.
  Fixture evidence is absorbing; unknown producers or schemas are invalid.
- Development and confirmatory benchmarks are separate. The frozen development study
  uses exactly 20 independent briefs, 0 ties/abstentions, at least 15 wins, Wilson 95%
  lower bound greater than 0.50, exact two-sided sign-test p at most 0.05, and zero
  accessibility regressions. Mirrored views diagnose side bias; they do not inflate n.
- A production panel needs at least five unique configuration fingerprints spanning
  at least two provider families. Fake CLIs, environment substitutions, and fixture
  ballots cannot upgrade live evidence.
- Source selection is metadata-first. It reserves qualifying pairs before downloading
  bytes, then downloads only the selected 252 identities and verifies declared size,
  upstream checksum, and local SHA-256.
- Worker handoff is a persisted state machine:
  `WORKING -> HANDOFF_PENDING -> HANDOFF_COMMITTED -> QUIESCING -> DONE`.
  Only the worker finalization transaction may author its marker/verdict bytes.
- Autonomous acceptance failure may trigger repair. External acceptance remains
  explicitly open and routes the cycle to `EXTERNAL-EVIDENCE-OPEN`; it never causes a
  worker repair or mutates a committed handoff.

## Acceptance

```bash
bash tests/test-taste-execution-contract-v3.sh &&
bash tests/test-evidence-dag.sh &&
bash tests/test-taste-source-contract-v3.sh &&
bash tests/test-finalization-watchdog.sh &&
bash tests/test-contract-acceptance.sh &&
bash tests/test-verdict-repair.sh &&
bash tests/test-lane-done.sh &&
bash tests/test-lane-done-live.sh &&
bash tests/test-supervisor.sh &&
shellcheck -S warning \
  bin/polylane-taste-execution-contract.sh \
  bin/polylane-evidence-dag.sh \
  bin/polylane-taste-source-contract.sh \
  bin/polylane-finalize.sh \
  bin/polylane-memory.sh \
  bin/polylane-run.sh \
  bin/polylane-supervisor.sh \
  assets/verify-gate.sh &&
tests/run.sh &&
bin/polylane-markers.sh check-docs references/ &&
bash tests/test-skill-parity.sh &&
git diff --check
```

No success in this cycle is a taste certificate. It is the frozen executable grader
that later production cycles must satisfy.

