# Verify — receipt-producers (Cycle 39, run c39-visual-loop-20260812-a1)

Lane goal: close the validator receipt chain so real pixel, corpus, calibration,
ballot, statistics, and threat executions emit hash-bound production evidence a
certificate compiler can trust. Every input JSON and adapter result is treated
as hostile evidence; every production-eligible validator writes one atomic,
versioned receipt whose status/classification are validator-derived, never
caller-supplied.

## SKILL-READ

- SKILL-READ: data:validate-data | /Users/leonardo/.codex/plugins/cache/claude-cowork/data/1.1.0/skills/validate-data/SKILL.md | 1311249913-14916
- SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
- SKILL-READ: operations:risk-assessment | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md | 3889652016-1630
- SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md | 1657109997-9015

## Exact command outputs

Focused suites + cross-validator suite (all green):

```
test-taste-pixels: test-taste-pixels.sh: 36 pass, 0 fail
test-taste-ballot: test-taste-ballot.sh: 26 pass, 0 fail
test-taste-corpus: PASS test-taste-corpus assertions=32
test-taste-calibrate: PASS: test-taste-calibrate
test-taste-stats: PASS: taste stats
test-taste-threat: test-taste-threat.sh: 23 pass, 0 fail
test-taste-validator-receipts: test-taste-validator-receipts.sh: 38 pass, 0 fail
```

`shellcheck -S warning` on all six owned helpers:

```
clean: 0 findings
```
(`bin/polylane-taste-{pixels,ballot,corpus,calibrate,stats,threat}.sh`)

`git diff --check`:

```
clean
```

Collateral (not owned, run read-only to confirm backward compatibility): the
optional receipt argument is additive, so `tests/test-taste-visual-capture.sh`
(uses the 3-arg pixels form → 19 pass) and `tests/test-taste-certification.sh`
(hand-writes fixture receipts, does not invoke the producers → pass) are
unaffected.

## Receipt schema map

Every receipt exposes the common envelope `{status, classification,
input_sha256, validator{id,fingerprint}, reason_codes}`; `classification` is
validator-derived (always `fixture` this hermetic cycle — production is
unreachable without external attestation forbidden by EXTERNAL-EVIDENCE);
`validator.fingerprint` is the SHA-256 of the helper script itself.

| Validator | Receipt schema | Emitted by | Primary input → `input_sha256` | Subject / chain bindings | Output counts |
|---|---|---|---|---|---|
| pixels | `taste-pixels-receipt/v1` | `verify … [receipt-out]` (new optional 4th arg) | SHA-256 of capture manifest file | `subject.project_head`=git HEAD, `candidate_source_revision`, `candidate_id`; `inputs.{browser_adapter_receipt_sha256, browser_command_sha256, decoder_command_sha256, source_revision_sha256}`; `freshness_window`; per-capture PNG + decoded-pixel hashes; sorted route/state/viewport `matrix` | `output.{capture_count, distinct_screenshot_hashes, distinct_decoded_hashes}` |
| corpus | `taste-corpus-receipt/v1` | `receipt MANIFEST split count seed OUT` (new subcommand) | SHA-256 of corpus manifest file | `provenance.sources[]` (spdx + license/source hashes), `separation.{per_domain,balanced}`, `human_labels`, deterministic `sample.{ids, asset_sha256, sample_sha256}` | `output.{record_count, source_count}` |
| calibrate | `taste-calibration/v1` (enriched) | `INPUT OUT` | SHA-256 of calibration input file | `corpus_holdout_receipt_sha256`; `judge_configuration.{provider,model,model_version,system_prompt_sha256,sampling_sha256,kind}`; `accuracy`, `wilson_lcb_95`, side/mirror probes | `human_labelled_pairs` = exact unique unit count (≥24, not hardcoded 24) |
| stats | `polylane.taste.stats.v1` (field `schema`) | `aggregate [OUT] < ballots` | SHA-256 of **canonical** (`jq -cS`) ballots JSON | tie/abstention-aware `sample_units` (abstentions leave denominator), `per_brief`, `eligible_judge_count` (union, never pooled as samples) | `brief_count`, `candidate_wins`, `baseline_wins`, `ties`, `preference_rate`, `wilson_lower_bound` |
| ballot | `taste-ballot-validation/v1` (enriched, fixture-only) | `validate GROUP PW_DIR CAL OUT` | SHA-256 of mirrored-group file (`= group_sha256`) | `inputs.{calibration_sha256, candidate_ids_escrow_sha256, capture_manifest_sha256, pointwise_sha256{…}}`; `judges[]`; `brief_sha256`, `winner`; `fixture_only:true`, `human_certified:false` | pointwise-count via `inputs.pointwise_sha256` |
| threat | `taste-threat-receipt/v1` (enriched) | `check MANIFEST OUT` | SHA-256 of threat manifest file | `subject.source_root`; `inputs.{threat_manifest_sha256, capture_sha256[], receipt_payload_sha256[]}` (inspected artifacts); four independent axes; `review` | axis_results + `reason_codes` |

