# Cycle 23 research — fixture hermeticity and terminal truth

## Confirmed Cycle 22 boundary

The Cycle 22 audit and integrator completed with exact nonce-matched markers.  The host
recorded two launches, zero restarts, one terminal gate, a passing efficiency proof,
and 1,047,313 known tokens.  Promotion was withheld only after frozen acceptance found
eight direct recovery-fixture failures plus their Cycle 14 wrapper failure.

`test-runtime-recovery.sh` asserts the runner's default three-attempt recovery behavior.
The terminal process intentionally exported `POLYLANE_MAX_RETRIES=0` for live workers,
and the fixture sourced `polylane-run.sh` without isolating that operator setting.  The
test now clears the inherited value before sourcing the runner, while a red-first wrapper
deliberately exports zero and requires all 14 default-contract assertions to pass.

After that repair, the exact terminal replay passed 2,210 suite assertions, whole-tree
ShellCheck, 57 parity checks, and 50 installer checks.  It then reached the live rehearsal
and exposed plan drift: the prompts required `docs/status-lane-a.md` and
`docs/status-lane-b.md`, but the synthetic manifest's `own_globs` omitted both paths.
The status-ownership preflight correctly stopped the fixture.  The manifest now owns each
canonical marker exactly once, with static red-first tests; the live GO and intentional
NO-GO rehearsal routes both pass under the same zero-retry environment.

## Graph and research boundary

The fresh AST-only graph covers 59 executable files, 931 nodes, 2,033 links, and 65
communities at zero model-token cost.  It contains the runner's focused/terminal proof
functions and the rehearsal lifecycle.  It intentionally excludes prose, so workers use
it for code navigation and cite durable Cycle 22 documents for rationale.  Internet
research or new installations would add no evidence to this narrow process certification.
