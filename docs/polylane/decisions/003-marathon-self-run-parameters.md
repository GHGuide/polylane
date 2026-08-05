# ADR 003 — Marathon self-run parameters

- **Status:** accepted
- **Cycle:** 1

## Decision
Performance intensity; POLYLANE_MAX_CYCLES=99 (open-ended until mechanical COMPLETE); POLYLANE_AUTONOMOUS=1; target = polylane itself production-grade.

## Why
User picked these explicitly at launch (2026-08-05). Open-ended cap = the route/COMPLETE gate is the only stop besides the user.

## Consequences
Every cycle: performance-tier lanes, autonomous defaults, ledger caps consulted but cap=99.
