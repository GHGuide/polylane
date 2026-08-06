# Verify — graph performance (cycle 3)

## Initial RED

Before implementation, the production fixture test was run with:

```bash
bash tests/test-graph-benchmark.sh
```

It reported `4 pass, 2 fail`: `benchmark-fixture-graph-valid` and the ready
operation failed because the old fixture omitted the immutable graph header,
routes, and loops.  The readiness regression was then pinned separately:

```bash
bash tests/test-graph-contract.sh
```

It reported `36 pass, 2 fail`: a `passed` verifier route did not admit
`promote`, and an ordinary failed route did not admit `halt`.  Finally, after
the valid fixture was in place but before the checkpoint implementation, the
benchmark reported `7 pass, 2 fail`: no checkpoint was created and a warm
10,000-row append measured `780ms`, above the frozen `250ms` limit.

## Implementation decisions

- `polylane-graph-bench.sh fixture DIR 64 10000` now compiles a real
  contract-v2 64-lane graph through `polylane-graph.sh`, emits its exact graph
  ID in a deterministic 10,000-event JSONL ledger, and writes a start-ready
  state file.
- Ready routing is deterministic: joins require every declared inbound route;
  ordinary nodes require one inbound route whose source state matches its
  declared outcome.  `passed` and `repaired` normalize to `succeeded`.
- JSONL remains the audit record.  The optional `.checkpoint` sidecar holds
  replay-derived state and idempotency keys only after a strict replay.  It is
  atomically written while the ledger append lock is held and is accepted only
  when run ID, graph ID, inode, byte size, and `cksum` content hash match.
  Missing, malformed, mismatched, replaced, and truncated inputs use strict
  validation/replay or fail with `EVENT-INVALID`.

## Focused proof

```bash
bash tests/test-graph-contract.sh
bash tests/test-graph-benchmark.sh
shellcheck -S warning bin/polylane-graph.sh bin/polylane-events.sh bin/polylane-graph-bench.sh
```

The graph contract suite reports 38 assertions.  The benchmark suite reports
16 assertions: valid 64-lane / 10,000-event production fixture, public CLI
packet, warm ready and append ceilings, malformed-checkpoint strict replay,
and replaced/truncated-ledger fail-closed behavior.  ShellCheck emits no
warnings for the owned scripts.

The benchmark packet performs fixture compilation, graph validation, ledger
verification, ready routing, append, verification, and replay through the
production CLIs.  The local ceiling is 10,000ms (20,000ms when `CI` is set).
Warm ready and append each have an independent 250ms ceiling.

## Timing samples

Fresh focused benchmark run command:

```bash
bash tests/test-graph-benchmark.sh
```

Recorded complete-packet samples on this host:

1. `2171ms`
2. `2213ms`
3. `2207ms`

Recorded warm samples in that run: ready `158ms`; append `117ms`.

PASS — all 16 benchmark assertions, all 38 graph-contract assertions, and
owned-script ShellCheck pass; the three production packets are below 10s and
warm operations are below 250ms, with cache-corruption and replaced-ledger
negative coverage.
