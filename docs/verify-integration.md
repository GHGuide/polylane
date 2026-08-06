# Walk C6 integration verification

Run: `walk-c6-20260806-225228`
Integrator branch: `codex/walk-c6-integrator`

## Merged lane tips

- `codex/walk-c6-host-canary` — `2064b3c`
- `codex/walk-c6-report-truth` — `6efd4ce`

## Report-item wiring

`report_open_items` now passes only explicit current-run paths to
`bin/polylane-report-items.sh`: each lane worktree's
`docs/verify-<lane>.md`, plus the integrator worktree's
`docs/verify-integration.md`. It no longer scans repository-root historical
evidence. The report fixture proves lane, external, and integration items are
included from those paths while a historical root file is excluded.

## Graph path query

The single Graphify query for the report/gate path identified
`report_open_items()` and `merge_gate()` in `bin/polylane-run.sh`. The gate
recognizes the run-tagged `READY-FOR-HOST-GATE` candidate and records
`terminal_gates` before frozen host acceptance; no graph rebuild was run.

## Rehearsal candidate contract

The merged rehearsal success path writes exactly
`POLYLANE-VERDICT: READY-FOR-HOST-GATE run=<nonce>` and its GO assertion
requires durable `docs/polylane/run-stats.json` telemetry to report
`terminal_gates=1`, alongside promotion and clean teardown. The live tmux
terminal acceptance is host-only evidence for the outer coordinator.

## Focused verification

All test commands were cache-routed through
`bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator/" --`.

- `bash tests/test-rehearse.sh` — 5 pass, 0 fail (live rehearsal correctly
  remains gated to the outer host acceptance).
- `bash tests/test-report-items.sh` — 1 pass, 0 fail.
- `bash tests/test-efficiency-canary.sh` — 12 pass, 0 fail.
- `bash tests/test-write-report.sh` — 25 pass, 0 fail.
- `shellcheck -S warning bin/polylane-run.sh bin/polylane-report-items.sh` —
  clean.

## Review

The integration diff has one runner seam: it preserves the existing report
deduplication and limit while delegating extraction to the exact-path helper.
No untrusted path expansion or repository-wide evidence discovery remains in
that call path. No frozen acceptance or efficiency budget changed.

POLYLANE-VERDICT: READY-FOR-HOST-GATE run=walk-c6-20260806-225228
