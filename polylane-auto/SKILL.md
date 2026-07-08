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
After you approve the plan, the run is TRULY walk-away** — launch, poll, integrate,
merge, and scratch-delete all proceed without stopping, and every stuck-lane case
self-recovers so nothing hangs waiting for you:
- **A lane that dies** (claude exits / crashes) is re-seeded with its locked prompt
  — never blanked to an amnesiac session.
- **A lane hitting the usage limit** follows `POLYLANE_ON_LIMIT` (default
  `fallback`: respawn on the next model down the ladder — fable→opus→sonnet→haiku —
  from the manifest's `available_models`). Alternatives: `credits` (auto-select
  paid credits) or `wait` (hold, then fail). No decision blocks the run.
- **A lane that truly can't recover** (no fallback model left, retries exhausted)
  is marked failed and the run **halts with a report** rather than hanging.
Set `POLYLANE_ON_LIMIT=credits` at launch if you'd rather spend credits than
downgrade models. Everything lands in `docs/polylane-report.md` either way.

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
Resolve the runner once (portable — works in any project), doctor-check, preview,
then launch **with `--yes`** so the run needs no further confirmation (the plan
gate already approved it):
```
RUNNER="$(command -v polylane-run.sh 2>/dev/null || echo "$HOME/.claude/skills/polylane/bin/polylane-run.sh")"
test -x "$RUNNER" || { echo "runner not found at $RUNNER — reinstall polylane"; exit 1; }
for t in tmux jq claude; do command -v "$t" >/dev/null || { echo "$t MISSING — install it"; exit 1; }; done

DOCTOR="$(dirname "$RUNNER")/polylane-doctor.sh"
"$DOCTOR" .polylane/run.json                    # doctor first — before the dry-run

"$RUNNER" .polylane/run.json --dry-run          # for the record — show the panes
"$RUNNER" .polylane/run.json --yes              # hands-off: launch → poll → integrate → merge → delete
```
**Doctor preflight:** CLI `bin/polylane-doctor.sh [manifest]` — the manifest
argument is optional; pass it so this run's plan is checked too. Exit code is
the contract: **exit 0 = healthy, exit 1 = problem found**. On exit 1, relay
the doctor's output, fix what it reports, and only then dry-run. Hands-off
never means launching over a failed doctor.

**Offer the dashboard at launch:** right after the launch command, offer the
live status pane so the user can watch the run:
```
DASHBOARD="$(dirname "$RUNNER")/polylane-dashboard.sh"
tmux split-window -h "$DASHBOARD .polylane/run.json"
```
CLI: `bin/polylane-dashboard.sh <manifest> [--interval N]` — `--interval N`
sets the refresh interval in seconds; it can be closed and reopened anytime.

`--yes` pre-approves the runner's launch and final scratch-delete prompts. The
runner then, on its own:
- opens one tmux pane per lane and auto-polls each
  `<worktree>/docs/status-<lane>.md` until all DONE;
- **auto-retries transient errors** — every 5 min it scans each unfinished pane
  for an API 500 / overloaded / network error and respawns that lane, up to 3×
  (tune via `POLYLANE_HEALTH_INTERVAL` / `POLYLANE_MAX_RETRIES`); past the cap
  the run halts and writes the report instead of hanging;
- runs the integrator over the finished branches and merges on GO (re-merge of
  current HEADs);
- **notifies on milestones** via `bin/polylane-notify.sh <event> <msg>` —
  events `done | go | no-go | halt | stall` — so outcomes reach the user
  without watching panes;
- **keeps per-lane logs** at `docs/lane-logs/<lane>.log` — they survive cleanup
  as the audit trail of what each lane did;
- deletes worktrees + branches + `.polylane` scratch while keeping
  `docs/verify-*.md`. When it finishes it writes `docs/polylane-report.md` —
  the plain-terms digest of the whole run.

