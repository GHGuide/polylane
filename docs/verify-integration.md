# Cycle 3 integration verification — authoritative graph runtime

Run: `graph-c3-20260806-194631`

Locked source: `docs/polylane/cycle-3-plan.md`

## Integrated tips and scope

- Graph performance tip: `972fbb68de5e5b59ab5fe585be1a256e34c4a15c`
- Graph authority tip: `32a13792effdce9c8eeb9da424166f73b72a5c39`
- Performance merge: `6adddbbbd8c999fb703dd5f2b907d716129996d4`
- Authority merge: `51d1e35e26c51b59ec79968dbd57d49cb8f8a370`

Exact ancestry proof:

```bash
git merge-base --is-ancestor 972fbb68de5e5b59ab5fe585be1a256e34c4a15c HEAD
git merge-base --is-ancestor 32a13792effdce9c8eeb9da424166f73b72a5c39 HEAD
```

Both commands returned 0. `git diff --name-only 4c42435..TIP` confirmed that
each lane changed only its declared scripts/tests plus its required
`docs/verify-*` and exact run-scoped `docs/status-*` files. There was no product
write-set violation.

## Integration-only repairs

- `ee02bc1c20019f3f4b6e8909f10759ce486eb5f7` — test-first linear graph
  validation for the 10,000-lane fixture.
- `6175552cbad217e19fb53c7aa29aa5aaf970af7a` — runner auto-checkpoint of
  authoritative retry, terminal-route, resume-order, and negative-test repair.
- `25a97161ffac7bec4896d024c169a38ebc1f43a3` — runner auto-checkpoint of
  idempotent resume and verifier-before-action ordering repair.
- `077787c8d05ff7ec0b3593f223d7c00478c09c5a` — compiled-graph/ledger fixture
  alignment and exact checkpoint fallback coverage.

`82b2f09a94b8d516013c5ee31b13a478016df92f` is the runner's run-start
checkpoint that removed stale prior-cycle integrator evidence before this file
was regenerated; it contains no product change.

## Monitored cross-regression: RED to GREEN

Before repair, the mandated historical observation for the exact command was
over two minutes followed by termination with rc 143. I independently ran the
same merged-tip command:

```bash
bash tests/test-graph-events.sh
```

It was still inside the 10,000-lane graph validation after 30 seconds; only the
first 32 assertions had completed, no fixture assertion had been reached, and I
terminated it. The added bounded regression then failed for the intended
reason: the edge endpoint/outcome jq validation exceeded its 10-second CPU
limit, fixture compile returned rc 2 after 11 seconds, and the test reported
`32 pass, 7 fail`.

After indexed validation and linear queue traversals, the unchanged command
reported `42 pass, 0 fail`. Its 10,000-lane / 10,000-row public fixture build
reported 7 seconds in the focused certification run (6 seconds in the full
suite). The fixture was not reduced, the local/CI ceilings were not raised, and
all 10,000 ledger rows are now proven to name nodes declared by the compiled
production graph.

## Mandatory focused commands

Run sequentially and without check-cache reuse after all merges and repairs:

```bash
bash tests/test-graph-contract.sh
bash tests/test-graph-events.sh
bash tests/test-graph-shadow.sh
bash tests/test-graph-authority.sh
bash tests/test-runtime-survival.sh
bash tests/test-graph-benchmark.sh
```

Observed totals:

- `test-graph-contract.sh`: 41 pass, 0 fail.
- `test-graph-events.sh`: 42 pass, 0 fail.
- `test-graph-shadow.sh`: 48 pass, 0 fail.
- `test-graph-authority.sh`: 43 pass, 0 fail.
- `test-runtime-survival.sh`: 2 pass, 0 fail.
- `test-graph-benchmark.sh`: 17 pass, 0 fail.

Supplementary seam commands were also run:

```bash
bash tests/test-verdict-repair.sh
bash tests/test-agent-adapter.sh
bash tests/test-lane-done.sh
bash tests/test-supervisor.sh
```

