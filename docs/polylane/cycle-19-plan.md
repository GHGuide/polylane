# Cycle 19 plan — optional domain gate recovery

## Why this cycle exists

Cycle 18 completed every builder and integration check, and its host terminal suite
passed all 107 test files. The final hermetic GO rehearsal then stopped before its
terminal gate. A standalone debug reproduction identified one deterministic cause:
`advanced_runtime domain-grade` correctly returned
`ADVANCED: domain-grader=not-requested`, but `domain_grade_gate` still tried to stage
the default bundle and grade paths. Generic projects do not create those optional
artifacts, so Git rejected the absent pathspec and promotion was withheld.

Cycle 18 remains truthful NO-GO. Cycle 19 starts from its preserved integrated tip and
repairs only this confirmed post-grade contract.

## Frozen lane and interface

| Lane | Owns | Frozen outcome |
|---|---|---|
| `optional-domain-gate` | `bin/polylane-run.sh`, `tests/test-cycle-16-contract.sh`, owned evidence/status | When `domain_runtime` is absent or disabled, the wrapper reports `not-requested`, exits 0, creates/stages/commits nothing, and leaves integration evidence unchanged; when requested, the existing bundle/grade/evidence commit path remains green |
| `integrator` | merge, review, Cycle 19 evidence/state | Reproduce both optional and requested paths, preserve all Cycle 18 fixes, and hand exactly one fresh terminal command to the host |

The advanced helper remains authoritative for whether a domain grader is requested.
No default artifact path may be interpreted as proof that optional grading ran.

## Acceptance and safety

- Add a red unit regression before changing production code.
- Keep the requested-domain Cycle 16 assertion unchanged and green.
- Builders and the integrator do not run `tests/run.sh` or the live rehearsal.
- The host gets one fresh terminal attempt: full suite, ShellCheck, parity, installers,
  and both live rehearsal outcomes.
- No external action occurs; trading remains research/backtest/paper-only.

## Finish

Promotion requires the focused optional/requested-domain contract, independent merged
review, and one coordinator-owned terminal command that reaches both rehearsal outcomes.
