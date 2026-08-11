# Visual-taste certification protocol v1

## Status and scope

This is an executable specification for a future provider-neutral implementation.
It creates no browser render, human label, panel, benchmark, calibration result,
or certificate in Cycle 37. A missing adapter, receipt, field, or predicate is
an evidence failure, not permission to approximate the result. The coordinator
uses Bash 3.2, `jq`, `git`, a declared SHA-256 command, and explicitly declared
browser/decoder/OCR/accessibility adapters; it must never install or fetch an
adapter silently.

`HUMAN_CERTIFIED` is deliberately difficult: it is a claim about a closed,
immutable evidence chain for actual rendered briefs. It is not a compliment for
a screenshot or an attribute of a model.

## 1. Claim labels

| Label | Preconditions | Meaning | Forbidden statement |
|---|---|---|---|
| `MACHINE_EVALUATED` | Valid real-render evidence and eligible machine diagnostics, but no actual deciding human ballot requirement met. | A pinned machine configuration evaluated the bundle. | “human preference” or “certified.” |
| `HUMAN_CALIBRATED_MACHINE` | `MACHINE_EVALUATED` plus a frozen machine configuration passes the held-out human-labelled calibration predicate. | The configuration was calibrated against that specified held-out set. | “human-certified” or a claim about a changed configuration/new population. |
| `HUMAN_CERTIFIED` | All gates in §§2–10, including deciding isolated human ballots, pass. | The candidate won under this named corpus, panel, and protocol. | “universally better,” “accessible for everyone,” “not AI-made,” or “non-infringing.” |
| `NOT-CERTIFIED` | Any failed hard gate. | This manifest cannot make a certification claim. | A negative claim about the UI's intrinsic quality. |
| `UNKNOWN` / `INCONCLUSIVE` | A required external receipt, qualification, or evidence item is absent/ambiguous. | The protocol cannot decide. | A pass by inference or substitution. |

The label generator derives the label from ballot provenance and gates; no caller,
model, or release note supplies it as an input.

## Threshold registry: rationale and failure behaviour

Every number in v1 is either a frozen scope floor, a source-scale integrity rule,
or a calibration-required review trigger. No numeric rule is described as a
universal human-taste optimum.

| Rule / value | Class and rationale | Failure behaviour |
|---|---|---|
| 3–5 same-category references + 1 wildcard | Policy breadth floor: exposes category grammar without a single visual anchor and forces a transformed adjacent stimulus. | Missing/malformed reference packet: `UNKNOWN`; copied asset/copy/mark/layout: `NOT-CERTIFIED`. |
| 3 direction cards | Policy exploration floor: makes a palette-only variation falsifiable before build. | Fewer than 3: `REPLAN`. |
| >=2 structural differences per pair; one pair >=3 | Policy anti-fixation floor: color/type alone are weak divergence. | Relabelled or insufficiently different cards: `REPLAN`. |
| 2 initial candidates | Bounded champion–challenger comparison unit; it avoids unbounded best-of-N search. | Missing/mismatched candidate: `UNKNOWN`; extra candidate cannot silently enter ballots. |
| Desktop 1440x900; mobile 390x844 | Frozen comparable viewport evidence for web hierarchy and native narrow rendering. | Wrong, resized, or absent capture: `NOT-CERTIFIED`; unavailable browser adapter: `UNKNOWN`. |
| Pointwise 1–7 anchors | Human-observation scale tied to rubric anchors, not a promotion score. | Out-of-range/missing/reasonless score invalidates ballot; no average threshold can pass a hard gate. |
| >=5 raw human ratings per selected corpus image | Minimum source-label support before treating a page as a calibration item. | Source record excluded; quota failure: `TASTE-CORPUS-UNAVAILABLE`. |
| Raw/aggregate delta <=0.01 | Source-scale integrity tolerance, not a taste margin. | Mismatch: `TASTE-CORPUS-UNAVAILABLE`. |
| 180 calibration / 72 holdout, 60/24 per domain | Fixed finite, stratified initial corpus that keeps tuning separate from a usable holdout. | Any domain shortfall or changed split: `TASTE-CORPUS-UNAVAILABLE`; no rebalancing. |
| Pair delta >=1.00 native scale and 95% bootstrap interval excludes zero | Avoids pairs whose source human label is ambiguous after normalization. | Pair omitted; insufficient pairs/holdout: `UNKNOWN`. |
| Calibration 24 pairs, >=17 correct (70.8%), Wilson LCB >=0.50 | Frozen finite qualification; 17 is the smallest integer above 70%, Wilson prevents raw small-n overclaim. | Judge/configuration excluded; related quota failure: `UNKNOWN`. |
| >=12 side probes, exact p >=0.05 | Small screen for gross left/right tendency; passing does not prove absence of bias. | Judge excluded. |
| >=8 mirror probes, <2 contradictions | Small screen for unstable reversal; it detects rather than erases order effects. | Judge excluded. |
| 1 A/B + 1 B/A exposure from different judges per group | Mandatory side reversal while preserving individual isolation. | Group invalid; it cannot be imputed or repaired post hoc. |
| >=5 eligible complete mirrored human groups per brief | Frozen evidence floor, operationalized more strongly than five single ballots. | Brief is `UNKNOWN`; no tie-break or model substitute. |
| >=10 varied briefs and >=7 brief wins | Frozen corpus coverage floor plus a corpus-majority requirement. | Certificate remains `UNKNOWN`. |
| 20 varied briefs for the real old-versus-new study; compiler capacity 100 | Scale target, not a replacement for the frozen ten-brief floor: prompts are sampled units and repeated votes on a few screens do not broaden coverage. | An undersized live study may meet only the ten-brief minimum label; changed/overflowed manifest needs a new study version. |
| pooled preference >=0.70 and 95% Wilson LCB >0.50 | Project acceptance margin plus conservative uncertainty floor. | Certificate remains `UNKNOWN`, not “almost certified.” |
| 0 accessibility regressions | Non-compensatory rights/access floor; no visual preference may buy a regression. | `NOT-CERTIFIED`. |
| pair sameness >=6; same-structure+surface; pHash <=4; repeated combo >=3 | Calibration-required starters that surface repeated structural/surface/signature combinations without treating a single motif as copying. | Blinded human review required; unresolved: `UNKNOWN`; no AI/copy conclusion from trigger alone. |
| <=2 targeted repairs per brief/design lock | Frozen bound against latest-wins, forgotten constraints, and endless polishing. | Third/non-material/drifting/oscillating repair: `REPLAN`; preserve incumbent. |
| Perceptual duplicate threshold for required captures | Must be declared before capture because it is renderer/domain sensitive. | Omitted/changing threshold: `UNKNOWN`; below threshold: non-material/duplicate evidence. |

