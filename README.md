# polylane

**Describe what you want in plain English. Polylane turns any repository-backed project
goal into a profile, strategy, safe file-isolated lanes, verified evidence, and a durable
handoff—then keeps iterating until the locked outcome is complete.**

The repository has two product entrypoints: a standalone, Codex-native
`codex/SKILL.md` and the Claude Code `SKILL.md`. They share one deterministic
engine in `bin/`, so reliability fixes land in both without mixing model ids,
prompt syntax, skills, or CLI behavior. Codex never substitutes app subagents for
the tmux `codex exec` lanes.

You stay in the loop for **core decisions only**. Everything else is derived,
launched, verified, repaired, merged, documented, and routed into the next cycle.
State survives conversations; the supervisor recovers crashes, HALTED runners,
dead panes, usage limits, missing seeds, and frozen workers.

---

## Quickstart

Install the Codex package (current priority) and two runner dependencies:

```bash
git clone https://github.com/GHGuide/polylane
cd polylane && ./codex/install.sh --user
brew install tmux jq   # runner deps (Debian/Ubuntu: apt-get install -y tmux jq)
```

Then the whole happy path is three lines:

```
cd your-project && codex
> $polylane turn this goal into a verified outcome: <your idea, research, workflow, data, content, or app>
# Answer only material outcome/secrets/money/external-authority decisions. Polylane keeps working.
```

Prefer to just plan and stop at paste-ready prompts? Say "only plan the lanes, don't run them" — polylane will stop at the plan gate. (See [install-helpers](references/install-helpers.md) for details.)

