# Cycle 10 research — evidence from the live self-run

## Conclusion

The highest-value research in this cycle was the production run itself. It showed that the remaining autonomy failures were identity and authority failures, not a need for more agents or more prose. A lane is complete only when the runner's canonical contract says so; a pane is the pane tmux actually created, not the number the launcher predicted; a shared result belongs under the manifest's project root; and two expensive checks are equivalent only when an operator-assigned key says they are equivalent at the same acceptance tier.

## Findings

1. **Runtime identity must be returned, not inferred.** Tmux renumbers panes after deletion. The launcher previously advanced a local counter and could assign an integrator to a non-existent pane, after which the supervisor launched a duplicate. `new-session` and `split-window` now return `#{pane_index}` directly, and the runtime map stores that value.
2. **Acceptance economy needs explicit semantic identity.** Command-text similarity is unsafe, while broad memoization can cache a false pass. Stable keys deduplicate only within one invocation, and tier filtering prevents a cheap focused check from standing in for a terminal suite.
3. **Observers cannot reconstruct authority independently.** State, dashboard, and runner now share marker, dirtiness, project-root, and session rules. The control room projects canonical state; it does not become another state machine.
4. **Cross-worktree coordination needs canonical storage and locking.** A repository file inside each worktree is not shared. The new JSONL relay lives at the canonical run root and uses an atomic lock, while durable summaries are written only after integration.
5. **Generated learning data must not poison completion.** Outcome telemetry now resolves from the manifest even when an adapter runs from another directory, preventing a generated ledger from dirtying a lane worktree and invalidating its DONE marker.

## Ranked future research

1. Measure real Codex token telemetry across a release benchmark; current live-run telemetry is still unknown.
2. Accumulate enough outcome rows to evaluate whether lane-shape model tuning beats the static effort presets.
3. Add held-out vague-product benchmark cases only when they expose a concrete failure, avoiding benchmark theater.
4. Test coordination claims under process death and stale-lock recovery on Linux as well as macOS Bash 3.2.
5. Compare deterministic judges with opt-in model judges on user-journey defects that tests cannot express.

These are informational release experiments, not open requirements for the completed goal.
