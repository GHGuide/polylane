# Cycle 21 plan — zero-restart final certification

## Why this cycle exists

Cycle 20 truthfully stopped at its host efficiency boundary after one builder restart.
The restart originated in a frozen plan/observer filename mismatch, not worker
disobedience. Commits `763fb00`, `e1de56a`, and `f58d3cb` now provide bounded marker
recovery, exact live-relay delivery, canonical host evidence/reporting, and prelaunch
rejection of noncanonical status contracts. Prelaunch audit then found and fixed an
inert-help/signal defect in `dabd6f0` and host-owned criterion finalization in
`864050d`. Cycle 21 starts a fresh process from `864050d`; no old scratch is reused.

## Frozen lane and interface

| Lane | Owns | Frozen outcome |
| --- | --- | --- |
| `final-certification-audit` | `docs/verify-final-certification-audit.md` and its exact canonical DONE marker | Prove the Cycle 20 root causes and all prelaunch repairs from primary commits and focused tests without changing production code |
| `integrator` | Exact-tip merge plus Cycle 21 integration evidence | Reproduce focused/static contracts, preserve a clean merged tree, and hand exactly one READY boundary to the coordinator |

The run targets all remaining autonomous integration subgoals: `m20.1`, `m18.3`,
`m17.3`, and `m16.4`. Criterion `c56` is host-owned: it remains open through builder,
integrator, terminal gate, and promotion, and closes only after successful cleanup and
the final nonce-bound efficiency proof.

## Mechanical acceptance

- Contract-v2 preflight rejects wrong, broad, duplicate, or contradictory status paths
  before worktrees or models exist, and compiled prompts contain the literal live relay.
- The authoritative execution graph admits every transition from start through complete.
- Run telemetry records exactly two launches, zero lane/supervisor restarts, one terminal
  gate, and complete cleanup within 3,600 seconds.
- Frozen focused checks pass. Exact duplicate Cycle 17/18 focused commands and Cycle
  16/18 terminal commands share acceptance keys and execute once per boundary.
- The coordinator alone runs the terminal command: full suite, whole-tree ShellCheck,
  skill parity, installers, and hermetic GO plus NO-GO rehearsal.
- The final efficiency proof has this run nonce, phase `final`, one terminal gate, zero
  unexpected launches, and cleanup `complete` before `c56` becomes done.

## Safety and stopping rule

No external action, install, push, deployment, purchase, publication, live trade, or
manual approval is authorized. Trading remains research/backtest/paper-only. Builders
and integrator must not run the full suite or doctor rehearsal. Any restart, second
terminal boundary, stale nonce, failed focused/terminal check, incomplete cleanup, or
untruthful evidence remains NO-GO; a failed cycle is never rewritten.
