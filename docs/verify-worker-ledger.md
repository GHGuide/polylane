# Worker ledger verification — m14.3

## Conflict reproduction and repair

Cycle 13 allowed each worktree to treat its positional `PROJECT` argument as
the durable worker-state authority.  Two checkouts of one logical project each
therefore acquired a different `docs/polylane/workers/.lock`, counted a
different `history.jsonl`, and could both allocate sequence 27.

The regression test reproduces that topology with real Git worktrees:

```bash
CANONICAL=/tmp/.../canonical
LANE_A=/tmp/.../lane-a
LANE_B=/tmp/.../lane-b
git -C "$CANONICAL" worktree add -b worker-ledger-a "$LANE_A"
git -C "$CANONICAL" worktree add -b worker-ledger-b "$LANE_B"
POLYLANE_PROJECT_ROOT="$CANONICAL" POLYLANE_WORKERS_DIR="$CANONICAL/docs/polylane/workers" \
  bin/polylane-workers.sh capsule "$LANE_A" alpha ...
POLYLANE_PROJECT_ROOT="$CANONICAL" POLYLANE_WORKERS_DIR="$CANONICAL/docs/polylane/workers" \
  bin/polylane-workers.sh capsule "$LANE_B" beta ...
```

`tests/test-worker-canonical-state.sh` then concurrently updates both
capsules, sends two messages, and acknowledges both messages from separate
worktrees.  Before this repair the canonical history did not exist, both lane
directories acquired independent histories, and cross-worktree sends failed
because the recipient identity was invisible.

The repair resolves the paired launcher exports `POLYLANE_PROJECT_ROOT` and
the matching `POLYLANE_WORKERS_DIR` once per operation.  The supplied project
must be that root or a registered worktree with the same Git common directory;
an unrelated Git repository is rejected.  Every write then derives the state
directory, lock, sequence allocator, capsule files, and history from that
physical canonical root.  Reads use the same resolution.  A root alone, or a
plain standalone directory, intentionally retains local behavior for backward
compatibility.  Relay imports remain constrained to the declared canonical
root's `.polylane/` directory.

## GREEN evidence

Run on 2026-08-08:

```text
$ bin/polylane-check.sh "$PWD/.polylane/check-cache/worker-ledger" -- bash tests/test-worker-canonical-state.sh
test-worker-canonical-state.sh: 23 pass, 0 fail
CHECK-CACHE: PASS

$ bin/polylane-check.sh "$PWD/.polylane/check-cache/worker-ledger" -- bash tests/test-workers.sh
test-workers.sh: 45 pass, 0 fail
CHECK-CACHE: PASS

$ bin/polylane-check.sh "$PWD/.polylane/check-cache/worker-ledger" -- tests/run.sh
SUMMARY: 1801 passed, 0 failed, 97 test files
CHECK-CACHE: PASS

$ bin/polylane-check.sh "$PWD/.polylane/check-cache/worker-ledger" -- shellcheck -S warning bin/*.sh
# exit 0; no diagnostics
```

The canonical-state test asserts all of the following from the shared history:

- no worker runtime is created in either lane;
- concurrent capsule mutations succeed;
- message IDs are unique and follow history order;
- both acknowledgements remain in canonical history and reads see an empty
  canonical inbox after acknowledgement;
- all history sequence numbers are unique and strictly increasing;
- a relay located in a lane is rejected even when that lane invoked the API.

SKILL-EVIDENCE: test-driven-development — read
`/Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md` once; used the real-worktree capsule, message, and acknowledgement regression to pin the canonical behavior, and retained the required hermetic standalone fixture.

SKILL-EVIDENCE: verification-before-completion — read
`/Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/verification-before-completion/SKILL.md` once; recorded fresh targeted command output, ShellCheck, and the full-suite result before committing.

SKILL-EVIDENCE: architecture — read
`/Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/architecture/SKILL.md` once; selected the explicit canonical-root contract with standalone fallback, rather than granting worktrees independent state authority.

SKILL-EVIDENCE: process-optimization — read
`/Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/process-optimization/SKILL.md` once; removed the duplicate allocation handoff by making all mutations and reads converge on one lock and history.
