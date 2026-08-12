# verify — ballot-live (`taste-ballot-validation/v2` producer)

Lane: **ballot-live** · run `c40-live-harness-20260812-a3`
Producer: [`bin/polylane-taste-ballot-live.sh`](../bin/polylane-taste-ballot-live.sh)
Tests: [`tests/test-taste-ballot-live.sh`](../tests/test-taste-ballot-live.sh) — **50 pass, 0 fail**, ShellCheck clean.

## What it produces

A production `taste-ballot-validation/v2` receipt that derives the mirrored-group
winner **only** from bound live raw responses. Every caller field is treated as
forged until recomputed: the group SHA, both raw-response hashes, pointwise
self-hashes, request/image/orientation hashes, candidate-capture hashes, the
calibration receipt hash, independence attestations, and the escrow binding are
all recomputed here; the winner is **derived** from the raw bytes through the
recomputed orientation map, never read from the caller.

`fixture_only:false` (classification `live`) is reachable only when every bound
invocation receipt is classified `live` by a **declared** provider adapter
(`claude|codex|gemini-visual-judge`). Any fixture ancestor degrades to a fixture
receipt and can never mint a production receipt.

## Positive receipt (real derivation)

Minted from a positive **test fixture** (real-format signed hashes; no live
provider actually ran — see the self-attestation seam below). Winner `stim-a…`
is derived because both mirrored orientations, served by two distinct judges,
independently resolve to it:

```json
{
  "schema_version": "taste-ballot-validation/v2",
  "status": "eligible",
  "classification": "live",
  "fixture_only": false,
  "human_certified": false,
  "mirror_group_id": "mg-live-001",
  "winner": "stim-aaaaaaaaaaaa",
  "group_sha256": "b5e0b6d9e1b432bedf1e30a4a378b2e3281a9483d569ad00b37f26d13455728f",
  "derived": {
    "winner": "stim-aaaaaaaaaaaa",
    "method": "unanimous-mirrored-pairwise",
    "exposures": [
      {"display_order":"A/B","judge_id":"judge-001","canonical_choice":"stim-aaaaaaaaaaaa","response_sha256":"029e49eb…"},
      {"display_order":"B/A","judge_id":"judge-002","canonical_choice":"stim-aaaaaaaaaaaa","response_sha256":"d39947c8…"}
    ]
  },
  "judges": ["judge-001","judge-002"],
  "validator": {"id":"polylane-taste-ballot-live","fingerprint":"6ebefcbd…"},
  "reason_codes": []
}
```

## Cert-consumability (v2 certificate consumer)

The consumer is a **forbidden neighbour** (`bin/polylane-taste.sh`); we assert its
documented promotion predicate, we never invoke it. Its production-promotion
edge (`polylane-taste.sh:398–407`, `V2_CERT_FILTER`) requires, per mirrored
group `$g` with raw-file SHA `$gsha`:

| Consumer predicate | Receipt field | Recomputed here from |
|---|---|---|
| `schema_version == "taste-ballot-validation/v2"` | `schema_version` | literal |
| `status == "eligible"` | `status` | derivation success |
| `human_certified == false` | `human_certified` | literal (never claims human) |
| `mirror_group_id == $g.mirror_group_id` | `mirror_group_id` | slurped from validated group |
| `brief_sha256 == $g.brief_sha256` | `brief_sha256` | `sha256_file(brief)`, bound to group |
| `fixture_only == false` | `fixture_only` | all invocations declared-`live` |
| `group_sha256 == $gsha` | `group_sha256` | `sha256_file(group)` — raw bytes, matches consumer `S()` |
| `winner == $g.exposures[0].canonical_choice` | `winner` | derived from raw responses |

`group_sha256` uses the raw-file SHA because the consumer's `$gsha = S(group.in)`
is the manifest's raw-file SHA (`polylane-taste.sh:142,368`). `escrow` uses the
**canonical** SHA (`jq -cS`) because the escrow producer binds it that way
(`polylane-taste-stimulus.sh:291`). Test `receipt-is-cert-consumable-as-production`
encodes this predicate against a minted receipt.

## Transitive evidence — every edge recomputed, one mutation per edge

Winner trust flows bottom-up; a break at any edge fails closed with **no
receipt** and a specific reason. Each row is a positive recompute plus the red
mutation test that proves the edge is load-bearing.

| # | Evidence edge | Recompute (producer) | Fail-closed reason | Mutation test |
|---|---|---|---|---|
| 1 | brief → group | `sha256_file(brief)` == `group.brief_sha256` | — | `tamper-brief-breaks-brief-binding` |
| 2 | escrow → group | `sha256_canonical(escrow)` == `group.candidate_ids_escrow_sha256` | — | `tamper-escrow-breaks-escrow-binding` |
| 3 | escrow distinctness | two distinct stimuli → two distinct candidates | `ALIAS` | `escrow-self-comparison-is-alias` |
| 4 | capture → stimuli | both escrowed stimuli have bound `screenshot_png_sha256` | — | `tamper-capture-breaks-capture-binding` |
| 5 | pointwise self-hash | `record_self_hash` (canonical, hash-field removed) | — | `tamper-pointwise-breaks-self-hash` |
| 6 | pointwise → brief/capture | pointwise binds recomputed brief + capture SHAs | — | `pointwise-brief-must-bind-group-brief` |
| 7 | orientation balance | exact mirror over the escrowed pair, A/B.A==B/A.B | — | `orientation-must-be-balanced-mirror` |
| 8 | orientation self-hash | `sha256_text("A/B\|A=…\|B=…")` == `orientation.sha256` | — | `orientation-hash-must-bind` |
| 9 | request image order | `request.images` stimuli == `orientation[order]` | — | `request-image-order-must-match-orientation` |
| 10 | request image hashes | `request.images.*.image_sha256` == capture screenshot SHAs | — | (covered by 4/9 recompute) |
| 11 | response bytes → invocation | `sha256_file(response.raw)` == `invocation.response_sha256` | — | `raw-response-must-bind-invocation-hash` |
| 12 | request bytes → invocation | `sha256_file(request)` == `invocation.request_sha256` | — | `tamper-invocation-request-binding` |
| 13 | attestation → group edge | `sha256_file(attestation)` == exposure `independence_attestation_sha256` | — | `tamper-attestation-breaks-independence-binding` |
| 14 | calibration eligibility | serving judge is `eligible+independent`, `pass`, no-identity, no-shared-channel | — | `uncalibrated-judge-rejected` |
| 15 | attested channel | attestation declares `no_shared_ballot_channel:true`, `independent:true` | — | `attested-shared-channel-rejected` |
| 16 | winner derivation | raw `choice` → `orientation[order]` → canonical; both mirrors agree | `SIDE_ORDER_CONTRADICTION` | `side-order-contradiction-rejected` |

