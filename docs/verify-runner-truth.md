# Runner truth verification — cycle 14

Scope: m14.1 transactional promotion/reporting and m14.2 process-aware worker liveness.

## RED

- `tests/test-promotion-transaction.sh` initially reproduced runner-owned `max-state.json`/worker-history dirt surviving the verified merge, unrelated `README.md` dirt advancing the base, and a conflict leaving an unfinished merge.
- `tests/test-write-report.sh` initially showed a `GO` verdict reporting that all lanes merged and cleaned after a failed promotion.
- `tests/test-wedge.sh` initially treated a completed `command_execution` event as a terminal agent turn and wedged a quiet high-effort live turn at the medium grace.
- `tests/test-runtime-recovery.sh` preserves the dead-pane recovery boundary while proving a Codex descendant beneath a shell is live, not dead.

## GREEN

- `bash tests/test-promotion-transaction.sh` — 12 pass, 0 fail: narrow runner-owned pre-promotion commit, user-dirt refusal, and conflict abort with unchanged base/index.
- `bash tests/test-write-report.sh` — 31 pass, 0 fail: failed promotion reports “Nothing merged, nothing cleaned”, records a NO-GO ledger row, and cleanup warning never claims cleanup completed.
- `bash tests/test-wedge.sh` — 23 pass, 0 fail: terminal agent messages are distinguished from completed commands; high effort receives a bounded 40-check quiet-turn grace.
- `bash tests/test-runtime-recovery.sh` — 14 pass, 0 fail: live Codex child is retained; missing/renumbered dead-pane recovery still succeeds.
- `shellcheck -S warning bin/polylane-run.sh tests/test-promotion-transaction.sh tests/test-write-report.sh tests/test-wedge.sh tests/test-runtime-recovery.sh` — clean.
- `bash -n bin/polylane-run.sh tests/test-promotion-transaction.sh tests/test-write-report.sh tests/test-wedge.sh tests/test-runtime-recovery.sh` — clean.

All checks above ran through `.polylane/check-cache/runner-truth`. Full suite and physical rehearsal are intentionally left to integration.

## Risk controls

- Auto-commit is limited to the explicit durable runner-state allowlist; unrelated tracked or untracked user edits block before the base ref moves.
- Failed non-fast-forward merges run `git merge --abort`, retain worktrees, and set the observed promotion state to `failed`.
- Report success wording and push guidance require recorded `PROMOTION_STATE=promoted`; cleanup wording requires observed cleanup completion.
- Quiet live turns are bounded by effective effort (low 12, medium 20, high 40, xhigh/max 60), while terminal/error turns and dead panes remain recoverable.

SKILL-EVIDENCE: superpowers:test-driven-development read once from `/Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md`; effect: wrote and ran the promotion/report/wedge reproductions before changing runner logic.

SKILL-EVIDENCE: superpowers:systematic-debugging read once from `/Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/systematic-debugging/SKILL.md`; effect: traced the failures to direct base merge, verdict-derived report text, and overly broad terminal-event matching.

SKILL-EVIDENCE: engineering:debug read once from `/Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/debug/SKILL.md`; effect: isolated reproduction, root cause, and regression boundary for each runner failure.

SKILL-EVIDENCE: operations:risk-assessment read once from `/Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md`; effect: constrained auto-staging to durable runner paths and preserved user worktrees/base on failure.
