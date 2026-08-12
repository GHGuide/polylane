# Verify — calibration-live (production judge-eligibility receipt v2)

Run: `c40-live-harness-20260812-a3` · Lane: `calibration-live`

Subject under verification:

- `bin/polylane-taste-calibration-live.sh` — validator/compiler for
  `taste-calibration/v2` (receipt `polylane.taste.judge-eligibility.v2`).
- `tests/test-taste-calibration-live.sh` — 22 red-first assertions (positive +
  full reject matrix).

The validator never runs a model. All LLM invocation happens upstream; this
script content-addresses already-captured evidence and recomputes every claim.

---

## 1. Claim semantics — machine, not human

Eligibility asserts exactly one thing: **a machine judge, under a frozen
configuration, reproduced human-authored held-out labels well enough to clear
the preregistered floors.** It is never a human ballot.

The receipt hard-codes this and cannot be talked out of it:

| Field | Value | Meaning |
|---|---|---|
| `machine_panel_claim` | `HUMAN_CALIBRATED_MACHINE` | the only claim the receipt makes |
| `human_certified` | `false` (constant) | never a human certification |
| `machine_not_human` | `true` (constant) | a machine matched human labels; it did not vote |
| `claim_semantics` | fixed sentence | spelled out in prose inside the receipt |

Any input that tries to self-declare eligibility (`judge.eligible`,
`judge.eligibility`, `judge.result`, …) is `SCHEMA_REJECTED` — the closed schema
forbids those keys, so a caller can never smuggle a verdict past recompute.

`classification`/`production` are **derived**, never trusted:

- `production` ⇔ eligible **and** every image + both raw responses of every unit
  resolve to hash-matched regular files under the artifact root.
- Anything using inline responses or image-by-digest stays `fixture_only`;
  fixtures exercise logic but can never be represented as a production,
  human-calibrated machine ballot (`EXTERNAL-EVIDENCE` boundary).
- A record that *declares* a file binding (a `path`) but cannot produce the
  matching bytes is a shape-compatible synthetic receipt → `SYNTHETIC_RECEIPT`,
  rejected. No success receipt is emitted after any failed link (`fail_closed`
  and code aggregation both short-circuit to `eligible:false`).

---

## 2. Exact formulas (recomputed, never read from input)

Let `n = units`, `c = correct`, and `s = scored` (units where both sides parsed
to a non-abstain verdict).

**Accuracy** `= c / n`.

**Gold** for a unit is `labels[unit_id].correct_stimulus` from the bound,
hash-verified holdout labels file — never a field on the unit.

**Vote** for a side is re-parsed from the hash-verified raw response with the
pinned parser (`response-parser/v1`): the token of the LAST line matching
`^FINAL: (FIRST|SECOND|ABSTAIN)$`; `FIRST→1`, `SECOND→2`, `ABSTAIN→0`, no
match → unparseable. Chosen stimulus = `orientation[pos-1]`; a unit is
**correct** only if both primary and mirror chose the gold stimulus *and* the
unit carries zero structural reject codes.

**Wilson 95% lower confidence bound** (`z = 1.959963984540054`, `p = c/n`):

```
        p + z²/(2n) − z·√( (p(1−p) + z²/(4n)) / n )
LCB =  ─────────────────────────────────────────────
                     1 + z²/n
```

**Side probe — two-sided exact binomial** against H₀ `p = 0.5`. Let `L` = number
of scored units whose *primary* parsed to position 1 (left/FIRST),
`k = min(L, s−L)`:

```
p = min(1, 2 · Σ_{i=0}^{k} C(s,i) / 2ˢ)
```

`C(s,i)` is built incrementally (`C·(s−j+1)/j`) to stay exact in awk. A judge
that always answers the same side drives `p→0`.

**Mirror contradictions** = number of scored units where the primary-chosen
stimulus ≠ the mirror-chosen stimulus. A stable judge picks the same stimulus
regardless of left/right presentation, so contradictions ≈ 0.

`side_probe_n = mirror_probe_n = s` (abstained/unparseable units are excluded
from both probes but remain in the accuracy denominator `n`).

