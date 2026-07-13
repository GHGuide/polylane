---
name: polylane
description: Use when the user gives a goal — or even just a VAGUE one-line app/product idea — and wants it strategized and BUILT for them by parallel Claude Code (or GPT/aider) terminals, autonomously. polylane opens with a product-discovery interview (numerous easy recommended-default questions + research) that turns a fuzzy idea into a locked strategy + goal tree, then loops: derive file-isolated lanes → build them in parallel → merge on GO → ~50-bullet report → deep-research → critic → questions → continue, until a critic judges the goal met or the user stops. Triggers on "/polylane", "/lanes", "polylane", "build my app idea", "I have an idea build it all", "strategize and build", "split this into prompts", "parallel terminals", "drive to the goal", "keep building toward", "autonomous build loop", "turn my idea into an app", "run the lanes", "plan and run".
---

# /polylane — autonomous product build loop

**One command. Describe what you want; polylane strategizes it, derives the optimal
parallel lanes, builds them, merges, reports, researches, and keeps going** — cycle
after cycle toward a single ULTIMATE GOAL, until a critic judges it reached or you stop.

Each cycle **builds** (the parallel-lane pipeline in `references/planning.md`: recon →
derive file-isolated lanes → generate prompts → run in tmux → merge on GO) then
**reflects**: ~50-bullet report → deep-research → critic → questions → next spec.

**Each cycle:** build → merge → **~50-bullet report of what it made**
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
- **Research depth:** full `deep-research` skill each cycle (favor thoroughness over
  token thrift) — but scoped to NEW ground: each cycle reads prior
  `cycle-*-research.md` and never re-runs coverage already done.
- **Report:** ~50 concrete bullets of what the cycle made, in the chat, immediately
  after merge — before research.
- **Thorough, not redundant — gates before spend:** a cheap check always precedes an
  expensive fan-out. Never launch a full wave a 1-agent gate would reject; never fan
  out speculative/discovery lanes; never re-cover researched ground; run the critic
  once per cycle. Spend thoroughness on NEW ground, not repetition.
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
- **Resumable across conversations:** the state file is the source of truth, so a
  dead/compacted conversation is not a lost run. See "Resume" below — on entry, if a
  `max-state.json` already exists, offer to continue from it instead of re-interviewing.

## Claude memory — recall + persist learnings ACROSS runs (do at entry + after decisions)
`max-state.json` is per-run; Claude Code's memory persists across every run and
project. `bin/polylane-claudemem.sh` bridges them so polylane gets smarter each run.
Resolve the dir once (project auto-memory, else global):
```
CLM="$(dirname "$MEM")/polylane-claudemem.sh"
MEMDIR="${CLAUDE_MEMORY_DIR:-$HOME/.claude/projects/$(pwd | sed 's#/#-#g')/memory}"
```
- **On entry (before discovery), RECALL:** `"$CLM" "$MEMDIR" relevant "<project name + goal + stack>"`
  and read what comes back — a past run may already know this project's real build/test
  command, a carving rule that bit, a recurring gotcha. Fold it into the strategy so you
  don't relearn it the hard way.
- **Inject into EVERY lane prompt:** put the matching facts in a short "Known project
  facts (from prior runs)" block in each generated lane prompt — so all builders start
  with the hard-won knowledge, not just the orchestrator.
- **After a big decision, a NO-GO, or run end, PERSIST** the DURABLE, cross-run-useful,
  non-secret learnings (not run-specific noise):
  `"$CLM" "$MEMDIR" add <slug> "<one-line>" "<body>" <project|reference|feedback>`
  e.g. the project's real test invocation, a lane-carving rule that caused a NO-GO, a
  constraint discovered mid-build. The helper refuses anything that looks like a secret.
  Keep it to 1–3 facts per cycle — memory is signal, not a log.

