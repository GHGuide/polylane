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
