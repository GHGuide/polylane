# Build pipeline — derive lanes, generate prompts, emit manifest

> The per-cycle build mechanics the `polylane` loop (Phase 1) uses. Was the standalone `/polylane` planner skill; folded in here when polylane collapsed to one skill.


# /lanes — parallel-lane prompt orchestrator

Turn a plain-line description into N paste-ready builder prompts for parallel Claude CLI terminals, with file isolation, forced verification, and per-lane model/effort tuned for token efficiency.

**You are the orchestrator. You NEVER implement. Output = prompts + recommendations. Hard rule: no prompt generation until the user explicitly approves the spec (Phase 2) and the plan (Phase 5).**

## Phases (in order, no skipping)

### 1. Interview → integration spec
Read `references/interview.md`. Converse until you can present a complete numbered **INTEGRATION SPEC** — every feature/change the user expects, each one line with a testable outcome. Use batched AskUserQuestion (2-4 questions per round, options pre-recommended) so the user only clicks. Re-present the updated spec after every round. In an early round also ask the ONE intensity question (`economy | balanced | performance | max | custom`, `balanced` recommended) and the optional "which models do you have" step — default probe = assume the `model-selection.md` trio available. These set the global `intensity` + `available_models` consumed in Phase 4.

### 2. Spec gate (blocking)
Present the full spec. Ask: "Is this everything?" Loop on edits. **Only an explicit yes advances.** No file edits, no prompts before this.

### 3. Recon
First, `git status` + `git worktree list`: inventory ALL uncommitted/untracked work and existing worktrees. Any uncommitted work not owned by a planned lane is an **ORPHAN** — surface it and have the user commit/stash it (or assign it to a lane) BEFORE any worktree/branch op; a checkout can wipe it. Never generate lanes over uncommitted orphan work.

Next, install the graph query helpers so builders actually use the graph (biggest realized token saving) — follow `references/install-helpers.md`: copy `assets/q.py` → `<project>/graphify-out/q.py` and `assets/graphify-nudge.sh` → `<project>/.claude/hooks/`, add the CLAUDE.md nav rule, and HAND the user `assets/settings-hook-snippet.json` for `.claude/settings.json` (you cannot write settings.json under auto-mode). Skip if no `graphify-out/graph.json` exists.

Then map spec items → files. If `graphify-out/` exists: run `/graphify-auto`, then query via `python graphify-out/q.py <symbol>` per subsystem — do not grep to discover. Else: one read-only Explore agent. Output: file-set per spec item. Also read the project's CLAUDE.md + any `docs/parallel-status.md` for constraints (shared devices, broken tooling, contracts).

### 4. Derive lanes + models + skills
- Lane count/carving: `references/lane-derivation.md`. N is computed from file-overlap, never assumed. **Also check hidden couplings that share no file** (DOM ids, routes, schemas, config keys) — a UI feature's markup and the JS bound to it are ONE lane by default; splitting them reads as INDEPENDENT in the file matrix but leaves the JS wired to an element that never lands (a real repeat NO-GO). Co-locate the vertical slice, or name the interface in both contracts.
- **Candidate-plan bake-off (multi-plan selection — a bad carving costs a whole run).** Generate 2–3 CANDIDATE carvings of the same spec (e.g. finer-grained vs coarser; grouped-by-subsystem vs grouped-by-change-type), then score each on: file-isolation cleanliness (zero source overlap = best), parallelism (independent lanes), contract simplicity (fewer frozen APIs between lanes = less coupling), and risk (a lane that could stall/conflict). Pick the highest-scoring plan; note in one line why it beat the runners-up. This is cheap (orchestrator reasoning, no builder spend) and prevents the expensive failure mode of committing to a collision-prone decomposition.
- Per-lane model + effort: resolve each lane from the chosen `intensity` preset against `available_models` using the rank map in `references/model-selection.md` (Fable 5 / Opus 4.8 / Sonnet 5 / Haiku 4.5, effort level, token-efficiency rules). When a preset's ideal model isn't in `available_models`, degrade gracefully to the best available rank. If `intensity` = `custom`, skip auto-resolution — the user sets model + effort per lane at the Phase 5 gate.
- Skill recommendations: `references/skill-catalog.md` — check installed skills first, then search the awesome-lists for gaps. Output a **GitHub repo/skill suggestion list** (name, purpose, install command). Recommend only — NEVER install third-party skills without explicit user approval (untrusted skill = prompt-injection surface).

