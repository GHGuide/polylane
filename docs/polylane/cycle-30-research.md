# Cycle 30 research — gate truth and hermetic evidence

Run: `c30-gate-truth-20260811-a1`

Cycle 29's source is green but its host lifecycle is not. The runner treats every
`READY-FOR-HOST-GATE` handoff as a terminal boundary before determining whether
the current target owns any terminal-tier acceptance. Because older autonomous
goals remained outside the target and the target itself had only focused checks,
no terminal command ran, yet telemetry recorded `terminal_gates=1`.

The focused acceptance command included `tests/test-memory.sh`. The outer memory
checker exported canonical failure-evidence variables, and `_accept_run` passed
them into every child command. The nested test's deliberate failures therefore
looked like current-run host failures. Even though the outer acceptance succeeded,
the artifact remained. Promotion's narrow user-dirt guard correctly rejected it.
The fix must make evidence configuration local to the checker, clear stale
current-phase evidence on a successful top-level pass, and never weaken promotion's
allowlist.

READY currently runs the same focused matrix once before the terminal decision
and again inside `contract_acceptance_gate`. Repetition is justified only if the
integrated tree or frozen acceptance definition changed. An exact committed tip,
clean-worktree fingerprint, and acceptance-definition fingerprint can safely carry
the focused proof across the immediate host boundary; any mutation invalidates it.

Finally, promotion knows the exact rejected path but drops it before report
generation. A bounded runner-owned failure reason must survive to HALTED reports
and next-step guidance without turning arbitrary filenames into Markdown or shell.

Graphify was queried as a free stale navigation cache. Its generic `gate()` nodes
did not expose the coupled runner path, so direct source, the immutable runner log,
and focused regressions are authoritative.
