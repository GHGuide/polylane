# Cycle 9 plan — measured product autonomy

## Goal and route

Implement all eight open `m8.*` subgoals as one performance-intensity expansion while preserving
the north star: a stranger's first run works flawlessly and unattended. Every subgoal already has
a frozen executable check in `max-state.json`; the terminal suite remains coordinator-owned.

Research basis: [cycle-9-research.md](cycle-9-research.md). Autonomous choices:
[cycle-9-questions.md](cycle-9-questions.md).

## Numbered integration spec

1. Add a versioned realistic vague-brief corpus plus `polylane-product-benchmark.sh` with
   deterministic validation, adapter execution, per-case JSONL, and aggregate text/JSON scores.
2. Add `polylane-discovery.sh` with durable question nodes, answer edges, recommended/deep/bold
   routing, contradiction tracking, bounded `next`, and transcript-free strategy summary/lock.
3. Make `polylane-models.sh` agent-aware so Codex never receives Claude ids; read the local Codex
   model cache when present and use a current Codex fallback otherwise.
4. Add a lean Codex worker launch contract (`ephemeral`, `ignore-user-config`, explicit model,
   effort, sandbox, and approval) plus a prompt optimizer that enforces mandatory blocks and a
   configurable token/byte budget before launch.
5. Upgrade the scout to resolve selected skills to concrete `SKILL.md` paths, recommend the
   smallest installed activity-specific kit, and rank it from an append-only outcome ledger.
6. Wire `polylane-outcomes`, seams, champion selection, and configured salvage through a single
   advanced runtime surface invoked by the runner at admission/integration/close.
7. Add exactly three independent manifest-defined quality judges and insert their typed boundary
   into the immutable graph with one bounded repair route; preserve replay determinism and the
   existing graph benchmark budget.
8. Replace dashboard-only reconstruction with a canonical `--once`/`--json` control snapshot
   sourced from `polylane-state`, max-state, graph/events, spend ledger, report, and cleanup state.
9. Update Claude-root and Codex-overlay documentation from the frozen CLI contracts, preserve ADR
   001/002, prove install parity, run focused tests, full suite, shellcheck, and a mock product
   benchmark end to end.

## Frozen shared contracts

These names and shapes are stable for every lane; request changes in `docs/parallel-status.md`.

### Product benchmark

`bin/polylane-product-benchmark.sh validate <corpus-dir>` validates every `*.json` case. A case
contains `schema`, `id`, `title`, `brief`, `product_shape`, `feasibility`, and non-empty `rubric`.
`run <corpus-dir> <out-dir> -- <adapter command...>` creates one isolated case directory, exports
`POLYLANE_BENCH_CASE`, `POLYLANE_BENCH_WORKDIR`, and `POLYLANE_BENCH_RESULT`, and expects the
adapter to write result JSON. `summarize <out-dir> [--json]` never turns unknown metrics into zero.

### Discovery graph

`bin/polylane-discovery.sh init <state> <brief>`; `next <state> [limit]`;
`answer <state> <question-id> <recommended|deep|bold|custom> [text]`;
`summary <state>`; `lock <state> <docs-dir>`. State is JSON and contains version, brief, nodes,
answers, contradictions, and strategy status. Deep/bold answers must create or activate a child.

### Models, worker profile, prompt optimizer

`bin/polylane-models.sh [claude|codex]` defaults to Claude for backward compatibility. Codex mode
uses `${CODEX_HOME:-$HOME/.codex}/models_cache.json`, returning only `gpt-*` ids. Manifest field
`codex_profile` is `lean|user` and defaults to `lean`; `lean` adds `--ephemeral
--ignore-user-config`. `bin/polylane-promptopt.sh check <prompt> [budget]` and `metrics <prompt>`
must preserve every strict prompt block and fail over budget.

### Skill outcomes

`polylane-scout.sh resolve <skill>` prints the exact trusted local `SKILL.md` path.
`recommend <domain> <activity>` emits installed-only ranked JSON. `record-outcome <ledger> <lane>
<domain> <skill> <helped|unused|hurt> [why]` appends JSONL. Validation requires at least one skill
per role and at most four unique; no fixed filler count.

### Advanced runtime and judges

`bin/polylane-advanced.sh preflight|select|salvage|record <manifest> ...` is the only runner-facing
adapter for existing helpers. Risk prediction and outcome recording always run. Selection requires
explicit `champion_candidates`; salvage requires at least three lanes plus `salvage_verify_cmd`.
Absence is reported as `not-requested`, never claimed as executed.

`bin/polylane-judges.sh run <manifest> <tree> <out-dir>` requires exactly three independent
`quality_judges`, each `{name,lens,command,timeout_s}`. It runs commands independently, writes one
evidence file and aggregate JSON, exits non-zero on any failure, and emits actionable reasons.
The graph adds `judges` and `judge-repair`; repair may loop back once, never indefinitely.

### Control room

`bin/polylane-dashboard.sh <manifest> --once` and `--once --json` project one canonical snapshot.
JSON fields include schema, goal, cycle, run_id, route, graph, lanes, spend, verdict, heartbeat,
cleanup, and next_action. Interactive mode repeatedly renders that snapshot. Current-nonce marker
semantics come from runner/state helpers, never dashboard-local bare-marker parsing.

## Lane carve

The write-set overlap matrix is zero by construction. Existing cross-file CLI names are frozen
above, so the four builders can run concurrently.

| Lane | Owns | Current subgoals | Skills |
|---|---|---|---|
| `product-foundation` | `bin/polylane-product-benchmark.sh`, `bin/polylane-discovery.sh`, `benchmarks/**`, `tests/test-product-benchmark.sh`, `tests/test-discovery-graph.sh` | `m8.1,m8.2` | TDD, verification, product brainstorming, write spec |
| `worker-efficiency` | `bin/polylane-models.sh`, `bin/polylane-scout.sh`, `bin/polylane-promptopt.sh`, `tests/test-models.sh`, `tests/test-intensity.sh`, `tests/test-promptopt.sh`, `tests/test-scout-outcomes.sh` | `m8.3,m8.7` | TDD, verification, testing strategy, system design |
| `quality-runtime` | `bin/polylane-advanced.sh`, `bin/polylane-judges.sh`, `bin/polylane-graph.sh`, `bin/polylane-run.sh`, `tests/test-codex-profile.sh`, `tests/test-advanced-runtime.sh`, `tests/test-graph-quality-loop.sh`, `tests/test-judges.sh`, existing graph/adapter/contract tests it must update | `m8.4,m8.5,m8.6` plus the runner half of `m8.3` | TDD, verification, architecture, code review |
| `control-docs` | `bin/polylane-dashboard.sh`, `tests/test-dashboard.sh`, `tests/test-control-room.sh`, `SKILL.md`, `codex/SKILL.md`, `README.md`, `references/**`, `codex/install.sh` | `m8.8` plus shared docs truth | TDD, verification, documentation, process optimization |

Each lane forbids every other row's paths. `quality-runtime` is the sole owner of runner and graph
semantics. `control-docs` documents only the frozen APIs above and must not edit implementation
scripts outside its row. The integrator may repair cross-lane contract mismatches after merging.

## Test cadence and done conditions

Builders run their new focused tests while iterating and the smallest relevant existing subsystem
suite before DONE. The integrator runs scope checks, prompt lint, skill lint, marker-doc parity,
seam scan, every new frozen test, then the full suite and shellcheck once through the canonical
check cache. A GO requires all eight focused acceptances, the terminal acceptance, no regression,
clean teardown, and current-nonce evidence.
