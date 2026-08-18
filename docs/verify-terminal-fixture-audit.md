# Terminal-fixture audit — Cycle 23

Run: `c23-terminal-cert-20260809-a1`  
Scope: evidence-only certification of the two Cycle 22 fixture repairs; no
production source was changed by this lane.

## Required skill receipts

SKILL-READ: superpowers:systematic-debugging | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/systematic-debugging/SKILL.md | 4111822586-9465

SKILL-READ: superpowers:verification-before-completion | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/verification-before-completion/SKILL.md | 1896692335-3646

## Primary provenance and causal reconstruction

`23572df7defc3b9e5327ce9fe0a76db7e2abe08c` is the repair commit
(`fix: keep terminal fixtures hermetic`).  The current checkout is `3140ba3`;
the six target files (`bin/polylane-rehearse.sh`, `bin/polylane-run.sh`,
`bin/polylane-scope.sh`, and the three repair tests) are unchanged from
`23572df` (`git diff --quiet 23572df..HEAD -- <target files>` returned 0).
The preserved [Cycle 22 outcome](polylane/cycle-22-outcome.md) reports the
original eight recovery failures plus the Cycle 14 wrapper failure, followed by
the rehearsal ownership drift found in the exact-environment replay.

### Recovery-fixture boundary

The runner's health recovery reads `max="${POLYLANE_MAX_RETRIES:-3}"` in
`bin/polylane-run.sh`; its documented default is three.  The repaired
`tests/test-runtime-recovery.sh` executes `unset POLYLANE_MAX_RETRIES` before
sourcing that runner.  The parent terminal is not mutated: the focused command
starts a child with `env POLYLANE_MAX_RETRIES=0 bash tests/test-runtime-recovery.sh`,
and `unset` affects only that child shell.

The matching Cycle 14 wrapper deliberately exports the stricter policy:
`assert_ok ... env POLYLANE_MAX_RETRIES=0 bash "$ROOT/tests/test-runtime-recovery.sh"`.
Thus it proves the fixture restores its *default-contract* environment rather
than silently relying on the terminal's live policy.

Counterfactual primary check: evaluating the parent version
`23572df^:tests/test-runtime-recovery.sh` under that zero-retry environment
returned exit 1 with `6 pass, 8 fail` (the missing-pane and renumbered-pane
recovery assertions failed).  The repaired fixture returned `14 pass, 0 fail`.

### Rehearsal status-marker ownership

The repair diff adds exactly one explicit canonical marker to each builder
manifest entry:

| Builder | Prompt and mock runtime marker | Manifest ownership |
| --- | --- | --- |
| `lane-a` | `docs/status-lane-a.md` | `a/**`, `docs/status-lane-a.md` |
| `lane-b` | `docs/status-lane-b.md` | `b/**`, `docs/status-lane-b.md` |

`bin/polylane-rehearse.sh` writes the corresponding marker requirements into
each builder prompt and its mock agent writes those exact runtime paths.  The
same generated manifest owns each path once.  `check_status_markers()` derives
`docs/status-$lane.md`, rejects broad status-marker globs, and requires an
exact count of one, so the prompt/runtime/manifest contract is aligned.

Counterfactual primary checks on `23572df^:bin/polylane-rehearse.sh` made each
of the two new exact `test-rehearse.sh` marker assertions return 1: neither
`["a/**","docs/status-lane-a.md"]` nor
`["b/**","docs/status-lane-b.md"]` existed before the fixture edit.

## Graph use and limits

Before source review, the pre-refreshed read-only graph was queried for
`contract_focused_acceptance_gate`, `write_efficiency_proof`, `rehearse`,
`check_status_markers`, and runtime recovery.  It located
`contract_focused_acceptance_gate()` at `bin/polylane-run.sh:L3389`,
`write_efficiency_proof()` at `bin/polylane-run.sh:L131`, `rehearse()` at
`bin/polylane-rehearse.sh:L44`, and `check_status_markers()` at
`bin/polylane-scope.sh:L78`.  It also showed `merge_gate()` calling the two
runner acceptance/efficiency functions and `rehearse()` calling its fixture
helpers.  This narrowed the primary inspection.  The graph's AST call edges
are navigation evidence only and its documented scope excludes prose, so this
audit used direct commit/source reads for causal and historical claims.

## Fresh focused verification

All required checks were invoked through
`bin/polylane-check.sh "$PWD/.polylane/check-cache/terminal-fixture-audit"`.
The required set passed on source fingerprint `1356419392:200`:

| Command | Result |
| --- | --- |
| `env POLYLANE_MAX_RETRIES=0 bash tests/test-runtime-recovery.sh` | 14 pass, 0 fail |
| `bash tests/test-cycle-14-contract.sh` | 13 pass, 0 fail |
| `bash tests/test-rehearse.sh` | 14 pass, 0 fail |
| `bash tests/test-scope.sh` | 19 pass, 0 fail |
| `bash tests/test-orchestration-contract.sh` | 14 pass, 0 fail |
| `bash tests/test-efficiency-canary.sh` | 25 pass, 0 fail |

There were seven cache executions rather than six: the Cycle 14 command was
started once through a nested `bash -c` batch form and once in the exact direct
form after its streamed output returned before its cache record was visible.
Both completed fresh with the same `13 pass, 0 fail` result.  No production
source was edited and no failed current-tip check was retried.

## Skill evidence

SKILL-EVIDENCE: superpowers:systematic-debugging — helped: required a
parent-versus-repair causal trace, which exposed the exact eight-failure
zero-retry counterfactual instead of inferring hermeticity from the green test.

SKILL-EVIDENCE: superpowers:verification-before-completion — helped: kept the
claim limited to fresh cache output, the immutable commit diff, and the scoped
owned-file evidence; it also records the duplicate Cycle 14 execution rather
than presenting it as a single run.
