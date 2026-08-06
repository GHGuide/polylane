# STORY SO FAR — corpus through cycle 6

## Earlier (one line each)
cycle 1: Cycle 1 digest — install-test + docs-truth
cycle 2: Cycle 2 digest — explicit execution graph
cycle 3: Cycle 3 digest — authoritative graph runtime

## Recent (verbatim, last 3 cycles)

===== cycle 4 =====
# Cycle 4 digest — real walk-away proof

## Built

- The contract-v2 rehearsal now executes real supervised GO and NO-GO lifecycles. GO promotes
  and cleans; NO-GO withholds promotion, retains evidence, bounds repair, then cleans its fixture.
- Runtime paywall detection requires an actionable credits/upgrade decision instead of matching
  source or prose that happens to say “usage limit”.
- Cleanup canonicalizes macOS `/var` and `/private/var` worktree paths and accepts intentional
  durable goal-state updates while still rejecting leaked runtime markers.
- Graph and event CLIs run on Apple jq as well as Homebrew jq; the benchmark harness now does too.
- A failed verifier can resume through the declared repair loop when committed current-run GO
  evidence proves the repair finished before the prior runner died.
- Fresh-clone installers and session tests distinguish a real product failure from a worker
  sandbox that cannot write the project or open the host tmux socket.

## Verified

- Real two-builder + integrator Codex cycle reached a legitimate supervised GO and promoted.
- `tests/run.sh`: 954 passed, 0 failed across 62 test files; ShellCheck clean.
- Host rehearsal: `REHEARSE-GO ... promoted=1 cleaned=1 leaks=0`; `REHEARSE-NOGO ...
  promoted=0 evidence=1 retained=1 bounded=1 cleaned=1`.
- Homebrew jq: ready 62 ms, append 116 ms, full packet 1,861–1,882 ms.
- Apple jq: ready 54 ms, append 109 ms, full packet 1,845–1,870 ms.

## Learned

- Graph execution is not the current bottleneck. Prompt breadth, repeated skill reads, repeated
  terminal suites, dead-pane recovery, and lost resume telemetry dominate time and tokens.
- A live Codex PID is not proof of progress: one worker wedged after a skills-context error and
  stayed “working” indefinitely until externally interrupted.
- `tmux respawn-pane` against a vanished pane fails, but the old fallback sent keys to that same
  nonexistent target and still consumed retries. Recovery must recreate and remap the pane.
- Worker sandboxes cannot truthfully grade host-only tmux behavior. They need an explicit
  host-gate handoff; only the outer runner should execute and certify terminal host checks.
- The canonical project `.polylane/check-cache` is outside a linked worktree's write sandbox.
  The cache must live inside the lane worktree.
- Cycle reporting lost prior-run token and wall evidence on resume, rendering unknown as zero.
  Metrics need an append-only per-run snapshot independent of one runner process.

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