### 5. Plan gate (blocking)
Present: lane table (name, model+effort, OWN globs, contracts, goals, **est. cost**), the skill-suggestion list, and the isolation choice. The model+effort column is the value **resolved from the `intensity` preset** in Phase 4 (or the user's picks when `intensity` = `custom`).

**Cost-estimate row — REQUIRED.** The table MUST include a per-lane cost estimate plus a **TOTAL** row, so the user sees the dollars before approving: tokens-guess × the lane's resolved-model rates from the `references/model-selection.md` price table (that table is canonical for costs), computed per its "Cost-per-lane estimation" formula, and always labelled **rough** (±2× is normal). Never present the plan gate without it. Before approving, the user may override ANY single lane — bump it up or drop it down (model and/or effort), independent of the global preset. Apply the overrides, re-present the table, then take the batched approval. **Default isolation = one git worktree per lane.** On a shared working tree every lane shares ONE git index, so any lane's `git add` + commit sweeps in every other lane's already-staged files — the shared-index race (observed in a prior run: one lane's commit co-committed another lane's staged, unrelated files). A worktree per lane gives each its own index + checkout, so scoped commits stay scoped and branches stay independent. Fall back to a shared tree only if the user explicitly opts out (e.g. worktrees unavailable). One batched AskUserQuestion. Wait for approval.

### 6. Generate prompts + emit run manifest
**Target agent (Claude by default; GPT/codex/aider supported).** polylane's pipeline is agent-agnostic — the done-signal + verdict are file-based, so any CLI can drive a lane. Set the agent via the manifest `agent` field (`claude` | `codex`/`gpt` | `aider`) or `POLYLANE_AGENT`, or a full `POLYLANE_AGENT_CMD` template with `{model}`/`{prompt}`. **When the agent is NOT claude, the mandatory-4 preamble below does NOT apply** — `/graphify-auto`, the caveman skill, `/goal`, and `superpowers:*` are Claude-Code-only and a GPT/aider CLI would choke on them. For a non-claude agent, generate prompts in **plain instructions**: state the locked goal in prose, "keep output terse", "query the graph via `python graphify-out/q.py <symbol>` instead of grepping", and the same OWN/FORBIDDEN + contract + forced-verify + done-signal blocks (those are all agent-neutral). Use non-claude model ids in the manifest (e.g. `gpt-5-codex`).

Fill `references/lane-template.md` per lane using the blocks in `references/prompt-blocks.md`. **For Claude lanes**, every prompt MUST OPEN with the mandatory-4 preamble (block 0), in order: **1) `/graphify-auto`, 2) caveman skill (full), 3) `/goal <one-line lane goal>` (Anthropic built-in — sets + locks the objective), 4) `superpowers:using-superpowers`** — these four are non-negotiable in every Claude prompt. (The caveman step is fixed; only its LEVEL follows the round's intensity — `ultra` under `economy`, `full` otherwise, per `references/model-selection.md`.) The LOCKED-GOAL block also restates the goal in-prompt (belt-and-suspenders with `/goal`). Then include: OWN/FORBIDDEN + contracts, the graphify-first query block (E), the lane's specific superpowers (D), forced-verify evidence file, coordination/status block, scoped git, LOCKED goal, done-checklist.

**Done-signal — bake into EVERY generated prompt:** on completion each lane writes `docs/status-<lane>.md` whose FIRST LINE is exactly `STATUS: <lane> DONE`. **`<lane>` MUST be the lane's `name` in the manifest, character-for-character** — the runner polls `<worktree>/docs/status-<name>.md` for `STATUS: <name> DONE`, so any drift (e.g. prompt says `foo-tests` while the manifest name is `foo`) makes the poll hang forever on work that is actually finished. Emit the manifest `name` and the status marker from the SAME string; never decorate one. This per-lane file is worktree-safe (each lane owns its own status file — no shared-index collision) and is the machine-readable completion marker the runner consumes. `docs/parallel-status.md` is NOT the done signal; it stays only for cross-lane requests (shared-file edit asks, NEEDS DECISION).

Brainstorming is orchestrator-only — builders get the LOCKED goal. Print each prompt as: launch command + fenced paste block. Offer the integrator lane (runs last) by default.

**Then emit two machine-readable outputs the runner consumes:**
1. Write each lane's full paste block (and the integrator's) to `.polylane/lanes/<lane>.txt` — one file per lane, so the runner launches from files instead of copy-paste.
2. Emit the run manifest `.polylane/run.json`, conforming EXACTLY to this frozen schema — do NOT add, drop, or rename keys:

