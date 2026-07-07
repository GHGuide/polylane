---
name: polylane-auto
description: Use when the user wants the WHOLE parallel-build pipeline in one command — interview, spec + plan gates, lane derivation, prompt generation, then automatically launch the tmux panes, poll, integrate, merge, and clean up. It fuses /polylane (plan) and /polylane-run (execute) into a single hands-off flow after the plan gate. Triggers on "/polylane-auto", "plan and run", "do the whole thing", "autopilot the lanes", "interview and launch", "build it end to end".
---

# /polylane-auto — plan AND run, one command

`/polylane` plans and stops at the paste blocks. `/polylane-run` runs an existing
plan. **`/polylane-auto` does both**: it interviews you, locks the spec, derives
the lanes, generates the prompts + manifest, then — with no further command —
launches the panes, polls them, integrates, merges on GO, and cleans up.

**Two interactive gates remain (the interview): the spec gate and the plan gate.
After you approve the plan, the run is fully hands-off** — launch, poll, integrate,
merge, and scratch-delete all proceed without stopping.

## How it composes the two skills

This skill runs the polylane planner phases verbatim, then hands the emitted
manifest to the runner. Do not re-implement either — drive them.

### Phase 1–6 — plan (identical to /polylane)
Follow `~/.claude/skills/polylane/SKILL.md` Phases 1 through 6 exactly, including:
- **Phase 1 interview** — batched AskUserQuestion until a numbered INTEGRATION SPEC;
  ask the ONE intensity question (`economy | balanced | performance | max | custom`,
  `balanced` recommended) + the optional available-models step.
- **Phase 2 spec gate** — blocking; only an explicit yes advances.
- **Phase 3 recon** — `git status` + `git worktree list` FIRST; protect orphans.
- **Phase 4** — derive lanes from file-overlap; resolve per-lane model+effort from
  the intensity preset against `available_models`.
- **Phase 5 plan gate** — blocking; present the lane table + per-lane override;
  **default isolation = one git worktree per lane.**
- **Phase 6** — generate every lane prompt (mandatory-4 preamble, OWN/FORBIDDEN +
  contracts, forced-verify, done-signal `docs/status-<lane>.md`), write each to
  `.polylane/lanes/<lane>.txt`, and emit `.polylane/run.json` (frozen schema).

**Difference from /polylane:** do NOT stop after Phase 6. The paste blocks are still
printed for the record, but the manifest is the real handoff — continue straight to
the run below.

### Phase 6.5 — create the worktrees
The plan gate approved worktree isolation, so before launching, create one worktree
+ branch per lane from the manifest (idempotent — skip any that exist):
```
jq -r '.lanes[] | "\(.worktree) \(.branch)"' .polylane/run.json | while read wt br; do
  git worktree add "$wt" -b "$br" 2>/dev/null || echo "exists: $br"
done
```
(The runner also self-heals missing worktrees, but creating them here keeps the
dry-run readable.)

### Phase 7 — run hands-off (drive the runner)
Resolve the runner once (portable — works in any project), preview, then launch
**with `--yes`** so the run needs no further confirmation (the plan gate already
approved it):
```
RUNNER="$(command -v polylane-run.sh 2>/dev/null || echo "$HOME/.claude/skills/polylane/bin/polylane-run.sh")"
test -x "$RUNNER" || { echo "runner not found at $RUNNER — reinstall polylane"; exit 1; }
for t in tmux jq claude; do command -v "$t" >/dev/null || { echo "$t MISSING — install it"; exit 1; }; done

"$RUNNER" .polylane/run.json --dry-run          # for the record — show the panes
"$RUNNER" .polylane/run.json --yes              # hands-off: launch → poll → integrate → merge → delete
```
`--yes` pre-approves the runner's launch and final scratch-delete prompts. The
runner then, on its own: opens one tmux pane per lane, auto-polls each
`<worktree>/docs/status-<lane>.md` until all DONE, runs the integrator over the
finished branches, merges on GO (re-merge of current HEADs), and deletes worktrees
+ branches + `.polylane` scratch while keeping `docs/verify-*.md`. When it finishes
it writes `docs/polylane-report.md` — the plain-terms digest of the whole run.

### Phase 8 — report back to the chat (REQUIRED — do not skip)
The run happens in tmux, out of the user's sight. **When it finishes you MUST
surface the result in this chat, in simple terms.** Wait for the runner to complete
(poll for `docs/polylane-report.md` to appear, or wait on the background task),
then read it (plus `docs/verify-integration.md` for verdict detail):
```
test -f docs/polylane-report.md && cat docs/polylane-report.md
```
Then post a short, plain-language summary in the chat — the user's own words, no
jargon:
- **What happened** — GO or NO-GO, how many lanes, what got built + merged.
- **Per lane** — one line each, from the report's Lanes table.
- **Suggested next steps** — the report's next-steps, phrased simply (e.g. "push to
  back it up", "one thing needs your call: <the flagged item>", "UI wasn't visually
  checked — want me to?").
Keep it to a few lines. If NO-GO: say plainly what blocked it and that the worktrees
are still there to fix.

## Runtime model controls (optional, same as /polylane-run)
Both override flags still compose onto the launch call — layer them on and dry-run
first:
- `--intensity <economy|balanced|performance|max>` — remap the whole run at launch.
- `--model <lane=model_id>` — pin one lane (repeatable).
```
"$RUNNER" .polylane/run.json --intensity performance --model docs=claude-fable-5 --yes
```

## What stays interactive vs automatic
| Step | Interactive? |
|---|---|
| Interview + spec gate | **Yes** — you approve the spec |
| Recon (orphan protection) | Auto (surfaces orphans if any) |
| Lane derivation + models | Auto |
| Plan gate + per-lane override | **Yes** — you approve the plan |
| Worktrees, launch, poll, integrate, merge, delete | **Auto** (`--yes`) |

## Requirements
Same as `/polylane-run`: **tmux**, **jq**, **claude** on PATH, and the polylane
skill installed (this skill drives its runner + references). Optional
`ANTHROPIC_API_KEY` enables live model probing; without it a curated fallback list
is used.

## Install
```
cp -r polylane-auto/ ~/.claude/skills/polylane-auto/
```
Then type `/polylane-auto` (or "plan and run", "do the whole thing"). For the
granular steps, `/polylane` (plan only) and `/polylane-run` (run only) remain.
