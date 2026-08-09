# Runtime resilience verification

## Root cause

Cycle-17 ENOSPC recovery exposed four coupled false-progress paths: startup polling
treated quoted trust/onboarding prose as live UI; `merge_gate` appended host failure
text to an already committed integrator handoff; report/event writes could claim or
leave incomplete output; and the supervisor counted resource pressure as runner
crashes. A graphless recovery worktree also only looked in its own directory rather
than a same-repository primary worktree.

## Red reproductions

```sh
bash tests/test-wedge.sh
bash tests/test-write-report.sh
bash tests/test-graph-events.sh
bash tests/test-share-graph.sh
bash tests/test-verdict-repair.sh
bash tests/test-supervisor.sh
```

Before repair these deterministic failpoints showed two unwanted key sends, report
overwrite/success despite a simulated failure, event append mutation, a dirty READY
integrator with no canonical host record, a missing recovery graph link, and disk
pressure proceeding without a supervisor wait.

## Green verification

```sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/runtime-resilience" -- bash tests/test-wedge.sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/runtime-resilience" -- bash tests/test-lane-done.sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/runtime-resilience" -- bash tests/test-verdict-repair.sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/runtime-resilience" -- bash tests/test-graph-events.sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/runtime-resilience" -- bash tests/test-write-report.sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/runtime-resilience" -- bash tests/test-supervisor.sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/runtime-resilience" -- bash tests/test-share-graph.sh
shellcheck -S warning bin/polylane-run.sh bin/polylane-events.sh bin/polylane-supervisor.sh
```

All focused tests passed: wedge 29, lane-done 26, verdict-repair 40, graph-events
47 (including the 10,000-event linear fixture), write-report 33, supervisor 26,
and share-graph 11. The supervisor suite was additionally run three consecutive
times after deterministic cases passed.

## Disk-safety proof

`POLYLANE_TEST_REPORT_WRITE_FAIL=1` fails before rename, preserving the old report.
`POLYLANE_TEST_EVENT_APPEND_FAIL=1` fails before the one bounded locked append and
the prior JSONL ledger still passes replay/verify. `POLYLANE_DISK_PROBE` is a local
deterministic executable seam: the supervisor's fake probe reports 0GB then 10GB;
it waits, launches once, and spends zero crash-restart budget. No test allocates or
fills real disk space. Runner report, host-failure, and event writes independently
check fresh configured disk headroom.

## Resume proof

Host gate failures now atomically write
`docs/polylane/host-gate-failures/<run>.md` in the canonical host root. The
integrator's committed `READY-FOR-HOST-GATE` evidence is untouched, its Git status
remains clean, and `lane_done` accepts it after failure; a resume therefore skips
launching that completed integrator. Report success text is emitted only after a
successful publish rename.

## Graph proof

`share_graph` first uses the current root, then searches only Git worktrees in the
same resolved common Git directory. The recovery fixture receives a read-only link
to the primary graph; an existing path is never overwritten, and unrelated
repositories cannot enter the search.

## Skill delivery

SKILL-READ: superpowers:systematic-debugging | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/systematic-debugging/SKILL.md | 808fc5717aa88ad65efff312b11c186294d3e6ee301afb584e2f86599b137787

SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 5c5e95830754bbdd838213fa05fc8f07523f591fd558fd3c86031ffd479f7a9e

SKILL-READ: engineering:incident-response | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/incident-response/SKILL.md | 9eaa7a974c90395ac7116e82710f74546f38e69f735d78f684ee13fd79646e9a

SKILL-EVIDENCE: superpowers:systematic-debugging — helped: traced the ENOSPC sequence to host evidence mutation and unguarded durable-write boundaries before changing code.

SKILL-EVIDENCE: engineering:testing-strategy — helped: led to isolated red failpoints for key injection, report publish, event append, disk probe, resume cleanliness, and graph ownership.

SKILL-EVIDENCE: engineering:incident-response — helped: kept host failure evidence factual, canonical, atomic, and separate from the completed worker checkout.
