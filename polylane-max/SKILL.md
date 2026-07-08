---
name: polylane-max
description: Use when the user gives an ULTIMATE GOAL — or even just a VAGUE one-line app/product idea they want fully strategized and built for them — and wants polylane to drive it autonomously. It opens with a product-discovery interview (numerous easy recommended-default questions + research) that turns a fuzzy idea into a locked strategy + goal tree, then loops build → ~50-bullet report → deep-research → critic → questions → continue, until the goal is met or the user stops. Triggers on "/polylane-max", "polylane max", "build my app idea", "I have an idea, build it all", "strategize and build", "drive to the goal", "keep building toward", "autonomous build loop", "turn my idea into an app".
---

# /polylane-max — goal-driven autonomous build loop

`/polylane-auto` runs ONE build end to end. **`/polylane-max` runs MANY** — an
outer loop that keeps building toward a single ULTIMATE GOAL, cycle after cycle,
reporting and researching between each, until a critic judges the goal reached or
the user stops.

**Each cycle:** build (polylane-auto) → merge → **~50-bullet report of what it made**
→ **deep-research the next steps toward the goal** → **critic scores progress** →
**batch of recommended-default questions** → synthesize the next cycle's spec →
build again. It does not stop for you between cycles — recommended defaults carry it
forward; your answers only steer.

## Locked behaviors (this mode's contract)
- **Termination:** loop until the critic judges the ULTIMATE GOAL met (or blocked),
  or the user says stop. No fixed cycle count.
- **Questions:** every question ships a pre-picked recommended answer. Ask, but if
  the user doesn't weigh in, take the recommended path and start the next cycle —
  it "pops questions AND keeps working."
- **Research depth:** full `deep-research` skill each cycle (this is MAX mode;
  favor thoroughness over token thrift) — but scoped to NEW ground: each cycle reads
  prior `cycle-*-research.md` and never re-runs coverage already done.
- **Report:** ~50 concrete bullets of what the cycle made, in the chat, immediately
  after merge — before research.
- **Thorough, not redundant — gates before spend:** a cheap check always precedes an
  expensive fan-out. Never launch a full wave a 1-agent gate would reject; never fan
  out speculative/discovery lanes; never re-cover researched ground; run the critic
  once per cycle. MAX spends its thoroughness on NEW ground, not repetition.
- **Action over artifacts:** when a converting action is within reach (one run, one
  API key, small $), it becomes the cycle's PRIMARY deliverable — surfaced at the top
  of the report and preferred over another planning cycle. Planning serves the next
  action, not the archive.
- **Context-bounded (never blow the window):** the loop's memory lives ON DISK
  (`max-state.json` + digests + research), NOT in conversation. Start every cycle by
  reading the compact brief (`polylane-memory.sh <state> brief`, ~a few hundred bytes)
  + only the files that cycle needs. NEVER rely on remembering earlier cycles from the
  transcript — re-read the brief/tree/digests. If context is getting long, that is
  fine: dump anything new to disk and keep going from the brief. This is what lets the
  loop run many cycles without dying on the context window.
- **Budgeted (never unbounded spend):** honor a hard cycle cap and a token budget.
  `POLYLANE_MAX_CYCLES` (default 8) caps total cycles; `POLYLANE_BUDGET` (optional,
  tokens or $) caps cumulative cost. Default each cycle's build to the CHEAPEST models
  that clear the viability gate (`--intensity economy`; only bump a lane when a
  sub-goal genuinely needs it). Track cumulative cost in `progress.md` from each run's
  report; if the cap or budget is hit, STOP with the wrap-up instead of another cycle.

## Phase 00 — Discovery & Strategy (when the idea is vague — the flagship path)
If the user handed you a crisp goal + criteria, skip to Phase 0. If they gave a
BRIEF, fuzzy idea ("an app that helps me X") and want it strategized + built for
them, run discovery FIRST — follow `references/discovery.md`:
- **Strategize like a product partner, extract through easy questions.** Batched
  AskUserQuestion rounds (2–4 at a time, "numerous") across the discovery dimensions
  (problem · audience · the one thing · MVP features · platform · look & feel ·
  accounts/data · integrations · business model · constraints · ambition · done).
  Every option is concrete with a recommended default first — one click answers, no
  answer takes the default. **Every question also carries a final "🔍 Go deeper — ask
  me more about this next round" option**; picking it opens a finer drill-down round
  on that dimension (unbounded depth), so the user can explore any topic as far as
  they want before committing. Re-present the growing strategy after each round.
- **Research the gaps.** Use `deep-research` to propose the feature set, stack, design
  references, and competitor norms, so the user chooses from informed options rather
  than inventing them. Name the riskiest assumption.
- **Flag NEEDS FROM YOU early** — anything the system can't do alone (API key, app-
  store account, domain, payment processor, a real product call) goes in the strategy
  so the final GO isn't a surprise.
- **Lock the PRODUCT STRATEGY** (save `docs/polylane-max/STRATEGY.md`): one-liner ·
  problem/audience/the-one-thing · MVP scope (deferred marked) · platform+stack ·
  look & feel · integrations · business model · NEEDS FROM YOU · success criteria ·
  riskiest assumption. Confirm once (recommended = "yes, build this"); edits loop.
