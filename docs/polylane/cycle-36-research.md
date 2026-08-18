# Cycle 36 research — why a green integrator became UNKNOWN

Cycle 35 completed both panes in one launch each and independently passed its focused
matrix. The integrator committed
`POLYLANE-VERDICT: GO run=c35-install-upgrade-20260811-a1`, but placed that line in
`docs/status-integrator.md`. The runner's gate intentionally and correctly parses only
`docs/verify-integration.md`, which contained no sentinel, so the run ended `NO-GO`.

The source prompt said to end `docs/verify-integration.md` with the sentinel, but the
later compiler-injected runtime block said to write the status file “and its integrator
verdict,” followed by “write only docs/status-integrator.md.” This is a contradictory
late instruction, not a test or installer failure. The smallest durable repair is a
role-aware runtime contract with explicit file destinations plus strict lint and a live
compiler regression. The runner's canonical gate path must not be widened to trust the
status file, because two verdict sources would weaken nonce and ambiguity safety.
