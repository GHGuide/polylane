# Cycle 6 digest — canary rejected repair churn

## Built

- The live rehearsal now hands a nonce-bound READY candidate to the outer runner and requires
  exactly one durable terminal gate on GO.
- Report action extraction is a standalone, fixture-tested helper that accepts only explicit
  current-run evidence files and exact action headings.
- The verified integration commit was adopted only after an independent clean run reported
  1,026 passed, 0 failed across 67 files.

## Benchmark result

- The first candidate reached the gate in 412 seconds with 3/3 launches, zero restarts, one gate,
  and no manual intervention; its provisional efficiency proof passed.
- A transient global-suite failure was not logged precisely. The old runtime launched one
  integrator repair and fired a second host gate.
- Final result was correctly NO-GO: 801 seconds, three launches, one restart, two gates, cleanup
  pending, and truthful unknown token usage. Nothing was automatically promoted.

## Learned

- A host terminal gate is a one-shot fact. Model repair cannot make a consumed gate unused; it
  must stop the run and let a fresh run retry from verified source.
- Run telemetry lacked run identity, so a fresh cycle could inherit old launches and gates.
- Terminal acceptance suppressed the failing suite output, forcing diagnosis by reproduction.
- GO report extraction cannot depend on worktrees after cleanup; it must read promoted exact-path
  evidence. NO-GO reports should continue reading retained worktrees.
