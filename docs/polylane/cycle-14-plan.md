# Cycle 14 plan — truthful self-hosting

## Locked outcome

A verified run promotes and reports transactionally, active workers are not killed as
wedged, all worktrees share one monotonic worker ledger, and selected skills reach the
builder as trusted readable paths with actual-use evidence.

## Integration spec

1. Make pre-promotion runner writes explicit and safe, preserve unrelated dirty files,
   and make reports derive merge/cleanup claims from observed lifecycle outcomes.
2. Replace broad `status=completed` terminal matching with agent-turn/process-aware
   liveness while retaining bounded recovery for dead and truly frozen panes.
3. Resolve worker capsule/message/ack operations to one canonical state root so parallel
   worktrees cannot allocate duplicate event sequences.
4. Carry each selected skill's trusted resolved `SKILL.md` path through scouting,
   prompt compilation, launch, and use-audit receipts.
5. Certify all four reproductions, Claude/Codex parity, fresh installation, full suite,
   ShellCheck, and physical GO/NO-GO rehearsal.

## Lane carve

| Lane | Owns | Excludes | Frozen evidence |
|---|---|---|---|
| `runner-truth` | runner promotion/report/liveness logic; promotion, report, wedge, recovery tests | workers ledger, scout/catalog/compiler | dirty-base promotion, false report, quiet active turn, dead-pane recovery |
| `worker-ledger` | worker canonical-root/ledger helper and worker tests | runner, scout/compiler | cross-worktree concurrent append, unique monotonic sequence, no lost events |
| `skill-delivery` | skill catalog/acquisition/scout delivery and compiler-facing kit tests | runner, workers | trusted resolved paths, runtime readability, actual-use receipts |
| `integrator` | shared docs/parity/certification and cross-lane seam repair | builder-owned implementation except necessary seams | cycle-14 matrix, full terminal gate, live rehearsal |

Intensity is `balanced`; the agent-aware policy chooses lane models and applies the
integrator safety clamp. The runner-truth lane is the hardest lane and receives the
highest builder effort permitted by the selected tier.
