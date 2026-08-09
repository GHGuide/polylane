# Cycle 20 questions

The live run answered one material design question without needing user authority.

- **Recommended:** Should Polylane salvage a worker that committed the exact current-run
  DONE line under one wrong `docs/status-*.md` filename? Yes, but only through the
  deterministic single-candidate rename implemented in `763fb00`; this saves an entire
  model restart without weakening nonce, Git, or clean-tree trust. The stronger first
  defense is `f58d3cb`: reject any plan or prompt that assigns a noncanonical status
  path before a model launches, so normalization remains recovery rather than policy.
- **Go deeper next round:** Exercise the compiled relay command and marker normalizer in
  a fresh real run together with the nonce-scoped host proof and corrected report, then
  add adversarial cases only if that execution exposes a new boundary. The terminal
  criterion is zero restarts, not more speculative mechanisms.
- **Defer:** Do not generalize recovery into arbitrary filename/content repair. Multiple,
  stale, dirty, symlinked, foreign-lane, or uncommitted candidates must continue to stop.
