# Phase 4b — Model + effort per lane (token-efficiency first)

Recommend per lane; user overrides at the plan gate. This cached table is CANONICAL for costs — the Phase 5 plan gate's REQUIRED cost-estimate row (see "Cost-per-lane estimation" below) computes from it, and other lanes' reports cite it. IDs + pricing re-confirmed against the claude-api skill 2026-07-08; per 1M tokens. Re-verify with the claude-api skill only when the user questions a number or a new model ships.

| Model | In/Out | Character |
|---|---|---|
| Claude Fable 5 (`claude-fable-5`) | $10/$50 | Most capable; always-on thinking; long turns → highest token volume. Medium effort often beats prior models' max. |
| Claude Opus 4.8 (`claude-opus-4-8`) | $5/$25 | Agentic-coding workhorse (Claude Code default); xhigh available. |
| Claude Sonnet 5 (`claude-sonnet-5`) | $3/$15* | Near-Opus quality on coding/agentic at Sonnet cost; xhigh available. Mid rank — the balanced fallback when the round doesn't need Opus. |
| Claude Haiku 4.5 (`claude-haiku-4-5`) | $1/$5 | Cheapest. Recon/read-only subagents inside lanes; the economy floor when the whole round can run cheap. |

\* Sonnet 5 has introductory pricing of $2/$10 through 2026-08-31; estimate with the $3/$15 sticker rate so the numbers stay valid after the intro window.

## Capability / price rank map (freeze — presets resolve against this)

Capability high → low. **Price mirrors capability** ($10/$50 > $5/$25 > $3/$15 > $1/$5), so one order serves both.

| Rank | Model | ID | In/Out | Notes |
|---|---|---|---|---|
| 1 (most capable / most expensive) | Claude Fable 5 | `claude-fable-5` | $10/$50 | Runs cyber/bio refusal classifiers — excluded from security lanes and from `performance`. |
| 2 | Claude Opus 4.8 | `claude-opus-4-8` | $5/$25 | Best agentic non-Fable. Default builder + integrator tier. |
| 3 | Claude Sonnet 5 | `claude-sonnet-5` | $3/$15 | Mid rank. |
| 4 (least capable / cheapest) | Claude Haiku 4.5 | `claude-haiku-4-5` | $1/$5 | Cheapest. |

**Presets pick by RANK, never by hardcoded ID.** `available_models` = the set the user's Claude CLI can actually run (probed / from `/model`). Resolution operates ONLY within that set — a preset never names a model the user may not have.

**Resolution rule** — sort `available_models` by rank (rank 1 = most capable first):

- **`economy` → cheapest available** (highest rank number present).
- **`max` → most capable available** (rank 1 present, else next).
- **`balanced` → mid available** — the median rank; on an even count, pick the more capable of the two middles.
- **`performance` → best agentic non-Fable available** — the most-capable available model that is NOT Fable 5. If only Fable is available, it falls back to Fable and the planner notes it.
- **Unknown probed model** — a model in `available_models` that is NOT in the rank map above: the planner PAUSES and asks the user to place it (capability tier + price band relative to the four known models) before resolving any preset. Until placed, it is excluded from resolution.

Worked resolutions (full set `[fable, opus, sonnet, haiku]`): economy → Haiku 4.5 · balanced → Opus 4.8 · performance → Opus 4.8 · max → Fable 5. On `[opus, haiku]`: economy → Haiku 4.5 · balanced/performance/max → Opus 4.8 (tiers compress on a 2-model set).

## Cost-per-lane estimation (feeds the Phase 5 plan gate — REQUIRED)

The Phase 5 lane table MUST carry a rough dollar estimate per lane plus a total, so the user sees $ before approving. Compute it from this file's price table — nothing else — and ALWAYS label it "rough" (real spend varies with caching, retries, and how chatty the run gets; ±2× is normal).

**Formula (per lane):**

```
est_cost ≈ (input_tokens_guess × input_rate + output_tokens_guess × output_rate) / 1,000,000
```

`input_rate`/`output_rate` come from the lane's resolved model in the price table above.

