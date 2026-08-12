# verify — stimulus-evidence (Cycle 39, run c39-visual-loop-20260812-a1)

Coordinator-owned anonymized visual stimulus bundle: `bin/polylane-taste-stimulus.sh`
(+ `tests/test-taste-stimulus.sh`). New helper/test only; no existing file touched.

## Commands run

```
bash tests/test-taste-stimulus.sh          → test-taste-stimulus.sh: 34 pass, 0 fail
shellcheck -S warning bin/polylane-taste-stimulus.sh   → clean (via bin/polylane-check.sh cache)
git diff --check                            → clean
```

Real OCR/browser tools are NOT installed here (EXTERNAL-EVIDENCE): every positive
test uses the fixture scanner and is classified `fixture`. A declared `production`
run yields `external` and blocks — the integrated real-OCR/judge run is benchmark scope.

## CLI

```
polylane-taste-stimulus.sh build SPEC OUT -- SCANNER [args...]   # build+scan+escrow, atomic
polylane-taste-stimulus.sh verify OUT                            # re-prove escrow/orientation/bundle
```

Spec (`taste-stimulus-spec/v1`): `run_id`, `brief_lock`, `design_lock`,
`ocr{adapter_id,adapter_version,command_sha256,kind:fixture|production}`,
`identity_terms[]`, `inherent_identity_terms[]`, `candidates[2]{candidate_id,capture_manifest}`.
Scanner adapter contract: reads `POLYLANE_STIMULUS_SCAN_IMAGE`, writes
`POLYLANE_STIMULUS_SCAN_OUTPUT/ocr.json` = `{schema_version:"taste-ocr/v1",text:[…]}`.
The scanner's file hash MUST equal the spec pin; its output text is re-scanned,
never trusted.

## Outputs (published atomically to OUT/)

| Artifact | Visibility | Purpose |
|---|---|---|
| `stimulus-receipt.json` (`taste-stimulus-receipt/v1`) | consumers | relayed schema below |
| `escrow.json` (`taste-stimulus-escrow/v1`) | coordinator-only | opaque→canonical bindings |
| `judge-bundle/brief.json` (`taste-stimulus-brief/v1`) | judges | brief clauses + rubric, no ids |
| `judge-bundle/flow.json` (`taste-stimulus-flow/v1`) | judges | states/routes/viewports per stimulus |
| `judge-bundle/stimuli/<stim>/<cap>/screenshot.png` | judges | exact screenshot bytes, re-keyed |
| `scan-receipts/<stim>-<cap>.json` (`taste-stimulus-scan-receipt/v1`) | coordinator | OCR adapter + byte bindings |

The judge bundle is published only for a `clean` + `fixture` outcome. Leak / external
outcomes still publish `escrow.json` + `stimulus-receipt.json` (evidence of the abstain)
but never anonymized stimuli, and `build` exits non-zero.

## Visible-versus-escrow schema (relay for ballot/threat/tournament/certificate)

Judge-visible (`stimulus_ids`, orientation, brief clauses, rubric, screenshots, flow)
carries ONLY opaque `stim-[0-9a-f]{12}` ids. Canonical truth lives in escrow, invisible
to judges:

```
receipt.stimulus_ids            = ["stim-<12hex>", "stim-<12hex>"]   → ballot .candidate_ids
receipt.candidate_ids_escrow_sha256 = sha256(jq -cS escrow.json)     → ballot .candidate_ids_escrow_sha256
receipt.orientation."A/B"       = {A:stimX, B:stimY, sha256}         → ballot exposure display_order proof
receipt.orientation."B/A"       = {A:stimY, B:stimX, sha256}
receipt.leakage_status          = clean | leak | external            → threat provenance input
receipt.threat_status           = clean | blocked | external
receipt.fixture_classification  = fixture | external                 → certificate fixture boundary
receipt.judge_bundle_sha256     = sha256(sanitized_map | brief_file | flow_file)   (immutable bundle)
receipt.sanitized_artifact_sha256 = { "<stim>/<cap>": <png sha256> }
receipt.reason_codes            = stable codes (below)

escrow.bindings[] = { stimulus_id, candidate_id, source_revision,
                      capture_manifest_sha256, screenshot_png_sha256[], decoded_pixel_sha256[], dom_sha256[] }
```

Ballot's `candidate_ids` ARE the opaque `stim-` ids (per `taste-mirrored-group/v1`
`^stim-[a-f0-9]{12}$`), and `canonical_choice` is a `stim-` id — so the ballot lane is
already blind; the escrow lets only the certificate compiler de-anonymize a winning
`stim-` back to its `cand-` id, source revision, and pixels.

## Leakage matrix (independent DOM + OCR-of-exact-bytes scan)