## 2. Protocol state machine

```text
NEW
  -> BRIEF_LOCKED
  -> REFERENCES_VALIDATED
  -> DIRECTIONS_VALIDATED
  -> CANDIDATES_BUILT
  -> CAPTURES_VALIDATED
  -> HARD_GATED
  -> POINTWISE_SEALED
  -> MIRRORS_COMPLETE
  -> BRIEF_SELECTED
  -> CORPUS_AGGREGATED
  -> CERTIFIED | NOT_CERTIFIED | UNKNOWN

BRIEF_SELECTED
  -> REPAIR_1_STARTED -> REPAIR_1_CAPTURED -> HARD_GATED -> POINTWISE_SEALED -> MIRRORS_COMPLETE -> BRIEF_SELECTED
  -> REPAIR_2_STARTED -> REPAIR_2_CAPTURED -> HARD_GATED -> POINTWISE_SEALED -> MIRRORS_COMPLETE -> BRIEF_SELECTED

Any state -> NOT_CERTIFIED  (failed hard gate, proven tamper, invalid/duplicate render,
                              injected or unblinded stimulus, failed task/accessibility)
Any state -> UNKNOWN         (missing/ambiguous/external receipt, unavailable adapter,
                              insufficient eligible evidence)
BRIEF_SELECTED -> REPLAN    (third repair, design-lock drift, non-material repair,
                              plateau/repeated rejection, oscillation, material scope change)
```

The coordinator writes append-only events. A transition is legal only when the
predecessor event, all referenced digests, expected state, and monotonic repair
counter validate. It does not infer completion from a status marker, a prose
review, or a nonempty file. `REPLAN` starts a new brief/design lock and a new
evidence chain; it cannot reuse old ballots as a result.

### State transition rules

| From | Required proof | To | Failure behaviour |
|---|---|---|---|
| `NEW` | Canonical brief bytes and scope declaration. | `BRIEF_LOCKED` | Missing/changed bytes: `UNKNOWN`. |
| `BRIEF_LOCKED` | Valid reference contract; no-copy transformations. | `REFERENCES_VALIDATED` | Licence/provenance gap: `UNKNOWN`; disallowed asset/copy: `NOT-CERTIFIED`. |
| `REFERENCES_VALIDATED` | Three divergent direction cards and product-signature tests. | `DIRECTIONS_VALIDATED` | Palette-only variants or generic signature: `REPLAN`. |
| `DIRECTIONS_VALIDATED` | Exactly two candidate source identities tied to the same lock. | `CANDIDATES_BUILT` | Source/lock mismatch: `NOT-CERTIFIED`. |
| `CANDIDATES_BUILT` | Complete declared real-browser capture matrix for both candidates. | `CAPTURES_VALIDATED` | Missing, undecodable, stale, synthetic, wrong-viewport, or duplicate capture: `NOT-CERTIFIED`; unavailable adapter: `UNKNOWN`. |
| `CAPTURES_VALIDATED` | Task and accessibility veto receipt for every required state. | `HARD_GATED` | Any failed/unknown veto: `NOT-CERTIFIED`/`UNKNOWN`; no taste vote opens. |
| `HARD_GATED` | Immutable pointwise records from qualified judges. | `POINTWISE_SEALED` | Missing/late/identity-leaked pointwise: invalidate ballot; quota failure is `UNKNOWN`. |
| `POINTWISE_SEALED` | Complete paired A/B and B/A isolated ballot groups. | `MIRRORS_COMPLETE` | Order contradiction, one-sided tie, missing mirror, or invalid judge: exclude group; quota failure is `UNKNOWN`. |
| `MIRRORS_COMPLETE` | Per-brief qualified human aggregation. | `BRIEF_SELECTED` | No strict group winner or failed threshold: `UNKNOWN`, never a random tie-break. |
| `BRIEF_SELECTED` | Ten-brief corpus aggregation plus all cross-brief reviews resolved. | `CORPUS_AGGREGATED` | Missing/ambiguous brief/review: `UNKNOWN`. |
| `CORPUS_AGGREGATED` | Claim-label derivation and complete manifest closure. | `HUMAN_CERTIFIED` / lower label | Any closure mismatch: `NOT-CERTIFIED`. |

