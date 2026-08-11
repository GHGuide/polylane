# Cycle 29 outcome

**Outcome: HALTED.** The immutable report is
`/Users/leonardo/Downloads/polylane-c29/docs/polylane-report.md`.

- Source-ready integrator tip: `9df16a33c51ccbb210247c51fc9bbb1207d256ed`.
- Runtime: two launches, zero lane/supervisor restarts, one terminal gate.
- Every targeted focused acceptance passed.
- `tests/test-memory.sh`, running inside a frozen acceptance command, inherited
  the outer `POLYLANE_ACCEPT_FAILURE_*` variables and persisted its intentional
  failing fixtures as the real run's acceptance evidence.
- Promotion refused
  `docs/polylane/host-gate-failures/c29-active-scope-20260811-a1.acceptance.jsonl`
  as unrelated user data. Nothing merged or cleaned.
- The published HALTED report named neither the exact blocker nor the retained
  integrator tip, so diagnosis required the runner log.

Cycle 30 starts from the retained source tip and repairs these gate-truth seams.
