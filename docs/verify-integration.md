# Verify — taste-calibration-integrator (c41-source-calibration-20260812-a1)

Target: `m32.4` — acquire the real human-rated corpus and calibrate the
independent judge swarm. This document is the only verdict destination for
this run; `docs/status-taste-calibration-integrator.md` is status-only.

## 1. Merges and ancestry

All fifteen Cycle-41 lane tips merged into `lane/c41-taste-calibration-integrator`
with `git merge --no-ff`, zero conflicts; every tip proven with
`git merge-base --is-ancestor` (all fifteen ANCESTOR-OK):

| Lane | Tip |
|---|---|
| dataverse-transport | `942f75019bef` |
| dataone-metadata | `3a2cb8ab0a63` |
| source-freeze | `0ceea9b78c5a` |
| download-campaign | `90111d4cbc02` |
| cache-integrity | `46b82dc40f89` |
| ratings-normalize | `5f6ebe777457` |
| corpus-select | `d0905f7f8776` |
| pair-builder | `164bb0f3f2f3` |
| calibration-campaign | `7548fdbdb19f` |
| calibration-audit | `f81c2226de2b` |
| panel-freeze | `11edf4164c44` |
| benchmark-preflight | `7ab89fbba908` |
| source-adversary | `7a407ac49645` |
| source-runbook | `26a37402e871` |
| source-protocol | `bfe945d07b1f` |

Every lane `docs/verify-*.md` was inspected; the source-adversary catalog of
twelve integrator seams drove the repair plan.

## 2. Seam repairs (all twelve adversarial seams closed)

`tests/test-taste-source-adversarial.sh` and
`tests/test-taste-source-campaign-e2e.sh` now pass integrator mode
(`POLYLANE_ADVERSARY_REQUIRE_SEAMS_CLOSED=1`) with `seams=0`
(70 and 29 assertions; previously 50/19 with 7+5 seams). Wired against the
merged sibling interfaces: dataone-metadata-crosscheck and distribution-drift
(source-freeze compile refuses DOI/licence/version/size/missing/extra/
challenge-HTML disagreement), download-resume-ledger (campaign selftest),
benchmark-preflight-gate (fail-closed NOT-READY probe), pair-manifest-freeze
(deterministic byte-identical rebuild + verify), corpus-select-unbalanced-quota
(production 60/24 selector accepts the unbalanced split its cycle-40
predecessor rejected), dataverse-transport-rehearsal (adapter selftest),
ratings-normalize-schema (real released schema round-trip + drift rejection),
calibration-audit-recompute (independent recompute over the completed
rehearsal campaign, Wilson agreement to 1e-4), panel-freeze-claim-ceiling
(frozen panel invariants). Two required production repairs, test-first:

- `bin/polylane-taste-calibration-campaign.sh` — duplicate raw-response
  digests across sealed ballots refused at seal time and in `verify-ledger`
  (session-uniqueness seam).
- `bin/polylane-taste-cache.sh` — new `verify-content` subcommand: image
  magic bytes + minimum plausible size on top of digest checks
  (image-content-verification seam).

## 3. Steered integration repairs (all test-first, all green)

- **NUL hygiene**: raw NUL bytes inside jq programs (bash silently strips
  them from words) escaped as backslash-u0000 in
  `bin/polylane-taste-calibration-campaign.sh` (1) and
  `bin/polylane-taste-a11y-live.sh` (9); no-NUL regressions added; tracked
  `*.sh` scan clean.
- **`bin/polylane-taste-ratings.sh`** (focused test 70 → 121 assertions):
  - Source-exact pipeline reproduction: training ratings enter each compliant
    session's dup-averaged sample-SD standardization basis (discovered by
    live replay, independently confirmed); byte-identical repeated raw and
    aggregate rows collapse losslessly while distinct repeats stay terminal.
  - Strict `sessions` subcommand: demographics susCheat=FALSE
    (case-insensitive, header-bound incl. the raw sessionId column) →
    compliant-session list with SHA-receipt; duplicate/malformed/missing
    columns and empty joins terminal.
  - Source-fidelity verification decoupled from eligibility: every finite
    published cell verified — finite siblings of NA rows and training-only
    stimuli included — before any exclusion; counters
    expected/verified/unverified/mismatched + max_abs_error in output and
    receipt; any mismatch or coverage gap is a non-success exit.
  - Per-stimulus standardized AE samples (`--samples AE`), explicit
    `label_dimension`/`label_support`, and a label-dimension-scoped support
    floor (unchanged value 5) so pair/selection contracts consume real
    sample arrays.

