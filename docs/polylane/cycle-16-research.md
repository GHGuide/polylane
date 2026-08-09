# Cycle 16 research — executable autonomy, not domain-flavored prose

The evidence converges on five mechanisms. Public-data adapters need explicit source,
query, retrieval-time, vintage/version, checksum, and transformation receipts: FRED has
real-time/vintage semantics, while Crossref and OpenAlex expose filter, search, and
pagination behavior that must be recorded for reproducibility. A cached public-source
snapshot is therefore valid regression evidence; an unrecorded live response is not.

Domain grading must combine deterministic checks with independent judgment. Trading
research needs chronological splits, cost/slippage assumptions, robustness and multiple-
testing warnings because selecting the best-looking backtest can overfit. Research needs
source inclusion/exclusion, citation coverage, and uncertainty. Operations needs controls,
owners, rehearsal evidence, and recovery. Content needs factual/source checks and an
audience/editorial rubric. Software retains builds, tests, seams, and user-path evidence.

Long-run reliability should be tested as controlled experiments against a measurable
steady state: inject worker death, stale markers, malformed state, interrupted writes,
and resume events; assert bounded recovery and durable evidence. A short accelerated mode
belongs in the test suite, while a resumable wall-clock mode records checkpoints for a
6–24 hour operator-run certification.

Learning and economy policy must use accepted outcome deltas, tokens, wall time, and
quality—not launches or prose. Recommendations require minimum samples, confidence, and
safe fallback clamps. The same rule applies to skill selection: textual relevance may
nominate a candidate, but only a lane-shaped benchmark can make it a recommended default.

Consequential actions are a separate execution boundary. Polylane may prepare a request,
simulate it, render a redacted impact preview, and hash the exact payload. It may not cross
the boundary without explicit approval tied to that receipt.

Primary sources and evidence records are stored under `docs/polylane/research/c16/`.

