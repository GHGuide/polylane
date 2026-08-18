# Cycle 42A research lock — scoped, human-calibrated machine taste

Run: `c42a-taste-contracts-20260813-a2`

This lock incorporates the independent provenance, source, statistics, HCI, judge,
prompt-optimizer, UI-contract, resource, and lifecycle audits completed after Cycle 41.
Implementation may make a gate stricter but may not lower it after seeing an outcome.

## What can honestly be certified

Visual preference is empirical, subjective, multidimensional, and population-specific.
A self-authored rubric, one model's critique, or agreement among correlated models can
guide repairs but cannot become a human verdict. The autonomous claim is therefore:

- `status: MACHINE-EVALUATED`
- `claim: HUMAN_CALIBRATED_MACHINE`
- `human_calibrated: true` only after HCM-v2 target-human evidence passes
- `human_certified: false`
- a mandatory exact `calibration_scope`

The scope names the private target-human population, tasks, domains, states, viewports,
criteria, split, and acquisition revision. Public corpora are transfer diagnostics and
cannot activate the claim. `HUMAN_CERTIFIED` requires humans to adjudicate the exact
released artifact and is unreachable from machine receipts, regardless of model count
or compute.

Every artifact participates in a typed evidence DAG. Nodes bind schema, registered
producer, exact input digests, output digest, execution configuration, source revision,
and evidence grade. The effective grade is the least trusted grade across every
ancestor. Fixture evidence is absorbing. Missing, unknown, stale, cyclic,
schema-mismatched, disconnected, or unregistered ancestry makes a claim ineligible.

## Corrected statistical lock

The earlier 20-brief/15-win proposal is rejected. At 15/20 its Wilson 95% lower bound
is about 0.531299 and its exact two-sided sign p-value about 0.041389, so those two
conditions collapse to essentially one boundary. More importantly, the design has only
about 0.416 power when the true brief-win probability is 0.70.

The untouched confirmatory design uses exactly 1,000 independent product briefs,
balanced as 100 briefs across each of ten preregistered categories. Its primary
estimand is the equal-weight probability that Polylane wins a newly sampled brief over
the frozen baseline. It tests `H0:p<=0.70` versus `H1:p>0.70` with a one-sided exact
upper-tail test at `alpha=0.025`; at least 729/1,000 wins are required. The actual Type-I
error at `p=.70` is about 0.0238095, power at `p=.75` about 0.940820, and the Wilson 95%
interval at 729/1,000 approximately `[0.7006,0.7556]`. The Wilson interval is
interpretation, not an independent extra gate.

The denominator is frozen at 1,000. A tie, abstention, missing vote, failed render, or
insufficient panel coverage is a non-win or a completeness failure according to the
preregistered reason code; it is never dropped or replaced after outcomes exist.
Mirrored orientations, judges, states, flows, and viewports are repeated measurements,
not extra sample units. Brief IDs are disjoint from all adaptive development,
calibration-development, prompt-validation, and repair data.

Prompt optimization has four authorities: 12 purposive smoke briefs for wiring, 192
adaptive development briefs across twelve strata, one one-bit 300-brief sealed
validation, and no access to the final 1,000. Promotion requires at least 183/300 wins
against `H0:p<=0.55` at one-sided `alpha=.025`; the actual Type-I error is about 0.0207
and power about 0.934 at true `p=.65`. Each arm receives identical model, tools,
references, skills, budgets, and three paired build replicates, with zero repair. Ties,
abstentions, missing evidence, and invalid candidate builds stay non-wins. The former
4+2 tournament remains a wiring smoke only: 2/2 has one-sided null probability 0.25,
a Wilson 95% lower bound near 0.342, and misses a 20% defect with probability 0.64.

## Human calibration is a stack, not one screenshot corpus

### Static first-impression sanity

The Miniukovich–Figl source is retained and explicitly renamed
`STATIC_HOMEPAGE_AE_SANITY_CALIBRATION`. Its human ratings can check broad static
first-impression ordering. It does not measure interaction, task success, responsive
states, product fit, originality, or the quality of generated functional interfaces.

Cycle 41 observed 3,180 source files including 3,156 JPEG screenshots and normalized
human-rating coverage of 262 fashion, 443 homeware, 340 university, and 510 banking
records. Those counts and the known banks b889/b952 duplicate decision remain pinned
facts; unexplained residuals remain uncertainties rather than invented causes.

### Professional-designer multidimensional transfer diagnostic