## 4. Verification totals (final tree)

- Frozen focused matrix: 17/17 PASS (test-by-test receipts in §2/§3; totals:
  transport 31, dataone 19, freeze 54, download 63, cache 57, ratings 121,
  corpus-select 29, pairs 46, campaign 48, audit 21, panel PASS,
  preflight 34, adversarial 70 seams=0, campaign-e2e 29 seams=0,
  source-live 40, calibration-live 22, live-harness-e2e PASS).
- Full suite `tests/run.sh`: 4005 passed, 0 failed, 166 test files (completed
  run after the seam-closure commit); every test file changed after that run
  was rerun green individually on the final tree (ratings 121, campaign 48,
  a11y-live 47, adversarial 70, campaign-e2e 29, cache 57); a confirming
  full-suite rerun on the final tree was still executing at handoff.
- `shellcheck -S warning bin/*.sh codex/install.sh claude-code/install.sh`: clean.
- `bin/polylane-markers.sh check-docs references/`: OK.
- `tests/test-skill-parity.sh`: 72 pass, 0 fail.
- `bin/polylane-seams.sh scan .`: no findings.
- `git diff --check`: clean.

## 5. Real external evidence (classification: live, public, CC0; no fixtures)

Cache root `~/Library/Caches/polylane/taste-primary-v1`: 23 content-addressed
objects, 23 MB; binaries never enter Git.

- **Harvard Dataverse (live, ephemeral WAF-cleared Chrome)**: all three
  frozen dataset envelopes acquired and re-fetch-stable — e-commerce
  `17ef0759…` (v4.0, 1074 files), universities `14a57bc1…` (v4.0, 1066),
  banks `c608ee19…` (v4.0, 1040); all CC0 1.0. All twelve
  ratings/aggregate/demographics files acquired with content hashes
  (full table: `docs/polylane/taste-certification/benchmark/source/PROVENANCE-NOTES.md`).
- **DataONE (live, cn.dataone.org)**: immutable-PID receipts for all three
  domains, `mode:"live"`, `urn:node:HD`, digests equal to the frozen PIDs,
  distribution counts 1074/1066/1040 matching Harvard exactly.
- **Source reproduction**: every finite published aggregate cell verified —
  fashion 3315/3315, homeware 3063/3063, universities 6354/6354, banks
  6196/6196; mismatches 0; max abs error 0.000000/0.000000/0.000000/0.004141
  (banks residuals ≤ 0.004141 recorded as a publisher basis quirk). Eligible
  AE-labeled records: e-commerce 262+443=705, universities 340, banks 510 —
  all three domains exceed the 84-per-domain quota pool.
- **Image corpus**: 8 image objects fetched live before the WAF throttled
  the burst (receipts preserved); the 3159-image sweep was deliberately
  stopped per steering in favour of a selected-only 252 acquisition that is
  not yet implemented (§6). Source counts: 0 of 252 selected images
  finalized; split/pairs not sealed; no judge output exists, so nothing was
  tuned on holdout and no item was replaced after results.

## 6. Confirmed open engineering gaps (catalogued, not hidden)

Independent red-team and schema audits during this run confirmed the
following producer/consumer breaks that block the remaining campaign; none
is reachable by the frozen test suite today, and closing them is the next
cycle's work:

1. Two-stage selected-only acquisition contract (inventory receipt bound to
   DOI/version/metadata-SHA/file-id/name/size/MD5 → deterministic
   preselection ranked by `seed|domain|file-id/name` → download only the 252
   → finalize with observed SHA-256 → re-deriving verify): not yet built;
   the shipped corpus-select ranks by `sha256(seed|id|image-sha)` which
   structurally demands all 3159 images first.
2. Transport: per-source persistent/batch browser session with consecutive-
   failure circuit breaker, 429/Retry-After classification, plan-bound
   resume keys, browser-instance receipts (current shim launches one
   ephemeral Chrome per fetch; observed 8 fast OKs then a throttle streak;
   the "text/plain renders inline" hypothesis was refuted — 11/11 text
   files fetched, failures were a transient global WAF window).
3. Judge chain: runner appends REQUEST_JSON to `adapter.command` but the
   frozen panel's `polylane-taste-judge-{claude,codex}` CLIs implement a
   different invocation surface; work-unit/request v1 carries hashes without
   brief/rubric content; response schema hardcodes a smoke work-unit id;
   calibration-live/audit pin a `FINAL:` line parser while the runner
   produces strict JSON choices. A per-slot provider bridge, request v2 with
   canonical brief/rubric binding, and one canonical parser fingerprint are
   required before any 24-pair run; a lossy FINAL translation was refused.
