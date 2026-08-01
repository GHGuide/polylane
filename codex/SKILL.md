---
name: polylane
description: Build and continuously improve a software product from one prompt using autonomous parallel Codex CLI builders in isolated git worktrees and visible tmux panes. Use for Polylane, autonomous build loops, parallel terminal lanes, strategize-and-build requests, long-running product work, or when the user wants Codex to keep iterating until the locked goal is fully verified.
---

# Polylane for Codex

Polylane turns a prompt into a durable product loop:

`lock goal → plan cycle → tmux Codex builders → integrator → verify → research/council → next cycle`

This is the Codex-native entrypoint. Shared deterministic helpers live in `scripts/`.
Do not import Claude Code assumptions, commands, models, memory, or skills.

## Non-negotiable runtime

- Execute every builder and integrator as a real `codex exec` CLI inside the tmux
  session created by `scripts/polylane-supervisor.sh`.
- Never substitute Codex app collaboration agents, subagents, background tasks, or
  prose-only simulation for the tmux Codex CLI lanes.
- Every launched Codex CLI has multi-agent/fan-out features disabled mechanically.
  A builder or integrator is one process for one lane and never spawns another
  agent inside itself.
- Keep one canonical project folder. Lane worktrees are scratch and are promoted
  only through the verified integrator branch.
- While tmux is active, surface exactly the one line printed by:

  ```bash
  scripts/polylane-cycle.sh runtime .polylane/run.json
  ```

  It must look like `tmux attach -t <session>`. Do not claim a watch command when
  the runtime check fails.
- Run through the supervisor, not the runner directly:

  ```bash
  POLYLANE_AUTONOMOUS=1 scripts/polylane-supervisor.sh .polylane/run.json
  ```

- Default fast cadence: poll every 2 seconds, health-check every 15 seconds,
  seed verification after 2 seconds, supervisor tick every 5 seconds. A
  shell-only frozen pane is recovered after about 60 seconds; a confirmed live
  Codex turn gets a bounded five-minute quiet window so long inference and
  verification cannot destroy an expensive context.

## Stop contract

Do not send a final answer or become idle at a cycle boundary, council verdict,
GO, NO-GO, digest, research result, suggestion packet, or arbitrary cycle/budget
count. Those are routing inputs.

After every material action run:

```bash
scripts/polylane-cycle.sh route docs/polylane/max-state.json
```

Interpret the result mechanically:

- `CONTINUE <subgoal>`: create and launch the next cycle immediately.
- `COMPLETE`: allowed only after requested work, frozen acceptance, terminal
  tests, shippability, and the perfection pass are all green.
- `NEEDS-USER`: ask only for the exact core decision, secret, money commitment,
  inaccessible account, hardware/physical action, or manual evidence that remains.
  Continue every independent autonomous subgoal before asking.
- `DEAD-END` or `INCOMPLETE`: repair the goal tree, acceptance, evidence, or
  cycle plan. This is not permission to stop.

An integrator `NO-GO` launches an autonomous integrator repair wave. A verified
`EXTERNAL-EVIDENCE-OPEN` promotes engineering work and routes around the external
item. The supervisor resumes HALTED/crashed runners. Exhaust safe retries and
different approaches before exposing a genuine user blocker.

The loop may run for hours or days. State and evidence on disk—not the chat
transcript—must be sufficient to resume it.

## Entry and goal lock

Set:

```bash
PL="$(cd "$(dirname "$(command -v polylane-run.sh 2>/dev/null || printf '%s' scripts/polylane-run.sh)")" && pwd)"
MEM="$PL/polylane-memory.sh"
STATE=docs/polylane/max-state.json
```

If `$STATE` exists, read `"$MEM" "$STATE" resume` and continue it. Do not repeat
discovery or discard accepted decisions.

For a new prompt:

1. Inspect the repo, `AGENTS.md`, current build/test commands, git status, and
   relevant product docs.
2. If the request is vague, ask concise recommended-default questions only for
   choices that materially change the product. Research missing facts. Core
   product decisions remain user-owned; routine implementation choices do not.
3. Write:
   - `docs/polylane/NORTHSTAR.md`
   - `docs/polylane/STRATEGY.md`
   - `docs/polylane/ULTIMATE_GOAL.md`
   - `docs/polylane/INDEX.md`
4. Initialize `$STATE` with measurable criteria, milestones, and weighted
   subgoals. Register frozen graders before builders start:

   ```bash
   "$MEM" "$STATE" init "<locked goal>"
   "$MEM" "$STATE" add-criterion c1 "<measurable criterion>" 10
   "$MEM" "$STATE" add-milestone m1 "<milestone>"
   "$MEM" "$STATE" add-subgoal m1 m1.1 "<observable outcome>" 10
   "$MEM" "$STATE" add-accept m1.1 '<focused executable check>'
   "$MEM" "$STATE" add-accept m1.1 '<full terminal check>' --tier terminal
   ```

