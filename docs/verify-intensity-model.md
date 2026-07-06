# Verify — intensity-model lane

Evidence that `references/model-selection.md` now defines 5 intensity presets + a capability/price rank map + a resolution rule, with the existing per-lane rules reconciled. All quotes are copied verbatim from the file.

## 1. Intensity presets table (frozen names — contract others depend on)

Names are EXACTLY `economy | balanced | performance | max | custom`. Grep proof:

```
$ grep -oE '`(economy|balanced|performance|max|custom)`' references/model-selection.md | sort -u
`balanced`
`custom`
`economy`
`max`
`performance`
```

Each preset maps to `{model-rank, effort, caveman-level}`:

| Preset | Model (by rank, resolved vs `available_models`) | Effort | Caveman level |
|---|---|---|---|
| `economy` | cheapest available | medium | ultra |
| `balanced` | mid available | high | full |
| `performance` | best agentic non-Fable available | high → xhigh | full |
| `max` | most capable available | xhigh | full |
| `custom` | user sets per lane (no round default) | per lane | per lane |

## 2. Capability / price rank map

Capability high → low; **price mirrors capability**, so one order serves both:

| Rank | Model | ID | In/Out |
|---|---|---|---|
| 1 | Claude Fable 5 | `claude-fable-5` | $10/$50 |
| 2 | Claude Opus 4.8 | `claude-opus-4-8` | $5/$25 |
| 3 | Claude Sonnet 5 | `claude-sonnet-5` | $3/$15 |
| 4 | Claude Haiku 4.5 | `claude-haiku-4-5` | $1/$5 |

IDs + pricing confirmed against the claude-api skill (cached 2026-06-24): Fable 5 $10/$50, Opus 4.8 $5/$25, Sonnet 5 $3/$15, Haiku 4.5 $1/$5 — price order matches capability order exactly.

**Resolution rule** (verbatim intent): economy = cheapest available · max = most capable available · balanced = median available rank (even count → more capable of the two middles) · performance = most-capable available non-Fable. A probed model NOT in the rank map → planner pauses and asks the user to place it before resolving.

## 3. Worked example — `available=[opus, haiku]`, `intensity=economy`

Probed `available_models = [claude-opus-4-8, claude-haiku-4-5]`. Sorted by rank: `[opus (rank 2), haiku (rank 4)]`.

Round default from `economy` → **cheapest available = Haiku 4.5, effort medium, caveman ultra.** Then the precedence ladder (highest wins: user override > hard rules > per-lane role adjustment > intensity default) resolves each lane:

| Lane | Resolves to | Model / effort / caveman | Which rule fired |
|---|---|---|---|
| Generic builder | intensity default | Haiku 4.5 / medium / ultra | level 4 — economy baseline |
| Mechanical / docs | intensity default (already at floor) | Haiku 4.5 / medium / ultra | level 4 — economy baseline |
| Integrator / final verify | role clamp: top non-Fable available + xhigh | **Opus 4.8** / xhigh / full | level 3 — beats the Haiku default; the gate is never cheaped out |
| Security / Tor / exploit-adjacent | hard rule: non-Fable Opus-tier | **Opus 4.8** / high / full | level 2 — floors at Opus even under economy |

Reading: economy pushes the whole round to the cheapest model (Haiku here), but the integrator role adjustment and the security hard rule still pin their lanes to Opus 4.8 — the intensity default sets the baseline, the layered rules clamp where the role demands it.

Secondary check — `available=[fable, opus, sonnet, haiku]`, `intensity=max`: default resolves to **Fable 5 / xhigh / full**, but the "never Fable on all lanes" hard rule forces the mechanical/docs and security lanes off Fable (→ Opus-tier), so not every lane is Fable. The `max` ceiling rises but the guardrail still holds.

## 4. Old rules survive + reconciled

- Assignment table (novel→Fable medium, iterative builder→Opus high, mechanical→Opus medium, integrator→xhigh, orchestrator→Fable xhigh) — **kept**, reframed as per-lane role adjustments layered on the intensity default.
- `Never Fable on all lanes` — **kept**, now noted to override even `max`/`performance`.
- `Security → Opus 4.8` — **kept**, now a two-way clamp (never Fable, never below Opus-tier).
- Recon → cheap read-only subagents, builder effort ceiling = high — **kept**.
- New **Precedence** ladder states exactly how intensity, role adjustments, hard rules, and user override reconcile.

Grep proof the reconciliation anchors are present:

```
$ grep -cE 'Precedence|Never Fable on all lanes|Security.*Opus 4.8|per-lane user override' references/model-selection.md
6
```

## Scope check

Only `references/model-selection.md` was edited (plus this verify file + the status file). No FORBIDDEN file touched — confirmed by `git status --short` showing only `references/model-selection.md` before the docs were written.

DONE = presets + rank map + resolution rule + old rules reconciled + this verify + status.