4. Ledger→calibration-input, pairs→work-unit, selection→download-plan,
   selection+samples→pair-input, normalized→selector-ratings compilers do
   not exist; preflight trusts individual eligibility receipts instead of
   the audit closure and expects a `taste-source-acquisition/v1` receipt no
   v2 chain emits; calibration-live can classify local files as production
   without a verified campaign-ledger/native-invocation closure.
5. Claim hardening: certificate paths must never mint HUMAN_CERTIFIED from
   relabeled machine receipts; `human_certified` remained false in every
   receipt this run produced and no GO/certification claim is made.
6. 20-brief study blockers recorded for the generation cycle: ui-contract
   encoding drift across five components, a dispatched-but-missing
   `polylane-visual-quality.sh authoritative` subcommand, and candidate-
   policy conflicts (3-direction doctrine vs 2-direction protocol vs
   baseline+3 generator), plus tournament-vs-absolute-floor gaps.
7. Minor routed defects: samples serialized at 6 decimals; isDuplicate
   FALSE/FALSE-TRUE/TRUE pair semantics not yet validated; normalize does
   not consume the sessions receipt.

## 7. Judge eligibility

No judge configuration was executed this run (chain gaps in §6.3–6.4);
eligible machine judge configurations: 0 of the required 5. The frozen
thresholds (24 pairs, ≥17 correct, Wilson LCB ≥ 0.50, side p ≥ 0.05, <2
mirror contradictions, 5-config panel floor) were not altered; no judge was
tuned on holdout; no item was replaced after results (no results exist).

## 8. Limitations

- The 252-image selected corpus, sealed split/pairs, provider calibration,
  independent audit, and benchmark preflight remain unexecuted; every gate
  needed for `HUMAN_CALIBRATED_MACHINE`/`human_calibrated:true` is therefore
  unmet this run and no such claim is made. `human_certified` is false
  everywhere. The full 20-brief taste certificate is not minted.
- Committed normalized evidence reflects the AE label dimension only; any
  future machine-judge claim is scoped to human-calibrated visual-aesthetic
  preference.
- The detached image campaign was stopped after eight objects; its receipts
  and all cache objects were preserved (resume-safe).

## 9. Next route

Build, in order: the two-stage selected-only source contract (§6.1) with its
adversarial matrix; the per-source session transport with circuit breaker
(§6.2); the judge bridge + request/parser unification (§6.3) with a
runner→bridge→native contract test and a two-unit live smoke; the missing
chain compilers plus one hermetic end-to-end whose only handwritten inputs
are external-boundary fixtures and whose result is FIXTURE-READY, never
production (§6.4); then rerun the real network path: fetch the 252, seal
split/pairs, run the declared panel through the bridges, audit, preflight.

## 10. Skill receipts

- SKILL-READ: engineering:debug | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/debug/SKILL.md | 303222582-4074
- SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
- SKILL-READ: operations:risk-assessment | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md | 3889652016-1630
- SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/test-driven-development/SKILL.md | 1657109997-9015
- SKILL-EVIDENCE: superpowers:test-driven-development — helped: every repair
  (seam wiring, NUL regressions, dup-collapse, training-basis, fidelity
  counters, sessions helper, header binding) was written as a failing test
  first and watched fail — the RED runs caught two real defects (unset
  `sup[]` emitting invalid JSON; the hardcoded aggregate-check claim) before
  they could ship.
- SKILL-EVIDENCE: engineering:testing-strategy — helped: kept the cadence
  merge → focused failures → frozen matrix → full suite, and scoped the
  bounded fixes to hermetic tests while classifying the live campaign as a
  separate evidence layer.
- SKILL-EVIDENCE: engineering:debug — helped: the reproduce→isolate cadence
  refuted the text/plain-inline transport hypothesis with receipts and
  isolated the WAF throttle window, and located the exact standardization
  variant (training-in-basis) by hypothesis-testing four pipelines against
  published values.
- SKILL-EVIDENCE: operations:risk-assessment — helped: ranked the seam
  catalog by certification-honesty impact (mirror substitution and claim
  escalation first), and drove the decision to refuse a lossy FINAL-line
  translation rather than force a panel this run.

POLYLANE-VERDICT: EXTERNAL-EVIDENCE-OPEN run=c41-source-calibration-20260812-a1
