# Verify — lane-derivation + model-selection sharpening

Lane: **derivation**. Owner files: `references/lane-derivation.md`, `references/model-selection.md`.
Model Opus 4.8, HIGH effort. All work verified against the frozen HARD CONTRACT
(IDs `claude-fable-5` / `claude-opus-4-8` / `claude-haiku-4-5`; effort tiers low/medium/high/xhigh) — **unchanged**.

---

## 1. lane-derivation.md — N-procedure now concrete

### BEFORE (single bullet, non-followable)

```
1. **Cluster by file overlap.** Build an item×item matrix: shared files between each pair.
   - Zero overlap → separate clusters (parallel-safe).
   - Heavy overlap (entangled logic, same functions) → SAME lane.
   - Light overlap (1-2 files with a clean interface) → CARVE: one lane owns the shared file; the other gets a HARD CONTRACT (...).
   - Producer/consumer (one item's output feeds another) → SEQUENCE inside one lane, or lane B starts after lane A's contract is published.
```

Problem: says *classify overlaps* but never says **how to turn classifications into a number**. A reader still guesses N.

### AFTER (mechanical: write-sets → matrix → classify → components → N)

```
### Step 1 — Compute N from file overlap

1. **List the work units with their write-sets.** ... Reads don't count — only files a lane would edit can collide ...
2. **Build the overlap matrix.** For every pair (i, j), compute |write-set(i) ∩ write-set(j)| ... symmetric item×item table.
3. **Classify every non-zero cell.** 0 → INDEPENDENT; heavy (>~2 files / same functions) → MERGE; light (1–2 files, clean interface) → CARVE; producer/consumer → SEQUENCE.
4. **Collapse to components — this yields N.** Edge between any two items marked MERGE or SEQUENCE-into-one-lane. **Raw N = the number of connected components.** CARVE does *not* merge lanes.

Then refine N downward with the caps below (caps can only *lower* N, never raise it).
```

Plus a full **worked example** (6 items → overlap matrix → classify → components → Raw N=4 → tiny-lane cap → **N=3 builders + integrator**), with the matrix rendered and every cell value derived from the stated write-sets. A reader can now compute N without guessing — goal 1 met.

Key added invariant: **CARVE keeps two lanes** (contract, not shared ownership) — the prior text left this ambiguous, which is where readers over-merged.

---

## 2. model-selection.md — IDs + pricing confirmed current

Verified against the **claude-api skill** (Current Models table, cached 2026-06-24):

| Model | ID (frozen) | claude-api In/Out | model-selection.md | Match |
|---|---|---|---|---|
| Claude Fable 5 | `claude-fable-5` | $10 / $50 | $10/$50 | ✓ |
| Claude Opus 4.8 | `claude-opus-4-8` | $5 / $25 | $5/$25 | ✓ |
| Claude Haiku 4.5 | `claude-haiku-4-5` | $1 / $5 (200K ctx) | $1/$5 | ✓ |

Effort tiers confirmed real in claude-api: `low` / `medium` / `high` / `xhigh` / `max`. Table uses medium/high/xhigh — all valid, within the frozen tier set. **No pricing number changed. No ID changed.**

Edits (self-consistency only):
- Haiku row now cites its ID: `Claude Haiku 4.5 (`claude-haiku-4-5`)` — previously the only row missing its parenthetical ID while Fable/Opus rows had theirs.
- Provenance note sharpened: "cached table (as of 2026-07 ...)" → "cached table (IDs + pricing confirmed against the claude-api skill 2026-07 ...)".

Preserved verbatim (goal 2 guardrails):
- **"Never Fable on all lanes."** (Hard rules)
- **"Security/anonymity/Tor/anti-censorship/exploit-adjacent lanes → Opus 4.8"** (Fable cyber/bio refusal-classifier stall risk) — this is corroborated by the claude-api skill's Fable 5 `refusal` stop-reason docs (safety classifiers target research bio + most cyber; benign security-adjacent work can false-positive). Rule is well-founded.
- Assignment-rules table kept intact.

---

## 3. Cross-consistency

- lane-derivation.md contains **no** model IDs or effort tiers (pure lane-count/isolation) → cannot contradict model-selection.md.
- model-selection.md IDs + tiers match SKILL.md (`claude-fable-5` / `claude-opus-4-8`; Fable/Opus split). No contradiction. Goal 3 met.

## claude-api facts confirmed
1. Model IDs `claude-fable-5`, `claude-opus-4-8`, `claude-haiku-4-5` all current & correct.
2. Pricing $10/$50, $5/$25, $1/$5 per 1M — all current (matches cache 2026-06-24).
3. Effort tiers low/medium/high/xhigh/max are the real set; xhigh is between high and max.
4. Fable 5 runs cyber/bio refusal classifiers that false-positive on benign security-adjacent code → justifies the security→Opus rule.

**DONE:** both files sharper; contract IDs/tiers unchanged; no NEEDS DECISION.
