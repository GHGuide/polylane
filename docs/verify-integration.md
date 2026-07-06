# Verify — integrator lane (adaptive-model / intensity feature)

**VERDICT: GO.** 4 lane branch tips re-merged into `main` (0 commits at risk, 0
conflicts); all 5 hard contracts cross-checked with quoted lines from the merged
tree (zero contradiction); runner + probe helper smoke-tested on merged `main`
including the no-API-key fallback. Details below. This is a fresh re-verify of
the current branch HEADs — no prior GO was trusted.

Merged `main` tip at verification: `41e22ca`.
Environment: host bash `3.2.57`; `tmux`, `claude`, `jq`, `git`, `curl` all present;
**no `ANTHROPIC_API_KEY`** set (fallback path exercised for real).

---

## 1. Per-lane merged status (goal 1 — 4 branches merged, 0 at risk)

Pre-merge `main` = `4a97f99`. Each lane = exactly one feat commit ahead, clean
file isolation (no two lanes touch the same file), so all four merged with the
`ort` strategy and **zero conflicts**:

| Lane | Branch | Tip | Merge commit | Files (owned) | In `main`? |
|---|---|---|---|---|---|
| La intensity-model | `lane/intensity-model` | `4b4633b` | `7927634` | `references/model-selection.md` | ✅ 0 at risk |
| Lb planner-wiring | `lane/planner-wiring` | `f8c956f` | `ee89744` | `SKILL.md`, `references/interview.md`, `references/lane-template.md` | ✅ 0 at risk |
| Lc schema-runner | `lane/schema-runner` | `eb5fd72` | `c4c89ab` | `.polylane/SCHEMA.md`, `bin/polylane-run.sh`, `bin/polylane-models.sh` (new) | ✅ 0 at risk |
| Ld runner-docs | `lane/runner-docs` | `b7b8b5f` | `41e22ca` | `polylane-run/SKILL.md`, `references/install-helpers.md` | ✅ 0 at risk |

Ancestry proof (`git merge-base --is-ancestor <tip> HEAD` → true for all four):

```
OK  lane/intensity-model (4b4633b) fully in main — 0 at risk
OK  lane/planner-wiring   (f8c956f) fully in main — 0 at risk
OK  lane/schema-runner    (eb5fd72) fully in main — 0 at risk
OK  lane/runner-docs      (b7b8b5f) fully in main — 0 at risk
```

All four lane DONE markers verified in-branch before merge (first line of each
`docs/status-<lane>.md` = `STATUS: <lane> DONE`).

---

## 2. Cross-check of the 5 hard contracts (goal 2 — each quoted from merged `main`)

### Contract 1 — preset names `economy|balanced|performance|max|custom`

Two deliberate surfaces, each internally consistent; **not drift** — reconciled
explicitly in `SCHEMA.md`.

**Manifest/preset surface = 5-set (incl `custom`):**
- `references/model-selection.md` distinct tokens: `` `balanced` `` `` `custom` `` `` `economy` `` `` `max` `` `` `performance` `` (grep `-oE` unique).
- `SKILL.md:15` — `` ask the ONE intensity question (`economy | balanced | performance | max | custom`, `balanced` recommended) ``
- `SKILL.md:49` — `"intensity": "<economy|balanced|performance|max|custom>",`
- `.polylane/SCHEMA.md:43` — `` `economy` \| `balanced` \| `performance` \| `max` \| `custom`. **Advisory metadata** … ``

**Runtime `--intensity` flag surface = 4-set (`custom` excluded by design):**
- `bin/polylane-run.sh:33` — `[--intensity <economy|balanced|performance|max>]`
- `bin/polylane-run.sh:237` — `unknown --intensity '$INTENSITY' (want economy|balanced|performance|max)`
- `polylane-run/SKILL.md:87` — `` ### `--intensity <economy|balanced|performance|max>` — remap the whole run ``

