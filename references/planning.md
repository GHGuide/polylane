# Per-cycle build pipeline

Use this after the locked goal and current cycle target exist. It is shared
planning knowledge; the active platform skill decides CLI syntax and installed
skill names.

Autonomous Polylane executes the plan. Prompt generation, plan approval, council
output, or a verdict is not a stopping point. A user may explicitly request
prompt-generation-only mode; otherwise continue through launch and cycle routing.

## 1. Freeze the executable target

Read the durable goal brief, north star, settled decisions, and current
`cycle-<N>-plan.md`. Each target item must map to:

- an open/doing subgoal id;
- observable done-when behavior;
- at least one frozen focused acceptance command;
- a small terminal check only when broad/final certification is needed.

Detect whether the target creates or materially changes a user-facing UI. If it
does, [visual-intelligence.md](visual-intelligence.md) is a frozen acceptance
contract: its reference packet, three directions, automatic council choice/design
lock, safe skill-admission record, staged screenshots, three-lens verdict, bounded
repairs, and champion benchmark belong in the plan before implementation.

Ask only if a core product decision would materially change the build. Routine
implementation choices take the recommended path and are recorded.

## 2. Recon before carving

Run `git status` and `git worktree list` first. Preserve unrelated user changes.
Read `AGENTS.md` and the real build/test commands.

Map target behavior to files and hidden couplings:

- shared entrypoints, routers, schemas, types, config, and generated code;
- DOM ids/events, route names, storage keys, API contracts, migrations;
- physical mutexes such as device, database, deploy target, or signed package.

Use an existing code graph when available, otherwise targeted `rg`/reads. Recon is
read-only and single-threaded; do not spend builder lanes on generic exploration.

## 3. Derive the smallest safe lane set

Follow `lane-derivation.md`. Generate two or three candidate carvings mentally
and select the one with:

1. zero source-file overlap;
2. the fewest frozen cross-lane contracts;
3. meaningful concurrent work;
4. low integration and stall risk.

Use one lane when writes overlap heavily. More lanes are not inherently better.
Every builder has non-empty `own_globs`; run:

```bash
bin/polylane-scope.sh check-static .polylane/run.json
```

A shared file has one owner. Other lanes use the canonical append-only relay at
`$POLYLANE_COORDINATION_FILE` through
`$POLYLANE_PROJECT_ROOT/bin/polylane-coordinate.sh`; the runner exports both into
every pane. Use `request`, `decision`, `claim`, and `release`; inspect `pending` or
`snapshot` rather than editing relay JSONL. One lane at a time holds any shared
physical resource. `docs/parallel-status.md` is written only as a durable post-cycle
summary, never as the live cross-worktree channel.

## 4. Select models and skills

Use model ids supported by the selected CLI. Never put Claude ids in a Codex
manifest or vice versa. Use a strong integrator; choose the cheapest builder that
reliably fits each lane.

Run the per-lane scout from `skill-scout.md`. Every builder gets a bounded selected
kit: one or two installed predefined plus one or two installed lane-specific skills,
at most four unique. For a UI skill gap, use only the authorized automatic route in
`visual-intelligence.md`: discover, quarantine, audit, isolated benchmark, pinned
project install, then arm. It never executes rejected content; an admission failure
records why and falls back to the best installed kit. Other GitHub results remain
informational opt-in recommendations, never executable defaults.

## 5. Generate self-contained prompts

Write `.polylane/lanes/<name>.txt`. Platform-specific preambles are optional and
must match the selected CLI, but these agent-neutral blocks are mandatory:

- identity, project context, `ULTIMATE-GOAL`, and exact locked `CURRENT-SUBGOAL`;
- exact `OWN` and `FORBIDDEN` paths;
- frozen shared APIs and request-an-edit behavior;
- `PREDEFINED-SKILLS:` and `LANE-SPECIFIC-SKILLS:`;
- explicit instruction to read only the named installed kit once; no generic stack or post-launch inventory discovery;
- `TEST-CADENCE:` focused while iterating, subsystem before DONE, full terminal
  suite only in integration/final certification;
- `DELEGATION:` forbidden; each tmux CLI is the sole agent for its lane and may
  not spawn app/subagents or nested fan-out;
- `CHECK-CACHE:` use `bin/polylane-check.sh "$PWD/.polylane/check-cache/<lane>" -- <command>` for expensive commands and reuse the
  recorded pass/fail until source or build environment changes;
- `EXTERNAL-EVIDENCE:` manual/physical evidence stays external while autonomous
  work continues;
- when `prime_hybrid: true`, the runner-provided context-packet/inbox instruction
  from `prompt-blocks.md` (read the bounded packet once; use the durable inbox for
  follow-ups; global prompt/skill ideas remain skill-evolution proposals);
- `docs/verify-<lane>.md` evidence contract;
- scoped staging/commits and no `git add -A`;
- exact `STATUS: <lane> DONE run=<run_id>` first-line marker.

For a UI lane, additionally compose the visual block from
`prompt-blocks.md`: literal goal and design lock, evidence-backed reference packet,
native selected-skill invocation, staged state/flow captures, three independent
lenses, at most two targeted repairs, product-specific asset/copy pass, and the
old-vs-new champion certification. Do not substitute a generic aesthetic.

