# Verify — graph-contract

## RED — test first

Command:

```bash
bash tests/test-graph-contract.sh
```

Result: exit 1, `graph-compile-rc0` failed with `expected rc 0, got 127`
because `bin/polylane-graph.sh` did not exist. The initial run ended with
`0 pass, 34 fail`.

## GREEN — focused behavioral contract

Command:

```bash
bash tests/test-graph-contract.sh
```

Result: exit 0, `test-graph-contract.sh: 34 pass, 0 fail`.

The test covers deterministic atomic compile; schema-v1 graph invariants;
agent contracts; bounded repair loop; lexical parallel builder readiness;
blocked dependencies; and every pinned malformed-graph rejection.

## Shellcheck

Command:

```bash
shellcheck -S warning bin/polylane-graph.sh
```

Result: exit 0 with no output.

## Deferred items

- Execution-graph consumption, state mutation, and event integration remain
  intentionally outside this compiler/routing contract and this lane's ownership.
- No external evidence is required.
