# Cycle 33 efficiency contract repair — verification

Run: `c33-efficiency-contract-20260811-a1`

## Red reproduction and root cause

Before the repair, a cache-local manifest explicitly declared
`expected_terminal_gates: 0`; its matching stats recorded one launch, zero
restarts, `terminal_gates: 0`, known tokens, and `cleanup: complete`. Final
capture returned `1` and wrote a durable proof whose only failure was
`terminal_gates=0`. Its `Status: FAIL` therefore contradicted the complete
cleanup telemetry without consuming a terminal boundary.

The fault was confined to `bin/polylane-efficiency.sh`: capture compared every
actual gate count to a literal `1`, while verification required the legacy
literal proof line `Terminal gates: 1`. Neither branch read a focused
manifest's terminal-gate expectation.

## Exact repair

- Capture reads `efficiency_canary.expected_terminal_gates`, validates an
  explicitly configured value as a non-negative JSON integer, and defaults a
  missing field to `1`.
- Capture compares actual and expected values and emits
  `Terminal gates: actual / expected`; failures retain both values.
- Verification accepts exactly one terminal-gate line: legacy exact
  `Terminal gates: 1`, or a numeric `actual / expected` line whose values
  agree. Mismatched, duplicate, and malformed terminal-gate proofs fail
  closed.
- The canary freezes focused `0 / 0`, default terminal `1 / 1`, legacy
  compatibility, mismatch rejection, malformed-proof rejection, and the
  preserved Cycle 32 failed proof's rejection. Manifest validation freezes
  string, negative, fractional, boolean, and null configuration rejection.

## Focused evidence

All checks used
`bin/polylane-check.sh "$PWD/.polylane/check-cache/efficiency-contract-repair" -- …`.

- Red: `test-efficiency-canary.sh` recorded 31 pass / 5 fail; the focused
  final capture and verification failed, and the proof lacked `0 / 0`.
- Red: `test-manifest-validation.sh` recorded 19 pass / 10 fail; every
  malformed `expected_terminal_gates` case was treated as a normal failing
  certificate instead of a configuration error.
- Green: `bash tests/test-efficiency-canary.sh` — 36 pass / 0 fail.
- Green: `bash tests/test-manifest-validation.sh` — 29 pass / 0 fail.
- Adjacent: `bash tests/test-write-report.sh` — 55 pass / 0 fail.
- Adjacent: `bash tests/test-orchestration-contract.sh` — 14 pass / 0 fail.
- Static: `shellcheck -S warning bin/polylane-efficiency.sh` — pass.

The green focused certificate is `0 / 0` with complete cleanup; default
terminal capture is `1 / 1`; a hand-written legacy `Terminal gates: 1` proof
still verifies. `0 / 1` and `zero / zero` proof lines are rejected. Explicit
`"0"`, `-1`, `1.5`, `true`, and `null` configuration values return helper
configuration error `2`, so none can be coerced into PASS.

## Scope proof

`git diff --name-only` is limited to the owned helper, its two owned tests,
and this verification record before the final status handoff. No runner,
terminal-tier command, durable goal state, historical Cycle 31/32 evidence,
installer, full suite, rehearsal, push, or external action was changed or
run.

## Skill receipts

SKILL-READ: superpowers:systematic-debugging | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/systematic-debugging/SKILL.md | 4111822586-9465

SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md | 1657109997-9015

SKILL-EVIDENCE: superpowers:systematic-debugging — helped: isolated the contradiction to the literal capture/verify terminal-gate branches after reproducing complete cleanup with zero gates.

SKILL-EVIDENCE: superpowers:test-driven-development — helped: the focused `0 / 0` and malformed configuration assertions failed before the helper change, then passed with the minimal manifest-driven implementation.
