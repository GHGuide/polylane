# Cycle 30 integration verification

Run: `c30-gate-truth-20260811-a1` · branch: `lane/c30-integrator`.

## Exact-tip provenance

- Frozen base: `ad01fe70e7e748bfe24afb839ae3d164baf3f7ab`.
- Final builder status tip: `1e8f8cc96e259f31776528e5c3f981e8430ea676`.
- Builder implementation parent: `c9e37c7376d7ff0ebf22a9018318e3ef63effbe9`.
- Exact-tip merge commit: `520b7477eb6a686354f913a712758bdec9af5ddb`.
- Final engineering/evidence parent: `809c246a82bb20cc6b0b59b0dcc557f3c219a2a5`.

The builder's nonce-bound DONE marker and verification were read before its exact
tip was merged. The final tip is an ancestor of this branch. Its complete base diff
was reviewed across memory, runner, documentation, and focused regressions. Cycle
29's retained source remains historical input; its immutable outcome is HALTED and
is not claimed as GO.

## Independent contract review

### Terminal eligibility

`contract_terminal_eligible` requires terminal-tier acceptance for a current target
and no open/doing autonomous subgoal outside it. READY evaluates eligibility before
terminal telemetry or proof creation. Focused-only fixtures promote without executing
or counting a terminal gate; a real eligible terminal fixture counts once and passes
the already-counted flag into acceptance. Both paths pass focused regressions.

### Evidence isolation

The top-level checker retains failure authority while `_accept_run` removes all three
`POLYLANE_ACCEPT_FAILURE_*` variables from child commands. Nested intentional failures
cannot escape their owner run/phase. A new top-level phase removes only same-run,
same-phase stale evidence; a real selected failure atomically retains bounded current
command, return-code, timestamp, and output-tail evidence. Nonce, regular-file,
symlink, and atomic-replacement guards remain fail-closed.

### Focused proof reuse

The proof receipt is process-local and one-use. Its key binds exact committed HEAD,
selected targets, and acceptance `sid/cmd/tier/key/deps` definitions. Byte-identical
runner `.polylane-prompt.txt` and the verified graph link are scratch; a tampered
prompt, ordinary source dirt, new commit, or acceptance-definition change forces a
rerun. Focused regressions cover every boundary.

### Promotion and report truth

Promotion's allowlist was not broadened. Unrelated tracked or untracked user data
remains unstaged and unchanged; merge failures restore the base/index and retain
verified branches/worktrees. Bounded blocker text containing `$()` or backticks is
rendered through `printf` as literal report data and cannot execute. HALTED reports
name the exact safe blocker and preservation/retry guidance.

### Recovery seams

The preserved first handoff passed each direct matrix but the real focused wrapper
failed `efficiency-canonical-proof`: focused-only GO exported the current run nonce
without a concrete host efficiency proof, so a nested canary evaluated a tracked old
fallback proof against the new nonce. An isolated cached reproduction failed 24/1.
The runner now exports efficiency proof path and nonce atomically; focused-only GO
exports neither. The repaired canary passes 27/0 and the actual full focused wrapper
passes on scratch state.

The relay also proved `POLYLANE_MAX_REPAIRS=0` was ignored by the separate integrator
default. An explicit `POLYLANE_INTEGRATOR_REPAIRS` now wins; otherwise the integrator
inherits `POLYLANE_MAX_REPAIRS`; only an entirely unspecified policy keeps default 3.
The shared-zero and explicit-override regressions pass in the 61-check verdict matrix.

## Frozen focused matrices

Every frozen command ran through
`bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" -- <command>` on final
source fingerprint `464436691:25846`.

| ID | Frozen command group | Result |
| --- | --- | --- |
| m24.1 | manifest, Cycle 13, scout, orchestration, dry-run | PASS |
| m24.2 | status normalization, lane DONE/live DONE, scope | PASS |
| m24.3 | memory, acceptance, verdict repair, report | PASS: 62/38/61/55 |
| m25.1 | wedge, runtime recovery, pane error | PASS: 31/26/16 |
| m25.2 | report, runtime recovery | PASS: 55/26 |
| m25.3 | run stats, report, efficiency canary | PASS: all/55/27 |
| m25.4 | agent adapter, prompt compiler, orchestration, prompt lint | PASS: 53/16/14/32 |
| m26.1 | progress guard, wedge | PASS: 21/31 |
| m26.2 | agent adapter, prompt compiler, prompt lint | PASS: 53/16/32 |
| m26.3 | live DONE, runtime recovery, report | PASS: 15/26/55 |
| m26.4 | scope, manifest, orchestration | PASS: 29/19/14 |
| m27.1 | acceptance, run stats | PASS: 38/all |
| m27.2 | memory, acceptance | PASS: 62/38 |
| m27.3 | promotion transaction, report | PASS: 29/55 |
| m27.4 | acceptance, efficiency canary | PASS: 38/27 |

The runner-equivalent focused acceptance wrapper also passed on a scratch copy of
the frozen state. Terminal eligibility was false, so no terminal check or telemetry
event occurred. No full suite, terminal acceptance, installer, parity certificate,
doctor rehearsal, push, deployment, publication, or external action ran; those remain
Cycle 31 work.

## Syntax, lint, whitespace, refinement, and telemetry

- `bash -n` passed for both changed production scripts and all changed shell tests.
- `shellcheck -S warning bin/polylane-memory.sh bin/polylane-run.sh` passed.
- `git diff --check` passed.
- The refinement queue returned `[]`; no propose/decline command was eligible.
- Final relay and durable inbox were read. Literal promotion data, runner scratch,
  nested evidence, half efficiency context, repair precedence, and immutable restart
  truth requests were handled.
- Canonical nonce-matched stats record `gate-truth launches=1 restarts=0`,
  `integrator launches=1 restarts=1`, `supervisor_restarts=0`, and
  `terminal_gates=0`.

## Skill receipts and evidence

SKILL-READ: engineering:code-review | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/code-review/SKILL.md | 936987158-4285

SKILL-READ: superpowers:verification-before-completion | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/verification-before-completion/SKILL.md | 1896692335-3646

SKILL-EVIDENCE: engineering:code-review — helped: the environment-isolation review
found the proof-path/run-nonce half context and the incoherent repair-policy fallback;
both now have bounded regressions without weakening promotion or evidence guards.

SKILL-EVIDENCE: superpowers:verification-before-completion — helped: fresh exact-source
focused matrices, the runner-equivalent wrapper, lint/syntax/whitespace checks, exact
ancestry, and nonce-matched telemetry preceded this verdict; the immutable restart
prevents a false GO despite green engineering.

## Final verdict

Cycle 30's source-level focused contracts are green and zero terminal gates were
consumed. Canonical telemetry nevertheless records one integrator restart from the
preserved repair attempt, violating the frozen zero-restart criterion. The defect is
repaired, but this nonce cannot certify it. Cycle 29 remains HALTED, and Cycle 31's
separate terminal certificate remains untouched.

POLYLANE-REPAIRABLE: NO run=c30-gate-truth-20260811-a1
POLYLANE-VERDICT: NO-GO run=c30-gate-truth-20260811-a1
