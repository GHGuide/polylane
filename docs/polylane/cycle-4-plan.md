# Cycle 4 plan — walk-away proof and truthful observability

## Locked outcome

Close `m2.1`, `m4.1`, and `m5.1` in one real supervised two-builder Codex run. The updated
contract-v2 rehearsal must reach both GO and NO-GO, the complete suite and ShellCheck must pass,
the promoted base must be clean of runtime status markers, and the run must write
`docs/polylane/selfrun-proof.md` with an exact `Outcome: GO` line and reproducible evidence.

## Frozen acceptance

- `bin/polylane-rehearse.sh go && bin/polylane-rehearse.sh nogo`
- `tests/run.sh` and `shellcheck -S warning bin/*.sh`
- `test -f docs/polylane/selfrun-proof.md && grep -q 'Outcome: GO' docs/polylane/selfrun-proof.md`
- A real `bin/polylane-supervisor.sh ... --yes` run reaches a fresh GO report with no user input.

## Lane carving

### `runtime-integrity`

Owns `bin/polylane-run.sh`, `tests/test-cleanup.sh`, `tests/test-write-report.sh`, a new
`tests/test-pane-stalled.sh`, and `docs/verify-runtime-integrity.md`. Add failing tests first.
Cleanup must remove committed `docs/status-*.md` markers in a narrow automatic cleanup commit so
the promoted base is clean; it must preserve unmerged recovery branches. A paywall stall requires
an actionable credits/upgrade prompt, not prose mentioning “usage limit”. Suggested next steps
must come only from recognized structured sections in this run's lane evidence, never historical
examples or shell output.

### `rehearsal-audit`

Owns `bin/polylane-rehearse.sh`, `bin/polylane-doctor.sh`, `tests/test-rehearse.sh`, and
`docs/verify-rehearsal-audit.md`. Upgrade both mock cases to a complete contract-v2 fixture with
state, index, plan, lane skill kits, strict prompts, immutable graph, and authoritative events.
Assert GO promotes and cleans; assert NO-GO withholds promotion and retains evidence. Keep it
hermetic, deterministic, Bash 3.2-safe, and bounded.

### Integrator

Merge exact lane tips, run all frozen checks, write `docs/polylane/selfrun-proof.md`, and include
the run id, model/effort assignments, tmux session, lane commits, benchmark sample, test totals,
ShellCheck result, rehearsal results, clean-tree proof, and final report outcome. A prose claim is
not evidence. Reject any workaround that disables contract v2, uses danger-full-access, deletes
an unmerged branch, weakens acceptance, or hides a cleanup warning.

## Efficiency budget

Use `gpt-5.6-terra` at medium effort for both narrow builders and `gpt-5.6-sol` at high effort for
integration. Builders may not delegate. Reuse cached green checks while iterating, run the full
terminal suite once at the gate, and stop broad auditing after the frozen seams are proven.
