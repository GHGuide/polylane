# .polylane/SCHEMA.md — manifest + engine contract

Frozen contract for `bin/polylane-run.sh`. Generators (the `polylane` skill) write
`.polylane/run.json` to this shape; the engine reads it. **Do not rename keys** —
lanes L2/L3/L4 depend on them.

---

## Manifest: `.polylane/run.json`

```json
{
  "orchestration_contract": 2,
  "prime_hybrid": true,
  "run_id": "cycle-7-unique-nonce",
  "cycle": 7,
  "state_file": "docs/polylane/max-state.json",
  "lane_skills_file": ".polylane/lane-skills.json",
  "cycle_plan_file": "docs/polylane/cycle-7-plan.md",
  "target_subgoals": ["m2.3"],
  "base": "main",
  "session": "polylane-c7",
  "intensity": "balanced",
  "agent": "codex",
  "codex_profile": "lean",
  "codex_sandbox": "workspace-write",
  "prompt_token_budget": 8000,
  "prompt_byte_budget": 32768,
  "available_models": ["gpt-5.6-sol", "gpt-5.6-terra"],
  "integrator": {
    "name": "integrator",
    "model": "gpt-5.6-sol",
    "branch": "lane/integrator",
    "worktree": "../pl-integrator",
    "prompt_file": ".polylane/prompts/integrator.txt",
    "effort": "high"
  },
  "lanes": [
    {
      "name": "api",
      "model": "gpt-5.6-terra",
      "branch": "lane/api",
      "worktree": "../pl-api",
      "prompt_file": ".polylane/prompts/api.txt",
      "own_globs": ["backend/api/**"],
      "target_subgoals": ["m2.3"],
      "effort": "high"
    }
  ]
}
```

### Keys

| Key | Type | Meaning |
|---|---|---|
| `orchestration_contract` | integer | Set to `2` for reliable Codex runs. Enables pre-launch gates for state, plans, prompts, skills, scope, acceptance, and prior-cycle artifacts. Fresh Codex runs reject legacy manifests unless `POLYLANE_ALLOW_LEGACY=1` is explicitly set for migration. A `--resume` may grandfather a legacy manifest only when it has a non-empty `run_id` and at least one already-materialized lane worktree, preventing an upgrade from stranding real in-flight work without weakening new launches. |
| `prime_hybrid` | boolean | *(optional, default `false`)* Retained-worker and evidence-gated refinement runtime for long product work. Requires contract v2. Before panes open, it initializes canonical `docs/polylane/harness` and `docs/polylane/workers`, validates pending prior-cycle refinements, refreshes the deduplicated propose-or-decline queue, imports the live relay, and creates one bounded `.polylane/context/<lane>.md` per builder and integrator. Legacy manifests are unchanged. |
| `run_id` | string | Fresh per-run nonce baked into every DONE marker and verdict sentinel. |
| `cycle` | integer | Current durable cycle number, starting at 1. |
| `state_file` | string | Durable goal/acceptance state. Must live outside `.polylane/`, normally `docs/polylane/max-state.json`. |
| `lane_skills_file` | string | Structured skill kits. Every builder needs one or two predefined plus one or two lane-specific installed skills, with at most four unique. GitHub suggestions remain informational metadata. |
| `cycle_plan_file` | string | Non-empty current executable cycle plan. |
| `target_subgoals` | string[] | Open/doing frozen-acceptance subgoals executed by this run. The highest-priority `memory next` id must be included. |
| `base` | string | Branch each lane/integrator worktree is created from (e.g. `main`). |
| `session` | string | *(optional, recommended)* Durable tmux session name. When absent, `POLYLANE_SESSION` wins; observers can discover upgraded active runs from tmux ownership tags, then fall back to `polylane`. Use only `A-Za-z0-9._-`. |
| `agent` | string | *(optional, default `claude`)* Which agent CLI each pane launches: `claude` \| `codex`/`gpt` \| `aider`. Env `POLYLANE_AGENT` overrides this; `POLYLANE_AGENT_CMD` (a template with `{model}` and `{prompt}`) overrides both for any other CLI. The pipeline is agent-agnostic (file-based done-signal + verdict); only the launch command differs. For a non-claude agent, the manifest `model` ids and the prompt style must match that agent (see SKILL.md). |
| `codex_sandbox` | string | *(optional, default `workspace-write`)* Sandbox passed mechanically to every Codex lane: `read-only` \| `workspace-write` \| `danger-full-access`. Invalid values abort before tmux opens. `POLYLANE_CODEX_SANDBOX` overrides the manifest for explicit host-level recovery. |
| `codex_profile` | string | *(optional, default `lean`)* `lean` adds `--ephemeral --ignore-user-config`; `user` preserves normal Codex user configuration. |
| `prompt_token_budget` | integer | *(optional, default `8000`)* Maximum whitespace-token estimate admitted by the strict prompt gate before launch. |
| `prompt_byte_budget` | integer | *(optional)* Maximum prompt bytes admitted by the same gate. Absent means no separate byte ceiling. |
| `intensity` | string | *(optional)* Preset the generator tuned this manifest for: `economy` \| `balanced` \| `performance` \| `max` \| `custom`. **Advisory metadata** — records provenance; the per-lane `model`/`effort` are already baked to match it. The engine does **not** re-resolve from this at runtime; use the `--intensity` flag to remap live. `custom` = hand-tuned, no preset. |
| `available_models` | string[] | *(optional)* Model ids the `--intensity` flag resolves against (typically the output of `bin/polylane-models.sh` or the Codex model probe used by the generator). Required only if you pass `--intensity`; empty/absent then → error. Rank strongest first for Codex manifests; when no Claude ladder id matches, presets fall back to this first available id and vary effort. |
| `integrator` | object | The lane that runs **last**: merges lane branches, writes the verdict. |
| `lanes[]` | array | One object per parallel builder. |