## 3. Common contract conventions

All JSON files have `schema_version`, `run_id`, RFC 3339 UTC timestamps, and a
canonical UTF-8 serialization. Digests are lower-case SHA-256 values. Opaque IDs
are generated independently of candidate side, author, provider, source path,
or version. Every record contains `previous_event_sha256` where it belongs to the
append-only event chain. Unknown fields are rejected until a new schema version
is approved; a parser must not silently coerce numeric strings, timestamps, or
empty arrays into valid evidence.

An adapter receipt has this minimum shape:

```json
{
  "schema_version": "taste-adapter-receipt/v1",
  "adapter_id": "browser-capture",
  "adapter_version": "declared-version",
  "command_sha256": "<sha256>",
  "input_sha256": ["<sha256>"],
  "output_sha256": ["<sha256>"],
  "exit_status": 0,
  "executed_at": "2026-08-11T00:00:00Z"
}
```

The coordinator compares these inputs and outputs with its own manifest. A
receipt only binds an adapter's reported facts; it does not prove a compromised
host, human identity, or legal conclusion.

## 4. Immutable inputs

### 4.1 Brief lock

```json
{
  "schema_version": "taste-brief/v1",
  "brief_id": "brief-opaque-001",
  "brief_sha256": "<sha256>",
  "target_population": {"role": "declared", "locale": "declared", "coverage_limit": "declared"},
  "core_task": {"id": "task-1", "success_oracle": "declared executable condition"},
  "required_routes": ["/declared"],
  "required_states": ["default", "loading", "empty", "validation-error", "success", "focus", "mobile"],
  "acceptance_facts_sha256": "<sha256>",
  "rubric_version": "taste-rubric/v1",
  "locked_at": "2026-08-11T00:00:00Z"
}
```

Only states applicable to the brief are listed; each omitted common state needs
an explicit brief-linked `not_applicable` rationale. Changing the task, audience,
route, required state, or acceptance fact creates a new lock and requires
`REPLAN`.

### 4.2 References and direction cards

```json
{
  "schema_version": "taste-reference-packet/v1",
  "brief_sha256": "<sha256>",
  "same_category_references": [
    {"reference_id":"r1","url":"https://example.invalid","license":"recorded","license_url":"https://example.invalid/license","observed_pattern":"abstract pattern","transform":"translate","no_copy_boundary":"no assets, copy, marks, or distinctive composition"}
  ],
  "wildcard_reference": {"reference_id":"w1","category":"adjacent","observed_pattern":"abstract pattern","transform":"invert","brief_reason":"task-linked"},
  "pattern_matrix_sha256": "<sha256>"
}
```

There must be 3–5 same-category references and exactly one adjacent wildcard.
Reference count creates breadth, not a licence or originality claim. A missing
licence/URL/transform/no-copy boundary is `UNKNOWN`; reference asset/copy/mark or
distinctive-layout reuse is `NOT-CERTIFIED` for that candidate and may require
external IP review.

```json
{
  "schema_version": "taste-direction/v1",
  "brief_sha256": "<sha256>",
  "directions": [
    {"direction_id":"d1","layout_family":"enum","density_band":"enum","navigation_archetype":"enum","primary_information_unit":"enum","signature":{"mechanism":"task-specific aid","anchor":"screen-region","brief_trace":"brief clause","counterfactual":"fails unrelated brief","task_proof":"capture key"},"anti_goals":["declared"]}
  ]
}
```

Exactly three direction cards are required before rendering. Every pair differs
on at least two of layout family, density band, navigation archetype, and primary
information unit; at least one pair differs on three. A signature must pass all
five checks: mechanism, brief trace, anchor, unrelated-brief counterfactual, and
rendered task proof. The coordinator selects two direction IDs for the initial
candidates and records the exclusion reason for the third. Failing divergence or
signature is `REPLAN`, not an invitation to relabel colors.

### 4.3 Corpus/study manifest and separate tracks

```json
{
  "schema_version":"taste-study-manifest/v1",
  "study_id":"taste-study-opaque",
  "brief_floor":10,
  "target_locked_briefs":20,
  "compiler_capacity":100,
  "brief_sampling":{"method":"frozen stratified prompt/brief draw","population":"declared product archetypes, complexity, and viewports","manifest_sha256":"<sha256>"},
  "executable_core":{"offline":true,"asset_licenses":["owned","public-domain","CC0","OFL","MIT","BSD","Apache"],"task_scripts_sha256":"<sha256>"},
  "tracks":["render_fidelity","human_taste","grounding","functional_success"],
  "optional_audits":["Design2Code","TASTE","Vibe-Design-Arena","UICrit","UIClip","VisualWebArena"]
}
```

