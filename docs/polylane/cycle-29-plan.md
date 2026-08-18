# Cycle 29 plan — recover active work without scope churn

Run: `c29-active-scope-20260811-a1`

Base: `candidate/c29-runtime-recovery` at recovered Cycle 28 worker tip
`cf60d3c1646dc6a7ae3f76a636be423cef91e9a1`.

## Frozen target

- Re-verify and make durable `m25.1`–`m25.4`; Cycle 28's report remains HALTED.
- `m26.1` — an in-progress structured command suppresses material-progress
  replanning; completed command churn remains bounded and recoverable.
- `m26.2` — resolve every manifest worktree to an absolute physical source root
  before pane export, including project-relative worktrees and escaped paths.
- `m26.3` — detect a committed current-run handoff with invalid lane scope as one
  terminal lane failure, preserving its exact bounded reason and consuming no
  retry, repair, or model budget.
- `m26.4` — add an opt-in planned-write manifest contract used by every newly
  generated Polylane plan; preflight rejects missing, unsafe, duplicate, or
  out-of-scope planned paths before git/tmux side effects.
- `m25.5`, `m24.4`, `c66`, and `c71` remain open for a separate fresh Cycle 30
  terminal run. A process that changes these guards cannot certify itself.

## Carve

One builder owns the coupled runtime, scope checker, planning contract, and
regressions. Splitting `polylane-run.sh` from the scope and manifest contract
would create the same shared-file seam this cycle is repairing. The complete
planned write-set is repeated mechanically in the manifest and is fully covered
by the lane's `own_globs`.

The integrator owns only the exact merge, bounded cross-lane seam repair,
independent focused verification, and cycle-close evidence.

## Frozen focused acceptance

- inherited `m24.1`–`m24.3` matrices from Cycle 28
- inherited `m25.1`–`m25.4` matrices from Cycle 28
- `m26.1`: `bash tests/test-progress-guard.sh && bash tests/test-wedge.sh`
- `m26.2`: `bash tests/test-agent-adapter.sh && bash tests/test-prompt-compiler.sh && bash tests/test-promptlint.sh`
- `m26.3`: `bash tests/test-lane-done-live.sh && bash tests/test-runtime-recovery.sh && bash tests/test-write-report.sh`
- `m26.4`: `bash tests/test-scope.sh && bash tests/test-manifest-validation.sh && bash tests/test-orchestration-contract.sh`

Use `bin/polylane-check.sh` for every matrix. Changed shell scripts must pass
`bash -n`, ShellCheck warning level, and `git diff --check`. No full suite,
installer, doctor rehearsal, push, publication, or external action is allowed.

## Runtime acceptance

The run may use exactly one builder launch and one integrator launch, zero lane
or supervisor restarts, and zero terminal gates. Any restart makes this cycle a
truthful NO-GO and forces a fresh recovery; the runner must not reinterpret it.

## Next cycle

Cycle 30 starts from the promoted Cycle 29 tip in a new process. Its single
runner-owned terminal command executes the full suite, ShellCheck, Claude/Codex
parity, fresh installers, and both live GO/NO-GO doctor rehearsals. Only that
fresh GO authorizes local skill installation.

