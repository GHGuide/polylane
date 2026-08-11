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
Do not require Claude slash commands in a Codex prompt. Do not browse, list, or search skill inventories after launch. `graphify` and `graphify-auto` are navigation infrastructure, never selected builder-kit records: do not load either skill body in a lane.
**Lanes do NOT run `/graphify-auto`** — the ORCHESTRATOR refreshes the graph once per
cycle before launch, and the runner symlinks the parent's `graphify-out/` into every
worktree (`share_graph`), so each lane already has the CURRENT graph read-only. A lane
refreshing it would race its siblings through the shared symlink and waste N rebuilds
of the same commit. Lanes only QUERY (block E). **Step 3 `/ponytail full` is included ONLY when the ponytail plugin is installed** (check `ls ~/.claude/skills/ | grep ponytail` or the plugins cache during recon) — it enforces "build the minimum that meets the goal, the best code is the code you never wrote" (~54% less code, ~20% cheaper on real sessions), which is squarely polylane's token mission; omit the line cleanly if absent (skill-scout recommends installing it — see `skill-scout.md`). The caveman LEVEL in step 2 follows the round's intensity — write `(ultra)` when the round is `economy`, `(full)` otherwise (per `model-selection.md`); the step itself is never dropped or reordered. Ponytail level tracks the same: `ultra` under `economy`, `full` otherwise. Fallbacks only if a project genuinely lacks one: caveman → the terse instruction in block C; graphify → the Explore-agent fallback in block E. Never omit the intent. This block is the DOMAIN-AGNOSTIC base for EVERY lane; the per-lane skill scout (references/skill-scout.md) never re-suggests these — it layers only DOMAIN skills into block D on top.

## A. Identity + context
```
ULTIMATE-GOAL: <verbatim durable product goal>
CURRENT-SUBGOAL: <verbatim cycle subgoal>
Project outcome: <profile outcome>. Owned deliverables: <artifact paths and types>. Evidence modes: <profile evidence modes>. External-action policy: <profile policy>.
Project: <PROJECT one-liner>. Read THIS project's CLAUDE.md and memory/MEMORY.md first. IGNORE any unrelated CLAUDE.md from other projects. YOUR LANE = <LANE NAME>. Other lanes run in parallel — do NOT touch their artifacts.
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

## D.2 Visual Intelligence Loop — only for UI lanes
```
This is a UI lane. Carry the literal ULTIMATE-GOAL and CURRENT-SUBGOAL into the
locked visual contract in references/visual-intelligence.md. Invoke and use the
selected installed skills in this platform's native syntax; do not substitute the
other platform's slash-command syntax. The reference packet is evidence: synthesize
3–5 relevant references plus one wildcard, then use the council-selected direction
and locked tokens, layout, motion, and signature. Do not replace it with a generic
aesthetic.

If a required UI skill is genuinely missing, use only the authorized route:
discover → quarantine → audit → isolated benchmark → pinned project install → arm.
Never execute rejected content. On any failure, record why and continue with the
best installed kit.

Capture desktop and mobile plus empty, loading, error, hover, and focus states and
one real flow. Supply independent design, accessibility, and originality lenses;
the council permits at most two targeted repairs. Complete the product-specific
typography/imagery-or-icons-or-illustration and humanized UX copy pass. Reject
emoji-as-product-art, generic stock gradients, meaningless hero text, nested-card
soup, decorative pills, and default-font sameness unless evidence justifies them.
For a visual-champion replacement, preserve external/unavailable evidence honestly
and require >=10 varied prompts, anonymized screenshots, blind decisive comparison,
>=70% creative/polish wins, and no accessibility regression; otherwise retain the
current champion. Write the Visual certification record in verification evidence:
design lock, every capture or external blocker, three verdicts, each targeted repair
and re-review, and the old-vs-new blind tally/accessibility/champion decision. A
missing artifact is external or NO-GO, never a prose-only pass.
```

## D.1 Prime hybrid continuity — only when manifest `prime_hybrid: true`
```
The runner exported POLYLANE_HARNESS_DIR, POLYLANE_WORKERS_DIR,
POLYLANE_WORKER_ID, POLYLANE_WORKER_RUN_ID, and POLYLANE_CONTEXT_PACKET from canonical project state.
Before work, read "$POLYLANE_CONTEXT_PACKET" exactly once. For follow-ups, use the
durable inbox through "$POLYLANE_PROJECT_ROOT/bin/polylane-workers.sh" inbox "$POLYLANE_PROJECT_ROOT" "$POLYLANE_WORKER_ID"; do not invent a worktree-local
memory file or edit the relay.

