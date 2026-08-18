# Terminal certification audit — Cycle 34

Run: `c34-terminal-cert-20260811-a1`
Lane: `terminal-certification-audit`  
Audit source tip: `39c0a447a13930befb660b5b59c07fc7dbb7e987` (`plan Cycle 34 terminal certification`)

## Exact source and retained repair provenance

The audit tip is the Cycle 34 planning child of the promoted Cycle 33 tip
`d69fa43cc437eedc34270c83aef1bbd51b61d37d`; `git merge-base --is-ancestor`
returned success for that promoted tip and for Cycle 33 implementation repair
`62b9453afd482ff1b0855840a4f080d4e66d9782`. The promoted source is therefore
the exact starting source, with no source or test edit by this lane.

The retained Cycle 30 gate-truth repairs also remain ancestors:
`809c246a82bb20cc6b0b59b0dcc557f3c219a2a5` (`repair focused gate recovery
policy`) and its handoff `6ca299cb78f376035a60d74a7c6b9ba7fa9b69ec`. Historical
Cycle 30 NO-GO evidence is not changed or reused as a terminal result.

Cycle 33 repaired `bin/polylane-efficiency.sh` so an explicitly configured
non-negative integer `expected_terminal_gates` is used, but a missing field
defaults to `1`. Capture records `actual / expected`, and verification rejects
mismatched, duplicate, or malformed gate proof lines while accepting legacy
exact `Terminal gates: 1`. The current Cycle 34 research/plan intentionally
omits the field, so its host proof must be `1 / 1`; the explicit focused `0 / 0`
route remains separately covered.

## Frozen target and complete acceptance inventory

Direct state inspection found exactly 27 open autonomous subgoals and 23 open
criteria (`c57`–`c79`). The open autonomous set is exactly
`m21.1`–`m21.4`, `m22.1`–`m22.3`, `m23.1`–`m23.3`, `m24.1`–`m24.4`,
`m25.1`–`m25.5`, `m26.1`–`m26.4`, and `m27.1`–`m27.4`. The frozen acceptance
inventory has 28 unchecked entries: 24 focused and four terminal. Set comparison
returned no open autonomous subgoal without acceptance and no acceptance entry
outside the open target.

| Subgoal | Tier | Frozen key |
| --- | --- | --- |
| m21.1 | focused | pane-identity |
| m21.2 | focused | bounded-context |
| m21.3 | terminal | terminal-cert |
| m21.4 | focused | custom-intensity |
| m22.1 | focused | handoff-contract |
| m22.2 | focused | runtime-finality |
| m22.3 | focused | c25-integration |
| m22.3 | terminal | terminal-cert |
| m23.1 | focused | repair-transaction |
| m23.2 | focused | terminal-report |
| m23.3 | focused | fresh-runtime |
| m24.1 | focused | — |
| m24.2 | focused | — |
| m24.3 | focused | — |
| m24.4 | terminal | terminal-cert-c29 |
| m25.1 | focused | live-turn-supervision |
| m25.2 | focused | failure-reason-truth |
| m25.3 | focused | usage-breakdown |
| m25.4 | focused | source-control-roots |
| m25.5 | terminal | terminal-cert-c29 |
| m26.1 | focused | active-command-progress |
| m26.2 | focused | absolute-source-root |
| m26.3 | focused | scope-fail-fast |
| m26.4 | focused | planned-write-set |
| m27.1 | focused | target-terminal-eligibility |
| m27.2 | focused | accept-evidence-hermetic |
| m27.3 | focused | promotion-failure-report |
| m27.4 | focused | focused-proof-snapshot |

The four terminal entries are `m21.3`, `m22.3`, `m24.4`, and `m25.5`.
`m24.4` and `m25.5` have byte-identical command, tier, key, and dependency
records and share `terminal-cert-c29`; the four entries therefore have two
distinct keys, and the duplicate pair executes only once per invocation.

`contract_terminal_eligible` requires orchestration contract v2, at least one
terminal entry in `target_subgoals`, and zero open/doing autonomous work outside
that target. The inventory satisfies these source-level conditions. The READY
path increments `run_stats terminal-gate` only after the focused gate and
eligibility checks; a failed terminal attempt becomes non-repairable NO-GO.
Thus exactly one host-owned boundary is eligible, not yet consumed.

## Provider, installer, and host matrix surface

The two provider packages keep provider-native instructions separate while sharing
the deterministic `bin/` engine: Claude packages root `SKILL.md` and `bin/*.sh`;
Codex packages `codex/SKILL.md` and the same helpers as `scripts/*.sh`. README
states the same one-engine contract. `tests/test-installers.sh` copies a fresh
checkout before repo-scoped installation and compares the installed Claude/Codex
runner checksums. `tests/test-install-fresh.sh` uses `TEST_TMPDIR` fake Claude
and Codex homes, including a Codex reinstall and dual-root synchronization.

The frozen host matrix is intentionally unrun here: full `tests/run.sh`, complete
warning-level ShellCheck, provider skill parity, fresh installer tests, and
`bin/polylane-doctor.sh --rehearse`. The doctor source explicitly invokes the
real rehearsal helper once for GO and once for NO-GO. Those commands, promotion,
cleanup, final proof, report, and terminal counting remain exclusively with the
host gate.

## Fresh focused evidence

The required cache executed these non-terminal checks at source fingerprint
`3415557535:621`:

```text
bin/polylane-check.sh "$PWD/.polylane/check-cache/terminal-certification-audit" -- \
  bash -c 'bash tests/test-contract-acceptance.sh && bash tests/test-efficiency-canary.sh && \
    bash tests/test-manifest-validation.sh'
```

- `test-contract-acceptance.sh`: 38 pass, 0 fail. It covers focused non-counting,
  eligible one-gate execution, terminal failure truth, and immutable focused-proof
  reuse/invalidation.
- `test-efficiency-canary.sh`: 36 pass, 0 fail. It covers explicit `0 / 0`,
  omitted-field default `1 / 1`, legacy-one verification, mismatch rejection,
  current-run proof propagation, and no integrator-tree mutation.
- `test-manifest-validation.sh`: 29 pass, 0 fail. It rejects string, negative,
  fractional, boolean, and null `expected_terminal_gates` values.
- Cached `bash -n codex/install.sh claude-code/install.sh` passed.

No source defect was observed. This is not terminal certification evidence and
does not claim terminal matrix success.

## Required host telemetry and final proof

The new host process must record exactly one audit/builder launch and one
integrator launch, zero lane, integrator, or supervisor restarts, one terminal
gate event, verified promotion, complete cleanup, and a nonce-matched current-run
PASS final efficiency proof containing `Terminal gates: 1 / 1`. Its current-run
report must retain those measurements. Any deviation is a truthful NO-GO for a
new cycle and does not authorize repair or rewrite of historical evidence.

## Skill receipts

SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279

SKILL-READ: superpowers:verification-before-completion | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/verification-before-completion/SKILL.md | 1896692335-3646

SKILL-EVIDENCE: engineering:testing-strategy — helped: it limited fresh execution
to the high-risk focused acceptance, gate-contract, and malformed-manifest seams,
leaving the integrated terminal matrix to its single host boundary.

SKILL-EVIDENCE: superpowers:verification-before-completion — helped: it required
current ancestry, exact frozen inventory, cached focused outputs, and source-level
host-boundary inspection before this evidence-only handoff.

## Handoff

Source and frozen evidence are internally prepared for `READY-FOR-HOST-GATE`.
This audit does not award terminal GO.
