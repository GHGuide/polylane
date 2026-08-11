# Terminal certification audit — Cycle 31

Run: `c31-terminal-cert-20260811-a1`  
Lane: `terminal-certification-audit`  
Audit source tip: `ffbb520dcf6ae1a6fe53887177a2e606dde26d21` (`freeze Cycle 31 terminal acceptance`)

## Scope and provenance

The audit started from the retained Cycle 30 handoff
`6ca299cb78f376035a60d74a7c6b9ba7fa9b69ec`; it is an ancestor of the audit
source tip. `809c246a82bb20cc6b0b59b0dcc557f3c219a2a5` is also an ancestor.
That repair introduced two coupled protections in `bin/polylane-run.sh`:

- `contract_export_efficiency_context` exports the efficiency proof and its
  expected run nonce together, or unsets both for a focused-only route.
- `gate_with_repairs` gives an explicit `POLYLANE_INTEGRATOR_REPAIRS` value
  precedence, otherwise inherits `POLYLANE_MAX_REPAIRS`, and uses legacy `3`
  only when neither setting is present.

Cycle 30 remains the recorded NO-GO: its retained telemetry contained one
integrator restart. This audit neither changes that outcome nor treats its
historical focused pass as current terminal evidence.

## Frozen target and terminal eligibility

`docs/polylane/max-state.json` has 27 autonomous subgoals in `open`/`doing`:
`m21.1`–`m21.4`, `m22.1`–`m22.3`, `m23.1`–`m23.3`, `m24.1`–`m24.4`,
`m25.1`–`m25.5`, `m26.1`–`m26.4`, and `m27.1`–`m27.4`. This exactly matches
the Cycle 31 frozen target; the computed set of open/doing autonomous work
outside that target is empty. Host-owned `c57`–`c79` remain open; external
`c28` is explicitly out of scope.

The current target has 28 frozen acceptance entries: 24 focused and four
terminal. The terminal entries are `m21.3`, `m22.3`, `m24.4`, and `m25.5`.
They represent three distinct terminal certificate commands because `m24.4`
and `m25.5` are byte-identical and share the invocation-local
`terminal-cert-c29` key. The `ffbb520` freeze registered `m24.4` before
launch without weakening that command.

`contract_terminal_eligible` requires orchestration contract v2, at least one
terminal-tier entry within the manifest target, and zero open/doing autonomous
subgoals outside it. The current frozen target satisfies those source-level
conditions, so one—and only one—runner-owned terminal boundary is eligible.
The function does not count an event itself; `contract_acceptance_gate` counts
and executes the boundary only after this eligibility decision.

## Provider, installer, and rehearsal surface

Claude's installer packages root `SKILL.md` and shared `bin/*.sh`; Codex's
installer packages `codex/SKILL.md` and the same shared `bin/*.sh` as
`scripts/*.sh`. The parity suite checks the shared behavioural contract in both
provider skills. The installer tests are intentionally terminal-gate work, but
their frozen source shows the required isolation: `test-installers.sh` uses a
fresh copied checkout and compares installed shared-core hashes, while
`test-install-fresh.sh` uses temporary fake Claude/Codex homes and verifies a
Codex reinstall does not nest references. Both installer scripts passed fresh
syntax parsing in this audit.

The frozen terminal definitions include `tests/run.sh`, complete
`shellcheck -S warning bin/*.sh`, skill parity, fresh installer coverage where
specified, and `bin/polylane-doctor.sh --rehearse`. The doctor source invokes
the real rehearse helper for GO and NO-GO separately. Those commands were
inspected but not executed here; they remain exclusively assigned to the host
terminal boundary.

## Fresh focused evidence

The final verification executed through the required check cache:

```text
bin/polylane-check.sh "$PWD/.polylane/check-cache/terminal-certification-audit" -- \
  bash -c 'bash tests/test-contract-acceptance.sh && bash tests/test-efficiency-canary.sh && \
    bash tests/test-verdict-repair.sh && bash tests/test-run-stats.sh && \
    bash tests/test-skill-parity.sh && bash -n codex/install.sh claude-code/install.sh'
```

The cache ran the command, reported
`CHECK-CACHE: PASS source=2048234216:320`, and retained its output under the
lane-local cache. Results were:

- `test-contract-acceptance.sh`: 38 pass, 0 fail. This includes focused-only
  non-counting, eligible terminal counting/execution, terminal failure truth,
  and focused-proof mutation invalidation.
- `test-efficiency-canary.sh`: 27 pass, 0 fail, including no half-exported
  proof context on focused prechecks/GO and current-run host proof propagation.
- `test-verdict-repair.sh`: 61 pass, 0 fail, including shared-zero repair cap,
  explicit override precedence, one READY host gate, and no repair after host
  failure.
- `test-run-stats.sh`: passed its initialize/resume/usage/snapshot/concurrency
  smoke contract.
- `test-skill-parity.sh`: 59 pass, 0 fail; both provider skill variants retain
  the frozen shared behavioural requirements.
- `bash -n codex/install.sh claude-code/install.sh`: passed.

No source defect was found by this audit. The evidence is deliberately not a
terminal certificate: no full suite, complete production ShellCheck, installer
test, live doctor rehearsal, promotion, cleanup, or terminal-tier acceptance
command was consumed.

## Required host telemetry and handoff expectation

The fresh host run must begin with `POLYLANE_MAX_RETRIES=0`,
`POLYLANE_MAX_REPAIRS=0`, and `POLYLANE_INTEGRATOR_REPAIRS=0`. Its current-run
report must prove exactly one builder launch, one integrator launch, zero lane
retries or repairs, zero integrator repairs, zero supervisor restarts, exactly
one terminal-gate event, a nonce-matched current-run efficiency proof, verified
promotion, complete cleanup, and a GO report. Any deviation is a NO-GO for a
new cycle, never a repair or rewrite of Cycle 30 evidence.

## Skill receipts

SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279

SKILL-READ: superpowers:verification-before-completion | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/verification-before-completion/SKILL.md | 1896692335-3646

SKILL-EVIDENCE: engineering:testing-strategy — helped: it kept the audit to the
unique high-risk seams—terminal eligibility, atomic proof context, repair-cap
precedence, provider parity, and installer parsing—while preserving the
host-owned end-to-end boundary.

SKILL-EVIDENCE: superpowers:verification-before-completion — helped: its
evidence-first requirement led to a current cached focused run, exact ancestry
checks, and explicit separation between fresh local smoke evidence and the
unconsumed terminal certificate.

## Verdict

Source and frozen evidence are internally ready for the fresh host gate. This
is an evidence-only audit, not the terminal verdict.