Each **lane** object (and the **integrator** object) has:

| Key | Type | Meaning |
|---|---|---|
| `name` | string | Lane id. Used in the DONE file name and tmux window name. Keep it filesystem-safe. |
| `model` | string | Model id passed to the agent's `--model` (e.g. `claude-opus-4-8`, `claude-fable-5`, or `gpt-5-codex` for the codex agent). |
| `branch` | string | Branch created for this lane (`git worktree add -b <branch> <base>`). |
| `worktree` | string | Path of the lane's git worktree. Relative paths resolve from the repo root. |
| `prompt_file` | string | File whose contents seed the lane's selected-agent pane. Read at pane runtime. |
| `effort` | string | *(optional)* Reasoning effort for this lane: `low` \| `medium` \| `high` \| `xhigh` \| `max`. Surfaced to the pane as the `POLYLANE_EFFORT` env var and printed at launch. Absent → unset (no behavior change; the legacy pane command is reproduced byte-for-byte). |
| `own_globs` | string[] | *(lanes only)* Files the lane owns. Contract v2 rejects empty or conservatively overlapping sets before launch. |
| `target_subgoals` | string[] | *(lanes only, contract v2)* The run-level target ids assigned to this builder. Must be non-empty and a subset of the run-level list. |

---

## CLI

```
bin/polylane-run.sh <manifest.json> [--dry-run] [--yes] [--resume] [--push]
                    [--intensity <economy|balanced|performance|max>]
                    [--model <lane=model_id>]...
```

| Arg / flag | Effect |
|---|---|
| `<manifest.json>` | Path to the manifest. **Required** — missing → exit 2. |
| `--dry-run` | Print every git/tmux command without executing. Nothing is created, launched, or deleted. |
| `--yes` | Skip the final delete-confirmation prompt. |
| `--resume` | Skip lanes whose DONE file is already valid (no respawn); launch only the unfinished lanes. Composes with every other flag. |
| `--push` | After a GO verdict + cleanup, `git push` the current branch. |
| `--intensity <preset>` | Remap **every** lane **and** the integrator to the preset's model + effort (see *Intensity presets* below). The model is resolved against `available_models`. `--intensity=<preset>` form also accepted. Applied before any worktree/pane exists. |
| `--model <lane=model_id>` | Override **one** lane's (or the integrator's) `model`, matched by `name`. **Repeatable.** Applied *after* `--intensity`, so a per-lane override always wins. `--model=<lane=id>` form also accepted. |
| `-h`, `--help` | Print usage, exit 0. |

Both overrides are applied **before** any worktree or pane is created; a bad
value aborts with nothing created or launched.

Exit codes: `0` success · `1` preflight / gate / conflict failure, or `--intensity` with an empty/absent `available_models` · `2` bad arguments, including an unknown `--intensity` value, a malformed `--model` (not `lane=model_id`), or a `--model` naming an unknown lane.