**Token guesses by lane size** (a lane ≈ one Claude Code session; input dominates — every turn re-reads context, and caching discounts but doesn't erase it):

| Lane size | Input guess | Output guess |
|---|---|---|
| Small (few files, mechanical/docs) | ~2M | ~50k |
| Medium (typical builder lane) | ~5M | ~150k |
| Large (hardest lane, long-horizon, high/xhigh effort) | ~10M | ~300k |

Bump one size up for xhigh effort or an always-thinking model (Fable's long turns raise both columns). The integrator is usually Medium.

**Worked example** — 3 lanes + integrator, `balanced` on the full set (all Opus 4.8, $5/$25):

- 2 × Medium builder: 2 × (5M×$5 + 0.15M×$25)/1M ≈ 2 × $28.75 = $57.50
- 1 × Small docs lane: (2M×$5 + 0.05M×$25)/1M ≈ $11.25
- Integrator (Medium): ≈ $28.75
- **Total ≈ $97 (rough)** — present per-lane + total in the Phase 5 table.

If the user is on a subscription (Claude Code plan, not API billing), present the same numbers as a usage-budget proxy and say so — the $ figure then approximates how hard the run hits their rate limits, not an invoice.

## Intensity presets (freeze the names — others depend)

The user (or planner) picks ONE intensity for the round. It sets the DEFAULT `{model-rank, effort, caveman-level}` every lane starts from; per-lane role adjustments + hard rules refine it; per-lane user override is final (see Precedence). Names are EXACTLY these five.

| Preset | Model (by rank, resolved vs `available_models`) | Effort | Caveman level |
|---|---|---|---|
| `economy` | cheapest available | medium | ultra |
| `balanced` | mid available | high | full |
| `performance` | best agentic non-Fable available | high → xhigh | full |
| `max` | most capable available | xhigh | full |
| `custom` | user sets per lane (no round default) | per lane | per lane |

- **Model** resolves through the rule above at plan time against the probed `available_models`.
- **Effort** is the round default; the assignment table below still raises it for the integrator (xhigh) and the hardest lane, and the builder effort-ceiling hard rule still applies. `high → xhigh` for `performance` means default high, escalate to xhigh for the hardest lane or a stalling lane.
- **Caveman level** sets the level inside each generated prompt's mandatory caveman block (block 0 / `prompt-blocks.md`) — `ultra` for `economy`, `full` otherwise. The caveman step itself is never dropped (it stays non-negotiable in the mandatory-4 preamble); intensity only picks its level.
- **`custom`** skips the round default entirely: the user assigns model-rank + effort + caveman-level per lane at the plan gate.

## Assignment rules (per-lane role adjustments, layered on the intensity default)

These describe the RELATIVE shape of a round — which lanes get more capability/effort than the baseline and which get less. They apply on top of the resolved intensity default (see Precedence). The models named are the RANK the role wants; resolve each against `available_models` the same way.

| Lane profile | Rank / model | Effort | Why |
|---|---|---|---|
| Novel/hard optimization, unsolved problem, long-horizon autonomous run | Fable 5 (rank 1) | **medium** | Fable medium ≈ prior models' max at far fewer tokens than Fable high. The token-efficient way to buy Fable. |
| Hardest single lane of the round, correctness > cost | Fable 5 (rank 1) | high | Reserve for ONE lane max. Never default. |
| Iterative build/fix/verify in a known codebase (most lanes) | Opus 4.8 (rank 2) | **high** | Half Fable's price, no always-on-thinking bloat. The default builder. |
| Mechanical wiring, config, scaffolding, docs | Opus 4.8 (rank 2) | medium | high wastes tokens on the easy stuff. |
| Integrator / final verify / completeness critic | top non-Fable available (rank 2) | xhigh | Review quality matters most at the gate; still cheaper than Fable. Never cheaped out — beats the intensity default even under `economy`. |
| Orchestrator (this skill's session) | Fable 5 (rank 1) | xhigh/ultrathink | Tiny output, maximum leverage — the one seat where Fable always pays. |

Under a chosen intensity, the generic builder/mechanical rows above are what the intensity default expresses (`balanced` ≈ this table as written); `economy` shifts them down a rank, `max` up. The integrator, security, hardest-lane, and recon rows are role clamps that hold at every intensity.

## Precedence (highest wins — how intensity, roles, and hard rules reconcile)

1. **Explicit per-lane user override** (final at the plan gate; includes the `custom` preset). User is the authority.
2. **Hard rules** (safety + token guardrails below) — clamp specific lanes regardless of intensity.
3. **Per-lane role adjustment** from the assignment table (integrator / mechanical / hardest / security / recon) — deviates from the baseline where the lane's role demands it.
4. **Intensity preset default** — the round baseline for every lane with no more-specific rule.

So intensity sets the default; the assignment table + hard rules refine/clamp per lane; the user overrides last. Even under `max`, the "never Fable on all lanes" and "security → Opus" hard rules still force specific lanes off Fable — the intensity default raises the ceiling but never overrides a guardrail.

## Hard rules

- **Never Fable on all lanes.** Fable everywhere ≈ 4-5× spend for marginal gain on mechanical work. Overrides even `max`/`performance`: at least the mechanical/docs and security lanes drop to non-Fable.
- **Security/anonymity/Tor/anti-censorship/exploit-adjacent lanes → Opus 4.8** (rank 2, non-Fable), not Fable: Fable runs cyber/bio refusal classifiers that can false-positive on legitimate privacy/security code and stall the lane. Pins to Opus-tier when available (else the most capable available non-Fable) — overrides the intensity default in BOTH directions: never Fable even under `max`, never below Opus-tier even under `economy`.
- **Effort ceiling = high** for builders unless the lane keeps stalling (then bump one level and note it). xhigh is for the integrator, not the builders.
- Recon/searching inside a lane → tell the lane to use cheap read-only subagents (Explore/Haiku), not its main model — independent of the round's intensity.

## Token-efficiency add-ons (bake into every generated prompt)

- Terse-output/caveman block (see prompt-blocks.md) — cuts output ~75%. Level set by the round's intensity preset (`ultra` for `economy`, `full` otherwise).
- "Act when you have enough information; don't re-derive or narrate options you won't pursue."
- Locked goal (no builder-side brainstorming — that happened in the interview).
