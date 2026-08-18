# Cycle 19 research — root-cause record

## Reproduction

From the preserved Cycle 18 integrated tip:

```bash
POLYLANE_MIN_DISK_GB=0 POLYLANE_REHEARSE_DEBUG=1 bin/polylane-rehearse.sh go
```

Both builders and the integrator reached current-run DONE. The next boundary printed
`ADVANCED: domain-grader=not-requested`, immediately followed by Git's fatal missing
pathspec for `docs/polylane/domain-runtime/bundle.json`. The summary was
`ready=0 promoted=0 terminal_gates=0 cleaned=0 leaks=1`.

## Data-flow trace

`domain_grade` in `polylane-advanced.sh` owns optionality and returns 0 after printing
`not-requested`. Its runner wrapper, `domain_grade_gate`, checked only the return code,
then unconditionally derived default paths, amended integration evidence, and staged
the paths. The bad state therefore originates at the wrapper boundary: success means
"requested grade passed OR optional grade was skipped," but the wrapper treated both
as "durable grade files exist."

## Confirmed hypothesis

The wrapper must stop post-processing when grading is not requested. A focused test
must prove no artifacts, evidence mutation, or commit occur in that branch while the
existing requested-domain test continues to prove bundle/grade/evidence persistence.
No other Cycle 18 change is implicated.
