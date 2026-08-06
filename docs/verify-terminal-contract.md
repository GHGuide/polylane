# Terminal-contract verification

## Scope and provenance

- Worktree: `/Users/leonardo/Downloads/polylane/.polylane/wt/walk-c8-terminal-contract`
- Commit tested: `55213d0ca2831f23ca1226eab823beb70e70e065`
- Run identifier: `walk-c8-20260806-233854`
- Source changes: none. This evidence-only run exercised the committed source.

## Commands and exact current-run output

### `bash tests/test-verdict-repair.sh`

Exit code: `0`

```
PASS gate-repair-keeps-original
PASS gate-repair-points-canonical-transcript
PASS repair-eventually-go
PASS repair-two-waves
PASS repair-polls-each-wave
PASS repair-captures-each-wave
PASS repair-exhaustion-fails
PASS repair-cap-exact
PASS unrepairable-host-gate-stops
PASS unrepairable-gate-read-once
PASS unrepairable-spawns-zero-repairs
Integrator verdict: GO — engineering gate passed; proceeding.
PASS ready-host-gate-passes
PASS ready-host-gate-runs-once
PASS ready-efficiency-proof-runs-once
PASS ready-host-gate-converts-to-go
PASS ready-host-gate-failure-is-not-go
PASS ready-host-gate-failure-runs-once
PASS ready-host-gate-failure-proves-once
PASS ready-host-gate-failure-stops-repair
PASS ready-host-gate-failure-stops-loop
PASS ready-host-gate-failure-loop-runs-once
PASS ready-host-gate-failure-loop-spawns-no-repair
PASS ready-efficiency-proof-failure-is-not-go
PASS ready-efficiency-proof-failure-skips-acceptance
PASS ready-efficiency-proof-failure-is-no-go
PASS ready-efficiency-proof-failure-stops-repair
test-verdict-repair.sh: 26 pass, 0 fail
```

Evidence: the host gate is read once in the unrepairable case, runs once in the ready case, and a host-gate failure remains NO-GO while stopping repair and the loop. The report also records the current-run GO transition.

### `bash tests/test-efficiency-canary.sh`

Exit code: `0`

```
PASS efficiency-gate-capture
PASS efficiency-gate-verify
PASS efficiency-launch-budget
PASS efficiency-one-gate
PASS efficiency-token-truth
PASS efficiency-restart-rejected
PASS efficiency-failure-durable
PASS efficiency-final-capture
PASS efficiency-final-verify
PASS efficiency-unknown-not-zero
PASS efficiency-clean
PASS efficiency-stale-run-rejected
PASS efficiency-dry-run-noop
test-efficiency-canary.sh: 13 pass, 0 fail
```

Evidence: the one-shot efficiency gate, two-lane launch budget, restart rejection, stale-run rejection, durable failure state, and clean teardown all passed.

### `bash tests/test-write-report.sh`

Exit code: `0`

```
PASS go-report-exists
PASS go-verdict-line
PASS go-base-branch
PASS go-lane-row-alpha
PASS go-lane-row-beta
PASS go-merged-text
PASS go-push-step
PASS go-current-root-open-item
PASS go-telemetry
PASS go-telemetry-tokens-unknown
PASS go-ledger-cycle
PASS go-ledger-tokens
PASS nogo-report-exists
PASS nogo-verdict-line
PASS nogo-withheld-text
PASS nogo-nothing-merged
PASS nogo-open-item
PASS nogo-external-item
PASS nogo-integration-open-item
PASS nogo-arbitrary-prose-excluded
PASS nogo-historical-evidence-excluded
PASS nogo-shell-output-excluded
PASS halted-verdict-line
PASS halted-failed-row
PASS halted-retry-hint
test-write-report.sh: 25 pass, 0 fail
```

Evidence: current-run GO and NO-GO reports carry their required verdict, two lane rows, and supported outcome details; arbitrary prose, historical evidence, and shell output are excluded.

## Conclusion

PASS — all three prescribed current-run checks passed: 64 pass, 0 fail. The committed source proves the one-shot host gate, stale-run efficiency rejection, two-lane efficiency-canary clean teardown, and exact GO/NO-GO report evidence.
