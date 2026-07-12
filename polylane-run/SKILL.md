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

### 3. Doctor preflight (always, before the dry-run)
Run the doctor before anything launches. It ships next to the runner:
```
DOCTOR="$(dirname "$RUNNER")/polylane-doctor.sh"
"$DOCTOR" .polylane/run.json
```
CLI: `bin/polylane-doctor.sh [manifest]` — the manifest argument is optional;
pass it so the doctor checks this run's plan too. The exit code is the contract:
**exit 0 = healthy, exit 1 = problem found**. On exit 1, relay the doctor's
output to the user and stop — fix what it reports before moving to the dry-run.

### 4. Dry-run first (always)
Show the planned panes without launching anything:
```
"$RUNNER" .polylane/run.json --dry-run
```
Relay the output to the user: how many panes, which lane in each, the model/effort
per lane. This is the review gate — the user sees the plan before any terminal opens.

### 5. Launch on go-ahead
Only after the user approves the dry-run. **For an unattended/walk-away run, launch
through the supervisor** — it owns the runner's lifecycle: relaunches a crashed
runner with `--resume` (DONE lanes skipped), drains SAFE approval prompts even while
the runner is dead, parks + notifies CRITICAL ones, and writes a heartbeat. Runner
death was the dominant failure mode of real long runs; the supervisor makes it a
non-event:
```
SUPERVISOR="$(dirname "$RUNNER")/polylane-supervisor.sh"
"$SUPERVISOR" .polylane/run.json            # implies --yes; extra runner args pass through
```
For an interactive run the user watches live, the bare runner is fine:
```
"$RUNNER" .polylane/run.json
```
(Optional: append `--yes` to pre-approve the runner's own prompts — including the
final scratch-delete — for an unattended run. Default flow leaves them interactive.
Optional: append `--push` to auto-push the merged result on GO — see
"Push on GO" below. Offer the dashboard pane now too — see "Watch the run".)

**Answer "are they done?" with ONE command — never by hand-capturing panes/git/files:**
```
"$(dirname "$RUNNER")/polylane-state.sh" .polylane/run.json   # or --json
```
Per lane: `done | likely-done(verify me) | awaiting-approval(safe|CRITICAL) | stalled |
errored | working | no-pane` + branch HEAD + commits ahead, plus runner-alive /
verdict / report / supervisor-heartbeat age. `likely-done` = the work exists but the
done-signal is missing → verify + recover instead of waiting forever.

### 6. Explain what happens next
Tell the user, once, what the runner now does on its own:
- **Auto-polls** each lane pane until every lane signals done.
- **Auto-retries transient errors** — every 5 min it scans each unfinished pane for
  an API 500 / overloaded / network error and respawns (retries) that lane, up to 3×
  (tune via `POLYLANE_HEALTH_INTERVAL` / `POLYLANE_MAX_RETRIES`). Past the cap the run
  halts and writes the report instead of hanging.
- **Auto-integrates** — runs the integrator lane over the finished branches.
- **Merges on GO** — when the integrator issues GO on a re-merge of current HEADs,
  the branches merge into one project folder.
