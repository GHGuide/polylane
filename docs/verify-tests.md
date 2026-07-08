# verify — tests lane

Test suite for bin/polylane-run.sh (sourced as a library; guarded main).

- Command: `/bin/bash tests/run.sh` (GNU bash 3.2.57, macOS system bash — no framework deps)
- Result: **112 passed, 0 failed, 8 test files** — exit code 0
- Date: 2026-07-08 15:20

## Coverage (frozen contracts only)

| File | Function under test | Assertions |
|---|---|---|
| test-abs-prompt.sh | abs_prompt | 6 |
| test-intensity.sh | preset_effort / preset_model / model_available / apply_overrides | 20 |
| test-lane-done.sh | lane_done (DONE detect) | 8 |
| test-load-manifest.sh | load_manifest (schema load incl effort/available_models) | 26 |
| test-pane-errored.sh | pane_errored (tmux mocked via PATH shim) | 14 |
| test-parse-args.sh | parse_args (CLI parse, exit 2 paths) | 15 |
| test-parse-verdict.sh | parse_verdict (GO/NO-GO/UNKNOWN/missing) | 7 |
| test-write-report.sh | write_report (GO / NO-GO / HALTED) | 16 |

## Full output

```
== test-abs-prompt.sh ==
PASS abs-passthrough
PASS abs-root-slash
PASS rel-anchored
PASS rel-bare-name
PASS rel-dot-prefix
PASS rel-follows-project-root
test-abs-prompt.sh: 6 pass, 0 fail

== test-intensity.sh ==
PASS effort-economy
PASS effort-balanced
PASS effort-performance
PASS effort-max
PASS effort-unknown-rc1
PASS model-available-hit
PASS model-available-miss
PASS preset-economy
PASS preset-balanced
PASS preset-performance
PASS preset-max
PASS preset-unknown-rc1
PASS preset-fallback-first-available
PASS ov-noop
PASS ov-intensity-all
PASS ov-model-beats-intensity
PASS ov-unknown-preset-exit2
PASS ov-empty-models-exit1
PASS ov-unknown-lane-exit2
PASS ov-malformed-exit2
test-intensity.sh: 20 pass, 0 fail

== test-lane-done.sh ==
PASS done-valid
PASS done-wrong-name
PASS done-missing-file
PASS done-empty-file
PASS done-not-first-line
PASS done-leading-space
PASS done-trailing-text
PASS done-no-trailing-newline-not-done
test-lane-done.sh: 8 pass, 0 fail

== test-load-manifest.sh ==
PASS manifest-base
PASS manifest-project-root
PASS int-name
PASS int-model
PASS int-branch
PASS int-worktree
PASS int-effort
PASS int-prompt-abs
PASS models-count
PASS models-0
PASS models-2
PASS lanes-count
PASS lane0-name
PASS lane1-name
PASS lane0-model
PASS lane1-model
PASS lane0-branch
PASS lane0-worktree
PASS lane0-effort-present
PASS lane1-effort-absent
PASS lane0-prompt-anchored
PASS lane1-prompt-anchored
PASS lane0-pollspec
PASS lane1-pollspec
PASS int-effort-null-maps-empty
PASS models-absent-empty
test-load-manifest.sh: 26 pass, 0 fail

== test-pane-errored.sh ==
PASS err-api-error
PASS err-500-internal
PASS err-503-error
PASS err-overloaded
PASS err-rate-limit-space
PASS err-rate-limit-hyphen
PASS err-ratelimit-joined
PASS err-connection
PASS err-network
PASS err-status-page
PASS err-case-insensitive
PASS ok-clean-pane
PASS ok-benign-noise
PASS err-negative-index
test-pane-errored.sh: 14 pass, 0 fail

== test-parse-args.sh ==
PASS args-manifest-only
PASS args-dry-run
PASS args-yes
PASS args-both-flags
PASS args-intensity
PASS args-intensity-eq
PASS args-model-repeat
PASS args-none-exit2
PASS args-unknown-flag-exit2
PASS args-missing-manifest-exit2
PASS args-extra-positional-exit2
PASS args-intensity-no-value-exit2
PASS args-help-exit0
PASS args-long-help-exit0
PASS args-dashdash-manifest
test-parse-args.sh: 15 pass, 0 fail

== test-parse-verdict.sh ==
PASS verdict-go
PASS verdict-no-go
PASS verdict-unknown
PASS verdict-missing-file
PASS verdict-no-go-wins-same-line
PASS verdict-go-word-boundary
PASS verdict-last-line-wins
test-parse-verdict.sh: 7 pass, 0 fail

== test-write-report.sh ==
PASS go-report-exists
PASS go-verdict-line
PASS go-base-branch
PASS go-lane-row-alpha
PASS go-lane-row-beta
PASS go-merged-text
PASS go-push-step
PASS go-no-open-items
PASS nogo-report-exists
PASS nogo-verdict-line
PASS nogo-withheld-text
PASS nogo-nothing-merged
PASS nogo-open-item
PASS halted-verdict-line
PASS halted-failed-row
PASS halted-retry-hint
test-write-report.sh: 16 pass, 0 fail

SUMMARY: 112 passed, 0 failed, 8 test files
```