```json
{
  "base": "<base branch lanes fork from>",
  "intensity": "<economy|balanced|performance|max|custom>",
  "available_models": ["<model id>", "..."],
  "integrator": {
    "name": "<integrator lane name>",
    "model": "<model id>",
    "effort": "<low|medium|high|xhigh>",
    "branch": "<integrator branch>",
    "worktree": "<integrator worktree path>",
    "prompt_file": ".polylane/lanes/<integrator>.txt"
  },
  "lanes": [
    {
      "name": "<lane name>",
      "model": "<model id>",
      "effort": "<low|medium|high|xhigh>",
      "branch": "<lane branch>",
      "worktree": "<lane worktree path>",
      "prompt_file": ".polylane/lanes/<lane>.txt",
      "own_globs": ["<glob>", "..."]
    }
  ]
}
```

Global `intensity` is the Phase 1 preset; `available_models` is the resolved-against set; per-object `effort` is the Phase 4-resolved (or user-overridden) effort, carried on every lane object and the integrator exactly as `model` is — matching Lc's `.polylane/SCHEMA.md`. Each `prompt_file` points at the `.polylane/lanes/<lane>.txt` written in step 1; `worktree` is the per-lane worktree from the Phase 5 default. The integrator object omits `own_globs` (it edits only its own verify/glue files); every lane object includes it. Then STOP.

### 7. Merge + cleanup (automatic, after the integrator issues GO)
When the run finishes and the integrator issues GO on a **re-merge of current branch HEADs** (never a stale prior GO), consolidate to ONE project folder — follow `references/merge-and-cleanup.md`. (During the run the runner also auto-retries lanes stuck on transient API errors — `POLYLANE_HEALTH_INTERVAL` / `POLYLANE_MAX_RETRIES` — so a stalled pane is not automatically a failed lane.) The runner then writes `docs/polylane-report.md` (plain-terms digest: outcome, per-lane results, suggested next steps) on GO or NO-GO; the orchestrator MUST read it and relay a simple summary back to the user in the chat (the run happened in tmux, out of sight): verify each lane branch is merged (0 commits at risk), remove merged worktrees (`git worktree remove --force`), delete merged lane branches (`git branch -d`), and MOVE stray / duplicate / non-canonical dirs into `<project>-useless/` (never `rm` what you didn't create; never touch the main tree's uncommitted work or the harness cwd). Cleanup removes only scratch (`.polylane/`, `docs/status-*.md`) and KEEPS the evidence: `docs/verify-*.md`, `docs/parallel-status.md`, `docs/polylane-report.md`, and `docs/lane-logs/`. One project folder remains. If auto-mode blocks a destructive step, hand the user the exact commands.

## Non-negotiables
- Every generated prompt opens with the mandatory-4 preamble, in order: `/graphify-auto` · caveman (full) · `/goal <lane goal>` · `superpowers:using-superpowers`. All four are real on this install; never omit one.
- Recon runs `git status` + `git worktree list` FIRST; orphan uncommitted work is surfaced + protected (commit/stash) before any worktree/branch op.
- The integrator NEVER trusts a prior GO — it re-merges current branch HEADs; any GO with commits after it is stale and re-verified.
- Human device / voice / visual verification batches to the FINAL gate only, and is diff-aware (re-verify only surfaces that changed). Each re-install invalidates prior voice/visual sign-off — say so in the spec.
- After GO: auto merge + cleanup per `references/merge-and-cleanup.md` — verify merges before removing; quarantine (move), don't delete; leave one project folder.
- Never `git add -A` in any generated prompt.
- Every lane's "done" requires evidence in `docs/verify-<lane>.md`.
- Every generated prompt bakes the done-signal: the lane writes `docs/status-<lane>.md` with first line exactly `STATUS: <lane> DONE` (per-lane, worktree-safe). `docs/parallel-status.md` is for cross-lane requests only — never the done signal.
- Phase 5 defaults to one git worktree per lane (shared-index race — a shared tree lets one lane's commit bundle another's staged files); shared-tree only on explicit user opt-out.
- The Phase 5 plan gate always shows the rough per-lane + total cost estimate computed from the `references/model-selection.md` price table (canonical for costs) — never ask for approval without the $ visible.
- Phase 6 emits `.polylane/run.json` (frozen schema: `base` · `intensity` · `available_models[]` · `integrator{name,model,effort,branch,worktree,prompt_file}` · `lanes[]{name,model,effort,branch,worktree,prompt_file,own_globs}`) plus `.polylane/lanes/<lane>.txt` per lane, alongside the printed paste blocks. New keys (`intensity`, `available_models`, per-object `effort`) match Lc's `.polylane/SCHEMA.md`.
- Shared file between lanes → one lane owns it; the other requests edits via `docs/parallel-status.md`, never edits directly.
- Exactly one lane may hold any shared physical resource (device/simulator/deploy target) — mutex via status file.
- Project-specific facts (build recipes, device UDIDs, quirks) come from the project's CLAUDE.md — keep this skill generic.