Haystack per capture = raw `dom.html` ∪ OCR `text[]` (from exact screenshot bytes) ∪
`action-trace.json`, lowercased. Caller `visible_text` / identity booleans unused.

| Vector | Detection | Outcome | Reason |
|---|---|---|---|
| candidate/provider/model name in DOM | `PROVIDER_RE` + identity_terms | leak/block | `IDENTITY_LEAK` |
| identity in OCR text (bytes) | scan of adapter output | leak/block | `IDENTITY_LEAK` |
| hidden / zero-size text | whole-DOM byte scan (not render-gated) | leak/block | `IDENTITY_LEAK` |
| alt/aria/filename/path leakage | whole-DOM byte scan | leak/block | `IDENTITY_LEAK` |
| cross-candidate label (other cand id) | both cand ids auto-added as terms | leak/block | `IDENTITY_LEAK` |
| prompt injection | `INJECTION_RE` | leak/block | `PROMPT_INJECTION` |
| generation metadata | `METADATA_RE` | leak/block | `GENERATION_METADATA` |
| malicious scanner injecting identity | its output re-scanned as untrusted | leak/block | `IDENTITY_LEAK` |
| changed pixels/DOM + reused manifest hash | byte sha ≠ manifest sha | block | `CAPTURE_TAMPERED` (die) |
| changed judge-bundle bytes + reused receipt | `verify` re-hashes vs receipt | block | die |
| same candidate twice | candidate_id seen-set | block | die |
| missing state (coverage differs) | sorted required_states must match | block | die |
| fixture scanner relabeled production | `kind==production` → external | block | `PRODUCTION_OCR_EXTERNAL` |
| inherent brand identity only | matches ⊆ inherent_identity_terms | external/abstain | `INHERENT_IDENTITY_EXTERNAL` |
| unsafe/symlink scanner or path, unpinned hash | path + pin checks | block | die |

Provider tokens, injection, and metadata are never eligible to be "inherent". Screenshots
are copied byte-exact — legitimate product text is never altered to force a pass.

## Orientation proof

`build` emits a balanced mirror: `A/B = {A:stim_a, B:stim_b}`, `B/A = {A:stim_b, B:stim_a}`,
each with `sha256 = sha256("<order>|A=<stim>|B=<stim>")`. Every candidate appears once in
A and once in B. `verify` proves: A/B.A==B/A.B, A/B.B==B/A.A, A/B.A≠A/B.B, both per-order
hashes recompute, and the id pair equals the escrow pair. A ballot exposure with
`display_order:"A/B"` and `choice:"A"` therefore maps deterministically to
`orientation."A/B".A` — the canonical `stim-` id — so a blind A/B vote is verifiable
without exposing identity. Test `verify-detects-orientation` proves a non-mirrored map is
rejected.

## Test ledger (red→green)

34 assertions: clean opaque mirrored bundle (schema, clean status, 2 opaque ids, escrow
hash binds, mirror, rubric=8, no cand id in bundle, verify passes); DOM identity; OCR
identity; hidden zero-size identity; prompt injection; filename/path leak; cross-candidate
label; bundle-tamper (verify) + stale-capture (build); malicious scanner; wrong orientation;
duplicate candidate; missing state; production relabel → external; inherent brand → external;
symlink scanner; unpinned scanner. Leakage + orientation cases were written red first (helper
absent → intended-behavior assertions failed), then driven green.

## SKILL-READ

- SKILL-READ: design:design-critique | /Users/leonardo/.codex/plugins/cache/claude-cowork/design/1.2.0/skills/design-critique/SKILL.md | 2647275183-3923
- SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
- SKILL-READ: operations:risk-assessment | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md | 3889652016-1630
- SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.claude/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md | 1657109997-9015

## SKILL-EVIDENCE

- SKILL-EVIDENCE: superpowers:test-driven-development — helped: wrote the full leakage/orientation assertion set first, watched the green assertions fail with the helper absent, then implemented to green; no production code preceded a failing test.
- SKILL-EVIDENCE: engineering:testing-strategy — helped: prioritized security-boundary + contract cases (identity in DOM vs OCR, tamper, pin, relabel) over trivial coverage, and added a consumer-contract check (escrow-hash binds ballot field) as the integration seam.
- SKILL-EVIDENCE: operations:risk-assessment — helped: enumerated leak vectors as a likelihood/impact register (hidden text, cross-candidate, malicious scanner, stale receipt, inherent brand) so each high-impact path became a named reason code and a red test rather than an untested assumption.
- SKILL-EVIDENCE: design:design-critique — helped: shaped the judge bundle to expose only first-impression signal (brief clauses, staged screenshots, states/flow, the 8-criterion rubric) and nothing identifying, matching the critique framework's hierarchy/consistency dimensions without leaking authorship.

## DEFERRED
DEFERRED: none
