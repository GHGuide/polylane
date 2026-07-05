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
bin/polylane-run.sh .polylane/run.json --dry-run
```
Relay the output to the user: how many panes, which lane in each, the model/effort
per lane. This is the review gate — the user sees the plan before any terminal opens.

### 4. Launch on go-ahead
Only after the user approves the dry-run, run the same command **without** `--dry-run`:
```
bin/polylane-run.sh .polylane/run.json
```
The runner opens the tmux panes and starts every lane.
(Optional: append `--yes` to pre-approve the runner's own prompts — including the
final scratch-delete — for an unattended run. Default flow leaves them interactive.)

### 5. Explain what happens next
Tell the user, once, what the runner now does on its own:
- **Auto-polls** each lane pane until every lane signals done.
- **Auto-integrates** — runs the integrator lane over the finished branches.
- **Merges on GO** — when the integrator issues GO on a re-merge of current HEADs,
  the branches merge into one project folder.
- **Cleans up** — removes merged worktrees/branches and quarantines strays, then
  **deletes the scratch after one confirmation** (or immediately if `--yes` was passed).

Then hand back to the runner — it drives the rest.

## Install

Copy this skill into your Claude Code skills dir:
```
cp -r polylane-run/ ~/.claude/skills/polylane-run/
```
Then type `/polylane-run` (or "run the lanes" / "launch the terminals") after
`/polylane` has planned a run.
