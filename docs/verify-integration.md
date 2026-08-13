# Cycle 42A taste-contract integration verification

Run: `c42a-taste-contracts-20260813-a2`

Subgoal: `m32.6`

Cycle base: `5a4357c9b1e0153f80bb428c81cf835985f28025`

## Outcome

All four current Cycle 42A lane tips were merged, their handoff evidence was independently inspected, and the v3 execution, evidence, source-calibration, statistics, and lifecycle contracts were frozen into one repository-local consumer boundary. The aggregate lock and claim registry are deterministic and every focused Cycle 42A acceptance check passes.

The required full suite is not green on this host: `tests/run.sh` completed with 4,022 passes and 17 failures in three unchanged live/host test files. The failures are concrete sandbox capability errors (`listen EPERM` on `127.0.0.1` and tmux socket creation `Operation not permitted`), not external human evidence. Because a frozen autonomous acceptance command failed, this run is NO-GO. No human-calibrated or taste-certification claim is minted.

## Merge provenance and ancestry

The branch refs were resolved at merge time, not from memorized hashes. `git merge-base --is-ancestor <tip> HEAD` succeeded for every row after the merge.

| Lane | Merged current tip | Handoff inspected | Ancestor of merged head |
|---|---|---|---|
| `lane/c42a-execution-contract-freeze` | `3e6be95859641ca649d53b2ba13d633e2cfbf9d7` | `docs/verify-execution-contract-freeze.md` | yes |
| `lane/c42a-evidence-policy-freeze` | `a18cd3bbbfdd87d735222686187f127ae0b15e4b` | `docs/verify-evidence-policy-freeze.md` | yes |
| `lane/c42a-source-contract-freeze` | `5b3daffd37df4596afccf0a2befa3a766527de18` | `docs/verify-source-contract-freeze.md` | yes |
| `lane/c42a-lifecycle-external-routing` | `a468b818352f2b68e47887dcc7d2cd923582a1cf` | `docs/verify-lifecycle-external-routing.md` | yes |

The four-way merged head before integrator-authored seam work was `759ef4d978c5b4ba970b5163ac3a025e97ea84ba`.

## Canonical aggregate artifacts

- `docs/polylane/taste-certification/contracts/CONTRACT-LOCK.v3.json`
  - exact file SHA-256: `689ab890c339966b15f32a22f309a564f92d1ff34b354184425ffef0f8e41c34`
  - canonical body freeze SHA-256: `9c25a6293f037210e26f4376ce75e767e5b87fa6bdc2216b831525d12b414a50`
- `docs/polylane/taste-certification/contracts/EVIDENCE-CLAIM-REGISTRY.v3.json`
  - exact file SHA-256: `00b2dc076bf74c2b511ef780f1cda796730ad4704a9d1ccb1f397f4d025864da`
  - canonical body freeze SHA-256: `b6562c6e297f82d877e43f5efbeae01471780f2455f7a326a732aee6b1df58b2`

Both files are single-line canonical JSON. Two independent aggregate validations recomputed `sha256(jq -cS 'del(.freeze_sha256)')`, checked every `artifact_bindings[].sha256`, regenerated canonical bytes twice, and compared the two outputs byte-for-byte. Both passes produced the hashes above with no drift. The lock resolves artifacts only from repository-root-relative paths; its consumer contract rejects a missing/unknown producer, unknown key, or hash mismatch and requires no sibling branch or worktree import.

The lock binds the exact bytes of 37 schemas, policies, examples, validators, lifecycle artifacts, and tests, plus all 14 acceptance command strings. Its claim-registry binding is the exact registry file hash above.

## Independently checked contract ceilings

