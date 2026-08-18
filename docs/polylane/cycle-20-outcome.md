# Cycle 20 terminal outcome — NO-GO preserved

- Run: `c20-clean-cert-20260809-a1`
- Outcome: `NO-GO`
- Wall time: 1,617 seconds
- Launches: 2 / 2 expected
- Restarts: 1 / 0 allowed
- Host terminal-boundary entries: 1
- Full terminal acceptance executions: 0
- Tokens: 4,424,983, known
- Cleanup: pending; worktrees retained

The integrator produced a committed `READY-FOR-HOST-GATE` handoff. The runner entered
the host boundary once, generated a failed efficiency certificate because
`restarts=1>0`, skipped frozen terminal acceptance, and halted without promotion or
cleanup. The old report then incorrectly summarized that host rejection as “integrator
withheld GO” and wrote the failed gate certificate into the completed integrator
checkout. Commit `e1de56a` fixes both behaviors for subsequent runs: reports attribute
the canonical host failure and never display an unknown cost as zero, while gate proofs
live under a nonce-scoped canonical host path and terminal acceptance verifies the exact
run id without dirtying the READY worktree.

Post-run inspection proved the worker had not invented the wrong path: the Cycle 20
manifest and authored prompt both assigned it. Commit `f58d3cb` now rejects that
plan/observer mismatch before worktrees or models launch and passed a 292/0 focused
scope/prompt/orchestration/parity matrix.

Cycle 20 remains failed evidence. It does not close `m20.1`, `m18.3`, or `c56`.
