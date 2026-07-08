# Phase 1 — Interview until the integration spec is locked

Goal: converge on a complete, numbered INTEGRATION SPEC with minimum user effort. The user should mostly CLICK (AskUserQuestion options), not type.

## Loop

1. **Parse the opening lines.** Each user line → a draft spec item: `<what> — <observable outcome>`. Mark ambiguous items.
2. **Ask in batches.** One AskUserQuestion call per round, 2-4 questions, each with 2-4 concrete options and the recommended one FIRST labeled "(Recommended)". Ask only questions that change the build:
   - Scope forks (e.g. "full black theme: OLED #000 or near-black?")
   - Priority/ordering when goals conflict
   - Constraints (device availability, deadline, what must NOT change)
   - Acceptance ("how will you know this one is done?") — only when the outcome isn't obvious.
   Never ask what recon can answer. Never ask more than 4 per round. Max ~3 rounds for typical requests.
3. **Re-present the spec after every round.** Full numbered list, one line each:
   `N. <feature> — done when <testable outcome>`
   Mark changes since last round with `*`.
4. **Probe for the missing.** Before declaring complete, ask ONE completeness question: "Anything else — settings, error states, offline, migrations, docs?" with a "No, that's everything" option.

## Intensity + model availability (ask once, early)

Two extra choices belong in Phase 1 — they set the token/quality budget the planner spends later (Phase 4 model resolution). Fold them into an early AskUserQuestion round (they change the build), then keep re-presenting the spec as usual.

1. **Intensity — one question.** "How hard should the fleet run?" with these presets, recommended FIRST:
   - `balanced (Recommended)` — Opus-high builders, the default fleet.
   - `economy` — cheapest models/effort that still ship the spec.
   - `performance` — bias toward more capable models on the load-bearing lanes.
   - `max` — top model + effort everywhere, cost no object.
   - `custom` — the user picks model + effort per lane themselves at the plan gate.

   If the user leans `max` (or asks for Fable everywhere), warn once, in the same round: an all-Fable fleet burns subscription usage limits fast (always-on thinking, long turns — a multi-lane run can exhaust a 5-hour window), and the hard rule in `references/model-selection.md` keeps at least the mechanical/docs and security lanes off Fable anyway. The Phase 5 cost row will show the $ before they approve.

   The answer becomes the global **`intensity`** (one of `economy | balanced | performance | max | custom`) — the exact preset the manifest emits and Phase 4 resolves against the rank map in `references/model-selection.md`.

2. **Which models do you have — optional.** "Which Claude models can this machine run?" Sets the global **`available_models`** list (model ids) that Phase 4 resolves within.
   - **Default probe path:** don't require a live API call. If the user skips this, assume the standard install trio from `references/model-selection.md` is available — `["claude-fable-5","claude-opus-4-8","claude-haiku-4-5"]`. The user narrows it only if a model is missing (e.g. no Fable), or confirms exact current availability via the `claude-api` skill when they care.

Both feed Phase 4 (`references/model-selection.md`): the preset + the available set resolve each lane's model + effort; `custom` defers the per-lane choice to the user at the Phase 5 plan gate.

## Environment checks (lessons from real runs — ask/verify once, don't skip)

Fold these into the same early round (or resolve them silently in recon when the answer is checkable):

1. **tmux session collision — ask only when it can bite.** The runner names its tmux session `polylane` by default; a second concurrent run on the same machine collides. If another polylane run may be live (`tmux ls` during recon shows one, or the user says so), ask for a session name and record it — the run launches with `POLYLANE_SESSION=<name>`. Otherwise don't ask.
2. **Disk space — check, don't ask.** N lane worktrees ≈ (N+1) full checkouts plus build artifacts. Run `df -h .` in recon; if it's tight, surface it at the plan gate with the option to merge lanes (see `references/lane-derivation.md` Step 2 caps).
3. **Usage-limit warning for all-Fable / `max` runs.** Covered in the intensity question above — deliver the warning the moment the user picks `max` or asks for Fable on every lane; don't wait for the plan gate.
4. **Orphan heads-up.** If `git status` in recon shows uncommitted/untracked work no lane owns, the user must commit/stash it (or assign it to a lane) before any worktree/branch op — say so early so it isn't a surprise blocker at Phase 3 (see SKILL.md Phase 3, orphan protection).

## Worked round (what one batch actually looks like)

User opens with three lines:
```
dark theme
faster search
export to CSV
```

Draft spec (before asking anything):
```
1. Dark theme — done when <scope?> renders dark, screenshot-verified.
2. Faster search — done when <target?> latency met.
3. CSV export — done when <what data?> downloads as valid CSV.
```

Three slots are ambiguous, so fire ONE AskUserQuestion with three questions (each option's recommended choice first, labeled "(Recommended)"):

- **Dark theme scope** — options: `App + modals + menus (Recommended)` / `App shell only` / `Also emails/PDF exports`.
- **Search target** — options: `<150 ms on 10k rows (Recommended)` / `<500 ms, keep it simple` / `Add a backend index`.
- **CSV contents** — options: `Current filtered view (Recommended)` / `Entire dataset` / `User picks columns`.

The user clicks three answers. Re-present the spec immediately (step 3), marking every changed line with `*`. If no slots remained ambiguous, skip the question entirely — never ask to look busy.

## Re-present rule (when the numbered spec is shown again)

Show the full numbered spec: after EVERY question round, after any freeform correction the user types, and one final time at the gate. Between those, don't reprint it. Each reprint carries a version bump (`v1 → v2 …`) and `*` on changed lines so the user diffs at a glance.

## Spec item format

```
INTEGRATION SPEC (v3)
1. Full-black theme — done when every surface renders #000, screenshot-verified.
2. Circular liquid-glass buttons — done when send FAB + icon buttons use the new style, screenshot-verified.
3. Siri zero-config ask — done when a fresh install answers "Hey Siri, ask <app>" with no setup.
...
```

Rules: one deliverable per item; every item testable; no vague items ("improve UX" → split into observable outcomes); note explicit NON-goals at the bottom (things the user said to skip) so lanes don't drift into them. Flag any item only HALF-satisfiable in this environment as **CONDITIONAL** — needs a bundle / external service / product decision not present (e.g. an anonymity feature that needs a bundled on-device daemon; a paid API not wired). Mark it CONDITIONAL in the spec so the final GO isn't surprised by a feature that's architecturally done but not functionally usable.

## Exit condition (hard gate)

Present the final spec and ask exactly: **"Is this everything you expect to be integrated? Reply yes to lock it, or tell me what to change."** Loop until an explicit yes. Do not proceed to recon/lanes/prompts on silence, "looks good so far", or partial approval — those get one more confirmation round.
