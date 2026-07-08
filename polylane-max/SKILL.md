---
name: polylane-max
description: Use when the user gives an ULTIMATE GOAL and wants polylane to drive toward it autonomously over many build cycles — each cycle builds a chunk (via polylane-auto), merges, then immediately reports ~50 bullets of what it made, deep-researches the best next steps toward the goal, asks a batch of recommended-default questions, and continues into the next cycle on its own until a critic judges the goal met (or the user stops). Triggers on "/polylane-max", "polylane max", "drive to the goal", "keep building toward", "autonomous build loop", "iterate to the ultimate goal".
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
  favor thoroughness over token thrift).
- **Report:** ~50 concrete bullets of what the cycle made, in the chat, immediately
  after merge — before research.

## Phase 0 — lock the ultimate goal (once)
Capture the ULTIMATE GOAL from the user's prompt in one crisp paragraph + 3–5
measurable success criteria. Confirm it once (single AskUserQuestion, recommended
= "yes, this is the goal"). Persist it so every cycle references the same north
star:
```
mkdir -p .polylane docs/polylane-max
cat > .polylane/ULTIMATE_GOAL.md   # the goal paragraph + success criteria
```
Record the loop baseline: `git rev-parse HEAD` → this is `cycle-1` baseline.

## Phase 1 — build a cycle (polylane-auto, no re-interview after cycle 1)
Run the full polylane-auto pipeline for THIS cycle's spec:
- **Cycle 1:** derive the first concrete spec from the ultimate goal (a short
  deep-research pass to scope it), present it at the plan gate, then build.
- **Cycle N>1:** the spec is already synthesized from the prior cycle (Phase 5) —
  skip the interview, go straight to recon → lanes → plan gate → hands-off run.
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

## Phase 3 — deep-research the next steps toward the goal
Invoke the `deep-research` skill scoped to: *"We are building toward <ULTIMATE
GOAL>. So far we have built <cycle digests>. What are the highest-leverage next
steps, the biggest risks/gaps, and the strongest options to move forward?"* Produce
a ranked suggestion set (each: what, why it advances the goal, rough effort).
Save to `docs/polylane-max/cycle-<N>-research.md`.

## Phase 4 — critic gate (goal met?)
A critic agent scores progress vs the ULTIMATE GOAL's success criteria (0–100 per
criterion + overall), using the cycle digests + research. Append to
`docs/polylane-max/progress.md`.
- **Goal met / blocked** → write the final wrap-up (all cycle digests + the
  criteria scores + what's left), post it, and STOP the loop.
- **Not yet** → continue to Phase 5.

## Phase 5 — batch questions + synthesize the next spec (auto-continue)
From the research suggestions + critic gaps, form the next cycle's direction:
- Ask a batch of questions via AskUserQuestion (multiple rounds of ≤4 if needed —
  "numerous"). **Every question's FIRST option is the recommended next step**, so a
  single click (or no answer) advances the loop. Questions steer scope/priority/
  tradeoffs — they never block the loop from continuing on defaults.
- Synthesize the chosen (or recommended) answers + top research suggestions into
  the next cycle's numbered INTEGRATION SPEC (each item one line + a testable
  outcome), exactly as `/polylane` Phase 1 produces.
- Set the new baseline (`git rev-parse HEAD`), increment N, and GOTO Phase 1.

## Artifacts (persist across cycles)
- `.polylane/ULTIMATE_GOAL.md` — the north star (never deleted by cleanup).
- `docs/polylane-max/cycle-<N>-digest.md` — the ~50 bullets per cycle.
- `docs/polylane-max/cycle-<N>-research.md` — deep-research + ranked suggestions.
- `docs/polylane-max/progress.md` — critic scores + decisions log across cycles.

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
