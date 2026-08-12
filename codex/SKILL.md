---
name: polylane
description: Build and continuously improve any repository-backed project from a vague or defined goal using isolated parallel Codex CLI lanes, durable documentation, and verified evidence. Use for software, trading or quantitative research, research/analysis, operations, content, data/automation, custom mixed projects, autonomous build loops, or when the user wants a goal taken to a truthful verified outcome.
---

# Polylane for Codex

Polylane turns a project goal into a durable, evidence-bearing outcome:

`discover profile → lock strategy → plan isolated lanes → Codex execution → integrate → verify → route next work`

The project may be software, but it need not be. Work, decisions, and evidence must
be repository-backed. This Codex package uses only Codex-native launch syntax; do not
import Claude commands, models, memory, or skill assumptions.

## Core contract

- Execute every builder and integrator as a real `codex exec` CLI in a tmux pane
  launched by `scripts/polylane-supervisor.sh`. Never replace it with collaboration
  agents, subagents, background tasks, or prose-only simulation.
- The goal tree and frozen acceptance are authoritative. A council is advisory and
  cannot declare completion or stop the loop; obey `scripts/polylane-cycle.sh route`.
- Keep one canonical repository. Builders get disjoint non-empty ownership and are
  promoted only through a verified integrator.
- Ask only for core decisions, secrets, money, consequential external authority, or
  unavailable manual evidence. Recommended defaults keep routine work moving.
- Never report a draft, simulation, analysis, or paper result as a live outcome.

## Entry, resume, and discovery

Keep durable state in `docs/polylane/`, never `.polylane/` scratch:

```bash
PL="$(cd "$(dirname "$(command -v polylane-run.sh 2>/dev/null || printf '%s' scripts/polylane-run.sh)")" && pwd)"
MEM="$PL/polylane-memory.sh"
STATE=docs/polylane/max-state.json
test -f "$STATE" && "$MEM" "$STATE" resume
```

On resume, read the bounded packet and accepted decisions; do not repeat discovery.
For a new or vague goal, follow [references/discovery.md](references/discovery.md).
Ask outcome/profile/evidence/risk first, then read only the chosen route in
[references/project-types.md](references/project-types.md). Before decomposition,
write `docs/polylane/PROJECT_PROFILE.md` and its matching machine form
`docs/polylane/PROJECT_PROFILE.json` with outcome, deliverables, stakeholders,
constraints, evidence, risk, external actions, and finish conditions. Run this
pre-goal gate before the goal tree or lanes:

```bash
scripts/polylane-project.sh gate docs/polylane/PROJECT_PROFILE.md docs/polylane/PROJECT_PROFILE.json
```

Lock concise `NORTHSTAR.md`, `STRATEGY.md`, `ULTIMATE_GOAL.md`, `INDEX.md`, and
decision records. The strategy links the profile, names the riskiest assumption,
and distinguishes autonomous deliverables from external proof. Create `AGENTS.md`
from [references/documentation.md](references/documentation.md): project operating
instructions, artifact provenance, reproduction/validation, decisions, and handoff.

Initialize observable criteria and frozen acceptance before lanes start:

```bash
"$MEM" "$STATE" init "<locked project outcome>"
"$MEM" "$STATE" add-criterion c1 "<observable finish condition>" 10
"$MEM" "$STATE" add-milestone m1 "<deliverable group>"
"$MEM" "$STATE" add-subgoal m1 m1.1 "<observable result>" 10
"$MEM" "$STATE" add-accept m1.1 '<focused reproducible check>'
"$MEM" "$STATE" add-accept m1.1 '<terminal certification>' --tier terminal
```

If a criterion can only become true after the coordinator's terminal host gate, list
its open id in the manifest's optional `target_criteria`; the runner closes it only
after verified promotion, cleanup, and the final efficiency proof. Never let a builder
or integrator pre-close host-owned evidence.

Use executable checks where they fit, plus source provenance, review, measurement,
or manual proof where that is credible. `external` is not `done`: preserve the exact
blocker while independent work continues.

## Profile safety gates

Apply the selected route in `project-types.md`:

- Trading defaults to research, backtest, walk-forward/out-of-sample, and paper
  evidence with provenance, leakage checks, costs/slippage, drawdown, robustness,
  and risk limits. Live capital or broker action needs explicit user authority and
  actual execution evidence.
- Research distinguishes sources, findings, inferences, uncertainty, and qualified
  review boundaries.
- Operations, content, and data work distinguishes a prepared artifact from sent,
  published, purchased, deployed, or changed external state.
