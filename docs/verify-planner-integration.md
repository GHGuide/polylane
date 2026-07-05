# Verify — lane planner-integration

Lane wires the polylane PLANNER (SKILL.md + references/lane-template.md) to emit what the runner engine consumes. Evidence below is grepped from the two owned files post-edit. Frozen L1 contract honored exactly — no invented keys, mandatory-4 order intact.

Owned/edited: `SKILL.md`, `references/lane-template.md`.
Not touched (forbidden): `references/prompt-blocks.md`, `.polylane/**`, `bin/**`, README, assets, evals.

---

## Goal 1 — Phase 6 emits `.polylane/run.json` + `.polylane/lanes/<lane>.txt`

SKILL.md Phase 6 renamed and now describes BOTH machine outputs (grep `SKILL.md`):

```
35:### 6. Generate prompts + emit run manifest
43:1. Write each lane's full paste block (and the integrator's) to `.polylane/lanes/<lane>.txt` — one file per lane, so the runner launches from files instead of copy-paste.
44:2. Emit the run manifest `.polylane/run.json`, conforming EXACTLY to this frozen schema — do NOT add, drop, or rename keys:
69:Each `prompt_file` points at the `.polylane/lanes/<lane>.txt` written in step 1; `worktree` is the per-lane worktree from the Phase 5 default. The integrator object omits `own_globs` (it edits only its own verify/glue files); every lane object includes it. Then STOP.
```

### Frozen schema block (SKILL.md:47-66) — matches contract key-for-key
Contract: `{"base","integrator":{name,model,branch,worktree,prompt_file},"lanes":[{name,model,branch,worktree,prompt_file,own_globs}]}`

Emitted schema keys (grep `"base"|"integrator"|"worktree"|"prompt_file"|"own_globs"`):
```
48:  "base": "<base branch lanes fork from>",
49:  "integrator": {
53:    "worktree": "<integrator worktree path>",
54:    "prompt_file": ".polylane/lanes/<integrator>.txt"
61:      "worktree": "<lane worktree path>",
62:      "prompt_file": ".polylane/lanes/<lane>.txt",
63:      "own_globs": ["<glob>", "..."]
```
integrator = {name,model,branch,worktree,prompt_file} (no own_globs). lanes[] = {name,model,branch,worktree,prompt_file,own_globs}. EXACT match to frozen contract.

---

## Goal 2 — DONE convention switched to per-lane `docs/status-<lane>.md`

DONE marker baked into every generated prompt; `parallel-status.md` demoted to cross-lane requests only.

SKILL.md:
```
38:**Done-signal — bake into EVERY generated prompt:** on completion each lane writes `docs/status-<lane>.md` whose FIRST LINE is exactly `STATUS: <lane> DONE`. This per-lane file is worktree-safe ... `docs/parallel-status.md` is NOT the done signal; it stays only for cross-lane requests (shared-file edit asks, NEEDS DECISION).
82:- Every generated prompt bakes the done-signal: the lane writes `docs/status-<lane>.md` with first line exactly `STATUS: <lane> DONE` (per-lane, worktree-safe). `docs/parallel-status.md` is for cross-lane requests only — never the done signal.
```

lane-template.md (skeleton + mini-example + readout):
```
30:DONE-SIGNAL: on completion write docs/status-<lane>.md, first line EXACTLY `STATUS: <lane> DONE` — per-lane + worktree-safe; the runner reads this file to know the lane finished.
103:DONE-SIGNAL: on completion write docs/status-dark-theme.md, first line EXACTLY `STATUS: dark-theme DONE` — the runner reads this to know the lane finished.
105:DONE = ... + docs/status-dark-theme.md written with first line `STATUS: dark-theme DONE` + no new errors.
```
Mini-example coordination block narrowed: "Use docs/parallel-status.md ONLY for cross-lane requests ... It is not a general status log and not the done signal."

---

## Goal 3 — Phase 5 defaults to worktrees (with shared-index race cited)

SKILL.md:47 → line 33:
```
Present: lane table ... and the isolation choice. **Default isolation = one git worktree per lane.** On a shared working tree every lane shares ONE git index, so any lane's `git add` + commit sweeps in every other lane's already-staged files — the shared-index race (observed in a prior run: one lane's commit co-committed another lane's staged, unrelated files). A worktree per lane gives each its own index + checkout, so scoped commits stay scoped and branches stay independent. Fall back to a shared tree only if the user explicitly opts out (e.g. worktrees unavailable).
```
Reinforced in non-negotiables (SKILL.md:83). Prior-run evidence for the race: `docs/parallel-status.md` derivation-lane note — commit `f53b9e9` co-committed the workflow lane's staged files via the shared index.

---

## Goal 4 — lane-template.md matches Phase 6

Launch line now worktree-scoped:
```
7:cd "<WORKTREE_ABS_PATH>" && claude --model <MODEL_ID>
9:(`<WORKTREE_ABS_PATH>` = this lane's own git worktree — the Phase 5 default; each lane launches in its own worktree so its git index + commits stay isolated. ...)
60:cd "/Users/me/.worktrees/todo-app-dark-theme" && claude --model claude-opus-4-8   (mini-example)
```
Manifest-emit step added (lane-template.md:33-46) mirroring SKILL Phase 6, same frozen schema (integrator omits own_globs; lanes include it). Status-file done-signal added to skeleton (line 30) + order readout (line 108).

---

## Goal 5 — cross-consistency (SKILL.md ↔ lane-template.md)

| Concern | SKILL.md | lane-template.md | Agree |
|---|---|---|---|
| DONE marker | `docs/status-<lane>.md`, first line `STATUS: <lane> DONE` | same (skeleton:30, example:103/105, readout:108) | ✓ |
| parallel-status.md role | cross-lane requests only, not done signal (38,82) | same (skeleton:27 note, example narrowed) | ✓ |
| isolation default | one worktree per lane (33,83) | worktree launch line (7,9,60) | ✓ |
| manifest schema | integrator{5 keys} · lanes[]{6 keys incl own_globs} (47-66) | identical (33-46) | ✓ |
| mandatory-4 order | /graphify-auto · caveman · /goal · superpowers (36,75) | unchanged (skeleton block 0, preamble intact) | ✓ |

No contradiction found across the two owned files.

---

## Note for integrator / L1 (transparency, non-blocking)
`references/prompt-blocks.md` (FORBIDDEN to this lane) blocks H and J still phrase `docs/parallel-status.md` as the general status/done log. This does NOT violate the frozen contract — the contract requires only that the status-`<lane>.md` marker be present in generated prompts, which the owned template now bakes in. If L1 wants prompt-blocks.md H/J narrowed to match the new convention, that is a separate lane's edit. No divergence taken here; parallel-status.md not modified (frozen prior-run audit trail).