- Final confirmation is exactly 1,000 independent preregistered brief lineages, 100 in each of ten categories, one shot, fixed denominator, ties/abstentions/missing or invalid evidence as non-wins, with 728 failing and 729 passing. Task and accessibility regressions must both be zero; the set is never optimizer input.
- Prompt selection is exactly a 12-brief wiring smoke test, a 192-brief adaptive development bank, and one untouched 300-brief validation. Promotion requires 183 wins; 182 fails. The three paired build replicates, viewports, states, mirror orientations, judge invocations, and ballots never increase `n`.
- The execution provenance chain binds source, compiled, delivered, consumed-stdin, and request bytes. Delivered and consumed SHA-256 and byte counts must agree, the successful `polylane-stdin-adapter/v1` receipt must bind the request receipt, and a path or environment variable is not consumption proof.
- `STATIC_HOMEPAGE_AE_SANITY_CALIBRATION` and the public professional-designer TASTE source are diagnostic only. Public or fixture ancestry cannot be laundered into private HCM-v2 authority. Genericness is review-only until human-qualified and cannot independently pass or fail taste.
- `HUMAN_CALIBRATED_MACHINE` requires a connected private HCM-v2 trust root, target-matched sealed study, exact calibration scope, and passing final benchmark. The status remains `MACHINE-EVALUATED`, `human_certified` remains false, and `taste_certified` remains false.
- The panel is five primaries plus one availability reserve, at least three verified provider organizations and three verified base lineages, at most two configurations per lineage, and `n_eff >= 3.0`. Provider/lineage aliases do not create independence.
- Each judge configuration must pass no more than six reversals across 240 unique mirrored pairs; both 300-probe equivalence counts must lie in the inclusive 135–165 region; the designer qualifier is 84 both-mirror-correct among 120 decisive pairs plus its frozen Wilson, macro, and stratum floors.
- Evidence grades use the least-trusted transitive ancestor; fixtures are absorbing. No producer, fixture, example, public corpus, heuristic, or prose assertion has certification mint authority.
- Lifecycle transitions are limited to `WORKING -> HANDOFF_PENDING -> HANDOFF_COMMITTED -> QUIESCING -> DONE` plus explicit idempotent self-transitions. Only the worker finalizer may author handoff bytes; the runner may not normalize, append, delete, or recommit them. Acceptance `evidence_kind` and cadence `tier` are independent, and external-open cannot mask an autonomous failure.
- Call ceilings, retry classes, retained CAS, selected-source, staging, quarantine, and the 5 GiB storage safety floor are exact locked fields rather than prose expectations.

Adversarial fixtures exercised the requested 728/729 and 182/183 boundaries, denominator shrinkage, repeated-unit inflation, public-to-HCM and fixture laundering, uncalibrated genericness verdicts, lineage aliases and lineage caps, bias-equivalence boundaries, exact prompt-byte discontinuity, missing consumed-stdin proof, and external-open routing. All were rejected or accepted at their frozen boundary as intended.

## Registered Cycle 42B implementation defects

The claim registry marks all five as `OPEN` and blocks affected descendants from promotion until repaired and regression-tested:

1. unsafe whole-document prompt dedupe;
2. comparator pseudo-WIN;
3. optimized-prompt deletion;
4. run-mode vocabulary mismatch;
5. missing consumed-stdin proof.

## Cross-contract seam repairs

No builder handoff, sibling worktree, `codex/taste-certification`, `docs/polylane/max-state.json`, cycle plan, research/suggestion/index file, or runner scratch/ledger path was edited. The only repairs outside the integrator's five direct files were within the lifecycle builder OWN-set union:

| Path | Repair | Focused proof |
|---|---|---|
| `bin/polylane-run.sh` | Preserve legacy pane-role fallback, legacy acceptance invocation/output, and legacy wedge-count semantics below contract v3 while retaining v3 fail-closed roles, typed evidence routing, and durable elapsed watchdogs. | agent adapter 53/53; Cycle 14 13/13; efficiency 36/36; graph-shadow 52/52; handoff 58/58; contract acceptance 42/42; verdict repair 64/64 |
| `assets/verify-gate.sh` | Enter explicit v3 mode only from explicit CLI identity arguments and restore the legacy integrator-to-`verify-integration.md` lookup. | verify gate 6/6; hooks green; v3 finalization green |
| `SKILL.md` | Restore the exact contract-v2 finalization compatibility wording while keeping v3 lifecycle policy. | skill parity 72/72; lifecycle focused suite green |
| `references/planning.md` | Restore the contract-v2 compatibility block required by legacy manifest tests. | marker/docs parity green; lifecycle focused suite green |
| `references/prompt-blocks.md` | Restore the contract-v2 prompt block and builder/integrator final-handoff wording. | marker/docs parity green; lifecycle focused suite green |

The final relay repeated two previously resolved scope requests. Coordinator decision sequence 2 keeps the stale m32.4 `SUBJECT_ROOT`/`confidence_lower`/unregistered-summary predicates external and host-owned, so `docs/polylane/max-state.json` remains untouched. The request to mirror v3 wording into `codex/SKILL.md` is also outside the direct scope and every builder OWN set; existing skill parity passes 72/72, and a later packaging-owned mirror remains the dependency-safe route. Integrator decision sequence 5 records both dispositions.

