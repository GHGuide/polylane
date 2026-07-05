STATUS: docs DONE

Lane: docs. Owns references/merge-and-cleanup.md, references/install-helpers.md.

- merge-and-cleanup.md: rewrote from the manual quarantine flow to the automated `bin/polylane-run.sh <manifest> [--dry-run] [--yes]` flow. Documents: DONE markers (`docs/status-<lane>.md`, first line `STATUS: <lane> DONE`) → verify merged (`git log --oneline <lane-branch> ^<integration-branch>` empty = 0 at risk) → one y/N confirm → hard-delete (`git worktree remove --force` + `git branch -d`) + rm `.polylane/` + rm `docs/status-*.md`, KEEP `docs/verify-*.md` + `docs/parallel-status.md`. Includes conflict→abort-delete-nothing + never-`rm`-outside-worktrees/.polylane invariants + --dry-run.
- install-helpers.md: added "Install the polylane-run skill" (`cp -R polylane-run/ ~/.claude/skills/polylane-run/`) + runtime deps (`brew install tmux jq`, apt variant, verify lines). Existing q.py/nudge/settings/navigation steps untouched (additive).
- Matches L1 contract: same CLI, same marker, same keep/delete lists. No invented behavior.
- Proof: docs/verify-docs.md (11 contract elements quoted + grep evidence + consistency check). PASS.
- NEEDS DECISION: none.