TASTE v2 is a materially relevant public transfer diagnostic. It contains two disjoint cohorts
of five professional designers who ranked four designs across nine criteria including
typography, hierarchy/layout, color, aesthetics, and prompt fidelity. The paper reports
moderate designer agreement and reports that none of its tested off-the-shelf VLM or
image-preference judges exceeded 0.55 macro agreement with the five-designer majority.
That finding forbids treating an uncalibrated frontier model as a taste oracle. Because
its prompts, images, and labels are public, pretraining contamination is unknowable;
TASTE can report transfer agreement but cannot serve as a sealed authority or activate
`HUMAN_CALIBRATED_MACHINE`.

The source is public, ungated, and marked MIT at Hugging Face revision
`731a7f588d433214c6d864d2e9f47978d91aed6b`. The live metadata envelope reports 654
files, 644 images, 1,598,746,498 total bytes, 14,460 ranking rows, 721 prompts, and ten
masked evaluators. The corresponding GitHub source revision is
`e37f02d2e79125bb692b432214928101f026fcc9`. Contracted metadata SHA-256 values include:

- `assets.parquet`: `326e9300bac89f5ed884de7a9a59dccfc7d5aa203f6d2844f604000dc4e32bf1`
- `evaluators.parquet`: `1136892daada59c9dc0e54508c1ef6892e60eab12dc492c4ecc19ac27e5c4c7d`
- `prompts.parquet`: `12c3d2782c61d9ed7a5c84e4615145aa1688c79392c42974b9616b0b2cd1c1b9`
- `rankings.parquet`: `7a9b57e442577dc296d48321c3cc165da25c59326bd7e5401e13008d475e0ffa`
- `hallucinations.parquet`: `2f1ed706c1a0ff2cb101afd7c2f47cf0d21fdc0e2a2ef59719e97ae4f1e3efc6`
- `rankings_with_images.parquet`: `e8719b3b5d4240de0466a6ff3d889d778f65ef179c5abc66859efd2c91797428`
- `hallucinations_with_images.parquet`: `b48e6c988847372d40400981542ea36f484877dd33cc8f6cf88a388d5c56bf26`

The release is not silently regularized. Its nominal 720 ranking groups and 14,400
rows are actually 721 and 14,460; ten evaluator cells and two prompt/criterion groups
contain eight rather than four assets; `prompt_id_src=613` collides across two scenes;
twenty hallucination rows have null `asset_id`; and released ranks are 1–4 although
the card says 1–5. Pairwise labels are derived from strict ranks rather than preserved
original clicks. The source-613 collision, malformed cells, and null-linked rows are
quarantined as whole leakage units.

Stage A downloads only the roughly 193 KiB canonical metadata parquets, never either
`*_with_images` file. It verifies revision/license/digests and defines
`scene_id=sha256(track || sorted(content_sha256 of all four scene assets))`. Selection
is outcome-blind and hash-seeded: exactly eight globally scene-disjoint units per each
of nine criteria, at most one pair-plus-criterion per scene, and at least 4/5 designer
agreement. Quota shortage fails closed. Stage B then acquires only the at most 144
unique image identities reachable from the frozen 72-pair plan and verifies declared
size and SHA-256. TASTE has no certification threshold in v3: it emits an audit report
only and cannot affect judge eligibility or the HCM claim.

The MLLM-as-a-UI-Judge study is a methodological anchor, not a usable v3 source: its
500-person, 15,000-response study found roughly 60% overall pairwise human agreement
for Claude/GPT-era judges and explicitly recommends machine judges as supplements
rather than replacements, but no official redistributable package with verifiable
license, hashes, and image rights was found. The contract records
`UI-JUDGE-SOURCE-UNAVAILABLE` and must not substitute an unofficial mirror.

### HCM-v2 target-matched calibration

Public corpora cannot establish a future product population. HCM-v2 is the sole
load-bearing human calibration and uses 320 naturalistic UI pair units across 40
highest-level-disjoint brief families: 120 development pairs from 15 families, 40
validation pairs from five families, and a one-shot 160-pair confirmatory holdout from
20 families. Thirty-two obvious anchor pairs test attention and sensitivity but never
enter performance metrics. Splits are disjoint by brief lineage, template, asset pack,
generation run/seed, source example, and visual-near-duplicate cluster.

Every natural pair receives 80 eligible target-user judgments after preregistered
exclusions: 20 in each desktop A/B, desktop B/A, mobile A/B, and mobile B/A cell. A
participant sees a pair once and at most eight natural pairs plus two anchors, implying
at least about 3,200 completed participants before recruitment overage. A separately
reported professional-designer audit uses 12 judgments per pair, at least 96 verified
designers, and at most 40 pairs per designer; target-user and designer votes are never
pooled.

