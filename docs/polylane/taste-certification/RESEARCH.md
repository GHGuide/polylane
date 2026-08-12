# Visual-taste certification research synthesis

## Executive summary

This is a protocol-design result, not a claim that Polylane has rendered a UI,
run a benchmark, convened a panel, calibrated a judge, or issued a taste
certificate. The evidence supports a narrow future claim: for a frozen,
product-specific corpus, a candidate may be described as preferred only when its
browser-rendered evidence, accessibility/task gates, isolated human ballots,
calibration records, and uncertainty calculation are all available and mutually
consistent. Missing evidence is `UNKNOWN`/`NOT-CERTIFIED`; persuasive prose,
fixtures, screenshots, and model confidence are not substitutions.

The protocol keeps three claim classes separate. `MACHINE_EVALUATED` means a
pinned automated configuration produced auditable diagnostic output.
`HUMAN_CALIBRATED_MACHINE` means that configuration also met a pre-registered,
held-out human-label calibration test. `HUMAN_CERTIFIED` additionally requires
the deciding isolated human ballots for the actual rendered briefs. Neither
machine agreement nor aesthetics may stand in for task success, accessibility,
factual credibility, originality, or universal preference.

The evidence base favors a lexicographic workflow: lock the brief and
transformed-reference boundaries; make divergent directions; render two
candidates in a real browser; veto inaccessible, unexecuted, stale, duplicate,
or unproven work; collect sealed pointwise observations; collect mirrored,
blinded comparative ballots from isolated judges; aggregate only qualified
human evidence; and make no more than two evidence-targeted repairs while
preserving the best eligible incumbent. Ten varied briefs and five complete
eligible mirrored ballot groups per brief are floors, not a statistical claim
that this sample represents all users. The release threshold is a pooled human
preference rate of at least **0.70** (70%) and a two-sided 95% Wilson lower bound
strictly above 0.50, alongside a majority win in at least seven briefs.

## Cycle 40–41 live-boundary update

Cycles 39–40 turned the protocol above from a design into a live harness whose
adapters are now merged in this tree; Cycle 41 freezes the real acquisition and
calibration campaign design. This section states exactly which live facts are
established and which remain future or external; the rest of this document is
the standing research synthesis behind the protocol.

**Primary corpus and its honest acquisition path.** The primary calibration
source stays Miniukovich & Figl's released homepage-evaluation corpus — 3,156
full-page homepages across commercial banking, e-commerce, and universities, with
raw and filtered aggregate ratings from 3,319 sessions on a `[-3,3]` scale, with
compliance filtering, within-participant standardization, and per-page
aggregation [9,10,11]. The three Dataverse deposits declare CC0 1.0. Acquisition
must be described truthfully: bare HTTP requests to all four documented Dataverse
metadata/export variants returned an empty **WAF** `202` challenge on the
observing host, but a fresh real Chrome session completes the challenge and a
same-context API request then returned dataset id `6830013`, release version
`4.0`, 1,074 files, and a byte-exact download of a canary file
(`ratings.avg.fashion.txt`). Cycle 40 shipped that path as an explicit,
versioned, hash-receipted **browser adapter** (`bin/polylane-taste-source.sh`
with `benchmarks/taste-live/tools/dataverse-acquire.mjs`); it does not bypass,
spoof, or hide the WAF, and it never substitutes fixture bytes for a blocked
download. A blocked corpus yields a precise external-evidence receipt, not a
fabricated dataset — the Cycle-40 unattended run's own canary was WAF-blocked
and correctly closed `EXTERNAL-EVIDENCE-OPEN`.

**Cycle-41 transport and mirror facts.** Chrome readiness is a
poll-for-valid-JSON-envelope condition, not a fixed delay; an in-page `fetch()`
of a data file fails after Dataverse redirects to object storage because the
redirected response is cross-origin — a transport limitation, not missing data.
The approved directions are a same-browser CDP download or a narrowly scoped
handoff of the fresh ephemeral WAF session; no personal browser profile, user
cookie, API key, or credential may be inspected, persisted, logged, or copied,
and an uncleared challenge is `UNKNOWN`. DataONE independently indexes
immutable metadata objects for all three releases and serves as a
provenance/discovery mirror only: downloaded bytes must still bind the Harvard
file id, canonical URL, declared size/checksum, and a locally recomputed
SHA-256, and a mirror disagreement is `SOURCE-MISMATCH`, never a majority vote
[30,31,32,33]. `SOURCE-AUDIT.md` in this directory records the observed
identities, transport facts, and frozen substitution rules in full.

