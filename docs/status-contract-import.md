STATUS: contract-import DONE run=c43-recovery-20260818-a1

Imported the frozen cycle-42a v3 contract set from handoff `4851bc1` and
reconciled it with main. Evidence: `docs/verify-contract-import.md`.
Implementation commit: `4acb538`.

- 16 content-addressed artifacts imported; all eight contract JSONs byte-verified
  against their `4851bc1` blobs, SHA-256s recorded.
- Both frozen provenance hashes from `docs/polylane/cycle-42a-outcome.md`
  re-derived and matched at `4851bc1`; no WIP tip was read.
- The four shared files were ported, not overwritten. `polylane-run.sh` and
  `polylane-supervisor.sh` were three-way merged from the merge-base; main's
  `check_auth`, auth-park, dying-words, and `claude-opus-5` fixes all survive and
  their tests are green (test-doctor-auth 8, test-auth-park 8, test-models 32,
  test-supervisor 38 — all 0 FAIL).
- Imported v3 checks green: 43 + 95 + 60 assertions, test-finalization-watchdog
  18, test-contract-acceptance 42 — all 0 FAIL. ShellCheck 0, markers 0,
  skill-parity 72, `git diff --check` 0.
- Full suite: 4060 passed, 2 failed, 173 files.

NOT DONE — one blocker, outside this lane's OWN set:
`tests/test-lane-done-live.sh` fails `runtime-integrator-verdict-has-canonical-path`
because the imported `polylane-run.sh` lifecycle delta replaces the integrator
finalize prompt with the `polylane-finalize.sh` invocation, and the handoff's
paired assertion update to that test file is unowned by any cycle-43 lane. The
m32.6 focused acceptance therefore returns rc=1, short-circuiting at that link;
every other stage in the command passes independently. Repair relayed to
`integrator`: `git diff main 4851bc1 -- tests/test-lane-done-live.sh | git apply -`.

The other suite failure, `test-graph-benchmark.sh`, is a load-induced perf flake
on a file this lane does not touch (green 3/3 standalone).