- UI Visual Intelligence is required only when discovery or recon finds a user-facing
  UI. Then follow [references/visual-intelligence.md](references/visual-intelligence.md),
  carry literal `ULTIMATE-GOAL`, a reference packet with reference evidence, and a
  design lock covering tokens, layout, motion, and signature. Automatically discover
  optional candidates only into quarantine; audit and benchmark them, then require a pinned arm before use.
  If admission fails, never execute rejected content and use the best
  installed kit. The council chooses the lock automatically. Require product-specific
  typography, imagery, and humanized UX copy; desktop/mobile and
  empty/loading/error/hover/focus captures; three independent visual lenses; and at most two targeted repairs.
  Render at least three divergent candidates from one locked base and pick the winner by
  calibrated blind mirrored judging against the incumbent best-so-far after deterministic
  hard gates. Label a per-project pick `SELECTED_NOT_CERTIFIED`; reserve `TASTE-CERTIFIED`
  and `human_certified` for the separate >=10 varied-brief global benchmark and real humans.
  After promotion write only bounded, evidence-scoped taste memory.
  Compare anonymized screenshots blind. Reject
  emoji-as-product-art and default-font sameness. Promotion needs >=10 varied prompts and >=70% creative/polish wins.
  Require no accessibility regression and a visual certification record.

## Evidence-driven domain autonomy

For a selected profile, seed discovery with the typed adapter tree:

```bash
scripts/polylane-discovery.sh init .polylane/discovery.json "<brief>" <software|trading|research|operations|content|data|custom|mixed>
scripts/polylane-discovery.sh next .polylane/discovery.json
```

Keep **Go deeper** domain-specific: a trading answer leads to chronological
splits/costs/paper boundaries, research to sources/inclusion/uncertainty, and so
on. After a promoted cycle, ask an emergent question only when its answer could
change deliverables, evidence, risk, or next focus; otherwise continue autonomously.
The short report always precedes `Next:` and any question.

Before builders launch, register the chosen profile’s executable bundle grader in
the manifest’s optional `domain_runtime` object (profile, bundle, grade, and
registration paths). The runner registers it before pane creation and reruns it
against the integrator worktree before promotion. A missing, checksum-mismatched,
or profile-incomplete deliverable bundle is a gate failure—not a generic
file-exists pass. See [evidence-driven domain autonomy](references/evidence-driven-domain-autonomy.md).

Use source-pinned real-domain trials as deterministic completion evidence:

```bash
scripts/polylane-domain-trials.sh validate benchmarks/domain-trials/v1
scripts/polylane-domain-trials.sh run benchmarks/domain-trials/v1 .polylane/trials
```

`--live` is an explicitly requested, read-only canary; `SKIP` is not `PASS` and
can never make offline CI flaky. For long-run certification, prove faults now with
the accelerated harness, then give operators the exact 6/12/24-hour resumable
commands and status path; do not wait in an integration cycle.

When `outcome_learning` is configured, the runner calls the empirical optimizer at
the plan gate and writes its recommendation/reason. It applies only a measured,
available, role-safe single model or effort change; thin samples, ties, unavailable
models, and lane/context topology changes preserve the user intensity/default.
After a promoted accepted cycle it writes an accepted-outcome receipt. Unknown
telemetry stays unknown and is not supplied as made-up optimizer evidence.

Skill scouting is lane-specific. Candidates with no matching benchmark, a failed
benchmark, or a changed fingerprint may be offered but are never recommended,
armed, or auto-installed; **None** remains an explicit choice. Before every
consequential action, prepare and verify the exact action-preview/simulation
receipt, surface critical approval in the main chat, and bind approval to its
receipt hash. Approval never authorizes an altered payload, and this helper has no
execution path. Trading remains paper/backtest research unless the user separately
authorizes live capital and supplies actual execution proof.

## Plan and launch a cycle

Read the current brief, profile, strategy, accepted decisions, and only relevant
artifacts. Plan the smallest safe lane set: target, evidence, risks, dependencies,
`OWN`/`FORBIDDEN`, and frozen cross-lane contracts. Do not create idle lanes or
repeat a recorded failed approach.

Each prompt must state the goal, project profile, ownership, selected installed skills,
focused test cadence, scoped staging, `docs/verify-<lane>.md`, exact completion
marker `STATUS: <lane> DONE run=<RUN_ID>`, and builder POLYLANE-RUNTIME-FINALIZE: immediately before completion, run the final relay and durable inbox read; handle all addressed autonomous work; run focused verification; scope-stage every owned changed or new file with `git add <your files>`; commit implementation and evidence; verify `git status --short` contains only runner-owned `.polylane-prompt.txt` and `graphify-out`; only then write the current-run status file, force-add the ignored status file with `git add -f`, commit that final handoff, and immediately exit. No reads, tests, edits, relay decisions, or commits may follow the marker/verdict commit. For an integrator, only then write the only current-run POLYLANE-VERDICT sentinel as the final line of docs/verify-integration.md and write docs/status-<lane>.md with only its DONE marker and no verdict, force-add both handoff files with `git add -f`, commit that final handoff, and immediately exit. Route expensive repeated checks through:

```bash
scripts/polylane-check.sh <canonical-project>/.polylane/check-cache/<lane> -- <command>
```

For every Codex manifest, set the provider identity literally as
`"agent": "codex"`; use Codex-supported model ids and never import Claude launch
syntax, model names, or memory helpers.

A cached failure requires a relevant source change before retry. For `prime_hybrid`,
read `POLYLANE_CONTEXT_PACKET` exactly once and use `polylane-workers.sh` and the
durable inbox for follow-ups. `prime_hybrid` refinements first run
`"$POLYLANE_PROJECT_ROOT/bin/polylane-refine.sh" queue "$POLYLANE_HARNESS_DIR"`, then
exactly one real `propose` or `decline` per eligible item; `propose-or-decline` is NOT
a subcommand. Global skill changes remain proposals
to `scripts/polylane-skill-evolve.sh`, never edits to the active skill.

Builder final handoff: write only `docs/status-<lane>.md`, force-add it if ignored,
commit it, and exit immediately. Integrator final handoff: write the only current-run
verdict sentinel as the final line of `docs/verify-integration.md`; write
`docs/status-<lane>.md` with only its DONE marker and no verdict, force-add both
handoff files if ignored, commit them, and exit immediately. Refinements first run `"$POLYLANE_PROJECT_ROOT/bin/polylane-refine.sh" queue "$POLYLANE_HARNESS_DIR"`, then exactly one real `propose` or `decline` per eligible item; `propose-or-decline` is NOT a subcommand.

Use `orchestration_contract: 2`; validate scope and prompts. A contract-v2 manifest
uses Codex-only model IDs and defaults `codex_profile` to `lean`. Run doctor and the
supervisor, then surface only the actual watch command, `tmux attach -t <session>`.
The integrator checks seams, profile evidence, and focused failures, then hands a
source-green result to the coordinator as `READY-FOR-HOST-GATE` without reinterpreting
launch or restart counters; runner-owned eligibility decides whether terminal checks start.
It writes one nonce-bearing verdict. `NO-GO` names repairs;
`EXTERNAL-EVIDENCE-OPEN` promotes verified repository work but never passes missing
external proof.

## Shared measured assurance

Use [references/cycle-9-control-room.md](references/cycle-9-control-room.md):
`scripts/polylane-product-benchmark.sh`, `scripts/polylane-discovery.sh`, model policy,
`scripts/polylane-promptopt.sh`, `scripts/polylane-judges.sh`, and the
canonical dashboard. Build a metadata-only `catalog-index`; select installed skills
only and record `SKILL-EVIDENCE` with each observable contribution. Use
`POLYLANE_COORDINATION_FILE` through `scripts/polylane-coordinate.sh`.
Use the compiled launch and lifecycle hooks contract in
`references/cycle-13-integration.md` only through shared helpers.

For `prime_hybrid`, retain bounded worker context and reject unvalidated refinement.
Repeated evidence enters the queue; queue it, then make exactly one real proposal or
decline decision, which validates it or invokes a rollback next cycle.
Skill evolution uses `scripts/polylane-skill-evolve.sh`: champion and challenger compare
against frozen cases, a failed canary rolls back, and ordinary
success does not rewrite the skill. Use `scripts/polylane-certify.sh` for focused and
terminal certification.

## Close, route, and complete

Write a cycle digest with delivered artifacts, evidence, provenance, decisions,
regressions, external blockers, and reproduction notes; update profile, strategy,
goal tree, `INDEX.md`, and handoff instructions before the next wave. The council can
add a frozen-acceptance subgoal or prioritize work, but cannot declare completion.

Profile-specific final handoffs name the actual artifacts and provenance, bundle-grade
result, risks/uncertainty, open external evidence, and material next questions. Never
promote an ungraded deliverable bundle or describe a prepared/simulated action as done.

When initially requested work is verified, generate exactly 30 concise, in-scope
suggestions, validate them, and take only the highest-leverage additions as one
`perfection` milestone. Final completion requires every requested and perfection
subgoal and criterion, all focused and terminal checks, no regressions or unresolved
seams, truthful documentation, and actual evidence for every external claim. Only then
end the tmux run and report the outcome with links to proof.