**TASTE is a separate, secondary, pinned audit.** The TASTE release (Hugging Face
`purvanshi/TASTE`, repository SHA `731a7f588d433214c6d864d2e9f47978d91aed6b`) —
14,460 evaluator ranking rows over 644 images, five evaluators per group, with
dimensions including preference, typography, color harmony, and visual hierarchy —
is an orthogonal secondary audit. It is **never** a silent substitute for a failed
primary corpus: each source keeps its own provenance, scale, split, and receipt,
and a source substitution is a new manifest version, not a repaired result.

**Claim ceiling this cycle.** The retained live controls — pointwise before
pairwise, hidden candidate/provider identity, mirrored side order across different
sessions, a frozen human-label holdout, exact side-bias and contradiction screens,
multiple provider/model configurations, abstention on insufficient evidence, and a
Wilson lower bound — govern a **machine** panel whose sessions are correlated
diagnostics, not independent humans. The strongest honest label attainable without
recruited deciding people is `HUMAN_CALIBRATED_MACHINE` with `human_certified:false`.
`HUMAN_CERTIFIED` remains external and unreached.

**Frozen thresholds (no post-result change).** Study target 20 briefs, hard floor
10; at least 7 brief wins; pooled preference at least 0.70; Wilson lower bound above
0.50; at least five complete mirrored groups per brief; zero accessibility
regressions; at most two evidence-targeted repairs. The primary split is 180
calibration + 72 held-out pages, stratified 60/24 per domain; judge eligibility is
24 deterministic mirrored pairs, at least 17 correct, Wilson lower bound at least
0.50, side-probe `p >= 0.05`, and fewer than two mirror contradictions. None of
these may shrink after results.

## Method and scope

The integrator read the eight file-isolated lane reports and their verification
records, the Cycle 37 scope/plan, the canonical coordination relay, and the
read-only registry at
`/Users/leonardo/Documents/UI_Taste_Certification_Research_20260811` (50 source
records, 49 evidence records at inspection). Load-bearing rules were retained
only when they had a direct standard/dataset contract or triangulated evidence;
thresholds with no direct validation are labelled policy floors and require a
future held-out calibration. The source mix is deliberately heterogeneous:
peer-reviewed HCI/psychometrics and datasets; primary standards; human-rated
dataset contracts; UI-generation benchmarks; and first-party design-practice
descriptions. First-party material is evidence of that publisher's practice,
not independent proof of effectiveness.

The synthesis is limited to browser-rendered web UI evaluation. It does not
generalize to native mobile applications, assistive-technology use in all
contexts, every culture or locale, commercial trustworthiness, IP clearance,
or an evaluator's ability to infer authorship. DOI records may be
access-restricted to automated clients; their stable DOI URL remains the cited
identity, while the lane verification records the access limitation.

### Evidence-status vocabulary

| Status | Meaning |
|---|---|
| Direct | A study, standard, or dataset contract supports the bounded proposition. |
| Triangulated | Independent sources support the mechanism, not this exact policy value. |
| Policy floor | An auditable operating threshold chosen for safety/falsifiability; it is not presented as an empirically universal optimum. |
| External | The fact needs trusted people, legal/IP review, a live browser/adapter, or a future study; software must not claim it proved the fact. |

## Evidence synthesis

### 1. Human visual judgment has dimensions, limits, and non-compensatory boundaries

Website aesthetics has measurable but non-universal structure: classical
order/clarity and expressive creativity are separable [1]; simplicity,
diversity, colorfulness, and craftsmanship are independently measured facets
[2,3]. First impressions can form rapidly [4], yet visual complexity,
prototypicality, audience, country, and task all modify outcomes [5,6]. The
rubric therefore records product fit, hierarchy, typography/readability,
color/imagery, spatial rhythm, simplicity, visual diversity/expressiveness,
craftsmanship, originality, state coherence, and interaction feedback as
anchored *human observations*, not a universal scalar.

