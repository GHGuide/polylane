# Cycle 10 integration verification

Run: `c10-1786059806-3040` on 2026-08-07 from `lane/c10-integrator`.

## Integrated tips

| Lane | Committed tip | Integration evidence |
| --- | --- | --- |
| `lane/c10-acceptance-economy` | `1a7b020d85f9a9a4e5acbb10276238519bc1a2dd` | Present in `HEAD` (`git merge-base --is-ancestor`, exit 0). |
| `lane/c10-state-truth` | `125c6971305b13e117a2976d15f294c23cb25c81` | Merge `9349dbf`; both `ce84a7e` and the tip are present in `HEAD`. |
| `lane/c10-coordination-relay` | `d19b672127d2cba52df58957bdd1c3a7451e4754` | Merge `155df2b`; tip present in `HEAD`. |

All three lane verification notes were read and the combined `54513dcf..HEAD`
diff was reviewed for correctness, error propagation, concurrency, shell/path
injection, scope, maintainability, and installer parity.

## Focused cycle-10 evidence

Each command below exited 0:

```text
bash tests/test-accept-dedupe.sh       # 26 pass, 0 fail
bash tests/test-memory.sh              # 53 pass, 0 fail
bash tests/test-state.sh               # 19 pass, 0 fail
bash tests/test-dashboard.sh           # 41 pass, 0 fail
bash tests/test-outcome-rooting.sh     # 6 pass, 0 fail
bash tests/test-advanced-runtime.sh    # 19 pass, 0 fail
bash tests/test-coordination.sh        # 17 pass, 0 fail
bash tests/test-agent-adapter.sh       # 44 pass, 0 fail (final source-dependent run)
bash tests/test-prompt-economy.sh      # 19 pass, 0 fail
bash tests/test-installers.sh          # 12 pass, 0 fail
bash tests/test-skill-parity.sh        # 19 pass, 0 fail
bash tests/test-dryrun-pure.sh         # 7 pass, 0 fail
```

- m9.1: keyed results execute once per invocation, rerun on the next invocation,
  and propagate both pass and failure to later selected members.
- m9.2: state, runner, dashboard session/watch, nonce, committed-marker, and dirty
  worktree semantics agree.
- m9.3: foreign observer cwd runs write only to the manifest-derived outcome root;
  explicit outcome/hub overrides remain supported.
- m9.4: append-only replay, stale-lock reacquisition, two concurrent writers,
  canonical pane relay environment, prompt contract, Codex installation, and skill
  parity are executable checks.

## Integrated suite and repairs

`tests/run.sh` ran exactly once. It exited 1 with `1250 passed, 2 failed, 79 test
files`; both failures were in `test-control-room.sh` because its contract-v2 fixture
still used uncommitted DONE markers. The fixture now creates commits for both valid
wire formats. The source-dependent rerun `bash tests/test-control-room.sh` exited 0
with `10 pass, 0 fail`; the full suite was not repeated, per the frozen cadence.

Two minimal cross-lane regressions were repaired:

1. A nested/self-run inherited an outer pane's `POLYLANE_PROJECT_ROOT` and
   `POLYLANE_COORDINATION_FILE`, overriding the current manifest-derived relay.
   `pane_cmd` now prefers values loaded for the current run. The regression test
   was red-green checked: old precedence exited 1 with 2 failures; restored code
   exited 0 with `44 pass, 0 fail`.
2. The cycle-9 control-room fixture was updated to exercise m9.2's committed-marker
   contract instead of relying on the old state/runner mismatch.

No other adversarial-review finding remains open.

## Terminal checks

| Command | Exit | Evidence |
| --- | ---: | --- |
| `shellcheck -S warning bin/*.sh` | 0 | No output. |
| `bin/polylane-seams.sh scan "$PWD"` | 0 | No output; no seam finding. |
| `git diff --check` | 0 | No whitespace error. |
| `bin/polylane-doctor.sh` | 1 | Honest first attempt: host-owned tmux session `polylane-c11-deterministic-gates` already existed; no session was killed. |
| `POLYLANE_SESSION=polylane-c10-integrator-3040 bin/polylane-doctor.sh` | 0 | `9 PASS · 2 WARN · 0 FAIL`; warnings were pre-commit worktree changes and no active `.polylane/run.json`. |

The seam scan's complete stdout was empty.

## External gate

The host-owned live GO+NO-GO rehearsal (`bin/polylane-doctor.sh --rehearse`) was
not rerun in this lane. Its genuine external evidence remains open for the runner
promotion gate; no PASS is inferred from the gated-off rehearsal unit test.

## DEFERRED

DEFERRED: none

POLYLANE-VERDICT: READY-FOR-HOST-GATE run=c10-1786059806-3040