No single public dataset is sufficient for all four tracks. The Miniukovich–Figl
CC0 collection remains the separately fetched primary **human-label calibration**
source, not a default redistributable executable corpus. The official executable
benchmark must instead use locally cleared, offline pages with deterministic
task scripts and per-file licence/asset receipts. Each optional audit retains
its own source terms, access and rights receipt. A fidelity, taste, grounding,
or function result is reported in its own track; no blended score may substitute
for a hard gate. Fewer than 10 valid locked briefs is `UNKNOWN`. The planned
old-versus-new study targets 20; manifest/compiler inability to preserve all
locked inputs up to 100 is an implementation failure, not a reason to silently
shrink or repeat the prompt sample.

## 5. Candidate and live browser-render contract

```json
{
  "schema_version": "taste-candidate/v1",
  "candidate_id": "cand-opaque-a",
  "brief_sha256": "<sha256>",
  "design_lock_sha256": "<sha256>",
  "direction_id": "d1",
  "source_revision": "<git-tree-or-commit-sha256>",
  "dependency_lock_sha256": "<sha256>",
  "build_receipt_sha256": "<sha256>",
  "created_at": "2026-08-11T00:00:00Z"
}
```

```json
{
  "schema_version": "taste-capture-manifest/v1",
  "candidate_id": "cand-opaque-a",
  "candidate_source_revision": "<sha256>",
  "browser": {"adapter_receipt_sha256":"<sha256>","command":"declared command","version":"declared","profile_sha256":"<sha256>"},
  "environment": {"locale":"en-US","timezone":"UTC","color_scheme":"light","device_scale_factor":1},
  "captures": [
    {"capture_id":"cap-1","route":"/declared","state":"default","action_trace_sha256":"<sha256>","viewport_css_px":{"width":1440,"height":900},"screenshot_png_sha256":"<sha256>","decoded_pixel_sha256":"<sha256>","decoded_width":1440,"decoded_height":900,"dom_sha256":"<sha256>","captured_at":"2026-08-11T00:00:00Z"},
    {"capture_id":"cap-2","route":"/declared","state":"mobile","action_trace_sha256":"<sha256>","viewport_css_px":{"width":390,"height":844},"screenshot_png_sha256":"<sha256>","decoded_pixel_sha256":"<sha256>","decoded_width":390,"decoded_height":844,"dom_sha256":"<sha256>","captured_at":"2026-08-11T00:00:00Z"}
  ]
}
```

### JSON example validation

Every fenced `json` example is a contract example, not illustrative pseudo-JSON.
In particular, `taste-capture-manifest/v1` has one root `candidate_id`; source
identity is the distinct `candidate_source_revision` field. Before a protocol
change is accepted, parse every example and reject duplicate object-key paths:

```bash
example_dir=$(mktemp -d)
trap 'rm -rf "$example_dir"' EXIT
awk -v dest="$example_dir" '
  /^```json$/ { in_json=1; n++; file=sprintf("%s/example-%02d.json", dest, n); next }
  /^```$/ && in_json { close(file); in_json=0; next }
  in_json { print > file }
' docs/polylane/taste-certification/PROTOCOL.md
for example in "$example_dir"/*.json; do
  jq -e . "$example" >/dev/null
  duplicates=$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("\u001f")' "$example" | sort | uniq -d)
  test -z "$duplicates" || { printf 'duplicate JSON key path: %s\n' "$duplicates" >&2; exit 1; }
done
```

Required capture keys are the Cartesian product of each declared route and
applicable state, at desktop **1440×900** and mobile **390×844**, except a
mobile-only state whose documented key still requires native 390×844 evidence.
Every capture must result from the declared browser adapter after the candidate
source revision is fixed, decode as an image, match its requested route/state/
viewport/environment, and have a replayable action trace. A static mock, file
header, resized desktop image, source-only screenshot, caller supplied `pass`,
or image older than the candidate source cannot enter the manifest.

Different required keys must have nonduplicate decoded-pixel digests. An exact
duplicate, or a perceptual duplicate at the frozen same-viewport threshold,
fails as `DUPLICATE_RENDER` unless a reviewed invariant explains why the *same
state* is intentionally identical; it never explains desktop as mobile or one
state as another. The threshold is versioned before capture. Missing/invalid
decoder, OCR, browser, or comparison adapter is `UNKNOWN`; stale/wrong/fake/
duplicate capture is `NOT-CERTIFIED`.

## 6. Hard gates before any taste judgement

```json
{
  "schema_version": "taste-hard-gate/v1",
  "candidate_id": "cand-opaque-a",
  "capture_manifest_sha256": "<sha256>",
  "task_results": [{"task_id":"task-1","capture_id":"cap-1","status":"pass","trace_sha256":"<sha256>"}],
  "accessibility": [{"capture_id":"cap-1","ruleset":"WCAG-2.2-declared-scope","adapter_receipt_sha256":"<sha256>","status":"pass","manual_exception_ids":[]}],
  "state_coverage": [{"capture_id":"cap-1","status":"pass"}],
  "product_specificity": {"signature_test_sha256":"<sha256>","status":"pass"},
  "overall": "PASS"
}
```

