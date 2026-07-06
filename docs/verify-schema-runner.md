# verify-schema-runner.md — evidence for the schema-runner lane

Lane: **schema-runner**. Owns `.polylane/SCHEMA.md`, `bin/polylane-run.sh`,
`bin/polylane-models.sh`. Scope: 3 new manifest fields (`intensity`,
`available_models`, per-lane `effort`) + 2 runtime flags (`--intensity`,
`--model`) + a model-probe helper. Nothing else.

Built TDD (RED→GREEN): a sourced-function suite for the run.sh override engine
(24 assertions) and a no-key fallback suite for the probe helper (8 assertions).
Both started RED (functions/file absent) and are GREEN below. Host bash is
`3.2.57` — the code is 3.2-safe (no `mapfile`/associative arrays). Every block
below is real command output from this worktree.

---

## Goal 0 — syntax: `bash -n` on both scripts

```
$ bash -n bin/polylane-run.sh    && echo OK   → OK
$ bash -n bin/polylane-models.sh && echo OK   → OK
```

## Goal 2 — `bin/polylane-models.sh` probe with graceful fallback

There is **no** `ANTHROPIC_API_KEY` in this environment, so the fallback path is
the one exercised. Prints one id per line, exit 0:

```
$ env -u ANTHROPIC_API_KEY bash bin/polylane-models.sh
claude-fable-5
claude-opus-4-8
claude-sonnet-5
claude-haiku-4-5
[exit=0]
```

The suite also confirms an empty-string key (`ANTHROPIC_API_KEY=""`) takes the
same fallback path (8/8 assertions GREEN). With a key present the helper runs
`curl -s --fail https://api.anthropic.com/v1/models -H "x-api-key: …"
-H "anthropic-version: 2023-06-01" | jq -r '.data[].id'`; any HTTP/network
error or empty result falls back to the curated list.

## Goal 1 — SCHEMA.md documents the new fields/flags/helper; example validates with jq

The first ```json``` block in `.polylane/SCHEMA.md`, extracted and validated:

```
$ awk '/^```json$/{f=1;next} /^```$/{if(f)exit} f' .polylane/SCHEMA.md | jq empty && echo VALID
VALID JSON (exit 0)

$ … | jq -e '.intensity and (.available_models|length>0) and .lanes[0].effort and .integrator.effort'
new fields present: intensity, available_models, lane.effort, integrator.effort
```

SCHEMA.md documents: the 3 fields (keys tables), the 2 flags (CLI table), the
`## Intensity presets` resolution table (preset → effort + model ladder), and
the `## Model probe helper` section.

## Goal 3 — `--intensity` / `--model` remap correctly; existing behavior unchanged

Fixture: 2 lanes (`api`=sonnet/medium, `ui`=fable/low) + integrator
(opus/high), `available_models` = all four ids.

**Baseline (no flags) — unchanged:**

```
$ bin/polylane-run.sh fixture.json --dry-run
lane api: model=claude-sonnet-5 effort=medium
lane ui: model=claude-fable-5 effort=low
lane integrator: model=claude-opus-4-8 effort=high
```

(The pane command sent to tmux is byte-identical to the pre-change version when
effort is empty — asserted by `pane_cmd empty-effort == legacy` in the suite.)

**`--intensity max` — every lane + integrator → opus / max:**

```
$ bin/polylane-run.sh fixture.json --dry-run --intensity max
== intensity 'max' -> model=claude-opus-4-8 effort=max (all lanes + integrator) ==
lane api: model=claude-opus-4-8 effort=max
lane ui: model=claude-opus-4-8 effort=max
lane integrator: model=claude-opus-4-8 effort=max
```

**`--model ui=claude-opus-4-8` — single lane override, others untouched:**

```
$ bin/polylane-run.sh fixture.json --dry-run --model ui=claude-opus-4-8
== model override: ui -> claude-opus-4-8 ==
lane api: model=claude-sonnet-5 effort=medium
lane ui: model=claude-opus-4-8 effort=low
lane integrator: model=claude-opus-4-8 effort=high
```

**`--intensity economy --model integrator=claude-opus-4-8` — override wins:**

```
$ bin/polylane-run.sh fixture.json --dry-run --intensity economy --model integrator=claude-opus-4-8
== intensity 'economy' -> model=claude-haiku-4-5 effort=low (all lanes + integrator) ==
== model override: integrator -> claude-opus-4-8 ==
lane api: model=claude-haiku-4-5 effort=low
lane ui: model=claude-haiku-4-5 effort=low
lane integrator: model=claude-opus-4-8 effort=low
```

**Effort reaches the pane** (grep of the dry-run `tmux send-keys` line):

```
$ bin/polylane-run.sh fixture.json --dry-run --intensity max | grep -o "POLYLANE_EFFORT='max' claude --model 'claude-opus-4-8'"
POLYLANE_EFFORT='max' claude --model 'claude-opus-4-8'
```

## Goal 4 — guards: clean error + non-zero exit, no panes launched

Each aborts in `apply_overrides`, which runs before `split_worktrees`, so
`== split` never prints (⇒ no worktree, no pane):

```
$ … --intensity turbo
polylane-run: unknown --intensity 'turbo' (want economy|balanced|performance|max)
[exit=2]  OK: no split

$ … --intensity max   (manifest with available_models=[])
polylane-run: --intensity needs a non-empty "available_models" in <manifest>
[exit=1]  OK: no split

$ … --model backend=claude-opus-4-8
polylane-run: --model names unknown lane 'backend' (not a lane or the integrator)
[exit=2]  OK: no split

$ … --model justname
polylane-run: malformed --model 'justname' (want lane=model_id)
[exit=2]
```

## Test suites (TDD, sourced functions)

```
== models: 8 passed, 0 failed ==
== run:   24 passed, 0 failed ==
```

Covered: `preset_effort` (4 presets + unknown→rc1), `preset_model` (ladder pick
+ single-available + unknown-only graceful fallback), `apply_overrides`
(intensity remap, model override wins, integrator override, no-flag no-op), all
four guards, `pane_cmd` effort prefix + legacy equality, `parse_args` collection
of `--intensity`/`--intensity=`/repeatable `--model`/missing-value.

Suites live in the session scratchpad (not repo files); this doc is the evidence
of record.

---

VERDICT: schema-runner GO — schema fields + both flags + probe helper + guards
all verified with the command output above.
