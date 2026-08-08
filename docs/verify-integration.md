# Cycle 14 integration verification

Run: `c14-self-hosting-truth-20260808` on `lane/c14-integrator`.

## Cross-lane review and closed source contracts

The current runner-truth (`8df7952`), skill-delivery (`57781b5`), and
worker-ledger (`6f38155`) tips are merged. The integration seam repair makes
every prime-hybrid worker call bind `POLYLANE_PROJECT_ROOT` and
`POLYLANE_WORKERS_DIR` from the active runner, so an inherited parent run
cannot redirect a Git worktree's canonical worker ledger. Its regression makes
the fixture a Git repository with a deliberately mismatched ambient contract.

- c35 / m14.1: runner-owned durable dirt is narrowly committed before
  promotion. This now includes the exact skill-outcomes ledger and only the
  current run's named lane receipts; unrelated user dirt still blocks without
  alteration. Merge failure aborts and reporting says neither merge nor cleanup
  occurred.
- c36 / m14.2: a quiet high-effort live Codex turn receives its bounded grace;
  terminal turns and dead or missing panes remain recoverable.
- c37 / m14.3: two Git worktrees share one canonical lock/history and produce
  unique, strictly monotonic worker events without a merge conflict.
- c38 / m14.4: selected `{id,path,reason,source,fingerprint}` records reach
  compiled prompts exactly once; a helpful receipt needs matching
  `SKILL-READ` evidence. The cycle-13 fixture now migrates and validates the
  historical name-only kit before auditing it.
- c39 / m14.5 source layer: the named self-hosting-truth contract verifies all
  four paths together. Its physical rehearsal portion remains host-owned.

## Fresh checks

Every repeatable command was routed through
`bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator"` after the
relevant source change.

| Check | Result |
| --- | --- |
| m14.1 promotion/report reproduction | 43 pass, 0 fail |
| m14.2 liveness/recovery reproduction | 37 pass, 0 fail |
| m14.3 canonical worker ledger reproduction | 68 pass, 0 fail |
| m14.4 trusted selected-skill reproduction | 80 pass, 0 fail |
| `tests/test-cycle-14-contract.sh` | 13 pass, 0 fail |
| `tests/test-cycle-13-contract.sh` seam regression | 40 pass, 0 fail |
| `tests/test-prime-hybrid-integration.sh` | 47 pass, 0 fail |
| `tests/test-skill-parity.sh` | 43 pass, 0 fail |
| `tests/test-installers.sh` | 34 pass, 0 fail |
| `tests/test-install-fresh.sh` | 37 pass, 0 fail |
| `tests/run.sh` | 1,866 pass, 0 fail, 100 files |
| `shellcheck -S warning bin/*.sh` | 0 diagnostics |
| `bin/polylane-certify.sh focused` | exit 0, including `self-hosting-truth` |
| post-`5566152` `tests/test-promotion-transaction.sh` | 17 pass, 0 fail; ledger + exact receipt promoted, `README.md` dirt blocked |
| post-`5566152` promotion/report/worker focus | `test-promote` 4/0; `test-write-report` 31/0; `test-workers` 47/0; `test-worker-canonical-state` 23/0 |
| post-`5566152` `tests/test-cycle-14-contract.sh` | 13 pass, 0 fail |
| post-`5566152` ShellCheck | `bin/polylane-run.sh` and `bin/polylane-workers.sh`: 0 diagnostics |

The durable state has 51 acceptance records: 50 pass, 0 fail, and 1 unchecked.
c35–c38 and m14.1–m14.4 are `done`. c39 and m14.5 remain `doing` only because
the unchecked frozen terminal command includes the physical rehearsal.

## Review, risk, and skill-use audit

SKILL-READ: engineering:code-review | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/code-review/SKILL.md | 936987158-4285
SKILL-EVIDENCE: engineering:code-review — helped: reviewed the merged runner,
worker, and selected-skill seams; found and repaired the inherited worker-root
and legacy name-only receipt contracts.

SKILL-READ: superpowers:verification-before-completion | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/verification-before-completion/SKILL.md | 1896692335-3646
SKILL-EVIDENCE: superpowers:verification-before-completion — helped: required
fresh cached reproduction, parity/install, full-suite, ShellCheck, and focused
certification evidence before this readiness verdict.

SKILL-READ: operations:risk-assessment | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md | 3889652016-1630
SKILL-EVIDENCE: operations:risk-assessment — helped: kept user dirt,
failed-promotion cleanup, canonical worker history, and the host-only terminal
boundary as separate controlled risks.

SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
SKILL-EVIDENCE: engineering:testing-strategy — helped: grouped the five
business-critical c14 reproductions into the named 13-assertion integration
contract while retaining focused and terminal layers.

The durable inbox was read, the pending lifecycle reply was sent, and all
observed messages were acknowledged. Both queued refinement signals received
bounded declines; the authoritative queue is empty. The root Claude/Codex skill
contracts and installers needed no text change: their selected-kit and
prime-hybrid requirements already match the executable repair, which semantic
parity and fresh installation verified.

## Host-only boundary

The requested post-repair command was attempted in this restricted Codex
sandbox:

```sh
POLYLANE_REHEARSE_DEBUG=1 POLYLANE_MIN_DISK_GB=0 bin/polylane-rehearse.sh go
```

It reached runner launch, then this sandbox denied creation of the fresh tmux
Unix socket (`Operation not permitted`) before any mock lane launched. That is
not a GO/NO-GO lifecycle result; therefore the conditional NO-GO rehearsal was
not run. The coordinator must execute the same GO command, and then the NO-GO
command only if GO is clean, on a tmux-capable host. A successful rehearsal is
required to change c39/m14.5 and the terminal acceptance from their current
pending state. The pre-existing m12.4/c28 visual corpus is still external
evidence, not a PASS and not a block on this engineering gate.

ACCEPTANCE-GATE: terminal host rehearsal remains incomplete; the sandbox tmux
denial is not a lifecycle verdict.

POLYLANE-VERDICT: READY-FOR-HOST-GATE run=c14-self-hosting-truth-20260808
