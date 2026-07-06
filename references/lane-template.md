# Lane prompt template — assemble from prompt-blocks.md

Emit ONE of these per lane, as: a launch line + a fenced paste block. Order the blocks exactly A→J. Everything in `<...>` is filled from recon + derivation; blocks C, E, G, H, I are verbatim.

## Launch line
```
cd "<WORKTREE_ABS_PATH>" && claude --model <MODEL_ID>
```
(`<WORKTREE_ABS_PATH>` = this lane's own git worktree — the Phase 5 default; each lane launches in its own worktree so its git index + commits stay isolated. `<MODEL_ID>` (`claude-fable-5` or `claude-opus-4-8`) and the lane's effort both come from the Phase 4 resolution of the `intensity` preset against `available_models` per model-selection.md — or the user's Phase 5 per-lane override. Effort is instructed in-prompt via block B — there is no verifiable CLI effort flag.)

## Paste block skeleton (fill and inline the blocks)
```
[A identity + context]
[B model + effort header]
[0 MANDATORY-4 preamble: /graphify-auto · caveman(full) · /goal <lane goal> · superpowers:using-superpowers]
[C terse output]
[D skills for this lane]
[E graphify-first]   (omit only if graphify-out/ absent AND graphify skill unavailable — then substitute: "Use one read-only Explore agent to map <subsystem> before editing.")
[F file ownership + contract]

GOAL (LOCKED — do not re-scope):
<the spec items assigned to this lane, each with its done-when outcome>

WORKFLOW: <writing-plans → smallest steps → verify each → commit>.
[G forced verification]
[H coordination + mutex]   (docs/parallel-status.md = cross-lane requests + NEEDS DECISION only, never the done signal)
[I scoped git]
[J done checklist]

DONE-SIGNAL: on completion write docs/status-<lane>.md, first line EXACTLY `STATUS: <lane> DONE` — per-lane + worktree-safe; the runner reads this file to know the lane finished.
```

## After all lane prompts — emit the run manifest (planner action, not the builder's)
Once every lane's paste block is printed, the planner ALSO writes them to disk and emits the manifest the runner consumes (mirrors SKILL.md Phase 6):
- Write each lane's full paste block (and the integrator's) to `.polylane/lanes/<lane>.txt`.
- Emit `.polylane/run.json` conforming EXACTLY to the frozen schema — no added, dropped, or renamed keys:
```json
{
  "base": "<base branch>",
  "intensity": "<economy|balanced|performance|max|custom>",
  "available_models": ["<id>", "..."],
  "integrator": {"name":"<int>","model":"<id>","effort":"<low|medium|high|xhigh>","branch":"<int-branch>","worktree":"<int-worktree>","prompt_file":".polylane/lanes/<int>.txt"},
  "lanes": [
    {"name":"<lane>","model":"<id>","effort":"<low|medium|high|xhigh>","branch":"<lane-branch>","worktree":"<lane-worktree>","prompt_file":".polylane/lanes/<lane>.txt","own_globs":["<glob>"]}
  ]
}
```
`intensity` is the Phase 1 preset; `available_models` is the set it resolved against; per-object `model` + `effort` are the Phase 4-resolved (or Phase 5-overridden) values, on every lane object and the integrator (matching Lc's `.polylane/SCHEMA.md`). `worktree` is each lane's Phase 5 worktree; `prompt_file` is its `.polylane/lanes/<lane>.txt`. The integrator omits `own_globs`; every lane includes it.

## Rules
- The GOAL is copied verbatim from the locked INTEGRATION SPEC — never paraphrased or expanded. If a builder wants scope beyond it, it must raise NEEDS DECISION, not act.
- Keep each prompt self-contained (a fresh terminal has no session context).
- Project-specific recipes (build/install commands, device IDs, known-broken tooling) are pulled from the project's CLAUDE.md and inlined into the relevant lane(s) — not hardcoded in this template.
- After all lane prompts + the integrator prompt: STOP. Do not launch, do not edit code.

## Filled mini-example (one lane, end to end)

Scenario: a Vue todo app. One derived lane, `dark-theme`, on Opus 4.8 / high, owning the styling layer only. This is what a single generated lane looks like once every `<...>` slot is filled and blocks A→J are inlined in order. (A real run also emits sibling lanes + the integrator; only one is shown here.)

Launch line:
```
cd "/Users/me/.worktrees/todo-app-dark-theme" && claude --model claude-opus-4-8
```

Paste block:
```
Project: Vue 3 todo app (Vite + Pinia). Read THIS project's CLAUDE.md and memory/MEMORY.md first. IGNORE any unrelated CLAUDE.md from other projects. YOUR LANE = dark-theme. Other Claudes run api-lane and test-lane in parallel — do NOT touch their files.

Run on claude-opus-4-8 at high effort: confirm with /model, ultrathink before non-trivial steps.

Before anything else, in order:
1. /graphify-auto
2. Invoke the caveman skill (full)
3. /goal Ship a full dark theme across every rendered surface, screenshot-verified.
4. superpowers:using-superpowers

Keep output terse (caveman-style: drop articles/filler/hedging, fragments OK). Write code, commits, and PRs in normal prose. Act when you have enough information; do not re-derive settled facts or narrate options you won't pursue.

Invoke: superpowers:using-superpowers, then design skills + /design-critique + verification-before-completion. Your goal is LOCKED (below) — do NOT open superpowers:brainstorming; go straight to writing-plans/execution.

STEP 1 (before ANY Read/Grep): run /graphify-auto (free AST refresh), then map the styling subsystem by QUERYING the graph — do NOT grep to discover where things are:
  python graphify-out/q.py theme
  python graphify-out/q.py callers useTheme
  python graphify-out/q.py uses ThemeProvider
  python graphify-out/q.py near tokens.css
  python graphify-out/q.py file styles/
Print the resulting map and work from it. Use Grep/Glob ONLY to confirm an exact string right before an edit.

YOU OWN (edit only these): src/styles/**, src/components/**/*.css, tailwind.config.*
FORBIDDEN (other lanes own — do not edit/refactor): src/api/**, tests/**
HARD CONTRACT: the CSS custom-property names in src/styles/tokens.css are frozen (api-lane reads them). If you need a change in a file you don't own, log the request in docs/parallel-status.md addressed to the owning lane; do NOT edit it.

GOAL (LOCKED — do not re-scope):
1. Dark theme on every surface — done when app, modals, and menus render the dark palette with no light-mode bleed, screenshot-verified.
2. Persisted toggle — done when the choice survives reload, verified in two sessions.

WORKFLOW: writing-plans → smallest steps → verify each → commit.

VERIFY with evidence — no claim without it. Write docs/verify-dark-theme.md containing: preview_start command output + before/after screenshots of app, a modal, and a menu in dark mode. Never say "done"/"works"/"looks good" without the artifact in that file.

Use docs/parallel-status.md ONLY for cross-lane requests: a shared-file edit ask addressed to the owning lane, or a NEEDS DECISION: line if you hit a fork only the user can resolve (then continue other work, don't stall). It is not a general status log and not the done signal.

Commit often. Stage ONLY your paths (git add src/styles src/components tailwind.config.*) — NEVER git add -A or git add . (scope every add to your own paths). On index.lock, wait + retry.

DONE-SIGNAL: on completion write docs/status-dark-theme.md, first line EXACTLY `STATUS: dark-theme DONE` — the runner reads this to know the lane finished.

DONE = all true: both GOAL items observably met + docs/verify-dark-theme.md has proof + docs/status-dark-theme.md written with first line `STATUS: dark-theme DONE` + no new errors. Drive with the skills; no generic output.
```

Reading top to bottom: A (identity) → B (model header) → 0 (mandatory-4 preamble) → C (terse) → D (skills) → E (graphify-first) → F (ownership + contract) → GOAL (locked, verbatim from spec) → WORKFLOW → G (verify) → H (coordination) → I (scoped git) → J (done) → DONE-SIGNAL (docs/status-<lane>.md, first line `STATUS: <lane> DONE`). Same order the skeleton above prescribes.
