# Cycle 34 plan — one fresh terminal certificate

Run: `c34-terminal-cert-20260811-a1`

## Frozen target

All 27 remaining autonomous subgoals (`m21.1`–`m27.4`) and all 23 remaining
criteria (`c57`–`c79`). No autonomous work is outside the manifest. Four target
subgoals own terminal-tier acceptance, so READY is eligible for exactly one host
boundary.

## Lane carve

One audit-only builder owns `docs/verify-terminal-certification-audit.md` and its
status marker. It must not edit source or tests. The integrator merges the exact
audit tip, independently verifies retained source/focused evidence, and emits
READY-FOR-HOST-GATE only from a clean committed tip. Any discovered source defect
is NO-GO; this cycle permits no repair wave.

## Runtime and terminal contract

- one audit launch + one integrator launch;
- zero lane, integrator, and supervisor restarts;
- zero terminal events before READY, exactly one after READY;
- no explicit `expected_terminal_gates`, proving the backward-compatible default
  is one;
- terminal matrix: full suite, warning-level production ShellCheck, provider skill
  parity, fresh installer tests, and live doctor GO/NO-GO rehearsal;
- verified promotion, complete cleanup, PASS final `1 / 1` efficiency proof,
  current-run report, and durable closure of every target and criterion.

## Completion boundary

Only the runner may award final GO. A terminal failure remains truthful NO-GO and
retains bounded host evidence. Local Claude/Codex installation occurs only after
GO, followed by installed-path parity checks; no push is authorized in this cycle.
