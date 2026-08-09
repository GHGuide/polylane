# Pane identity verification

## Red reproduction

On 2026-08-10, a private nonce-isolated tmux server hosted a pane whose process
cwd was `/private/tmp` while its `@polylane_run_id`, `@polylane_lane`, and
`@polylane_worktree` identified this worktree. The old cwd-only discovery could
not match it: `RED: cwd-only observer cannot discover tagged drifted pane`.

## API invariants

- `polylane_tmux_tag_pane SESSION PANE RUN_ID LANE WORKTREE` canonicalizes an
  existing worktree and writes all three pane-local identity options.
- `polylane_tmux_find_pane SESSION RUN_ID WORKTREE` first accepts a complete
  matching nonce/worktree tag. A partial tag, wrong run, or mismatched worktree
  is never eligible; a same-worktree conflict suppresses cwd adoption.
- Only a fully untagged pane can be adopted through canonical `pane_current_path`.
- State and supervisor now use the shared finder. State still obtains and emits
  the pane command; neither observer writes tmux state.

## Focused evidence

- `tests/test-tmux-runtime.sh`: 11 pass, 0 fail (including real private-tmux
  cwd drift and untagged legacy fallback).
- `tests/test-state.sh`: 19 pass, 0 fail.
- `tests/test-supervisor.sh`: 32 pass, 0 fail.
- `shellcheck -S warning bin/polylane-tmux.sh bin/polylane-state.sh bin/polylane-supervisor.sh`: pass.

All checks ran via `.polylane/check-cache/pane-identity`.

## Exact diff

`bin/polylane-tmux.sh` adds canonical path, tag, and fail-closed finder helpers.
`bin/polylane-state.sh` and `bin/polylane-supervisor.sh` replace cwd-only pane
lookup with the helper. `tests/test-tmux-runtime.sh` adds the real-tmux drift and
legacy regression coverage; `tests/test-supervisor.sh` updates its manifest nonce
fixture. The implementation diff is 73 insertions and 34 deletions across five files.

## Skill receipts

SKILL-READ: engineering:debug | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/debug/SKILL.md | 303222582-4074

SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md | 1657109997-9015

SKILL-EVIDENCE: engineering:debug — helped: the private-tmux reproduction separated cwd drift from socket/session connectivity.

SKILL-EVIDENCE: superpowers:test-driven-development — helped: the real-tmux drift regression was made red before the helper implementation and then green through the focused cache.
