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

**Each cycle:** build → merge → **on-disk digest** →
**deep-research the next steps toward the goal** → **COUNCIL scores + elects where next** →
**one-paragraph report + the Next line, then emergent questions** → synthesize the next spec →
build again. It does not stop for you between cycles — recommended defaults carry it
forward; your answers only steer.

## Locked behaviors (this mode's contract)
- **Termination:** loop until the COUNCIL + the goal-tree BOTH judge the ULTIMATE GOAL met
  AND a mechanical shippability gate passes (or it's blocked),
  or the user says stop. No fixed cycle count.
- **Questions:** every question ships a pre-picked recommended answer. Ask, but if
  the user doesn't weigh in, take the recommended path and start the next cycle —
  it "pops questions AND keeps working."
- **Research depth:** full `deep-research` skill each cycle (favor thoroughness over
  token thrift) — but scoped to NEW ground: each cycle reads prior
  `cycle-*-research.md` and never re-runs coverage already done.
- **Report:** ONE short paragraph of what the cycle made + a single `Next:` line, in the
  chat at the cycle CLOSE (Phase 5) — AFTER the council elects where to go next, so `Next`
  is the council's actual decision, not a premature guess. The ~40–60 bullet digest is
  written to disk (`cycle-<N>-digest.md`), never dumped into chat.
- **Walk-away (autonomous) mode:** with `POLYLANE_AUTONOMOUS=1` the orchestrator NEVER
  blocks on `AskUserQuestion` — for every question (skill scout, plan gate, emergent
  questions) it takes the recommended default in-process, records the chosen defaults to
  `docs/polylane/cycle-<N>-questions.md`, and proceeds. Interactive mode asks, but
  recommended-first so a no-answer/one-click still advances. A cycle boundary never hangs.
- **Question budget:** at most ONE consolidated scout round (≤4 lanes per `AskUserQuestion`
  call) and ONE emergent-question round (≤4 per call; extra rounds only while answers keep
  changing the spec) per cycle — never flood the user.
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

**Two memory layers — they complement, not compete:**
- **Curated (above, `polylane-claudemem.sh`)** — YOU choose 1–3 high-signal durable facts.
  Deliberate, secret-screened, always on.
- **Automatic (`thedotmack/claude-mem`, optional)** — a hook-based plugin that captures
  EVERY session (each lane is one) and auto-injects relevant prior context into new ones,
  with zero prompt changes. If installed, the orchestrator can also `mem-search "<query>"`
  at entry as an extra recall source. Recommend it via skill-scout. **Caveat:** its broad
  auto-injection can add noise to a deliberately isolated lane — lanes still obey their
  hard OWN/FORBIDDEN contract, so it's a noise risk not a correctness one; wrap anything a
  lane must NOT persist in `<private>…</private>`. Use it for breadth, the curated bridge
  for the facts that actually decide the next run.

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
- **Scaffold the built app's `AGENTS.md`** (root of the project being built — the
  cross-agent context anchor Claude Code + Codex both read). Write a TIGHT first version
  from the strategy: Mission · Stack + key decisions · Run/build/test (fill in as they
  become real) · Status. Refreshed every cycle (Phase 5); kept short + curated per
  `references/documentation.md` — bloated context files measurably hurt.
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
# VERIFY-FIRST: register a FROZEN, executable acceptance check per sub-goal NOW,
# while it is still open — the grader is authored before the build, so a lane can't
# weaken its own bar. Phase 4 runs `check-accept` and `met` requires every one green.
"$MEM" "$STATE" add-accept    m1.1 'cd "$REPO" && <a command that EXITS 0 iff m1.1 truly works>'
```
**Always seed ≥1 success criterion** — `met` can never fire without one, so a crisp-goal
run with zero criteria can never terminate; if the user gave none, synthesize 3–5
measurable ones from the goal. **If `docs/polylane/NORTHSTAR.md` does not exist** (the
crisp-goal path skipped Phase 00 discovery), synthesize a MINIMAL one now from the goal +
criteria — a few punchy lines (vision · the one thing · anti-goals) — so every downstream
feature that re-reads the north-star (lane prompts, the Phase-4 council, the Phase-5
harvest) has its anchor.

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
file-isolated lanes real overlap allows → tune model/effort per lane → **per-lane skill scout (Gate 1b) — arm each lane before its prompt is written** → generate the
paste-ready prompts → emit `.polylane/run.json` (with the `intensity` the USER PICKED in
discovery dimension 12 — never silently default; if somehow unset, ASK before launch) →
launch (below) → merge on GO. The picked intensity sets each lane's model+effort per
`references/model-selection.md`; you may still bump a single hard sub-goal a tier up:
- **Cycle 1:** derive the first concrete spec from the ultimate goal (a short
  deep-research pass to scope it), present it at the plan gate, then build.
- **Cycle N>1:** the spec is already synthesized from the prior cycle (Phase 5) —
  skip the interview, go straight to recon → lanes → plan gate → hands-off run.

**Gate 1b — PER-LANE skill scout (after lane derivation, BEFORE prompt generation —
`references/skill-scout.md`):** the domain-agnostic base (graphify · caveman · ponytail ·
superpowers · claude-mem) is already in block 0 of EVERY lane — the scout never re-suggests
it. Walk each BUILDER lane (skip the integrator + every non-Claude lane): infer its domain
from name + OWN globs + goal, list that lane's activities, and match each slot against
already-installed skills → curated DOMAIN list → GitHub search for unfilled slots. For each
lane with a real slot, add ONE question object (`multiSelect: true`) scoped to THAT lane —
1–3 domain skills each with a one-line WHY tied to THIS lane ("`playwright` — drives the
real dashboard + screenshots each view as verify evidence") + ALWAYS a final `None`
(≤4 options, the tool cap); batch ≤4 lanes per `AskUserQuestion` call. **The recommended
first option contains ONLY already-installed skills (they bake free); any skill needing
install is a non-default option requiring an explicit YES, GitHub-searched skills are never
the default, and NOTHING untrusted is auto-installed.** A lane with no slot gets no
question. In autonomous mode, skip the call, take installed-only defaults, log to
`cycle-<N>-questions.md`. Bake each accepted skill into ONLY that lane's block D `<lane
skills>` slot AFTER a passing `test -f`, and write the per-lane picks to
`.polylane/lane-skills.json` (Phase 6 reads it). Record per lane in
`docs/polylane/skills-ledger.md` (`| cycle | lane | skill | why | used by lane? | verdict
|`). The council later scores each (used/helped/hurt) — unused 2 cycles on the same kind of
lane → suggest removal; the scout reads the ledger first and never re-suggests removed /
unused / declined ones. The ponytail/claude-mem install-once offers (whole-run wins) fire
only the first time they're absent, and a decline is logged so a resumed run won't re-nag.

**Gate 1c — mechanical isolation + best-of-N + salvage (cheap, catches what LLMs miss):**
- **Isolation pre-check (free, before launch):** `bin/polylane-scope.sh check-static
  .polylane/run.json` — asserts every lane has non-empty `own_globs` and no two lanes'
  globs can match the same path. On `SCOPE-OVERLAP`/`SCOPE-EMPTY`, RE-CARVE (the derivation
  put two lanes on a collision course) before spending a single pane. After a lane commits,
  `check-lane .polylane/run.json <lane> $(git -C <wt> diff --name-only $BASE..HEAD)` catches
  silent scope creep (a same-file double-write git merges with no conflict marker).
- **History-based risk predictor (learns across runs):** `bin/polylane-outcomes.sh predict
  .polylane/run.json` (`OUTC="$(dirname "$MEM")/polylane-outcomes.sh"`) — scores each proposed
  lane's NO-GO rate among past lanes of the same mechanical SHAPE (`b<globs>:hub<k>:crowd`,
  where hub-files are auto-learned from prior `SEAM-DANGLING`/bisect culprits). `RISK <lane>
  <pct> (hub file '<f>')` at rc 5 → isolate that hub file or re-carve before spending. In
  Phase 4, feed it: `"$OUTC" record <lane> "$("$OUTC" signature <globs>)" <model> <GO|NO-GO>`
  for every lane, and `"$OUTC" hub add <file>` for each seam/bisect culprit — so the recurring
  "two lanes both need the router/entrypoint/global-CSS" carving mistake becomes a free
  pre-spend static check next run. `"$OUTC" tune "$sig"` returns the cheapest model that has
  historically CLEARED that shape — default a lane's model to it instead of re-deriving.
- **Best-of-N for ONE high-uncertainty lane** (the signature moment, a gnarly algorithm, a
  bold visual): give that lane `"variants": K` — K worktrees build it in parallel, each
  emits `POLYLANE-SCORE: <int>` in its verify file; `bin/polylane-select.sh pick …` merges
  the winner (tie → fewer LOC), discards the rest. Reserve for a genuinely uncertain lane —
  it's K× the spend.
- **Salvage on NO-GO (≥3 lanes):** don't discard four good lanes for one bad neighbour —
  `bin/polylane-bisect.sh salvage <lanes…>` (with a verify callback that merges a subset into
  a throwaway branch + runs the integrator smoke) delta-debugs the minimal failing subset,
  promotes the maximal GREEN subset, and maps each culprit → `"$MEM" "$STATE" set-status
  <lane> blocked` so the next cycle routes around it.

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
POLYLANE_CYCLE=<N> POLYLANE_SESSION="polylane-c<N>" "$BIN/polylane-supervisor.sh" .polylane/run.json
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

## Phase 2 — build the on-disk digest (the record, not the chat report)
As soon as the cycle merges, gather the raw inventory and turn it into the durable RECORD —
but post NOTHING to chat yet. The visible one-paragraph report + `Next:` line is emitted at
the cycle CLOSE (Phase 5), after the council has decided where to go next, so `Next` is the
council's real call and not a premature guess.
```
DIGEST="$(dirname "$RUNNER")/polylane-digest.sh"
"$DIGEST" <this-cycle-baseline>          # commits + diffstat + new files + verify summaries
```
Condense the inventory into ~40–60 concrete bullets grouped by area, each specific ("added
X", "fixed Y", not "improved things"), and save to `docs/polylane/cycle-<N>-digest.md`.
Then rebuild the bounded corpus so the council + research read O(1), not every digest:
`"$(dirname "$RUNNER")/polylane-corpus.sh" compact` (recent cycles verbatim, older
one-lined, hard byte cap — this is what keeps a long run context-bounded).
That file is a hard deliverable every cycle — full detail lives there, on disk. A single
terse chat ack is fine ("cycle N merged — <k> lanes; digest saved; scoring next"); never
dump the bullets into chat. If one action would realize the value of what's built (ship it,
run the real thing, the one paid run behind an API key), note it at the TOP of the digest
as "DO THIS TO CONVERT" — it becomes the lead of the Phase-5 paragraph.

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

## Phase 4 — council gate (goal met? where next? shippable?) — scored against the tree
Update the goal tree from this cycle's digest, then judge with a COUNCIL — not vibes, not a
single lenient judge (LLMs skew optimistic on "done"). First reconcile the tree with
evidence:
```
"$MEM" "$STATE" set-status <subgoal-id> done "<evidence: commit / test / file>" <N>
"$MEM" "$STATE" set-status <criterion-id> done|open
"$MEM" "$STATE" progress            # X/Y sub-goals · A/B criteria · %
"$MEM" "$STATE" dump >> docs/polylane/progress.md
```

**The council — an ODD panel of 5 INDEPENDENT members, distinct lenses, run ONCE.** Not a
done/not-done vote — it decides WHERE the loop works next so the WHOLE vision lands, and
stops only when the vision is truly whole + shippable. Fan the 5 out in parallel (they must
NOT see each other's answers). Each reads the same packet — tree `dump` + all cycle digests
+ `NORTHSTAR.md` (or `ULTIMATE_GOAL.md` if absent) + this cycle's evidence + any
high-original-weight sub-goal open ≥3 cycles (the STARVATION guard — force it into the
packet so weight-inflation can't bury it) — and returns TWO things:
- a **COMPLETE vote**: is the FULL vision truly done? `yes|no` + the single weakest/missing
  piece if `no`.
- a **NEXT-FOCUS proposal**: the one thing most worth building next toward the WHOLE vision,
  from that lens, mapped to an existing sub-goal id OR `NEW: <text> under <milestone-id>`.

The 5 lenses (each answers ONLY from its lens, no consensus-seeking):
1. **USER-VALUE** — the single next focus that most helps a REAL user; the thing they'd hit
   first that isn't there yet.
2. **COMPLETENESS** — against `NORTHSTAR.md` + every criterion, the biggest MISSING piece.
3. **QUALITY/RISK** — what shipped this cycle is fragile/unverified/unsafe; the focus that
   most cuts the risk of the whole thing breaking.
4. **EFFORT/ROI** — the CHEAPEST high-impact next step (informs the debate, never decides).
5. **ADVERSARY** (mandatory) — told to PROVE the vision is NOT done: the criterion with
   weak/missing evidence, the sub-goal marked done without proof, the north-star element
   never actually delivered. Its NEXT-FOCUS is the gap it judges most damning.

Log every member's vote + proposal:
```
"$MEM" "$STATE" log <N> decision "council/<lens>: complete=<yes|no> focus=<subgoal-id|NEW:...>" "<one-line why>"
```

First run the frozen graders — `"$MEM" "$STATE" check-accept --cycle <N>` executes every
pre-registered acceptance check (ALWAYS re-run for correctness — a check often reads files
outside its declared deps, so caching a stale pass would hide broken work; opt into
content-hash memoization only via `POLYLANE_ACCEPT_MEMO=1` when a check provably reads
only its deps) and stamps pass/fail; `met` (below) then REQUIRES every
one green, so a sub-goal marked `done` whose executable check fails cannot terminate the
loop. `"$MEM" "$STATE" unmet-accept` lists any that block it. Then the TEMPORAL guard —
`REG=$("$MEM" "$STATE" regressions)`: any output means a check that PASSED in an earlier
cycle now FAILS (this cycle silently broke earlier verified work — a temporal seam the
spatial seam-scanner can't see). Non-empty `$REG` is an auto-NO-GO/revert of THIS cycle,
same as a `SEAM-DANGLING`; fix the regression before the council can vote complete.

**Ledger the spend (mechanical money gates the council can't rationalize past).** The
runner already appended a row to `docs/polylane/spend-ledger.jsonl` with `subgoals 0 0`;
re-stamp it with the real counts (`"$MEM" "$STATE" progress`) via a corrected `LED record`
(`LED="$(dirname "$MEM")/polylane-ledger.sh"`). Then the gates before the next cycle:
`"$LED" cap` (rc 5 = hit `POLYLANE_MAX_CYCLES` or `POLYLANE_BUDGET` → the HARD "never
unbounded spend" stop, enforced mechanically not by discretion → STOP), `"$LED" trend`
(rc 3 = spend with ZERO tree progress → a semantic stall the pane-level detector misses →
STOP with the wrap-up), and `"$LED" roi <next-weight> <open-weight-sum> <budget>` (rc 4 =
the next sub-goal costs more than its share of remaining value warrants → STOP on the
diminishing tail). At lane-carve, `N=$("$LED" fit <budget> <N>)` trims the wave
to what the budget affords before any pane spawns.

**Synthesis (a) — Terminate?** STOP only when ALL THREE pass (each patches the others' blind
spot):
- a MAJORITY (≥3 of 5) votes `complete=yes`, AND
- `"$MEM" "$STATE" met` exits 0 (every criterion AND sub-goal `done`, AND every acceptance check `pass`), AND
- the **mechanical shippability gate** passes: from a FRESH checkout/clone, `install →
  build → boot/smoke-run` all green (the integrator's per-cycle verify is incremental — this
  is a from-zero certification), a root **`AGENTS.md` exists with real run/build/test commands**
  (context a fresh agent needs — a build with no entry doc isn't shippable), and every
  `NEEDS FROM YOU` in `STRATEGY.md` is resolved or explicitly acknowledged. An LLM council
  can vote "complete" on code that doesn't compile;
  only this gate catches that.
Reconcile disagreement rather than trusting one signal:
- `met`=0 but council majority says NOT complete → the tree is under-specified: turn each
  dissenter's missing piece into a NEW sub-goal/criterion (`add-subgoal`/`add-criterion`) so
  the tree reflects reality, then continue. **Scope-creep filter:** only add a criterion for
  a genuine `NORTHSTAR.md` element — never gold-plating/polish, or the tree grows faster than
  it closes and `met` never converges.
- Council majority says complete but `met`≠0 → the tree is authoritative; do NOT stop.
- Shippability gate fails → create a sub-goal for the failure, `set-weight <id> top`,
  continue (this becomes next cycle's focus).
- All three pass → write the final **runbook wrap-up** (how to run/deploy, env/secrets
  needed, the one converting action, tree `dump` + all digests + an honest what's-left),
  STOP.

**Synthesis (b) — pick WHERE to work next (the council's real job, only if not stopping).**
Tally the 5 NEXT-FOCUS proposals; group ones pointing at the same focus. **Always ground the
tally in the tree, not raw LLM count:** first restrict to proposals that advance an OPEN
criterion or OPEN sub-goal; a proposal advancing nothing open is dropped. **Anti-thrash
completion bias:** if a focus with committed-but-incomplete work is still open, keep working
it — do NOT switch off it unless it's `blocked` or a strictly higher-severity gap emerged.
The most-backed surviving focus wins. **TIE → break toward the HIGHEST-VISION-ADVANCING
option**, in strict order: (1) closes an OPEN success criterion, (2) delivers an undelivered
`NORTHSTAR.md` element, (3) the COMPLETENESS pick, (4) the ADVERSARY pick. NEVER break toward
the cheapest.

Make the winner the loop's next target:
```
# winner = an existing OPEN sub-goal:
"$MEM" "$STATE" set-weight <subgoal-id> top
# winner = NEW (create under the closest milestone, then elevate):
"$MEM" "$STATE" add-subgoal <milestone-id> <new-id> "<focus>" 1
"$MEM" "$STATE" set-weight <new-id> top
"$MEM" "$STATE" log <N> decision "council focus → <id>: <focus>" "<why it most advances the vision now>"
```
**Dead-end guard:** if `met`≠0 but `"$MEM" "$STATE" next` prints nothing (a criterion is
open with no sub-goal mapping to it), you MUST `add-subgoal` + `set-weight top` a sub-goal
that closes each still-open criterion — otherwise Phase 1 has no build target while `met`
refuses to terminate.

**The council also audits two things each cycle:**
- **Drift audit:** did output honor `NORTHSTAR.md` + settled decisions? A contradiction
  becomes a fix item in the next spec; repeated drift on a theme → strengthen the north-star
  block in the lane prompts (do it).
- **Skills-ledger scoring (per lane, `docs/polylane/skills-ledger.md`):** for each skill the
  scout installed, grep THAT lane's logs/verify docs for its trigger/output and mark
  `used+helped | unused | hurt`. `hurt` → remove now + log the learning; `unused` 2 cycles on
  the same kind of lane → next scout suggests removal.

A blocked-and-unblockable winning focus → `set-status <id> blocked`, surface it, and re-run
(b) on the remaining proposals to route around it. If EVERY proposal is blocked, surface why
and stop.

## Phase 5 — close the cycle: report + Next, then emergent questions → next spec (auto-continue)
The council (Phase 4) has already elected the focus and given it top weight, so
`"$MEM" "$STATE" next` now returns the council's decision. Close the cycle in this order —
report first (matches the user's "report, then what's next, then questions"):

**1. Emit the ONE visible report (chat).** Exactly this shape, nothing else — the paragraph
comes from the on-disk digest (Phase 2), the `Next` line from the council-elected focus:
```
<one short paragraph, 2–4 sentences, plain prose, no bullets: what THIS cycle actually
built — the concrete features/systems the user can now touch — leading with the converting
action if one is in reach, ending with: Full digest: docs/polylane/cycle-<N>-digest.md>

