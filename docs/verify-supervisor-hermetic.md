# Supervisor hermeticity verification

## Scope

Worktree: `/Users/leonardo/Downloads/polylane/.polylane/wt/walk-c8-supervisor-hermetic`  
Commit tested: `55213d0ca2831f23ca1226eab823beb70e70e065`

## Current-run evidence

1. Exact command: `POLYLANE_SUP_MAX_RESTARTS=0 bash tests/test-supervisor.sh`  
   Exit code: `0`  
   Summary: `test-supervisor.sh: 22 pass, 0 fail`. The current-run output includes PASS results for revive and halted recovery, external and NO-GO single-launch behavior, needs-user no-loop behavior, lock cleanup, and the zero-restart cap (`sup-cap-rc1`, `sup-cap-halt`, `sup-cap-launches`).

2. Exact command: `bash tests/test-run-stats.sh`  
   Exit code: `0`  
   Summary: `PASS: run stats initialize, resume, usage, snapshot, and concurrency`.

## Conclusion

PASS — Under the outer `POLYLANE_SUP_MAX_RESTARTS=0` policy, the supervisor recovery fixtures are hermetic: all 22 current-run checks passed with no failures. Fresh-run telemetry behavior is run-ID-scoped as exercised by the passing run-stats initialize, resume, usage, snapshot, and concurrency check.
