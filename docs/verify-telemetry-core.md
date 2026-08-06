# Telemetry core verification

## Red / green

`tests/test-run-stats.sh` was first run with the helper absent and failed at the expected missing executable. The helper was then implemented and the focused test passed through the worktree-local check cache.

## Resume and data fidelity

The hermetic fixture initializes at epoch 100, initializes again at 150, and verifies that `started_at` remains 100 while durable wall time advances. It records a launch, lane restart, supervisor restart, two terminal gates, and cleanup warning; the snapshot at 300 reports cumulative 200 seconds.

Structured `turn.completed` JSON captures both `input_tokens + output_tokens` and `total_tokens`. Repeating capture from offset zero does not add prior records. A valid zero-token completion preserves the known total instead of fabricating a value. Before usable usage is observed, the state holds `tokens: null` and `token_state: "unknown"`.

## Concurrency

Twelve concurrent terminal-gate writers use the helper's mkdir lock and atomic same-directory replacement. The fixture verifies all 12 increments remain durable.

## Commands

```text
bin/polylane-check.sh "$PWD/.polylane/check-cache/telemetry-core" -- bash tests/test-run-stats.sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/telemetry-core" -- shellcheck -S warning bin/polylane-run-stats.sh
```

## DEFERRED

- Runner, supervisor, and report wiring remain with the integrator.