The contrary evidence matters. Aesthetic appeal can influence perceived
usability, but observed usability and post-use preference do not reliably
collapse into beauty [7,8]. Prototypicality can assist first impressions while
novelty can also contribute to appeal [9]. A high visual score consequently
cannot compensate for a failed task, WCAG problem, missing state, unclear
product purpose, or altered evidence. Credibility is an observer's impression,
not verification of a claim.

### 2. A human-rated calibration corpus is available, but it is not a certificate

The chosen calibration candidate is the public **Web Design Prototypicality
Data**: 3,156 homepage screenshots over banking, online shopping, and university
domains, with individual and aggregate human ratings for visual aesthetics,
prototypicality, perceived usability, and trustworthiness [10,11]. The three
Dataverse deposits provide a CC0-1.0 contract, but an importer must re-receipt
each pinned version, image/rating join, checksum, licence, raw rating count, and
scale before use. The initial deterministic plan is 180 calibration pages and
72 held-out pages, stratified 60/24 by domain, with within-domain unambiguous
pairs only. The selection is `TASTE-CORPUS-UNAVAILABLE` if a source page lacks
five valid raw human ratings, a verified image, or an unambiguous native-scale
label.

UICrit provides a useful human-rated mobile/out-of-domain audit, but its RICO
image provenance is a separate receipt and it is not a replacement for the web
calibration corpus [12]. UIClip is useful contrary evidence about pairwise
preference modelling and rater disagreement, but no public licensed acquisition
route was established for this protocol [13]. Synthetic reconstruction datasets
and visual-similarity datasets are excluded from human calibration because they
do not establish human preference.

The final 32-source corpus audit reinforces a boundary rather than replacing
the selection: no one-piece public corpus currently supplies legally clear,
human-rated web taste, executable behaviour, visual fidelity, and GUI grounding.
Miniukovich–Figl remains the **primary human-label calibration** input, fetched
and pinned separately. A future executable certification corpus instead uses
locally cleared/offline pages with owned, public-domain, CC0, OFL, MIT, BSD, or
Apache-licensed assets/components and deterministic task scripts. Design2Code,
TASTE, Vibe Design Arena, UICrit/UIClip, and VisualWebArena are optional,
separately receipted audits for fidelity, taste, critique/defect sensitivity, or
function/grounding. They must never be pooled into one opaque quality score.

### 3. Judge reliability requires both diagnostic pointwise records and blinded comparison

Pointwise scoring and pairwise choice answer different questions. Response mode
can change expressed preference [14], while comparative judgement provides a
well-established way to decide a relative ordering [15]. The protocol therefore
requires sealed, criterion-grounded pointwise observations before a comparison;
the paired choice decides only between candidates that already passed hard gates.
It permits `TIE`, never converts it to a fractional win, and preserves the
diagnosis even when no winner is selected.

Order and identity are material threats. LLM judging research observes position
bias and comparative bias [16,17], while review research shows that blinding
can reduce some identity effects but is imperfect and context-dependent [18].
Each actual comparison is consequently presented in both A/B and B/A orientations
to different isolated judges. A contradiction, one-sided tie, missing mirror,
identity leakage, prompt injection, visible prior ballots, or a failed side-bias
probe invalidates the group. Models are diagnostic only; their votes never enter
the human denominator or break a human tie.

The independent multimodal-judge report sharpens that machine boundary: a judge
must not evaluate its own output or a closely related model family without an
explicit separated result and cross-family check where available. Machine
diagnostics use atomic rubric items with evidence locators, staged UI screenshots
where a state transition matters, strict A/B+B/A agreement or abstention, and
held-out human-calibrated abstention. An order flip, panel split, visual
prompt-injection/transfer signal, missing evidence, or low predicted human
agreement routes to human review/`UNKNOWN`. Judges do not debate; one bounded
aggregation reads independent initial outputs. These controls improve machine
diagnostics only and cannot turn them into deciding human ballots.

For a larger future human-preference study, briefs/prompts—not repeat ratings of
a few screens—are sampled units. The frozen implementation floor remains ten,
but the real Polylane old-versus-new study should target twenty varied locked
briefs and make its manifest/compiler scale to one hundred. Confirmatory
analysis should model ties and prompt/rater clustering (hierarchical
Davidson–Bradley–Terry), report a Thurstone–Mosteller sensitivity analysis and
prompt/rater-cluster uncertainty, and use Elo only for exploratory tracking.
The current Wilson policy stays the minimum certificate gate rather than an
assertion that it is the only valid future analysis.