Before pointwise or pairwise judging, every candidate must pass the frozen task
oracle and accessible path for every required state: applicable semantic,
keyboard/focus, contrast, reflow/overflow, target-size, and motion checks plus
the declared manual exception ledger. A missing, unknown, failed, skipped, or
post-hoc exception is an accessibility veto. The baseline must itself be
eligible: `zero accessibility regression` means no required current-candidate
criterion regresses from the accepted eligible incumbent; it never permits an
inaccessible baseline to pass. A positive taste vote cannot offset any hard
gate. Failed gates are `NOT-CERTIFIED`; unavailable required evidence is
`UNKNOWN`.

## 7. Pointwise, calibration, isolation, and mirrored ballots

### 7.1 Pointwise record

```json
{
  "schema_version": "taste-pointwise/v1",
  "ballot_id": "ballot-opaque-1",
  "judge_id": "judge-opaque-1",
  "candidate_id": "stimulus-opaque-a",
  "brief_sha256": "<sha256>",
  "capture_manifest_sha256": "<sha256>",
  "scores_1_to_7": {"product_fit":5,"hierarchy":5,"typography":5,"color_imagery":5,"spatial_rhythm":5,"simplicity":5,"expressiveness":5,"craftsmanship":5,"originality":5,"state_coherence":5,"interaction_feedback":5},
  "observations": [{"criterion":"hierarchy","capture_id":"cap-1","region_or_state":"header","severity":"medium","brief_clause":"task-1","reason":"observable and brief-specific","proposed_change":"bounded"}],
  "identity_visible": false,
  "prior_ballots_visible": false,
  "sealed_at": "2026-08-11T00:00:00Z"
}
```

Scores are anchored diagnostic observations, not a compensatory composite.
Each candidate is displayed alone under the same brief and complete evidence
bundle. Reasons must name a capture/state/region and brief clause; generic
adjectives are invalid. The pairwise control remains disabled until both
candidate records are immutable. This preserves evidence when both choices are
poor and stops comparison from erasing product/task context.

### 7.2 Calibration and judge eligibility

```json
{
  "schema_version": "taste-calibration/v1",
  "calibration_set_id": "human-ui-calibration/v1",
  "human_label_source":"pinned held-out corpus manifest digest",
  "human_labelled_pairs":24,
  "calibration_manifest_sha256":"<sha256>",
  "judge_configuration": {"kind":"human-or-machine","provider":"only-for-machine","model":"only-for-machine","model_version":"only-for-machine","system_prompt_sha256":"only-for-machine","sampling_sha256":"only-for-machine"},
  "correct":17,
  "accuracy":0.708333,
  "wilson_lcb_95":0.50,
  "side_probe_n":12,
  "side_probe_exact_binomial_p":0.05,
  "mirror_probe_n":8,
  "mirror_contradictions":0,
  "result":"eligible"
}
```

The calibration set contains pre-existing human labels and is disjoint by ID,
source URL, decoded-pixel hash, perceptual-hash cluster, hostname, prompt,
candidate, and certification brief. The source corpus contract is: CC0 receipt,
unique image-to-rating join, at least five valid raw human ratings per selected
image, source-native aggregate recomputation within 0.01, duplicate removal,
and within-domain high/low pairs at least 1.00 native-scale point apart with a
95% bootstrap difference interval excluding zero. The fixed initial split is
180 calibration / 72 holdout pages across three domains (60/24 per domain); a
domain quota failure is `TASTE-CORPUS-UNAVAILABLE`.

A human or machine configuration is eligible only if it gets **at least 17 of
24** held-out labels correct (70.8%) and a recomputed two-sided 95% Wilson lower
bound of **at least 0.50**. It also needs at least **12** balanced side probes
with exact-binomial `p >= 0.05`, at least **8** pre-registered mirror probes,
and fewer than **2** mirror contradictions. These are policy floors: 24 makes
the test finite; 17/24 is the smallest integer above 70%; Wilson prevents a
small-sample raw rate masquerading as precision; probes expose gross side or
mirror bias. Failing/changed/incomplete configuration means exclusion; a model
cannot become calibrated by re-running the same holdout. Passing machine
calibration affects only the `HUMAN_CALIBRATED_MACHINE` label.

Each deciding human also provides a consent/independence attestation: no
authorship/identity knowledge, no shared ballot channel, no coordination, and
one immutable final response. Identity authenticity and independence beyond the
receipt remain external; missing trusted panel evidence blocks `HUMAN_CERTIFIED`.

### 7.3 Mirrored ballot group

