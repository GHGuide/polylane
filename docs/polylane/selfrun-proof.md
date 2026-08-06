# Cycle 4 self-run proof

Run: `walk-c4-20260806-210324`

Outcome: NO-GO

## Runtime identity

- Requested integrator: `gpt-5.6-sol`, high effort.
- Fixture models: builders `gpt-5.6-terra`/medium; integrator `gpt-5.6-terra`/high.
- Fixture session: `plrh-<pid>`; no session was created in this host because tmux socket creation was denied.
- Exact merged lane tips: runtime `3d41c2bdaddb486cb8f7c041664ab8de51caa592`; rehearsal `838f01cde5e601ac8f3ded864b67eabdc7837eb9`.
- Integration merges: `cad1097b9aa84197e2d65fed88f3c91fab0e237d` and `f4cd17bb6c04decd69191cd47444c3890e95b210`.
- Both exact lane tips are ancestors of `HEAD`.

## Evidence

- `bin/polylane-doctor.sh --rehearse`: NO-GO. GO fixture reached strict contract-v2 preflight, then tmux returned `Operation not permitted` before mock launch.
- Full suite: `943 passed, 11 failed, 62 test files`. Failures are six `test-installers.sh` checks blocked from creating repo `.codex/`, and five `test-session-resume.sh` checks blocked from tmux socket access.
- ShellCheck: passed with no warnings.
- Benchmark sample: warm ready `60ms`; warm append `110ms`; packets `1859ms`, `1833ms`, `1841ms`.
- Graph authority: `test-graph-authority.sh` passed `43` assertions in the full suite; fixture mock verifies compiled graph identity and append-only ledger validity before each launch.
- Seam scan: `bin/polylane-seams.sh scan "$PWD"` exited 0 with no finding.
- Promoted-tree cleanup contract: focused `test-cleanup.sh` passed `12` assertions. Paywall control contract: `test-pane-stalled.sh` passed `5`. Structured current-run report contract: `test-write-report.sh` passed `23`.

## Clean-worktree evidence

Not clean at certification: integration repair sources, this evidence, and `graphify-out/` are present. No clean promoted-tree GO fixture exists because tmux cannot create its Unix socket in this sandbox.

This is not a GO claim. Re-run on a host that permits tmux Unix sockets and repo-scoped `.codex/` writes.
