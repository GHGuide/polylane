# Cycle 27 integration verification

Run: `c27-gate-repair-20260810-a1`

## Exact-tip provenance

The asserted builder tip
`013534eef494976e66826d39e3fd2c9a845c60e8` was read directly from
`lane/c27-gate-repair`, including its committed `docs/verify-gate-repair.md` and
`docs/status-gate-repair.md`, then merged by exact object as merge commit
`ed550a4`. The moving branch name and the base branch were not merged.

## Independent trust-boundary review

- Optional integrator kits share one `kit_active` predicate between preflight and
  prompt compilation. An absent or empty role selection is a compatibility no-op;
  partial content arms strict cardinality, installed-resolution, canonical path,
  source, fingerprint, duplicate-path, and four-skill validation. Empty, partial,
  complete, and stale-fingerprint cases pass.
- Marker normalization permits only a two-path HEAD commit with the exact runner
  subject, one regular current-run source, the canonical destination, identical
  blobs, and no ambiguous candidate. Only that proven deleted source is filtered
  from ordinary completed-branch ownership checks. Stale nonce, symlink, dirty,
  ambiguous, fabricated-subject, extra-commit-path, and ordinary out-of-scope
  cases remain rejected.
- Review found one real cross-lane defect in the builder tip: acceptance execution
  rebound `REPO_ROOT` to the integrator worktree before selecting the failure-log
  root. The bounded seam repair snapshots the canonical root before the subshell.
  The actual focused gate now proves output lands in the canonical project and not
  in the disposable checkout.
- Failed acceptance output is same-directory temporary-file + rename atomic JSON
  data. A one-line configured tail proves the bound; shell-special output is never
  executed; successful checks create no record. Host evidence and reports link a
  regular non-symlink record only when every entry carries the current run ID. A
  same-filename stale-run record is rejected.
- Virtual dry-run panes skip real tmux tagging and reach the normal preview return;
  real launches still call the fail-closed tagging helper.

## Fresh focused evidence

The frozen matrices were launched once under the integrator cache cadence, and
their retained per-test cache entries were reused rather than repeating unchanged
expensive checks.

- `m24.1`: the frozen manifest, Cycle 13, scout, orchestration, and dry-run matrix
  passed **124/124** assertions.
- `m24.2`: the frozen normalization, lane-done, live lane-done, and scope matrix
  passed **78/78** assertions.
- `m24.3`: the frozen memory, contract-acceptance, verdict-repair, and report matrix
  passed **183/183** assertions, including the canonical-root seam regression.
- Adjacent efficiency-canary, graph-authority, and graph-shadow tests passed
  **133/133** assertions.
- `shellcheck -S warning bin/polylane-run.sh bin/polylane-scout.sh
  bin/polylane-memory.sh` passed with zero output.
- `git diff --check` passed. The full suite, terminal acceptance, installers,
  parity certification, and doctor rehearsal were deliberately not run.

## Runtime telemetry and identity

Canonical `docs/polylane/run-stats.json` for this nonce records builder
`gate-repair` launches=1/restarts=0, integrator launches=1/restarts=0,
supervisor_restarts=0, and terminal_gates=0. Tmux pane tags bind pane 0 to the
builder worktree and pane 1 to this integrator worktree under the same run ID.
Worker capsules retain both identities as active. The canonical manifest targets
only `m24.1`–`m24.3`; both compiled prompts contain their exact selected-skill
records and final relay/inbox/marker contracts. The scoped relay and inbox were
empty at start. The refinement queue returned `[]`, so no item was eligible for a
decision.

## Graphify audit

The existing `graphify-out/q.py` was queried directly before targeted repair reads;
no Graphify skill body was read and the graph was not rebuilt. It located
`validate_kits`, `_accept_run`, `normalize_status_marker`, `new_pane`,
`launch_panes`, `contract_acceptance_gate`, `host_gate_failure`,
`report_host_gate_failure`, and `write_report`. The staged graph predates new
`kit_active` and `lane_completion_scope_valid` nodes and reported no relationship
edges for the repair nodes, so source and focused tests—not absent graph edges—are
the trust evidence.

## Skill receipts

SKILL-READ: engineering:code-review | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/code-review/SKILL.md | 936987158-4285

SKILL-EVIDENCE: engineering:code-review — helped: the independent correctness and
trust-boundary pass found that acceptance output was rooted to the disposable
integrator checkout, leading to the canonical-root seam repair and regression.

SKILL-READ: superpowers:verification-before-completion | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/verification-before-completion/SKILL.md | 1896692335-3646

SKILL-EVIDENCE: superpowers:verification-before-completion — helped: required fresh
124/78/183 focused evidence, 133 adjacent assertions, clean ShellCheck, and direct
telemetry inspection before any READY claim while preserving terminal_gates=0.

The final machine verdict is intentionally reserved for the last handoff commit
after the final live relay, durable inbox, focused-evidence, and commit-scope checks.
