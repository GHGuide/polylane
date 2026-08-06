# Cycle 9 research — measured product autonomy

## Executive summary

The current Polylane proves that isolated lanes, graph-backed recovery, and promotion gates can work, but its strongest public evidence is still a self-audit of the harness. The next quality jump is not more agent prose or a larger graph. It is a versioned product benchmark, persistent discovery state, cheap blocking gates before fan-out, and outcome-driven optimization of prompts and skills. OpenAI’s agent-first engineering report reaches the same operational conclusion from a different direction: when an agent fails, the useful response is to make the missing capability legible and enforceable in the environment, while keeping repository guidance as a small map with progressive disclosure rather than a giant manual ([OpenAI Harness Engineering](https://openai.com/index/harness-engineering/)).

The implementation should therefore preserve Polylane’s small Bash/jq runtime and extend it with typed evidence. A corpus runner should turn vague app briefs into reproducible cases and record completion, quality, wall time, and tokens. A discovery graph should persist questions, answers, contradictions, and deep/bold branches. Codex lanes should use an explicit lean launch profile and path-resolved skill capsules. Three independent judges should run as bounded promotion guardrails. Existing risk, seam, outcome, selection, and salvage helpers should be called from the Codex contract rather than merely documented. The control room should project canonical goal, graph, event, spend, and lane state in both text and JSON. Prompt changes should be accepted only when they improve benchmark metrics, following the eval-driven approach used by DSPy rather than subjective prompt polishing ([DSPy optimizers](https://github.com/stanfordnlp/dspy/blob/main/docs/docs/learn/optimization/optimizers.md), [MIPROv2](https://arxiv.org/abs/2406.11695)).

## Scope and method

This cycle investigated only gaps not already covered by cycles 1–8: realistic product evaluation, persistent branching discovery, Codex startup/context cost, bounded quality routes, independent judges, outcome-learned scouting, and operator visibility. It deliberately excluded another event-ledger optimization pass, a general-purpose graph framework, and any repository restructure forbidden by ADR 002. Fourteen primary technical sources were compared: OpenAI engineering and SDK documentation, official benchmark repositories, LangGraph documentation, and DSPy documentation and research. The evidence and claim ledger live in [research/cycle-9](research/cycle-9/).

## Finding 1 — evaluate products, not only patches or the harness

SWE-bench established the value of real repositories, real issue descriptions, and executable tests, while the Verified audit showed why feasibility review is necessary: ambiguous or impossible tasks distort the score ([SWE-bench](https://github.com/SWE-bench/SWE-bench), [SWE-bench Verified](https://openai.com/index/introducing-swe-bench-verified/)). METR’s RE-Bench adds a common task format for longer autonomous work ([RE-Bench](https://github.com/METR/RE-Bench)). OpenAI Evals recommends private datasets representing the recurring patterns of the system being optimized ([OpenAI Evals](https://github.com/openai/evals)).

Polylane should not import those large infrastructures. It should borrow their invariants. Each benchmark case needs a stable id, a deliberately vague user brief, frozen observable requirements, a feasibility classification, an adapter command, and machine-readable results. The corpus must span different product shapes so the system cannot overfit to this Bash repository: consumer UI, API/data, local-first workflow, mobile-shaped product, and a report/automation product. A run should preserve the chosen discovery strategy, final repository, acceptance results, independent judge results, wall time, tokens, retries, and final route.

The score must separate dimensions. “Tests passed” is necessary but cannot stand in for product usefulness. Completion measures frozen behavior; product quality comes from independent rubric judges; efficiency records time/tokens/restarts; autonomy records interventions; context quality records whether a fresh agent can use the result. A benchmark summary should report every dimension and never collapse unknown data to zero. A mock adapter makes the runner testable without spending model tokens; real Codex adapters can then be used for periodic releases.

## Finding 2 — discovery should be a durable graph, not an interview transcript

LangGraph treats persistence and durable execution as runtime properties ([LangGraph](https://langchain-ai.github.io/langgraph/index.html)). OpenAI’s harness report likewise argues for a small navigable knowledge map and mechanically checked documentation ([OpenAI Harness Engineering](https://openai.com/index/harness-engineering/)). Polylane already persists the goal tree after strategy lock, but its discovery process is still described as adaptive behavior the orchestrator should remember during a conversation. That is precisely where a long vague-idea session can lose depth requests, contradictions, and branch history.

The missing primitive is a discovery-state JSON document. Question nodes should have a dimension, prompt, recommended option, deep option, bold option, dependencies, and status. Answer edges should preserve the selected option, provenance, timestamp, and which new nodes became eligible. “Go deeper” must enqueue a narrower child in the same dimension; “go bold” must commit a named provocation and enqueue consequence questions. Contradictions should be explicit records that block strategy lock until resolved or consciously accepted. `next` should rank eligible questions by expected strategy impact, not list order. `summary` should emit a bounded packet from which a fresh agent can synthesize STRATEGY and NORTHSTAR without the transcript.

This graph is not an LLM replacement. The model still writes good options and follows up creatively. The graph guarantees continuity, budgets the question surface, and proves that deeper/bold choices actually caused another round. It also gives the benchmark a measurable discovery result: coverage, unresolved contradictions, number of pivots, and whether the final strategy can be reconstructed from disk.

## Finding 3 — lean workers need explicit context and a measured launch contract

OpenAI reports that a giant instruction file crowds out the task and that progressive disclosure works better ([OpenAI Harness Engineering](https://openai.com/index/harness-engineering/)). Codex’s own engineering reports frame the harness—context, tools, observations, and feedback—as a major part of agent quality ([Unrolling the Codex agent loop](https://openai.com/index/unrolling-the-codex-agent-loop/)). The local CLI confirms it supports ephemeral sessions, ignoring user configuration, strict profiles, output schemas, and explicit approval/sandbox/model settings. Those local capabilities should become a Polylane worker mode, because cycle 8 observed marketplace/MCP startup noise before source work began.

The safe design is opt-out user configuration for isolated builders, not globally mutating the user’s Codex setup. A lean worker command should use `--ephemeral --ignore-user-config`, keep explicit sandbox/approval/model/effort flags, and receive only the selected skill files by resolved path in its prompt. The integrator may use the normal profile when it genuinely needs broad tools. A launch probe should time a no-op adapter and preserve stderr diagnostics. The manifest must declare the worker profile so resume reproduces it.

Prompt optimization also needs a hard budget and a correctness checksum. Mandatory blocks—goal, exact subgoal, ownership, contracts, selected skill paths, test cadence, evidence, and marker—cannot be removed. A prompt optimizer may deduplicate and compress only outside those blocks, then run prompt lint. Token count and required-block coverage should be recorded. No prompt variant should become the default because it “looks cleaner”; it must improve the versioned product corpus or at least preserve completion while reducing tokens.

## Finding 4 — guardrails and judges belong at workflow boundaries

OpenAI’s Agents SDK distinguishes cheap blocking guardrails from parallel guards: a blocking guard can prevent expensive model work and side effects before they begin ([OpenAI Guardrails](https://openai.github.io/openai-agents-python/guardrails/)). That directly supports Polylane’s “cheap gate before fan-out” contract. The existing scope and outcome checks should execute at admission. Seam checks and product judges should execute at promotion. They should produce typed evidence consumed by the graph and control room.

Three judges are enough to reduce correlated optimism without creating another agent fleet. Their lenses should be independent and non-overlapping: behavior/completeness, user journey/product quality, and reliability/operability. Each judge is a command with a name, lens, timeout, and evidence file. All run against the same integrated tree without seeing each other’s result. Any failure emits one actionable reason and routes through the already bounded repair loop. Judge commands can be deterministic tests, browser/accessibility tools, or model graders, but the contract is identical. The default should be deterministic and local; model judges are opt-in because they add cost and variance.

The immutable graph should add a typed `judges` boundary between integration and promotion, with only declared outcomes and a bounded repair edge. This is an extension of the current topology, not an invitation for arbitrary cycles. OpenAI tracing models a workflow as one trace containing task, turn, tool, guardrail, and handoff spans ([OpenAI Tracing](https://openai.github.io/openai-agents-python/tracing/)). Polylane’s append-only node events can represent the same boundary without adopting a Python SDK.

## Finding 5 — dormant helpers and skill recommendations need outcome closure

Polylane already has risk prediction, best-of-N selection, delta-debug salvage, seam scanning, and skill outcome concepts. The Codex skill currently mentions only part of that behavior and the runner does not call most helpers. OpenAI’s Symphony pattern continuously ensures active work remains assigned until done ([OpenAI Symphony](https://openai.com/index/open-source-codex-orchestration-symphony/)); the analogous requirement here is that a declared helper must either be invoked mechanically or removed from the advertised contract.

Preflight should run risk prediction after scope validation. Promotion should always run seam scanning and configured judges. Every completed lane should append its shape, model, and outcome. Champion selection and salvage should be manifest-gated because they require extra spend or a project-specific subset verifier; when configured, the runner must call the helpers and record the route. When not configured, the control room should say “not requested,” not silently imply they ran.

Skill recommendations need the same closure. The current structured kit is a sound trust boundary, but forcing a fixed number of skills can add irrelevant context. The scout should resolve each selected skill to a concrete SKILL.md path, recommend the smallest installed kit that covers the lane’s activities, and rank candidates by prior `helped`, `unused`, and `hurt` outcomes for the same domain/shape. GitHub candidates remain informational and untrusted. After the lane, evidence should update the outcome ledger. This converts recommendations from a static catalog into a measured policy.

## Finding 6 — the control room should be a projection, never another state machine

Codex’s original product model made parallel task progress visible to the operator ([Introducing Codex](https://openai.com/index/introducing-codex/)). OpenAI tracing similarly treats observability as a comprehensive event record rather than terminal scraping ([OpenAI Tracing](https://openai.github.io/openai-agents-python/tracing/)). Polylane’s current dashboard predates nonce markers and reconstructs part of lane state from panes, so it can disagree with the runner. The new control room should read `polylane-state --json`, the immutable graph and event replay, max-state, spend ledger, report, and runtime heartbeat. It should never decide state.

`--once` text should answer: what is the ultimate goal, which cycle/run is active, what each lane is doing, which graph node is ready, what has been spent, what verdict exists, whether cleanup is complete, and what the next route is. `--json` should expose the same schema for monitors. Marker parsing must use the current run nonce. Missing measurements remain `null` or `unknown`. The interactive dashboard can render repeated snapshots of this one-shot projection.

## Recommendations, ranked

1. Build the product benchmark and discovery graph first; they become the measurement and state foundations for every later optimization.
2. Add a lean Codex worker mode plus prompt budget/required-block gate, but preserve an explicit compatibility switch for normal user config.
3. Insert three manifest-defined independent judges as a typed, bounded promotion boundary.
4. Wire outcome prediction/recording and seam checks unconditionally; wire champion selection and salvage only when their manifest contracts are supplied.
5. Resolve skill names to concrete files and rank the smallest useful kit from a JSONL outcome ledger.
6. Replace dashboard reconstruction with a one-shot projection of canonical state, then render the live loop from that projection.
7. Accept future prompt or policy changes only through corpus A/B evidence; do not optimize from a single self-run.

## Limitations and critique

The research sources describe Python and cloud agent systems more often than Bash/tmux orchestration, so the recommendation is an architectural translation, not a direct library adoption. Product-quality judges can still correlate if their commands share the same weak tests; the three-lens contract reduces but does not eliminate that risk. A small benchmark corpus can overfit, so cases need versioning, held-out additions, and feasibility review. `--ignore-user-config` may remove a capability a particular project needs; that is why the worker profile must be declared and overridable rather than globally forced. Finally, prompt optimization requires repeated real runs before quality claims are credible; cycle 9 can ship the harness and mock proof, while periodic release canaries accumulate the real comparative evidence.

## Methodology appendix

The investigation decomposed the goal into seven independent angles, retrieved primary sources, triangulated each core claim across at least three sources where available, and refined the initial outline when the evidence made repository knowledge and blocking guardrails more central than hook count. Claims, source identities, and evidence locators are persisted beside this report. Recommendations were filtered through the project constraints: Bash 3.2, jq, tmux, isolated CLI lanes, immutable graph replay, and the existing ADRs. The main inference is explicit: Polylane should adopt the invariants of eval-driven and durable agent systems while keeping its smaller runtime, rather than importing their frameworks.

## Bibliography

- OpenAI (2026), [Harness engineering: leveraging Codex in an agent-first world](https://openai.com/index/harness-engineering/).
- OpenAI (2026), [An open-source spec for Codex orchestration: Symphony](https://openai.com/index/open-source-codex-orchestration-symphony/).
- OpenAI (2026), [Unrolling the Codex agent loop](https://openai.com/index/unrolling-the-codex-agent-loop/).
- OpenAI (2025), [Introducing upgrades to Codex](https://openai.com/index/introducing-upgrades-to-codex/).
- OpenAI (2026), [Guardrails — Agents SDK](https://openai.github.io/openai-agents-python/guardrails/).
- OpenAI (2026), [Tracing — Agents SDK](https://openai.github.io/openai-agents-python/tracing/).
- OpenAI (2026), [OpenAI Evals](https://github.com/openai/evals).
- SWE-bench (2026), [SWE-bench repository](https://github.com/SWE-bench/SWE-bench).
- OpenAI (2024), [Introducing SWE-bench Verified](https://openai.com/index/introducing-swe-bench-verified/).
- METR (2026), [RE-Bench](https://github.com/METR/RE-Bench).
- LangChain (2026), [LangGraph overview](https://langchain-ai.github.io/langgraph/index.html).
- Stanford NLP (2026), [DSPy optimizers](https://github.com/stanfordnlp/dspy/blob/main/docs/docs/learn/optimization/optimizers.md).
- Opsahl-Ong et al. (2024), [Optimizing Instructions and Demonstrations for Multi-Stage Language Model Programs](https://arxiv.org/abs/2406.11695).
- OpenAI (2025), [Introducing Codex](https://openai.com/index/introducing-codex/).
