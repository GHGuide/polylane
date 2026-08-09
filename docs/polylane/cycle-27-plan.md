# Cycle 27 plan — repair, promote, then certify fresh

Run: `c27-gate-repair-20260810-a1`

Base: `candidate/c27-repair` at Cycle 26 integration tip `d8b9417`

## Frozen target

- `m24.1` — optional integrator kits are a true no-op unless any integrator skill
  is armed; a non-empty kit receives full trusted-path/fingerprint validation.
- `m24.2` — the runner's one exact committed status-marker rename remains
  compatible with completed-branch scope enforcement without creating a general
  out-of-scope bypass.
- `m24.3` — every failed acceptance command retains a bounded run-scoped output
  log, and host-gate evidence/report points to it.
- `m24.4` — fresh process certification remains open and is explicitly outside
  this repair cycle.

## Carve

One builder owns the coupled scout/runner/memory and focused regression surfaces.
Splitting them would force two lanes to edit `bin/polylane-run.sh` and the same gate
tests, so the lane-carving rule requires one lane. The integrator owns only merge,
bounded seam repairs, and Cycle 27 evidence.

## Frozen focused acceptance

- `m24.1`: `bash tests/test-manifest-validation.sh && bash tests/test-cycle-13-contract.sh && bash tests/test-scout.sh && bash tests/test-orchestration-contract.sh`
- `m24.2`: `bash tests/test-status-marker-normalization.sh && bash tests/test-lane-done.sh && bash tests/test-lane-done-live.sh && bash tests/test-scope.sh`
- `m24.3`: `bash tests/test-memory.sh && bash tests/test-contract-acceptance.sh && bash tests/test-verdict-repair.sh && bash tests/test-write-report.sh`

The integrator may run affected matrices and changed-script ShellCheck through its
local cache. The runner must observe exactly two launches, zero restarts, and
**zero terminal gates**. It may promote only a focused-green READY handoff. No
full suite, doctor rehearsal, installers, push, deployment, or publication occurs
in Cycle 27.

## Next cycle

Cycle 28 starts a new process from the promoted repair tip and spends one terminal
gate on the full suite, ShellCheck, parity, installers, and live GO/NO-GO doctor
rehearsal. A failure remains NO-GO and its exact command output must already be
available without rerunning the suite.

