# Product foundation verification

## Tests run

- `bash tests/test-product-benchmark.sh`: 15 pass, 0 fail.
- `bash tests/test-discovery-graph.sh`: 17 pass, 0 fail.
- Cached combined command: `bash tests/test-product-benchmark.sh && bash tests/test-discovery-graph.sh`: pass.
- `shellcheck -S warning bin/polylane-product-benchmark.sh bin/polylane-discovery.sh`: pass.
- `bash -n` on both owned scripts and focused tests: pass.
- `bin/polylane-product-benchmark.sh validate benchmarks/schema-v1`: validated 5 cases.
- `git diff --check`: pass.

## Design tradeoffs

- Corpus cases use the compact `schema-v1` JSON contract and require explicit `feasible` status; validation rejects malformed cases, missing rubrics, and duplicate IDs deterministically.
- Benchmark records retain unavailable adapter metrics as JSON `null`; aggregate means become `null` if an input is unknown rather than silently treating it as zero.
- Discovery state is a single JSON document with typed question and answer records. `deep` and `bold` produce an active child question; `next` orders unanswered active questions by impact and permits only one through five results.
- Locking writes only `strategy.md`, `north-star.md`, and `goal.md`, and refuses a state with unresolved persisted contradictions.

## Changed files

- `bin/polylane-product-benchmark.sh`
- `bin/polylane-discovery.sh`
- `benchmarks/schema-v1/*.json`
- `tests/test-product-benchmark.sh`
- `tests/test-discovery-graph.sh`
- `docs/verify-product-foundation.md`
- `docs/status-product-foundation.md`

## DEFERRED

DEFERRED: none