They reported 11/11, 39/39, 19/19, and 22/22 passing assertions,
respectively.

## Frozen benchmark — three fresh runs

Exact command, run three separate times after the final source/test repair:

```bash
bash tests/test-graph-benchmark.sh
```

No threshold or environment edit was made between samples.

| Fresh run | Warm ready | Warm append | Complete packets | Assertions |
| --- | ---: | ---: | --- | ---: |
| 1 | 62 ms | 120 ms | 1901 ms, 2001 ms, 1897 ms | 17/17 |
| 2 | 91 ms | 116 ms | 1969 ms, 1969 ms, 1993 ms | 17/17 |
| 3 | 61 ms | 116 ms | 1849 ms, 1857 ms, 1836 ms | 17/17 |

The slowest complete production-CLI packet was 2001 ms against the frozen
10,000 ms local ceiling. The slowest warm ready query was 91 ms and the slowest
warm append was 120 ms against their frozen 250 ms ceilings.

The benchmark exercises the production compiler, graph validation, ready
query, event append, ledger verify, and replay. Its negative assertions cover a
malformed checkpoint and a replaced/incomplete ledger. The focused events
suite additionally proves literal exact replay after a malformed checkpoint,
valid-checkpoint/inode mismatch, and complete-row ledger truncation; JSONL
alone reconstructs the exact `last_seq`, node state, and attempt.

## Authority and recovery audit

- Graph authority precedes tmux side effects:
  `authority-blocked-lane-no-new-pane` proves no `new-session`/`new_pane` call
  occurs before readiness; `authority-gate-before-every-verifier-action` proves
  admission precedes each verifier attempt.
- Every compiled edge/loop endpoint and outcome is declared, every nonterminal
  has an outgoing route, and every node reaches a terminal. The missing
  exhausted-verifier route was repaired as an explicit `verifier/failed ->
  halt` edge.
- Join-all and route-any are covered by
  `ready-join-blocked-by-unmatched-loop-predecessor`,
  `ready-ordinary-failed-route-and-retry`, and
  `ready-ordinary-failed-route-after-retry-exhausted`.
- Authoritative retry attempt 1, direct GO, repaired NO-GO, HALTED, start-first
  resume, duplicate resume, and duplicate start are replayed through the real
  graph/events CLIs in `test-graph-authority.sh`. Shadow compatibility covers
  GO, EXTERNAL-EVIDENCE-OPEN, NO-GO, HALTED, resume, and failed-node retry.
- Checkpoint corruption or identity mismatch never authorizes work: it either
  strictly replays JSONL or fails with `EVENT-INVALID`. Replaced and incomplete
  ledgers cannot inherit a stale successful checkpoint.
- `test-agent-adapter.sh` proves Codex `workspace-write` receives only the
  canonical `git rev-parse --git-common-dir` path via `--add-dir`; `read-only`
  and explicit `danger-full-access` receive no added directory.
- `test-lane-done.sh` proves only a `graphify-out` symlink resolving to the
  runner's canonical graph directory is ignored; any other untracked file
  blocks DONE.
- `test-runtime-survival.sh` proves a vanished owned tmux session exits with
  recoverable rc 75 and `SESSION-LOST:` instead of polling forever;
  `test-supervisor.sh` proves bounded resume and restart-cap behavior.

## Terminal certification

Exact uncached commands after the focused set was green:

```bash
tests/run.sh
shellcheck -S warning bin/*.sh
```

`tests/run.sh` reported `SUMMARY: 929 passed, 0 failed, 60 test files`.
ShellCheck returned 0 and emitted no warnings.

Final repository checks before this evidence commit:

```bash
git diff --check 4c42435b6391b228388feb93f79a15757d02cf68..HEAD
git status --short --branch
```

The diff check emitted nothing. The only worktree path outside this evidence
file was the untracked runner-owned `graphify-out` symlink resolving to
`/Users/leonardo/Downloads/polylane/graphify-out`; no other ignored or dirty
path existed.

POLYLANE-VERDICT: GO run=graph-c3-20260806-194631
