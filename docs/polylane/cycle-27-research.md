# Cycle 27 research — terminal gate repair

Cycle 26 is preserved as a truthful one-shot NO-GO. Its runtime stayed within the
frozen efficiency envelope: one builder launch, one integrator launch, zero lane
or supervisor restarts, and exactly one terminal gate. The integrated source was
`d8b94176f0a1272f76018e85696c300c633f6484`.

The runner-owned terminal command failed with **2343 passing and 4 failing
assertions across 111 test files**. A diagnostic rerun on the preserved integrated
tip isolated two source contracts:

1. `validate_kits` validates an integrator whenever its kit object merely exists.
   A structurally present but empty integrator kit is supposed to be a compatible
   no-op, so `test-manifest-validation.sh` rejects a valid dry run.
2. `normalize_status_marker` creates the intended canonical rename commit, then
   calls the stricter completed-branch scope gate. That gate sees the deleted
   near-miss status path as unowned and rejects the runner's own bounded repair;
   `test-status-marker-normalization.sh` has three failures.

The durable host-gate record retained only the generic phrase `frozen checks
failed`. The exact command tail existed on stderr but was discarded, forcing a
manual full-suite rerun. A terminal failure must retain a bounded run-scoped log
and link it from the host failure/report.

Cycle 27 is deliberately repair-only. It targets those three contracts with
focused checks and leaves fresh-process terminal certification open, so this run
must consume **zero** terminal gates. Cycle 28 will start from the promoted repair
tip and certify the loaded runtime once.

