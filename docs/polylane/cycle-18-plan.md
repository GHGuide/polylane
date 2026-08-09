# Cycle 18 plan — walk-away recovery truth

## Why this cycle exists

Cycle 17 integrated the Cycle-16 repairs and reproduced every focused contract, but its
host certification was interrupted when the machine reached ENOSPC. After space was
restored, the resumed suite reached 2,103/2,104 with one transient supervisor failure;
the same complete suite then passed 2,104/2,104 in isolation. The run remains NO-GO:
infrastructure recovery exposed defects that must be fixed before promotion.

Confirmed defects:

- startup automation types `1` whenever pane prose merely mentions the folder-trust
  question, even when no live option menu exists;
- host-gate failure prose is appended to the completed integrator worktree, making the
  runner's own write invalidate `lane_done` and relaunch a committed DONE integrator;
- report/event paths can leave misleading success text or torn state under ENOSPC, and
  the supervisor consumes retries instead of waiting for disk headroom;
- the runner calls plain prompt compilation, so benchmark-admitted selected skill paths
  never reach builders even though the standalone `compile-selected` helper works;
- a recovery root in the same Git repository does not inherit the canonical
  `graphify-out`, leaving every child lane graphless.

## Frozen lanes and interface

| Lane | Owns | Frozen outcome |
|---|---|---|
| `runtime-resilience` | runner, events, supervisor, runtime/resume/report/graph tests | Trust automation requires a real visible option; host failures never dirty DONE worktrees; disk pressure fails closed with atomic truth and bounded waiting; same-repository recovery roots share the canonical graph |
| `skill-context` | prompt optimizer and selected-skill compiler tests | Builder compilation places exact trusted id/path/fingerprint records next to the selected-kit instruction and requires observable `SKILL-READ` receipts |
| `integrator` | merge, interface wiring, provider parity, durable evidence | Runner invokes selected compilation for builders, all fixes coexist, and exactly one clean host terminal matrix remains |

The interface is fixed before fan-out: `polylane-promptopt.sh compile-selected SOURCE
KIT LANE OUTPUT` remains the only selected-kit compiler. The runtime lane wires builders
to that command after ordinary normalization; the skill-context lane owns its output
contract. No builder may edit the other lane's files.

## Acceptance and safety

- Simulate ENOSPC/write failures in temporary fixtures; never fill the real disk.
- A report is announced only after an atomic write succeeds.
- A graph ledger write failure leaves the previous valid history replayable.
- Terminal failure evidence belongs to canonical host-run state, not a completed lane.
- No terminal suite is run by builders or the integrator.
- Consequential external actions remain preview/receipt/approval-bound; trading remains
  research/backtest/paper-only.

## Finish

Promotion requires both focused lane contracts, merged interface checks, whole-tree
ShellCheck, Claude/Codex install parity, and one coordinator-owned terminal suite plus
GO/NO-GO rehearsal. Cycle-17 failure evidence remains historical and unchanged.