**Works best with** (polylane recommends/installs them for you where relevant):
- graphify — code knowledge graph (query instead of grep)
- caveman — terse output mode
- [superpowers](https://github.com/obra/superpowers) — verification / debugging / plans

None are hard requirements — polylane degrades gracefully (Explore-agent fallback if there's no graph, a terse instruction if caveman isn't installed, etc.).

### Project profiles and truthful completion

Polylane begins by selecting a concise profile and writing
`docs/polylane/PROJECT_PROFILE.md`: outcome, deliverables, stakeholders, constraints,
evidence, risk, external actions, and finish conditions. It supports software,
trading/quant research, research/analysis, operations/business, content/creative,
data/automation, and custom/mixed projects. UI visual intelligence is used only for
user-facing UI work.

Trading defaults to research, backtest, walk-forward, and paper evidence with data
provenance, leakage, costs/slippage, drawdown, robustness, and risk limits. Live capital,
publication, sent communications, production changes, purchases, and physical execution
always need explicit user authority and actual evidence; a plan or simulation is not a
completed action. See [project profiles](references/project-types.md).

---

## Why polylane (vs "swarm" / autonomous multi-agent frameworks)

Most multi-agent tools (swarm frameworks, `/batch`, fire-and-forget agent runtimes) **spawn a fixed fan-out of autonomous agents and hope for the best.** polylane is the opposite philosophy — an **operator pattern** that keeps you in control and keeps the token bill sane:

| | Autonomous swarm / ultra-agents | **polylane** |
|---|---|---|
| **How many agents** | Fixed fan-out ("spawn 10–30 subagents") | **Optimal count derived from real file-overlap** — merges lanes that would collide, splits genuinely independent work. No wasted parallelism. |
| **Collisions** | Agents edit shared files → clobber, merge hell | **Hard file isolation** — every lane gets an OWN/FORBIDDEN file list + a frozen public-API contract. Zero source overlap by construction. |
| **Control** | Runs autonomously, you find out later | **Two approval gates** (spec lock, plan lock) + click-only questions. You approve the plan before a single prompt runs. |
| **Cost** | Dozens of agents burning tokens in the background | **One visible tmux pane per lane** — `tmux attach` and watch any of them; nothing spawns silently. Plus per-lane model/effort tuning and terse output (see below). |
| **Verification** | "Done" = the agent said so | **Frozen executable acceptance + forced evidence** — focused checks per cycle, terminal suite once at final certification, and an integrator verdict. NO-GO starts a repair wave. |
| **Cleanup** | Leftover worktrees + branches pile up | **Auto merge + cleanup** — removes merged worktrees, deletes merged branches, quarantines strays into one folder. |

It's not "more agents." It's **the right agents, isolated, verified, and cheap.**

### Measured product autonomy

Cycle 9 adds a versioned vague-brief product benchmark, durable discovery,
agent-aware model selection, lean Codex launch profiles, prompt-budget checks,
outcome-learned minimal skill kits, advanced runtime hooks, three independent
quality judges, and the canonical control room. Their frozen commands and
honesty rules live in [the runtime contract](references/cycle-9-control-room.md).

Polylane can also improve its own skills without letting a reflection model edit
the live instructions. Verified failures trigger immutable challenger copies;
frozen train/development/hidden cases, cost ceilings, and three blind judges choose
a winner. Promotion protects concurrent user edits, and a failed canary restores
the previous generation. See [evidence-gated skill evolution](references/skill-evolution.md).

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

1. **Interview → profile → spec.** Batched click-through questions establish the intended outcome, deliverables, evidence, risk, and finish conditions before a numbered integration spec is locked. External or authority-gated items are explicit so final GO is never surprised.
2. **Recon.** `git status` first — any uncommitted orphan work is surfaced and protected before any branch op. Then maps goals → files (via the graph, not grep).
3. **Derive lanes.** Optimal count + carving from file-overlap. Every builder gets one or two predefined and one or two lane-specific installed skills; GitHub candidates stay informational.
4. **Plan gate.** You approve the lane table, models, isolation mode (worktrees vs shared tree), and which suggested skills to install.
5. **Generate prompts.** One paste-ready prompt per lane — each opens with the graphify/caveman/`/goal`/superpowers preamble, then OWN/FORBIDDEN + contracts, forced-verify, coordination, scoped git, done-checklist. Plus an optional **integrator** lane that runs last. `/polylane` also emits the run manifest `.polylane/run.json`.
6. **Launch + watch.** Contract v2 rejects missing state, acceptance, artifacts, skills, prompt blocks, and overlapping scope before tmux opens. The supervisor launches real CLIs and prints one valid watch command: `tmux attach -t <session>`.
7. **Integrate + continue.** GO promotes. NO-GO/UNKNOWN preserves evidence and repairs in-process. `EXTERNAL-EVIDENCE-OPEN` promotes verified engineering and routes around manual proof. Cycle artifacts and the next plan are required before continuing.
8. **Learn safely.** Repeated skill failures create benchmarked challengers; the active champion changes only after hidden evaluation and remains rollback-safe.

For Codex, each tmux pane is mechanically prevented from spawning nested agents.
The runner also caches unchanged expensive checks and detects command churn with no
source/evidence progress; it narrows and downgrades the lane instead of spending
another identical wave.

---

## The feature tour

Everything below belongs to the runner and its helpers. The full CLI:

```
polylane-run.sh <manifest> [--dry-run] [--yes] [--push] [--resume] [--intensity ...] [--model lane=id]
```

`--dry-run` previews every pane before anything launches; `--yes` pre-approves the runner's own prompts for unattended runs; `--intensity <economy|balanced|performance|max>` remaps every lane's model at launch and `--model lane=id` pins one lane on top of it — no manifest editing.

For contract-v2 runs, Polylane prints the resolved model/effort policy before
launch, validates and launches frozen-contract-equivalent compiled prompt copies,
and records explicit selected-skill outcomes after each builder. The planner uses
a metadata-only local skill catalog; builders receive only their selected ids.
See [cycle-13-integration.md](references/cycle-13-integration.md) for the exact
commands and project-local safe-admission boundary.

Lifecycle hook fragments are optional and project-scoped: review
`assets/hooks/codex-hooks.json` or `assets/hooks/claude-settings.json` before
merging either into a target project. They never modify global settings or
replace the supervisor. Use `bin/polylane-certify.sh focused` during integration
and `bin/polylane-certify.sh terminal` once for the fresh terminal matrix.

### Cross-lane relay

The runner exports `POLYLANE_PROJECT_ROOT` and `POLYLANE_COORDINATION_FILE` into
every pane. Builders use `bin/polylane-coordinate.sh` for append-only `request`,
`decision`, `claim`, `release`, `pending`, and `snapshot` operations. This keeps
live coordination and resource mutexes outside isolated worktrees; stale locks are
recovered safely. `docs/parallel-status.md` is a post-cycle summary, not the live
coordination channel.

### Retained workers and bounded context

Set `"prime_hybrid": true` in a long-running manifest to retain worker identities
and evidence safely across cycles. Before launch, Polylane validates pending local
refinements, imports the canonical relay, and writes one bounded
`.polylane/context/<lane>.md` packet per lane. The runner exports its canonical
harness, workers directory, stable worker id, and packet path to each pane; global
prompt or skill ideas remain proposal-only handoffs to `polylane-skill-evolve.sh`.
Repeated failures, stalls, NO-GOs, or compaction signals automatically enter a
deduplicated refinement queue; the integrator must propose a check-backed local
change or explicitly decline it, and accepted changes validate or roll back next cycle.
Legacy manifests are unchanged.

### End-of-run report

The run happens in tmux, so the runner writes `docs/polylane-report.md` with the
verified outcome, one line per lane, actual goal-tree counts, and suggested next
steps. Intermediate NO-GO attempts remain repair evidence and are not exposed as
false cycle-completion reports.

```
cat docs/polylane-report.md
```

### Auto-retry on transient errors

A lane that dies on an API/network error should not sink the run. The runner
polls DONE markers every 2 seconds and health-checks every 15 seconds. It retries
transient failures, uses a different reflect-and-repair approach after retry
exhaustion, and treats an unchanged pane for about 60 seconds as wedged.

```
POLYLANE_MAX_RETRIES=5 polylane-run.sh .polylane/run.json --yes
```

### Usage-limit stall detection

Hitting an agent usage limit is not a code failure. The unattended default tries
the next configured lower-cost model. `POLYLANE_ON_LIMIT=wait` holds for a bounded
number of health cycles; `credits` may be used only when the user authorized that
spend behavior.

### Resume a run

Re-running after a failure, stall, or Ctrl-C shouldn't redo finished work. `--resume`
skips every valid DONE lane and adopts surviving tmux panes for unfinished builders
or the integrator. A same-named unrelated session is rejected rather than killed or
reused.

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

Persist the same name as `"session": "run2"` in the manifest so observers and
resumed supervisors recover the exact attach command without chat memory.
(`POLYLANE_POLL_INTERVAL` tunes the DONE-file poll, default 2s.)

### Control room

The read-only control room projects the runner's canonical state rather than
reconstructing panes or markers. For automation or a support handoff, take one
truthful snapshot; unknown spend, cleanup, or graph facts stay unknown. Completion
still belongs to the shared current-nonce marker contract; its exact first line is
valid with or without a final newline.

```
bin/polylane-dashboard.sh .polylane/run.json --once --json
```

Without `--once`, it renders that same snapshot repeatedly in a second terminal.

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

- **Codex CLI** (`codex` on PATH) for the Codex package, or **Claude Code CLI**
  (`claude`) for the Claude package.
- **A git repository** for the target project — worktree/branch isolation and the merge/cleanup phase need one.
- **tmux + jq** — needed to launch + run lanes; a plan-only run (stops at the plan gate) needs neither.
- **macOS for notifications** — `polylane-notify.sh` uses `osascript`; elsewhere it silently no-ops.
- **shellcheck** — optional, and only if you hack on the runner scripts themselves.

## Troubleshooting

**A lane hit the usage limit.** The runner first follows `POLYLANE_ON_LIMIT`
(default `fallback`). If a real money/credits decision remains, it parks the lane
and surfaces the exact `tmux attach -t <session>` line. Independent autonomous
lanes continue.

**Disk space.** Worktree isolation checks out one full copy of the repo per lane. On a big repo × many lanes that adds up — `bin/polylane-doctor.sh` warns below 5 GB free and fails below 1 GB. Free space or approve fewer lanes at the plan gate.

**Two runs collide in tmux.** Symptom: a launch errors on an existing session, or panes from another run show up. Fix: give the second run its own session name with `POLYLANE_SESSION=<name>`; doctor flags the collision before launch.

---

## Design principles (why it holds up in real use)

- **Descriptions describe *when to trigger*, not the workflow** — the skill body loads on demand (progressive disclosure), so triggering it is cheap.
- **Positive recipes, closed loopholes** — generated prompts state exactly what to do (never `git add -A`, no "done" without an evidence file, shared file → request-an-edit not edit-it), so generation is deterministic.
- **Generic, not project-specific** — build recipes, device IDs, and quirks come from the target project's `CLAUDE.md`; the skill ships zero hardcoded specifics.
- **You in the loop for core decisions only** — routine cycle gates take their
  recommended autonomous route. Council verdicts and reports never become pauses.

## License

MIT — see [LICENSE](LICENSE).