Local refinements require repeated observed evidence and a declared bounded expected
check through polylane-refine.sh; next-cycle validation either validates or rolls
back the immutable harness snapshot. If the packet contains `refinement-queue.json`,
first run `"$POLYLANE_PROJECT_ROOT/bin/polylane-refine.sh" queue "$POLYLANE_HARNESS_DIR"`.
For each eligible item, then exactly one real `propose` or `decline` invocation through
`"$POLYLANE_PROJECT_ROOT/bin/polylane-refine.sh"`; `propose-or-decline` is NOT a subcommand
(it is only the conceptual decision phrase). Never silently leave an eligible item
unreviewed. A global prompt or skill idea is proposal-only:
stage it for bin/polylane-skill-evolve.sh. Never directly overwrite SKILL.md or an
installed skill.
```

## E. Graphify-first (navigation) — MANDATORY, blocking Step 1 when graphify-out/ exists
```
STEP 1 (before ANY Read/Grep): build a map of your subsystem by QUERYING the graph with the helper — do NOT grep to discover where things are. When `graphify-out/q.py` exists, these direct queries are mandatory; do not load the Graphify skill body. The graph in graphify-out/ is a READ-ONLY symlink to the parent repo's, refreshed by the orchestrator this cycle — do NOT run /graphify-auto or rebuild it (you'd race the other lanes through the shared link):
  python graphify-out/q.py <symbol>           # find nodes -> file:line + community
  python graphify-out/q.py callers <symbol>   # who points AT it
  python graphify-out/q.py uses <symbol>      # what it points to
  python graphify-out/q.py near <symbol>      # both directions
  python graphify-out/q.py file <path-sub>    # nodes defined in a file
Query every key symbol in your OWN file set + the shared-file boundary, print the resulting map, and work from it. Each result gives file:line so you can do a TARGETED Read only when you truly need the source. Treat line numbers as APPROXIMATE (the graph is refreshed per cycle, not per edit) — confirm the exact anchor with a targeted Read/Grep right before an edit; use Grep/Glob ONLY for that confirmation, never to find where code lives.
```
For non-code artifacts, query paths, schemas, and evidence locations rather than only symbols. If `graphify-out/q.py` is absent: do targeted read-only inspection yourself; do not create a discovery lane or delegate exploration.

## F. File ownership
```
YOU OWN (edit only these): <OWN globs>
FORBIDDEN (other lanes own — do not edit/refactor): <FORBIDDEN globs>
HARD CONTRACT: <frozen artifact paths, schemas, formats, APIs, or evidence handoffs>. If you need a change in an artifact you do not own, use the canonical relay; do NOT edit it.
```

## G. Forced verification (no done without proof)
```
VERIFY with evidence — no claim without it. Write docs/verify-<lane>.md containing: <lane-appropriate evidence mode and artifact path>. Never say "done"/"works"/"looks good" without that evidence. Examples: test/build for source, citation audit for a review, sample/quality report for data, backtest for strategy research, tabletop/dry-run for operations, editorial/brand review for content.
TEST-CADENCE: run focused artifact/evidence checks while iterating, lane-level verification before DONE, and leave the expensive full terminal gate for integration/final certification when the profile requires one; only coordinator-owned terminal checks remain.
DELEGATION: forbidden. This tmux CLI is the sole agent for this lane. Do not spawn
Codex app collaboration agents, subagents, or nested fan-out.
CHECK-CACHE: route every expensive check through
`bin/polylane-check.sh "$PWD/.polylane/check-cache/<lane>" -- <command>`.
Reuse an unchanged PASS or FAIL; a FAIL requires a source/environment change before
the command may execute again.
EXTERNAL-EVIDENCE: physical/manual proof and every consequential external action stay explicitly external; continue every autonomous task and never turn missing evidence into PASS. You may validate simulations, samples, dry runs, backtests, and prepared artifacts. Do not execute live trades, spend money, publish, deploy production, contact third parties, or claim physical/manual outcomes without explicit authority and evidence.
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
DONE = all true: <per-lane observable criteria> + docs/verify-<lane>.md has proof + no new errors. The status marker is written only by the finalization transaction below. Drive with the skills; no generic output.
```
Also write a `## DEFERRED` section at the END of docs/verify-<lane>.md: every fork/decision this lane PUNTED, each as `DEFERRED: <what> — <options left open>` (or `DEFERRED: none`). Phase 5's emergent-question harvest greps these — a missing section is a defect; an empty one is fine.

## K. Runtime finalization — compiled builder prompt
```
POLYLANE-RUNTIME-FINALIZE: immediately before completion, run the final relay and durable inbox read; handle all addressed autonomous work; run focused verification; scope-stage every owned changed or new file with `git add <your files>`; commit implementation and evidence; verify `git status --short` contains only runner-owned `.polylane-prompt.txt` and `graphify-out`; only then write the current-run status file, force-add the ignored status file with `git add -f`, commit that final handoff, and immediately exit. No reads, tests, edits, relay decisions, or commits may follow the marker/verdict commit.
```
The final relay command is `COORD="$POLYLANE_PROJECT_ROOT/bin/polylane-coordinate.sh"; "$COORD" pending "$POLYLANE_COORDINATION_FILE"`; the final inbox command is `"$POLYLANE_PROJECT_ROOT/bin/polylane-workers.sh" inbox "$POLYLANE_PROJECT_ROOT" "$POLYLANE_WORKER_ID"`. `docs/parallel-status.md` remains post-cycle evidence, never the live relay. Builders create only `docs/status-<lane>.md`. Integrators: only then write the only current-run POLYLANE-VERDICT sentinel as the final line of docs/verify-integration.md; write `docs/status-<lane>.md` with only its DONE marker and no verdict. Keep the marker nonce, exact first line, clean-tree, exact-HEAD, and host-gate ownership language intact.