### 4. Real rendering and finite feedback are evidence primitives, not taste evidence

UI-generation studies support inspecting execution and rendered discrepancies,
but their typical target is reconstruction or benchmark performance rather
than original product taste [19,20,21]. This supports a real-browser capture
receipt (command/version, commit, route, viewport, device scale, locale,
timezone, state trace, decoded pixels, DOM/trace hashes) and local,
evidence-linked repairs. It does not support quoting a benchmark gain as a
Polylane gain.

The relay's independent visual-loop review adds a stricter controller: no model
response replaces a champion directly; a challenger is promoted only through a
complete evidence bundle and the predeclared policy. Best-so-far preservation,
champion–challenger comparison, hard gates plus a metric vector, and selective
extra diagnostic work on disagreement protect against late-round regression.
Plateau, repeated rejection, oscillation, design-lock drift, or a third repair
route to `REPLAN`, not more polishing. Cycle 37 freezes the more conservative
maximum of **two** targeted repairs even though the external review explored
larger starting policies.

### 5. Product-specificity must resist both cloning and genericness false positives

Design fixation and AI-assisted convergence are credible risks [22,23], but
familiarity is not a defect: typicality and novelty can jointly influence appeal
[9]. Each brief therefore records 3–5 same-category references plus one
adjacent wildcard as *abstract patterns*, bans source assets/copy/marks and
distinctive composition, and requires three structurally different direction
cards before two candidates are built. Each direction needs a product signature
whose mechanism, brief trace, visible anchor, counterfactual, and task proof
are inspectable. A recolored dashboard is not divergence.

Across unrelated briefs, sidecars expose finite structural, system, surface, and
signature fields. Repeated combinations trigger human review; they do not prove
copying or low taste. The independent anti-pattern report supplied on the relay
requires four non-collapsed axes: `genericness_review`, `quality_risk`,
`context_fit`, and `provenance_integrity`. Common fonts, gradients, cards,
layouts, sparse pages, accessibility defects, or appearance similarity may be
review evidence, but never proof of AI authorship, copying, or a quality verdict.
Any genericness detector needs a future process-labelled, partitioned calibration
with coverage, precision, recall, false-positive, and subgroup-error reporting.

### 6. The evidence chain must be closed before a promotion claim

WebDriver, PNG, SHA-256, C2PA, WCAG, and adversarial-ML standards support a
bounded evidence-chain design: capture from a declared browser adapter; decode
rather than trust a file header; bind source/capture/ballot/aggregate digests;
treat page text and images as untrusted data; and make accessibility a veto
[24–29]. They do not prove a human created an interface or that an interface is
tasteful. The red team reproduced three present scaffolding false passes:
header-only PNG evidence, arbitrary reference bytes, and duplicated self-scored
ten-row arithmetic. The protocol turns each into a future negative regression;
no current script is declared a certificate.

## Exact merge and conflict resolution

| Lane | Exact adopted contribution | Integrator decision and reason |
|---|---|---|
| `hci-rubric` | Anchored multidimensional human rubric; task, accessibility, state, product-specificity, and evidence-integrity floors; population limits. | Adopted. Direct HCI work supports dimensions, but no composite hides a floor. |
| `human-corpus` | CC0 Web Design Prototypicality primary corpus; deterministic split/join/licence/duplicate rules; UICrit conditional audit. | Adopted. Human labels and an acquisition contract outrank convenient synthetic benchmarks. |
| `judge-science` | Pointwise before comparison, opaque identities, held-out calibration, side probes, isolation, Wilson aggregation, no model-to-human substitution. | Adopted with mirrored groups allocated across different judges; this better preserves isolation than asking one live judge twice. |
| `visual-feedback` | Immutable locks, actual browser captures, hard gate before voting, localized repairs, two-repair cap, fail-closed state machine. | Adopted. The canonical protocol adds best-so-far champion preservation from the relay. |
| `design-practice` | Brief/question, direction cards, rendered review packet, finite state/copy/interaction inventory, evidence-linked critique. | Adopted as lightweight receipts, not a recurring ceremony or a claim that a team's taste transfers to an agent. |
| `anti-homogenization` | 3–5 references plus wildcard, three structural directions, product-signature counterfactual, cross-brief sidecars and review triggers. | Adopted. Thresholds remain calibration-required review triggers, not an originality detector. |
| `threat-model` | Digest-bound evidence chain, declared adapters, blind-packaging, prompt-injection treatment, durable repair ledger, external boundaries. | Adopted. Host compromise, human identity, collusion, IP, and semantic fit remain external. |
| `red-team` | Header-only PNG, duplicate renders/briefs, caller-supplied lenses, stale state, calibration leakage, accessibility, claim-mismatch, and false-positive regressions. | Adopted as the next-cycle abuse suite. `genericness` and provenance remain separate so common motifs cannot fail by appearance alone. |

