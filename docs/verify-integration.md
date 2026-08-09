# Cycle 20 integration verification — truthful failed-certification handoff

Run: `c20-clean-cert-20260809-a1` on `lane/c20-integrator`.

## Provenance and independent review

The integrator accepted only the committed builder tip
`716624affb45b6e8ba75945e0fb135ea229bd59a` after confirming its committed first line
was `STATUS: restart-accounting-audit DONE run=c20-clean-cert-20260809-a1`. Its complete
range from base `228570d` added only `docs/verify-restart-accounting.md` and
`docs/status-restart-accounting-audit.md`, passed `git diff --check`, and was merged as
`20aa4e1c82b85ab701b3172da1ea01e696786740` with that exact tip as second parent.

Commits `80849c5c54713a1c406b0b93a62193896a803f4a` and
`e26c208b91c382ee07dda47ccca6d09fcfcc5ed6` were independently inspected. The former
returns from `domain_grade_gate` before bundle/grade/evidence/Git mutation whenever
`domain_runtime` is absent or disabled; the latter makes `lane_done` ignore only a graph
symlink resolving to a real non-symlink graph directory owned by another registered
worktree in the exact Git common directory. Current caller tracing found
`domain_grade_gate` at the verifier gate and `shared_graph_link_owned` only at the
clean-tree exception in `lane_done`. The required existing-graph queries for both
changed helpers and callers returned stale fuzzy document nodes rather than source
nodes; the graph was not rebuilt, and current source plus hermetic contracts were used
instead.

The initial code review found no defect in those two Cycle 19 repairs. The live Cycle 20
run then exposed two different orchestration seams outside that review boundary:

1. The builder twice committed the exact current-run DONE line under
   `docs/status-restart-accounting.md`, not the canonical
   `docs/status-restart-accounting-audit.md`. The old runner correctly rejected the
   near-miss but spent one health restart before coordinator commit `716624a` performed
   the auditable rename. Canonical run stats now prove one builder launch, one builder
   restart, one integrator launch, zero terminal gates, and pending cleanup.
2. The canonical relay contained a coordinator request naming that confirmed seam, but
   the authored integrator prompt said only to read the "canonical relay". The worker
   instead read tracked `docs/parallel-status.md` and missed the live request. This was
   a prompt-delivery failure even though the reference block described the relay
   correctly.

Coordinator commit `763fb00` closes both classes for the next process. Contract-v2
health recovery now normalizes only one clean, committed, regular `docs/status-*.md`
whose first line exactly matches the lane and current nonce; stale, foreign-lane,
uncommitted, dirty, symlink, and ambiguous candidates remain rejected. Prompt
compilation now injects the literal relay command and canonical DONE path into every
builder and integrator prompt after optimization/skill delivery, and strict runtime
lint requires each injected contract exactly once. The durable cleanup reference now
also calls `docs/parallel-status.md` a post-cycle summary rather than a live log.

## Fresh merged-tree evidence

Every command below ran once from this merged worktree through
`bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" --`.

| Command | Observed result |
| --- | --- |
| `bash tests/test-lane-done.sh` | 27 pass, 0 fail; accepts the registered same-repository graph link, rejects a foreign repository, and keeps unrelated dirt blocking completion. |
| `bash tests/test-share-graph.sh` | 11 pass, 0 fail; includes recovery sharing from the primary graph. |
| `bash tests/test-cycle-16-contract.sh` | 35 pass, 0 fail; proves both requested bundle/grade/PASS persistence and the unrequested `not-requested` no-op with unchanged evidence, HEAD, and clean Git. |
| `bash tests/test-verdict-repair.sh` | 40 pass, 0 fail; preserves the one-use READY host boundary and its failure paths. |
| `bash tests/test-supervisor.sh` | 26 pass, 0 fail; includes session-loss recovery and bounded launch accounting. |
| `bash tests/test-efficiency-canary.sh` | 14 pass, 0 fail; includes restart rejection and canonical-proof checks. |

Focused runtime total: 153 pass, 0 fail. Whole-tree `shellcheck -S warning bin/*.sh`,
`bin/polylane-markers.sh check-docs references/`,
`bin/polylane-seams.sh scan "$PWD"`, and `git diff --check` all exited 0. Skill parity
passed 57/0; installers passed 50/0; fresh installs passed 39/0.

After the two live seams were reproduced, the coordinator added a red-first recovery
and prompt-delivery matrix. The marker test failed 6 assertions before implementation;
the Cycle 13 compiler contract failed 6 assertions before injection. The repaired
12-file runtime/prompt/parity matrix then passed 381/0, including marker normalization
17/0, lane completion 27/0, runtime recovery 14/0, Cycle 13 contract 50/0, prompt
compiler 16/0, prompt lint 22/0, selected-skill delivery 44/0, agent adapter 49/0,
prime-hybrid integration 57/0, skill parity 57/0, and supervisor 26/0. Documentation
truth passed 25/0; whole-tree ShellCheck, marker-doc consistency, and diff hygiene
exited 0. The full terminal suite and doctor rehearsal were deliberately not consumed
inside a run that had already exceeded its zero-restart budget.

## State, boundary, and limitations

The focused `m20.1` acceptance remains local evidence only. Cycle 20 cannot certify
`m20.1`, `m18.3`, or `c56`: its one recorded restart exceeds the configured zero-restart
budget. The runner must preserve that NO-GO without spending the terminal gate. A fresh
Cycle 21 process must load `763fb00` and establish exactly two launches, zero restarts,
one terminal gate, complete cleanup, and both rehearsal outcomes. No live external
action occurred; approval-bound receipts remain simulations and trading remains
research/backtest/paper-only. The pre-existing untracked `.polylane-prompt.txt` and
`graphify-out/` were retained as runner-owned helpers.

POLYLANE-VERDICT: READY-FOR-HOST-GATE run=c20-clean-cert-20260809-a1