Builder final handoff: after the scoped implementation/evidence commit and clean-status check, write only its current-run `docs/status-<lane>.md`, force-add it if ignored, commit it, and exit immediately. Integrator final handoff: write the only current-run verdict sentinel as the final line of `docs/verify-integration.md`; write `docs/status-<lane>.md` with only its DONE marker and no verdict, force-add both handoff files if ignored, commit them, and exit immediately. Neither role may perform repository work after that final commit.

## Integrator lane (append when used)
Compose A/B(top non-Fable available, xhigh — the integrator role clamp in `model-selection.md`)/C/E + a merge-build-install-verify-critic body:
- **Merge into YOUR OWN integrator branch — NEVER the base branch.** You run in your own worktree on your own branch. Merge each lane branch's CURRENT tip INTO THIS branch and verify the combined tree HERE. Do NOT check out or merge into `main`/base — the runner fast-forwards the base to your branch itself, and ONLY on a GO, so a NO-GO can never touch the base. Never trust a prior GO: if commits followed one, re-verify from scratch.
- Read all verify-*.md plus the canonical relay snapshot, and, for a prime-hybrid run, the bounded integrator packet and eligible refinement evidence. Combine current artifact tips, run cross-lane focused evidence checks, list what is missing/unverified/regressed, write docs/verify-integration.md with GO/NO-GO. Fix only cross-lane seams, each logged in the relay; write `docs/parallel-status.md` once as the durable post-cycle summary. Use `READY-FOR-HOST-GATE run=<RUN_ID>` only when this target has terminal-tier acceptance and no open/doing autonomous work remains outside it; otherwise a focused recovery emits GO. Do not rerun the full terminal suite or reinterpret launch/restart counters in this sandbox: runner-owned eligibility decides whether a real terminal boundary starts.
- The integrator's committed `STATUS: <lane> DONE run=<RUN_ID>` means its local branch and evidence are complete; it is not a host-GO claim. It may accompany `READY-FOR-HOST-GATE` before the coordinator runs terminal checks. Never defer this local completion marker until host GO.
- **If ponytail is installed, run `/ponytail-review` on the merged diff** — flag any over-engineering a lane introduced (dead abstraction, speculative generality, needless deps). Note findings in verify-integration.md; a lane that grossly over-built against its goal is a quality regression worth a NO-GO. Keeps the token-efficiency mission enforced at the gate, not just per-lane.
- **Independent evidence, never a vibes-only GO.** Use independent verifier lanes
  when the plan includes them; otherwise combine mechanical acceptance, artifact
  checks, declared evidence modes, and an adversarial review in the integrator. Codex app
  subagents never replace the runner's tmux Codex CLI lanes.
- **Mechanical seam scan (before you decide).** Run `bin/polylane-seams.sh scan <your integrator worktree> >> docs/verify-integration.md` when source seams apply; also check every declared artifact handoff, schema, version, and evidence location. A dangling seam or missing required evidence is AUTO-NO-GO; live external action is never a substitute for evidence.
- **End docs/verify-integration.md with exactly one verdict sentinel on its OWN line:**
  `POLYLANE-VERDICT: GO run=<RUN_ID>`,
  `POLYLANE-VERDICT: READY-FOR-HOST-GATE run=<RUN_ID>`,
  `POLYLANE-VERDICT: EXTERNAL-EVIDENCE-OPEN run=<RUN_ID>`, or
  `POLYLANE-VERDICT: NO-GO run=<RUN_ID>`. Ready-for-host-gate is valid only when
  this target owns frozen terminal-tier acceptance and no open/doing autonomous
  work remains outside it; the outer runner runs that boundary once
  before converting it to GO. External-open is valid only after engineering is
  verified and remaining proof truly requires a person/physical system. NO-GO is
  repair feedback, not a stopping point. The runner trusts only the current nonce
  and commits the evidence.
- **Skip impossible identical repair waves:** only when the current
  host/account/hardware blocks a required gate before artifact verification and no
  owned artifact change can alter it, add
  `POLYLANE-REPAIRABLE: NO run=<RUN_ID>` immediately before the NO-GO sentinel.
  Do not use this for source defects or uncertainty. The outer orchestrator must
  route other autonomous work rather than treating the marker as completion.
- **Batch the human device/voice/visual sign-off here** (diff-aware — only re-verify surfaces changed since last sign-off; note each re-install invalidates prior voice/visual proof).
- **On GO: run merge + cleanup** (references/merge-and-cleanup.md) — verify each branch merged, `git worktree remove` merged worktrees, `git branch -d` merged branches, MOVE strays/duplicates into `<project>-useless/` (never rm, never touch the main tree's uncommitted work or the harness cwd). Leave one project folder. If auto-mode blocks a destructive step, hand the user the exact commands.
- Stage only docs/verify-integration.md + logged glue fixes.
