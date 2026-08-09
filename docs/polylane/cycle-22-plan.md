# Cycle 22 plan — atomic proof-context terminal certification

## Why this cycle exists

Cycle 21 truthfully ended NO-GO before its terminal gate.  It used exactly two launches
and zero restarts, and both workers completed, but the runner's focused precheck exported
the new run nonce before a matching host efficiency proof existed.  Commit `870bce6`
keeps the proof path and nonce atomic: the precheck receives neither, while terminal
acceptance receives both only after the host writes its run-scoped gate proof.

Cycle 22 starts a new process from `870bce6`.  It reuses no Cycle 21 scratch, process,
pane, worktree, marker, graph ledger, or proof.  The failed Cycle 21 evidence remains
immutable.

## Frozen lane and interface

| Lane | Owns | Frozen outcome |
| --- | --- | --- |
| `terminal-boundary-audit` | `docs/verify-terminal-boundary-audit.md` and its exact canonical DONE marker | Reconstruct the Cycle 21 failure from primary evidence and independently prove the atomic proof-context repair without changing production code |
| `integrator` | Exact-tip merge plus Cycle 22 integration evidence | Reproduce the repaired focused boundary, preserve a clean merged tree, and hand exactly one READY candidate to the coordinator |

The run targets every remaining autonomous integration subgoal: `m20.1`, `m18.3`,
`m17.3`, and `m16.4`.  Criterion `c56` is host-owned and may close only after successful
promotion, cleanup telemetry, and the final nonce-bound efficiency proof.

## Mechanical acceptance

- Contract-v2 preflight, strict prompt lint, static scope, selected-skill delivery, and
  the authoritative execution graph pass before any pane launches.
- The audit proves the Cycle 21 half-context from the preserved outcome and commit, then
  runs only the repaired focused suites through its lane-local check cache.
- The integrator merges the exact audit tip and independently reruns focused/static
  contracts without consuming the terminal command.
- Telemetry records exactly two launches, zero lane/supervisor restarts, exactly one
  terminal gate, and complete cleanup within 3,600 seconds.
- The coordinator alone executes the frozen terminal command: full suite, whole-tree
  ShellCheck, skill parity, installers, and hermetic live GO plus NO-GO rehearsal.
- The final proof names this run, phase `final`, the exact launch/gate counts, zero
  restarts, and cleanup `complete` before `c56` becomes done.

## Safety and stopping rule

No install, push, deployment, publication, purchase, live trade, or other consequential
external action is authorized.  Trading remains research/backtest/paper-only.  Any
restart, stale nonce, second terminal event, failed frozen check, incomplete cleanup,
or unclean evidence is NO-GO.  A failed run is recorded and superseded only by a fresh
process; it is never rewritten.

