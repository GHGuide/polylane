# Runtime truth verification — Cycle 28

Run: `c28-watchdog-truth-20260810-a1`  
Scope: `runtime-truth`

## Repair attempt 1 reflection

What went wrong: the prior attempt stopped after broad verification and did not close the addressed integrator failure-reason gaps or complete finalization.
Root cause: reporting iterated only builder lane names, so an integrator reason stored by health recovery never reached a report row or guidance.
Different approach: freeze the integrator health-to-report path, make the smallest reporting repair, run only the affected cached matrices, and finalize in the prescribed order.

## Root cause and red/green evidence

Cycle 27 classified a live high-effort Codex turn as wedged after the old
40-check cap (about 400 seconds at its ten-second health interval). The durable
latest boundary was `turn.started`; PID liveness was real but was not treated as
progress. `tests/test-wedge.sh` was made red for that exact boundary and then
green: it holds at check 40, derives the high-effort ceiling as 180 checks at a
ten-second interval, and still trips an explicit 60-second hard cap.

`tests/test-runtime-recovery.sh` additionally proves stored reasons for both a
missing mapped pane and a live-turn cap. `tests/test-write-report.sh` proves a
live-turn report row uses that reason and does not recommend a provider status
page. Repair attempt 1 added the missing integrator path: health recovery now
stores `live turn silence cap exhausted after 60s` under `INT_NAME`, and the
HALTED table plus next steps render that exact reason without provider-status
guidance (red: 2 report assertions missing; green: 20 recovery and 51 report
assertions).

## Timing semantics

Production defaults are elapsed seconds: low 300, medium/default 900, high 1800,
and xhigh/ultra/max 3600. `lane_live_wedge_checks` computes
`ceil(effective_seconds / health_interval)`; invalid/zero intervals fall back to
15 seconds. `POLYLANE_LIVE_WEDGE_SECONDS` and legacy
`POLYLANE_LIVE_WEDGE_CHECKS` may extend a tier, while
`POLYLANE_LIVE_WEDGE_HARD_SECONDS` (default 3600) is a finite upper bound.
Active commands remain immune, and completed/failed/error turns retain the short
durable-progress path. Live-turn diagnostics name the effective quiet duration.

## Failure reason contract

`mark_lane_failed` stores one bounded per-lane reason and prevents duplicate lane
entries. The runner records: `usage wait exhausted`, `no fallback`,
`material-progress replans exhausted`, `mapped pane missing past retries`,
`live turn silence cap exhausted after <seconds>s`, or
`transient/dead/wedged retries and repairs exhausted: <actual cause>`. Integrator
reason storage uses the same contract. Direct legacy test setup
of `FAILED_LANES` keeps the historic `errored after retries` report text.
Reports and next steps read the stored reason; only the generic transient/dead/
wedged category mentions provider status.

## Token accounting

Legacy `.tokens` remains the aggregate per-completion total: use `total_tokens`
when present, otherwise `input_tokens + output_tokens`. Independently observed
fields accumulate under `.usage.input_tokens`, `.usage.cached_input_tokens`,
`.usage.output_tokens`, and `.usage.reasoning_output_tokens`. Per-completion
uncached input is `max(input_tokens - cached_input_tokens, 0)` and accumulates
only when both source values are present. Missing fields remain absent/null rather
than fabricated as zero. The append-only offset and first-run trailing completion
limit are unchanged, so unseen valid current-run completions count once; noisy,
partial, zero-usage, resume, and old state-file behavior remains compatible.
Snapshots and reports include the compact breakdown.

## Source/control-root trust

Each pane command shell-escapes and exports `POLYLANE_SOURCE_ROOT` as its exact
lane worktree. `POLYLANE_PROJECT_ROOT` remains the canonical coordination root.
Compiled prompts remove prior runtime-roots copies and inject exactly one contract:
source edits/tests/Graphify queries use the source root; coordination, workers,
and harness use the project root. Prompt lint requires that single contract and
the source-root Graphify path. Adapter coverage proves stale ambient root values
cannot override either runner-derived value.

## Focused verification

All commands used `bin/polylane-check.sh "$PWD/.polylane/check-cache/runtime-truth" --`.

- m25.1: wedge + runtime recovery + pane errors: 66 assertions, pass.
- m25.2: report + runtime recovery: 71 assertions, pass.
- m25.3: run stats + report + efficiency canary: run-stat contract plus 76 assertions, pass.
- m25.4: agent adapter + prompt compiler + orchestration contract + prompt lint: 110 assertions, pass.
- Inherited m24.1 manifest/scout/orchestration/dry-run matrix: pass.
- Inherited m24.2 status-normalization/lane-DONE/scope matrix: pass.
- Inherited m24.3 memory/acceptance/verdict/report matrix: pass.

`bash -n` and `shellcheck -S warning` passed for the three changed shell scripts.
`git diff --check` passed. Diff review confirmed exactly the owned runner,
telemetry, prompt-lint, and focused-test seams; no full suite, installer, doctor
rehearsal, push, deployment, or external action was run.

## Skill receipts

SKILL-READ: superpowers:systematic-debugging | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/systematic-debugging/SKILL.md | 4111822586-9465

SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md | 1657109997-9015

SKILL-EVIDENCE: superpowers:systematic-debugging — helped: traced the false halt from latest `turn.started` through the count-based watchdog and generic report state.

SKILL-EVIDENCE: superpowers:test-driven-development — helped: the watchdog, usage, report, source-root, and failure-reason regressions were first observed failing before their corresponding production changes.
