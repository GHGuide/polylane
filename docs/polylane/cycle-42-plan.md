# Cycle 42A plan — freeze the taste-certification trust boundary

Run: `c42a-taste-contracts-20260813-a2`
Target: `m32.6`
Base: `codex/taste-certification`
Mode: autonomous maximum-assurance, four file-isolated Codex builders plus one
deferred Codex integrator

## Outcome

Produce one executable, content-hashed contract lock before any production source,
judge, prompt-optimizer, or UI implementation proceeds. The lock defines the exact
build/request/receipt chain, evidence grades and claim ceilings, multi-source human
calibration, preregistered statistics, resource accounting, and worker-finalization
state machine. It also repairs the Cycle 41 control-plane defect: unresolved external
evidence may remain open without mutating a valid autonomous handoff or spawning a
meaningless repair wave.

This is an implementation cycle, not a prose exercise. Every contract gets a strict
validator and adversarial tests. The integrator alone creates the aggregate claim
registry and lock after merging all four independently authored contracts.

Cycle 42A attempt `a1` was intentionally stopped before worktree creation or pane
launch. Independent review showed its 20-brief rule had only about 41.6% power at a
true 70% win rate and that its Wilson and sign-test gates were effectively the same
boundary. No implementation from that invalidated attempt is reused.

## Lane carve

1. `execution-contract-freeze` — canonical v3 brief/sample-unit, build, exact prompt,
   request, capture, judge, and receipt identities; deterministic fingerprints; no
   repeated-measure inflation.
2. `evidence-policy-freeze` — verified evidence DAG, least-trusted-ancestor grading,
   fixture absorption, registered producers, scoped claim ceilings, and the corrected
   development/optimizer/confirmatory statistical policies.
3. `source-contract-freeze` — metadata-first selected-only acquisition for static
   homepage and professional-designer diagnostics plus the private HCM-v2 target-human
   study, immutable split reservations, source checksums, consent/privacy receipts,
   contamination controls, judge eligibility, and equivalence-based bias checks.
4. `lifecycle-external-routing` — persisted worker finalization, immutable handoffs,
   elapsed progress watchdogs, evidence-homogeneous autonomous/external acceptance,
   and no runner-authored status or verdict repair.

The deferred `taste-contract-integrator` merges all four current tips, repairs only
documented cross-contract seams, creates `CONTRACT-LOCK.v3.json` and
`EVIDENCE-CLAIM-REGISTRY.v3.json`, runs focused and full verification, and emits the
sole nonce-bound verdict.

## Frozen contract decisions

- Certification status is `MACHINE-EVALUATED`; the machine claim is
  `HUMAN_CALIBRATED_MACHINE` and must include a precise `calibration_scope`.
  It must also state `taste_certified:false`; `human_calibrated:true` never implies
  `human_certified:true`.
- `HUMAN_CERTIFIED` is unreachable without roster-bound deciding-human ballots and a
  trust-rooted human-study receipt. Public human-labelled corpora calibrate a machine;
  they do not turn its later votes into human votes.
- A claim's effective evidence grade is the least trusted transitive ancestor.
  Fixture evidence is absorbing; unknown producers, unknown schemas, stale inputs,
  disconnected nodes, and cycles are invalid rather than warnings.
- The 20-brief set is development-only and cannot mint a claim. The untouched
  confirmatory study has exactly 1,000 independent briefs, 100 in each of ten frozen
  categories. It tests `H0: p <= 0.70` with a one-sided exact `alpha=0.025`, keeps all
  1,000 in the denominator, counts ties/abstentions as non-wins, requires at least 729
  wins, and permits zero task or accessibility regressions. At 729/1,000 the actual
  null-tail probability is about 0.0238095 and power is about 0.94082 at true `p=0.75`.
  Wilson uncertainty is reported, not presented as an independent safeguard. Judges,
  mirrors, states, viewports, and build replicates never increase `n`.
