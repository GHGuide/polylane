# Verify — graph-c2 integrator repair

Run: `graph-c2-1786031267`

## Lane tips, merges, and independent review

- `lane/graph-c2-contract`: `f835e89ec51276c501085c66823e01a61907945e`
  (`feat: enforce graph routing outcome names`), merged by `16cf45e`.
- `lane/graph-c2-events`: `9cc80bdba7c292f243dd3babd1950736029055a6`
  (`feat(graph): add append-only event ledger`), merged by `1044e0f`.
- Both current tips are ancestors of the integrator branch. Re-running both
  `git merge --no-ff --no-edit` commands reported `Already up to date`.
- The contract diff is an additive compiler/validator, verification record, and
  focused test (421 inserted lines). The events diff is an additive append-only
  ledger, deterministic fixture generator, verification record, and focused test
  (500 inserted lines). The lane diffs are disjoint and contain no runner change.
- Independent correctness/security/maintainability review found no blocking lane
  defect. Integration uses the main-guarded `compile`/`validate` and
  `append`/`replay`/`verify` command boundaries without rewriting lane-owned code.

## Lane-focused tests first

Fresh repair-run commands, executed before any new implementation edit:

```text
bash tests/test-graph-contract.sh
test-graph-contract.sh: 36 pass, 0 fail

bash tests/test-graph-events.sh
test-graph-events.sh: 38 pass, 0 fail
```

Both exited 0.

## Original shadow RED/GREEN evidence

The preserved first-attempt report records the mandated behavioral RED before
the original runner integration. `bash tests/test-graph-shadow.sh` exited 1 with
`7 pass, 30 fail`; its first failure was the real main-flow fixture reaching the
first simulated worktree side effect without `graph.json` or `events.jsonl`
(fixture exit 91). Review-added dry-run and failed-node resume cases were also
observed RED before their corresponding runner changes.

The first implementation reached:

```text
bash tests/test-graph-contract.sh  # 36 pass, 0 fail
bash tests/test-graph-events.sh    # 38 pass, 0 fail
bash tests/test-graph-shadow.sh    # 46 pass, 0 fail
```

## Repair diagnosis and RED/GREEN evidence

The outer runner rejected the first GO with only:

```text
ACCEPTANCE-GATE: frozen focused/terminal checks failed; repair autonomously.
```

Preserved durable state showed the `m6.1` contract command and `m6.2`
events/shadow command as `fail`, but the acceptance runner redirected all command
output and the generic verdict line discarded even the failed subgoal and command.
The original trigger is not reproducible:

```text
# Exact m6.2 events + shadow chain
real 12.23

# Shadow suite alone before the repair test was added
test-graph-shadow.sh: 46 pass, 0 fail
real 9.84

# contract_acceptance_gate against a temporary copy of durable state
gate_rc=0
m6.1  pass
m6.2  pass
```

This refutes both a deterministic test failure and the 60-second acceptance
timeout as the cause. The autonomous defect exposed by the preserved evidence was
loss of failure diagnostics: a transient failure could only generate a generic
repair loop. A behavioral test using the real acceptance ledger was added before
the runner repair:

```text
bash tests/test-graph-shadow.sh
PASS shadow-acceptance-failure-stays-closed
FAIL shadow-acceptance-failure-actionable — output does not contain [g1: false [fail]]
test-graph-shadow.sh: 47 pass, 1 fail
```

The minimal runner change reports persisted checks whose status is `fail` at all
three existing focused/terminal failure exits, then returns the same nonzero
result. It does not alter selection, timeout, retry, scheduling, promotion, or
cleanup. GREEN evidence:

```text
bash tests/test-graph-contract.sh
test-graph-contract.sh: 36 pass, 0 fail

bash tests/test-graph-events.sh
test-graph-events.sh: 38 pass, 0 fail

bash tests/test-graph-shadow.sh
test-graph-shadow.sh: 48 pass, 0 fail
```