## Resume — continue a loop from disk (FIRST thing on entry)
Before Phase 00, check for an existing run:
```
STATE=docs/polylane/max-state.json
# legacy runs stored state under docs/polylane-max/ — adopt it if present
[ ! -f "$STATE" ] && [ -f docs/polylane-max/max-state.json ] && STATE=docs/polylane-max/max-state.json
test -f "$STATE" && "$MEM" "$STATE" resume
```
- **If it prints a RESUME packet:** a prior loop exists. Show its GOAL + CYCLE +
  progress and ask once (recommended = "yes, continue"): resume, or start fresh?
  On resume, **skip discovery entirely** — the packet IS the context. Jump straight
  to the build phase for the next open sub-goal at `CYCLE+1`. This is how a run that
  died mid-loop (context blown, crash, closed terminal) picks up with zero re-work.
- **If there is no state file:** brand-new run → start at Phase 00 (Discovery).
The `resume` packet is self-contained (goal, cycle, every open sub-goal/criterion,
blocked items, recent decisions, next action) — you need nothing from the old
transcript to continue correctly.
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
  AskUserQuestion rounds (2–4 at a time, "numerous") across the discovery dimensions —
  the SPEC set (problem · audience · the one thing · MVP features · platform · look &
  feel · accounts/data · integrations · business model · constraints · ambition · done)
  AND the CREATIVE set (north-star/10× · differentiation · signature moment · anti-goals
  · personality/tone · wildcard feature · constraint-as-fuel). Every option is concrete
  with a recommended default first — one click answers, no answer takes the default.
- **Every question carries TWO escape hatches**, always:
  - **"🔍 Go deeper — ask me more about this next round"** → opens a finer drill-down
    round on that dimension (unbounded depth).
  - **"✨ Surprise me / go bold"** → commits to an ambitious, non-obvious choice you
    name (a wildcard feature, a striking visual direction, a contrarian scope cut).
  So the user can always go deeper OR bolder on anything; both are opt-in, never forced.
  When they keep taking deeper/bold options, lean further in — match their appetite.
- **Adaptive follow-ups, not a fixed checklist.** The dimension list is raw material.
  After each round, pick follow-ups by the follow-up engine (`references/discovery.md`):
  chase the biggest UNKNOWN not the next list item; branch on the answer (a "social"
  pick unlocks different follow-ups than "solo tool"); reflect back every ~3 answers
  ("so: X for Y who care about Z — right?") to catch drift cheaply; ask WHY on pivotal
  choices; surface contradictions instead of averaging them; and CONVERGE — stop asking
  once answers stop changing the strategy. Generate the bold/creative options with the
  provocation toolkit (analogy transplant · inversion · forced constraint · extremes ·
  magic wand), never generic "make it pop".
- **Concept bake-off (do it early — the biggest creativity lever).** Right after the
  first spec round, use `superpowers:brainstorming` + `deep-research` to generate 2–3
  genuinely DISTINCT product concepts from the brief (real forks, not tweaks — each
  named, with a one-line pitch, its signature moment, its trade-off). Present them side
  by side; the user picks one, merges two, or rejects all (also gold). The winner seeds
  the strategy; graft the best of the rest. `references/discovery.md` has the full play.
- **Research the gaps AND surface the non-obvious.** Use `deep-research` to propose the
  feature set, stack, design references, and competitor norms — and to surface wildcard
  capabilities the user never mentioned, so they choose from informed + surprising
  options, not just what they already knew. Name the riskiest assumption.
- **Sharpen before locking — kill the generic.** Run an adversarial distinctiveness
  gate (2–3 critics attacking blandness: "where's the WEDGE?", "the signature moment is
  weak", "what's the boldest buildable version?"). Fold the upgrades in and present the
  safe vs sharpened strategy as a final choice (recommended = sharpened). This is what
  makes the output *better*, not just *more* — see `references/discovery.md`.
- **Flag NEEDS FROM YOU early** — anything the system can't do alone (API key, app-
  store account, domain, payment processor, a real product call) goes in the strategy
  so the final GO isn't a surprise.
