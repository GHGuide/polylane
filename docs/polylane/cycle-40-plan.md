# Cycle 40 plan — live taste-study harness

Run: `c40-live-harness-20260812-a2`
Target: `m32.4a`
Base: `codex/taste-certification` at the committed Cycle 39 close plus preflight repair `93269ca`
Mode: autonomous, high-assurance, file-isolated Claude Code lanes in tmux

Attempt `a1` stopped before worktree, branch, tmux, or worker side effects when the
production-size scope gate exposed a Bash 3.2 process-substitution SIGTRAP. Commit
`93269ca` pins the fifteen-lane regression and bounds manifest glob loads. This fresh
nonce prevents the aborted attempt's telemetry or markers from entering study evidence.

## Frozen outcome

Implement and live-smoke the complete non-fixture boundary needed for the real
old-versus-new study: source-pinned human-label acquisition, held-out calibration,
isolated Claude and Codex judge adapters, raw-response provenance, ballot-v2 receipts,
Playwright capture, decoded PNGs, task/state/accessibility vetoes, prompt and generation
freezes, a varied twenty-brief corpus, and a production manifest compiler. Cycle 40 may
promote this harness only; it cannot mark `m32.4` complete or mint a taste certificate.

The machine-panel claim is frozen as `HUMAN_CALIBRATED_MACHINE` with
`human_certified:false`. No machine output may be represented as a deciding human ballot.

## Preregistered study constants

- Baseline skill revision: `0b802ad13ada13a0dc7cc702a526ed17d3348851`, the final
  commit before the visual-intelligence plan.
- Candidate subject: the final clean Cycle 40 merge revision, frozen before generation.
- Primary builder: Claude Fable 5, same fixed configuration for baseline and current.
- Baseline arm: one prompt, one build. Current arm: three structurally divergent
  directions, a blind rendered tournament, and at most two evidence-targeted repairs.
- Corpus: 20 unique offline briefs across consumer, collaboration, operations, health,
  finance, data, culture, logistics, education, and creative tools. The existing five
  briefs remain; fifteen named strata are added before any generation.
- Primary calibration source: the three CC0 Miniukovich–Figl Dataverse releases
  (`DVN/9FKSQI`, `DVN/XOI0HI`, `DVN/Z7KLIH`), version and file digests frozen from the
  source API. TASTE at repository SHA
  `731a7f588d433214c6d864d2e9f47978d91aed6b` is a separate secondary audit and cannot
  silently replace a failed primary corpus.
- Primary split: 180 calibration pages plus 72 held-out pages, stratified 60/24 per
  domain. Judge eligibility uses 24 deterministic unambiguous mirrored pairs, at least
  17 correct, Wilson lower bound at least 0.50, side-probe `p >= 0.05`, and fewer than
  two mirror contradictions.
- Final floor remains the protocol's preregistration: at least 10 valid briefs, at least
  7 brief wins, pooled preference at least 0.70, Wilson lower bound above 0.50, at least
  five complete mirrored groups per brief, and zero accessibility regression. The study
  targets all 20 briefs and may not shrink after results.
- Every live adapter is explicit, versioned, hash-receipted, and external to the Bash
  3.2 core. Missing Chrome, Playwright, decoder, accessibility engine, model CLI, corpus,
  or raw response yields `UNKNOWN`/failure—never fixture fallback.
- Binary calibration assets live in a content-addressed user cache. Committed receipts
  contain source URLs, licences, file IDs, source checksums, SHA-256, selection seed, and
  exact reproduction commands. Final benchmark screenshots required by the certificate
  remain in the declared evidence closure.

## Frozen lane carve

1. `source-live` — browser-backed Dataverse acquisition, deterministic three-domain
   split, TASTE secondary receipt, cache verification, and a real one-file canary.
2. `calibration-live` — production calibration input/receipt v2 that binds images,
   source labels, mirrored raw responses, parser/invocation hashes, and judge identity.