Directly affected existing contracts also passed:

```text
test-contract-acceptance.sh: 11 pass, 0 fail
test-verdict-repair.sh: 11 pass, 0 fail
test-orchestration-contract.sh: 4 pass, 0 fail
```

## Architecture and parity

The durable goal graph under `docs/polylane/` remains separate and untouched.
For contract-v2, the immutable per-cycle execution graph and append-only ledger
are created beside the manifest after contract preflight and before worktree/tmux
side effects. The runner still makes every scheduling, retry, repair, promotion,
and cleanup decision; graph helpers only validate and compare those decisions.
`POLYLANE_GRAPH_SHADOW=0` is the sole opt-out.

| Runner decision | Exact legal execution-graph route | Recorded terminal |
|---|---|---|
| `GO` | `verifier/passed -> promote`, `promote/succeeded -> complete` | `complete=succeeded` |
| `EXTERNAL-EVIDENCE-OPEN` | same route as `GO` | `complete=succeeded` |
| `NO-GO` | `verifier/failed -> repair`, `repair/failed -> halt` | `halt=succeeded` |
| `HALTED` builder/integrator | failed node `/failed -> halt` | `halt=succeeded` |
| resume builder | `lane:<name>/succeeded -> builders-joined` | builder remains replay-idempotent |
| resume integrator | `integrator/succeeded -> verifier` | integrator remains replay-idempotent |

Compile, validation, event, and route-parity failures emit `GRAPH-SHADOW:` and
return nonzero before promotion. The graph is never queried for ready work.

## Fresh graph/event sample

Generated from the cycle manifest through Bash with the real compiler, runner
shadow helpers, ledger writer, and replay command:

```json
{"graph_schema":1,"graph_id":"graph-v1-3136873992-1828","run_id":"graph-c2-1786031267","immutable":true,"routes":[{"from":"verifier","to":"promote","outcome":"passed"},{"from":"promote","to":"complete","outcome":"succeeded"}]}
```

First and last ledger rows:

```json
{"event_schema":1,"seq":1,"timestamp":1786034290,"run_id":"graph-c2-1786031267","graph_id":"graph-v1-3136873992-1828","node":"lane:graph-contract","from":"pending","to":"ready","attempt":0,"idempotency_key":"shadow:lane:graph-contract:0:ready","reason":"builder-done","artifact_hash":""}
{"event_schema":1,"seq":18,"timestamp":1786034292,"run_id":"graph-c2-1786031267","graph_id":"graph-v1-3136873992-1828","node":"complete","from":"running","to":"succeeded","attempt":0,"idempotency_key":"shadow:complete:0:succeeded","reason":"GO","artifact_hash":""}
```

Canonical replay:

```json
{"graph_id":"graph-v1-3136873992-1828","last_seq":18,"nodes":{"complete":{"attempt":0,"state":"succeeded"},"integrator":{"attempt":0,"state":"succeeded"},"lane:graph-contract":{"attempt":0,"state":"succeeded"},"lane:graph-events":{"attempt":0,"state":"succeeded"},"promote":{"attempt":0,"state":"succeeded"},"verifier":{"attempt":0,"state":"succeeded"}},"run_id":"graph-c2-1786031267"}
```

## Terminal gates

The full suite was invoked once for the repaired source through the required
cache path:

```text
bin/polylane-check.sh /Users/leonardo/Downloads/polylane/.polylane/check-cache/graph-integrator -- tests/run.sh
CHECK-CACHE: RUN source=2283139526:11442 command=tests/run.sh
SUMMARY: 852 passed, 0 failed, 57 test files
CHECK-CACHE: PASS source=2283139526:11442
```

All executable scripts were checked once after that suite:

```text
shellcheck -S warning bin/*.sh
exit 0 (no output)
```

`git diff --check` and Bash parsing of the runner and shadow test also exited 0.
No external evidence is required.

POLYLANE-VERDICT: GO run=graph-c2-1786031267