- **Lock the PRODUCT STRATEGY** (save `docs/polylane/STRATEGY.md`): one-liner ·
  problem/audience/the-one-thing · MVP scope (deferred marked) · platform+stack ·
  look & feel · integrations · business model · NEEDS FROM YOU · success criteria ·
  riskiest assumption. Confirm once (recommended = "yes, build this"); edits loop.
- **Write the NORTH-STAR + first decision records.** On lock, write the anchor doc
  `docs/polylane/NORTHSTAR.md` — a SHORT, punchy statement of the vision, the one
  thing, the wedge, the signature moment, the personality, and the anti-goals. This is
  the doc every cycle and every lane re-reads to stay true. Then record each BIG call
  from discovery as a decision record (see "North-star docs" below): the chosen concept,
  the stack, any pivotal trade-off or scope cut. These persist and are re-read — the
  loop never silently contradicts a settled call.
Then hand the locked strategy to Phase 0 — its success criteria become the tree's
`criteria` and its MVP scope becomes the milestones → sub-goals.

## Phase 0 — lock the ultimate goal + build the goal tree (once)
Capture the ULTIMATE GOAL — from the user's prompt, or synthesized from the Phase 00
strategy — in one crisp paragraph + 3–5 measurable success criteria. Confirm it once (single AskUserQuestion, recommended
= "yes, this is the goal"). Persist it, then **decompose it into an HTN goal tree +
open a shared blackboard** — a structured state file that turns "score progress by
vibes" into "score against a real tree", and stops the loop from ever repeating a
failed approach or re-litigating a settled decision:
**The loop's state lives in `docs/polylane/`, NEVER in `.polylane/`.** `.polylane/`
is the RUNNER's per-cycle scratch — it is wiped on every cycle's cleanup, so a
`max-state.json` placed there is destroyed after cycle 1 (found by a real run). Keep
all cross-cycle memory under `docs/polylane/`, which cleanup preserves.
```
mkdir -p docs/polylane
cat > docs/polylane/ULTIMATE_GOAL.md   # the goal paragraph + success criteria
MEM="$(dirname "$(command -v polylane-run.sh || echo "$HOME/.claude/skills/polylane/bin/x")")/polylane-memory.sh"
STATE=docs/polylane/max-state.json     # durable — survives the runner's cleanup
"$MEM" "$STATE" init "<ultimate goal, one line>"
# success criteria -> the tree's measures:
"$MEM" "$STATE" add-criterion c1 "<criterion>" <weight>   # repeat per criterion
# decompose the goal into milestones -> sub-goals (weight = leverage toward the goal):
"$MEM" "$STATE" add-milestone m1 "<milestone>"
"$MEM" "$STATE" add-subgoal   m1 m1.1 "<sub-goal>" <weight>   # repeat
```
Record the loop baseline: `git rev-parse HEAD` → this is `cycle-1` baseline. From
here every phase reads/writes `$STATE` (the blackboard + tree).

