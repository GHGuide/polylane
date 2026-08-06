# Cycle 8 digest — fresh efficiency certificate passed

## Final benchmark

- Outcome: GO, promoted to `main`, final cleanup complete.
- Wall time: 305 seconds against a 900-second budget.
- Execution: three initial launches, zero lane or supervisor restarts, exactly one host terminal
  gate, no approval prompt, and no manual tmux input.
- Token usage: 780,626 total from current-run Codex `turn.completed` events. Compared with cycle 5,
  this is about 82% fewer tokens and 59% less wall time.
- Verification: the hostile zero-restart suite and terminal suite passed; after token-parser
  hardening, the full repository suite passed 1,032 checks across 67 files with zero failures,
  and ShellCheck remained clean for every runtime script.

## Delivered hardening

- Supervisor recovery fixtures now own their retry policy and cannot inherit the outer canary cap.
- Codex usage parsing tolerates warning and prompt lines in pane logs.
- Fresh launches baseline append-only log offsets; repeated lane names no longer count prior cycles,
  while same-run resumes and respawns continue accumulating from the durable boundary.
- Logger attachment now precedes process seeding, closing the early-output loss window.

## Completion

The mechanical goal tree is complete: 13/13 subgoals and 10/10 criteria. The final certificate is
`docs/polylane/efficiency-proof.md`; durable telemetry is `docs/polylane/run-stats.json`.