Then hand the locked strategy to Phase 0 — its success criteria become the tree's
`criteria` and its MVP scope becomes the milestones → sub-goals.

## Phase 0 — lock the ultimate goal + build the goal tree (once)
Capture the ULTIMATE GOAL — from the user's prompt, or synthesized from the Phase 00
strategy — in one crisp paragraph + 3–5 measurable success criteria. Confirm it once (single AskUserQuestion, recommended
= "yes, this is the goal"). Persist it, then **decompose it into an HTN goal tree +
open a shared blackboard** — a structured state file that turns "score progress by
vibes" into "score against a real tree", and stops the loop from ever repeating a
failed approach or re-litigating a settled decision:
```
mkdir -p .polylane docs/polylane-max
cat > .polylane/ULTIMATE_GOAL.md   # the goal paragraph + success criteria
MEM="$(dirname "$(command -v polylane-run.sh || echo "$HOME/.claude/skills/polylane/bin/x")")/polylane-memory.sh"
STATE=.polylane/max-state.json
"$MEM" "$STATE" init "<ultimate goal, one line>"
# success criteria -> the tree's measures:
"$MEM" "$STATE" add-criterion c1 "<criterion>" <weight>   # repeat per criterion
# decompose the goal into milestones -> sub-goals (weight = leverage toward the goal):
"$MEM" "$STATE" add-milestone m1 "<milestone>"
"$MEM" "$STATE" add-subgoal   m1 m1.1 "<sub-goal>" <weight>   # repeat
```
Record the loop baseline: `git rev-parse HEAD` → this is `cycle-1` baseline. From
here every phase reads/writes `$STATE` (the blackboard + tree).

## Phase 1 — build a cycle (polylane-auto, no re-interview after cycle 1)
**Start every cycle from the compact brief + a budget check — not from memory:**
```
"$MEM" "$STATE" brief          # the few-hundred-byte resume state: goal, progress, NEXT, blocked
# STOP the loop instead of building another cycle if either cap is hit:
#   cycle count >= POLYLANE_MAX_CYCLES (default 8), or cumulative cost >= POLYLANE_BUDGET.
```
Read the brief (and only the specific digests/research the cycle needs) — do NOT
rely on the transcript for earlier cycles. Then run the full polylane-auto pipeline
for THIS cycle's spec, defaulting to the cheapest models that clear the viability
gate (`--intensity economy`, bump only a sub-goal that needs it):
- **Cycle 1:** derive the first concrete spec from the ultimate goal (a short
  deep-research pass to scope it), present it at the plan gate, then build.
- **Cycle N>1:** the spec is already synthesized from the prior cycle (Phase 5) —
  skip the interview, go straight to recon → lanes → plan gate → hands-off run.

