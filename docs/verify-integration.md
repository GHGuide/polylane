# Cycle 20 integration verification — clean process-start handoff

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

Correctness/security/performance review found no confirmed defect or integration seam.
The optional guard preserves requested-grade behavior and acts before durable effects;
the ownership predicate rejects foreign links and every other untracked path. Ponytail
review: Lean already. Ship.

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

## State, boundary, and limitations

The focused `m20.1` acceptance is marked pass only from the six reproduced contracts.
`m20.1` itself, `m18.3`, and `c56` remain open: no outer process-start run, terminal
full suite, or hermetic GO/NO-GO rehearsal was executed here. The coordinator alone
must establish exactly two launches, zero restarts, one terminal gate, complete cleanup,
and both rehearsal outcomes. No live external action occurred; approval-bound receipts
remain simulations and trading remains research/backtest/paper-only. The pre-existing
untracked `.polylane-prompt.txt` and `graphify-out/` were retained, so this certification
attests the committed merge and its focused evidence rather than claiming an empty local
scratch directory.

POLYLANE-VERDICT: READY-FOR-HOST-GATE run=c20-clean-cert-20260809-a1
