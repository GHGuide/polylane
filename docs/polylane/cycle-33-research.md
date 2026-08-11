# Cycle 33 research — focused efficiency and cleanup truth

Run: `c33-efficiency-contract-20260811-a1`

Cycle 32 is a focused GO: 69/69 target assertions passed, promotion completed,
both worktrees and merged branches were removed, canonical telemetry records two
launches, zero restarts, zero terminal gates, and `cleanup=complete`. Its final
report nevertheless says cleanup was incomplete and its final efficiency proof
says FAIL solely because `bin/polylane-efficiency.sh` hard-codes exactly one
terminal gate for every run.

That invariant is correct for terminal certification and wrong for deliberately
focused cycles. The manifest already owns launch, restart, and wall-time budgets;
it should also own `expected_terminal_gates`. Preserve backward compatibility by
defaulting the missing field to `1`. A focused manifest explicitly declares `0`.
The proof must print actual and expected values, and verification must accept only
a passing proof whose terminal-gate values agree, while continuing to accept the
legacy exact `Terminal gates: 1` format.

No terminal-tier check, full suite, installer, doctor rehearsal, push, deployment,
publication, or external action belongs in this cycle. Cycle 34 will use the
default/explicit-one terminal contract in a fresh process.
