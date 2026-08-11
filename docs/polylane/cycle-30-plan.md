# Cycle 30 plan — repair gate truth without consuming a terminal gate

Run: `c30-gate-truth-20260811-a1`

Base: `candidate/c30-gate-truth` at retained Cycle 29 source tip
`9df16a33c51ccbb210247c51fc9bbb1207d256ed`.

## Frozen target

- Re-verify and finalize `m24.1`–`m24.3`, `m25.1`–`m25.4`, and
  `m26.1`–`m26.4`; Cycle 29 remains HALTED.
- `m27.1` — READY counts and executes a terminal boundary only when the current
  target has terminal-tier acceptance and no autonomous work remains outside it.
- `m27.2` — nested acceptance commands cannot inherit outer failure-evidence
  authority; a successful top-level pass leaves no stale current-run artifact.
- `m27.3` — a failed promotion publishes the exact bounded blocking path/reason
  in its HALTED report and recovery guidance while leaving user data untouched.
- `m27.4` — READY reuses a just-passed focused matrix only while exact tip,
  worktree cleanliness, and frozen acceptance definitions remain unchanged;
  mutation forces a rerun.
- Terminal certificates `m24.4`, `m25.5`, `c66`, and `c71` remain open for a
  separate fresh Cycle 31 process.

## Carve

One builder owns the coupled memory, runner, READY contract documentation, and
regressions. Splitting these paths would create a shared trust-boundary seam.
The integrator owns exact-tip merge, independent focused verification, bounded
cross-file repair, and truthful cycle-close evidence.

## Frozen focused acceptance

- inherited `m24.1`–`m24.3`, `m25.1`–`m25.4`, and `m26.1`–`m26.4` checks;
- `m27.1`: `bash tests/test-contract-acceptance.sh && bash tests/test-run-stats.sh`;
- `m27.2`: `bash tests/test-memory.sh && bash tests/test-contract-acceptance.sh`;
- `m27.3`: `bash tests/test-promotion-transaction.sh && bash tests/test-write-report.sh`;
- `m27.4`: `bash tests/test-contract-acceptance.sh && bash tests/test-efficiency-canary.sh`.

Use `bin/polylane-check.sh` for unchanged matrices. Changed shell scripts pass
`bash -n`, `shellcheck -S warning`, and `git diff --check`. Do not run the full
suite, installers, doctor rehearsal, push, publication, deployment, or any other
external action.

## Runtime acceptance

Exactly one builder launch and one integrator launch, zero lane/supervisor
restarts, and **zero terminal gates**. The integrator emits GO for this focused
cycle; an accidental READY must still promote without charging a phantom gate.

## Next cycle

Cycle 31 starts from the promoted Cycle 30 tip in a fresh process, targets every
remaining autonomous subgoal, and owns exactly one real terminal command: full
suite, ShellCheck, Claude/Codex parity, fresh installers, and live GO/NO-GO doctor
rehearsal. Only that GO authorizes local installation.
