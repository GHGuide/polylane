# polylane

**Describe what you want in plain English. polylane splits it into file-isolated lanes, builds them in parallel Claude Code terminals — and, if you want, launches, watches, merges, and cleans up the whole run while you walk away.**

`polylane` is a set of three [Claude Code](https://docs.claude.com/en/docs/claude-code) skills that turn a plain-line description of several goals into **N optimized, file-isolated builder prompts** — and then run them. It interviews you until the spec is locked, works out the *right* number of lanes from how the code actually overlaps, tunes the model and effort per lane, bakes your best skills into every prompt, and cleans up the mess at the end.

You stay in the loop for **decisions only** — a couple of click-through questions and two approval gates. Everything else is derived, generated, launched, and merged for you.

**Four entry points:**

- **`/polylane`** — plan only: interview → spec + plan gates → paste-ready prompts. You launch them.
- **`/polylane-run`** — run an already-planned `.polylane/run.json`: launch tmux panes → poll → integrate → merge → clean up.
- **`/polylane-auto`** — both in one command: interview and gates, then hands-off launch/poll/integrate/merge/cleanup after the plan gate.
- **`/polylane-max`** — goal-driven loop: give one ultimate goal and it cycles (build → ~50-bullet report → deep-research next steps → recommended-default questions → repeat) until a critic judges the goal met or you stop.

---

## Quickstart

Install the three skills and the two tools the runner needs:

```bash
git clone https://github.com/GHGuide/polylane ~/.claude/skills/polylane
cp -r ~/.claude/skills/polylane/polylane-run  ~/.claude/skills/polylane-run
cp -r ~/.claude/skills/polylane/polylane-auto ~/.claude/skills/polylane-auto

brew install tmux jq   # runner deps; shellcheck optional (only for hacking on the runner itself)
```

Then the whole happy path is five lines:

```
cd your-project && claude
> /polylane-auto
# answer the click-through interview, approve the spec gate, approve the plan gate…
# …walk away — lanes build in tmux, integrate, merge on GO, clean up.
# come back to docs/polylane-report.md for the plain-terms digest.
```

Prefer more control? `/polylane` to plan and stop at paste-ready prompts, `/polylane-run` when you're ready to launch. (See [install-helpers](references/install-helpers.md) for details.)

**Works best with** (polylane recommends/installs them for you where relevant):
- graphify — code knowledge graph (query instead of grep)
- caveman — terse output mode
- [superpowers](https://github.com/obra/superpowers) — verification / debugging / plans

None are hard requirements — polylane degrades gracefully (Explore-agent fallback if there's no graph, a terse instruction if caveman isn't installed, etc.).

---

## Why polylane (vs "swarm" / autonomous multi-agent frameworks)

Most multi-agent tools (swarm frameworks, `/batch`, fire-and-forget agent runtimes) **spawn a fixed fan-out of autonomous agents and hope for the best.** polylane is the opposite philosophy — an **operator pattern** that keeps you in control and keeps the token bill sane:

| | Autonomous swarm / ultra-agents | **polylane** |
|---|---|---|
| **How many agents** | Fixed fan-out ("spawn 10–30 subagents") | **Optimal count derived from real file-overlap** — merges lanes that would collide, splits genuinely independent work. No wasted parallelism. |
| **Collisions** | Agents edit shared files → clobber, merge hell | **Hard file isolation** — every lane gets an OWN/FORBIDDEN file list + a frozen public-API contract. Zero source overlap by construction. |
| **Control** | Runs autonomously, you find out later | **Two approval gates** (spec lock, plan lock) + click-only questions. You approve the plan before a single prompt runs. |
| **Cost** | Dozens of agents burning tokens in the background | **One visible tmux pane per lane** — `tmux attach` and watch any of them; nothing spawns silently. Plus per-lane model/effort tuning and terse output (see below). |
| **Verification** | "Done" = the agent said so | **Forced evidence** — no lane is "done" without a `docs/verify-<lane>.md` proof file. An integrator lane re-merges current HEADs, re-verifies, and issues GO/NO-GO. |
| **Cleanup** | Leftover worktrees + branches pile up | **Auto merge + cleanup** — removes merged worktrees, deletes merged branches, quarantines strays into one folder. |

It's not "more agents." It's **the right agents, isolated, verified, and cheap.**

## Why polylane (vs just brainstorming)

The `superpowers:brainstorming` skill is excellent — for exploring **one** task's design. polylane is the layer above it:

- **Brainstorming** designs a single feature. **polylane** decomposes *many* goals into parallel lanes, generates the actual builder prompts, enforces isolation + contracts, and handles verification, merge, and cleanup.
- polylane **brainstorms once, at the orchestrator level**, then hands each builder a **locked goal** — so the builders don't each re-explore the design (which is where parallel agents usually waste tokens and drift).
- Brainstorming is a step. polylane is the whole pipeline: **interview → spec → derive lanes → tune models → generate prompts → launch → verify → merge → clean up.**

---

## Token efficiency is the point, not a side effect

polylane bakes your most token-saving skills into **every generated prompt**, automatically:

- **graphify** — builders *query a code graph* (`python graphify-out/q.py <symbol>` → ~100 bytes of `file:line` + call edges) instead of grepping and reading whole files (~5–15K tokens). polylane even ships a query helper + a `PreToolUse` nudge so builders actually use it instead of falling back to grep. It installs these into the target project during recon.
- **caveman** — terse output mode, ~75% fewer output tokens, with code/commits kept in normal prose.
- **superpowers** — `verification-before-completion`, `systematic-debugging`, `writing-plans` — the discipline that stops wasted rework.
- **`/goal`** — locks each lane's objective so it doesn't wander.

On top of that:

- **Per-lane model tuning** — Fable only where its capability actually changes the outcome; Opus everywhere else. No blanket-Fable (2× cost for no gain on mechanical work) and no blanket-Opus. Security/anonymity lanes are pinned to Opus to dodge classifier stalls.
- **Per-lane effort tuning** — `high` for builders, `xhigh` reserved for the final integrator, `medium` for mechanical lanes.
- **Brainstorm once** — locked goals downstream, so no repeated exploration.

The result: a big feature set built in parallel, with the token profile of a careful single-threaded session.

---

## What it does, step by step

1. **Interview → spec.** Batched click-through questions (you pick, you don't type) until a numbered **integration spec** is locked. Half-satisfiable items (need a bundle / paid service / product call) get flagged so the final GO isn't surprised.
2. **Recon.** `git status` first — any uncommitted orphan work is surfaced and protected before any branch op. Then maps goals → files (via the graph, not grep).
3. **Derive lanes.** Optimal count + carving from file-overlap. Per-lane model, effort, and skill recommendations.
4. **Plan gate.** You approve the lane table, models, isolation mode (worktrees vs shared tree), and which suggested skills to install.
5. **Generate prompts.** One paste-ready prompt per lane — each opens with the graphify/caveman/`/goal`/superpowers preamble, then OWN/FORBIDDEN + contracts, forced-verify, coordination, scoped git, done-checklist. Plus an optional **integrator** lane that runs last. `/polylane` also emits the run manifest `.polylane/run.json`.
6. **Launch + watch.** `/polylane-run` (or the tail of `/polylane-auto`) opens one tmux pane per lane, polls each to completion, auto-retries transient errors, and runs the integrator over the finished branches. Or launch the prompts yourself in separate terminals — they coordinate through a shared status file either way (with a device/DB/deploy **mutex** so only one lane touches a shared resource at a time).
7. **Merge + cleanup + report.** After the integrator's GO (on a re-merge of current HEADs — never a stale prior GO), consolidate to one project folder, remove merged worktrees/branches, quarantine strays — and write `docs/polylane-report.md`.

---

## The feature tour

Everything below belongs to the runner and its helpers. The full CLI:

```
polylane-run.sh <manifest> [--dry-run] [--yes] [--push] [--resume] [--intensity ...] [--model lane=id]
```

`--dry-run` previews every pane before anything launches; `--yes` pre-approves the runner's own prompts for unattended runs; `--intensity <economy|balanced|performance|max>` remaps every lane's model at launch and `--model lane=id` pins one lane on top of it — no manifest editing.

### End-of-run report

The run happens in tmux, out of your sight — so the runner writes `docs/polylane-report.md` on **both GO and NO-GO**: outcome, one line per lane, and suggested next steps in plain terms. Cost figures in the report are **rough estimates** (parsed from pane output, best-effort), good for spotting an expensive lane, not for invoicing.

```
cat docs/polylane-report.md
```

### Auto-retry on transient errors

A lane that dies on an API 500 / overloaded / network blip shouldn't sink the run. Every `POLYLANE_HEALTH_INTERVAL` seconds (default 300) the runner scans each unfinished pane and respawns any that hit a transient error, up to `POLYLANE_MAX_RETRIES` times (default 3). Past the cap the run halts and writes the report instead of hanging.

```
POLYLANE_MAX_RETRIES=5 polylane-run.sh .polylane/run.json --yes
```

### Usage-limit stall detection

Hitting your Claude usage limit is **not** an error — it's a money decision, so the runner never makes it for you. A pane showing a usage-limit prompt is marked **STALL**: you get one notification, a line in the report, and no auto-answer or respawn. See [Troubleshooting](#troubleshooting) for what to do.

### Resume a run

Re-running after a failure, stall, or Ctrl-C shouldn't redo finished work. `--resume` skips every lane whose DONE file is already valid and launches only the unfinished ones.

```
polylane-run.sh .polylane/run.json --resume
```

### Push after GO

Off by default: `--push` runs `git push` (current branch) after GO and cleanup, so the finished work is backed up the moment the run ends.

```
polylane-run.sh .polylane/run.json --yes --push
```

### Parallel runs on one machine

The tmux session is named by `POLYLANE_SESSION` (default `polylane`). Two runs on the same machine just need two names:

```
POLYLANE_SESSION=run2 polylane-run.sh .polylane/run.json
```

(`POLYLANE_POLL_INTERVAL` tunes the DONE-file poll, default 15s.)

### Live dashboard

A read-only, single-screen view of the run: lane · model · state (waiting/working/DONE/FAILED/STALL) · elapsed · last-seen tokens, refreshed every 5 seconds (`--interval N` to change). It writes nothing — watch it in a second terminal while the runner works.

```
bin/polylane-dashboard.sh .polylane/run.json
```

Want to see it before you have a run? `--demo` fabricates three lanes cycling through states:

```
bin/polylane-dashboard.sh --demo
```

### Doctor

Preflight everything the run depends on **before** burning tokens: deps (tmux, jq, git, claude), git state and colliding worktrees/branches, manifest validity, disk space, tmux session collisions. Prints a PASS/FAIL/WARN table with a one-line fix per problem; exits 0 on all-pass, 1 on any failure — so it drops straight into scripts.

```
bin/polylane-doctor.sh .polylane/run.json
```

### Notifications

macOS banner + sound at the moments that matter, so you don't have to babysit the terminal: **Ping** when a lane finishes, **Glass** on GO, **Basso** on NO-GO or halt, **Sosumi** on a stall. **macOS only** (uses `osascript`) — on anything else it's a silent no-op and never breaks the run.

```
bin/polylane-notify.sh done "lane backend finished"
```

### Lane logs

Every pane's full transcript is piped to `docs/lane-logs/<lane>.log` as it runs — so when a lane does something odd, you read exactly what it saw and said instead of scrolling tmux history. Cleanup **keeps** these logs (alongside `docs/verify-*.md` and the report).

```
tail -f docs/lane-logs/backend.log
```

---

## Requirements

- **Claude Code CLI** (`claude` on PATH).
- **A git repository** for the target project — worktree/branch isolation and the merge/cleanup phase need one.
- **tmux + jq** — only for `/polylane-run` and `/polylane-auto`. Plain `/polylane` (plan-only) needs neither.
- **macOS for notifications** — `polylane-notify.sh` uses `osascript`; elsewhere it silently no-ops.
- **shellcheck** — optional, and only if you hack on the runner scripts themselves.

## Troubleshooting

**A lane hit the usage limit (STALL).** What you'll see: the dashboard and report mark the lane `STALL`, the pane shows a message like `usage limit` / `Switch to usage credits` / `Upgrade your plan`, and on macOS you hear one Sosumi. The runner deliberately does nothing else — answering that prompt spends money, and that call is yours. What to do: `tmux attach -t polylane` (or your `POLYLANE_SESSION` name), pick an option in the pane and the lane continues — or kill the run and relaunch later with `--resume` to redo only the unfinished lanes.

**Disk space.** Worktree isolation checks out one full copy of the repo per lane. On a big repo × many lanes that adds up — `bin/polylane-doctor.sh` warns below 5 GB free and fails below 1 GB. Free space or approve fewer lanes at the plan gate.

**Two runs collide in tmux.** Symptom: a launch errors on an existing session, or panes from another run show up. Fix: give the second run its own session name with `POLYLANE_SESSION=<name>`; doctor flags the collision before launch.

---

## Design principles (why it holds up in real use)

- **Descriptions describe *when to trigger*, not the workflow** — the skill body loads on demand (progressive disclosure), so triggering it is cheap.
- **Positive recipes, closed loopholes** — generated prompts state exactly what to do (never `git add -A`, no "done" without an evidence file, shared file → request-an-edit not edit-it), so generation is deterministic.
- **Generic, not project-specific** — build recipes, device IDs, and quirks come from the target project's `CLAUDE.md`; the skill ships zero hardcoded specifics.
- **You in the loop for decisions only** — two gates, click-through questions, nothing autonomous between them.

## License

MIT — see [LICENSE](LICENSE).
