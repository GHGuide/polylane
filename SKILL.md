---
name: polylane
description: Use when the user describes several goals in plain lines and wants them built by parallel Claude Code terminals — polylane interviews until the spec is locked, derives the OPTIMAL number of file-isolated lanes from real file-overlap, tunes model + effort per lane (Fable/Opus) for token efficiency, bakes graphify + caveman + superpowers into every generated prompt, recommends task-specific skills, and auto-merges + cleans up at the end. Triggers on "/polylane", "/lanes", "split this into prompts", "parallel terminals", "make lane prompts", "orchestrate builders".
---

# /lanes — parallel-lane prompt orchestrator

Turn a plain-line description into N paste-ready builder prompts for parallel Claude CLI terminals, with file isolation, forced verification, and per-lane model/effort tuned for token efficiency.

**You are the orchestrator. You NEVER implement. Output = prompts + recommendations. Hard rule: no prompt generation until the user explicitly approves the spec (Phase 2) and the plan (Phase 5).**

## Phases (in order, no skipping)

### 1. Interview → integration spec
Read `references/interview.md`. Converse until you can present a complete numbered **INTEGRATION SPEC** — every feature/change the user expects, each one line with a testable outcome. Use batched AskUserQuestion (2-4 questions per round, options pre-recommended) so the user only clicks. Re-present the updated spec after every round.

### 2. Spec gate (blocking)
Present the full spec. Ask: "Is this everything?" Loop on edits. **Only an explicit yes advances.** No file edits, no prompts before this.

### 3. Recon
First, `git status` + `git worktree list`: inventory ALL uncommitted/untracked work and existing worktrees. Any uncommitted work not owned by a planned lane is an **ORPHAN** — surface it and have the user commit/stash it (or assign it to a lane) BEFORE any worktree/branch op; a checkout can wipe it. Never generate lanes over uncommitted orphan work.

Next, install the graph query helpers so builders actually use the graph (biggest realized token saving) — follow `references/install-helpers.md`: copy `assets/q.py` → `<project>/graphify-out/q.py` and `assets/graphify-nudge.sh` → `<project>/.claude/hooks/`, add the CLAUDE.md nav rule, and HAND the user `assets/settings-hook-snippet.json` for `.claude/settings.json` (you cannot write settings.json under auto-mode). Skip if no `graphify-out/graph.json` exists.

Then map spec items → files. If `graphify-out/` exists: run `/graphify-auto`, then query via `python graphify-out/q.py <symbol>` per subsystem — do not grep to discover. Else: one read-only Explore agent. Output: file-set per spec item. Also read the project's CLAUDE.md + any `docs/parallel-status.md` for constraints (shared devices, broken tooling, contracts).

### 4. Derive lanes + models + skills
- Lane count/carving: `references/lane-derivation.md`. N is computed from file-overlap, never assumed.
- Per-lane model + effort: `references/model-selection.md` (Fable 5 vs Opus 4.8, effort level, token-efficiency rules).
- Skill recommendations: `references/skill-catalog.md` — check installed skills first, then search the awesome-lists for gaps. Output a **GitHub repo/skill suggestion list** (name, purpose, install command). Recommend only — NEVER install third-party skills without explicit user approval (untrusted skill = prompt-injection surface).

### 5. Plan gate (blocking)
Present: lane table (name, model+effort, OWN globs, contracts, goals), the skill-suggestion list, and worktree-vs-shared-tree choice. One batched AskUserQuestion. Wait for approval.

### 6. Generate prompts
Fill `references/lane-template.md` per lane using the blocks in `references/prompt-blocks.md`. Every prompt MUST OPEN with the mandatory-4 preamble (block 0), in order: **1) `/graphify-auto`, 2) caveman skill (full), 3) `/goal <one-line lane goal>` (Anthropic built-in — sets + locks the objective), 4) `superpowers:using-superpowers`** — these four are non-negotiable in every prompt. The LOCKED-GOAL block also restates the goal in-prompt (belt-and-suspenders with `/goal`). Then include: OWN/FORBIDDEN + contracts, the graphify-first query block (E), the lane's specific superpowers (D), forced-verify evidence file, coordination/status block, scoped git, LOCKED goal, done-checklist. Brainstorming is orchestrator-only — builders get the LOCKED goal. Print each as: launch command + fenced paste block. Offer the integrator lane (runs last) by default. Then STOP.

### 7. Merge + cleanup (automatic, after the integrator issues GO)
When the run finishes and the integrator issues GO on a **re-merge of current branch HEADs** (never a stale prior GO), consolidate to ONE project folder — follow `references/merge-and-cleanup.md`: verify each lane branch is merged (0 commits at risk), remove merged worktrees (`git worktree remove --force`), delete merged lane branches (`git branch -d`), and MOVE stray / duplicate / non-canonical dirs into `<project>-useless/` (never `rm` what you didn't create; never touch the main tree's uncommitted work or the harness cwd). One project folder remains. If auto-mode blocks a destructive step, hand the user the exact commands.

## Non-negotiables
- Every generated prompt opens with the mandatory-4 preamble, in order: `/graphify-auto` · caveman (full) · `/goal <lane goal>` · `superpowers:using-superpowers`. All four are real on this install; never omit one.
- Recon runs `git status` + `git worktree list` FIRST; orphan uncommitted work is surfaced + protected (commit/stash) before any worktree/branch op.
- The integrator NEVER trusts a prior GO — it re-merges current branch HEADs; any GO with commits after it is stale and re-verified.
- Human device / voice / visual verification batches to the FINAL gate only, and is diff-aware (re-verify only surfaces that changed). Each re-install invalidates prior voice/visual sign-off — say so in the spec.
- After GO: auto merge + cleanup per `references/merge-and-cleanup.md` — verify merges before removing; quarantine (move), don't delete; leave one project folder.
- Never `git add -A` in any generated prompt.
- Every lane's "done" requires evidence in `docs/verify-<lane>.md`.
- Shared file between lanes → one lane owns it; the other requests edits via `docs/parallel-status.md`, never edits directly.
- Exactly one lane may hold any shared physical resource (device/simulator/deploy target) — mutex via status file.
- Project-specific facts (build recipes, device UDIDs, quirks) come from the project's CLAUDE.md — keep this skill generic.
