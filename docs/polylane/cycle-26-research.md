# Cycle 26 research — terminal finality after a live NO-GO

## Observed failure chain

Cycle 25 produced a committed, nonce-bound NO-GO at `7854a1f`, but the runner did
not reach its report boundary. The live transcript proves this sequence:

1. The integrator emitted a repairable-by-default NO-GO even though its only blocker
   was immutable current-run restart telemetry.
2. `build_integrator_repair_prompt` appended new `DELEGATION` and `CHECK-CACHE`
   scalars to a prompt that already contained them; strict admission rejected it.
3. `repair_integrator_verdict` checkpointed and removed terminal evidence before the
   replacement prompt was admitted, leaving the branch between two valid states.
4. Graph finalization returned before `write_report`; the supervisor therefore read a
   crash, relaunched with `--resume`, and recovery checkpointed deleted handoff files.

The intact source/evidence boundary is commit `7854a1f`; later Cycle 25 auto-retry
commits are contamination and are not a base for this cycle.

## Design conclusions

- Repair admission is a transaction: build and strict-lint the replacement prompt
  before checkpointing, deleting, or respawning anything.
- Repair addenda are prose-only. Existing strict scalar lines remain authoritative and
  must not be re-emitted under the same labels.
- Runtime efficiency is coordinator-owned. A source-green integrator hands off READY;
  a cheap pre-terminal eligibility check rejects immutable restart/supervisor history
  before the one expensive terminal gate is counted.
- Every terminal GO/NO-GO path publishes a fresh report even when graph bookkeeping or
  optional telemetry fails. Failed reporting may remain resumable, but committed
  handoff evidence must survive unchanged.
- Resume and supervisor behavior need a hermetic regression for the exact Cycle 25
  sequence, not only isolated helper tests.

## Graphify receipt

One shared graph was carried into the cycle. The coordinator queried only
`build_integrator_repair_prompt`, `repair_integrator_verdict`, `gate_with_repairs`, and
`supervisor_main`; builders receive direct `graphify-out/q.py` navigation, never the
Graphify skill body and never a per-lane rebuild.

