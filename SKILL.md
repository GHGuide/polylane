---
name: polylane
description: Use when the user wants a vague or defined repository-backed project goal strategized, decomposed into isolated parallel Claude Code lanes, executed, and verified with durable evidence. Supports software, trading or quantitative research, research/analysis, operations, content, data/automation, and custom mixed projects. Triggers on "/polylane", "/lanes", "polylane", "strategize and build", "plan and run", "parallel terminals", "drive to the goal", "keep building toward", or requests to turn an idea, research, workflow, dataset, campaign, or product into a verified outcome.
---

# /polylane — autonomous project outcome loop

Polylane turns a goal into a durable, evidence-bearing outcome:

`discover profile → lock strategy → plan isolated lanes → execute → integrate → verify → route next work`

It supports any work representable in a repository. Software and UI work remain
specializations; they are never the default meaning of “project.” State and proof
live on disk, not in chat, so a later run can resume truthfully.

## Core contract

- Use real interactive Claude Code lanes in tmux; do not simulate lanes with
  subagents, background prose, or a different execution surface.
- The goal tree and frozen acceptance are authoritative. A council is advisory and
  cannot declare completion or stop the loop; obey `bin/polylane-cycle.sh route`.
- Keep one canonical repository. Builders own disjoint files, stage only owned
  changes, and are promoted only through a verified integrator.
- Ask only material questions. Recommended defaults keep routine work moving;
  user authority is required for secrets, money, material scope, consequential
  external actions, and inaccessible/manual evidence.
- Never call a drafted, simulated, researched, or paper result live. Evidence must
  support the exact completion language used.

## Entry, resume, and discovery

Set durable state under `docs/polylane/`, never `.polylane/` scratch:

```bash
MEM="$(dirname "$(command -v polylane-run.sh || echo "$HOME/.claude/skills/polylane/bin/x")")/polylane-memory.sh"
STATE=docs/polylane/max-state.json
test -f "$STATE" && "$MEM" "$STATE" resume
```

On a valid resume, read the packet and accepted decisions; do not repeat discovery.
For a new or vague goal, follow [references/discovery.md](references/discovery.md).
Ask outcome/profile/evidence/risk first, then read only the chosen router in
[references/project-types.md](references/project-types.md). Before decomposition,
write `docs/polylane/PROJECT_PROFILE.md` and its matching machine form
`docs/polylane/PROJECT_PROFILE.json` with outcome, deliverables, stakeholders,
constraints, evidence, risk, external actions, and finish conditions. Run this
pre-goal gate before the goal tree or lanes:

```bash
bin/polylane-project.sh gate docs/polylane/PROJECT_PROFILE.md docs/polylane/PROJECT_PROFILE.json
```

Lock concise `NORTHSTAR.md`, `STRATEGY.md`, `ULTIMATE_GOAL.md`, `INDEX.md`, and
decision records. The strategy must link the profile, name the riskiest assumption,
and distinguish autonomous deliverables from external proof. Create a root `AGENTS.md`
using [references/documentation.md](references/documentation.md): project operating
instructions, artifact provenance, reproduction/validation, decisions, and handoff.

Initialize measurable criteria and frozen acceptance before builders begin:

```bash
"$MEM" "$STATE" init "<locked project outcome>"
"$MEM" "$STATE" add-criterion c1 "<observable finish condition>" 10
"$MEM" "$STATE" add-milestone m1 "<deliverable group>"
"$MEM" "$STATE" add-subgoal m1 m1.1 "<observable result>" 10
"$MEM" "$STATE" add-accept m1.1 '<focused reproducible check>'
"$MEM" "$STATE" add-accept m1.1 '<terminal certification>' --tier terminal
```

Use executable checks where they fit, plus source provenance, review, measurement,
or external/manual proof where that is the credible evidence. `external` is not
`done`: it preserves the exact blocker while independent work continues.

## Profile safety gates

Apply the selected profile’s gate from `project-types.md`:

- Trading defaults to research, backtest, walk-forward/out-of-sample, and paper
  evidence with data provenance, leakage checks, costs/slippage, drawdown,
  robustness, and risk limits. Live capital or broker action needs explicit user
  authority and actual execution evidence.
- Research distinguishes sources, findings, inferences, uncertainty, and qualified
  review boundaries.
- Operations, content, and data work distinguishes a prepared artifact from sent,
  published, purchased, deployed, or changed external state.
