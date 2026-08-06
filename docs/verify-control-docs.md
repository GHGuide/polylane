# Control-docs verification

## Evidence

- `bash tests/test-dashboard.sh` — PASS: 25 pass, 0 fail.
- `bash tests/test-control-room.sh` — PASS: 10 pass, 0 fail. It accepts the
  exact current-nonce first line with and without a final newline, while
  rejecting bare, mismatched, stale, and first-line-extra markers.
- `bash tests/test-docs-truth.sh` — PASS: 16 pass, 0 fail.
- `bash tests/test-installers.sh` — PASS: 11 pass, 0 fail; the copied benchmark
  sentinel proves a fresh Codex install includes benchmark artifacts.
- `bash tests/test-skill-parity.sh` — PASS: 18 pass, 0 fail.
- `bin/polylane-markers.sh check-docs references/` — PASS.
- `shellcheck -S warning bin/polylane-dashboard.sh` — PASS.

## Design tradeoffs

- The dashboard is a projection: it invokes `polylane-state --json` for lane
  state and joins durable max-state, event, ledger, report, heartbeat, and
  cleanup facts. It does not recreate pane or marker state.
- Unknown durable values remain `null` or `unknown`; spend is not made zero.
- Current-nonce marker parsing remains with runner/state helpers. The dashboard
  therefore accepts the established marker wire format without a final newline
  and has no competing state engine.

## Changed files

- `bin/polylane-dashboard.sh`
- `tests/test-dashboard.sh`, `tests/test-control-room.sh`
- `SKILL.md`, `codex/SKILL.md`, `README.md`
- `references/cycle-9-control-room.md`
- `codex/install.sh`
- `docs/parallel-status.md`

## DEFERRED

DEFERRED: none
