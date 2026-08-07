# STORY SO FAR — corpus through cycle 10

## Earlier (one line each)
cycle 1: Cycle 1 digest — install-test + docs-truth
cycle 2: Cycle 2 digest — explicit execution graph
cycle 3: Cycle 3 digest — authoritative graph runtime
cycle 4: Cycle 4 digest — real walk-away proof
cycle 5: Cycle 5 digest — measured recovery and prompt economy
cycle 6: Cycle 6 digest — canary rejected repair churn
cycle 7: Cycle 7 digest — efficient execution exposed a hostile-environment leak

## Recent (verbatim, last 3 cycles)

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

===== cycle 9 =====
# Cycle 9 digest — measured product autonomy

- Started from a fully green cycle-8 tree and deliberately reopened the goal for eight requested improvements.
- Added a versioned five-case corpus of realistic vague product briefs.
- Added isolated benchmark work directories and one JSONL result per case.
- Added completion and product-quality dimensions alongside time, tokens, interventions, and score.
- Preserved unavailable or malformed metrics as `null` instead of zero.
- Rejected malformed, duplicate, incomplete, and infeasible corpus cases.
- Hardened result parsing so wrong-shaped and nested-wrong-shaped JSON stays unknown.
- Added a durable typed discovery graph.
- Added recommended, deeper, bold, and custom answer routes.
- Bounded each discovery round to at most five questions.
- Made deep and bold answers activate child questions.
- Persisted contradictions and blocked strategy locking until resolution.
- Added bounded left/right contradiction resolution.
- Generated transcript-free strategy, north-star, and goal artifacts.
- Split Claude and Codex model discovery.
- Codex model discovery now returns only `gpt-*` IDs.
- Codex manifests reject Claude IDs in lanes, integrator, available models, and overrides.
- Added lean and user Codex profiles.
- Lean launches are ephemeral and ignore user configuration.
- Preserved explicit model, effort, sandbox, approval, prompt, and git metadata access.
- Added prompt byte/token metrics.
- Added mandatory-block and budget admission before launch, respawn, and repair.
- Added installed-only skill resolution to exact `SKILL.md` paths.
- Kept GitHub skill search informational until installation is explicit.
- Bounded executable skill kits to one-to-four skills.
- Added helped, unused, and hurt skill-outcome memory.
- Ranked recommendations from the outcome ledger.
- Wired risk admission through one advanced-runtime adapter.
- Wired mechanical seam evidence through that adapter.
- Kept champion selection and salvage opt-in behind explicit manifest contracts.
- Added exactly three independent quality judges.
- Required unique judge names and lenses.
- Added bounded judge timeouts.
- Staged judge evidence privately and published it atomically.
- Added a typed one-attempt judge-repair packet with aggregate/evidence paths.
- Added judge and judge-repair nodes only when configured.
- Preserved deterministic replay for legacy graphs without judges.
- Added a canonical one-shot control-room JSON schema.
- Rendered text and JSON from the same snapshot.
- Joined goal, graph readiness, lanes, spend, verdict, heartbeat, cleanup, and next action.
- Kept missing facts unknown instead of fabricating success or zero.
- Kept DONE parsing in the runner/state authority rather than the dashboard.
- Repaired the nonce marker newline contract after a worker proposed a contradictory test.
- Repaired scout root precedence and qualified plugin namespace isolation.
- Repaired the live rehearsal fixture to create real `SKILL.md` files.
- Repaired dashboard cleanup precedence to favor durable canonical telemetry.
- Repaired documentation drift for skill-kit bounds and the JSONL ledger path.
- Ran the five-case mock benchmark with zero adapter failures and no unknown metrics.
- Ran all three configured judges successfully with separate evidence.
- Finished with 1,171 passing assertions, zero failures, clean ShellCheck, a passing host GO/NO-GO rehearsal, and runner outcome GO.

## Observed operational costs

Cycle 9 took about 84 minutes, launched five worker turns, restarted twelve times, and reported roughly 58.8 million Codex input tokens. The largest avoidable costs were repeated full-suite terminal acceptances, user-profile plugin startup noise, and completion retries caused by a generated outcome ledger dirtying the integration worktree.

===== cycle 10 =====
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
