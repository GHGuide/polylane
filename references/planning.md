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

A shared file has one owner. Other lanes request changes through
`docs/parallel-status.md`. One lane at a time holds any shared physical resource.

## 4. Select models and skills

Use model ids supported by the selected CLI. Never put Claude ids in a Codex
manifest or vice versa. Use a strong integrator; choose the cheapest builder that
reliably fits each lane.

Run the per-lane scout from `skill-scout.md`. Every builder gets a bounded selected
kit: one or two installed predefined plus one or two installed lane-specific skills,
at most four unique. GitHub results are informational opt-in recommendations, never
executable defaults.

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
- `docs/verify-<lane>.md` evidence contract;
- scoped staging/commits and no `git add -A`;
- exact `STATUS: <lane> DONE run=<run_id>` first-line marker.

The integrator prompt also requires:

- merge current lane branch tips into its own branch, never base;
- scope checks and seam scan; when only coordinator-owned terminal checks remain, commit `READY-FOR-HOST-GATE run=<RUN_ID>` instead of rerunning the terminal suite;
- repair every autonomous issue it can;
- exactly one current-nonce sentinel:
  `GO`, `EXTERNAL-EVIDENCE-OPEN`, or `NO-GO`;
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
