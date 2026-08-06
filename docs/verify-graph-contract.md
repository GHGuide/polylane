# Verify — graph-contract

## RED — test first

Command:

```bash
bash tests/test-graph-contract.sh
```

Result: exit 1, `graph-compile-rc0` failed with `expected rc 0, got 127`
because `bin/polylane-graph.sh` did not exist. The initial run ended with
`0 pass, 34 fail`.

Additional RED command:

```bash
bash tests/test-graph-contract.sh
```

Result: exit 1, `invalid-rc-non-string-outcome` failed with
`expected [2] got [0]`, and `invalid-line-non-string-outcome` failed with
`expected [1] got [0]`. The run ended with `34 pass, 2 fail`, proving the
validator accepted numeric routing outcomes.

## GREEN — focused behavioral contract

Command:

```bash
bash tests/test-graph-contract.sh
```

Result: exit 0, `test-graph-contract.sh: 36 pass, 0 fail`.

The test covers deterministic atomic compile; schema-v1 graph invariants;
agent contracts; bounded repair loop; lexical parallel builder readiness;
blocked dependencies; declared string routing outcomes; and every pinned
malformed-graph rejection.

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
