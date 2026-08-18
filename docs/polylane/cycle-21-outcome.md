# Cycle 21 outcome — truthful pre-terminal NO-GO

Run `c21-final-cert-20260809-a1` started from a fresh process and used exactly two
worker launches with zero restarts.  The audit lane completed, the integrator merged
its exact tip, and the integrator handed off a clean, nonce-matched
`READY-FOR-HOST-GATE` candidate after a 230-pass focused review.

The runner correctly withheld promotion.  Its cheap focused gate failed before the
single terminal-gate event, so `terminal_gates=0`, cleanup remained pending, and all
four target subgoals plus `c56` remained open.  The canonical report attributed the
failure to the host gate rather than either completed worker.

## Root cause

`contract_focused_acceptance_gate` exported the current run nonce even though
`write_efficiency_proof gate` had not run and no matching current-run proof existed.
The nested efficiency canary therefore paired Cycle 21's nonce with its inherited or
default proof and rejected otherwise-green work at `efficiency-canonical-proof`.
This was a runner environment-boundary defect, not a product, lane, restart, or
integration failure.

## Repair and proof

The pre-terminal focused gate now explicitly clears both proof-context variables;
the actual terminal acceptance continues to receive the proof path and nonce as one
atomic pair after the host creates the gate proof.  A red-first regression reproduced
the half-context (`|pre-gate-run|`) and now requires an empty pair (`||`).

After the repair, the focused acceptance, verdict, and efficiency suites passed 84/84,
ShellCheck reported no warning, and the complete suite passed 2,210/2,210 across 108
test files.  These are repair checks, not a retroactive Cycle 21 terminal success.
A fresh process-start cycle owns the one-terminal-gate certification, live GO/NO-GO
rehearsal, promotion, cleanup, and final criterion closure.