Environment: `POLYLANE_POLL_INTERVAL` — DONE-file poll (default `2`) ·
`POLYLANE_SESSION` — tmux session (default `polylane`) ·
`POLYLANE_CODEX_SANDBOX` — explicit Codex sandbox override (`read-only`,
`workspace-write`, or `danger-full-access`) ·
`POLYLANE_HEALTH_INTERVAL` — pane-health sweep (default `15`) ·
`POLYLANE_SEED_VERIFY` — seed check (default `2`) ·
`POLYLANE_SUP_INTERVAL` — supervisor tick (default `5`) ·
`POLYLANE_MAX_RETRIES` — transient retries (default `3`) ·
`POLYLANE_INTEGRATOR_REPAIRS` — verdict repair waves (default `3`).
`POLYLANE_PROGRESS_CHECKS` — unchanged-source health sweeps before a churn replan
(default `12`) · `POLYLANE_PROGRESS_MIN_COMMANDS` — command executions required
before that replan (default `20`) · `POLYLANE_PROGRESS_REPLANS` — narrowed,
model/effort-downgraded replans before a durable `needs-user` stop (default `2`).

Codex panes launch with nested multi-agent and fan-out features disabled. Strict
contract-v2 prompts must include `DELEGATION:` and `CHECK-CACHE:` blocks.
With `prime_hybrid: true`, they must additionally require one read of
`POLYLANE_CONTEXT_PACKET` and durable-inbox follow-ups. The integrator must also
require a propose-or-decline decision for every queued refinement; the runner
rejects a prompt that omits any part of this contract.

---

## Intensity presets

