# Cycle 22 terminal-boundary audit

## Scope and provenance

This is an evidence-only audit of commit
`870bce64a33d424de878d4a5a3166d8f2dfbfbd9` (`fix: keep efficiency proof
context atomic`).  No production source, test, provider, state, cycle-control,
report, or external-action path was edited by this lane.

The preserved [Cycle 21 outcome](polylane/cycle-21-outcome.md) is the primary
historical record: its fresh process made two worker launches with zero
restarts, reached the READY handoff, and truthfully stopped before the terminal
gate (`terminal_gates=0`).  It identifies the failure as
`efficiency-canonical-proof`, caused by a current nonce paired with an empty or
inherited proof context.  The Cycle 22 plan and research retain the same
boundary: this audit is not a claim that Cycle 21 passed, or that the
coordinator-owned Cycle 22 terminal command has run.

## Read-only graph query

Before source inspection, the pre-refreshed read-only graph at
`/Users/leonardo/Downloads/polylane-c22/graphify-out/graph.json` was queried
for `contract_focused_acceptance_gate`, `contract_acceptance_gate`,
`write_efficiency_proof`, `merge_gate`, and `run_stats`, including callers and
locations.  It located all runner implementations in
`bin/polylane-run.sh` (lines 3389, 3305, 131, 3438, and 111 respectively),
and connected `merge_gate` to the focused and full acceptance gates.  It also
identified the regression harness definitions in
`tests/test-verdict-repair.sh`.

The graph was useful for the initial call chain and file locations.  It is not
the authority for shell environment semantics: several extracted edges are
directionally broad, so the commit diff, current runner source, and focused
canary below provide the causal proof.

## Primary failure and repair trace

The parent of `870bce6` shows the cheap
`contract_focused_acceptance_gate` exported
`POLYLANE_EFFICIENCY_PROOF="${EFFICIENCY_GATE_PROOF:-}"` and
`POLYLANE_EXPECTED_RUN_ID="${RUN_ID:-}"`.  In the preserved reproduction,
the proof variable is empty and `RUN_ID=pre-gate-run`; that old behavior would
therefore log the half-context `|pre-gate-run|` before the focused
`check-accept` invocation.

At current `bin/polylane-run.sh:3393-3402`, the same precheck instead unsets
both variables immediately before the focused `check-accept`.  The committed
canary at `tests/test-efficiency-canary.sh:102-108` sets precisely that
pre-proof state and requires the complete log to be
`||<state-file> check-accept --cycle 21 --targets s1 --focused`.  It therefore
distinguishes the Cycle 21 half-context from an empty precheck context; merely
making the proof empty cannot satisfy the assertion while a nonce remains.

The post-proof order is explicit in `merge_gate`: focused acceptance runs
first; on success it records `run_stats terminal-gate`, then calls
`write_efficiency_proof gate`, then calls `contract_acceptance_gate` with the
terminal count already consumed.  `write_efficiency_proof` derives the gate
path as
`$PROJECT_ROOT/docs/polylane/efficiency-proofs/${RUN_ID:-legacy}-gate.md`,
sets `EFFICIENCY_GATE_PROOF` to that path, and captures the gate proof.
`contract_acceptance_gate` exports the proof path and expected run ID together
for both its focused and terminal `check-accept` calls.  The canary verifies a
current-run proof and asserts two log entries matching
`<gate-proof-path>|eff-1|`, proving the pair reaches both acceptance calls.

`run_stats` delegates durable process-boundary telemetry to
`docs/polylane/run-stats.json`; the historical outcome and current focused
verdict checks consistently preserve the distinction between a failed cheap
precheck (zero terminal gates) and an entered terminal boundary (one gate).

## Fresh focused verification

Each command ran once through the lane-local check cache at
`.polylane/check-cache/terminal-boundary-audit`; all were cache `RUN` results,
not reused cache output.

| Command | Result |
| --- | --- |
| `bash tests/test-efficiency-canary.sh` | 25 pass, 0 fail |
| `bash tests/test-contract-acceptance.sh` | 19 pass, 0 fail |
| `bash tests/test-verdict-repair.sh` | 40 pass, 0 fail |
| `bash tests/test-supervisor.sh` | 32 pass, 0 fail |
| `bash tests/test-cycle-16-contract.sh` | 35 pass, 0 fail |

Total: 151 pass, 0 fail.  The efficiency canary itself passed the two boundary
assertions, the proof/nonce pair checks, and current-run verification.  No
whole-suite, whole-tree ShellCheck, skill-parity, installer, or doctor
rehearsal command was run.

## Skill receipts and evidence

SKILL-READ: superpowers:systematic-debugging | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/systematic-debugging/SKILL.md | 4111822586-9465

SKILL-READ: superpowers:verification-before-completion | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/verification-before-completion/SKILL.md | 1896692335-3646

SKILL-EVIDENCE: superpowers:systematic-debugging — helped: required tracing the bad nonce backward through the focused precheck, proof writer, terminal acceptance, and durable telemetry before making any repair claim.

SKILL-EVIDENCE: superpowers:verification-before-completion — helped: required fresh, exact cache-backed outputs for all five selected checks and prevents treating the preserved Cycle 21 failure as a terminal success.

## Audit conclusion

The Cycle 21 NO-GO boundary is independently reproduced from the preserved
outcome, parent/current commit trace, runner source, and focused canary.  The
repair is atomic at the environment boundary: pre-proof acceptance receives no
proof context, while post-proof terminal acceptance receives the matching
run-scoped proof path and nonce together.  This lane's scoped verification is
GO; coordinator-owned terminal certification remains outside this audit.
