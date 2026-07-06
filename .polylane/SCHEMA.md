# .polylane/SCHEMA.md — manifest + engine contract

Frozen contract for `bin/polylane-run.sh`. Generators (the `polylane` skill) write
`.polylane/run.json` to this shape; the engine reads it. **Do not rename keys** —
lanes L2/L3/L4 depend on them.

---

## Manifest: `.polylane/run.json`

```json
{
  "base": "main",
  "intensity": "balanced",
  "available_models": ["claude-fable-5", "claude-opus-4-8", "claude-sonnet-5", "claude-haiku-4-5"],
  "integrator": {
    "name": "integrator",
    "model": "claude-opus-4-8",
    "branch": "lane/integrator",
    "worktree": "../pl-integrator",
    "prompt_file": ".polylane/prompts/integrator.txt",
    "effort": "high"
  },
  "lanes": [
    {
      "name": "api",
      "model": "claude-opus-4-8",
      "branch": "lane/api",
      "worktree": "../pl-api",
      "prompt_file": ".polylane/prompts/api.txt",
      "own_globs": ["backend/api/**"],
      "effort": "high"
    }
  ]
}
```

### Keys

| Key | Type | Meaning |
|---|---|---|
| `base` | string | Branch each lane/integrator worktree is created from (e.g. `main`). |
| `intensity` | string | *(optional)* Preset the generator tuned this manifest for: `economy` \| `balanced` \| `performance` \| `max` \| `custom`. **Advisory metadata** — records provenance; the per-lane `model`/`effort` are already baked to match it. The engine does **not** re-resolve from this at runtime; use the `--intensity` flag to remap live. `custom` = hand-tuned, no preset. |
| `available_models` | string[] | *(optional)* Model ids the `--intensity` flag resolves against (typically the output of `bin/polylane-models.sh`). Required only if you pass `--intensity`; empty/absent then → error. |
| `integrator` | object | The lane that runs **last**: merges lane branches, writes the verdict. |
| `lanes[]` | array | One object per parallel builder. |

Each **lane** object (and the **integrator** object) has:

| Key | Type | Meaning |
|---|---|---|
| `name` | string | Lane id. Used in the DONE file name and tmux window name. Keep it filesystem-safe. |
| `model` | string | Model id passed to `claude --model` (e.g. `claude-opus-4-8`, `claude-fable-5`). |
| `branch` | string | Branch created for this lane (`git worktree add -b <branch> <base>`). |
| `worktree` | string | Path of the lane's git worktree. Relative paths resolve from the repo root. |
| `prompt_file` | string | File whose contents seed the lane's `claude` pane. Read at pane runtime. |
| `effort` | string | *(optional)* Reasoning effort for this lane: `low` \| `medium` \| `high` \| `xhigh` \| `max`. Surfaced to the pane as the `POLYLANE_EFFORT` env var and printed at launch. Absent → unset (no behavior change; the legacy pane command is reproduced byte-for-byte). |
| `own_globs` | string[] | *(lanes only)* Files the lane owns. Informational — the engine does not enforce it. |

---

## CLI

```
bin/polylane-run.sh <manifest.json> [--dry-run] [--yes]
                    [--intensity <economy|balanced|performance|max>]
                    [--model <lane=model_id>]...
```

| Arg / flag | Effect |
|---|---|
| `<manifest.json>` | Path to the manifest. **Required** — missing → exit 2. |
| `--dry-run` | Print every git/tmux command without executing. Nothing is created, launched, or deleted. |
| `--yes` | Skip the final delete-confirmation prompt. |
| `--intensity <preset>` | Remap **every** lane **and** the integrator to the preset's model + effort (see *Intensity presets* below). The model is resolved against `available_models`. `--intensity=<preset>` form also accepted. Applied before any worktree/pane exists. |
| `--model <lane=model_id>` | Override **one** lane's (or the integrator's) `model`, matched by `name`. **Repeatable.** Applied *after* `--intensity`, so a per-lane override always wins. `--model=<lane=id>` form also accepted. |
| `-h`, `--help` | Print usage, exit 0. |

Both overrides are applied **before** any worktree or pane is created; a bad
value aborts with nothing created or launched.

Exit codes: `0` success · `1` preflight / gate / conflict failure, or `--intensity` with an empty/absent `available_models` · `2` bad arguments, including an unknown `--intensity` value, a malformed `--model` (not `lane=model_id`), or a `--model` naming an unknown lane.

Environment: `POLYLANE_POLL_INTERVAL` — seconds between DONE-file polls (default `15`).

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
STATUS: <name> DONE
```

The poller checks each lane's own worktree at `<worktree>/docs/status-<name>.md`
and treats the lane as done only when that first line matches. Anything else
(missing file, DONE on a later line, different text) = not done.

The integrator uses the same convention: `docs/status-<integrator.name>.md`.

---

## Verdict file

The integrator writes `<integrator.worktree>/docs/verify-integration.md`, ending
in an explicit verdict line:

- `... GO` → engine proceeds to the confirm + cleanup step.
- `... NO-GO` → engine stops, prints the verdict, exits non-zero, **deletes nothing**.

Parsing takes the last line containing `GO`/`NO-GO`; `NO-GO` wins ties; an absent
or unrecognised verdict is treated as **not GO** (safe default).

---

## Lifecycle

```
parse args → preflight (tmux, claude, jq, git + valid JSON)
  → split: git worktree add per lane (idempotent; skips existing)
  → launch: tmux session 'polylane', one seeded claude pane per lane
  → poll: until every <worktree>/docs/status-<name>.md first line == DONE
  → integrator: its own worktree + seeded pane; poll its DONE
  → gate: GO required in verify-integration.md, else stop (exit 1)
  → assert no unmerged paths (conflict → exit 1, worktrees intact)
  → cleanup: one confirm (unless --yes) → git worktree remove --force,
             git branch -d (merged only), rm .polylane + docs/status-*.md
```

### Pane command

Each pane runs (prompt read at pane runtime, with a clipboard fallback if the
seed fails):

```sh
cd '<worktree>' && claude --model '<model>' "$(cat '<prompt_file>')" \
  || { pbcopy < '<prompt_file>' 2>/dev/null \
       || xclip -selection clipboard < '<prompt_file>' 2>/dev/null; \
       echo 'SEED FAILED — prompt copied to clipboard; paste it into claude'; \
       claude --model '<model>'; }
```

---

## Dependencies

| Tool | Used for |
|---|---|
| `tmux` | session `polylane`, one pane per lane + integrator |
| `claude` | the builder / integrator agents |
| `jq` | parsing the manifest |
| `git` | worktree split, branch create, merge-branch cleanup |

`pbcopy` (macOS) or `xclip` (Linux) are optional — only used by the seed-failure
clipboard fallback. `curl` is optional and used only by `bin/polylane-models.sh`
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
