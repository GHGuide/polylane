# Cycle 33 plan — repair focused efficiency/cleanup truth

Run: `c33-efficiency-contract-20260811-a1`

## Frozen target

- `m29.1`: make efficiency certificates grade the manifest-declared terminal-gate
  count and preserve backward-compatible terminal proof verification.
- `c80`: close the already-proven Cycle 32 path/prompt contract once final cleanup
  certification can complete truthfully.
- `c81`: focused zero-gate and terminal one-gate certificates remain distinct,
  fail closed, and agree with cleanup/report/criterion state.

## Lane carve

One builder owns only `bin/polylane-efficiency.sh`, its focused tests, and its own
evidence/status files. The integrator may make a bounded seam fix only if a direct
defect is proven. No production runner change is expected.

## Frozen acceptance

`bash tests/test-efficiency-canary.sh && bash tests/test-write-report.sh && bash
tests/test-manifest-validation.sh && bash tests/test-orchestration-contract.sh &&
shellcheck -S warning bin/polylane-efficiency.sh bin/polylane-run.sh`

The builder must start red by reproducing a focused manifest with zero terminal
gates that currently fails final capture. The green proof must cover explicit
`expected_terminal_gates: 0`, default terminal `1`, mismatch rejection, malformed
proof rejection, and legacy `Terminal gates: 1` verification.

## Runtime contract

Exactly one builder launch and one integrator launch, zero lane/integrator/
supervisor restarts, and zero terminal gates. The manifest declares
`expected_terminal_gates: 0`. Focused GO must promote, clean completely, write a
PASS final efficiency proof, mark `m29.1`, `c80`, and `c81` done, and produce a
report whose prose agrees with canonical `cleanup=complete` telemetry.

## Next

After truthful focused GO, launch one fresh terminal cycle targeting every
remaining autonomous subgoal and criterion. Only that later runner may consume
the terminal boundary, execute the full certification matrix, install locally,
and claim completion.