### Stall + halts (the one manual moment)
A lane stalled on a **usage limit** is NOT auto-retried — retrying can't help
until the limit resets. The runner fires a `stall` notification and waits.
Relay it and ask the user: wait the limit out, or halt now. After any halt —
stall cut short, a lane failed past its retry cap, or the runner was
interrupted — relaunch with `--resume` to continue where it left off instead
of starting over:
```
"$RUNNER" .polylane/run.json --resume --yes
```
`--resume` composes with every other flag; preview with `--resume --dry-run`.

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

### Phase 9 — auto-recover, don't ask (CONTINUE by default)
A halt, NO-GO, or stuck poll is a problem to SOLVE, not a question to ask. When the
run ends short of a clean GO, **diagnose → fix → re-run, autonomously** — do not stop
to ask permission for a step you can take yourself:
- **Poll hung but lanes look done** → check `<worktree>/docs/status-<name>.md` vs the
  manifest `name`; a naming drift or an inherited stale marker is the usual cause.
  Reconcile and let the poll advance (the runner now clears inherited markers itself).
- **Integrator NO-GO / failed** → read `docs/verify-integration.md`, fix the specific
  cross-lane problem it names, then re-run with `--resume` (finished lanes are skipped).
- **A lane failed after retries + repair** → the runner already tried Reflexion; read
  its `docs/lane-logs/<lane>.log`, address the root cause, `--resume`.
- **Cleanup errored on unmerged branches** → the work is safe in the branches; merge
  the verified-green ones yourself, then clean up.
Loop this (fix → re-run) until GO or until you hit something only a human can decide.
**Only surface a decision to the user when it is genuinely theirs** — a paid/irreversible
action, a spend policy, a missing secret, or a product-direction fork. A bug, a stale
file, a naming mismatch, a mechanical merge — you fix and continue. Report what you
did in Phase 8; don't ask whether to do it.

## Runtime run controls (optional, same as /polylane-run)
All flags compose onto the launch call — layer them on and dry-run first. The
base CLI stays `<manifest> [--dry-run] [--yes]`, extended by
`[--push] [--resume] [--intensity <economy|balanced|performance|max>]
[--model <lane=model_id>]...`.
- `--intensity <economy|balanced|performance|max>` — remap the whole run at launch.
- `--model <lane=model_id>` — pin one lane (repeatable).
- `--push` — auto-push the merged result once the integrator issues GO. Without
  it the merge stays local and the report suggests pushing by hand. On NO-GO
  nothing is pushed.
- `--resume` — continue a halted run where it left off (see "Stall + halts").
```
"$RUNNER" .polylane/run.json --intensity performance --model docs=claude-fable-5 --push --yes
```

**Parallel runs:** the tmux session is named `polylane` by default. To run two
or more runs side by side, give each its own session via the environment —
everything tmux-related stays inside that session, so runs never collide:
```
POLYLANE_SESSION=myrun "$RUNNER" .polylane/run.json --yes
```

## Environment knobs

| Variable | Default | What it does |
|---|---|---|
| `POLYLANE_SESSION` | `polylane` | tmux session name — set one per run for parallel runs |
| `POLYLANE_POLL_INTERVAL` | `15` | seconds between DONE-file polls |
| `POLYLANE_HEALTH_INTERVAL` | `300` | seconds between error-scans that auto-retry a lane stuck on a transient API/network error |
| `POLYLANE_MAX_RETRIES` | `3` | retries per lane before it is marked failed |

## What stays interactive vs automatic
| Step | Interactive? |
|---|---|
| Interview + spec gate | **Yes** — you approve the spec |
| Recon (orphan protection) | Auto (surfaces orphans if any) |
| Lane derivation + models | Auto |
| Plan gate + per-lane override | **Yes** — you approve the plan |
| Doctor preflight | Auto (exit 1 stops the launch) |
| Worktrees, launch, poll, integrate, merge, delete | **Auto** (`--yes`) |
| Transient-error retries, notifications, lane logs, report | Auto |
| Usage-limit stall | **Yes** — manual decision: wait it out, or halt + relaunch with `--resume` |

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
