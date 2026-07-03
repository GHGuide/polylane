# polylane

**Describe what you want in plain English. Get back a set of ready-to-paste prompts that build it — in parallel, without stepping on each other, at the lowest token cost.**

`polylane` is a [Claude Code](https://docs.claude.com/en/docs/claude-code) skill that turns a plain-line description of several goals into **N optimized, file-isolated builder prompts** you run in parallel terminals. It interviews you until the spec is locked, works out the *right* number of lanes from how the code actually overlaps, tunes the model and effort per lane, bakes your best skills into every prompt, and cleans up the mess at the end.

You stay in the loop for **decisions only** — a couple of click-through questions and two approval gates. Everything else is derived, generated, and merged for you.

---

## Why polylane (vs "swarm" / autonomous multi-agent frameworks)

Most multi-agent tools (swarm frameworks, `/batch`, fire-and-forget agent runtimes) **spawn a fixed fan-out of autonomous agents and hope for the best.** polylane is the opposite philosophy — an **operator pattern** that keeps you in control and keeps the token bill sane:

| | Autonomous swarm / ultra-agents | **polylane** |
|---|---|---|
| **How many agents** | Fixed fan-out ("spawn 10–30 subagents") | **Optimal count derived from real file-overlap** — merges lanes that would collide, splits genuinely independent work. No wasted parallelism. |
| **Collisions** | Agents edit shared files → clobber, merge hell | **Hard file isolation** — every lane gets an OWN/FORBIDDEN file list + a frozen public-API contract. Zero source overlap by construction. |
| **Control** | Runs autonomously, you find out later | **Two approval gates** (spec lock, plan lock) + click-only questions. You approve the plan before a single prompt runs. |
| **Cost** | Dozens of agents burning tokens in the background | **You launch the terminals** — no runtime silently spawning agents. Plus per-lane model/effort tuning and terse output (see below). |
| **Verification** | "Done" = the agent said so | **Forced evidence** — no lane is "done" without a `docs/verify-<lane>.md` proof file. An integrator lane re-merges current HEADs, re-verifies, and issues GO/NO-GO. |
| **Cleanup** | Leftover worktrees + branches pile up | **Auto merge + cleanup** — removes merged worktrees, deletes merged branches, quarantines strays into one folder. |

It's not "more agents." It's **the right agents, isolated, verified, and cheap.**

## Why polylane (vs just brainstorming)

The `superpowers:brainstorming` skill is excellent — for exploring **one** task's design. polylane is the layer above it:

- **Brainstorming** designs a single feature. **polylane** decomposes *many* goals into parallel lanes, generates the actual builder prompts, enforces isolation + contracts, and handles verification, merge, and cleanup.
- polylane **brainstorms once, at the orchestrator level**, then hands each builder a **locked goal** — so the builders don't each re-explore the design (which is where parallel agents usually waste tokens and drift).
- Brainstorming is a step. polylane is the whole pipeline: **interview → spec → derive lanes → tune models → generate prompts → verify → merge → clean up.**

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
5. **Generate prompts.** One paste-ready prompt per lane — each opens with the graphify/caveman/`/goal`/superpowers preamble, then OWN/FORBIDDEN + contracts, forced-verify, coordination, scoped git, done-checklist. Plus an optional **integrator** lane that runs last.
6. **Merge + cleanup.** After the integrator's GO (on a re-merge of current HEADs — never a stale prior GO), consolidate to one project folder, remove merged worktrees/branches, quarantine strays.

You launch the prompts in separate terminals. They coordinate through a shared status file (with a device/DB/deploy **mutex** so only one lane touches a shared resource at a time).

---

## Install

```bash
git clone https://github.com/OWNER/polylane ~/.claude/skills/polylane
```

Then in Claude Code, type `/polylane` (or just describe several goals and ask for parallel prompts).

**Works best with** (polylane recommends/installs them for you where relevant):
- [graphify](https://github.com/) — code knowledge graph (query instead of grep)
- caveman — terse output mode
- [superpowers](https://github.com/obra/superpowers) — verification / debugging / plans

None are hard requirements — polylane degrades gracefully (Explore-agent fallback if there's no graph, a terse instruction if caveman isn't installed, etc.).

## Requirements

- Claude Code CLI.
- A git repository for the target project (worktree/branch isolation + the merge/cleanup phase).

---

## Design principles (why it holds up in real use)

- **Descriptions describe *when to trigger*, not the workflow** — the skill body loads on demand (progressive disclosure), so triggering it is cheap.
- **Positive recipes, closed loopholes** — generated prompts state exactly what to do (never `git add -A`, no "done" without an evidence file, shared file → request-an-edit not edit-it), so generation is deterministic.
- **Generic, not project-specific** — build recipes, device IDs, and quirks come from the target project's `CLAUDE.md`; the skill ships zero hardcoded specifics.
- **You in the loop for decisions only** — two gates, click-through questions, nothing autonomous between them.

## License

MIT — see [LICENSE](LICENSE).
