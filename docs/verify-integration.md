# Cycle 9 integration verification

Run: `c9-product-autonomy-1786054003`  
Branch: `lane/c9-integrator`

## Verdict basis

- Current tips are contained: `lane/c9-product-foundation` at `5d54f649f4dbe1520bba0c0284aeb18283b02aa1`, `lane/c9-worker-efficiency` at `5d71629626ba024420312b619f80c137c7c8b076`, `lane/c9-quality-runtime` at `8d08d9b83b9321e7e2aa766d74f0a304f4dadfad`, and `lane/c9-control-docs` at `1ee85b17941722affd734efa95d18dc0e1d9d762`.
- `bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" -- tests/run.sh`: **1160 passed, 0 failed, 76 test files**. Log: `.polylane/check-cache/integrator/1557743017-64.output`.
- `bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" -- shellcheck -S warning bin/*.sh`: exit 0 across all 37 scripts. Log: `.polylane/check-cache/integrator/1608172591-955.output`.
- `bin/polylane-seams.sh scan "$PWD"`: exit 0, no production dangling seam. Cached log: `.polylane/check-cache/integrator/4250095565-114.output`.
- No canonical `.polylane/run.json` exists in this checkout, so `bin/polylane-scope.sh check-static` had no canonical target and was not represented as PASS.
- `graphify-out` was queried read-only first for `polylane-run`, `polylane-graph`, dashboard, scout, and models; it was not rebuilt or committed.

## Focused and affected evidence

- Frozen m8 acceptance tests: product benchmark 20/0; discovery graph 25/0; Codex profile 8/0; prompt optimizer 6/0; advanced runtime 11/0; graph quality loop 4/0; judges 9/0; scout outcomes 18/0; control room 10/0.
- Additional cross-lane gates: dashboard 35/0; scout 22/0; orchestration contract 7/0; verdict repair 26/0; docs truth 17/0; skill parity 18/0; installers 11/0.
- Graph compatibility and replay: graph contract 42/0, graph events 43/0, graph shadow 52/0, graph authority 50/0, graph benchmark 17/0. Final benchmark timings were ready 62 ms, append 116 ms, and packet samples 1873–1888 ms.
- Runtime/quoting/portability: agent adapter 39/0, models 20/0, intensity 20/0, runtime recovery 5/0, runtime refresh 11/0, runtime survival 2/0, prompt economy 17/0, prompt lint 18/0, marker contract 9/0, and seams 5/0.
- A pre-final terminal pass exposed two synthetic-manifest failures in `test-verdict-repair.sh` (1158/2). The fixture was aligned with the advanced seam contract, then passed 26/0; the final post-fix terminal invocation produced the 1160/0 result above.

## Runtime demonstrations

- Mock product corpus: all five `benchmarks/schema-v1` cases produced one isolated result each; `adapter_failures=0`, `mean_wall_time_s=0`, `mean_tokens=400`, `mean_interventions=0`, `mean_completion=1`, `mean_product_quality=0.8`, and `mean_score=0.85`.
- Exactly three judges ran independently: correctness (`test-product-benchmark.sh`, 20/0), architecture (`test-graph-quality-loop.sh`, 4/0), and operability (`test-control-room.sh`, 10/0). Aggregate status is `passed`; all three exits are 0 and each has a separate evidence file under `.polylane/judges-integrator/`.
- Dashboard JSON and text snapshots both used run `c9-product-autonomy-1786054003`, cycle 9, graph `graph-v1-3480793479-779`, ready node `start`, canonical goal, lane/model state, spend, and next action. The replay regression additionally proves three admitted events advance readiness from `start` to `lane:api`.

## Integration fixes

- Benchmark scoring now records completion and product quality, preserves unknown metrics as `null`, and treats valid-but-wrong-shaped adapter JSON as unknown instead of aborting.
- Discovery persists contradictions, blocks lock while any are open, records bounded typed resolutions, and applies left/right resolution to accepted strategy answers.
- Codex launch admission rejects every non-`gpt-*` integrator, lane, available-model, and runtime override path; the schema example contains no Claude model.
- Contract-v2 prompt admission enforces mandatory blocks plus token/byte budgets before initial launch, respawn, and integrator repair. Graph-authority fixtures now satisfy that same boundary.
- Scout skill resolution rejects traversal-shaped identifiers and uses exact installed `SKILL.md` paths with isolated outcome-ledger tests.
- The runner routes seams through the single advanced-runtime adapter. The seam scanner excludes intentional test fixtures while retaining actionable production evidence.
- Judges require exactly three unique lenses, cap timeouts at 300 seconds, stage evidence privately until all commands finish, and feed one typed `judge-repair` loop. Old graphs without judges still validate and replay.
- Dashboard snapshots consume nonce-aware state, max-state, validated graph replay, spend `.cost`, report, and cleanup data; missing facts remain null/unknown in JSON and text.
- Claude-root and Codex-overlay skills remain separate files, both point to the shared frozen reference, and both describe benchmark, discovery, prompt, advanced seam, judge, and control-room behavior consistently.

## Changed files

- Contract/docs: `.polylane/SCHEMA.md`, `README.md`, `SKILL.md`, `codex/SKILL.md`, `codex/install.sh`, `docs/polylane/cycle-9-plan.md`, `references/cycle-9-control-room.md`, `references/documentation.md`, `references/model-selection.md`, `references/planning.md`, `references/prompt-blocks.md`, `references/skill-scout.md`.
- Corpus: `benchmarks/schema-v1/dog-walk-route.json`, `pantry-planner.json`, `repair-reminder.json`, `shift-handoff.json`, `study-circle.json`.
- Runtime: `bin/polylane-advanced.sh`, `polylane-dashboard.sh`, `polylane-discovery.sh`, `polylane-graph.sh`, `polylane-judges.sh`, `polylane-models.sh`, `polylane-product-benchmark.sh`, `polylane-promptopt.sh`, `polylane-run.sh`, `polylane-scout.sh`, `polylane-seams.sh`.
- Evidence/status: `docs/status-control-docs.md`, `docs/status-integrator.md`, `docs/status-product-foundation.md`, `docs/status-quality-runtime.md`, `docs/status-worker-efficiency.md`, `docs/verify-control-docs.md`, `docs/verify-integration.md`, `docs/verify-product-foundation.md`, `docs/verify-quality-runtime.md`, `docs/verify-worker-efficiency.md`.
- Tests: `tests/test-advanced-runtime.sh`, `test-codex-profile.sh`, `test-control-room.sh`, `test-dashboard.sh`, `test-discovery-graph.sh`, `test-docs-truth.sh`, `test-graph-authority.sh`, `test-graph-quality-loop.sh`, `test-installers.sh`, `test-judges.sh`, `test-models.sh`, `test-orchestration-contract.sh`, `test-product-benchmark.sh`, `test-promptopt.sh`, `test-scout-outcomes.sh`, `test-scout.sh`, `test-skill-parity.sh`, `test-verdict-repair.sh`.

## DEFERRED

DEFERRED: none. No credential or hardware evidence was required or counted as PASS.

POLYLANE-VERDICT: GO run=c9-product-autonomy-1786054003
