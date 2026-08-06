# Cycle 9 integration certification

Run: `c9-product-autonomy-1786054003`
Branch: `lane/c9-integrator`
Verdict: READY-FOR-HOST-GATE

## Integrated tips

All requested current branch tips are ancestors of this integrator branch:

- `lane/c9-product-foundation` — `5d54f649f4dbe1520bba0c0284aeb18283b02aa1`
- `lane/c9-worker-efficiency` — `5d71629626ba024420312b619f80c137c7c8b076`
- `lane/c9-quality-runtime` — `8d08d9b83b9321e7e2aa766d74f0a304f4dadfad`
- `lane/c9-control-docs` — `1ee85b17941722affd734efa95d18dc0e1d9d762`

No merge conflict remained: the current tips were already contained by the prior
cycle-9 merge history. The canonical manifest contains only `gpt-*` Codex model
IDs and exactly three unique, bounded quality judges.

## Repair evidence

The preserved outer gate named only frozen acceptance `m2.1`: the rehearsal
created skill directories without resolvable `SKILL.md` files. The repair now
creates four exact fixture skills, and `tests/test-rehearse.sh` also propagates
`finish` failures instead of masking them. Focused result: 6 pass, 0 fail.

Additional integration contract repairs:

- malformed or wrongly typed benchmark metric containers now remain `null`
  without aborting; regression suite: 21 pass, 0 fail;
- judge failure uses a typed `judge` repair packet, preserves its own archive,
  names `docs/polylane/judges/judges.json`, and permits one bounded repair only;
- the dashboard reads durable cleanup from `docs/polylane/run-stats.json` and
  falls back to canonical max-state `ultimate` for the displayed goal;
- README skill-kit bounds and the scout JSONL outcome-ledger path now match the
  executable contracts.

## Mechanical verification

- Focused affected coverage: 19 suites, 428 pass, 0 fail. This includes corpus,
  discovery, scout outcomes, graph contract/events/shadow/authority/benchmark,
  bounded judge repair, dashboard, orchestration, installers, and skill parity.
- Final terminal gate, run exactly once through the integrator check cache:
  `bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" -- tests/run.sh`
  — **1171 passed, 0 failed, 76 test files**. Cache log:
  `.polylane/check-cache/integrator/1557743017-64.output`.
- `shellcheck -S warning bin/*.sh` — pass, zero warnings. Cache log:
  `.polylane/check-cache/integrator/1608172591-955.output`.
- `bash -n bin/*.sh` — pass. Every new cycle-9 script is executable and
  main-guarded; Codex installation copies all `bin/*.sh` and benchmarks.
- Canonical `bin/polylane-scope.sh check-static` — pass.
- `bin/polylane-seams.sh scan "$PWD"` — pass, zero findings.
- `bin/polylane-markers.sh check-docs references/` — pass.
- Graph performance: 10,000-event replay 6s; warm ready 56ms; warm append
  112ms; packet samples 1871/1848/1869ms. Old graph compatibility is covered
  by the graph contract, authority, shadow, and benchmark suites.

## Product and control-room proof

The mock adapter ran all five versioned `schema-v1` corpus cases with isolated
workdirs and durable JSONL results: 0 adapter failures, no unknown metrics,
mean tokens 400, interventions 0, completion 1, product quality 0.8, score 0.85.
Evidence: `.polylane/evidence/product-benchmark/results.jsonl`.

Both one-shot dashboard formats were executed against the canonical manifest.
Text and JSON agree on run `c9-product-autonomy-1786054003`, cycle 9, canonical
goal, graph `graph-v1-2366033565-4374`, lane states, spend, verdict, cleanup, and
next action. Cache logs:
`.polylane/check-cache/integrator/1945985529-137.output` and
`.polylane/check-cache/integrator/2854008457-144.output`.

## Judge evidence

Exactly three manifest judges ran in isolation and the aggregate passed:

- `product-behavior`: 46 pass, 0 fail;
- `worker-economy`: 32 pass, 0 fail;
- `runtime-truth`: 40 pass, 0 fail.

Aggregate: `.polylane/evidence/integrator-judges/judges.json`; all three entries
have `status=passed` and `exit_code=0`.

## Changed files

`README.md`, `bin/polylane-dashboard.sh`, `bin/polylane-product-benchmark.sh`,
`bin/polylane-rehearse.sh`, `bin/polylane-run.sh`,
`references/skill-scout.md`, `tests/test-advanced-runtime.sh`,
`tests/test-dashboard.sh`, `tests/test-docs-truth.sh`,
`tests/test-product-benchmark.sh`, `tests/test-rehearse.sh`,
`docs/status-integrator.md`, and `docs/verify-integration.md`.

## DEFERRED

DEFERRED: the frozen `m2.1` live GO+NO-GO rehearsal remains for the outer host
gate. After the fixture repair, this workspace still cannot produce that proof
because tmux socket creation fails with `Operation not permitted`; cache log
`.polylane/check-cache/integrator/1779000845-156.output`. This is not a PASS.

POLYLANE-VERDICT: READY-FOR-HOST-GATE run=c9-product-autonomy-1786054003
