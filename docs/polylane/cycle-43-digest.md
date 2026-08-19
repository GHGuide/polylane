# Cycle 43 digest — the v3 contract freeze landed; the harness paid for it

Cycle 43 recovered the work cycle 42A lost. Five promotion attempts (c43, c43b–e)
carried one candidate: the c42a taste-certification v3 contract set (execution,
evidence policy + DAG, source-calibration, lifecycle), the ported runner and
supervisor deltas, `bin/polylane-evidence-dag.sh`, `bin/polylane-finalize.sh`, and
the `--evidence-kind` acceptance extension.

**The engineering passed every attempt.** Four independent integrator runs each
ended `READY-FOR-HOST-GATE` with the frozen m32.6 focused acceptance green
(latest 4077/0). Every failure was in the harness, and each one produced a fix:
expired-login parking, safe-read approvals, model-paywall stall detection,
CPU-burn wedge immunity, bounded quiesce retry, runner-owned promotion evidence,
and verifier resume idempotence — seven defects, all now on main with regression
tests (`docs/polylane/cycle-43-findings.md`).

The final promotion was completed by the host: c43e's gate passed and reached
promotion, refused only because earlier runs' evidence sat uncommitted in the
base, after which `--resume` hit the (now fixed) verifier deadlock. Rather than
re-derive a fifth identical verdict, the host merged the certified candidate and
re-ran m32.6's **frozen acceptance** on the merged tree as the authority; it
passed, and only then did m32.6 close (`ab6d866`, state `6ba1cb2`).

Delivered: m32.6 done; goal tree 92/99 subgoals; suite 4110/0 across 175 files.
Not delivered: criterion c56 (zero-restart fresh process-start) remains open —
this cycle's canary was deliberately rescoped away from it, and it needs its own
clean run.

Next: cycle 44 implements the five frozen v3 defect controls against the lock.