Each pair first passes equivalent-content, task, accessibility, and provenance gates.
Humans then perform the same one-to-three brief-specific routes on each candidate,
complete unmodified VisAWI-S pointwise ratings, answer the frozen A/B/TIE visual-design
question, and may add confidence and a short reason. Required viewports are 1440x900 and
390x844. Orientation is balanced across different participants; ties, disagreement,
and exclusions remain visible. The protocol freezes population frame, locale, quotas,
consent, compensation, privacy, retention, randomization, analysis, and ethics/privacy
review before recruitment. Autonomous machinery may prepare and audit these artifacts
but cannot manufacture consent, people, credentials, payments, or governance approval.

## Judge and bias lock

Freeze five primary configurations plus one availability reserve, spanning at least
three provider organizations and three verified base-model lineages, with no more than
two configurations per lineage. The reserve may replace only a technically unavailable
configuration before substantive output exists. A fingerprint binds endpoint, lineage,
model snapshot, prompt bytes, decoding/reasoning settings, vision preprocessing,
parser, and tool policy. Different effort, reseller, endpoint, or wrapper does not
create another lineage; unknown lineage is presumed correlated. A judge cannot vote on
work generated or edited by its own lineage.

Each configuration is run in both orientations under the same `config_id` but fresh
judge-instance, session, and invocation IDs. An orientation contradiction or asymmetric
abstention is a failure, never a confidence-based tie break. Calibration denominators
do not shrink; only one allowlisted infrastructure retry gets a fresh session and both
attempt receipts. No retry follows a substantive answer, abstention, or parse failure.

`p >= 0.05` in a conventional bias test is not evidence of negligible bias. The frozen
position gate uses 240 unique mirrored pairs per configuration, 480 calls, and permits
at most 6 canonical-winner reversals; 7 fails. Each lineage also receives 300
human-quality-matched probes orthogonally crossing position, candidate lineage, and
verbosity. Self-lineage and verbose-candidate selections must each lie in 135–165/300,
the exact-binomial TOST acceptance region for `[0.40,0.60]` at alpha .05. Builder
rationales are never shown to production judges.

On the HCM-v2 human confirmatory corpus, every machine emits `p_A`, `p_tie`, `p_B`, and
`abstain`. Probabilities sum to one. Required target-user gates are coverage at least
0.80; cluster-bootstrap 95% lower Brier-skill bound above zero against frozen global,
brief-family, and legally available computational baselines; calibration-in-the-large
absolute error at most .05 per class; weighted calibration error at most .08 with 95%
upper bound at most .12; repeat stability at least .95; machine/human orientation
effects equivalent within +/- .05; and positive Brier-skill lower bound in every
claimed viewport, domain, and demographic stratum. A failed stratum narrows the claim.

The separate designer qualifier freezes 120 decisive pairs across six strata. A human
winner has at least 7/10 designer votes overall and 3/5 in each orientation. A machine
configuration is correct only if both mirrors choose that winner; at least 84/120,
Wilson 95% lower bound above .60, macro agreement at least .70, and every stratum at
least .60 are required. Public TASTE cannot supply this private holdout.

Panel aggregation occurs inside empirical error-correlation clusters, one vote per
cluster. On the human holdout, use 10,000 stratified bootstrap replicates; merge
identical error vectors, CAPA lower-95% at least .75, or double-fault frequency at least
twice independence expectation with Holm-adjusted `p<=.01`. Using upper-95% phi
correlations, require effective panel size at least 3.0 and a strict majority of at
least three eligible non-abstaining clusters. Otherwise return `UNKNOWN`.

## Execution, prompt, and genericness lock

The exact prompt bytes delivered on stdin are hashed into the request receipt. That
receipt also binds model/effort/profile, base lineage, revision, brief, contract lock,
direction lock, input assets, capabilities, and output tree. Capture receipts bind real
browser pixels plus DOM/state/task evidence to that build. Judge receipts bind blinded
stimuli to eligible configuration fingerprints. A filename, environment variable,
fake CLI, or self-reported model name is not consumption or provenance evidence.

Every UI task creates exactly three meaningfully divergent current directions. The
reference packet contains 3–5 same-category references plus one wildcard, each with
provenance, screenshot digest, borrow/transform/avoid notes, and a no-clone boundary.
The coordinator selects one rendered direction; the benchmark has two final arms:
locked incumbent versus selected current. Direction lock, optimized prompt digest,
build receipt, capture receipt, and judge stimulus are distinct identities.

