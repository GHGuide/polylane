# Cycle 7 digest — efficient execution exposed a hostile-environment leak

## Benchmark result

- Two low-effort audit builders and one medium integrator completed in three initial launches,
  with zero restarts, no approval prompt, one terminal gate, and no manual pane input.
- The candidate reached its gate in 151 seconds. The complete run stopped NO-GO after 280 seconds,
  below the 900-second ceiling, with cleanup correctly left pending.
- The host suite reported 1,025 passes and seven failures, all in `test-supervisor.sh`; the one-shot
  gate prevented a repair wave or second terminal run.

## Root cause and fix

- The canary's outer policy intentionally exported `POLYLANE_SUP_MAX_RESTARTS=0`.
- Nested supervisor recovery fixtures inherited that policy, so scenarios requiring one simulated
  recovery were forced to stop after their first launch. The product supervisor was not failing.
- `test-supervisor.sh` now owns its fixture retry policy explicitly. It passes 22/22 both normally
  and with the hostile outer value, and the complete hostile-environment suite passes 1,031/1,031.

## Learned

- Terminal tests must be hermetic against orchestration environment variables, not only filesystem
  state. A canary can otherwise invalidate its own grader.
- The one-shot terminal gate behaved correctly: it retained all worktrees, produced a truthful
  NO-GO report, and spawned no model repair for a consumed host fact.
