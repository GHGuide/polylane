# Verify — planner-wiring lane

Evidence for the LOCKED goal: planner asks intensity + detects models, resolves per-lane model/effort from the preset against `available_models` (per La's rank map), allows per-lane override at the plan gate, emits the new manifest fields. Nothing else.

Frozen contract honored: presets `economy | balanced | performance | max | custom`; manifest additions global `intensity`, global `available_models[]`, per-object `effort`; mandatory-4 preamble order unchanged. La's `model-selection.md` rank map referenced, not redefined (FORBIDDEN). Lc's `.polylane/SCHEMA.md` key names matched.

---

## 1. Intensity question + optional model step + default probe path (goal 1)

`references/interview.md` — new section "Intensity + model availability (ask once, early)":

> 1. **Intensity — one question.** "How hard should the fleet run?" with these presets, recommended FIRST:
>    - `balanced (Recommended)` — Opus-high builders, the default fleet.
>    - `economy` … `performance` … `max` … `custom` …
>    The answer becomes the global **`intensity`** (one of `economy | balanced | performance | max | custom`) …

Optional model step + default probe path:

> 2. **Which models do you have — optional.** … Sets the global **`available_models`** list …
>    - **Default probe path:** don't require a live API call. If the user skips this, assume the standard install trio from `references/model-selection.md` is available — `["claude-fable-5","claude-opus-4-8","claude-haiku-4-5"]`. …

`SKILL.md` Phase 1 (line 15):

> … In an early round also ask the ONE intensity question (`economy | balanced | performance | max | custom`, `balanced` recommended) and the optional "which models do you have" step — default probe = assume the `model-selection.md` trio available. These set the global `intensity` + `available_models` consumed in Phase 4.

## 2. Phase 4b resolution (goal 2)

`SKILL.md` Phase 4, model bullet (line 29):

> - Per-lane model + effort: resolve each lane from the chosen `intensity` preset against `available_models` using the rank map in `references/model-selection.md` … When a preset's ideal model isn't in `available_models`, degrade gracefully to the best available rank. If `intensity` = `custom`, skip auto-resolution — the user sets model + effort per lane at the Phase 5 gate.

Rank map is referenced (in `model-selection.md`, owned by La), not redefined here.

## 3. Phase 5 per-lane override (goal 3)

`SKILL.md` Phase 5 (line 33):

> … The model+effort column is the value **resolved from the `intensity` preset** in Phase 4 (or the user's picks when `intensity` = `custom`). Before approving, the user may override ANY single lane — bump it up or drop it down (model and/or effort), independent of the global preset. Apply the overrides, re-present the table, then take the batched approval. …

## 4. Phase 6 emit new keys (goal 4)

`SKILL.md` Phase 6 manifest JSON (lines 47–66) now emits global `intensity` (49), `available_models` (50), and `effort` on the integrator (54) + each lane (63). Non-negotiable bullet (line 88):

> - Phase 6 emits `.polylane/run.json` (frozen schema: `base` · `intensity` · `available_models[]` · `integrator{name,model,effort,branch,worktree,prompt_file}` · `lanes[]{name,model,effort,branch,worktree,prompt_file,own_globs}`) … New keys (`intensity`, `available_models`, per-object `effort`) match Lc's `.polylane/SCHEMA.md`.

JSON validity (placeholders substituted, run this session):

```
SKILL.md block#0: JSON OK  globals+=['available_models','intensity']  lane.effort=True  integrator.effort=True  -> PASS
references/lane-template.md block#0: JSON OK  globals+=['available_models','intensity']  lane.effort=True  integrator.effort=True  -> PASS
```

Note: `effort` is applied to the integrator object as well as every lane, exactly as `model` already is — consistent with Lc's `.polylane/SCHEMA.md` statement "each lane object (and the integrator object) has" the same per-object keys. No new key *name* invented.

## 5. lane-template consistent (goal 5)

`references/lane-template.md` launch note (line 9):

> … `<MODEL_ID>` (`claude-fable-5` or `claude-opus-4-8`) and the lane's effort both come from the Phase 4 resolution of the `intensity` preset against `available_models` per model-selection.md — or the user's Phase 5 per-lane override. …

Embedded manifest JSON (lines 40–45) carries the same new keys; prose (line 48) explains `intensity` / `available_models` / per-object `effort`, matching Lc's `.polylane/SCHEMA.md`.

## 6. Consistency + preamble intact (goal 6)

Preset names spelled identically across all three touched files (`economy | balanced | performance | max | custom`); `intensity` / `available_models` / `effort` used consistently — see grep output below. No misspellings found.

Mandatory-4 preamble order UNCHANGED — `SKILL.md:36`, `SKILL.md:79`, `lane-template.md:15` all read `/graphify-auto · caveman(full) · /goal · superpowers:using-superpowers`; block A→J order at `lane-template.md:110` unchanged.

`references/lane-derivation.md` deliberately NOT modified — unrelated to intensity/models; leaving it untouched keeps the change minimal (goal says "Nothing else").

### Fresh grep evidence
```
$ grep -rnE "economy ?\| ?balanced ?\| ?performance ?\| ?max ?\| ?custom" SKILL.md references/interview.md references/lane-template.md
SKILL.md:15  (Phase 1)      economy | balanced | performance | max | custom
SKILL.md:49  (Phase 6 JSON) <economy|balanced|performance|max|custom>
references/interview.md:30                 economy | balanced | performance | max | custom
references/lane-template.md:40 (JSON)      <economy|balanced|performance|max|custom>

$ grep -c preamble-order  (graphify-auto · caveman · /goal · using-superpowers)
SKILL.md:36, SKILL.md:79, lane-template.md:15 — all present, order unchanged
```

## Scope guard
- Edited ONLY owned files: `SKILL.md`, `references/interview.md`, `references/lane-template.md`. (`references/lane-derivation.md` in-scope-to-own but no edit needed.)
- Did NOT touch FORBIDDEN: `references/model-selection.md`, `.polylane/**`, `bin/**`, `polylane-run/**`, `README.md`, `assets/**`, `evals/**`.
- Pre-existing `.polylane/lanes` vs `.polylane/prompts` prompt_file path mismatch left as-is (out of scope).
