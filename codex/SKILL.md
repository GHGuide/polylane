---
name: polylane
description: Use when the user gives a goal — or even a vague one-line app/product idea — and wants it strategized and BUILT autonomously by parallel Codex (or Claude/aider) terminals. Opens a product-discovery interview (easy recommended-default questions + research) that turns a fuzzy idea into a locked strategy + goal tree, then loops: derive file-isolated lanes → build in parallel → integrator merges on GO → digest → research → council picks where-next → report + questions → continue, until the goal is met and shippable or the user stops. Triggers on "polylane", "build my app idea", "strategize and build", "split this into parallel prompts", "run the lanes", "autonomous build loop", "turn my idea into an app".
---

# polylane (Codex build) — parallel autonomous app builder

polylane's engine is a set of pure-bash helpers under `scripts/` (jq the only dep,
plus `tmux` for the runner). The engine is AGENT-AGNOSTIC — the done-signal and
verdict are file-based — so it drives Codex lanes exactly as it drives Claude ones.
This skill is the Codex-flavored orchestrator; the deep mechanics live in
`references/*.md` (read them on demand, don't inline).

## Codex deltas (the only differences from the Claude flow)
1. **Agent = codex.** Every emitted `.polylane/run.json` sets `"agent": "codex"`, so
   the runner launches `codex exec --full-auto --model <model> "$(cat <prompt>)"` per
   lane. Or set `POLYLANE_AGENT=codex` at launch.
2. **Lane prompts are PLAIN instructions.** The Claude preamble (`/graphify-auto`,
   the caveman skill, `/goal`, `superpowers:*`) is Claude-Code-only — DROP it for
   Codex lanes. Keep the agent-neutral blocks verbatim: identity, OWN/FORBIDDEN +
   frozen contract, the locked goal in prose, "keep output terse", forced-verify
   evidence file, and the DONE-signal `STATUS: <lane> DONE run=<RUN_ID>` +
   `POLYLANE-VERDICT: … run=<RUN_ID>` (agent-neutral, mandatory). Use GPT/Codex model
   ids (e.g. `gpt-5-codex`) in the manifest.
3. **Questions are inline.** Codex has no AskUserQuestion tool — ask the discovery +
   per-cycle questions as normal chat with a clearly recommended default so one reply
   advances; in autonomous mode take the default and log it.
4. **Everything else is identical** and driven by the same `scripts/` helpers — lanes,
   gates, ledger, scout, council, promote, cleanup.

## Requirements
- `tmux` + `jq` on PATH (`brew install tmux jq`). `codex` CLI on PATH.
- The helpers under `scripts/` (this skill ships them). Reference them as
  `"$(dirname "$SKILL")/scripts/polylane-<x>.sh"`.

## The loop (same as the Claude skill; Codex-flavored)
0. **Discovery → strategy → tree.** Interview the user across the dimensions in
   `references/discovery.md` (problem · audience · the one thing · MVP · platform ·
   look&feel · data · integrations · business model · constraints · ambition ·
   **build intensity — ALWAYS ASK: economy|balanced|performance|max** · definition of
   done). Every question ships a recommended default + a "go deeper" option. Synthesize
   `docs/polylane/STRATEGY.md` + `NORTHSTAR.md`, then build the goal tree with
   `scripts/polylane-memory.sh` (`init` · `add-criterion` · `add-milestone` ·
   `add-subgoal` · `add-accept` a frozen executable check per sub-goal). Seed ≥1
   criterion (else `met` can't fire).
1. **Build a cycle.** From the tree's `next`, derive the FEWEST file-isolated lanes
   real overlap allows (`references/lane-derivation.md`) — check hidden couplings (DOM
   ids/routes/schemas), and `scripts/polylane-scope.sh check-static` before launch.
   Per-lane skill scout via `scripts/polylane-scout.sh` (domain→suggest→installed→bake→
   lint). Resolve per-lane model+effort from the picked intensity
   (`references/model-selection.md`). Generate PLAIN Codex prompts + emit
   `.polylane/run.json` (with `run_id`, `agent:"codex"`). Lint before launch:
   `scripts/polylane-promptlint.sh lint-run` + `scripts/polylane-scout.sh lint`.
2. **Launch + supervise.** `scripts/polylane-supervisor.sh .polylane/run.json` runs the
   `scripts/polylane-run.sh` runner behind a reviver; read state via
   `scripts/polylane-state.sh`. Runner: split worktrees → poll → auto-retry/repair →
   integrator (ensemble verdict + `scripts/polylane-seams.sh` scan) → promote base on GO
   only → cleanup → report.
3. **Digest + research.** `scripts/polylane-digest.sh` → `docs/polylane/cycle-N-digest.md`;
   `scripts/polylane-corpus.sh compact`; research the next steps toward the goal.
4. **Council gate.** 5 independent lenses (user-value · completeness · quality/risk ·
   effort · adversary) vote COMPLETE + elect where-next; reconcile the tree
   (`set-status`, `set-weight top`), run `check-accept` + `regressions`, and the money
   gates `scripts/polylane-ledger.sh cap|trend|roi`. STOP only when council-majority +
   `memory met` + a from-zero shippability check all pass.
5. **Close the cycle.** One short paragraph of what got built + a `Next:` line, then the
   emergent questions distilled from this cycle. Synthesize the next spec, GOTO 1.

## Resume
`test -f docs/polylane/max-state.json && scripts/polylane-memory.sh docs/polylane/max-state.json resume`
— continue from disk with no prior context.

## Install (per README / references/install-helpers.md)
Repo scope: `.agents/skills/polylane/`. User scope: `$HOME/.agents/skills/polylane/`.
`codex/install.sh` assembles the skill dir (SKILL.md + scripts/ + references/ + assets/).