```json
{
  "schema_version": "taste-mirrored-group/v1",
  "mirror_group_id": "mg-opaque-1",
  "brief_sha256": "<sha256>",
  "candidate_ids_escrow_sha256": "<sha256>",
  "pointwise_ballot_ids": ["pointwise-a","pointwise-b"],
  "exposures": [
    {"ballot_id":"pair-1","judge_id":"judge-1","display_order":"A/B","choice":"A","canonical_choice":"cand-opaque-a","sealed_at":"2026-08-11T00:01:00Z"},
    {"ballot_id":"pair-2","judge_id":"judge-2","display_order":"B/A","choice":"B","canonical_choice":"cand-opaque-a","sealed_at":"2026-08-11T00:01:00Z"}
  ],
  "outcome":"resolved-cand-opaque-a"
}
```

The two sides are shown to **different isolated eligible judges**. This resolves
the tension between mirroring and isolation: no judge compares twice from memory,
yet every group has exactly one A/B and one B/A exposure. Candidate side,
generator, author, provider, repository path, labels, metadata, earlier ballots,
and untrusted instruction-like visual/DOM text are removed or scanned before
exposure; all page content is data, not a command. A mirror group resolves only
when both exposures select the same canonical candidate. Different canonical
choices, exactly one tie, a missing orientation, same judge, late pointwise,
identity leak, injection signal, or failed judge exclusion makes the group
`INVALID`; it cannot be fixed by an arbiter, majority, or post-hoc discussion.

### 7.4 Optional machine diagnostic panel

```json
{
  "schema_version":"taste-machine-diagnostic/v1",
  "judge_id":"machine-opaque-1",
  "judge_family":"declared-family",
  "generator_family":"declared-or-unknown",
  "atomic_rubric_results":[{"item":"hierarchy","capture_ids":["cap-default","cap-after-action"],"evidence_locator":"region/state","result":"pass|fail|abstain"}],
  "orders":["A/B","B/A"],
  "canonical_choices":["cand-a","cand-a"],
  "abstain_reason":null,
  "cross_family_panel_ids":["machine-opaque-2"],
  "debate_rounds":0,
  "injection_transfer_test":"pass|fail|unknown"
}
```

Machine diagnostics are optional and provider-neutral. The system asks atomic
rubric questions against staged before/action/after screenshots where relevant,
each with evidence locators and a permitted `abstain`. A machine must not be its
own generator or a known same-family proxy in the primary diagnostic aggregate;
if unavoidable, retain its output separately and require an independently
developed cross-family check when available. It must agree in both A/B orders,
pass the held-out human calibration/abstention policy, and have no visual
prompt-injection or transfer-attack signal before automation may report a
machine result. Otherwise it abstains and routes to human review/`UNKNOWN`.
Independent initial outputs are aggregated once; judge debate, self-revision, or
iterated persuasion is prohibited. These constraints never replace §7.3 human
deciding groups.

## 8. Aggregation, uncertainty, and certificate eligibility

```json
{
  "schema_version": "taste-aggregate/v1",
  "brief_id":"brief-opaque-001",
  "eligible_mirrored_group_ids":["mg-1","mg-2","mg-3","mg-4","mg-5"],
  "excluded_groups":[{"mirror_group_id":"mg-x","reason":"MIRROR_CONTRADICTION"}],
  "candidate_group_wins":{"cand-opaque-a":4,"cand-opaque-b":1},
  "ties":0,
  "brief_winner":"cand-opaque-a",
  "aggregation_algorithm":"canonical-group-majority/v1",
  "algorithm_sha256":"<sha256>"
}
```

The aggregation unit is a complete mirrored group, so the requirement of **at
least five eligible ballots per brief** is met by at least five complete eligible
mirrored groups (ten isolated human exposures), a stricter and auditable form of
the floor. A per-brief winner requires a strict group majority; no tie is
broken. Machine groups are stored separately and do not add to the human count.

For a corpus candidate to receive `HUMAN_CERTIFIED`, all of the following must
be true:

1. At least **10** varied briefs have unique locked brief IDs, categories,
   product tasks, source revisions, and nonduplicate render evidence.
2. Every brief has at least **5** eligible complete mirrored human ballot
   groups, a valid hard-gate receipt, and no unresolved evidence, access, or
   cross-brief review.
3. The candidate is the strict winner in at least **7 of 10** briefs.
4. Across every resolved eligible human mirrored group in the corpus, its
   `candidate_group_wins / resolved_groups` is **at least 0.70** and its
   recomputed two-sided 95% Wilson lower confidence bound is **strictly greater
   than 0.50**.
5. Accessibility regressions equal **0**, every required task passes, and all
   relevant state coverage is complete.

Use `z = 1.959964` and integer wins `w`, denominator `n`, `p = w/n`:

```text
denom  = 1 + z^2/n
center = (p + z^2/(2*n)) / denom
margin = z * sqrt((p*(1-p) + z^2/(4*n))/n) / denom
wilson_lcb_95 = center - margin
```

Ten and five are frozen coverage floors, seven makes the corpus majority
explicit, 70% is the project acceptance preference floor, and Wilson `> 0.50`
prevents a raw majority with insufficient evidence from sounding decisive. They
are not claimed to be population power calculations. A failed percentage,
bound, quorum, tie, or unresolved exclusion is `UNKNOWN`, not a lower standard.

