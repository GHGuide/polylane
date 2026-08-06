# Cycle 2 plan — explicit execution graph

## Locked outcome

Compile every contract-v2 run manifest into a versioned, immutable execution graph; reject unsafe or non-terminating topology before side effects; record node transitions append-only; replay exact state; and prove the graph predicts the current runner before it gains scheduling authority.

## Frozen acceptance

- `m6.1`: `bash tests/test-graph-contract.sh`
- `m6.2`: `bash tests/test-graph-events.sh && bash tests/test-graph-shadow.sh`
- `m6.3` remains for the next cycle: `bash tests/test-graph-benchmark.sh`
- Terminal regression gate remains `tests/run.sh` plus `shellcheck -S warning bin/*.sh`.

## Graph contract v1

- Node states: `pending`, `ready`, `running`, `succeeded`, `failed`, `blocked`, `skipped`.
- Node kinds: `agent`, `command`, `fanout`, `join`, `verifier`, `repair`, `human`, `checkpoint`, `terminal`.
- Every graph has one run-scoped id, at least one terminal node, no undeclared edge endpoint, no unbounded cycle, and a terminal path from every node.
- Agent nodes carry immutable model, effort, target subgoals, write globs, timeout, retry budget, and evidence contract.
- Every failed node may move only through a declared recovery edge with a finite budget.
- The goal graph in `max-state.json` remains separate from the per-cycle execution graph.

## Lane carving

### `graph-contract`

Owns `bin/polylane-graph.sh`, `tests/test-graph-contract.sh`, and `docs/verify-graph-contract.md`. It must write behavioral tests first, observe RED because the graph CLI is absent, then implement manifest compilation, static validation, ready-node calculation, and deterministic routing.

### `graph-events`

Owns `bin/polylane-events.sh`, `tests/test-graph-events.sh`, `bin/polylane-graph-bench.sh`, and `docs/verify-graph-events.md`. It must write behavioral tests first, observe RED, then implement append-only event validation, idempotent transition recording, replay, and benchmark fixture generation.

### Integrator

Merges both tips, owns integration edits to `bin/polylane-run.sh`, `tests/test-graph-shadow.sh`, `docs/verify-integration.md`, and any parity documentation. It must compare graph-predicted transitions with the runner's observed GO, NO-GO, HALTED, and resume decisions. Shadow mismatches are a NO-GO. The graph cannot become authoritative in this cycle unless parity fixtures are exact.

## Benchmark budget for the next cycle

On a synthetic 64-node graph and 10,000-event ledger, the benchmark must complete compile, validate, route, append, and replay loops within 10 seconds total on the local development host and within 20 seconds under CI. A single shadow transition must remain far below the runner's two-second poll interval. Correctness and deterministic replay are hard gates; caching that can hide changed input is forbidden.

## Risks

- Do not confuse Graphify's repository knowledge graph with execution state.
- Do not add Python, a graph framework, a database, or a daemon.
- Do not let an agent rewrite a graph after the first node starts; replanning creates a new version.
- Do not make a graph visualization the source of truth; only validated JSON and event records are authoritative.
