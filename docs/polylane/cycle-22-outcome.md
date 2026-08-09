# Cycle 22 outcome — truthful terminal NO-GO

Run `c22-terminal-cert-20260809-a1` started from a fresh process, launched exactly
one audit worker and one integrator, and recorded zero lane or supervisor restarts.
The audit completed, the integrator merged its exact tip, and a clean nonce-matched
`READY-FOR-HOST-GATE` handoff reached the coordinator after 151 focused checks.

The coordinator consumed the run's single frozen terminal gate.  Its efficiency proof
passed with two launches, zero restarts, 607 seconds at the gate, and 1,047,313 known
tokens.  The full suite then returned 2,201 passes and 9 failures, so promotion and
cleanup were correctly withheld.  All four target subgoals and criterion `c56` remain
open.  The canonical failure is
[`host-gate-failures/c22-terminal-cert-20260809-a1.md`](host-gate-failures/c22-terminal-cert-20260809-a1.md).

## Root causes and repairs

Eight direct failures came from `test-runtime-recovery.sh`, with the Cycle 14 wrapper
contributing the ninth.  That unit fixture verifies the runner's default three-attempt
recovery contract but inherited Cycle 22's live operator policy
`POLYLANE_MAX_RETRIES=0`.  It now clears only that variable before sourcing the runner.
A red-first wrapper test runs the fixture while deliberately exporting zero retries;
the repaired fixture passes 14/14 and the Cycle 14 contract passes 13/13.

The exact-environment diagnostic replay then passed all 2,210 suite assertions, whole-
tree ShellCheck, 57 parity checks, and 50 installer checks before exposing a second
fixture drift in the live rehearsal.  Its builder prompts wrote canonical status
markers, but its generated `own_globs` omitted those same marker paths, so the newer
status-ownership preflight stopped the synthetic run before launch.  The rehearsal
manifest now owns `docs/status-lane-a.md` and `docs/status-lane-b.md` exactly once, with
red-first static regressions.  Under the same zero-retry live environment, the GO
rehearsal now reaches READY, one terminal gate, promotion, and cleanup; the intentional
NO-GO rehearsal retains evidence and then cleans its fixture.  These diagnostic repair
checks do not retroactively turn Cycle 22 green.

Next: start Cycle 23 from the committed repaired tip with new scratch, process, tmux
server, graph ledger, proof path, worktrees, and nonce; only that fresh terminal result
may close the remaining goal state.
