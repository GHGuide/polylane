# Cycle 19 integration verification — optional domain gate recovery

Run: `c19-domain-gate-20260809-a1` on `lane/c19-integrator`.

## Provenance and review

The integrator accepted only the committed builder tip
`af221ab2b69365e497be2278234488e91a8784a5`, after reading its committed first line
`STATUS: optional-domain-gate DONE run=c19-domain-gate-20260809-a1`. Merge commit
`e9eb4230db8eed397c86d2a0c80b60ffc13ba08b` has that tip as its second parent.

The required existing graph was queried first for `domain_grade_gate`, `domain_grade`,
and callers. Its indexed C17-era documents did not contain the changed helper or its
runtime caller, so this limitation was recorded and the current source was traced
independently: `run_verifier_gate` is the sole production caller, and hermetic tests
cover the other call sites. Correctness review found no issue: the guard runs only after
the authoritative helper succeeds and before any evidence or Git mutation. Ponytail
review: `Lean already. Ship.`

## Fresh merged evidence

All commands below ran from the merged worktree through
`bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator"`.

- `bash tests/test-cycle-16-contract.sh` — 35 pass, 0 fail. The generic fixture emits
  `ADVANCED: domain-grader=not-requested`, returns successfully, preserves its sole
  integration-evidence line and `HEAD`, creates no bundle or grade, and remains clean.
  The unchanged requested fixture commits the tracked bundle and grade and records
  `DOMAIN-GRADER: PASS`.
- `bash tests/test-verdict-repair.sh` — 40 pass, 0 fail; the domain gate still runs
  before each merge attempt and the coordinator-owned READY host boundary remains
  single-use.
- `bash tests/test-skill-delivery.sh` — 44 pass, 0 fail; `bash
  tests/test-prompt-compiler.sh` — 16 pass, 0 fail; and `bash
  tests/test-cycle-13-contract.sh` — 44 pass, 0 fail, preserving exact selected-skill
  delivery and the Cycle 13 runner contract.
- Whole-tree `shellcheck -S warning bin/*.sh` was clean. `bash
  tests/test-skill-parity.sh` passed 57/0, `bash tests/test-installers.sh` passed 50/0,
  and `bash tests/test-install-fresh.sh` passed 39/0.

## Durable state and remaining boundary

`m19.1`, its focused frozen acceptance, and `c55` are marked done only from the fresh
35/0 reproduction. `m18.3` and both terminal acceptances remain unchecked. The
coordinator alone owns one fresh terminal matrix and both GO/NO-GO rehearsal outcomes;
this lane did not run `tests/run.sh` or either rehearsal. No external action occurred:
approval hashes remain required and trading remains research/backtest/paper-only.

POLYLANE-VERDICT: READY-FOR-HOST-GATE run=c19-domain-gate-20260809-a1