---

## 3. Threshold gate (HARD CONTRACT)

Eligible ⇔ **zero** structural codes **and** all of:

| Gate | Requirement | Code on breach |
|---|---|---|
| Held-out size | `n ≥ 24` unique mirrored units | `ACCURACY_FLOOR` |
| Correct | `c ≥ 17` | `ACCURACY_FLOOR` |
| Wilson LCB | `LCB ≥ 0.50` | `WILSON_FLOOR` |
| Side probe count | `s ≥ 12` | `SIDE_BIAS` |
| Side probe p | exact two-sided `p ≥ 0.05` | `SIDE_BIAS` |
| Mirror probe count | `s ≥ 8` | `MIRROR_INSTABILITY` |
| Mirror contradictions | `< 2` | `MIRROR_INSTABILITY` |

Freeze block must pin, before any call: `provider`, `model`, `model_version`,
`system_prompt_sha256`, `sampling_sha256`, `source_snapshot_sha256`,
`invocation_adapter_sha256`, `response_parser_sha256`, and
`image_orientation_frozen:true`. `judge.*` identity must equal the freeze;
every unit's `invocation.*` must equal the freeze and the pinned parser sha.

---

## 4. Positive matrix

| Test | Asserts |
|---|---|
| `test_fixture_inline_eligible` | 24 units / 17 correct inline → eligible; `classification=fixture_only`, `production=false`, `fixture_only=true`; `human_certified=false`, `machine_not_human=true`, `machine_panel_claim=HUMAN_CALIBRATED_MACHINE`; counts 24/17; probes pass; Wilson ≥ 0.50; accuracy 17/24 ∈ (0.70,0.71); parser/source/judge/validator-fingerprint/input-sha all bound |
| `test_more_than_24_units` | 26/26 → eligible with **exact** 26 units / 26 correct (counts are recomputed, not a constant 24) |
| `test_production_file_backed` | same case with file-backed images+responses → `classification=production`, `production=true`, `fixture_only=false`, `bound_response_units=true` |
| `test_paired_abstention_allowed` | one unit abstains on **both** sides with `abstain_reason` on both → still eligible; `side_probe_n=23` (abstained unit excluded from probes, kept in denominator) |

---

## 5. Negative matrix (reject class → trigger → code)

Every reject class in the lane contract has a red-first case. `assert_rejected`
requires non-zero exit, `eligible:false`, and the expected code present.

| Contract reject | Test | Trigger | Code |
|---|---|---|---|
| accuracy floor | `test_reject_accuracy_floor` | 16 correct | `ACCURACY_FLOOR` |
| Wilson floor | `test_reject_wilson_floor` | 24/40 correct | `WILSON_FLOOR` |
| side inversion / one-sided | `test_reject_side_bias` | every ballot answers side 1 | `SIDE_BIAS` |
| response hash mismatch | `test_reject_response_hash_mismatch` | tamper `raw_response.sha256` | `RESPONSE_HASH_MISMATCH` |
| changed parser | `test_reject_parser_changed` | `freeze.response_parser_sha256` ≠ pinned | `PARSER_CHANGED` |
| changed invocation | `test_reject_invocation_drift` | unit `invocation.model` drift | `INVOCATION_DRIFT` |
| identity leakage | `test_reject_identity_leak` | `identity_visible=true` | `IDENTITY_LEAK` |
| side inversion (orientation) | `test_reject_orientation_not_mirrored` | mirror orientation = primary's | `ORIENTATION_NOT_MIRRORED` |
| invalid abstention | `test_reject_invalid_abstention` | one-sided abstain | `INVALID_ABSTENTION` |
| stale source | `test_reject_stale_source` | labels `source_snapshot` ≠ freeze | `STALE_SOURCE` |
| tuning/holdout overlap (image) | `test_reject_tuning_overlap` | holdout image in `tuning_image_shas` | `TUNING_HOLDOUT_OVERLAP` |
| tuning/holdout overlap (receipt) | `test_reject_receipt_level_tuning_overlap` | tuning receipt = holdout receipt | `TUNING_HOLDOUT_OVERLAP` |
| unknown fields | `test_reject_unknown_field` | extra key on a unit | `SCHEMA_REJECTED` |
| self-attested eligibility | `test_reject_self_attested_eligibility` | `judge.eligible=true` | `SCHEMA_REJECTED` |
| duplicate prompt/image | `test_reject_duplicate_unit` | append a duplicate unit | `DUPLICATE_UNIT` |
| duplicate JSON keys | `test_reject_duplicate_keys` | inject a second `schema_version` | `JSON_INVALID` |
| shape-compatible synthetic receipt | `test_reject_synthetic_receipt` | file-backed `path` → non-existent | `SYNTHETIC_RECEIPT` |
| labels digest tamper | `test_reject_labels_digest_tamper` | edit labels bytes, don't rebind | `LABELS_INVALID` |