Input-hash semantics: **stats binds the canonical JSON** (`jq -cS`), every other
producer binds the raw input file bytes. The cross-validator closer recomputes
per producer (`tests/test-taste-validator-receipts.sh:recompute_input`).

## Attack / tamper matrix

Each row is fail-closed; the suite name is where it is proven.

| Attack | Validator(s) | Defense | Result |
|---|---|---|---|
| Forged shape-compatible receipt, wrong `input_sha256` | all (cross) | closer recomputes SHA-256 from the real artifact | REJECT (`forged-input-hash-rejected`, `chain-rejects-forged-member`) |
| Fixture receipt relabeled `classification:"production"` | all (cross) | production requires verified `production_bindings` (absent) | REJECT (`fixture-to-production-relabel-rejected`) |
| Forged `validator.fingerprint` (claims a trusted tool) | all (cross) | fingerprint must equal SHA-256 of the named helper | REJECT (`forged-validator-fingerprint-rejected`) |
| Cross-run receipt bound to another run's input | all (cross) | recompute against the actual artifact mismatches | REJECT (`cross-run-receipt-rejected`) |
| Hand-built receipt, right schema string, no real binding | corpus (cross) | recompute mismatch on the real manifest | REJECT (`hand-forged-shape-only-receipt-rejected`) |
| Duplicate JSON keys in a receipt | calibrate (cross) | `jq --stream` duplicate-path scan | REJECT (`duplicate-key-receipt-rejected`) |
| Header-only / truncated PNG, symlink, traversal, wrong viewport, stale capture, duplicate render, synthetic placeholder, missing decoder adapter | pixels | structural PNG parse, safe-relative-file, freshness window, decoded-pixel uniqueness, decoder receipt binding | REJECT (`test-taste-pixels.sh`) |
| Unknown/duplicate manifest key, unbalanced split, duplicate asset, ambiguous license, trust boolean | corpus | strict key sets + duplicate-key scan + balance/uniqueness/licence checks; no partial receipt on failure | REJECT (`test-taste-corpus.sh`) |
| Self-attested judge eligibility, identity drift, invalid abstention, side-bias, mirror instability, leakage, duplicate units, missing corpus/holdout binding, missing model-version/prompt/sampling hash | calibrate | schema + probe recomputation; corpus-receipt + full judge-config bindings required | REJECT (`test-taste-calibrate.sh`) |
| All-abstain (empty denominator), unknown per-ballot key, empty judge id, duplicate brief, pooled ratings | stats | non-abstain `sample_units>0`, key-subset, brief-dedup, judge union not pooled | REJECT / correct (`test-taste-stats.sh`) |
| Order contradiction, same-judge mirror, identity leak, prompt injection, incomplete pointwise scale, uncalibrated abstention | ballot | mirrored A/B+B/A + isolation + pointwise-before-pairwise timestamp checks | REJECT (`test-taste-ballot.sh`) |
| Visible prompt injection, provider/model leakage, receipt-hash tampering, duplicate pixels, cross-brief sameness, accessibility hard-veto | threat | independent axes; injection/leakage/tamper scans; sameness → blinded review, never authorship claim | REJECT / route-to-review (`test-taste-threat.sh`) |
| Backward compatibility: 3-arg pixels prints, no receipt; existing corpus/calibrate/stats/ballot CLIs unchanged | all | optional receipt outputs, additive fields | PASS |

## Clock-fix evidence