Prompt optimization is a measured equal-compute tournament, not global line
deduplication. The current compiler's whole-document duplicate-line removal is unsafe
for JSON, quoted examples, and repeated structural delimiters and must be replaced by
typed-section transformations. The current comparator's contract-equivalence `WIN` is
not a downstream product-quality metric; optimized prompts must not be generated and
then deleted; and a prompt path or environment variable does not prove consumption.
Every arm therefore binds source, compiled, delivered, and consumed prompt bytes with
separate SHA-256 receipts, and a stdin adapter proves the consumed bytes.

Adaptive search never reads sealed validation labels. After the 12-brief wiring smoke,
it may learn only from the 192-brief development bank. Once one finalist enters the
300-brief one-bit validation, its prompt bytes and policy are immutable; failure burns
that set and reveals no item-level outcomes. Promotion needs at least 183/300 wins with
identical provider, model revision, effort, seed policy, token budget, tools, network,
sandbox, browser, references, and skills, three paired build replicates per brief, zero
repairs, and no hard-gate regression. Its maximum local label is
`PROMPT_OPTIMIZER_SELECTED_NOT_CERTIFIED`.

Perceptual hashes detect duplicate/provenance reuse, not aesthetic quality. Layout
graphs, reading flow, component signatures, copy patterns, and cross-brief similarity
are diagnostics. Until their false-positive rate is calibrated against human
genericness labels, machine output is only `NO_REVIEW`, `REVIEW_REQUIRED`, or `UNKNOWN`;
it cannot independently pass or fail taste. The sealed qualification uses seven
designers per example, labels generic only at at least 5/7 and non-generic only at at
most 2/7, and preserves 3–4/7 as unknown. It includes hard negatives for a shared
design system, conventional patterns, accessibility controls, and responsive or
localized variants. Before any stronger authority, it must reach at least 97/112
sensitivity positives, no more than 9/311 false positives, at least 113/139 precision
on a natural stream, and no more than 30 false positives in each preregistered subgroup
of 480 negatives with multiplicity correction.

## Resource and retention lock

The host has roughly 18 GiB free, so a 1,000-brief campaign cannot retain every
intermediate build and duplicate every viewport. Every phase recomputes:

`retained_CAS + remaining_selected_bound + max_active_stage + 5 GiB safety floor`

and refuses new calls if the bound does not fit. Storage is content-addressed over
original bytes. Orientations and judges reference one capture object; they never copy
it. Accepted PNG/JPEG evidence remains byte-exact. Text/source archives may use
deterministic `gzip -n -9` only when decompression reproduces the recorded digest.
Objects become read-only after atomic publication. Leased cleanup can remove only
unreferenced temporary staging. All final claim ancestors remain pinned and are
hash-verified again before publication.

The campaign is shardable by frozen brief IDs. A shard boundary changes neither the
sample denominator nor the split. Calls, retries, builds, captures, source bytes,
staging, quarantine, and retained bytes all have manifest-derived hard ceilings before
the first external call.

## Lifecycle lock

Cycle 41 committed a valid external-open handoff, after which host logic mixed external
and autonomous checks, modified committed evidence, deleted status files, and spawned
a pointless repair. Acceptance therefore gains `evidence_kind` independently from
cadence `tier`. A subgoal is evidence-homogeneous; fresh autonomous manifests cannot
target external-kind subgoals. External-open is evaluated only after all targeted
autonomous evidence passes.

A worker handoff is immutable. Progress is measured from durable state transitions,
not changing tmux pane hashes. The supervisor has an elapsed progress deadline. Runner
recovery may checkpoint implementation, but may never manufacture, normalize, append
to, delete, or recommit worker-owned marker/verdict bytes.

## Primary references

- Miniukovich and Figl human homepage dataset/article:
  https://pmc.ncbi.nlm.nih.gov/articles/PMC10823051/
- TASTE professional-designer multidimensional preference dataset:
  https://arxiv.org/abs/2605.20731
- TASTE public data and immutable repository metadata:
  https://huggingface.co/datasets/purvanshi/TASTE
- MLLM as a UI Judge human/MLLM benchmark:
  https://arxiv.org/abs/2510.08783
- Visual Aesthetic Benchmark expert-comparison design:
  https://arxiv.org/abs/2605.12684
- Position bias in LLM judges:
  https://arxiv.org/abs/2406.07791
- VisAWI-S validated website-aesthetics instrument:
  https://doi.org/10.1080/0144929X.2012.694910
- Equivalence testing principles:
  https://doi.org/10.1177/1948550617697177
- Wilson score interval:
  https://doi.org/10.1080/01621459.1927.10502953
- Reusable/adaptive holdout risk:
  https://doi.org/10.1126/science.aaa9375
- OPRO prompt optimization:
  https://arxiv.org/abs/2309.03409
- TextGrad:
  https://arxiv.org/abs/2406.07496
