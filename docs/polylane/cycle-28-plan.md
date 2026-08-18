# Cycle 28 plan — long-turn supervision and usage truth

Run: `c28-watchdog-truth-20260810-a1`

Base: `candidate/c28-recovery` at recovered Cycle 27 READY tip `38ee3fa`

## Frozen target

- Inherit and independently re-verify `m24.1`–`m24.3`; Cycle 27's HALTED report
  remains immutable and those repairs become durable only if this run promotes.
- `m25.1` — replace the old 40-check high-effort watchdog with effort-scaled,
  time-based live-turn caps; protect active commands and current in-flight turns,
  preserve short terminal-turn recovery, and retain one finite hard limit.
- `m25.2` — record one exact bounded reason whenever a lane becomes failed and use
  it in HALTED table rows, notifications, and recovery guidance.
- `m25.3` — preserve legacy total tokens while adding truthful input, cached input,
  uncached input, output, and reasoning-output counters with append-only offsets.
- `m25.4` — export and document distinct source and control roots in every pane;
  direct Graphify queries through the source root without moving canonical state.
- `m24.4`, `m25.5`, and criterion `c71` remain open for a fresh Cycle 29 terminal
  process. Cycle 28 must not certify the watchdog using the process that changed it.

## Carve

One builder owns `polylane-run.sh`, run telemetry, the runtime prompt contract, and
their coupled tests. Splitting would force multiple lanes to edit the same runner
and report tests, violating file-isolated carving. The integrator owns only merge,
bounded seam repair, independent focused verification, and cycle evidence.

## Frozen focused acceptance

- inherited `m24.1`: manifest/scout/orchestration/dry-run matrix
- inherited `m24.2`: status-normalization/lane-DONE/scope matrix
- inherited `m24.3`: memory/acceptance/verdict/report matrix
- `m25.1`: `bash tests/test-wedge.sh && bash tests/test-runtime-recovery.sh && bash tests/test-pane-errored.sh`
- `m25.2`: `bash tests/test-write-report.sh && bash tests/test-runtime-recovery.sh`
- `m25.3`: `bash tests/test-run-stats.sh && bash tests/test-write-report.sh && bash tests/test-efficiency-canary.sh`
- `m25.4`: `bash tests/test-agent-adapter.sh && bash tests/test-prompt-compiler.sh && bash tests/test-orchestration-contract.sh && bash tests/test-promptlint.sh`

Run focused checks through `polylane-check.sh`; do not rerun an unchanged matrix.
Changed shell scripts must pass ShellCheck. Runtime evidence must show exactly two
launches, zero lane/supervisor restarts, and **zero terminal gates**.

## Bootstrap and stopping rule

The Cycle 28 supervisor exports `POLYLANE_LIVE_WEDGE_CHECKS=1000` because its shell
loads the old watchdog before the builder can repair it. This is a one-run bootstrap
extension, not acceptance evidence. Stop with READY only when production defaults
and regressions are correct. Any focused defect is NO-GO with retained worktrees.

## Next cycle

Cycle 29 starts a new process from the promoted Cycle 28 tip and runs exactly one
terminal command containing the full suite, ShellCheck, provider parity, fresh
installers, and live GO/NO-GO doctor rehearsal. Only that fresh GO can complete
`m24.4`, `m25.5`, `c66`, and `c71` and authorize local skill installation.