## Verification ledger

Focused acceptance from `docs/polylane/cycle-42-plan.md`:

| Command | Result |
|---|---|
| `bash tests/test-taste-execution-contract-v3.sh` | PASS, 43/43 |
| `bash tests/test-evidence-dag.sh` | PASS, 95 assertions |
| `bash tests/test-taste-source-contract-v3.sh` | PASS, 60 assertions |
| `bash tests/test-finalization-watchdog.sh` | PASS, 18/18 |
| `bash tests/test-contract-acceptance.sh` | PASS, 42/42 |
| `bash tests/test-verdict-repair.sh` | PASS, 64/64 |
| `bash tests/test-lane-done.sh` | PASS, 27/27 |
| `bash tests/test-lane-done-live.sh` | PASS, 18/18 |
| `bash tests/test-supervisor.sh` | PASS, 41/41 |
| frozen ShellCheck command | PASS, no warnings |

Additional focused seam verification passed: `test-agent-adapter.sh` 53/53, `test-cycle14.sh` 13/13, `test-efficiency.sh` 36/36, `test-graph-shadow.sh` 52/52, `test-handoff.sh` 58/58, `test-verify-gate.sh` 6/6, hooks, and the v3 finalization path. Cache evidence: `.polylane/check-cache/taste-contract-integrator/1641699969-748.output` and `.polylane/check-cache/taste-contract-integrator/1845471685-582.output`.

The single stable-tip full suite run completed, rather than short-circuiting:

- aggregate: 4,022 passed, 17 failed, 170 test files;
- `test-taste-browser-live.sh`: 24 passed, 15 failed because its fixture and real-browser paths could not start the required loopback server;
- `test-taste-dataone-metadata.sh`: failed at fixture-server startup with Node `listen EPERM: operation not permitted 127.0.0.1`;
- `test-tmux-runtime.sh`: 11 passed, 2 failed after tmux reported `Operation not permitted` creating its private socket under `/private/tmp`;
- all three failing files are unchanged by the four merges and integrator seam repairs.

Full-suite cache evidence: `.polylane/check-cache/taste-contract-integrator/3813231388-94.output`. Marker/docs parity passed. Skill parity passed 72/72. `git diff --check` is recorded in the pre-handoff section below.

## External work left open

No external campaign was run. HCM-v2 ethics/privacy determination, recruitment, consent, compensation, privacy/retention/withdrawal controls, target-matched tasks, real ballots, analysis, and provider/source campaigns remain external-open. Public/private source downloads were not performed. Accordingly this cycle does not assert `human_calibrated:true`, a human certification, a taste certification, or any equivalent label.

## Next dependency-safe carve

First rerun the three failed live/host files on an execution host that permits loopback binds and private tmux sockets; this is a host acceptance recovery, not authority to edit unrelated tests. A packaging-owned slice may then mirror the root v3 lifecycle wording into `codex/SKILL.md` and replace or retire the host-owned stale m32.4 predicates. Once the autonomous gate is green, Cycle 42B can be split into file-isolated implementation lanes for the five registered defects, with each lane consuming only the two aggregate v3 artifacts and their exact repository-relative bindings. The first implementation slice should repair typed-section prompt dedupe and the consumed-stdin receipt chain together because both affect immutable prompt identity; comparator outcome counting, optimized-prompt retention, and run-mode vocabulary can remain independent slices. HCM-v2 stays external-open throughout.

## Pre-handoff

The final relay returned request sequences 1–3 and the already-recorded scope decision sequence 5; no new autonomous work was addressed to this worker, and the durable worker inbox was empty. The final cached focused command reran all nine Cycle 42A focused tests, frozen ShellCheck, marker/docs parity, skill parity, and `git diff --check`; it passed with source fingerprint `1795215598:44713` and cache log `.polylane/check-cache/taste-contract-integrator/2090495819-870.output`. The scoped implementation/evidence commit contains only the four pre-handoff direct artifacts and the five itemized lifecycle seam paths. Its required post-commit clean-status gate permits only runner-owned `.polylane-prompt.txt` and `graphify-out` before the isolated worker-authored marker/verdict transaction.