`--intensity <preset>` re-resolves **model + effort** for every lane and the
integrator. Effort is fixed per preset; the model is picked from the manifest's
`available_models` by walking a preference ladder and taking the **first id that
is available**. If none of the ladder is available, it falls back to
`available_models[0]` (graceful — never a model the environment can't serve).

| Preset | effort | Model preference ladder (first available wins) |
|---|---|---|
| `economy` | `low` | `claude-haiku-4-5` → `claude-fable-5` → `claude-sonnet-5` → `claude-opus-4-8` |
| `balanced` | `medium` | `claude-sonnet-5` → `claude-fable-5` → `claude-haiku-4-5` → `claude-opus-4-8` |
| `performance` | `high` | `claude-opus-4-8` → `claude-sonnet-5` → `claude-fable-5` → `claude-haiku-4-5` |
| `max` | `max` | `claude-opus-4-8` → `claude-sonnet-5` → `claude-fable-5` → `claude-haiku-4-5` |

`custom` is a manifest `intensity` value only (hand-tuned, no remap) — it is
**not** a valid `--intensity` CLI argument.

Precedence: `--intensity` remaps all lanes first, then each `--model lane=id`
overrides that single lane's model (effort keeps the preset value). Guards: an
unknown preset, a `--model` for an unknown lane, or `--intensity` against an
empty/absent `available_models` all abort **before** any worktree/pane exists.

---

## Model probe helper — `bin/polylane-models.sh`

Prints the model ids to put in `available_models`, **one id per line**:

```
bin/polylane-models.sh
```

- With `ANTHROPIC_API_KEY` set (and `curl`+`jq` present): probes
  `GET https://api.anthropic.com/v1/models` and prints `.data[].id`.
- On no key, missing tool, network/HTTP failure, or empty result: prints the
  curated fallback list — `claude-fable-5`, `claude-opus-4-8`, `claude-sonnet-5`,
  `claude-haiku-4-5`.

Always prints at least the fallback and exits `0`. The generator (`polylane`
skill) captures its output into the manifest's `available_models`; the engine
itself does not call it.

---

## DONE-file convention

Each lane signals completion by writing:

```
<worktree>/docs/status-<name>.md
```

whose **first line is exactly**:

```
STATUS: <name> DONE run=<run_id>
```

The poller checks each lane's own worktree at `<worktree>/docs/status-<name>.md`
and treats the lane as done only when that first line matches. Anything else
(missing file, DONE on a later line, different text) = not done.

The integrator uses the same convention: `docs/status-<integrator.name>.md`.

---

## Verdict file

The integrator writes `<integrator.worktree>/docs/verify-integration.md`, ending
in exactly one nonce-tagged sentinel on its own line:

- `POLYLANE-VERDICT: GO run=<run_id>` → engineering and autonomous evidence pass.
- `POLYLANE-VERDICT: EXTERNAL-EVIDENCE-OPEN run=<run_id>` → engineering passes;
  only genuinely physical/manual evidence remains. Verified work is promoted and
  the outer cycle routes around the external item.
- `POLYLANE-VERDICT: NO-GO run=<run_id>` → the runner preserves evidence and
  immediately respawns the integrator with a repair prompt. Default repair budget
  is 3 (`POLYLANE_INTEGRATOR_REPAIRS`).

An integrator may add `POLYLANE-REPAIRABLE: NO run=<run_id>` immediately before
NO-GO only when a current host/account/hardware restriction blocks a required
gate before source execution and no owned source change can affect it. The runner
then skips identical repair waves. This does not complete the goal: the outer
orchestrator records the external evidence boundary and routes other autonomous
subgoals.

Prose never counts. Any matching NO-GO wins; a missing, stale-nonce, or malformed
sentinel is `UNKNOWN` and enters the same bounded repair path. A council verdict
outside this file is advisory and cannot terminate a run.

---

## Lifecycle

```
parse args → preflight (jq, git + valid JSON, then manifest-selected agent CLI + tmux)
  → split: git worktree add per lane (idempotent; skips existing)
  → launch: tmux session 'polylane', one seeded selected-agent pane per lane
  → poll: until every <worktree>/docs/status-<name>.md first line == DONE
  → integrator: its own worktree + seeded pane; poll its DONE
  → gate: verified verdict + frozen focused acceptance required
  → NO-GO/UNKNOWN: preserve evidence → integrator repair → gate again
  → final autonomous targets: terminal acceptance suite once
  → assert no unmerged paths (conflict → exit 1, worktrees intact)
  → stamp durable goal state/progress
  → cleanup: one confirm (unless --yes) → git worktree remove --force,
             git branch -d (merged only), rm .polylane + docs/status-*.md
```

### Pane command

Each pane runs the manifest-selected agent profile. For Codex manifests, the
default command is:

```sh
cd '<worktree>' && POLYLANE_EFFORT=<effort> codex exec --json --sandbox <codex_sandbox> \
  -c approval_policy=never -c model_reasoning_effort=<effort> --model '<model>' - < '<prompt_file>'
```

The `POLYLANE_EFFORT=<effort>` prefix appears only when the lane has an
`effort` key. Claude and aider profiles are still supported by setting
`agent: "claude"` or `agent: "aider"`, and any other CLI can be supplied through
`POLYLANE_AGENT_CMD` with `{model}` and `{prompt}` placeholders.

For a prime-hybrid run, the same command additionally exports canonical
`POLYLANE_HARNESS_DIR`, `POLYLANE_WORKERS_DIR`, `POLYLANE_WORKER_ID`, and
`POLYLANE_CONTEXT_PACKET`. The final two are lane-specific; no worker or relay
state is written into the lane worktree.

---

## Dependencies

| Tool | Used for |
|---|---|
| `tmux` | session `polylane`, one pane per lane + integrator |
| selected agent CLI | `codex`, `claude`, or `aider` builders/integrator, unless `POLYLANE_AGENT_CMD` supplies a custom command |
| `jq` | parsing the manifest |
| `git` | worktree split, branch create, merge-branch cleanup |

`curl` is optional and used only by `bin/polylane-models.sh`
to probe the live model list; without it the helper prints its fallback list.

---

## Safety guarantees

- Never `git add -A`; never `git branch -D` (force). Branch deletion uses `git
  branch -d`, which refuses an unmerged branch.
- `rm` only ever touches paths under the repo root (`.polylane/` and
  `docs/status-*.md`); a `safe_rm` guard refuses anything outside it.
- `docs/verify-*.md` and `docs/parallel-status.md` are **kept** — evidence and
  coordination survive cleanup.
- Any unresolved merge conflict aborts with a non-zero exit and leaves all
  worktrees intact.
- Contract v2 runs cannot launch if they have no autonomous route, missing frozen
  acceptance, stale prior-cycle artifacts, empty skill kits, weak prompts, or
  overlapping ownership.
- Prime-hybrid local refinements require repeated observed evidence plus a declared
  bounded expected check, then validate or roll back only in a later cycle. Repeated
  evidence is queued once per observation boundary and must be proposed or explicitly
  declined by the integrator; new evidence can reopen the subject. Global
  prompt/skill records remain inactive handoffs to `bin/polylane-skill-evolve.sh`;
  they never modify a live or installed skill directly.
- Every live supervised tmux run is observable with the exact line returned by
  `bin/polylane-cycle.sh runtime .polylane/run.json`.