**Gate 1a — cheap checks BEFORE the wave (skip spend that won't pay):**
- **Viability pre-gate:** one cheap agent (Haiku/Sonnet, single call) scores the
  synthesized spec against the goal — `advance` or `hold <why>` — from the goal +
  prior digests + research. `hold` → do NOT launch the wave; return to Phase 5 with
  the reason and re-synthesize. Turns an "N-lane run the critic later scores 'do not
  advance'" into one agent's cost.
- **No discovery/speculative lanes:** every lane maps to concrete files (`own_globs`);
  exploration stays in single-agent recon, never a parallel lane. Derive the FEWEST
  lanes real file-overlap allows — never fan out for coverage's sake.
- **Design-lock:** if the cycle produces UI/mockups, lock the design spec first (one
  brainstorm → lock), then generate; cap at ≤1 revision — no repeated mockup rounds.

Launch with the walk-away runner so a cycle never blocks:
```
RUNNER="$(command -v polylane-run.sh 2>/dev/null || echo "$HOME/.claude/skills/polylane/bin/polylane-run.sh")"
POLYLANE_SESSION="polylane-max-c<N>" "$RUNNER" .polylane/run.json --yes
```
Wait for the run to finish (its report at `docs/polylane-report.md`, verdict GO/NO-GO).

## Phase 2 — the ~50-bullet report (immediately, in chat)
As soon as the cycle merges, gather the raw inventory and turn it into ~50 concrete
bullets of WHAT THIS CYCLE MADE — features, files, fixes, tests, docs, each one
specific ("added X", "fixed Y", not "improved things"):
```
DIGEST="$(dirname "$RUNNER")/polylane-digest.sh"
"$DIGEST" <this-cycle-baseline>          # commits + diffstat + new files + verify summaries
```
Condense that inventory into ~40–60 bullets, grouped by area, and post them in the
chat. Also save to `docs/polylane-max/cycle-<N>-digest.md`. This is a hard
deliverable every cycle — the user sees exactly what got built.

**Lead with the converting action.** If one action would realize the value of what's
built (ship it, run the real thing, the one paid run behind an API key), put it at the
TOP of the digest as "DO THIS TO CONVERT" — not buried under more planning. Prefer
shipping that action over spending the next cycle on more artifacts.

## Phase 3 — deep-research the next steps toward the goal
First load prior `docs/polylane-max/cycle-*-research.md` and list the ground already
covered (competitors, markets, options already evaluated). Scope this cycle's research
to EXCLUDE it — research only NEW leverage points. Thorough on new ground, never a re-run.

Invoke the `deep-research` skill scoped to: *"We are building toward <ULTIMATE
GOAL>. So far we have built <cycle digests>. What are the highest-leverage next
steps, the biggest risks/gaps, and the strongest options to move forward?"* Produce
a ranked suggestion set (each: what, why it advances the goal, rough effort).
Save to `docs/polylane-max/cycle-<N>-research.md`.

Before building each cycle (in Phase 1) pick the target from the tree, not from
scratch: `"$MEM" "$STATE" next` prints the highest-leverage OPEN sub-goal — that
sub-goal is the cycle's focus. And `"$MEM" "$STATE" attempted "<approach>"` tells
you whether an approach already failed, so the loop never repeats it. Record what
this cycle tried + learned + decided:
```
"$MEM" "$STATE" log <N> attempt  "<approach taken>"   "<outcome>"
"$MEM" "$STATE" log <N> learning "<insight from a lane reflection / verify file>"
"$MEM" "$STATE" log <N> decision "<what was chosen>"  "<why>"
```

## Phase 4 — critic gate (goal met?) — scored against the tree
Update the goal tree from this cycle's digest, then score against it — not vibes.
Mark each sub-goal the cycle satisfied `done` (with evidence), and set each
criterion's status:
```
"$MEM" "$STATE" set-status <subgoal-id> done "<evidence: commit / test / file>" <N>
"$MEM" "$STATE" set-status <criterion-id> done|open
"$MEM" "$STATE" progress            # X/Y sub-goals · A/B criteria · %
"$MEM" "$STATE" dump >> docs/polylane-max/progress.md
```
**Ensemble critic — not a single lenient judge (LLMs skew optimistic on "done").**
Score the goal with an ODD panel (≥3) of INDEPENDENT critics, each judging "goal
met?" against the tree's criteria + sub-goals from the digests/evidence, and at
least ONE adversarial (told to prove it is NOT done — find the criterion with weak
or missing evidence, the sub-goal marked done without proof). A sub-goal/criterion
counts as `done` only on the MAJORITY vote; a tie or an unrebutted "not done" keeps
it open. This runs ONCE per cycle (the panel votes together, not a repeated
council). Then reconcile the tree from the vote and check termination — no vibes:
- `"$MEM" "$STATE" met` exits 0 (every criterion AND sub-goal done, per the panel)
  → write the final wrap-up (tree dump + all cycle digests + what's left), STOP.
- Otherwise → continue to Phase 5. (A blocked-and-unblockable sub-goal → mark it
  `blocked`, surface it, and either stop or route around it.)

## Phase 5 — batch questions + synthesize the next spec (auto-continue)
From the research suggestions + critic gaps + the tree's next open sub-goal, form
the next cycle's direction:
- Ask a batch of questions via AskUserQuestion (multiple rounds of ≤4 if needed —
  "numerous"). **Every question's FIRST option is the recommended next step**, so a
  single click (or no answer) advances the loop. **Every question also carries a final
  "🔍 Go deeper — more questions on this next round" option** (same drill-down
  mechanics as discovery — `references/discovery.md`), so the user can steer any
  decision to arbitrary depth. Questions steer scope/priority/tradeoffs — they never
  block the loop from continuing on defaults.
- Synthesize the chosen (or recommended) answers + top research suggestions +
  `"$MEM" "$STATE" next` into the next cycle's numbered INTEGRATION SPEC (each item
  one line + a testable outcome), exactly as `/polylane` Phase 1 produces. Skip any
  approach `attempted` already flagged as failed.
- Record the decision in the blackboard (`log <N> decision ...`), set the new
  baseline (`git rev-parse HEAD`), increment N, and GOTO Phase 1.

## Artifacts (persist across cycles)
- `.polylane/ULTIMATE_GOAL.md` — the north star (never deleted by cleanup).
- `.polylane/max-state.json` — the HTN goal tree + blackboard (criteria, sub-goals,
  decisions, learnings, attempts). The loop's memory across cycles.
- `docs/polylane-max/cycle-<N>-digest.md` — the ~50 bullets per cycle.
- `docs/polylane-max/cycle-<N>-research.md` — deep-research + ranked suggestions.
- `docs/polylane-max/progress.md` — critic scores + tree dumps across cycles.

## Requirements
Everything `/polylane-auto` needs (tmux, jq, claude, the polylane skill), plus the
`deep-research` skill for Phase 3. Each cycle uses the walk-away runner, so usage-
limit stalls and dead panes self-recover (`POLYLANE_ON_LIMIT`, default fallback) —
a cycle never hangs waiting for a human.

## Install
```
cp -r polylane-max/ ~/.claude/skills/polylane-max/
```
Then `/polylane-max <your ultimate goal>` (or "keep building toward <goal>").
