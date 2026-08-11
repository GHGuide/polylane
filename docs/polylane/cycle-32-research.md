# Cycle 32 research — terminal contract drift

Run: `c32-contract-drift-20260811-a1`

Cycle 31 reached the host terminal gate with correct telemetry: two launches, zero
restarts, and one terminal event. The full suite reported 2,444 passes and five
failures, all reproduced independently in two files.

`load_manifest` now passes every lane and integrator worktree through
`abs_worktree`, which is required by `m26.2` and keeps pane identity independent of
cwd. Four old test expectations still assert relative paths and poll specs. Runtime
behavior is correct; the regression fixture must assert the absolute path rooted at
its fixture project.

`references/prompt-blocks.md` still tells builders to leave the expensive full
terminal gate for integration/final certification and tells integrators that the
runner owns eligibility. The economy regression additionally freezes the exact
phrase `only coordinator-owned terminal checks remain`; that sentence disappeared
during prompt compaction. Restore it once in block G without reintroducing a generic
skill stack or adding prompt bulk.

No production Bash change, terminal command, installer, rehearsal, push, or local
skill installation belongs in this cycle.

