# Post-GO merge + cleanup (automatic — integrator/final step)

Parallel worktrees leave a confusing pile of sibling folders + branches. After the integrator issues GO, consolidate to ONE project folder and remove/quarantine the rest. Destructive — every step verifies before it removes, and quarantines (MOVE) rather than deletes anything it didn't create.

## 0. Precondition
Run ONLY after the integrator's GO on a **re-merge of current branch HEADs** (not a stale prior GO — see below). If NO-GO, skip cleanup.

## 1. Verify before destroying (never lose work)
- For each lane branch: `git log --oneline <branch> ^<integration-branch>` must be **empty** (0 commits not yet merged). Non-empty → NOT merged → STOP, do not remove that worktree.
- `git status` in the main tree: note uncommitted/untracked work. It lives in the MAIN tree (not a worktree) — it survives worktree removal. Never `rm` the main tree. If an orphan workstream is uncommitted, tell the user (commit/stash) — do not silently carry it into a destructive step.

## 2. Merge (if the integrator hasn't already)
Merge each verified lane branch into the integration branch. Resolve `docs/parallel-status.md` (and other doc) conflicts by keeping BOTH lane sections verbatim. Confirm the merged tree builds before cleanup.

## 3. Remove merged worktrees (git-aware, safe)
- `git worktree list`. For each lane worktree whose branch is confirmed merged: `git worktree remove --force <path>` (discards only build artifacts — node_modules/DerivedData/out — the committed code is in the branch).
- `git worktree prune`.

## 4. Delete merged branches
- `git branch -d <lane/branch>` for each merged lane branch (`-d` refuses if unmerged — safe by construction).

## 5. Quarantine the useless — MOVE, never rm
- The canonical project folder = the main worktree. Everything about the project stays there (that satisfies "one project folder").
- Create `<parent>/<project>-useless/` (e.g. `lelau-useless`). MOVE into it (do not delete): stray loose files, stale non-repo shells, duplicate checkouts that aren't the canonical tree, throwaway/detached worktrees already merged.
- Do NOT move: the harness's current working directory, or any folder holding UNIQUE uncommitted work — verify each with `ls`/`git status`/`du` first. When unsure, quarantine (reversible), never delete.

## 6. Report
Print: worktrees removed, branches deleted, dirs quarantined, space reclaimed. Exactly one folder should remain as the project; one `<project>-useless/` holds the quarantine. Nothing in the main tree touched.

## Permissions note
Removing worktrees / moving folders may be gated by the harness auto-mode (destructive). If blocked, present the exact `git worktree remove` / `mv` commands for the user to run or approve — do not work around the guard.
