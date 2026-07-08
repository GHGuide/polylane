# Post-GO merge + cleanup (automated — `bin/polylane-run.sh`)

Parallel worktrees leave a confusing pile of sibling folders + branches. After the integrator issues GO, one command consolidates to the single project tree and removes the rest. The runner is destructive by design, so every removal is gated: it verifies each lane is fully merged first, asks for one confirmation, and only ever deletes worktrees, branches, and its own scratch — never anything outside them.

**The base branch is only ever touched on GO.** The integrator merges every lane into its OWN branch and verifies the combined tree there — it never checks out or merges into the base (`main`). On a GO verdict the runner `promote_to_main` **fast-forwards the base to the integrator branch** (base + all lanes + the integrator's evidence), then cleans up. On NO-GO, promote never runs — the base is untouched and the worktrees stay put for fixing. This is why a NO-GO can never pollute `main`.

## The runner

```bash
bin/polylane-run.sh <manifest> [--dry-run] [--yes]
```

- `<manifest>` — the run manifest polylane wrote when it generated the lanes. It declares the integration branch, and each lane's worktree path + branch name. The runner reads it; you don't hand-list worktrees.
- `--dry-run` — print exactly what would be verified and removed, then stop. Deletes nothing. Run this first when unsure.
- `--yes` — skip the interactive confirmation (for non-interactive / CI use). Without it, the runner asks once (see step 3).
- The runner also takes `--intensity` / `--model` launch-time model overrides — documented in `polylane-run/SKILL.md`; they don't change cleanup behavior.

Environment variables the runner honors:

- `POLYLANE_SESSION` — tmux session name (default `polylane`); set it so parallel runs coexist without colliding.
- `POLYLANE_POLL_INTERVAL` — seconds between DONE-file polls (default 15).
- `POLYLANE_HEALTH_INTERVAL` / `POLYLANE_MAX_RETRIES` — the health check that auto-retries a lane stuck on a transient API/network error (default: scan every 300 s, 3 retries; past the cap the lane is marked failed and the run writes the report instead of hanging).

Run it ONLY after the integrator's GO on a **re-merge of current branch HEADs** (not a stale prior GO). If NO-GO, don't run cleanup.

## What the runner does, in order

### 1. Collect DONE lanes
Each lane signals completion by writing `docs/status-<lane>.md` with a first line `STATUS: <lane> DONE`. The runner reads these markers to know which lanes claim done. A lane with no `STATUS: … DONE` marker is treated as not-done and is left untouched.

### 2. Verify merged — never lose work
For every lane branch, the runner checks it is fully merged into the integration branch:

```bash
git log --oneline <lane-branch> ^<integration-branch>   # empty = 0 commits at risk = safe
```

- **Empty output → 0 commits at risk →** safe to remove.
- **Non-empty output →** that lane has commits not yet on the integration branch. The runner does NOT remove that worktree or branch. It reports the at-risk commits and skips that lane.

Uncommitted/untracked work lives in the MAIN tree, not in a lane worktree, so it survives worktree removal. The runner never touches the main tree.

### 3. One confirmation
After verification, the runner prints the plan — worktrees to remove, branches to delete, scratch to clear — and asks a single `y/N` prompt. Answer `N` (the default) and it aborts without deleting anything. `--yes` pre-answers `y`. `--dry-run` stops before this prompt.

### 4. Hard-delete (only after y)
For each lane confirmed merged (step 2):

```bash
git worktree remove --force <lane-worktree-path>   # discards only build artifacts; committed code is in the branch
git branch -d <lane-branch>                         # -d refuses an unmerged branch → safe by construction
```

Then it clears its own scratch:

- remove `.polylane/` (the runner's working state)
- remove `docs/status-*.md` (the DONE markers — scratch, their job is finished once merged)

### 5. Keep the evidence
The runner KEEPS, always:

- `docs/verify-*.md` — the per-lane proof files. These are the audit trail of what each lane verified; they are NOT scratch.
- `docs/parallel-status.md` — the coordination log.
- `docs/polylane-report.md` — the end-of-run digest (step 6).
- `docs/lane-logs/` — per-lane pane logs, when present.

Deleting the status markers but keeping the verify files is the point: the transient DONE signal goes, the durable evidence stays.

### 6. Report
The runner writes `docs/polylane-report.md` — a plain-language digest (outcome GO/NO-GO, per-lane results table, recent commits, suggested next steps) — on **both** GO and NO-GO, and prints: worktrees removed, branches deleted, scratch cleared, lanes skipped (if any were unmerged). The orchestrator reads the report and relays a simple summary to the user in the chat. Exactly one folder remains — the main project tree.

## Safety rules (invariants the runner holds)

- **Verify before remove.** No worktree or branch is removed until its lane branch shows 0 commits at risk (step 2). `git branch -d` (not `-D`) is a second guard — it refuses to delete an unmerged branch.
- **Conflict → abort, delete nothing.** If merging a lane into the integration branch hits a conflict, the runner aborts the whole cleanup and deletes nothing. Resolve the conflict (keep BOTH lane sections verbatim in doc files like `docs/parallel-status.md`), re-run the integrator to GO, then re-run the runner.
- **Never `rm` outside worktrees + `.polylane/` + status scratch.** The runner only ever calls `git worktree remove`, `git branch -d`, and removes `.polylane/` + `docs/status-*.md`. It never `rm`s the main tree, `docs/verify-*.md`, `docs/parallel-status.md`, `docs/polylane-report.md`, `docs/lane-logs/`, or any path outside that fixed set.

## Permissions note
Removing worktrees may be gated by the harness auto-mode (destructive). If blocked, the runner surfaces the exact `git worktree remove` / `git branch -d` commands for the user to run or approve — it does not work around the guard.
