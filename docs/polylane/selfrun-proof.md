# Cycle 4 self-run proof

Run: `walk-c4-20260806-210324`

Outcome: GO

## Runtime identity

- Requested integrator: `gpt-5.6-sol`, high effort.
- Fixture models: builders `gpt-5.6-terra`/medium; integrator `gpt-5.6-terra`/high.
- Fixture sessions: isolated `plrh-<pid>` tmux sessions for the GO and NO-GO rehearsals.
- Exact merged lane tips: runtime `3d41c2bdaddb486cb8f7c041664ab8de51caa592`; rehearsal `838f01cde5e601ac8f3ded864b67eabdc7837eb9`.
- Integration merges: `cad1097b9aa84197e2d65fed88f3c91fab0e237d` and `f4cd17bb6c04decd69191cd47444c3890e95b210`.
- Both exact lane tips are ancestors of `HEAD`.

## Evidence

- `bin/polylane-doctor.sh --rehearse`: GO. The host coordinator observed `REHEARSE-GO contract-v2=1 promoted=1 cleaned=1 leaks=0` and `REHEARSE-NOGO contract-v2=1 promoted=0 evidence=1 retained=1 bounded=1 cleaned=1`.
- Full suite: `954 passed, 0 failed, 62 test files` from the integrated commit.
- ShellCheck: passed with no warnings.
- Benchmark sample: warm ready `60ms`; warm append `110ms`; packets `1859ms`, `1833ms`, `1841ms`.
- Graph authority: `test-graph-authority.sh` passed `43` assertions in the full suite; fixture mock verifies compiled graph identity and append-only ledger validity before each launch.
- Seam scan: `bin/polylane-seams.sh scan "$PWD"` exited 0 with no finding.
- Promoted-tree cleanup contract: focused `test-cleanup.sh` passed `12` assertions. Paywall control contract: `test-pane-stalled.sh` passed `5`. Structured current-run report contract: `test-write-report.sh` passed `23`.

## Clean-worktree evidence

Both rehearsal fixtures certified their own promoted-tree contract: GO removed runtime markers, worktrees, and temporary branches; NO-GO retained its evidence and worktrees until the bounded fixture cleanup. The live cycle worktree remains intentionally present until the outer runner promotes and cleans it.
