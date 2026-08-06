# STORY SO FAR — corpus through cycle 8

## Earlier (one line each)
cycle 1: Cycle 1 digest — install-test + docs-truth
cycle 2: Cycle 2 digest — explicit execution graph
cycle 3: Cycle 3 digest — authoritative graph runtime
cycle 4: Cycle 4 digest — real walk-away proof
cycle 5: Cycle 5 digest — measured recovery and prompt economy

## Recent (verbatim, last 3 cycles)

===== cycle 6 =====
# Cycle 6 digest — canary rejected repair churn

## Built

- The live rehearsal now hands a nonce-bound READY candidate to the outer runner and requires
  exactly one durable terminal gate on GO.
- Report action extraction is a standalone, fixture-tested helper that accepts only explicit
  current-run evidence files and exact action headings.
- The verified integration commit was adopted only after an independent clean run reported
  1,026 passed, 0 failed across 67 files.

## Benchmark result

- The first candidate reached the gate in 412 seconds with 3/3 launches, zero restarts, one gate,
  and no manual intervention; its provisional efficiency proof passed.
- A transient global-suite failure was not logged precisely. The old runtime launched one
  integrator repair and fired a second host gate.
- Final result was correctly NO-GO: 801 seconds, three launches, one restart, two gates, cleanup
  pending, and truthful unknown token usage. Nothing was automatically promoted.

## Learned

- A host terminal gate is a one-shot fact. Model repair cannot make a consumed gate unused; it
  must stop the run and let a fresh run retry from verified source.
- Run telemetry lacked run identity, so a fresh cycle could inherit old launches and gates.
- Terminal acceptance suppressed the failing suite output, forcing diagnosis by reproduction.
- GO report extraction cannot depend on worktrees after cleanup; it must read promoted exact-path
  evidence. NO-GO reports should continue reading retained worktrees.

===== cycle 7 =====
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

===== cycle 8 =====
# Cycle 8 digest — fresh efficiency certificate passed

## Final benchmark

- Outcome: GO, promoted to `main`, final cleanup complete.
- Wall time: 305 seconds against a 900-second budget.
- Execution: three initial launches, zero lane or supervisor restarts, exactly one host terminal
  gate, no approval prompt, and no manual tmux input.
- Token usage: 780,626 total from current-run Codex `turn.completed` events. Compared with cycle 5,
  this is about 82% fewer tokens and 59% less wall time.
- Verification: the hostile zero-restart suite and terminal suite passed; after token-parser
  hardening, the full repository suite passed 1,032 checks across 67 files with zero failures,
  and ShellCheck remained clean for every runtime script.

## Delivered hardening

- Supervisor recovery fixtures now own their retry policy and cannot inherit the outer canary cap.
- Codex usage parsing tolerates warning and prompt lines in pane logs.
- Fresh launches baseline append-only log offsets; repeated lane names no longer count prior cycles,
  while same-run resumes and respawns continue accumulating from the durable boundary.
- Logger attachment now precedes process seeding, closing the early-output loss window.

## Completion

The mechanical goal tree is complete: 13/13 subgoals and 10/10 criteria. The final certificate is
`docs/polylane/efficiency-proof.md`; durable telemetry is `docs/polylane/run-stats.json`.
