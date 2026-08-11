# Cycle 36 plan — verdict-path recovery

Run: `c36-verdict-path-20260811-a1`

## Frozen target

- `m30.1` / `c82`: import the exact Cycle 35 installer implementation and prove clean
  provider-package upgrades again in this fresh run.
- `m31.1` / `c83`: make runtime prompt compilation role-aware so an integrator writes
  the only current-run verdict sentinel to `docs/verify-integration.md` and keeps
  `docs/status-integrator.md` status-only.

## Red evidence

`bash tests/test-lane-done-live.sh` currently reports exactly two failures:
`runtime-integrator-verdict-has-canonical-path` and
`runtime-integrator-status-forbids-verdict`. The live Cycle 35 transcript reproduces
the consequence: the status file contains GO, the verification file has no sentinel,
and `parse_verdict` returns `UNKNOWN`.

## Lane carve

One builder, `verdict-path-recovery`, owns the retained installer import plus the
prompt compiler/linter, provider-facing handoff documentation, and focused regressions.
The integrator owns merge evidence and the current-run two-file handoff. There is no
cross-builder overlap and no terminal acceptance in this cycle.

## Acceptance and stop rule

Run the frozen focused entries for `m30.1` and `m31.1`, changed-shell syntax and
warning-level ShellCheck, marker/docs consistency, and Claude/Codex skill parity. GO
requires exactly two launches, zero restarts, zero terminal gates, promotion, cleanup,
and a final efficiency proof of `0 / 0`. Any source defect or ambiguous verdict path is
NO-GO; the historical visual corpus remains external and unrelated.
