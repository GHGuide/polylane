# STORY SO FAR — corpus through cycle 5

## Earlier (one line each)
cycle 1: Cycle 1 digest — install-test + docs-truth
cycle 2: Cycle 2 digest — explicit execution graph

## Recent (verbatim, last 3 cycles)

===== cycle 3 =====
# Cycle 3 digest — authoritative graph runtime

## Built

- Contract-v2 execution now defaults to an authoritative graph scheduler. Every builder,
  join, integrator, verifier, repair, promotion, completion, and halt action is admitted
  only when the immutable graph says its node is ready.
- Codex `workspace-write` receives only the canonical linked-worktree Git metadata path;
  full filesystem access is no longer required for ordinary lanes.
- Event replay uses validated checkpoints while retaining strict fallback after malformed
  sidecars, inode replacement, truncation, or graph/run identity changes.
- Readiness semantics distinguish joins from routed nodes and include bounded loop edges.
- The 10,000-event benchmark fixture now uses only nodes declared by its valid compiled
  64-lane graph.
- Missing owned tmux sessions return a recoverable status for the supervisor.
- Runner-owned `graphify-out` links no longer make clean completed lanes look dirty.
- Post-promotion cleanup failure is now nonfatal, preserves late unverified branches, and
  `--resume` finishes cleanup/report from graph-backed durable evidence.

## Verified

- Three frozen benchmark runs: complete packets 1,836–2,001 ms; warm readiness 61–91 ms;
  warm append 116–120 ms. Independent post-promotion run: 1,864–1,892 ms.
- `tests/run.sh`: 940 passed, 0 failed across 61 test files after recovery hardening.
- `shellcheck -S warning bin/*.sh`: clean.
- Real two-builder + integrator cycle reached GO and promoted to `main`; its interrupted
  cleanup was recovered by the updated production `--resume` path.
- `bin/polylane-doctor.sh --rehearse`: both GO and NO-GO cases passed.

## Learned

- A safe `git branch -d` refusal was incorrectly fatal after promotion; transactional
  boundaries matter more than happy-path test count.
- A worker can produce a late commit after the integrator has captured its verified tip.
  The correct behavior is preserve, report, and continue—not force-delete or fail GO.
- The current rehearsal is still a legacy-contract mock, so it does not yet prove the
  authoritative graph contract end to end.
- Status markers committed for polling become tracked deletions after cleanup.
- Report next-step scraping reads historical examples and commands as if they were current
  actions; it needs structured, run-scoped extraction.
- A pane merely containing the words “usage limit” can be misclassified as a paywall even
  while the agent is discussing source code.

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