## Attacks — every forbidden mode fails closed

| Attack | Vector | Verdict | Test |
|---|---|---|---|
| Caller-supplied winner | `group.outcome`/`canonical_choice` disagrees with derivation | `CALLER_WINNER` | `caller-supplied-winner-rejected` |
| Missing raw bytes | empty/absent `response.raw` | `missing raw response bytes` | `missing-raw-bytes-rejected` |
| Prompt injection (response) | jailbreak markers in raw response | `INJECTION` | `prompt-injection-in-response-rejected` |
| Identity leak (response) | candidate id in judge-visible bytes | `IDENTITY_LEAK` | `identity-leak-to-judge-rejected` |
| Identity key (group) | `provider`/`model`/… key in blinded group | `IDENTITY_LEAK` | `identity-key-in-blinded-group-rejected` |
| Abstention asymmetry | one side abstains, other picks | `ABSTENTION` | `abstention-asymmetry-rejected` |
| Shared ballot channel | two exposures share a `session_id` | `REUSE` | `shared-ballot-channel-rejected` |
| One judge, both orders | same `judge_id` serves A/B and B/A | `JUDGE_NOT_INDEPENDENT` | `same-judge-both-orientations-rejected` |
| Aliased judge | two judge ids, one fingerprint | `ALIAS` | `aliased-judge-fingerprint-rejected` |
| Response reuse | identical raw bytes across orders | `REUSE` | (edge 11 + distinct-response guard) |
| Stale / future timestamp | pairwise before pointwise; future-dated | `STALE_TIMESTAMP` | `pairwise-before-pointwise-rejected`, `future-dated-exposure-rejected` |
| Fixture ancestor | any invocation not `live`, or undeclared adapter | degrade → `fixture_only:true` | `non-live-invocation-degrades-to-fixture`, `undeclared-adapter-degrades-to-fixture` |

## Forbidden self-attestation — the residual seam (honest limit)

The producer **cannot** cryptographically prove a real provider ran. Live
provenance is delegated to each invocation receipt's self-declared
`classification:"live"` plus a declared `adapter_kind`. A caller who fabricates
raw responses, re-signs the invocation's `response_sha256`/`request_sha256`, and
declares `classification:"live"` with a declared adapter would pass every hash
binding and mint `fixture_only:false`. The positive receipt above is exactly
such a fixture: **no live provider ran**; it is a real-format test fixture.

What the producer *does* guarantee, and what it explicitly does not:

- **Guaranteed** — the winner cannot be forged *independently of the raw bytes*:
  position is bound to `response.raw` via `response_sha256`; canonical mapping is
  bound via the recomputed orientation; the mirror must agree; identity is
  escrowed and blinded; judges are distinct, independent, and calibrated. To move
  the winner an attacker must rewrite the raw judge answer itself.
- **Not guaranteed** — that the rewritten raw answer was ever produced by a live
  provider. That single fact is asserted by the declared adapter's invocation
  receipt and is **out of this producer's cryptographic reach**. The receipt
  records the delegation: `classification`, the adapter, and the validator's own
  fingerprint (`validator.fingerprint = sha256(producer script)`) so a downstream
  auditor can see exactly which code and which declared adapters vouched for
  liveness.

This is why the producer never self-attests liveness and the certificate consumer
still treats a v2 `fixture_only:false` receipt as *promotion evidence gated by the
external adapter*, not as proof of a live panel. The `external_limitations` the
consumer emits ("panel identity and host assurance remain externally scoped")
carry the same boundary.

## Reproduce

```bash
bin/polylane-check.sh "$PWD/.polylane/check-cache/ballot-live" -- bash tests/test-taste-ballot-live.sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/ballot-live" -- shellcheck -S warning bin/polylane-taste-ballot-live.sh tests/test-taste-ballot-live.sh
```

## Skill receipts

- **SKILL-READ**: engineering:code-review | `/Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/code-review/SKILL.md` | fingerprint `936987158-4285`
- **SKILL-READ**: engineering:testing-strategy | `/Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md` | fingerprint `2811424084-1279`
- **SKILL-EVIDENCE**: engineering:code-review — **helped**: its security/correctness lens drove the trust-seam audit that surfaced the winner-derivation and forbidden-self-attestation seams; the residual-liveness limit above is the concrete finding.
- **SKILL-EVIDENCE**: engineering:testing-strategy — **helped**: its "security boundaries + error handling + edge cases" focus shaped the red-first, one-mutation-per-edge structure (positive production fixture + 16 evidence edges + 12 attack modes) rather than trivial-path coverage.
