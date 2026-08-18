# Cycle 17 council — bounded recovery, preserved host boundary

## Decision

Accept the two narrow compatibility repairs as locally verified: `c51`, `c52`, `m17.1`,
and `m17.2` are complete only from independent cached reproduction. The council does not
declare Cycle 16 or Cycle 17 complete; `m16.4` and `m17.3` remain at the single
coordinator-owned terminal boundary.

## Safety rulings

- Keep the graph mock hermetic only in its isolated fixture, while the repair loop
  remains covered by a domain-grade call count before every merge attempt.
- Treat an old `agent_message` as progress, never as a terminal boundary that shortens
  the live high-effort grace window.
- Treat recommendation status as untrusted metadata. Arming requires a trusted current
  skill resolution and public ledger gate for the exact fingerprint, domain, and lane
  shape; absent, thin, or stale evidence remains unarmed.
- Preserve Cycle 16's NO-GO record, paper-only trading, exact-hash action receipts, and
  the prohibition on consequential external execution.

## Verdict posture

`READY-FOR-HOST-GATE` is warranted only as a handoff for run
`c17-recovery-cert-20260809-a1`. The coordinator runs one fresh terminal matrix; a
failure records NO-GO and does not authorize a retry that would violate single-gate
accounting.
