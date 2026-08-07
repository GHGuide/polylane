# Cycle 11 digest — continual harness and bounded self-improvement

Cycle 11 added the useful Prime-Agent/RLM pattern without surrendering Polylane's frozen evidence boundary: local harness state can learn from repeated runtime evidence, stable workers retain bounded context and durable inboxes, and every lane receives a deterministic source-attributed packet. A queued improvement is never silent or self-authorizing—the integrator must propose a check-backed local change or explicitly decline it, later-cycle validation rolls regressions back, and global prompt/skill changes still pass the isolated skill-evolution gate. **Next:** the expanded goal tree is mechanically complete; stop unless a new executable failure or explicit product goal appears.

- Added versioned local/global harness records with atomic compare-and-swap CRUD.
- Protected immutable base instructions and conflict boundaries.
- Added exact-snapshot rollback with append-only history.
- Added typed repeated evidence for failures, stalls, NO-GOs, and compaction.
- Required at least two observations before a local refinement becomes eligible.
- Added a deduplicated refinement queue keyed to each handled repeated-signal boundary.
- Required the integrator to propose or decline every queued item before DONE.
- Added explicit decline evidence; later observations reopen the subject.
- Required every proposal to declare a bounded executable expected check.
- Validated proposals only in a later cycle.
- Rolled failed or expired proposals back to their immutable snapshots.
- Kept global prompt and skill proposals inactive.
- Routed global changes through `polylane-skill-evolve.sh` and its frozen corpus.
- Added stable named worker capsules with optimistic concurrency control.
- Added bounded summaries, next actions, evidence pointers, and cycle state.
- Added an append-only per-worker inbox with acknowledgement and relay import.
- Rejected secret-like content from capsules and messages.
- Added deterministic, source-attributed, hard-bounded context packets.
- Preserved the ultimate goal, current subgoal, worker capsule, and pending inbox.
- Generated canonical packets before panes launch and exported their paths.
- Made legacy manifests remain inert and dry-runs remain pure.
- Added prompt lint and runner preflight enforcement for prime-hybrid continuity.
- Fixed tmux pane-renumber recovery to rebind by canonical worktree identity.
- Preserved retry, repair, stall, wedge, and progress state across a rebind.
- Prevented a second integrator from entering the same worktree.
- Fixed direct-GO terminal gate accounting.
- Counted READY host boundaries before the efficiency certificate and exactly once.
- Corrected cycle-11 telemetry to one terminal gate.
- Passed 1,552 assertions across 86 test files with zero failures.
- Passed ShellCheck at warning severity across every runtime script.
- Passed fresh Claude/Codex installer and skill-parity checks.
- Passed the environment doctor with 9 PASS, 2 expected workspace warnings, 0 FAIL.
- Passed live GO rehearsal: READY observed, promoted, one terminal gate, clean teardown.
- Passed live NO-GO rehearsal: no promotion, evidence retained, bounded work, clean teardown.
- Finished at 29/29 subgoals and 27/27 criteria with route `COMPLETE`.

## Operational evidence

The production self-run promoted three builder lanes through one integrator in 2,453 seconds.
Telemetry records four launches, ten supervised restarts, one terminal gate, complete cleanup,
and 54,577,070 observed tokens. The post-promotion hardening suite and hermetic live rehearsal
then proved the two defects found in that run are fixed.