Next: <what the loop builds next = the council-elected focus> — <why it's the highest-leverage move now, tied to the goal/tree>.
```
Name real things ("email+password auth", "the /dashboard route"), never categories. This
paragraph + `Next` line IS the cycle's visible report; the ~40–60 bullets stay on disk.
(Skill-scout and the emergent questions below are separate interactive surfaces — this
"nothing else" rule scopes the REPORT, not the whole cycle.)

**2. Harvest the OPEN decisions this cycle surfaced** (the questions are DISTILLED from what
was just built, not a fixed script). Read, in order:
- this cycle's digest + the diff/new files — shipped work makes new choices decidable;
- each lane's `## DEFERRED` section in `docs/verify-<lane>.md` (guaranteed by block J) +
  grep the reflections/verify docs for `TODO|for now|left as|stub|hardcoded|assume`;
- Phase-4 council/adversary gaps + drift findings; Phase-3 research; and
  `"$MEM" "$STATE" next` — the council's chosen focus.
Distill into a SHORT list of REAL forks, each phrased "this cycle did X, so Y is now open."
DROP anything the build did not actually make live — no generic backlog items.

**3. Ask the emergent questions** (ranked by the council's focus first). `AskUserQuestion`,
≤4 per round, extra rounds only while answers keep changing the spec. Every question:
- NAMES the thing this cycle built that raised it ("You shipped device-only storage this
  cycle …") — so it visibly EMERGED from the work;
- FIRST option = the recommended next step, `(Recommended)` → one click or no answer advances;
- carries a "🔍 Go deeper — more questions on this next round" option AND a "✨ Surprise me /
  go bold" option (same engine as `references/discovery.md`);
- steers scope/priority/tradeoffs, NEVER the top focus (the council owns that) — never blocks.
In autonomous mode, skip the call, take recommended defaults, log to `cycle-<N>-questions.md`.

**4. Ask ONE idea-improvement question per cycle — RELEVANT-ONLY, to make the whole product
better, not just close the last cycle's forks.** Each cycle, from what JUST shipped + the
deep-research + the north-star, ask: is there a genuine way to make the WHOLE idea better —
a signature moment, a sharper wedge, a "what would make this remarkable" upgrade the new
surface makes newly possible? Run it through the provocation toolkit (analogy · inversion ·
forced constraint · extremes · magic wand) and offer it as a real recommended-default option
(with go-deeper / surprise-me). ONLY ask when there's a real improvement on the table — if
the honest answer this cycle is "just finish what's planned," say so and skip it (never
manufacture a question). This is the "keep making it better and better" loop — but gated on
relevance so it stays signal, not nagging.

**5. Maintain the built app's living docs (context always current).** The built project's
root **`AGENTS.md`** (the cross-agent context anchor — Claude Code, Codex, and every other
agent read it) is a LIVING SPEC, refreshed each cycle so a fresh agent (or the next polylane
run) never loses context. Keep it TIGHT and human-curated — research shows bloated,
LLM-sprawl context files HURT (−3% success, +20% cost); a few sharp sections beat a wall of
prose. Update per `references/documentation.md`: Mission (the north-star one-liner) · Stack +
key decisions (from the decision records — the "do not contradict" digest) · Run/build/test
commands (the real ones, verified) · Conventions · What's done / what's next (from the tree).
Update the spec (STRATEGY.md + tree) BEFORE the next build when scope changed — spec first,
then code; never let it go stale.

**6. Synthesize + close the loop.** Fold the chosen (or recommended) answers + top research
suggestions + `"$MEM" "$STATE" next` (the council-elected focus — it LEADS the spec as item
1) into the next cycle's numbered INTEGRATION SPEC (each item one line + a testable outcome),
exactly as `references/planning.md` produces. Skip any approach `"$MEM" "$STATE" attempted`
already flagged failed. Then record the decision (`"$MEM" "$STATE" log <N> decision "<what>"
"<why>"`), set the new baseline (`git rev-parse HEAD`), increment N, and GOTO Phase 1.

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
