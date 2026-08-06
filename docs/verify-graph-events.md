# Verify — graph-events

## RED (identifier grammar)

Command:

```bash
bash tests/test-graph-events.sh
```

Result: exit `1`. The expected missing-behavior failure was:

```text
FAIL events-malformed-leading-node-id — expected non-zero rc, got 0
test-graph-events.sh: 37 pass, 1 fail
```

The append-side identifier check accepted `.alpha`, even though the ledger
schema requires an identifier to begin with an alphanumeric character. The
test used `pending -> ready`, so its failure isolated validation rather than a
from-state rejection.

## GREEN

Command:

```bash
bash tests/test-graph-events.sh
```

Result: exit `0` with `test-graph-events.sh: 38 pass, 0 fail`.

The focused contract covers legal and illegal transitions, malformed
identifiers, wrong from-state, idempotency behavior, corrupt/mixed/gapped
history rejection, terminal state protection, canonical deterministic replay,
concurrent writers, and a valid deterministic 10,000-event fixture.

## ShellCheck

Command:

```bash
shellcheck -S warning bin/polylane-events.sh bin/polylane-graph-bench.sh
```

Result: exit `0` with no warnings.

## Deferred

The benchmark threshold/performance gate is deliberately deferred to the later
integration stage. This lane only creates deterministic synthetic graph/event
fixtures, as required by the frozen contract. The full repository suite was not
run during this focused lane cadence.
