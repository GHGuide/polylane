# Reusable prompt blocks (compose these into each lane prompt)

Fill `<...>` slots from recon + derivation. Keep blocks verbatim otherwise — they encode hard-won rules.

## 0. Selected-skill preamble — every builder prompt
Use the platform-native form. Do not add a generic stack or skill-discovery commands:

Before a lane is launched, run `bin/polylane-promptopt.sh check <prompt> [budget]`.
It must retain every strict block below while enforcing the configured byte/token
budget. Resolve selected skills to trusted local `SKILL.md` paths and use the
smallest outcome-learned kit; never pad a prompt with filler skills. Frozen details:
[cycle-9-control-room.md](cycle-9-control-room.md).
```
Claude builder: read only the named kit once, in listed order.
Codex builder: read only the named kit once, in listed order; follow these native prompt instructions directly.
```
Do not require Claude slash commands in a Codex prompt. Do not browse, list, or search skill inventories after launch.
**Lanes do NOT run `/graphify-auto`** — the ORCHESTRATOR refreshes the graph once per
cycle before launch, and the runner symlinks the parent's `graphify-out/` into every
worktree (`share_graph`), so each lane already has the CURRENT graph read-only. A lane
refreshing it would race its siblings through the shared symlink and waste N rebuilds
of the same commit. Lanes only QUERY (block E). **Step 3 `/ponytail full` is included ONLY when the ponytail plugin is installed** (check `ls ~/.claude/skills/ | grep ponytail` or the plugins cache during recon) — it enforces "build the minimum that meets the goal, the best code is the code you never wrote" (~54% less code, ~20% cheaper on real sessions), which is squarely polylane's token mission; omit the line cleanly if absent (skill-scout recommends installing it — see `skill-scout.md`). The caveman LEVEL in step 2 follows the round's intensity — write `(ultra)` when the round is `economy`, `(full)` otherwise (per `model-selection.md`); the step itself is never dropped or reordered. Ponytail level tracks the same: `ultra` under `economy`, `full` otherwise. Fallbacks only if a project genuinely lacks one: caveman → the terse instruction in block C; graphify → the Explore-agent fallback in block E. Never omit the intent. This block is the DOMAIN-AGNOSTIC base for EVERY lane; the per-lane skill scout (references/skill-scout.md) never re-suggests these — it layers only DOMAIN skills into block D on top.

## A. Identity + context
```
ULTIMATE-GOAL: <verbatim durable product goal>
CURRENT-SUBGOAL: <verbatim cycle subgoal>
Project: <PROJECT one-liner>. Read THIS project's CLAUDE.md and memory/MEMORY.md first. IGNORE any unrelated CLAUDE.md from other projects. YOUR LANE = <LANE NAME>. Other Claudes run <other lanes> in parallel — do NOT touch their files.
```

## B. Model + effort header
```
Run on <MODEL> at <EFFORT> effort: confirm with /model, ultrathink before non-trivial steps.
```

## C. Terse output (token efficiency) — ALWAYS (block 0 already invokes the caveman skill; this is the wording + fallback)
```
Keep output terse (caveman-style: drop articles/filler/hedging, fragments OK). Write code, commits, and PRs in normal prose. Act when you have enough information; do not re-derive settled facts or narrate options you won't pursue.
```

