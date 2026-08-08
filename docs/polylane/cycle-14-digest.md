# Cycle 14 digest — truthful self-hosting

Cycle 14 repaired every concrete orchestration failure exposed by cycle 13, then
proved the repairs through the production promotion path rather than accepting only
fixture-level confidence. Three Codex builders and an integrator completed the wave;
the resulting tree passed 1,892 assertions across 100 test files, ShellCheck, semantic/install
parity, fresh dual installation, 51 frozen acceptances, and physical GO and NO-GO
rehearsals. The verified merge and cleanup completed on `main`. The only open item is
the previously declared external ten-product blind visual corpus.

## What changed

- Made promotion state independent from the language-model verdict.
- Made reports derive merge claims from observed promotion state.
- Made reports derive cleanup claims from observed cleanup state.
- Prevented a favorable verdict from falsely claiming a failed merge succeeded.
- Added a declared allowlist for runner-owned durable files.
- Preserved unrelated user modifications during promotion.
- Preserved unrelated user modifications during cleanup.
- Added transactional restoration when promotion fails.
- Kept failed worktrees and branches available for bounded recovery.
- Allowed current-run skill outcome evidence to cross promotion safely.
- Allowed only the current run's exact per-lane skill-use receipts.
- Preserved the canonical spend ledger as runner-owned durable evidence.
- Rejected unexpected generated or untracked files before promotion.
- Fixed credential scanning so ordinary skill names do not resemble API keys.
- Added a narrow semantic resolver for the declared goal-state file.
- Required immutable goal, criterion, and acceptance definitions to agree.
- Required learning logs to agree before resolving goal-state conflicts.
- Prevented done, external, or passing evidence from regressing.
- Kept every other merge conflict fail-closed.
- Streamed large JSON state comparison instead of exceeding argument limits.
- Proved divergent learning history blocks promotion and restores the base.
- Proved source conflicts block promotion and restore the base.
- Proved unrelated dirty files survive the full transaction.
- Classified a live agent process as positive liveness evidence.
- Distinguished quiet high-effort turns from dead or frozen panes.
- Retained bounded restart behavior for genuinely dead workers.
- Kept effort-aware liveness grace finite.
- Routed worker history through one canonical project root.
- Put worker sequence allocation under the canonical lock.
- Prevented parallel worktrees from allocating duplicate sequence numbers.
- Preserved capsules, requests, decisions, acknowledgements, and messages.
- Kept worker history out of disposable lane worktrees.
- Carried trusted resolved `SKILL.md` paths into selected lane kits.
- Rejected selected skill paths outside approved roots.
- Compiled each selected skill path into its builder prompt once.
- Required builders to produce read/use receipts for selected skills.
- Separated actual use evidence from prompt-name presence.
- Made the rehearsal's counters and mock binaries hermetic.
- Moved rehearsal worktrees under disposable runtime scope.
- Prevented fixture instrumentation from dirtying the promotion base.
- Prevented rehearsal artifacts from leaking after GO cleanup.
- Prevented rehearsal artifacts from leaking after NO-GO retention.
- Made low-disk preflight report precise MiB instead of a misleading `0GB`.
- Added a named cycle-14 self-hosting certification layer.
- Kept Claude and Codex skill semantics aligned.
- Kept Claude and Codex installation output aligned.
- Passed fresh installation for both skill packages.
- Passed the production GO path with promotion and complete cleanup.
- Passed the production NO-GO path with evidence and bounded retention.
- Closed `m14.1` through `m14.5` and criteria `c35` through `c39`.
- Left `m12.4` / `c28` external instead of manufacturing a visual verdict.

**Next:** collect the real ten-product rendered old-vs-new blind corpus for
`m12.4` / `c28`; the frozen tree contains no remaining autonomous engineering work.