**Reconciliation (single source of truth), `.polylane/SCHEMA.md:103-104`:**
> `custom` is a manifest `intensity` value only (hand-tuned, no remap) — it is
> **not** a valid `--intensity` CLI argument.

Operationally confirmed: `bin/polylane-run.sh sample.json --dry-run --intensity custom`
→ `polylane-run: unknown --intensity 'custom' (want economy|balanced|performance|max)`,
exit 2, no split. **PASS.**

### Contract 2 — manifest keys `intensity` / `available_models` / per-lane `effort`

Identical key names in Lc's `.polylane/SCHEMA.md` and Lb's `SKILL.md` Phase 6 emit:

- `.polylane/SCHEMA.md:43` `` | `intensity` | string | … ``
- `.polylane/SCHEMA.md:44` `` | `available_models` | string[] | … ``
- `.polylane/SCHEMA.md:57` `` | `effort` | string | … Surfaced to the pane as the `POLYLANE_EFFORT` env var … ``
- `SKILL.md:49` `"intensity": "<economy|balanced|performance|max|custom>",`
- `SKILL.md:50` `"available_models": ["<model id>", "..."],`
- `SKILL.md` Phase 6 JSON carries `"effort"` on the integrator object and on each lane object (same lines as `"model"`).
- `SKILL.md:88` non-negotiable — `` frozen schema: `base` · `intensity` · `available_models[]` · `integrator{name,model,effort,…}` · `lanes[]{name,model,effort,…}` … New keys (`intensity`, `available_models`, per-object `effort`) match Lc's `.polylane/SCHEMA.md`. ``

**PASS** (key names identical). Non-blocking note logged in §4.

### Contract 3 — CLI flags `--intensity` / `--model` spelled identically

- `bin/polylane-run.sh:33` — `[--intensity <economy|balanced|performance|max>]`
- `bin/polylane-run.sh:34` — `[--model <lane=model_id>]...`
- `polylane-run/SKILL.md:87` — `` ### `--intensity <economy|balanced|performance|max>` — remap the whole run ``
- `polylane-run/SKILL.md:96` — `` ### `--model <lane=model_id>` — override a single lane ``
- `references/install-helpers.md:37` — `` The runner's model controls (`--intensity` / `--model`, documented in … ``

Spellings match byte-for-byte across runner + docs. **PASS.**

### Contract 4 — probe helper name `bin/polylane-models.sh` consistent

- File present on merged `main`: `bin/polylane-models.sh` (executable, 65 lines).
- `.polylane/SCHEMA.md:44` — `` typically the output of `bin/polylane-models.sh` ``
- `.polylane/SCHEMA.md:113` — `` ## Model probe helper — `bin/polylane-models.sh` ``
- `references/install-helpers.md:39,41` — `` `bin/polylane-models.sh` … probes the Anthropic API … ``

**PASS.**

### Contract 5 — existing contracts unchanged (base CLI, DONE marker, mandatory-4)

- **Base CLI** — `bin/polylane-run.sh:14,32` `bin/polylane-run.sh <manifest.json> [--dry-run] [--yes]`; `polylane-run/SKILL.md:113-114` — `` These flags are additive — the base CLI (`<manifest> [--dry-run] [--yes]`) is unchanged. `` New flags are additive; baseline (no flags) dry-run reproduces the manifest values unchanged (§3 smoke 4).
- **DONE marker** — `SKILL.md:38` — `` each lane writes `docs/status-<lane>.md` whose FIRST LINE is exactly `STATUS: <lane> DONE` `` (also `SKILL.md:86`). Unchanged.
- **Mandatory-4 preamble** — `SKILL.md:36` and `SKILL.md:79` — `` `/graphify-auto` · caveman (full) · `/goal <lane goal>` · `superpowers:using-superpowers` `` in order. Unchanged.

**PASS.**

**No cross-lane contradiction found → no `SKILL.md` fix applied.**

---

## 3. Smoke tests on merged `main` (goal 3)