Root cause (pixels): the freshness gate `image_mtime <= now_epoch + 5` used a
wall-clock `NOW` frozen once near test start. Under load the Python `make_png`
subprocesses that re-create PNGs mid-test stamped later mtimes; once real time
advanced past `now_epoch + 5`, `STALE_CAPTURE` fired first and **masked** the
`DUPLICATE_RENDER` / `VIEWPORT_MISMATCH` cases the test intended. Baseline was
flaky: `test-taste-pixels.sh: 8 pass, 2 fail` on those two rows.

Fix (test-only, `tests/test-taste-pixels.sh`): pin `NOW = commit_epoch + 3600`
(one hour past the git commit that bounds `source_epoch`), so the window
`[source_epoch, now_epoch+5]` always brackets every fixture mtime regardless of
how slowly negative cases run; `captured_at`/`TASTE_NOW` derive from the same
fixed clock. Verified stable: `10 pass, 0 fail` across 3 consecutive runs, then
`36 pass, 0 fail` with the receipt assertions added. The helper's freshness
logic is unchanged (it legitimately rejects stale/future captures); only the
test clock was pinned, exactly as the contract requires.

## Cross-validator chain proof

`tests/test-taste-validator-receipts.sh` produces one real receipt from each of
the six validators over hermetic fixtures, then asserts (38 assertions):

1. Every real receipt exposes a deterministic `input_sha256` (recomputed and
   equal), a non-empty `status`, `classification == "fixture"`, and a
   `validator.fingerprint` equal to the SHA-256 of its helper.
2. The full producer chain closes (`close_chain`).
3. Seven forgery vectors (above) each fail to close the chain — a
   shape-compatible receipt whose content-addressed bindings do not recompute
   is rejected, and swapping one forged member breaks whole-chain closure.

## SKILL-EVIDENCE

- SKILL-EVIDENCE: superpowers:test-driven-development — helped: drove strict red/green per validator; watching the new receipt assertions fail first (pixels 22, ballot 11, threat 9 red rows) surfaced a real fixture-state bug — the solid-placeholder case left `default-desktop.png` synthetic on disk, which the follow-on compat verify caught as `SYNTHETIC_PLACEHOLDER` before I implemented the receipt, exactly the "watch it fail for the right reason" payoff.
- SKILL-EVIDENCE: engineering:testing-strategy — helped: shaped the coverage pyramid — six focused unit suites (each extended with tamper + backward-compat cases) under one cross-validator contract/integration test for chain closure and forgery; "test data integrity and security boundaries, skip framework code" kept the suites on hostile-evidence paths rather than on jq plumbing.
- SKILL-EVIDENCE: data:validate-data — helped: its denominator-correctness, "never average pre-aggregated averages", and deduplication pitfalls translated directly into the stats abstention-aware denominator (`sample_units` = non-abstain briefs), the "one brief = one sample unit, judges never pooled" rule, and the reproducibility/freshness lens that framed the pixels clock fix.
- SKILL-EVIDENCE: operations:risk-assessment — helped: its likelihood/impact framing produced the attack matrix and the fail-closed disposition for each high-impact vector (forged/relabeled/cross-run receipt, forged tool identity, stale clock), each mapped to a controllable mitigation (content-addressed hash binding recomputed by the consumer); it also justified escalating the receipt-shape negotiation with certificate-v2 to the relay rather than silently capitulating.

## DEFERRED

DEFERRED: compiler receipt-schema convergence with certificate-v2. Its seq-6
relay declares **closed** minimal key-sets and a production ballot
(`taste-ballot-validation/v2`, `fixture_only:false`). My hard contract mandates
the full hash-bound envelope on every receipt (superset of every field it
lists), and EXTERNAL-EVIDENCE forbids emitting a production/`fixture_only:false`
ballot this cycle. I posted a counter-proposal to certificate-v2 via the relay:
(1) validate producer receipts by required-field + hash-binding (subset) checks,
not closed-key equality; (2) exact field paths for each listed field are already
present; (3) `input_sha256` for stats binds canonical JSON, others bind the raw
file; (4) ballot stays fixture-only in c39 (protocol local label
`SELECTED_NOT_CERTIFIED`); (5) on confirmation of subset validation I will align
schema-identifier strings (pixel-singular, add `schema_version` to stats, bump
threat to v2) to avoid double churn. This seam is owned jointly with
certificate-v2 and the integrator; the producer side is complete and proven by
`tests/test-taste-validator-receipts.sh`. No producer work remains.
