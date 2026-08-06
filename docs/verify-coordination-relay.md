# Coordination relay verification

Run from the repository root:

```bash
git diff --check
shellcheck -S warning bin/polylane-coordinate.sh bin/polylane-run.sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/coordination-relay" -- bash tests/test-coordination.sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/coordination-relay" -- bash tests/test-dryrun-pure.sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/coordination-relay" -- bash tests/test-agent-adapter.sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/coordination-relay" -- bash tests/test-prompt-economy.sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/coordination-relay" -- bash tests/test-installers.sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/coordination-relay" -- bash tests/test-skill-parity.sh
```

Evidence recorded in this run:

- `test-coordination.sh`: 17 pass. It proves append-only request/decision/claim/release events, pending/snapshot replay, an exclusive resource claim, stale-lock recovery with reacquisition, and two concurrent writers retaining both events.
- `test-agent-adapter.sh`: 42 pass. It proves each pane receives `%q`-escaped canonical `POLYLANE_PROJECT_ROOT` and `POLYLANE_COORDINATION_FILE` independently of its prompt path.
- `test-installers.sh`: 12 pass. It proves the Codex package contains an executable `scripts/polylane-coordinate.sh` and the shared runner remains identical across packages.
- `test-prompt-economy.sh`: 19 pass; `test-skill-parity.sh`: 19 pass. They prove the helper/environment contract is present in prompts and both skill surfaces.
- `test-dryrun-pure.sh`: 7 pass. It proves dry-run skips the quality gate directly, does not execute a judge helper, does not create an outcome ledger, and leaves target state unchanged.

## DEFERRED

DEFERRED: none
