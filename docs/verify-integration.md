# Cycle 30 integration verification

Run: `c30-gate-truth-20260811-a1` · branch: `lane/c30-integrator`.

## Exact-tip provenance

- Frozen base: `ad01fe70e7e748bfe24afb839ae3d164baf3f7ab`.
- Final builder status tip: `1e8f8cc96e259f31776528e5c3f981e8430ea676`.
- Builder implementation parent:
  `c9e37c7376d7ff0ebf22a9018318e3ef63effbe9`.
- Exact-tip merge commit:
  `520b7477eb6a686354f913a712758bdec9af5ddb`.
- Verified implementation/evidence parent for this marker-last handoff:
  `9882e4585bbc9edebd3923a56aad79b40bdd8bfc`.

The builder's current-run DONE marker and evidence were read before merge. Its
complete base diff was reviewed across memory, runner, documentation, and six
regression files. The final builder tip is an ancestor of the integrator branch.
Cycle 29's `9df16a3` source remains historical recovery input; its immutable outcome
is still HALTED and is not claimed as GO.

## Independent contract review

### Terminal eligibility

`contract_terminal_eligible` requires a terminal-tier check for a current target
and no open/doing autonomous subgoal outside that target. READY evaluates this
before `run_stats terminal-gate` and terminal proof generation. A focused-only
fixture therefore completes focused acceptance and can promote with no terminal
execution, proof, or telemetry. A truly eligible target enters the boundary once,
counts before proof, and passes the already-counted flag into acceptance so it is
not charged twice. The focused-only and real-terminal paths both passed direct
runner regressions.

### Evidence isolation and lifecycle

The top-level checker retains failure authority while `_accept_run` clears all
three `POLYLANE_ACCEPT_FAILURE_*` variables from child commands. Nested intentional
failures therefore cannot escape into the owner run. A fresh top-level phase removes
only same-run/same-phase stale records before selection; a true selected failure
then atomically writes a bounded record with exact command, return code, timestamp,
and tail. Regular-file, symlink, nonce, run, and phase guards remain fail-closed.
The memory and acceptance fixtures proved nested isolation, current failure
retention, and successful stale-record removal.

### One-use focused proof

The receipt is process-local and consumed once. Its key binds the exact committed
integrator HEAD, target set, and selected acceptance `sid/cmd/tier/key/deps`
definitions. Tree cleanliness uses the existing narrow completed-lane boundary:
an exact byte-identical runner `.polylane-prompt.txt` and a verified sibling graph
link are scratch, while a tampered prompt or any other tracked/untracked path is
dirt. Regression fixtures proved one unchanged reuse and forced reruns for source
dirt, a new clean commit, and an acceptance-command mutation. This also closes the
final relay request that normal prompt transport must not permanently disable reuse.

### Promotion and report truth

Promotion's allowlist was not broadened. Unrelated tracked or untracked user data
stays unstaged, unchanged, and blocks before the base moves. Merge failure restores
the base ref and index and retains the verified branch/worktrees. The exact blocker
is reduced to one bounded line and rendered only through `printf`; regression data
containing both `$(...)` and backticks remained literal and executed nothing. HALTED
output names the blocker and gives preservation/retry guidance.

## Frozen focused matrices

Every matrix ran through
`bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" -- <command>`.
After the final relay repair changed source, every matrix was run fresh on source
fingerprint `2880044635:20328`.

| ID | Frozen command | Result |
| --- | --- | --- |
| m24.1 | manifest validation, Cycle 13 contract, scout, orchestration, dry-run purity | PASS |
| m24.2 | status normalization, lane DONE, live DONE, scope | PASS |
| m24.3 | memory, contract acceptance, verdict repair, report | PASS: 62/38/57/55 assertions |
| m25.1 | wedge, runtime recovery, pane error | PASS |
| m25.2 | report, runtime recovery | PASS |
| m25.3 | run stats, report, efficiency canary | PASS |
| m25.4 | agent adapter, prompt compiler, orchestration, prompt lint | PASS |
| m26.1 | progress guard, wedge | PASS |
| m26.2 | agent adapter, prompt compiler, prompt lint | PASS |
| m26.3 | live DONE, runtime recovery, report | PASS |
| m26.4 | scope, manifest validation, orchestration | PASS |
| m27.1 | contract acceptance, run stats | PASS |
| m27.2 | memory, contract acceptance | PASS: 62/38 assertions |
| m27.3 | promotion transaction, report | PASS: 29/55 assertions |
| m27.4 | contract acceptance, efficiency canary | PASS: 38/25 assertions |

No full suite, terminal acceptance, doctor rehearsal, installer, parity certificate,
push, deployment, publication, or external action ran.

## Syntax, lint, whitespace, and telemetry

- `bash -n` passed for both changed production scripts and every changed shell test.
- `shellcheck -S warning bin/polylane-memory.sh bin/polylane-run.sh` passed, matching
  the repository's authoritative `bin/*.sh` ShellCheck scope. An exploratory wider
  probe over test fixtures emitted their existing sourced-function/data-token fixture
  warnings; it was not substituted for or represented as the project lint gate.
- `git diff --check` passed on the final pre-handoff implementation/evidence tree.
- Canonical `/Users/leonardo/Downloads/polylane-c30/docs/polylane/run-stats.json`
  is nonce-matched and records `gate-truth launches=1 restarts=0`,
  `integrator launches=1 restarts=0`, `supervisor_restarts=0`, and
  `terminal_gates=0`. Ignored worktree copies belong to Cycle 23 and were rejected
  as stale evidence.
- The refinement queue returned `[]`; there were no eligible items, so no proposal
  or decline command was valid.

## Skill receipts and evidence

SKILL-READ: 936987158-4285 | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/code-review/SKILL.md | plugin-cache

SKILL-READ: 1896692335-3646 | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/verification-before-completion/SKILL.md | plugin-cache

SKILL-EVIDENCE: 936987158-4285 — helped: the isolation/race/report-truth review
found that byte-identical runner prompt scratch made the proof receipt unusable;
the bounded clean-tree helper and regression now distinguish scratch from real dirt.

SKILL-EVIDENCE: 1896692335-3646 — helped: fresh post-repair execution of all 15
matrices, exact ancestry, syntax/lint/whitespace checks, and nonce-matched zero-gate
telemetry preceded the verdict.

## Final verdict

Cycle 30's frozen focused source and evidence are green with two launches, zero
restarts, and zero terminal gates. The separate Cycle 31 terminal certificate remains
untouched and owns all terminal work.

POLYLANE-VERDICT: GO run=c30-gate-truth-20260811-a1
