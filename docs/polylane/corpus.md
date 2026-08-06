# STORY SO FAR — corpus through cycle 7

## Earlier (one line each)
cycle 1: Cycle 1 digest — install-test + docs-truth
cycle 2: Cycle 2 digest — explicit execution graph
cycle 3: Cycle 3 digest — authoritative graph runtime
cycle 4: Cycle 4 digest — real walk-away proof

## Recent (verbatim, last 3 cycles)

===== cycle 5 =====
# Cycle 5 digest — measured recovery and prompt economy

## Built

- Missing and inactive Codex panes can be recreated and remapped without duplicate workers.
- Integrators can commit `READY-FOR-HOST-GATE`; only the coordinator runs frozen terminal checks
  and converts the candidate to GO.
- Builder prompts carry the durable goal and exact sub-goal, a worktree-local check cache, and a
  bounded kit of selected installed skills with no post-launch inventory search.
- Durable run telemetry records cumulative wall time, launches, lane/supervisor restarts,
  terminal gates, cleanup, and truthful known-or-unknown token usage across resumes.

## Verified

- Three builders plus one integrator reached GO in 746 seconds with zero retries, approvals, or
  manual tmux intervention.
- Builder usage was 4,316,723 tokens total; this remains too high for such narrow changes and is
  the next optimization signal, not evidence to weaken verification.
- Promoted-tree suite: 1,007 passed, 0 failed across 65 files; ShellCheck clean.
- Live doctor rehearsal passed both GO promotion/cleanup and NO-GO withholding/retention.

## Learned

- The new runtime was merged by a coordinator process loaded before those functions existed, so
  cycle 5 could verify implementation but not the new host-gate path live. A fresh process must.
- Strict prompt improvements correctly broke stale test and rehearsal fixtures. Contract fixtures
  must be generated from the same prompt vocabulary or fail immediately rather than hang.
- The cycle report scraped wrapped prose and a verdict sentinel as open items. Report extraction
  needs structured boundaries instead of heading-adjacent text heuristics.
- Graph execution remains fast; model context and broad implementation turns dominate spend.


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