Every subgoal needs at least one focused executable check. Use a small number of
terminal checks for expensive full-suite, signed-build, end-to-end, accessibility,
or package verification. Never replace an external/manual requirement with `true`.

Statuses are `open`, `doing`, `done`, `external`, or `blocked`. `external` means
the system cannot produce the evidence; it does not erase or pass the criterion.

## Cycle protocol

### 1. Rehydrate and select

Read only the bounded packet and relevant durable files:

```bash
"$MEM" "$STATE" brief
cat docs/polylane/NORTHSTAR.md
```

Select the highest-weight `doing`/`open` subgoal from `"$MEM" "$STATE" next`.
Write `docs/polylane/cycle-<N>-plan.md` with the observable target, frozen checks,
ownership, dependencies, and risks. Mark routed targets `doing`.

Do not spend a wave on research that a cheap read-only check can answer. Do not
repeat an approach already recorded by `"$MEM" "$STATE" attempted`.

### 2. Derive the smallest safe lane set

Read `references/lane-derivation.md` and `references/planning.md`. Use the fewest
builders that provide real concurrency. Every builder gets disjoint non-empty
`own_globs`; shared APIs are frozen in prompts. Run:

```bash
scripts/polylane-scope.sh check-static .polylane/run.json
```

One lane is correct when the work overlaps heavily. Never create idle lanes merely
to appear parallel.

### 3. Arm every builder with skills

Create `.polylane/lane-skills.json` in structured v2 form. Each builder receives:

- at least two predefined, installed execution/testing skills;
- at least two installed skills chosen for that lane’s actual domain and work.

Use:

```bash
scripts/polylane-scout.sh arm-role .polylane/lane-skills.json <lane> predefined <skill> <skill>
scripts/polylane-scout.sh arm-role .polylane/lane-skills.json <lane> specific <skill> <skill>
scripts/polylane-scout.sh validate .polylane/lane-skills.json .polylane/run.json
```

The GitHub skills suggester proposes potentially useful skills after each cycle:
`polylane-scout.sh github-suggest "<activity>" 5`. Record reviewed candidates with
`polylane-scout.sh github`; they are informational only.
Do not install, invoke, or count a suggestion until it is actually installed.

### 4. Generate strict Codex prompts

Each prompt is self-contained and must include:

- project and lane identity;
- `GOAL` copied from the locked cycle plan;
- `OWN` and `FORBIDDEN` globs plus frozen cross-lane contracts;
- `PREDEFINED-SKILLS:` and `LANE-SPECIFIC-SKILLS:` naming every armed skill,
  with an explicit instruction to read and use each skill;
- `TEST-CADENCE:` focused checks while iterating, subsystem checks before DONE,
  and the full terminal suite only at integration/final certification;
- `DELEGATION:` forbidden—no subagents, collaboration agents, or nested fan-out;
- `CHECK-CACHE:` route expensive checks through
  `scripts/polylane-check.sh <canonical-project>/.polylane/check-cache/<lane> -- <command>`;
  reuse unchanged pass/fail results and change source before retrying a failure;
- `EXTERNAL-EVIDENCE:` physical/manual proof stays external while all autonomous
  work continues;
- evidence file `docs/verify-<lane>.md`;
- exact first-line marker `STATUS: <lane> DONE run=<run_id>`;
- terse execution, scoped git staging, no re-scoping, and no idle waiting.

Run both gates:

```bash
POLYLANE_STRICT_PROMPTS=1 scripts/polylane-promptlint.sh lint-run .polylane/run.json
scripts/polylane-scout.sh lint .polylane/lane-skills.json <lane> .polylane/lanes/<lane>.txt
```

The integrator merges current lane tips into its own branch, checks scope and
seams, runs focused failures first, runs the terminal suite at final
certification, and writes exactly one verdict sentinel:

- `POLYLANE-VERDICT: GO run=<run_id>`
- `POLYLANE-VERDICT: EXTERNAL-EVIDENCE-OPEN run=<run_id>`
- `POLYLANE-VERDICT: NO-GO run=<run_id>`

NO-GO must name executable repairs. It is feedback for the runner’s repair loop.
When the current host/account/hardware blocks a required gate before source
execution and no owned source change can alter the result, write
`POLYLANE-REPAIRABLE: NO run=<run_id>` immediately before the NO-GO sentinel.
This is not completion: the runner skips wasteful identical repair waves, and the
outer orchestrator marks that evidence external, routes every other autonomous
subgoal, and asks only when no independent work remains. Never use the marker for
an ordinary source failure, uncertainty, or an inconvenient test.