- **Detects usage-limit stalls** — a lane stalled on a usage limit is NOT
  auto-retried (retrying can't help until the limit resets); the runner fires a
  `stall` notification and waits for the user's manual decision — see "Stall
  detection" below.
- **Notifies on milestones** — fires `bin/polylane-notify.sh <event> <msg>` on
  `done`, `go`, `no-go`, `halt`, and `stall`, so the user hears about outcomes
  without watching the panes — see "Notifications" below.
- **Keeps per-lane logs** — each lane's output is captured to
  `docs/lane-logs/<lane>.log` and kept after cleanup — see "Lane logs" below.
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
launch. All these flags are additive — the base CLI stays
`<manifest> [--dry-run] [--yes]`, extended by
`[--push] [--resume] [--intensity <economy|balanced|performance|max>]
[--model <lane=model_id>]...`.

## Watch the run — dashboard pane

The dashboard is a live status view of the whole run, meant to sit in its own
tmux pane (or any spare terminal) while the runner works. It ships next to the
runner:
```
DASHBOARD="$(dirname "$RUNNER")/polylane-dashboard.sh"
tmux split-window -h "$DASHBOARD .polylane/run.json"
```
CLI: `bin/polylane-dashboard.sh <manifest> [--interval N]` — `--interval N`
sets the refresh interval in seconds. Offer it to the user right after launch;
it can be closed and reopened at any point in the run.

## Notifications

The runner announces the run's milestones through the notifier, which ships
next to it. CLI: `bin/polylane-notify.sh <event> <msg>` — events:
`done | go | no-go | halt | stall`.

- `done` — work completed.
- `go` — the integrator issued GO; the merge proceeds.
- `no-go` — the integrator blocked the merge.
- `halt` — the run stopped early (e.g. a lane failed past its retry cap).
- `stall` — a lane hit a usage limit and needs a manual decision.

The runner fires these itself; you can also invoke the CLI by hand once to
check that notifications reach the user.

## Parallel runs — POLYLANE_SESSION

The runner names its tmux session `polylane` by default. To run two or more
runs side by side, give each its own session name via the environment:
```
POLYLANE_SESSION=myrun "$RUNNER" .polylane/run.json
```
Everything tmux-related for that run happens inside the named session, so
parallel runs never collide.

## After a halt — `--resume`

If the run halted — a lane failed past its retry cap, a stall was cut short,
or the runner itself was interrupted — relaunch with `--resume` instead of
starting over:
```
"$RUNNER" .polylane/run.json --resume
```
It continues the halted run where it left off rather than launching a fresh
one. It composes with the other flags — preview with `--resume --dry-run`.

## Push on GO — `--push`

Pass `--push` at launch to have the runner push the merged result once the
integrator issues GO:
```
"$RUNNER" .polylane/run.json --push
```
Without it the merge stays local and the report suggests pushing by hand.
On NO-GO nothing is pushed.

## Stall detection (usage limits)

Transient API errors are auto-retried (see above). A **usage-limit stall is
different**: retrying cannot help until the limit resets, so the runner does
not burn retries on it. When it detects a stalled lane it fires a `stall`
notification and leaves the decision to the user — wait the limit out, or halt
the run and pick it back up later with `--resume`. Manual decision by design;
relay the notification and ask the user which way to go.

## Approval relay (permission prompts)

Lanes launch in **`--permission-mode acceptEdits`**, so a lane editing its own
files in its own worktree never hangs on an edit prompt. A lane can still hit a
permission prompt for a **non-edit** tool (a bash command, etc.). Every poll the
runner runs an **approval relay** that triages it:
- **SAFE** (local test/build, `git add`/`commit` of its own files, `mkdir`, `ls`,
  `node` — the isolated-worktree common case) → **auto-approved** (the runner sends
  the approve key). The run keeps moving with no human input.
- **CRITICAL** (network: `curl`/`npm install`; destructive: `rm -rf`; `git push`/
  `--force`; secrets/`.env`; anything reaching outside the worktree) → **NOT
  auto-answered**. The runner fires an **`approval`** notification and PARKS the lane,
  exactly like a usage stall.

**Your job when an `approval` notification fires:** read the parked pane
(`tmux capture-pane -t <session>:0.<idx> -p | tail -20`), see what it's asking, then:
- if on reflection it is genuinely safe → send the approve key
  (`tmux send-keys -t <session>:0.<idx> '1'`, or `'2'` for "don't ask again");
- if it is a real decision (spend, irreversible, a product call) → **ask the user in
  the main chat**, get their answer, then relay it back to the lane with `send-keys`.
Never blanket-approve a critical prompt on the user's behalf. Override the launch
mode with `POLYLANE_PERMISSION_MODE` if a run needs stricter/looser defaults.

## Lane logs — audit trail

Each lane's output is captured to `docs/lane-logs/<lane>.log`, and the logs
are **kept** through cleanup — after worktrees, branches, and scratch are
gone, they remain as the audit trail of what every lane actually did. Point
the user at them for any "why did lane X do that?" question after the run.

## Environment knobs

| Variable | Default | What it does |
|---|---|---|
| `POLYLANE_SESSION` | `polylane` | tmux session name — set one per run for parallel runs |
| `POLYLANE_POLL_INTERVAL` | `15` | seconds between DONE-file polls |
| `POLYLANE_HEALTH_INTERVAL` | `300` | seconds between error-scans that auto-retry a lane stuck on a transient API/network error |
| `POLYLANE_MAX_RETRIES` | `3` | retries per lane before it is marked failed |

## Install

Copy this skill into your Claude Code skills dir:
```
cp -r polylane-run/ ~/.claude/skills/polylane-run/
```
Then type `/polylane-run` (or "run the lanes" / "launch the terminals") after
`/polylane` has planned a run.