Additional recompute-only codes reachable but not needing a bespoke case:
`RESPONSE_UNPARSEABLE` (no matching `FINAL:` line) and `IMAGE_BINDING`
(unit image sha ≠ label image sha, image bytes ≠ declared, or orientation set ≠
label stimulus set) — all derived, none trusted.

Path safety: `safe_regular_file` rejects absolute paths, `..`, empty segments,
`//`, backslashes, and any symlink component; labels and every artifact must be
plain regular files under the artifact root.

---

## 6. Receipt closure

The receipt is self-describing and binds the full evidence chain by digest:

- `input_sha256` — the calibration input as-seen.
- `holdout_labels_sha256` — recomputed from disk, must equal the declared
  binding (else `LABELS_INVALID`).
- `corpus_holdout_receipt_sha256` / `tuning_corpus_receipt_sha256` — the
  upstream `source-live` corpus receipts; overlap is rejected.
- `source_snapshot_sha256` — frozen source; labels must agree (`STALE_SOURCE`).
- `response_parser_sha256` — the pinned parser digest (recomputed at runtime).
- `invocation_adapter_sha256` — the frozen adapter every ballot must cite.
- `judge_configuration{provider,model,model_version,system_prompt_sha256,sampling_sha256}`
  — the frozen judge.
- `validator.fingerprint` — sha256 of this validator script.
- `bound_response_units` — true only when every response is a hash-matched file.

The receipt declares its own `external_limitations`: production classification
proves hash-bound raw responses over frozen source images; it does **not** by
itself prove those bytes are live Dataverse renders or live model calls. Corpus
liveness and panel identity are attested by the `source-live` corpus receipt and
the integrator live-smoke receipt in the declared evidence closure — the seam
this lane hands to `study-live`/the integrator via the canonical relay. This
lane owns the calibration receipt only; it never mints a certificate and cannot
mark `m32.4` complete.

---

## 7. Reproduce

```bash
cd "$POLYLANE_SOURCE_ROOT"
bash tests/test-taste-calibration-live.sh          # -> PASS ... assertions=22
shellcheck -S warning bin/polylane-taste-calibration-live.sh   # clean
shellcheck -S warning tests/test-taste-calibration-live.sh     # clean
bin/polylane-taste-calibration-live.sh parser-sha  # pinned parser digest
```

---

## 8. Skill receipts

SKILL-READ: data:statistical-analysis | /Users/leonardo/.codex/plugins/cache/claude-cowork/data/1.1.0/skills/statistical-analysis/SKILL.md | 2702170626-10434
SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279

SKILL-EVIDENCE: data:statistical-analysis — helped: its sample-size and
practical-vs-statistical-significance caution confirmed keeping the exact
two-sided binomial for the side probe (small `s≈24`) and a Wilson LCB rather
than a normal-approx interval near the 0.50 floor; both bounds are computed on
the finite held-out `n`, never asymptotically.

SKILL-EVIDENCE: engineering:testing-strategy — helped: its "cover security
boundaries and error handling, skip trivial getters" guidance shaped the test
file as a trust-boundary reject matrix (18 negative cases) over the validator's
data-integrity paths rather than unit-testing pure helpers; every contract
reject class maps to one red-first case (§5).
