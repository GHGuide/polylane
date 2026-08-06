# Cycle 2 research

Execution-graph systems get their reliability from four separations: an immutable plan,
an append-only event history, deterministic state projection, and a scheduler that may
act only on currently enabled nodes. Polylane now has the first three in shadow mode.
The measured hot path is repeated whole-ledger parsing, not graph topology itself.
Therefore the next improvement should preserve the ledger as the audit source of truth
while deriving and atomically updating a validated replay checkpoint for scheduling.
The checkpoint is disposable and must always be reproducible from JSONL; corruption or
hash mismatch falls back to full replay rather than trusting cache.

