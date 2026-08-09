# Cycle 23 plan — fresh terminal-fixture certification

## Why this cycle exists

Cycle 22 truthfully consumed one terminal gate and ended NO-GO after 2,201 passing and
9 failing assertions.  Its workers and efficiency envelope were healthy: exactly two
launches, zero restarts, a clean READY handoff, and a passing nonce-bound gate proof.
The failure was a non-hermetic recovery fixture.  The exact diagnostic replay then
found a second stale contract in the live rehearsal manifest.  Commit `23572df` fixes
both with red-first regressions and proves the full terminal command locally, but that
diagnostic evidence cannot rewrite Cycle 22.

Cycle 23 starts from `23572df` in a new clone and process.  It reuses no Cycle 22
scratch, tmux server, pane, worktree, marker, graph ledger, report, or nonce.

## Frozen lane and interface

| Lane | Owns | Frozen outcome |
| --- | --- | --- |
| `terminal-fixture-audit` | `docs/verify-terminal-fixture-audit.md` and its exact canonical DONE marker | Independently prove both fixture repairs from primary evidence without changing production code |
| `integrator` | Exact-tip merge plus Cycle 23 integration evidence | Verify the repair boundary, preserve a clean candidate, and hand exactly one READY verdict to the coordinator |

The run targets `m20.1`, `m18.3`, `m17.3`, and `m16.4`.  Criterion `c56` remains
host-owned and may close only after successful promotion, cleanup telemetry, both live
rehearsal routes, and a final nonce-bound efficiency proof.

## Mechanical acceptance

- Contract-v2 plan/status ownership, strict prompt lint and compilation, selected-skill
  delivery, static scope, doctor preflight, and the authoritative graph pass before any
  worker launches.
- The builder confirms the inherited-retry reproduction, the hermetic recovery fixture,
  canonical rehearsal status ownership, and focused repair checks from commit `23572df`.
- The integrator merges only the exact builder tip and reruns focused/static contracts;
  neither worker may execute the full suite, installers, or live doctor rehearsal.
- Telemetry records exactly two launches, zero lane/supervisor restarts, exactly one
  terminal gate, and complete cleanup within 3,600 seconds.
- The coordinator alone runs the frozen terminal command: full suite, whole-tree
  ShellCheck, skill parity, installers, and hermetic live GO plus intentional NO-GO.
- The final proof names the Cycle 23 nonce, phase `final`, exact launch/gate counts, zero
  restarts, and cleanup `complete` before any target or `c56` becomes done.

## Safety and stopping rule

No install, push, deployment, publication, purchase, live trade, or other consequential
external action is authorized.  Trading remains research/backtest/paper-only.  Any
restart, stale nonce, second terminal event, failed frozen check, incomplete cleanup,
or unclean evidence is NO-GO.  A failed run remains immutable and can only be superseded
by another fresh process.
