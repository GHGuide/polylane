# Phase 4b — Model + effort per lane (token-efficiency first)

Recommend per lane; user overrides at the plan gate. Verify current pricing with the claude-api skill ONLY if the user asks for costs — otherwise use this cached table (IDs + pricing confirmed against the claude-api skill 2026-07; per 1M tokens).

| Model | In/Out | Character |
|---|---|---|
| Claude Fable 5 (`claude-fable-5`) | $10/$50 | Most capable; always-on thinking; long turns → highest token volume. Medium effort often beats prior models' max. |
| Claude Opus 4.8 (`claude-opus-4-8`) | $5/$25 | Agentic-coding workhorse (Claude Code default); xhigh available. |
| Claude Haiku 4.5 (`claude-haiku-4-5`) | $1/$5 | Recon/read-only subagents inside lanes only. |

## Assignment rules

| Lane profile | Model | Effort | Why |
|---|---|---|---|
| Novel/hard optimization, unsolved problem, long-horizon autonomous run | Fable 5 | **medium** | Fable medium ≈ prior models' max at far fewer tokens than Fable high. The token-efficient way to buy Fable. |
| Hardest single lane of the round, correctness > cost | Fable 5 | high | Reserve for ONE lane max. Never default. |
| Iterative build/fix/verify in a known codebase (most lanes) | Opus 4.8 | **high** | Half Fable's price, no always-on-thinking bloat. The default builder. |
| Mechanical wiring, config, scaffolding, docs | Opus 4.8 | medium | high wastes tokens on the easy stuff. |
| Integrator / final verify / completeness critic | Opus 4.8 | xhigh | Review quality matters most at the gate; still cheaper than Fable. |
| Orchestrator (this skill's session) | Fable 5 | xhigh/ultrathink | Tiny output, maximum leverage — the one seat where Fable always pays. |

## Hard rules

- **Never Fable on all lanes.** Fable everywhere ≈ 4-5× spend for marginal gain on mechanical work.
- **Security/anonymity/Tor/anti-censorship/exploit-adjacent lanes → Opus 4.8**, not Fable: Fable runs cyber/bio refusal classifiers that can false-positive on legitimate privacy/security code and stall the lane.
- **Effort ceiling = high** for builders unless the lane keeps stalling (then bump one level and note it). xhigh is for the integrator, not the builders.
- Recon/searching inside a lane → tell the lane to use cheap read-only subagents (Explore/Haiku), not its main model.

## Token-efficiency add-ons (bake into every generated prompt)

- Terse-output/caveman block (see prompt-blocks.md) — cuts output ~75%.
- "Act when you have enough information; don't re-derive or narrate options you won't pursue."
- Locked goal (no builder-side brainstorming — that happened in the interview).
