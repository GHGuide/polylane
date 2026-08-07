# Cycle 10 digest — walk-away truth and economy

Cycle 10 closed the four concrete regressions found after the measured-autonomy expansion. The result is a smaller, more truthful autonomous loop: equivalent terminal gates execute once, every observer agrees on lane completion and session identity, outcome learning always lands in the canonical project, and isolated workers have a real atomic coordination channel. The post-promotion audit then caught and fixed one tmux identity race and one acceptance-tier ambiguity. **Next:** the goal tree is mechanically complete, so stop autonomous building unless a new failing acceptance or an explicit new product goal appears.

- Began from the cycle-9 GO tree with all eight requested product-autonomy improvements merged.
- Limited scope to four observed walk-away regressions instead of reopening product design.
- Added optional stable keys to frozen acceptance checks.
- Rejected malformed acceptance keys before any state mutation.
- Added a supported command for tagging historical acceptance checks.
- Added focused-versus-terminal tier filtering to historical tagging.
- Scoped acceptance-key reuse to one check invocation only.
- Kept unkeyed acceptance checks on their prior always-run behavior.
- Reused the first keyed result across equivalent selected checks.
- Propagated both pass and fail outcomes to keyed duplicates.
- Tagged the two historical full-suite gates with `full-suite-shellcheck`.
- Restricted those tags to terminal entries so focused checks cannot suppress the suite.
- Preserved independent terminal checks that prove different behavior.
- Made state inspection load the same orchestration contract as the runner.
- Made committed current-run markers subject to the same dirty-tree rule everywhere.
- Kept Graphify's owned worktree symlink from creating a false dirty result.
- Made manifest ownership authoritative over an observer's stale session environment.
- Added canonical session identity to control-room snapshots.
- Added the exact watch command to control-room snapshots.
- Rendered text and JSON control-room output from the same snapshot.
- Rooted advanced outcome reads and writes at the manifest's canonical project.
- Prevented adapter execution from another directory from creating a stray outcome ledger.
- Preserved explicit outcome-path overrides for tests and embedding.
- Recorded all three successful builder lane outcomes in the canonical JSONL ledger.
- Added a Bash-3.2-safe append-only coordination helper.
- Added typed request, decision, claim, release, pending, and snapshot operations.
- Used an atomic directory lock for shared coordination writes.
- Made stale-lock recovery reacquire ownership before appending.
- Exported canonical project and coordination paths into every worker pane.
- Fixed nested-run environment precedence so child manifests beat inherited outer paths.
- Updated Claude and Codex prompt contracts to use the live relay.
- Kept `docs/parallel-status.md` as a durable summary rather than pretending it is live IPC.
- Shipped the coordination helper through both installers.
- Preserved Claude/Codex skill parity for the new contract.
- Added regression coverage for all four frozen subgoals.
- Ran builders in three disjoint file-owned worktrees plus one integrator.
- Merged acceptance-economy, state-truth, and coordination-relay lanes successfully.
- Used three independent quality judges at the promotion boundary.
- Passed the live GO rehearsal with promotion and complete cleanup.
- Passed the live NO-GO rehearsal with bounded retention and no promotion.
- Found a real pane-index race during the self-run instead of hiding it.
- Replaced guessed pane indices with indices returned directly by tmux.
- Preserved deterministic pane previews in dry-run mode.
- Added red-green tests proving launch identity follows tmux after renumbering.
- Stopped duplicate integrator creation after pane removal and renumbering.
- Found and fixed terminal-key tagging that could otherwise cross tiers.
- Passed 1,261 assertions across 79 test files with zero failures.
- Passed ShellCheck at warning severity across every runtime script.
- Passed fresh-install, installer, marker-document, and Claude/Codex parity checks.
- Finished at 25/25 subgoals and 22/22 criteria with route `COMPLETE`.

## Operational evidence

Runner verdict GO; three worker lanes; 1,661 seconds wall time; four launches; five
recorded restarts including recovery from the pane-identity race; one terminal gate;
cleanup complete. Token telemetry is unknown, and the report intentionally does not invent
a count or cost.