**Syntax — `bash -n` both scripts:**
```
run.sh: syntax OK
models.sh: syntax OK
```

**Probe helper, no `ANTHROPIC_API_KEY` → curated fallback (real, key absent):**
```
$ env -u ANTHROPIC_API_KEY bash bin/polylane-models.sh
claude-fable-5
claude-opus-4-8
claude-sonnet-5
claude-haiku-4-5
[exit=0]
```

**Schema example validates with `jq` (first ```json``` block in SCHEMA.md):**
```
SCHEMA example: VALID JSON
new fields present: intensity, available_models, lane.effort, integrator.effort
```

**Sample manifest** (2 lanes `api`=sonnet/medium, `ui`=fable/low + integrator
opus/high; `available_models`=all four; `intensity`=balanced).

Baseline `--dry-run` — unchanged, no real pane (dry `+ tmux` / `+ (dry-run) poll`):
```
lane api: model=claude-sonnet-5 effort=medium
+ tmux new-session -d -s polylane -n api
lane ui: model=claude-fable-5 effort=low
+ (dry-run) would poll for DONE: api:../polylane-api ui:../polylane-ui
lane integrator: model=claude-opus-4-8 effort=high
```

`--dry-run --intensity economy` — all lanes + integrator remap to haiku/low
(economy ladder `haiku→fable→sonnet→opus`, all available → haiku); 8 dry `+ tmux`
lines, **no real launch**:
```
== intensity 'economy' -> model=claude-haiku-4-5 effort=low (all lanes + integrator) ==
lane api: model=claude-haiku-4-5 effort=low
lane ui: model=claude-haiku-4-5 effort=low
lane integrator: model=claude-haiku-4-5 effort=low
```

`--dry-run --model api=claude-opus-4-8` — single-lane override, others untouched:
```
== model override: api -> claude-opus-4-8 ==
lane api: model=claude-opus-4-8 effort=medium
lane ui: model=claude-fable-5 effort=low
lane integrator: model=claude-opus-4-8 effort=high
```

Effort reaches the pane command:
```
POLYLANE_EFFORT='low' claude --model 'claude-haiku-4-5'
```

Guards (abort in `apply_overrides`, before `split_worktrees` — nothing launched):
```
$ … --intensity custom   → unknown --intensity 'custom' (want economy|balanced|performance|max)   [exit=2, no split]
$ … --model backend=…     → --model names unknown lane 'backend' (not a lane or the integrator)     [exit=2, no split]
```

All smoke tests + guards **pass**.

---

## 4. Missing / unverified / regressed

- **Regressed:** none. Baseline (no-flag) dry-run reproduces manifest values
  unchanged; `bash -n` clean on both scripts.
- **Missing:** none against the locked goal.
- **Non-blocking note (not one of the 5 enforced contracts):** the `SKILL.md`
  Phase 6 JSON `effort` placeholder reads `<low|medium|high|xhigh>` while
  `.polylane/SCHEMA.md:57` lists `low | medium | high | xhigh | max`. The **key
  name** (`effort`) is identical — the contract is satisfied. Only the
  illustrative enum in the placeholder under-lists `max` (which the `--intensity
  max` preset resolves to at runtime, `bin/polylane-run.sh:202`). Cosmetic doc
  under-spec in a placeholder; not a cross-lane contradiction, so left unchanged
  per minimal-edit scope. Recorded here only — no `SKILL.md` fix and no
  `docs/parallel-status.md` entry, since no contract mismatch was found.

---

## Verdict

**GO.** 4 branches merged (0 at risk), 5 contracts evidenced with quoted lines
(zero contradiction), runner + probe helper smoke-tested on merged `main`
including the no-key fallback. Proceed to merge-finalize + scratch cleanup
(remove 4 lane worktrees + branches, drop `docs/status-*.md` scratch, keep
`docs/verify-*.md` + `docs/parallel-status.md`).
