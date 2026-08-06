# Verify — graph-c2 integrator

Run: `graph-c2-1786031267`

## Lane merges and independent review

- `lane/graph-c2-contract` tip: `f835e89ec51276c501085c66823e01a61907945e`
  (`feat: enforce graph routing outcome names`), merged by `16cf45e`.
- `lane/graph-c2-events` tip: `9cc80bdba7c292f243dd3babd1950736029055a6`
  (`feat(graph): add append-only event ledger`), merged by `1044e0f`.
- The branches shared base `a5af8bc` and had disjoint additions. Both merges were
  conflict-free; no lane-owned graph/event source or test was rewritten.
- Independent correctness/security/maintainability review found no blocking lane
  issue. The integration uses only the lanes' main-guarded `compile`, `validate`,
  `append`, `replay`, and `verify` command boundaries.

## Lane-focused tests first

Commands, run immediately after the merges:

```text
bash tests/test-graph-contract.sh
test-graph-contract.sh: 36 pass, 0 fail

bash tests/test-graph-events.sh
test-graph-events.sh: 38 pass, 0 fail
```

Both exited 0.

## RED — behavioral tests before runner edits

The initial `bash tests/test-graph-shadow.sh` run exited 1 with `7 pass, 30 fail`.
The first break was the intended main-flow failure:

```text
FAIL shadow-main-preflight-before-side-effects — expected [0] got [91]
FAIL shadow-main-order — expected [... side-effect ... promote] got [preflight-basic
contract-v2]
```

Exit 91 came from the real main-flow fixture refusing to enter the first simulated
worktree side effect because `.polylane/graph.json` and `.polylane/events.jsonl`
did not exist. The remaining failures showed that the shadow helper behavior was
absent.

Two review-discovered cases also followed RED before their runner changes:

```text
# Only POLYLANE_GRAPH_SHADOW=0 may opt out; --dry-run is still contract-v2.
test-graph-shadow.sh: 38 pass, 2 fail
FAIL shadow-dry-run-graph-exists
FAIL shadow-dry-run-events-exist

# A resumed failed node must advance its event attempt/idempotency keys.
test-graph-shadow.sh: 43 pass, 3 fail
FAIL shadow-resume-failed-retries
FAIL shadow-resume-failed-succeeded — expected [succeeded] got [ready]
FAIL shadow-resume-failed-next-attempt — expected [1] got [0]
```

## GREEN — shadow integration

After the minimal runner changes:

```text
bash tests/test-graph-contract.sh
test-graph-contract.sh: 36 pass, 0 fail

bash tests/test-graph-events.sh
test-graph-events.sh: 38 pass, 0 fail

bash tests/test-graph-shadow.sh
test-graph-shadow.sh: 46 pass, 0 fail
```

The shadow test executes the real runner main order and graph/event CLIs. It pins
pre-side-effect atomic initialization, invalid graph/event rejection, GO,
EXTERNAL-EVIDENCE-OPEN, NO-GO, HALTED, resume idempotency and retry attempts,
explicit disablement, dry-run shadowing, and route mismatch fail-closed behavior.

Affected existing contracts also passed:

```text
test-orchestration-contract.sh: 4 pass, 0 fail
test-dryrun-pure.sh: 2 pass, 0 fail
test-verdict-repair.sh: 11 pass, 0 fail
test-parse-verdict.sh: 21 pass, 0 fail
test-promote.sh: 4 pass, 0 fail
test-session-resume.sh: 7 pass, 0 fail
```

## Architecture and parity

The goal graph in `docs/polylane/` remains separate and untouched. The immutable
per-cycle execution graph is compiled beside the manifest and is observational:
the runner never calls graph ready-routing, and its existing poll timing, retries,
repair budget, promotion, and cleanup continue to make every scheduling decision.
Before promotion, shadow helpers validate the graph and ledger, compare the chosen
route exactly, and append replay-safe events. Any failure emits `GRAPH-SHADOW:` and
returns nonzero.

| Runner decision | Exact legal execution-graph route | Event terminal |
|---|---|---|
| `GO` | `verifier/passed -> promote`, `promote/succeeded -> complete` | `complete=succeeded` |
| `EXTERNAL-EVIDENCE-OPEN` | same promote/complete route as GO | `complete=succeeded` |
| `NO-GO` | `verifier/failed -> repair`, `repair/failed -> halt` | `halt=succeeded` |
| `HALTED` | failed builder or integrator `/failed -> halt` | `halt=succeeded` |
| resume builder | `lane:<name>/succeeded -> builders-joined` | builder remains `succeeded` idempotently |
| resume integrator | `integrator/succeeded -> verifier` | integrator remains `succeeded` idempotently |

`POLYLANE_GRAPH_SHADOW=0` is the only opt-out. Its main-flow test creates no graph
artifacts and reaches the same promotion stub as the pre-integration runner.

## Graph/event sample

Generated through Bash with the real compiler, runner shadow helpers, and event
replay:

```json
{"graph_schema":1,"graph_id":"graph-v1-2068893318-350","run_id":"shadow-run","immutable":true,"routes":[{"from":"verifier","to":"promote","outcome":"passed"},{"from":"promote","to":"complete","outcome":"succeeded"}]}
```

Representative first and terminal event rows:

```json
{"event_schema":1,"seq":1,"run_id":"shadow-run","graph_id":"graph-v1-2068893318-350","node":"lane:builder","from":"pending","to":"ready","attempt":0,"idempotency_key":"shadow:lane:builder:0:ready","reason":"builder-done"}
{"event_schema":1,"seq":15,"run_id":"shadow-run","graph_id":"graph-v1-2068893318-350","node":"complete","from":"running","to":"succeeded","attempt":0,"idempotency_key":"shadow:complete:0:succeeded","reason":"GO"}
```

Canonical replay:

```json
{"graph_id":"graph-v1-2068893318-350","last_seq":15,"nodes":{"complete":{"attempt":0,"state":"succeeded"},"integrator":{"attempt":0,"state":"succeeded"},"lane:builder":{"attempt":0,"state":"succeeded"},"promote":{"attempt":0,"state":"succeeded"},"verifier":{"attempt":0,"state":"succeeded"}},"run_id":"shadow-run"}
```

## Full suite and ShellCheck

Required cache-routed command:

```text
bin/polylane-check.sh /Users/leonardo/Downloads/polylane/.polylane/check-cache/graph-integrator -- tests/run.sh
CHECK-CACHE: FAIL rc=1 source=2929477988:12883
SUMMARY: 847 passed, 3 failed, 57 test files
FAILED FILES: test-dashboard.sh
```

All three failures were the manifest row assertions in `test-dashboard.sh`. The
test's `run_frame` stops the dashboard as soon as the capture file is merely
nonempty, so it can observe the header before the manifest rows are printed. A
focused reproduction immediately afterward passed and did not touch integration
source:

```text
bash tests/test-dashboard.sh
test-dashboard.sh: 10 pass, 0 fail
```

The dashboard and its test are outside this lane's ownership. This verification
record is the required owned source change before retrying the cached full suite.

The exact cache-routed command was then rerun on the new fingerprint and passed:

```text
CHECK-CACHE: RUN source=3259380237:12962 command=tests/run.sh
SUMMARY: 850 passed, 0 failed, 57 test files
CHECK-CACHE: PASS source=3259380237:12962
```

ShellCheck was run once across every executable script and passed with no output:

```text
shellcheck -S warning bin/*.sh
exit 0
```

No external evidence is required.

POLYLANE-VERDICT: GO run=graph-c2-1786031267