### 5. Emit contract-v2 manifest and launch

`.polylane/run.json` must include:

```json
{
  "orchestration_contract": 2,
  "run_id": "<fresh nonce>",
  "cycle": 1,
  "state_file": "docs/polylane/max-state.json",
  "lane_skills_file": ".polylane/lane-skills.json",
  "cycle_plan_file": "docs/polylane/cycle-1-plan.md",
  "target_subgoals": ["m1.1"],
  "base": "main",
  "session": "polylane-c1",
  "agent": "codex",
  "codex_sandbox": "workspace-write",
  "available_models": ["<strongest>", "<faster>"],
  "integrator": {
    "name": "integrator",
    "model": "<codex-model>",
    "effort": "xhigh",
    "branch": "lane/integrator",
    "worktree": "<absolute-scratch-path>",
    "prompt_file": ".polylane/lanes/integrator.txt"
  },
  "lanes": [{
    "name": "builder",
    "model": "<codex-model>",
    "effort": "high",
    "branch": "lane/builder",
    "worktree": "<absolute-scratch-path>",
    "prompt_file": ".polylane/lanes/builder.txt",
    "own_globs": ["src/**"],
    "target_subgoals": ["m1.1"]
  }]
}
```

Probe the installed Codex CLI for model ids; never emit Claude model ids. Contract
v2 mechanically rejects missing state, plan, skills, acceptance, prompt blocks,
scope isolation, or prior-cycle closure before tmux opens.

`codex_sandbox` is optional and defaults to `workspace-write`. Set it to
`danger-full-access` only when the task genuinely requires host services and the
user has authorized that access; use `read-only` for observation-only lanes. The
engine validates the value and passes it to every real `codex exec` launch.
`POLYLANE_CODEX_SANDBOX` is the explicit host-level override.

Default Codex policy is `gpt-5.6-terra`/high for builders and routine verification,
with at most one `gpt-5.6-sol` integrator. Use xhigh only when the cross-lane gate
is genuinely complex. If command churn produces no source/evidence progress, the
runner narrows the plan and downgrades model/effort before spending another wave.

Run diagnostics, start the supervisor, then immediately surface the runtime line:

```bash
scripts/polylane-doctor.sh .polylane/run.json
POLYLANE_AUTONOMOUS=1 scripts/polylane-supervisor.sh .polylane/run.json
scripts/polylane-cycle.sh runtime .polylane/run.json
```

Do not block the chat process on the foreground supervisor if that would prevent
monitoring; launch it durably, verify the supervisor PID/heartbeat and tmux panes,
and keep checking state. No live run may exist without an observable runner and
the one-line attach command.

### 6. Close the cycle durably

After promotion, read the run report and current state. Produce:

- `cycle-<N>-digest.md` — commits, diff, tests, evidence, regressions;
- `cycle-<N>-research.md` — only new research that affects the next work;
- `cycle-<N>-council.md` — scored advice against frozen criteria;
- `cycle-<N>-questions.md` — defaults taken and real unresolved core choices;
- `progress.md` — generated by `polylane-cycle.sh`, never hand-maintained;
- `cycle-<N+1>-plan.md` whenever routing continues.

Run:

```bash
scripts/polylane-cycle.sh progress "$STATE" <N>
scripts/polylane-cycle.sh artifacts "$PWD" <N> "$STATE"
```

The council may reprioritize weights or add a new subgoal with frozen acceptance.
It cannot declare completion or stop execution.

In chat, give a short cycle result, the next focus, any informational skill
suggestions, and—while active—the exact tmux attach line. Then continue working.

## Initial-goal suggestions and perfection

When all initially requested subgoals first become verified, do not stop. Generate
`docs/polylane/next-suggestions.md` with exactly 30 concise, non-duplicate bullets:
product gaps, reliability, UX, accessibility, security, performance, packaging,
observability, tests, and maintainability. Validate:

```bash
scripts/polylane-cycle.sh suggestions docs/polylane/next-suggestions.md
```

Suggestions are informational. Without changing a core product decision, select
the highest-leverage suggestions that improve the locked goal, add them as a
`perfection` milestone with frozen acceptance, and continue cycles. Record one
blackboard attempt named `30-suggestion perfection expansion` so this packet is
generated exactly once. Do not silently expand into a different product.

Final `COMPLETE` requires:

- every requested and perfection subgoal `done`;
- every criterion `done`;
- every frozen focused and terminal check `pass`;
- no acceptance regression, unmerged branch, unresolved seam, silent external
  requirement, missing artifact, stale progress file, active runner, or tmux pane;
- installed artifact/package and real user path verified where applicable.

Only then terminate tmux, provide the final result and evidence, and end the task.
