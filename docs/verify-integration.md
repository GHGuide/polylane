# Cycle 9 integration verification

Run: `c9-product-autonomy-1786054003`  
Branch: `lane/c9-integrator`

## Integration fixes

- Benchmark records and aggregates now preserve `completion` and `product_quality`; unknown values remain `null`.
- Control snapshots now include canonical spend (`cost` included), compiled graph id/initial readiness, and matching text fields.
- Codex manifests reject non-`gpt-*` lane or integrator models; the canonical schema example is Codex-consistent.
- Contract-v2 invokes the immutable prompt-budget check before launch.
- Discovery has durable open/resolved contradiction records and lock blocks only unresolved entries.
- Judges bound timeouts to 300 seconds and withhold evidence publication until all three isolated commands finish.
- Advanced runtime exposes a durable seam gate; repository seam scans ignore intentional test fixtures and non-code prose.

## Evidence

- Branch tips contained: `lane/c9-product-foundation` `5d54f64`, `lane/c9-worker-efficiency` `5d71629`, `lane/c9-quality-runtime` `8d08d9b`, `lane/c9-control-docs` `1ee85b1`.
- `bash tests/test-product-benchmark.sh`: 19 pass, 0 fail (mock isolated adapter corpus run; completion/product-quality means 0.75).
- `bash tests/test-dashboard.sh`: 33 pass, 0 fail (both `--once --json` and text snapshot formats).
- `bash tests/test-advanced-runtime.sh`: 11 pass, 0 fail.
- `bash tests/test-codex-profile.sh`: 8 pass, 0 fail.
- `bash tests/test-discovery-graph.sh`: 22 pass, 0 fail.
- `bash tests/test-judges.sh`: 9 pass, 0 fail; exactly three isolated judge evidence files, bounded timeout, and hidden prior evidence proven.
- `bash tests/test-orchestration-contract.sh`: 5 pass, 0 fail.
- `bash tests/test-promptopt.sh`: 6 pass, 0 fail.
- `bash tests/test-scout-outcomes.sh`: 18 pass, 0 fail; `bash tests/test-scout.sh`: 22 pass, 0 fail.
- `bash tests/test-docs-truth.sh`: 17 pass, 0 fail.
- `bin/polylane-seams.sh scan "$PWD"`: pass; no production dangling DOM seam.
- `shellcheck -S warning bin/*.sh`: pass (cached canonical command, exit 0).
- `bin/polylane-scope.sh check-static`: no canonical cycle manifest is present in this checkout, so no static scope target exists.

## Terminal gate

The required single cached invocation of `tests/run.sh` started and passed through graph-authority (50 pass) but was host-interrupted while entering `test-graph-benchmark.sh`. Its log remains incomplete at `.polylane/check-cache/integrator/1557743017-64.output.32659`; it was not rerun under the usage guard. Therefore terminal-suite evidence is incomplete.

## Final narrow repair

- Codex now rejects a non-`gpt-*` entry in `available_models` before launch and rejects a non-`gpt-*` runtime `--model` override after override application. This closes the remaining path for a Claude id to enter a Codex launch manifest.
- `bash tests/test-orchestration-contract.sh`: 7 pass, 0 fail, through the worktree check cache. It includes `codex-rejects-non-gpt-available-model` and `codex-rejects-non-gpt-model-override`.
- `shellcheck -S warning bin/polylane-run.sh`: exit 0, no findings, through the worktree check cache.
- The mandated canonical cache path was attempted but this sandbox denied its directory creation (`Operation not permitted`); the established worktree-local cache was used for these two fresh focused checks. No canonical cycle manifest exists, so `polylane-scope.sh check-static` has no static target.

## Changed files

- `.polylane/SCHEMA.md`
- `bin/polylane-advanced.sh`, `bin/polylane-dashboard.sh`, `bin/polylane-discovery.sh`, `bin/polylane-judges.sh`, `bin/polylane-product-benchmark.sh`, `bin/polylane-run.sh`, `bin/polylane-seams.sh`
- Cycle-9 focused tests under `tests/`, including `tests/test-orchestration-contract.sh`, and this verification/status evidence.

## DEFERRED

DEFERRED: terminal full-suite completion requires a future host-run; no external credential or hardware evidence was treated as PASS.

POLYLANE-VERDICT: NO-GO run=c9-product-autonomy-1786054003
