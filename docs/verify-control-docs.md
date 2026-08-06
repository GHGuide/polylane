# Control-docs verification

## Evidence

- `bash tests/test-dashboard.sh` — PASS: 25 pass, 0 fail.
- `bash tests/test-installers.sh` — PASS: 11 pass, 0 fail; the copied benchmark
  sentinel proves a fresh Codex install includes benchmark artifacts.
- `bash tests/test-skill-parity.sh` — PASS: 18 pass, 0 fail.
- `bash tests/test-docs-truth.sh` — PASS: 16 pass, 0 fail.
- `bin/polylane-markers.sh check-docs references/` — PASS.
- `shellcheck -S warning bin/polylane-dashboard.sh` — PASS.
- `bash tests/test-control-room.sh` — BLOCKED: 8 pass, 1 fail. The no-newline
  current-nonce marker is reported `done` by the shared runner/state authority.

## Design tradeoffs

- The dashboard is a projection: it invokes `polylane-state --json` for lane
  state and only joins durable max-state, event, ledger, report, heartbeat, and
  cleanup facts. It does not recreate pane or marker state.
- Unknown durable values stay `null` or `unknown`; spend is not made zero.
- The dashboard does not locally reject the shared helper's no-newline result,
  because that would create a competing marker authority. The frozen-boundary
  correction is requested in `docs/parallel-status.md`.

## Changed files

- `bin/polylane-dashboard.sh`
- `tests/test-dashboard.sh`, `tests/test-control-room.sh`
- `SKILL.md`, `codex/SKILL.md`, `README.md`
- `references/cycle-9-control-room.md`
- `codex/install.sh`

## DEFERRED

DEFERRED: quality-runtime must make the runner/state marker authority reject a
current-nonce marker without a terminating newline; then rerun the required
control-room test and full focused cadence before committing this lane.