## Contrary evidence and falsifiers

| Proposed shortcut | Contrary evidence / falsifier | Required interpretation |
|---|---|---|
| “Beautiful means usable.” | Before/after-use and controlled studies distinguish preference, perceived usability, and task outcomes [7,8]. | Require task/browser evidence and WCAG veto independently. |
| “A familiar UI is best.” | Typicality and novelty can both support appeal [9]. | Preserve category grammar but require product-specific signature and divergent directions. |
| “A single visual metric or self-critique is enough.” | UI-generation work reports noisy absolute evaluation and benchmark-specific results [19–21]. | Use hard gates, capture evidence, metric vector, and blinded human comparison. |
| “More repair rounds improve quality.” | Iterative work can plateau, regress, forget constraints, or reward the latest attempt. | Preserve incumbent; two repairs maximum; then replan. |
| “Five votes prove broad preference.” | Five is a scope floor and votes may be correlated. | Require isolation, calibration, mirrors, Wilson reporting, population limits, and no universal claim. |
| “A detector can identify AI-made/copying UI.” | Appearance-only provenance is unsupported; familiar motifs create false positives. | Output separate review/provenance axes; route suspected copying to qualified human/IP review. |
| “A passing fixture proves rendering.” | Red-team reproductions passed header-only PNGs and arbitrary bytes. | Require declared real-browser capture, image decode, hashes, traces, and negative tests. |

## Limits and external evidence

This document's synthesis (§§Evidence synthesis) recruited no humans, ran no
model panel, and issued no certificate. Cycles 40–41 change only the acquisition
and adapter boundary: the primary-corpus browser-acquisition path is validated
(WAF-challenge Chrome session, dataset id `6830013` v`4.0`, byte-exact canary; see
the Cycle 40–41 live-boundary update), the fail-closed validator/compiler chain
and the Cycle-40 browser/decoder/a11y/judge/ballot adapters are merged in this
tree, and the Cycle-41 acquisition-campaign design is frozen in sibling lanes.
No real 180+72 corpus has been acquired — corpus acquisition remains
`EXTERNAL-EVIDENCE-OPEN` — and no recruited human panel supplied deciding
ballots, so `HUMAN_CERTIFIED` cannot be claimed. These remain explicitly
external or `UNKNOWN`: **host integrity**, **panel identity/independence/
collusion**, **population coverage**, **IP/trade-dress** non-infringement,
**manual accessibility** (assistive-technology experience), and **actual human
certification**. Dataset licences bind only the primary CC0 releases and the
separately pinned TASTE repository. A result with any one missing item must
receive the lower honest label or `NOT-CERTIFIED`.

## Stable bibliography