- Prompt optimization is adaptive only on a 192-brief development bank after a
  12-brief wiring smoke test. A challenger can replace the incumbent only after one
  untouched 300-brief, one-bit validation with at least 183 wins against `H0:p<=0.55`,
  equal compute, three paired build replicates, no repair, fixed-denominator non-win
  handling, and no hard-gate regression. The 1,000-brief certification set is never an
  optimizer input and is evaluated once.
- The Miniukovich–Figl corpus is named
  `STATIC_HOMEPAGE_AE_SANITY_CALIBRATION`; it cannot establish interaction quality,
  product fit, originality, state coherence, or general UI taste. The professional-
  designer TASTE corpus is a public multidimensional transfer diagnostic. Neither can
  activate `HUMAN_CALIBRATED_MACHINE`. That claim requires HCM-v2: a private, sealed,
  target-matched rendered-and-interactive human holdout with preregistered population,
  consent, compensation, privacy, tasks, states, viewports, analysis, and exclusions.
- Freeze five primary configurations plus one availability reserve across at least
  three provider organizations and three verified base-model lineages, with no more
  than two configurations per lineage and effective independent panel size at least
  3.0. Provider names are not proof of independence. Calibration reports individual
  and ensemble human-label agreement plus empirical correlated errors.
- Side-bias is cleared by preregistered equivalence, never by failure to reject bias.
  Each configuration must show at most 6 reversals among 240 unique mirrored pairs;
  on 300 human-quality-matched orthogonal probes, both self-lineage and verbose-side
  selections must fall in the exact-binomial TOST acceptance region 135–165. HCM-v2
  additionally requires human and machine order effects equivalent within `+/-0.05`.
  Mirror inconsistency yields abstention and can make coverage ineligible; discordant
  cases are never filtered away.
- Source selection is metadata-first and outcome-blind. Split identities are reserved
  before image acquisition or judge output; only selected bytes are downloaded and
  every declared size, upstream digest, local SHA-256, license, and source revision is
  verified.
- Genericness heuristics, perceptual hashes, and layout fingerprints are review
  triggers until calibrated against human labels. They cannot independently fail or
  pass taste. Perceptual hashes remain valid for duplicate/provenance detection.
- Worker handoff is a persisted transaction:
  `WORKING -> HANDOFF_PENDING -> HANDOFF_COMMITTED -> QUIESCING -> DONE`.
  Only the worker finalizer may author its marker/verdict bytes.
- Acceptance `evidence_kind` (`autonomous|external`) is independent from cadence
  `tier` (`focused|terminal`). A subgoal is evidence-homogeneous. External-open never
  masks a failed targeted autonomous check and never triggers worker repair.
- Every phase preflights retained CAS bytes, remaining manifest bounds, active staging,
  and a 5 GiB safety floor. Judge orientations reference the same capture objects;
  copies never consume evidence quotas. The 1,000-brief campaign is obligatorily
  sharded by frozen IDs and may archive hash-verified closed shards, but the sample
  frame, denominator, and one-shot outcome policy cannot change.

## Acceptance

```bash
bash tests/test-taste-execution-contract-v3.sh &&
bash tests/test-evidence-dag.sh &&
bash tests/test-taste-source-contract-v3.sh &&
bash tests/test-finalization-watchdog.sh &&
bash tests/test-contract-acceptance.sh &&
bash tests/test-verdict-repair.sh &&
bash tests/test-lane-done.sh &&
bash tests/test-lane-done-live.sh &&
bash tests/test-supervisor.sh &&
shellcheck -S warning \
  bin/polylane-taste-execution-contract.sh \
  bin/polylane-evidence-dag.sh \
  bin/polylane-taste-source-contract.sh \
  bin/polylane-finalize.sh \
  bin/polylane-memory.sh \
  bin/polylane-run.sh \
  bin/polylane-supervisor.sh \
  assets/verify-gate.sh &&
tests/run.sh &&
bin/polylane-markers.sh check-docs references/ &&
bash tests/test-skill-parity.sh &&
git diff --check
```

No Cycle 42A success is a taste certificate. It is the frozen executable grader that
later production cycles must satisfy.
