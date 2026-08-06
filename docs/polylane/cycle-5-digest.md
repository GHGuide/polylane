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

