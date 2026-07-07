---
name: polylane-run
description: Use when the user wants to actually LAUNCH the lanes that /polylane planned — locates the run manifest and drives bin/polylane-run.sh to open the tmux panes, auto-poll each lane, auto-integrate, merge on GO, and clean up scratch. Triggers on "/polylane-run", "run the lanes", "launch the terminals", "execute the plan", "start the builders".
---

# /polylane-run — launch the planned lanes

`/polylane` plans; `/polylane-run` executes. This skill finds the run manifest
`/polylane` emitted and hands it to `bin/polylane-run.sh`, which opens one tmux
pane per lane, polls them to completion, integrates, merges on GO, and cleans up.

**This skill only drives the runner. It does not plan lanes, edit source, or
merge by hand — the shell script owns all of that.**

## Requirements

- **tmux** — the runner puts each lane in its own pane. `brew install tmux`.
- **jq** — the runner reads the manifest with it. `brew install jq`.
- **claude** — the Claude Code CLI, on PATH; each pane launches one.
- **`.polylane/run.json`** — the run manifest, emitted by `/polylane`. If it is
  missing, there is nothing to run — the user must run `/polylane` first.

The runner consumes **exactly** what `/polylane` writes: the single manifest at
`.polylane/run.json`. No other input.

## What to do when invoked

Run these in order. Do not skip the dry-run.

### 0. Resolve the runner script (portable — works in any project)
The script ships with the polylane skill, not with the target project. Resolve it
once — prefer PATH, else the skill install path — and use `"$RUNNER"` everywhere below
(never a bare relative `bin/polylane-run.sh`, which only exists inside the polylane repo):
```
RUNNER="$(command -v polylane-run.sh 2>/dev/null || echo "$HOME/.claude/skills/polylane/bin/polylane-run.sh")"
test -x "$RUNNER" || { echo "runner not found at $RUNNER — reinstall polylane"; exit 1; }
```

### 1. Check the manifest exists
```
test -f .polylane/run.json && echo FOUND || echo MISSING
```
If `MISSING`: stop and tell the user — *"No `.polylane/run.json`. Run `/polylane`
first to plan the lanes, then re-run me."* Do not fabricate a manifest.

### 2. Preflight the tools
```
for t in tmux jq claude; do command -v "$t" >/dev/null && echo "$t ok" || echo "$t MISSING"; done
```
Any `MISSING` → tell the user the install command (above) and stop.

### 3. Dry-run first (always)
Show the planned panes without launching anything:
```
"$RUNNER" .polylane/run.json --dry-run
```
Relay the output to the user: how many panes, which lane in each, the model/effort
per lane. This is the review gate — the user sees the plan before any terminal opens.

### 4. Launch on go-ahead
Only after the user approves the dry-run, run the same command **without** `--dry-run`:
```
"$RUNNER" .polylane/run.json
```
The runner opens the tmux panes and starts every lane.
(Optional: append `--yes` to pre-approve the runner's own prompts — including the
final scratch-delete — for an unattended run. Default flow leaves them interactive.)

### 5. Explain what happens next
Tell the user, once, what the runner now does on its own:
- **Auto-polls** each lane pane until every lane signals done.
- **Auto-retries transient errors** — every 5 min it scans each unfinished pane for
  an API 500 / overloaded / network error and respawns (retries) that lane, up to 3×
  (tune via `POLYLANE_HEALTH_INTERVAL` / `POLYLANE_MAX_RETRIES`). Past the cap the run
  halts and writes the report instead of hanging.
- **Auto-integrates** — runs the integrator lane over the finished branches.
- **Merges on GO** — when the integrator issues GO on a re-merge of current HEADs,
  the branches merge into one project folder.
- **Cleans up** — removes merged worktrees/branches and quarantines strays, then
  **deletes the scratch after one confirmation** (or immediately if `--yes` was passed).
- **Writes `docs/polylane-report.md`** — a plain-terms digest (outcome, per-lane
  results, next steps) on both GO and NO-GO. When the run finishes, read it and
  relay a simple summary to the user in the chat.

Then hand back to the runner — it drives the rest.

## Runtime model controls (optional)

Each lane already has a model and effort baked into the manifest (you see them in
the dry-run). Two optional flags override the models **at launch, without editing
the manifest**. Layer them onto the same `"$RUNNER" .polylane/run.json` call and
preview with `--dry-run` first.

### `--intensity <economy|balanced|performance|max>` — remap the whole run
Shifts every lane to one intensity tier in a single switch: `economy` favours the
cheapest/fastest models, `max` the strongest, with `balanced` and `performance`
in between. Preview, then launch:
```
"$RUNNER" .polylane/run.json --intensity balanced --dry-run
"$RUNNER" .polylane/run.json --intensity balanced
```

### `--model <lane=model_id>` — override a single lane
Pins one lane to a specific model and leaves every other lane as planned. It is
**repeatable** — pass it once per lane you want to change:
```
"$RUNNER" .polylane/run.json --model backend=claude-opus-4-8 --dry-run
"$RUNNER" .polylane/run.json \
  --model backend=claude-opus-4-8 \
  --model docs=claude-fable-5
```

The two flags compose: `--intensity` sets the baseline for the run, then each
`--model lane=id` pins a specific lane on top of it.
```
"$RUNNER" .polylane/run.json --intensity performance --model docs=claude-fable-5 --dry-run
```

Always dry-run first and read back the per-lane model column before the real
launch. These flags are additive — the base CLI (`<manifest> [--dry-run]
[--yes]`) is unchanged.

## Install

Copy this skill into your Claude Code skills dir:
```
cp -r polylane-run/ ~/.claude/skills/polylane-run/
```
Then type `/polylane-run` (or "run the lanes" / "launch the terminals") after
`/polylane` has planned a run.