## D. Skills for this lane
```
PREDEFINED-SKILLS: <1-2 exact selected installed execution/testing skills>
LANE-SPECIFIC-SKILLS: <1-2 exact selected installed domain skills>
Read only the named kit once. Your goal is LOCKED (below); go straight to execution.
```
`<lane skills>` is filled in TWO layers, in order:
1. **Static type-baseline**: select one or two relevant installed skills, not an unconditional stack.
2. **Scouted DOMAIN skills** (this cycle's per-lane scout — `references/skill-scout.md`):
   read structured `.polylane/lane-skills.json` and append THIS lane's `specific`
   skills. Only concrete installed skills count. Codex uses Codex skill names; Claude uses
   Claude skill names. GitHub suggestions are reviewed informational recommendations and never appear here until installed. The executable kit is one to two `predefined` plus one to two `specific`, at most four unique skills.

## E. Graphify-first (navigation) — MANDATORY, blocking Step 1 when graphify-out/ exists
```
STEP 1 (before ANY Read/Grep): build a map of your subsystem by QUERYING the graph with the helper — do NOT grep to discover where things are. The graph in graphify-out/ is a READ-ONLY symlink to the parent repo's, refreshed by the orchestrator this cycle — do NOT run /graphify-auto or rebuild it (you'd race the other lanes through the shared link):
  python graphify-out/q.py <symbol>           # find nodes -> file:line + community
  python graphify-out/q.py callers <symbol>   # who points AT it
  python graphify-out/q.py uses <symbol>      # what it points to
  python graphify-out/q.py near <symbol>      # both directions
  python graphify-out/q.py file <path-sub>    # nodes defined in a file
Query every key symbol in your OWN file set + the shared-file boundary, print the resulting map, and work from it. Each result gives file:line so you can do a TARGETED Read only when you truly need the source. Treat line numbers as APPROXIMATE (the graph is refreshed per cycle, not per edit) — confirm the exact anchor with a targeted Read/Grep right before an edit; use Grep/Glob ONLY for that confirmation, never to find where code lives.
```
If `graphify-out/q.py` is absent: substitute one read-only Explore agent to map the subsystem before editing.

## F. File ownership
```
YOU OWN (edit only these): <OWN globs>
FORBIDDEN (other lanes own — do not edit/refactor): <FORBIDDEN globs>
HARD CONTRACT: <frozen public APIs>. If you need a change in a file you do not own, use the canonical relay; do NOT edit it.
```

## G. Forced verification (no done without proof)
```
VERIFY with evidence — no claim without it. Write docs/verify-<lane>.md containing: <lane-appropriate evidence>. Never say "done"/"works"/"looks good" without the artifact in that file. <For UI: preview_start + screenshots. For device: build/install/log. For logic: test output.>
TEST-CADENCE: run focused checks while iterating, subsystem checks before DONE, and
leave the expensive full terminal suite for integration/final certification.
DELEGATION: forbidden. This tmux CLI is the sole agent for this lane. Do not spawn
Codex app collaboration agents, subagents, or nested fan-out.
CHECK-CACHE: route every expensive check through
`bin/polylane-check.sh "$PWD/.polylane/check-cache/<lane>" -- <command>`.
Reuse an unchanged PASS or FAIL; a FAIL requires a source/environment change before
the command may execute again.
EXTERNAL-EVIDENCE: physical/manual proof the system cannot produce stays explicitly
external; continue every autonomous task and never turn missing evidence into PASS.
```

## H. Coordination + resource mutex
```
Live cross-worktree coordination uses the runner-provided canonical environment only: `POLYLANE_PROJECT_ROOT` and `POLYLANE_COORDINATION_FILE`. Set `COORD="$POLYLANE_PROJECT_ROOT/bin/polylane-coordinate.sh"`, then use `"$COORD" request "$POLYLANE_COORDINATION_FILE" <from-lane> <to-lane> "<shared-file change>"`, `decision ...`, `claim ... <resource>`, and `release ... <resource>`. A failed claim means another lane owns that resource: do other work, inspect `"$COORD" pending "$POLYLANE_COORDINATION_FILE"`, and retry only after release. The relay is append-only; do not edit it. `docs/parallel-status.md` is a durable post-cycle summary only, never the live channel or done signal.
```

## I. Scoped git
```
Commit often. Stage ONLY your paths (git add <your files>) — NEVER git add -A or git add . (scope every add to your own paths; on a shared tree you'd sweep other lanes' staged work). On index.lock, wait + retry.
```

## J. Done checklist
```
DONE = all true: <per-lane observable criteria> + docs/verify-<lane>.md has proof + docs/status-<lane>.md written with first line EXACTLY `STATUS: <lane> DONE run=<RUN_ID>` (the orchestrator bakes the manifest's literal run_id nonce in place of <RUN_ID>; the runner trusts the marker only when the tag matches THIS run) + no new errors. Drive with the skills; no generic output.
```
Also write a `## DEFERRED` section at the END of docs/verify-<lane>.md: every fork/decision this lane PUNTED, each as `DEFERRED: <what> — <options left open>` (or `DEFERRED: none`). Phase 5's emergent-question harvest greps these — a missing section is a defect; an empty one is fine.

## Integrator lane (append when used)
Compose A/B(top non-Fable available, xhigh — the integrator role clamp in `model-selection.md`)/C/E + a merge-build-install-verify-critic body:
- **Merge into YOUR OWN integrator branch — NEVER the base branch.** You run in your own worktree on your own branch. Merge each lane branch's CURRENT tip INTO THIS branch and verify the combined tree HERE. Do NOT check out or merge into `main`/base — the runner fast-forwards the base to your branch itself, and ONLY on a GO, so a NO-GO can never touch the base. Never trust a prior GO: if commits followed one, re-verify from scratch.
- Read all verify-*.md plus the canonical relay snapshot, build everything together, run cross-lane end-to-end checks WITH evidence, list what's missing/unverified/regressed, write docs/verify-integration.md with GO/NO-GO. Fix only cross-lane regressions, each logged in the relay; write `docs/parallel-status.md` once as the durable post-cycle summary. When only coordinator-owned terminal checks remain, commit the exact handoff `READY-FOR-HOST-GATE run=<RUN_ID>`; do not rerun the full terminal suite in this sandbox.
- **If ponytail is installed, run `/ponytail-review` on the merged diff** — flag any over-engineering a lane introduced (dead abstraction, speculative generality, needless deps). Note findings in verify-integration.md; a lane that grossly over-built against its goal is a quality regression worth a NO-GO. Keeps the token-efficiency mission enforced at the gate, not just per-lane.
- **Independent evidence, never a vibes-only GO.** Use independent verifier lanes
  when the plan includes them; otherwise combine mechanical acceptance, seam checks,
  build/test evidence, and an adversarial review in the integrator. Codex app
  subagents never replace the runner's tmux Codex CLI lanes.
- **Mechanical seam scan (before you decide).** Run `bin/polylane-seams.sh scan <your integrator worktree> >> docs/verify-integration.md` — it greps the merged tree for cross-file name danglers (a DOM id referenced in JS that no HTML produces — the classic "two halves don't wire up" bug). A `SEAM-DANGLING:` line it appends is an AUTO-NO-GO the gate enforces regardless of your prose, so fix the wiring (or reassign the lane) before issuing GO.
- **End docs/verify-integration.md with exactly one verdict sentinel on its OWN line:**
  `POLYLANE-VERDICT: GO run=<RUN_ID>`,
  `POLYLANE-VERDICT: READY-FOR-HOST-GATE run=<RUN_ID>`,
  `POLYLANE-VERDICT: EXTERNAL-EVIDENCE-OPEN run=<RUN_ID>`, or
  `POLYLANE-VERDICT: NO-GO run=<RUN_ID>`. Ready-for-host-gate is valid only when
  frozen coordinator-owned terminal checks remain; the outer runner runs them once
  before converting it to GO. External-open is valid only after engineering is
  verified and remaining proof truly requires a person/physical system. NO-GO is
  repair feedback, not a stopping point. The runner trusts only the current nonce
  and commits the evidence.
- **Skip impossible identical repair waves:** only when the current
  host/account/hardware blocks a required gate before source execution and no
  owned source change can alter it, add
  `POLYLANE-REPAIRABLE: NO run=<RUN_ID>` immediately before the NO-GO sentinel.
  Do not use this for source defects or uncertainty. The outer orchestrator must
  route other autonomous work rather than treating the marker as completion.
- **Batch the human device/voice/visual sign-off here** (diff-aware — only re-verify surfaces changed since last sign-off; note each re-install invalidates prior voice/visual proof).
- **On GO: run merge + cleanup** (references/merge-and-cleanup.md) — verify each branch merged, `git worktree remove` merged worktrees, `git branch -d` merged branches, MOVE strays/duplicates into `<project>-useless/` (never rm, never touch the main tree's uncommitted work or the harness cwd). Leave one project folder. If auto-mode blocks a destructive step, hand the user the exact commands.
- Stage only docs/verify-integration.md + logged glue fixes.
