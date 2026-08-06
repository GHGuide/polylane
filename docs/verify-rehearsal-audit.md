# Rehearsal audit

## Original RED

The legacy fixture was not contract v2: it had only three loose prompts and a
minimal manifest. It omitted durable goal and acceptance state, INDEX, cycle
plan, installed skill kit, authoritative graph/events, and supervisor state.

Focused RED command:

```text
env POLYLANE_REHEARSE=1 bash tests/test-rehearse.sh
FAIL rehearse-go-reaches-promote — expected [0] got [1]
FAIL rehearse-go-contract-v2 — output does not contain [REHEARSE-GO contract-v2=1 promoted=1 cleaned=1 leaks=0]
FAIL rehearse-nogo-gate-holds — expected [0] got [1]
FAIL rehearse-nogo-contract-v2 — output does not contain [REHEARSE-NOGO contract-v2=1 promoted=0 evidence=1 bounded=1 leaks=0]
```

## Contract-v2 fixture

The fixture now commits durable GOAL, ACCEPTANCE, INDEX, and cycle-plan state;
uses a structured Codex skill kit; stamps every strict prompt with its current
nonce; assigns disjoint `a/**` and `b/**` builder scopes; and compiles an
immutable authoritative graph with an append-only event ledger. The manifest
names contract version 2 and supervisor lifecycle ownership. The bounded mock
validates graph identity and ledger validity before every launch, commits each
lane's current-run marker, and sleeps for at most 30 seconds.

GO checks promoted `a/x` and `b/y`, GO report, exactly three mock launches,
three graph-authority witnesses, no tmux or worktree leak before cleanup, and
removed temporary root after cleanup. NO-GO checks retained NO-GO verdict
evidence and its live session/worktrees, withheld base promotion, and made
exactly three launches (no repair/restart loop) before fixture-owned cleanup.

Expected local traces:

```text
REHEARSE-GO contract-v2=1 promoted=1 cleaned=1 leaks=0
REHEARSE-NOGO contract-v2=1 promoted=0 evidence=1 retained=1 bounded=1 cleaned=1
```

## Local execution constraint

This sandbox denies tmux Unix sockets before the mock launches:

```text
error connecting to /private/tmp/tmux-501/default (Operation not permitted)
```

Therefore no GO/NO-GO trace was claimed from this environment. The failure is
before lifecycle execution; the fixture's own leak check still cleans its
temporary root on every exit. The required local verification remains:

```bash
bin/polylane-doctor.sh --rehearse
shellcheck -S warning bin/*.sh
```

## DEFERRED

DEFERRED: none