1. Lavie & Tractinsky (2004), *Assessing dimensions of perceived visual aesthetics of web sites*. https://doi.org/10.1016/j.ijhcs.2003.09.002
2. Moshagen & Thielsch (2010), *Facets of visual aesthetics*. https://doi.org/10.1016/j.ijhcs.2010.05.006
3. Moshagen & Thielsch (2013), *A short version of VisAWI*. https://doi.org/10.1080/0144929X.2012.694910
4. Lindgaard et al. (2006), *You have 50 milliseconds to make a good first impression*. https://doi.org/10.1080/01449290500330448
5. Miniukovich et al. (2020), *Keep it Simple*. https://doi.org/10.1145/3313831.3376849
6. Reinecke & Gajos (2014), *Quantifying Visual Preferences Around the World*. https://doi.org/10.1145/2556288.2557052
7. Lee & Koubek (2010), *Understanding user preferences before and after actual use*. https://doi.org/10.1016/j.intcom.2010.05.002
8. Sauer et al. (2012), *Is beautiful really usable?* https://doi.org/10.1016/j.chb.2012.03.024
9. Miniukovich & Figl (2023), *The Effect of Prototypicality on Webpage Aesthetics, Usability, and Trustworthiness*. https://doi.org/10.1016/j.ijhcs.2023.103103
10. Miniukovich & Figl (2024), *Dataset of user evaluations of homepages*. https://doi.org/10.1016/j.dib.2023.109976
11. Harvard Dataverse, *Web Design Prototypicality Data*. https://doi.org/10.7910/DVN/Z7KLIH ; https://doi.org/10.7910/DVN/9FKSQI ; https://doi.org/10.7910/DVN/XOI0HI
12. Duan et al. (2024), *UICrit*. https://github.com/google-research-datasets/uicrit
13. Wu et al. (2024), *UIClip*. https://doi.org/10.1145/3654777.3676408
14. Sengupta et al. (2021), *Simple Surveys*. https://doi.org/10.1177/0894439319848374
15. Thurstone (1927), *A Law of Comparative Judgment*. https://doi.org/10.1037/h0070288
16. Shi et al. (2025), *Position Bias in LLM-as-a-Judge*. https://aclanthology.org/2025.ijcnlp-long.18/
17. Jeong et al. (2025), *The Comparative Trap*. https://aclanthology.org/2025.blackboxnlp-1.5/
18. Nakamura et al. (2021), *Effects of Redacting Grant Applicant Identifiers*. https://doi.org/10.7554/eLife.71368
19. Wan et al. (2025), *DCGen*. https://arxiv.org/abs/2406.16386
20. Yang et al. (2026), *UI2Code^N*. https://arxiv.org/abs/2511.08195
21. Yue et al. (2025), *UIOrchestra*. https://aclanthology.org/2025.findings-emnlp.150/
22. Jansson & Smith (1991), *Design fixation*. https://doi.org/10.1016/0142-694X%2891%2990003-F
23. Wadinambiarachchi et al. (2024), *AI image generators and design fixation*. https://arxiv.org/abs/2403.11164
24. W3C, *WebDriver: Take Screenshot*. https://www.w3.org/TR/webdriver2/#take-screenshot
25. W3C, *PNG Specification (Third Edition)*. https://www.w3.org/TR/png-3/
26. NIST, *FIPS 180-4 Secure Hash Standard*. https://csrc.nist.gov/pubs/fips/180-4/upd1/final
27. C2PA, *Content Credentials Technical Specification 2.2*. https://spec.c2pa.org/specifications/specifications/2.2/specs/C2PA_Specification.html
28. NIST, *Adversarial Machine Learning, AI 100-2*. https://csrc.nist.gov/pubs/ai/100/2/e2023/final
29. W3C, *Web Content Accessibility Guidelines 2.2*. https://www.w3.org/TR/WCAG22/
30. Harvard Dataverse, *Native API Guide (v6.8)*. https://guides.dataverse.org/en/6.8/api/native-api.html
31. Harvard Dataverse, *Data Access API (v4.9.4)*. https://guides.dataverse.org/en/4.9.4/api/dataaccess.html
32. DataONE, *Identifiers in DataONE (PID immutability)*. https://dataone-architecture-documentation.readthedocs.io/en/latest/design/PIDs.html
33. DataONE, *PIRI resolution service*. https://dataoneorg.github.io/api-documentation/services/piri_service.html
34. Miniukovich & Figl (2024), PMC open-access record of [10]. https://pmc.ncbi.nlm.nih.gov/articles/PMC10823051/

## Skill receipts

Cycle 40 lane `protocol-live` selected kit (read once, in listed order):

SKILL-READ: deep-research | /Users/leonardo/.agents/skills/deep-research/SKILL.md | 3883242303-4343

SKILL-READ: engineering:documentation | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/documentation/SKILL.md | 177552282-1507

SKILL-READ: legal:compliance-check | /Users/leonardo/.codex/plugins/cache/claude-cowork/legal/1.3.0/skills/compliance-check/SKILL.md | 1175060322-14694
