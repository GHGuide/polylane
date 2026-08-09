# Verification — restart accounting and process-start boundary

Run: `c20-clean-cert-20260809-a1`  
Scope: evidence-only audit; no production code, test, provider, reference, state, or cycle-control document was changed.

## Skill receipts

SKILL-READ: superpowers:systematic-debugging | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/systematic-debugging/SKILL.md | 4111822586-9465

SKILL-READ: superpowers:verification-before-completion | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/verification-before-completion/SKILL.md | 1896692335-3646

## Cycle 19 attribution — correctly NO-GO

The terminal record for `c19-domain-gate-20260809-a1` says the efficiency proof saw
`restarts=3` against the budget of `1`, with `launches=2` and `terminal_gates=1`.
The runner/event summary preserved in `docs/polylane/cycle-20-research.md` attributes
exactly three recovery events:

| Count | Primary runner/event evidence | Root cause and provenance |
| --- | --- | --- |
| 1 | First dead-pane health respawn of builder `optional-domain-gate` | `share_graph` had created a same-repository sibling Graphify link, but the old `lane_done` predicate treated that runner-owned helper as dirty. The committed Cycle 19 integration evidence says it respawned the already-committed builder once. This was corrected by `e26c208`. |
| 2 | The owned tmux session vanished and the supervisor resumed once | This was a genuine recovery event in the same run, not a new process-start certification. It is independently consistent with the supervisor recovery contract: a lost session is a resume event. |
| 3 | First dead-pane health respawn of `integrator` | The coordinator resumed while its Bash process still held pre-`e26c208` functions; consequently the recovered runner could still apply the old ownership behavior. The Cycle 19 outcome explicitly identifies this as the third restart. |

Thus the count is not a duplicate accounting error: it is the sum of two health
respawns plus one supervisor recovery. Since `3 > 1`, the Cycle 19 NO-GO was required.
It must not be rewritten as a clean-run result. The outcome's `verifier=failed` and
`halt=succeeded` are therefore consistent with the efficiency gate, and its retained
integrated tip `23cabdf` is the correct input for a fresh process-start certification.

## Committed repair provenance and current-tip proof

- `80849c5c54713a1c406b0b93a62193896a803f4a` adds the
  `domain_runtime` object/enabled predicate directly after successful domain helper
  execution and before bundle/grade paths, integration evidence, staging, or commit.
  The missing-domain branch therefore returns as a no-op.
- `e26c208b91c382ee07dda47ccca6d09fcfcc5ed6` adds
  `shared_graph_link_owned`. It resolves the symlink, gets the exact Git common
  directory, enumerates registered worktrees, excludes the lane itself, and accepts
  only a real non-symlink `graphify-out` directory whose canonical path equals the
  link target. `lane_done` ignores the helper only when that predicate succeeds.
- `23cabdfeb0297f93bd743b9b73d8509ff41046a4` records the requested-profile grade
  after both repairs. Fresh ancestry checks returned 0 for `80849c5`, `e26c208`, and
  `23cabdf` being ancestors of `HEAD`; fresh diffs returned 0 for both the runner and
  the three directly relevant contracts relative to `23cabdf`.

The pre-existing graph was queried without rebuilding. It found `lane_done` and
`share_graph` in the runner and their call relationships; it had no indexed node for
`shared_graph_link_owned` and returned older efficiency documentation for restart
accounting. That index limitation is why the committed patches and fresh contracts are
the proof of the new predicate rather than an inference from graph coverage.

## Fresh focused checks

Each command ran once from this worktree through
`bin/polylane-check.sh "$PWD/.polylane/check-cache/restart-accounting-audit" --`.

| Command | Result |
| --- | --- |
| `bash tests/test-lane-done.sh` | 27 pass, 0 fail; includes same-repository Graphify-link acceptance and foreign-repository rejection. |
| `bash tests/test-share-graph.sh` | 11 pass, 0 fail; includes recovery sharing from the primary graph. |
| `bash tests/test-cycle-16-contract.sh` | 35 pass, 0 fail; includes the unrequested domain-grade no-op with unchanged evidence, HEAD, and clean Git. |
| `bash tests/test-verdict-repair.sh` | 40 pass, 0 fail. |
| `bash tests/test-supervisor.sh` | 26 pass, 0 fail; includes session-loss recovery and launch accounting cases. |
| `bash tests/test-efficiency-canary.sh` | 14 pass, 0 fail; includes restart rejection, durable failure, and canonical-proof checks. |

Total: 153 pass, 0 fail. No full suite, whole-tree ShellCheck, installer, doctor, or
rehearsal command was run.

## Limitations and boundary

The raw Cycle 19 runner log and event files are not committed in this worktree; the
available committed primary summary is the Cycle 19 terminal outcome and the explicit
runner/event attribution in Cycle 20 research. This audit therefore proves the
historical NO-GO and the integrated repair contracts, not an outer-run result. A fresh
Cycle 20 root and nonce must still demonstrate exactly two launches, zero restarts, one
terminal gate, and cleanup. The pre-existing untracked `.polylane-prompt.txt` and
`graphify-out/` were left untouched; this lane's commits contain only its two owned
documentation paths.

## Skill evidence

SKILL-EVIDENCE: superpowers:systematic-debugging — helped: the runner/event/commit trace separated the three historical recovery events and showed why the third one could persist in a process that had loaded pre-fix Bash functions.

SKILL-EVIDENCE: superpowers:verification-before-completion — helped: it required the six fresh focused command results, ancestry checks, and an evidence-only diff before the lane completion record.