## Phase 1 — build a cycle (the parallel-lane pipeline, no re-interview after cycle 1)
**Start every cycle from the compact brief + the north-star + a budget check — not
from memory:**
```
"$MEM" "$STATE" brief                       # goal, progress, NEXT, blocked (a few hundred bytes)
cat docs/polylane/NORTHSTAR.md          # the anchor — stay true to the vision
"$DEC" docs/polylane/decisions context  # the settled decisions — never contradict them
# STOP the loop instead of building another cycle if either cap is hit:
#   cycle count >= POLYLANE_MAX_CYCLES (default 8), or cumulative cost >= POLYLANE_BUDGET.
```
(`DEC="$(dirname "$MEM")/polylane-decision.sh"`.) Read the brief + north-star +
settled decisions (and only the specific digests/research the cycle needs) — do NOT
rely on the transcript for earlier cycles. **Inject the north-star one-liner + the
settled-decisions digest into every lane prompt** (a short "NORTH-STAR — stay true;
SETTLED — do not contradict" block), so parallel builders never drift from the vision
or re-open a closed call. Then run the **parallel-lane build pipeline
(`references/planning.md`)** for THIS cycle's spec — recon → derive the FEWEST
file-isolated lanes real overlap allows → tune model/effort per lane → generate the
paste-ready prompts → emit `.polylane/run.json` → launch (below) → merge on GO —
defaulting to the cheapest models that clear the viability gate (`--intensity
economy`, bump only a sub-goal that needs it):
- **Cycle 1:** derive the first concrete spec from the ultimate goal (a short
  deep-research pass to scope it), present it at the plan gate, then build.
- **Cycle N>1:** the spec is already synthesized from the prior cycle (Phase 5) —
  skip the interview, go straight to recon → lanes → plan gate → hands-off run.

**Gate 1b — skill scout (EVERY cycle, before launch — `references/skill-scout.md`):**
Derive the cycle's concrete activities from its lanes, then check: already-installed
skills → curated known-good list → GitHub search (`gh search repos "claude code
skill <activity>" --sort stars`) for unmatched gaps only. Propose ≤3 as ONE
recommended-default AskUserQuestion — each with a one-line WHY tied to THIS cycle
("`xcode-build` — this cycle installs to a device; removes the #1 lane failure").
Auto-continue on defaults; if no skill maps to a real gap, say so and skip the
question. Install accepted skills to `~/.claude/skills/`, bake each trigger into
ONLY the lane that has the gap, and record in `docs/polylane/skills-ledger.md`.
The critic later scores each installed skill (used/helped/hurt) — unused 2 cycles →
suggest removal; the scout reads the ledger first and never re-suggests removed ones.

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

Launch through the SUPERVISOR, never the bare runner (real 5,000+-message runs showed
the dominant failure = the long-lived runner dying mid-run, stranding lanes on
approvals for hours). The supervisor makes runner death a non-event: it relaunches
with `--resume` (DONE lanes skipped), drains safe approval prompts itself (so a dead
runner no longer blocks lanes), parks+notifies critical ones, and writes a heartbeat:
```
BIN="$(dirname "$(command -v polylane-run.sh || echo "$HOME/.claude/skills/polylane/bin/x")")"
POLYLANE_SESSION="polylane-c<N>" "$BIN/polylane-supervisor.sh" .polylane/run.json
```
Print the tmux watch commands in chat (`tmux attach -t polylane-c<N>`), then wait
for the finish notification. **Read run state through the state surface, never by
hand-capturing panes + git + files** (that reconstruction was ~80% of orchestrator
turns in real runs):
```
"$BIN/polylane-state.sh" .polylane/run.json          # or --json
```
One line per lane: `done | likely-done(verify me) | awaiting-approval(CRITICAL) |
stalled | errored | working | no-pane` + branch HEAD + commits ahead + runner/verdict/
report/heartbeat. `likely-done` = commits exist but no done-signal → verify + recover
immediately instead of waiting. `awaiting-approval(CRITICAL)` → relay to the user with
your recommendation, send the chosen keystroke to that pane, continue.

## Phase 2 — the ~50-bullet report (immediately, in chat)
As soon as the cycle merges, gather the raw inventory and turn it into ~50 concrete
bullets of WHAT THIS CYCLE MADE — features, files, fixes, tests, docs, each one
specific ("added X", "fixed Y", not "improved things"):
```
DIGEST="$(dirname "$RUNNER")/polylane-digest.sh"
"$DIGEST" <this-cycle-baseline>          # commits + diffstat + new files + verify summaries
```
Condense that inventory into ~40–60 bullets, grouped by area, and post them in the
chat. Also save to `docs/polylane/cycle-<N>-digest.md`. This is a hard
deliverable every cycle — the user sees exactly what got built.

**Lead with the converting action.** If one action would realize the value of what's
built (ship it, run the real thing, the one paid run behind an API key), put it at the
TOP of the digest as "DO THIS TO CONVERT" — not buried under more planning. Prefer
shipping that action over spending the next cycle on more artifacts.

## Phase 3 — deep-research the next steps toward the goal
First load prior `docs/polylane/cycle-*-research.md` and list the ground already
covered (competitors, markets, options already evaluated). Scope this cycle's research
to EXCLUDE it — research only NEW leverage points. Thorough on new ground, never a re-run.

Invoke the `deep-research` skill scoped to: *"We are building toward <ULTIMATE
GOAL>. So far we have built <cycle digests>. What are the highest-leverage next
steps, the biggest risks/gaps, and the strongest options to move forward?"* Produce
a ranked suggestion set (each: what, why it advances the goal, rough effort).
Save to `docs/polylane/cycle-<N>-research.md`.

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
"$MEM" "$STATE" dump >> docs/polylane/progress.md
```
**Ensemble critic — not a single lenient judge (LLMs skew optimistic on "done").**
Score the goal with an ODD panel (≥3) of INDEPENDENT critics, each judging "goal
met?" against the tree's criteria + sub-goals from the digests/evidence, and at
least ONE adversarial (told to prove it is NOT done — find the criterion with weak
or missing evidence, the sub-goal marked done without proof). A sub-goal/criterion
counts as `done` only on the MAJORITY vote; a tie or an unrebutted "not done" keeps
it open. This runs ONCE per cycle (the panel votes together, not a repeated
council). **The panel also audits two more things each cycle:**
- **Drift audit:** did this cycle's output honor `NORTHSTAR.md` + the settled
  decision records? Name any contradiction — a drift finding becomes a fix item in
  the next spec, and repeated drift on the same theme means the north-star block in
  the lane prompts needs strengthening (do it).
- **Skills-ledger scoring (`docs/polylane/skills-ledger.md`):** for each skill
  the scout installed, grep the lane logs/verify docs for its trigger/output and mark
  `used+helped | unused | hurt`. `hurt` → remove now + log the learning; `unused`
  2 cycles running → the next scout suggests removal.
Then reconcile the tree from the vote and check termination — no vibes:
- `"$MEM" "$STATE" met` exits 0 (every criterion AND sub-goal done, per the panel)
  → write the final wrap-up (tree dump + all cycle digests + what's left), STOP.
- Otherwise → continue to Phase 5. (A blocked-and-unblockable sub-goal → mark it
  `blocked`, surface it, and either stop or route around it.)

## Phase 5 — batch questions + synthesize the next spec (auto-continue)
From the research suggestions + critic gaps + the tree's next open sub-goal, form
the next cycle's direction:
- Ask a batch of questions via AskUserQuestion (multiple rounds of ≤4 if needed —
  "numerous"). **Every question's FIRST option is the recommended next step**, so a
  single click (or no answer) advances the loop. **Every question also carries BOTH a
  "🔍 Go deeper — more questions on this next round" AND a "✨ Surprise me / go bold"
  option** (same mechanics as discovery — `references/discovery.md`): the first opens a
  finer round, the second commits to an ambitious next feature you name from the
  research. Questions steer scope/priority/tradeoffs — they never block the loop.
- **Bring a creative proposal each cycle, don't just fill gaps.** From the deep-research,
  surface at least ONE non-obvious "what would make this remarkable" idea (a wildcard
  feature, a signature-moment upgrade, a bold direction) as a real option — run it
  through the provocation toolkit (analogy · inversion · forced constraint · extremes ·
  magic wand), so the loop keeps getting MORE interesting over cycles, not just complete.
- **Adaptive + convergent follow-ups** (same engine as discovery): chase the biggest
  unknown, branch on the last answer, reflect back the plan periodically, and STOP
  asking once answers stop changing the next spec — don't loop questions for their own
  sake.
- Synthesize the chosen (or recommended) answers + top research suggestions +
  `"$MEM" "$STATE" next` into the next cycle's numbered INTEGRATION SPEC (each item
  one line + a testable outcome), exactly as `references/planning.md` produces. Skip
  any approach `attempted` already flagged as failed.
- Record the decision in the blackboard (`log <N> decision ...`), set the new
  baseline (`git rev-parse HEAD`), increment N, and GOTO Phase 1.

## North-star docs — write after every BIG decision, keep them in mind
The blackboard `log` is a terse machine index; north-star docs are the readable
anchors the loop and every lane re-read so nothing drifts or re-opens a settled call.
- **`NORTHSTAR.md`** — one short doc: the vision, the one thing, the wedge, the
  signature moment, the personality, the anti-goals. Written at strategy lock; updated
  ONLY on a north-star-level pivot (and that pivot gets its own decision record).
- **Decision records** — one Markdown file per BIG decision, via the helper:
  ```
  DEC="$(dirname "$MEM")/polylane-decision.sh"; DDIR=docs/polylane/decisions
  "$DEC" "$DDIR" new "<title>" "<the decision>" "<why>" "<consequences>" <cycle>
  "$DEC" "$DDIR" context     # the "do not contradict" digest to inject into cycles/lanes
  ```
  What counts as BIG: the chosen concept, the stack/architecture, a pivotal trade-off,
  a scope cut/deferral, a north-star pivot, a hard constraint. Record it the moment it's
  made — in discovery, at a plan gate, or mid-loop in Phase 5. Also mirror a one-line
  `log <cycle> decision ...` into the blackboard so the machine index stays complete.
- **How they're kept in mind:** every cycle START reads `NORTHSTAR.md` + `decision …
  context` (Phase 1); every lane prompt carries the north-star one-liner + settled
  decisions; the Phase-4 critic checks the cycle's output against them (work that
  contradicts the north-star or a settled decision is a finding, not a pass).

## Artifacts (persist across cycles — ALL under docs/polylane/, which cleanup keeps)
- `docs/polylane/NORTHSTAR.md` — the vision anchor, re-read every cycle + lane.
- `docs/polylane/decisions/NNN-*.md` + `INDEX.md` — the durable decision trail.
- `docs/polylane/ULTIMATE_GOAL.md` — the goal paragraph + success criteria.
- `docs/polylane/max-state.json` — the HTN goal tree + blackboard (criteria,
  sub-goals, decisions, learnings, attempts). The loop's memory across cycles. NEVER
  put this in `.polylane/` — that is the runner's scratch and is wiped each cleanup.
- `docs/polylane/cycle-<N>-digest.md` — the ~50 bullets per cycle.
- `docs/polylane/cycle-<N>-research.md` — deep-research + ranked suggestions.
- `docs/polylane/progress.md` — critic scores + tree dumps across cycles.

## Requirements
- **tmux + jq** — the runner opens one pane per lane and reads its manifest with jq.
- **claude** (default agent) on PATH — or set `agent`/`POLYLANE_AGENT` to `codex`/`gpt`/
  `aider`, or `POLYLANE_AGENT_CMD` to any CLI template (`{model}`/`{prompt}`).
- **`deep-research`** skill for Phase 3; **`superpowers`** for the concept bake-off +
  verification; **caveman** + **graphify** + **ponytail** (anti-over-engineering,
  `DietrichGebert/ponytail`) are baked into Claude lane prompts for token thrift, and
  the integrator runs `/ponytail-review` on the diff (all degrade gracefully if absent).
Each cycle uses the walk-away runner behind the supervisor, so usage-limit stalls,
dead panes, and wedged/never-started panes self-recover — a cycle never hangs on a
human. The whole engine ships in `bin/` and the knowledge in `references/`.

## Install
```
git clone https://github.com/GHGuide/polylane ~/.claude/skills/polylane
brew install tmux jq            # runner deps (Debian/Ubuntu: apt-get install tmux jq)
```
Then just describe what you want: `/polylane <your idea or ultimate goal>` — or
"build my app idea", "keep building toward <goal>". One command does the rest.