- UI Visual Intelligence is mandatory only when discovery or recon finds a
  user-facing UI. Then follow [references/visual-intelligence.md](references/visual-intelligence.md);
  carry the literal `ULTIMATE-GOAL`, a reference packet with reference evidence,
  and a design lock covering tokens, layout, motion, and signature. Automatically
  discover optional candidates only into quarantine; audit and benchmark them, then require a pinned arm before use.
  If admission fails, never execute rejected content and use the
  best installed kit. The council chooses the lock automatically. Require
  product-specific typography, imagery, and humanized UX copy; desktop/mobile and
  empty/loading/error/hover/focus captures; three independent visual lenses; and at most two targeted repairs.
  Compare anonymized screenshots blind. Reject
  emoji-as-product-art and default-font sameness. Promotion needs >=10 varied prompts and >=70% creative/polish wins.
  Require no accessibility regression and a visual certification record.

## Plan and launch a cycle

Read the current brief, profile, strategy, accepted decisions, and only relevant
artifacts. Plan the smallest safe lane set: concrete target, evidence, risks,
dependencies, `OWN`/`FORBIDDEN` paths, and frozen cross-lane contracts. Never use
parallelism as theater or reopen a recorded failed approach.

Each prompt must state the goal, project profile, lane ownership, selected installed
skills, focused test cadence, scoped staging, `docs/verify-<lane>.md`, and the exact
completion marker `STATUS: <lane> DONE run=<RUN_ID>`. Route expensive repeated checks
through:

```bash
bin/polylane-check.sh <canonical-project>/.polylane/check-cache/<lane> -- <command>
```

A cached failure requires a relevant source change before retry. For prime-hybrid
runs, read `POLYLANE_CONTEXT_PACKET` exactly once and use `polylane-workers.sh` and
the durable inbox for follow-ups. `prime_hybrid` refinements use
`bin/polylane-refine.sh propose-or-decline`; global skill changes remain proposals to
`bin/polylane-skill-evolve.sh`, not edits to an active skill.

Use `orchestration_contract: 2`, validate scope and prompts, then run doctor and the
supervisor. Surface only the truthful watch command, `tmux attach -t <session>`.
The integrator checks seams, profile evidence, focused failures, then terminal check
at final certification and writes one nonce-bearing verdict. `NO-GO` names repairs;
`EXTERNAL-EVIDENCE-OPEN` promotes verified repository work but never passes missing
external proof.
After a post-PASS coordinator crash, the runner may reuse only its durable current-run
terminal receipt when the integration commit, manifest, acceptance state, tools,
platform, and exported environment still match exactly. List extra host executables in
`terminal_cache_tools`; any missing declaration or mismatch reruns the terminal gate.

## Shared measured assurance

Use [references/cycle-9-control-room.md](references/cycle-9-control-room.md):
`bin/polylane-product-benchmark.sh`, `bin/polylane-discovery.sh`, lean model policy,
`bin/polylane-promptopt.sh`, `bin/polylane-judges.sh`, and the canonical dashboard.
The shared runner keeps its `codex_profile` lean as metadata; Claude lanes do not
inherit Codex commands or launch assumptions. Use the compiled launch and lifecycle
hooks contract in `references/cycle-13-integration.md` only through shared helpers.
Build a metadata-only `catalog-index`; select installed skills only and record
`SKILL-EVIDENCE` with each observable contribution. The manifest’s `codex_profile`
equivalent is irrelevant here; do not import Codex syntax or assumptions into Claude
lanes. Use `POLYLANE_COORDINATION_FILE` through `bin/polylane-coordinate.sh`.

For `prime_hybrid`, retain bounded worker context and reject unvalidated refinement.
Repeated evidence enters the queue; `propose-or-decline` then validates it or invokes a rollback next cycle.
Skill evolution uses `bin/polylane-skill-evolve.sh`: champion and challenger compare
against frozen cases, a failed canary rolls back, and ordinary
success does not rewrite the skill. Use `bin/polylane-certify.sh` for focused and
terminal certification.

## Close, route, and complete

Write a cycle digest with delivered artifacts, evidence, provenance, decisions,
regressions, external blockers, and reproduction notes; update the profile, strategy,
goal tree, `INDEX.md`, and handoff instructions before the next wave. The council can
add a frozen-acceptance subgoal or prioritize work, but cannot declare completion.

When initially requested work is verified, generate exactly 30 concise, in-scope
suggestions, validate them, and take only the highest-leverage additions as one
`perfection` milestone. Final completion requires every requested and perfection
subgoal and criterion, all focused and terminal checks, no regressions or unresolved
seams, truthful documentation, and actual evidence for every external claim. Only then
end the tmux run and report the outcome with links to proof.

## Claude install

```bash
git clone https://github.com/GHGuide/polylane ~/.claude/skills/polylane
```