The integrator prompt also requires:

- merge current lane branch tips into its own branch, never base;
- scope checks and seam scan; when only coordinator-owned terminal checks remain, commit `READY-FOR-HOST-GATE run=<RUN_ID>` instead of rerunning the terminal suite;
- repair every autonomous issue it can;
- exactly one current-nonce sentinel:
  `GO`, `READY-FOR-HOST-GATE`, `EXTERNAL-EVIDENCE-OPEN`, or `NO-GO`;
- its own exact DONE marker.

Run:

```bash
POLYLANE_STRICT_PROMPTS=1 bin/polylane-promptlint.sh lint-run .polylane/run.json
bin/polylane-scout.sh lint .polylane/lane-skills.json <lane> .polylane/lanes/<lane>.txt
```

## 6. Emit contract-v2 manifest

```json
{
  "orchestration_contract": 2,
  "run_id": "fresh-safe-nonce",
  "cycle": 3,
  "prime_hybrid": true,
  "state_file": "docs/polylane/max-state.json",
  "lane_skills_file": ".polylane/lane-skills.json",
  "cycle_plan_file": "docs/polylane/cycle-3-plan.md",
  "target_subgoals": ["m2.1"],
  "base": "main",
  "session": "polylane-c3",
  "agent": "codex",
  "available_models": ["gpt-model-strong", "gpt-model-fast"],
  "integrator": {
    "name": "integrator",
    "model": "gpt-model-strong",
    "effort": "xhigh",
    "branch": "lane/integrator",
    "worktree": "/absolute/scratch/integrator",
    "prompt_file": ".polylane/lanes/integrator.txt"
  },
  "lanes": [{
    "name": "feature",
    "model": "gpt-model-fast",
    "effort": "high",
    "branch": "lane/feature",
    "worktree": "/absolute/scratch/feature",
    "prompt_file": ".polylane/lanes/feature.txt",
    "own_globs": ["src/feature/**"],
    "target_subgoals": ["m2.1"]
  }]
}
```

The run-level targets are the union of lane targets and include the
highest-priority `memory next` id. `run_id` uses only `A-Za-z0-9._-` and is baked
literally into prompts.

Contract v2 fails before any side effect when state, plan, index, skills, scope,
acceptance, prompts, markers, or prior-cycle artifacts are missing.

`prime_hybrid` is an explicit, backward-compatible opt-in for long product work.
Before panes launch, the runner initializes `docs/polylane/harness` and
`docs/polylane/workers`, validates pending prior-cycle refinements, retains stable
worker identities, imports the canonical relay, and writes one bounded
`.polylane/context/<lane>.md` packet per builder and integrator. It exports the
canonical harness/workers directories, worker id, and packet path to every pane.
Completion capsules, repeated failure/stall/NO-GO observations, and cycle
compaction stay in durable project state; they never contaminate lane worktrees.
Repeated evidence not already handled is materialized as `refinement-queue.json`
before packet generation. The integrator must propose a bounded, check-backed local
change or explicitly decline each queued item; global changes still route through
the frozen skill-evolution gate.

## Cycle-9 launch additions (frozen)

Keep the manifest and prompts aligned with
[cycle-9-control-room.md](cycle-9-control-room.md). Product benchmark and durable
discovery are pre-build evidence, not parallel speculative lanes. Use the agent's
model helper; Codex manifests set `codex_profile` to `lean` unless the user
explicitly requests `user`. Prompt optimization is a pre-launch gate: mandatory
blocks remain intact and the configured budget is hard. The runtime may request
advanced selection/salvage and exactly three independent quality judges, but
absence must read `not-requested`, not executed. Observe the run through the
canonical dashboard snapshot, never a hand-built pane/marker view.

## 7. Launch and observe

Use the supervisor:

```bash
POLYLANE_AUTONOMOUS=1 \
  POLYLANE_SESSION="polylane-c<N>" \
  bin/polylane-supervisor.sh .polylane/run.json
```

Verify the live runtime and surface exactly its output:

```bash
bin/polylane-cycle.sh runtime .polylane/run.json
```

The supervisor resumes runner crashes/HALTED reports and drains safe approvals.
The runner recovers missing seeds, transient errors, dead panes, usage limits, and
frozen screens. A live run must always have a runner/heartbeat and active tmux
watch line.

## 8. Integrate, repair, and route

The integrator gates its combined branch. A valid GO or external-open verdict
still passes frozen acceptance before promotion. NO-GO/UNKNOWN preserves evidence
and respawns the integrator with a repair prompt; it is not a task boundary.

After verified promotion, the runner stamps target subgoals done and regenerates
progress. Cleanup kills tmux, removes merged worktrees and merged branches, and
keeps verification/report/log evidence.

The outer workflow then writes digest, research, council, questions, progress,
and the next plan. Run `polylane-cycle.sh artifacts`, then `route`. Continue
immediately on `CONTINUE`; only `COMPLETE` or `NEEDS-USER` may end autonomous work.
