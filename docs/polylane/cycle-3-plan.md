# Cycle 3 plan — authoritative and efficient graph runtime

## Locked outcome

The execution graph becomes the scheduler for contract-v2 runs: no lane, join,
integrator, verifier, repair, promotion, completion, or halt action may occur unless its
node is ready and its route is declared. The append-only ledger remains authoritative
audit evidence, replay remains exact, and repeated scheduling uses only a disposable
validated checkpoint. Runtime failures observed in cycle 2 must self-heal or fail fast.

## Frozen acceptance

- `bash tests/test-graph-benchmark.sh`
- `bash tests/test-graph-authority.sh`
- `bash tests/test-runtime-survival.sh`
- `bash tests/test-graph-contract.sh && bash tests/test-graph-events.sh && bash tests/test-graph-shadow.sh`
- Terminal regression gate: `tests/run.sh` and `shellcheck -S warning bin/*.sh`.

## Benchmark contract

Use a valid compiled 64-lane graph and a deterministic 10,000-event ledger. Measure the
production CLIs, not substitute jq snippets. On this host, the complete compile,
validation, ready-route, append, verify, and replay packet must finish under 10 seconds;
CI receives a 20-second ceiling. A single append and a single ready query must each stay
below 250 ms after warm-up. Baseline evidence from cycle 2 is approximately 180 ms per
graph validation/readiness call, 820 ms per ledger verify/replay, and 890 ms per append.
The goal is at least 4x lower ledger scheduling overhead without skipping validation.

## Lane carving

### `graph-performance`

Owns `bin/polylane-graph.sh`, `bin/polylane-events.sh`,
`bin/polylane-graph-bench.sh`, `tests/test-graph-contract.sh`,
`tests/test-graph-benchmark.sh`, and
`docs/verify-graph-performance.md`. First pin the invalid fixture and measured budget as
failing tests. Then add a disposable replay checkpoint keyed by ledger identity, size,
last sequence, and content hash. Any mismatch, malformed checkpoint, replaced ledger, or
truncated row must force strict full replay. Keep Bash 3.2 + jq and the existing CLI
contract. Correct ready-node evaluation is part of this lane: join nodes require every
declared predecessor, while ordinary routed nodes require one matching predecessor
outcome (`passed`/`repaired` normalize to successful execution).

### `graph-authority`

Owns `bin/polylane-run.sh`, `bin/polylane-supervisor.sh`,
`tests/test-graph-authority.sh`, `tests/test-runtime-survival.sh`,
`tests/test-agent-adapter.sh`, `tests/test-lane-done.sh`, `tests/test-dashboard.sh`, and
`docs/verify-graph-authority.md`. Write negative tests first. Graph readiness must be
checked before any tmux launch or runner action. Add narrow Codex `--add-dir` access for
linked-worktree Git metadata under `workspace-write`; ignore only the runner-owned
`graphify-out` symlink when checking completion; make missing owned tmux sessions exit
recoverably instead of polling forever; and remove the dashboard partial-frame race.

### Integrator

Merge exact lane tips. Run every frozen focused check, the full suite, shellcheck, and
the benchmark at least three times. Reject any design that trusts a cache without
ledger-derived identity, permits an undeclared route, launches before readiness, broadens
write access unnecessarily, or passes only by raising the local 10-second ceiling.

## Stop conditions

- Correctness beats speed: a stale or corrupt checkpoint must never produce a GO.
- Do not add Python, a database, a daemon, or a third-party graph runtime.
- Do not mutate a graph after execution starts; replanning compiles a new graph id.
- If three measured optimization attempts cannot meet the frozen budget, preserve the
  fastest correct version and emit the exact remaining profile evidence for cycle 4.
