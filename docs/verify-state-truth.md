# State truth verification

## Commands

All commands ran from the repository root on 2026-08-07 and exited 0.

```bash
bin/polylane-check.sh "$PWD/.polylane/check-cache/state-truth" -- \
  shellcheck -S warning bin/polylane-state.sh bin/polylane-dashboard.sh \
  bin/polylane-advanced.sh bin/polylane-outcomes.sh
bash tests/test-state.sh && bash tests/test-dashboard.sh
bash tests/test-outcome-rooting.sh && bash tests/test-advanced-runtime.sh
```

The focused suites reported 19, 41, 6, and 19 passing assertions respectively.
The targeted diff review found no remaining correctness, security, performance,
or maintainability issue.

## Adversarial cases

- A contract-v2 current-nonce DONE marker with an uncommitted lane file is
  `likely-done(verify me)` in state and false from the runner's `lane_done`.
- A stale observer `POLYLANE_SESSION` cannot override the manifest-owned
  session or its live watch command.
- Dashboard JSON includes `session` and `watch`; its text hint remains `-`
  when a stale environment requests a different session.
- Recording outcomes from a foreign cwd writes under the manifest project,
  leaves no foreign `docs/polylane/outcomes.jsonl`, and honors explicit
  outcomes/hubs overrides.
- The sourced runner's `advanced_runtime record` preserves that canonical
  outcome root from a foreign observer cwd.

## Coordination

`POLYLANE_COORDINATION_FILE` and `bin/polylane-coordinate.sh` were not both
available. Request recorded: integrator should retain these focused-test and
lint results when assembling the cycle evidence.

## DEFERRED

DEFERRED: none
