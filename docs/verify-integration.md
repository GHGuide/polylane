# Cycle 31 integration verification

Run: `c31-terminal-cert-20260811-a1`

## Exact-tip provenance

- Retained repairs `809c246a82bb20cc6b0b59b0dcc557f3c219a2a5` and
  `6ca299cb78f376035a60d74a7c6b9ba7fa9b69ec` are ancestors of the integrated
  source.
- Builder audit source was `ffbb520dcf6ae1a6fe53887177a2e606dde26d21`.
- The builder's exact final current-run DONE tip
  `cff6ec32f988726471af51a9622f9cba53b56aa9` was fast-forwarded without
  alteration. It adds only the committed audit evidence and status marker.
- The complete retained-base diff from `6ca299c` contains the frozen Cycle 31
  plan/research/suggestions, the prelaunch `m24.4` terminal registration, and
  builder evidence. It contains no new production-script edit.

The physical source worktree is
`/Users/leonardo/Downloads/polylane-c31/.polylane/worktrees/c31-integrator`.
The canonical coordination/control root is
`/Users/leonardo/Downloads/polylane-c31/.polylane/runtime/c31-terminal-cert-20260811-a1`.
Both are absolute, they are distinct, and source work/tests stayed in the former
while relay, inbox, workers, and refinement state stayed in the latter.

## Independent retained-repair review

The review found no correctness, security, performance, or maintainability
blocker in the retained shell seams:

- `_accept_run` executes child acceptance commands in a subshell after unsetting
  `POLYLANE_ACCEPT_FAILURE_ROOT`, `POLYLANE_ACCEPT_FAILURE_RUN_ID`, and
  `POLYLANE_ACCEPT_FAILURE_PHASE`. Nested fixtures therefore lose outer evidence
  authority, while the top-level checker alone writes bounded current-run data.
- `contract_export_efficiency_context` exports the host proof path together with
  its current-run nonce. If the proof is absent, it unsets both
  `POLYLANE_EFFICIENCY_PROOF` and `POLYLANE_EXPECTED_RUN_ID`; no half context can
  survive into focused or terminal children.
- `gate_with_repairs` resolves
  `${POLYLANE_INTEGRATOR_REPAIRS:-${POLYLANE_MAX_REPAIRS:-3}}`. An explicit `0`
  is non-empty and wins, so this run's zero integrator-repair policy cannot be
  overridden by the shared fallback or legacy default.
- All paths remain quoted; the changes add no unbounded loop, external action,
  credential flow, or new mutable trust boundary. The evidence clear/write paths
  retain regular-file, nonce, bounded-output, and atomic-replace checks.

## Focused results

The integrator invoked the complete target-scoped focused acceptance once through
`bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator"`. It used a
temporary copy of `docs/polylane/max-state.json`, selected all 27 frozen targets,
and passed with `CHECK-CACHE: PASS source=1294778835:8298`. The selection resolved
to 24 focused entries and four excluded terminal entries, so no terminal command
was consumed. The retained cache log is
`.polylane/check-cache/integrator/1940456657-535.output`; successful acceptance is
quiet and the command exited zero.

The complete Cycle 30 retained shell-change set then passed cached `bash -n` for
`bin/polylane-memory.sh`, `bin/polylane-run.sh`, and the six changed focused test
scripts. Bounded `shellcheck -S warning` passed for the two changed production
scripts only, at `CHECK-CACHE: PASS source=1294778835:8298`. No full suite,
complete `bin/*.sh` ShellCheck, installer test, doctor rehearsal, promotion,
publication, deployment, or external action ran.

## Terminal eligibility

Mechanical comparison of the manifest and durable state found exactly 27
open/doing autonomous subgoals, and the sets are identical:
`m21.1`–`m21.4`, `m22.1`–`m22.3`, `m23.1`–`m23.3`, `m24.1`–`m24.4`,
`m25.1`–`m25.5`, `m26.1`–`m26.4`, and `m27.1`–`m27.4`. No current autonomous
target is outside the manifest.

The target owns terminal-tier acceptance for `m21.3`, `m22.3`, `m24.4`, and
`m25.5`, so the retained `contract_terminal_eligible` conditions are satisfied.
`m24.4` and `m25.5` retain byte-identical commands and the same invocation-local
`terminal-cert-c29` key. Eligibility authorizes the runner to attempt one real
terminal boundary; it is not terminal success and it is not GO.

## Runtime and handoff evidence

The canonical stats file is
`/Users/leonardo/Downloads/polylane-c31/docs/polylane/run-stats.json`. Its
pre-handoff snapshot records:

- `terminal-certification-audit`: one launch, zero restarts;
- `integrator`: one launch, zero restarts;
- zero supervisor restarts;
- zero terminal gates so far;
- cleanup pending and token state unknown, both correctly reserved for the host.

The runner launch policy is also present in the live environment:
`POLYLANE_MAX_RETRIES=0`, `POLYLANE_MAX_REPAIRS=0`,
`POLYLANE_INTEGRATOR_REPAIRS=0`, and `POLYLANE_SUP_MAX_RESTARTS=0`.
External evidence is absent and cannot substitute for a locally reproducible gate.
The required refinement queue returned `[]`, leaving no eligible decision item.

After the implementation/evidence commit, `git status --short` contained only the
runner-owned `.polylane-prompt.txt` and `graphify-out` scratch paths. The exact
evidence commit is `637fa7d66f842365e070fac837236299541465be`; executable source remains identical
to the focused-tested `cff6ec32f988726471af51a9622f9cba53b56aa9` tip.

## Skill receipts

SKILL-READ: engineering:code-review | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/code-review/SKILL.md | 936987158-4285

SKILL-READ: superpowers:verification-before-completion | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/verification-before-completion/SKILL.md | 1896692335-3646

SKILL-EVIDENCE: engineering:code-review — helped: the structured correctness and
security pass independently confirmed child evidence de-authorization, atomic
proof context, quoted paths, and zero-cap precedence instead of trusting the
builder summary.

SKILL-EVIDENCE: superpowers:verification-before-completion — helped: it required
fresh exact-tip ancestry, cached target-scoped execution, bounded syntax/lint,
canonical telemetry, and clean-tree proof before the READY marker.

## Final verdict

The source is eligible for the one real runner-owned terminal gate. No terminal
success, promotion, cleanup, criteria finalization, or GO is claimed here.
