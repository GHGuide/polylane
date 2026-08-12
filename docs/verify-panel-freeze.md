# Verify — panel-freeze (frozen machine-panel configuration and claim ceiling)

Run: `c41-source-calibration-20260812-a1` · Lane: `panel-freeze` · Target: `m32.4`

Subject under verification:

- `benchmarks/taste-live/calibration/panel.v1.json` — the frozen static panel
  configuration (`polylane.taste.panel/v1`), six slots.
- `tests/test-taste-panel-freeze.sh` — red-first hermetic freeze test: schema,
  identity/uniqueness, exact hash recomputation, and a 20-case tamper matrix.

Both artifacts were built test-first: the test was written and run against the
missing panel (observed failure `FAIL: panel file missing`), then the panel was
written to satisfy it.

---

## 1. What the static file is allowed to say — and what it is not

The panel binds only freeze-time facts:

| Bound in the file | Deferred to runtime |
|---|---|
| slot/judge/session identities (all unique) | observed `cli_version` / `model_version` |
| real adapter names + executable paths | CLI availability and auth |
| exact SHA-256 of system prompt, response schema, sampling canonical | eligibility (taste-calibration/v2 receipts only) |
| claim ceiling `HUMAN_CALIBRATED_MACHINE` | every per-unit vote, abstention, session id |
| correlation families + explicit limitations | audit recomputation (calibration-audit lane) |

The test enforces the boundary mechanically: no key named `eligible`,
`eligibility`, `human_certified`, `trusted`, `independent`, `available`,
`model_version`, `cli_version` (and variants) may appear anywhere in the file,
and no boolean may sit under any key matching `eligib|human|trust|independ`.
`runtime_observed_fields` must explicitly list `cli_version` and
`model_version` as runtime-filled. The static file therefore *cannot* call a
slot eligible, fabricate a model version, or assert independence.

## 2. Panel composition

Six slots across the two real judge adapters that exist in `bin/`:

| Slot | Provider | Adapter | Model | Config delta |
|---|---|---|---|---|
| `slot-claude-fable-5` | anthropic | `polylane-taste-judge-claude` | `claude-fable-5` | frozen argv template v2 |
| `slot-claude-opus-5` | anthropic | `polylane-taste-judge-claude` | `claude-opus-5` | frozen argv template v2 |
| `slot-claude-sonnet-5` | anthropic | `polylane-taste-judge-claude` | `claude-sonnet-5` | frozen argv template v2 |
| `slot-codex-gpt-5-codex-high` | openai | `polylane-taste-judge-codex` | `gpt-5-codex` | effort high, read-only sandbox |
| `slot-codex-gpt-5-high` | openai | `polylane-taste-judge-codex` | `gpt-5` | effort high, read-only sandbox |
| `slot-codex-gpt-5-medium` | openai | `polylane-taste-judge-codex` | `gpt-5` | effort medium, read-only sandbox |

Model ids are configuration intents; whether a CLI actually resolves them, and
to which exact version, is a runtime observation recorded in receipts
(`EXTERNAL-EVIDENCE`: availability is unknown here and is not claimed).

Frozen hashes (recomputed by the test on every run):

- `judge-claude-system.md` → `cc73f6c0…bf8c19c`
- `judge-codex-system.md` → `f4495f70…85c4c853`
- `judge-response-schema.json` (`taste-judge-response/v1`) → `a9e90337…44bfcda`
- sampling canonicals → SHA-256 of the exact `sampling_canonical` string held
  in each slot, so a sampling edit without a hash update is self-detecting.

## 3. Correlation limitations (documented, not waved away)

- Exactly **2** distinct families (`anthropic-claude`, `openai-gpt`);
  `distinct_family_count` is deliberately named to avoid claiming independence.
- Same-family slots share vendor, lineage, CLI, and system prompt — their
  agreement is never independent replication; `gpt-5` high vs medium are
  near-duplicates differing only in reasoning effort.
- Even cross-family agreement is weakened by shared web-scale training data
  and shared aesthetic conventions; family-level error correlation is not
  measured by per-slot eligibility and stays unknown.
- Calibration transfer beyond the frozen 2016–2018 screenshot corpus is
  unverified.

## 4. Abstention policy

Seven recorded classes (`cli_unavailable`, `auth_unavailable`, `timeout`,
`schema_invalid_response`, `provider_refusal`, `challenge_or_captcha`,
`ambiguous`). An abstention never becomes a vote, never counts correct, never
shrinks the 24-pair requirement; an insufficient panel is
`EXTERNAL-EVIDENCE-OPEN`, never a fixture.

## 5. How to verify

```bash
bash tests/test-taste-panel-freeze.sh
shellcheck -S warning tests/test-taste-panel-freeze.sh
```

Observed: `PASS: test-taste-panel-freeze (schema, identity, hash, tamper
matrix)` and a clean shellcheck. The test is hermetic (no network, no model,
no fixtures) and fails closed on: <5 slots, any duplicate slot/judge/session
identity, unknown or non-executable adapter, provider/adapter/model
mismatch, any prompt/schema/sampling hash drift, missing correlation
limitation, threshold drift, a single-provider panel, a claim above the
ceiling, a wrong run id, or any forbidden eligibility/human/trust/
independence/version field. Each of the 20 tamper cases was additionally
spot-checked to reject for its *specific* reason (e.g. sampling drift →
`sampling_sha256 does not match sampling_canonical`), not an incidental one.

## 6. Risk register (residual)

- **Runtime model drift** (medium/High): mitigated — receipts must carry
  observed versions; the panel binds intent hashes only. Owner: calibration
  campaign/audit lanes.
- **Correlated same-family failure** (medium/Medium): mitigated by documented
  limitation + two-family span; not eliminable with two vendors. Accepted.
- **Schema template divergence** (low/Medium): per-work-unit response schemas
  may vary only in `work_unit_id`; the panel binds the canonical
  `taste-judge-response/v1` file. Any other deviation breaks the slot's
  hash binding. Owner: benchmark-preflight.

## SKILL-EVIDENCE

- SKILL-EVIDENCE: superpowers:test-driven-development — helped: test written
  first and observed failing (`panel file missing`) before the panel existed;
  tamper matrix written before the fixtures it rejects.
- SKILL-EVIDENCE: engineering:testing-strategy — helped: shaped the split
  between one positive freeze check and a 20-case negative reject matrix at
  the trust boundary, skipping redundant per-field unit tests.
- SKILL-EVIDENCE: engineering:debug — helped: used to isolate why an early
  tamper case (byte-level prompt edit fixture) rejected for the wrong reason
  (path resolution, not hash mismatch); the fragile case was removed and the
  hash-drift case retained.
- SKILL-EVIDENCE: operations:risk-assessment — helped: produced §6 residual
  risk register and the family-correlation likelihood/impact framing in §3.