3. `judge-claude` — isolated noninteractive Claude visual-judge adapter with exact model,
   prompt, image, output-schema, raw-response, timing, and exit receipts.
4. `judge-codex` — equivalent provider-native Codex visual-judge adapter; no Claude syntax.
5. `judge-runner` — campaign sharding, unique session IDs, retry/abstain rules, no shared
   ballot channel, process isolation, and deterministic response parsing.
6. `ballot-live` — production `taste-ballot-validation/v2` producer that recomputes every
   group, raw response, orientation, pointwise, calibration, capture, and escrow binding.
7. `browser-live` — real Chrome/Playwright adapter for frozen route/state/viewport/action
   matrices, offline enforcement, and complete capture receipts.
8. `decode-live` — real PNG-to-RGBA decoder with dimensions, payload, provenance,
   duplicate/perceptual evidence, and corruption tests.
9. `a11y-live` — pinned accessibility adapter, keyboard/focus/reflow/contrast/target/motion
   evidence, baseline comparison, exception ledger, and fail-closed receipts.
10. `task-live` — replayable per-brief action/state/task oracle and hard-gate compiler.
11. `corpus-20` — frozen twenty-brief study corpus, task scripts, state applicability,
    categories, acceptance facts, and licence/offline rules.
12. `prompts-live` — immutable baseline/current prompt compiler, literal ultimate goal,
    reference and design locks, prompt optimization, provider-neutral evidence contract,
    and no candidate self-verdict.
13. `generate-live` — isolated fixed-model build runner, source/build receipts, timeouts,
    replay, no-network output checks, and baseline/current compute accounting.
14. `study-live` — study freeze/compiler, calibration-v2 and ballot-v2 certificate support,
    declared evidence closure, subject ancestry, statistics, and negative attacks.
15. `protocol-live` — update the research/protocol/provider docs to describe the now-live
    boundary, source substitution policy, claim semantics, and exact reproduction.

The deferred `taste-live-integrator` merges all fifteen tips, repairs cross-module seams,
runs the frozen matrix, runs one real primary-corpus canary plus one real Claude and one
real Codex visual-judge smoke, records their non-fixture receipts, and emits the sole
nonce-bearing verdict.

## Frozen acceptance

```bash
bash tests/test-taste-source-live.sh &&
bash tests/test-taste-calibration-live.sh &&
bash tests/test-taste-judge-claude.sh &&
bash tests/test-taste-judge-codex.sh &&
bash tests/test-taste-judge-run.sh &&
bash tests/test-taste-ballot-live.sh &&
bash tests/test-taste-browser-live.sh &&
bash tests/test-taste-decode-live.sh &&
bash tests/test-taste-a11y-live.sh &&
bash tests/test-taste-task-live.sh &&
bash tests/test-taste-corpus-20.sh &&
bash tests/test-taste-prompts-live.sh &&
bash tests/test-taste-generate-live.sh &&
bash tests/test-taste-study-live.sh &&
bash tests/test-taste-live-harness-e2e.sh &&
shellcheck -S warning bin/*.sh codex/install.sh claude-code/install.sh
```

The end-to-end test must verify the committed live-smoke receipts as real and bound; its
default test fixtures cannot produce a production receipt. The integrator also runs the
full suite, marker/doc consistency, skill parity, seam scan, and `git diff --check`.

## Failure and continuation

- A blocked corpus or provider adapter produces a precise external evidence receipt and
  `EXTERNAL-EVIDENCE-OPEN`; it never substitutes fixture data.
- A failed frozen test is `NO-GO`; preserve the Cycle 39 incumbent and repair in a fresh
  nonce-bound cycle.
- A judge that fails held-out calibration is excluded, not tuned on the holdout.
- No Cycle 40 result changes the baseline, brief list, split seed, thresholds, or claim.
- After GO, Cycle 41 performs the expensive generation wave; later cycles capture,
  calibrate, judge, repair within the frozen cap, and certify only if evidence passes.
