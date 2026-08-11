# Cycle 30 council

## Evidence

- Gate truth: a focused-only target promotes without terminal execution or
  telemetry; a truly eligible terminal target executes and counts once.
- Evidence isolation: nested acceptance fixtures cannot write outer-run
  diagnostics, real selected failures retain bounded current evidence, and a
  successful top-level phase removes its own stale record.
- Proof reuse: the one-use focused receipt is bound to the exact committed HEAD,
  a clean tree, selected targets, and acceptance definitions. Dirty-tree, new-HEAD,
  and definition mutations all rerun the focused command.
- Promotion truth: unrelated tracked or untracked user data remains unstaged and
  blocks promotion with an exact bounded reason; merge failures retain the branch,
  worktrees, base ref, and clean index. HALTED reports render the reason as literal
  data, including shell-looking text.
- Independent verification: all inherited `m24.1`–`m24.3`, `m25.1`–`m25.4`,
  `m26.1`–`m26.4`, and new `m27.1`–`m27.4` focused matrices passed through the
  integrator cache. Changed shell syntax, production-script ShellCheck, and diff
  whitespace checks passed.
- Runtime: canonical stats record one `gate-truth` launch, one integrator launch,
  zero lane restarts, zero supervisor restarts, and zero terminal gates.

## Decision

Emit GO for focused recovery run `c30-gate-truth-20260811-a1`. This decision
repairs Cycle 29's gate-truth lifecycle but does not rewrite Cycle 29's immutable
HALTED outcome and does not consume or certify any terminal boundary.

Cycle 31 remains a separate fresh process and exclusively owns `m24.4`, `m25.5`,
`c66`, `c71`, the full suite, complete `bin/*.sh` ShellCheck, provider parity,
fresh installers, both live doctor rehearsal outcomes, the one real terminal gate,
promotion, final report, and cleanup.
