# Integration verification — walk-c8

Run identifier: `walk-c8-20260806-233854`

## Merged evidence

- Supervisor-hermetic branch tip: `c6a409574a637096e66c710c26e895970cc5801c`
  (merged by `2ef14ea30babe5f619b730ed9a08f32c87a3a9cc`).
- Terminal-contract branch tip: `846bead999b47208152344ec510be080f63065c8`
  (merged by `3593146a88c5b48c05197c02eb6cd9792aea2574`).

Read merged evidence:

- `docs/verify-supervisor-hermetic.md` records 22 supervisor checks and the
  run-stats check passing under the zero-restart policy.
- `docs/verify-terminal-contract.md` records the terminal-contract, efficiency,
  and report evidence from its lane.

## Independent focused verification

| Exact command | Exit code | Current-run summary |
| --- | ---: | --- |
| `POLYLANE_SUP_MAX_RESTARTS=0 bash tests/test-supervisor.sh` | 0 | 22 pass, 0 fail; revive, halted recovery, single-launch terminal states, restart cap, lock cleanup, and heartbeat checks passed. |
| `bash tests/test-run-stats.sh` | 0 | Run-stat initialization, resume, usage, snapshot, and concurrency passed. |
| `bash tests/test-verdict-repair.sh` | 0 | 26 pass, 0 fail; the ready host gate and one-shot efficiency proof are each exercised once, with failure paths stopping repair/loop work. |
| `bash tests/test-efficiency-canary.sh` | 0 | 13 pass, 0 fail; capture/verify, two-lane launch budget, one gate, restart and stale-run rejection, durable failure, and clean teardown passed. |
| `bash tests/test-write-report.sh` | 0 | 25 pass, 0 fail; GO, NO-GO, and halted reports preserve only supported current-run evidence. |

All five prescribed focused commands were executed once in this integration
worktree and returned exit code 0. No check cache was used.

## Candidate verdict and handoff

Candidate verdict: focused integration evidence supports a single nonce-bound
terminal acceptance handoff for `walk-c8-20260806-233854`. The outer coordinator
must perform the host-only terminal gate and may decide the final frozen verdict.

POLYLANE-VERDICT: READY-FOR-HOST-GATE run=walk-c8-20260806-233854