For the planned twenty-or-more-brief old-versus-new study, store raw choices as
judgments nested in sampled briefs/prompts, candidate seeds, and raters. Keep
the frozen Wilson result as the minimum visible gate, then run a preregistered
tie-aware hierarchical Davidson–Bradley–Terry analysis by track, a
Thurstone–Mosteller sensitivity analysis, and prompt-and-rater cluster bootstrap
intervals. Elo/Glicko may track exploratory operations but cannot choose the
confirmatory winner. Repeated votes on one prompt are not independent prompt
evidence, and a post-unblinding sample increase, analysis switch, or exclusion
change is a new study manifest, not a repaired result.

## 9. Cross-brief sameness and the four independent review axes

```json
{
  "schema_version":"taste-sameness-sidecar/v1",
  "brief_id":"brief-opaque-001",
  "candidate_id":"cand-opaque-a",
  "category":"declared","unrelated_group":"declared",
  "render":{"capture_id":"cap-1","viewport":"1440x900","screenshot_sha256":"<sha256>","phash64":"optional"},
  "visual":{"layout_family":"enum","primary_information_unit":"enum","density_band":"enum","navigation_archetype":"enum","palette_family":"enum","accent_hue_bin":"enum","type_pair_class":"enum","shape_language":"enum"},
  "signature":{"mechanism":"task-specific","anchor":"region","brief_trace":"brief clause"},
  "constraint_exception":{"brand_locked":false,"rationale":null},
  "axis_results":{"genericness_review":"unknown","quality_risk":"pass","context_fit":"pass","provenance_integrity":"unknown"}
}
```

The certificate checks unrelated-brief pairs only by default. It calculates
`same_structure` (same layout family, primary information unit, and navigation;
weight 3), `same_system` (same density and shape; weight 1), `same_surface`
(same palette, accent bin, and type class; weight 2), and `same_signature`
(same mechanism and anchor; weight 4). `pair_sameness` is the sum. A score of
**6 or more**, `same_structure && same_surface`, an equal screenshot digest, a
same-viewport perceptual-hash distance at or below **4**, or the same
layout/palette/type/signature combination in **3 or more** unrelated briefs
triggers a blinded human `CROSS_BRIEF_REVIEW`.

The ten-brief corpus floor, score 6, pHash distance 4, and repeated-combination
count 3 are starter policy triggers chosen to avoid treating one common category
cue as proof while exposing repeated structural/surface/signature combinations.
They must be frozen before rendering and later calibrated on held-out
human-labelled "looks templated across brief" cases. A trigger is not a failing
taste score: the reviewer may accept a narrowly documented category/brand
constraint or route a suspected copy to external human/IP review. An unresolved
review yields `UNKNOWN`; known disallowed source reuse yields `NOT-CERTIFIED`.

The four axes never collapse:

| Axis | Permitted result | Failure behaviour |
|---|---|---|
| `genericness_review` | A clustered, calibrated review signal with coverage/false-positive receipt. | Trigger review or `UNKNOWN`; never emit AI probability/authorship/copy verdict. |
| `quality_risk` | Observable rendering, responsive, interaction, asset, or accessibility defect. | Apply hard gates; never use defect as provenance evidence. |
| `context_fit` | Match against supplied product/brand/audience/locale facts. | Missing required context is `UNKNOWN`; mismatch is a pointwise/human review finding. |
| `provenance_integrity` | Process record/attestation state. | Appearance-only default is `unknown`; suspected copying goes to external review. |

Genericness rules require reported coverage, precision, recall, false-positive,
and subgroup error rates across page type, industry, locale, viewport, and
collection date before any threshold changes. Common neutral sans faces,
gradients, cards, sparse layouts, conventional navigation, or accessibility
defects alone never prove authorship, copying, or bad taste.

## 10. Targeted repair budget and champion preservation

```json
{
  "schema_version":"taste-repair/v1",
  "repair_id":"repair-1",
  "brief_id":"brief-opaque-001",
  "design_lock_sha256":"<sha256>",
  "attempt":1,
  "incumbent_candidate_id":"cand-opaque-a",
  "finding_ids":["finding-3"],
  "affected_capture_ids":["cap-1"],
  "minimal_change_scope":["declared file/region"],
  "non_regression_checks":["task","accessibility","all capture keys"],
  "started_before_work":true,
  "previous_event_sha256":"<sha256>"
}
```

A repair is allowed only for a sealed, brief-linked finding and increments the
durable `(brief_id, design_lock_sha256)` ledger before work. It must retain the
brief/design lock, name affected capture/state, make a minimal causal change,
then recapture the full matrix, rerun hard gates, reseal pointwise observations,
and collect new mirrored groups comparing the incumbent with the repaired
challenger. The incumbent remains the champion unless the challenger clears all
gates and wins the predeclared comparison. Never replace it because a critic says
the latest version looks better.

At most **two** targeted repairs are permitted across reruns and branches for
one brief/design lock. The number bounds unvalidated iterative polishing,
history loss, and goal drift; it is not evidence that two changes are optimal.
A third request, non-material change, changed lock, repeated non-promotion,
oscillation between champions, or plateau after the two budgeted attempts is
`REPLAN`. A repair that causes any task/accessibility/state regression is
rejected and the prior eligible champion is preserved. No unused repair token is
transferred to another lock.

## 11. Certificate and failure contracts

```json
{
  "schema_version":"taste-certificate/v1",
  "run_id":"taste-run-opaque",
  "protocol_version":"taste-protocol/v1",
  "evidence_manifest_sha256":"<sha256>",
  "claim_label":"HUMAN_CERTIFIED|HUMAN_CALIBRATED_MACHINE|MACHINE_EVALUATED|NOT-CERTIFIED|UNKNOWN",
  "briefs":10,
  "eligible_human_mirrored_groups_per_brief":{"brief-opaque-001":5},
  "brief_wins":7,
  "preference_rate":0.70,
  "confidence_lower":0.500001,
  "accessibility_regressions":0,
  "calibration_receipts_sha256":["<sha256>"],
  "cross_brief_review_status":"resolved",
  "repair_ledger_sha256":"<sha256>",
  "external_limitations":["panel identity assurance scope", "population coverage scope"],
  "verdict_reason_codes":[]
}
```

The final receipt closes over the exact expected set of brief locks, candidates,
captures, hard gates, calibration records, ballot groups, exclusion reasons,
aggregation algorithm, review determinations, and repair ledger. Extra,
missing, cross-run, stale, or digest-mismatched assets are `NOT-CERTIFIED`.
`external_limitations` cannot be empty when any claim relies on human identity,
panel independence, IP/non-copying, host trust, population coverage, or manual
assistive-technology review.

## 12. Required future implementation map (no source is written in this cycle)

| Slice | Future deliverable | Verification before advancing |
|---|---|---|
| Contract parser | Versioned JSON schemas, canonical serialization, digest/event-chain validator. | Missing/unknown/changed field and non-monotonic event fixtures fail closed. |
| Capture adapters | Declared browser capture, image decoder, DOM/action trace, comparison, OCR adapters. | Header-only PNG, text-as-PNG, stale commit, resized desktop/mobile, duplicate state, wrong viewport, and adapter swap regressions fail. |
| Hard-gate runner | Task/state matrix and WCAG/manual-exception receipts. | Higher preference with keyboard/contrast/state failure cannot aggregate. |
| Corpus importer | Pinned CC0 acquisition receipt, raw rating join, duplicate guard, deterministic split/pairs/holdout lock; separate offline executable core. | Missing licence/checksum/rater count, leakage, cross-domain pair, duplicate/near-duplicate fixture, or unlicensed/non-offline core returns `TASTE-CORPUS-UNAVAILABLE`/`UNKNOWN`. |
| Ballot service/packager | Opaque IDs, pointwise sealing, isolated mirrored scheduling, calibration/exclusion receipts. | Identity token, prior ballot, visual/DOM prompt injection, same-judge mirror, side bias, tie, and calibration overlap fixtures invalidate groups. |
| Machine diagnostics | Atomic evidence-grounded items, staged captures, cross-family separation, abstention, one aggregation. | Same-family self-judge, order split, injected/transfer attack, low-calibration, or debate fixture abstains/blocks machine conclusion. |
| Aggregator/certificate | Canonical-group counts, Wilson calculation, label derivation, manifest closure; expanded prompt/rater-aware study analysis. | Model-only panel cannot derive human label; <10 briefs, <5 groups, <70%, Wilson <=.50, a11y regression, shaped exclusion, or prompt/rater-cluster omission all block/limit the claim. |
| Cross-brief review | Sidecar enumeration, trigger report, four-axis semantics, reviewed exception record. | Palette-only signal never proves AI/copying; unresolved/suspicious source reuse behaves exactly as §§9–11. |
| Repair controller | Durable two-token ledger and champion–challenger re-evaluation. | Third repair, budget reset, goal drift, non-material change, latest-wins, plateau, and oscillation fixtures route to `REPLAN`. |

## 13. Adversarial acceptance set

The next implementation must execute at least these negative cases without
network access: truncated PNG; arbitrary bytes posing as references; one render
reused for desktop/mobile/states; source-only/static flow; caller-supplied
judge pass; stale capture; wrong viewport/state; duplicate/one-pixel evasion;
hidden identity label; rendered prompt injection; calibration leakage; five
same-person/model ballots; absent opposite orientation; an accessibility failure
with higher votes; duplicate/cherry-picked briefs; self-scored numeric rows;
repair-ledger reset/third repair; goal drift; aggregate ballot omission; adapter
swap; receipt-chain mutation; source-asset reuse; and a common-font/gradient/card
false-positive control. Each must return the explicit blocked/unknown/replan
reason without silently repairing input or lowering a threshold.

## 14. Skill receipts

SKILL-READ: deep-research | /Users/leonardo/.agents/skills/deep-research/SKILL.md | 3883242303-4343

SKILL-READ: design:research-synthesis | /Users/leonardo/.codex/plugins/cache/claude-cowork/design/1.2.0/skills/research-synthesis/SKILL.md | 335799056-3014

SKILL-READ: engineering:code-review | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/code-review/SKILL.md | 936987158-4285

SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
