# Verify — lane `hcm-privacy` (run `c45-hcm-pipeline-20260819-a1`, target m32.8)

Goal: the HCM-v2 consent record and privacy boundary, and proof that no
prohibited certification claim is reachable — each by a regression test.

Delivered:

| path | role |
|---|---|
| `bin/polylane-taste-consent.sh` | consent / withdrawal / privacy boundary / claim-safety pipeline (386 lines) |
| `tests/test-hcm-v2-privacy.sh` | consent record, PII boundary, holdout-label boundary, external-dependency openness (62 assertions) |
| `tests/test-hcm-v2-claim-safety.sh` | prohibited claim labels, statuses, and certification flags (26 assertions) |

## Commands

```
polylane-taste-consent.sh record SPEC OUT                  # hcm-v2-consent/v1
polylane-taste-consent.sh withdraw CONSENT WITHDRAWN_AT OUT # hcm-v2-withdrawal/v1
polylane-taste-consent.sh pii-scan FILE
polylane-taste-consent.sh blind-check FILE                 # participant-facing artifact
polylane-taste-consent.sh claim-scan FILE...
polylane-taste-consent.sh external-open OUT                # hcm-v2-external-dependencies/v1
```

## Frozen parameters bound

Everything below is read from the contract at run time. The only inlined
literals are the two status strings, and each has an assertion that fails the
command when the contract's value changes (`assert_external_open_contract`,
`bin/polylane-taste-consent.sh:225`).

| parameter | source of truth | value at freeze | where enforced |
|---|---|---|---|
| `source_calibration.hcm_v2.source_id` | CONTRACT-LOCK.v3.json | `HCM-v2` | `cmd_record` rejects a consent record whose `study_id` differs (`:280`) |
| `source_calibration.hcm_v2.governance_requirements_are_external` | CONTRACT-LOCK.v3.json | `true` | `assert_external_open_contract` — a lock that flips this fails `record` and `external-open` |
| `source_calibration.hcm_v2.status` | CONTRACT-LOCK.v3.json | `EXTERNAL-EVIDENCE-OPEN` | same assertion; inlined string, drift-tested |
| `source_calibration.hcm_v2.authority` | CONTRACT-LOCK.v3.json | `EXTERNAL_TARGET_MATCHED` | same assertion; emitted verbatim into the external-dependency record |
| `private_hcm_v2_prerequisite.status` | EVIDENCE-CLAIM-REGISTRY.v3.json | `EXTERNAL-EVIDENCE-OPEN` | same assertion; emitted as the record's `status` |
| `private_hcm_v2_prerequisite.human_certified` / `.taste_certified` | EVIDENCE-CLAIM-REGISTRY.v3.json | `false` / `false` | same assertion — a registry claiming either fails the command |
| `private_hcm_v2_prerequisite.external_requirements` | EVIDENCE-CLAIM-REGISTRY.v3.json | 14 requirements | `external-open` emits each one `satisfied: false`; the test compares the emitted set to the registry's set, so adding a requirement to the registry cannot silently drop it |
| `claim_minting.certification_mint_authority` | EVIDENCE-CLAIM-REGISTRY.v3.json | `NONE_IN_V3` | copied into every emitted record; asserted by the claim-safety test |
| `prohibited_outputs.claim_labels` + `.statuses` | EVIDENCE-CLAIM-REGISTRY.v3.json | 2 tokens | `registry_prohibited_tokens` — the tokens are never written in the script (verified below: a per-token `grep -c -F` over the script returns `0` for both) |
| `prohibited_outputs.*_true_forbidden` | EVIDENCE-CLAIM-REGISTRY.v3.json | `human_certified`, `taste_certified` | `registry_forbidden_flags` derives the flag names from the registry keys; if the registry stops forbidding either, `claim-scan` fails loudly instead of permitting it |

No frozen number is re-typed as a magic constant anywhere in the lane.

## What the three required proofs are

1. **Consent record with no PII.** The spec key set is exact
   (`study_id`, `consent_version`, `enrolment_nonce`, `consented_at`,
   `withdrawal_path`) — an extra `email`/`full_name`/`phone`/`ip_address`/
   `postcode` field is rejected before anything is derived. The enrolment
   reference must be an opaque 64-hex nonce, so an identifier (`participant@…`,
   `participant-0007`) cannot be enrolled at all, and the participant id is
   `sha256(study_id:nonce)` — stable enough to honour a withdrawal, opaque
   enough to identify nobody. The nonce never reaches the record
   (`assert_fail grep -q "$NONCE" "$RECORD"`). Every emitted artifact is
   PII-scanned *before* it lands on disk (`emit`), so a PII-shaped field
   reaching an emitted record is a test failure, twice over: through the spec
   gate and through `pii-scan` on the emitted bytes.
2. **Holdout labels unreachable from participant-facing artifacts.**
   `blind-check` rejects a stimulus, ballot, or receipt that carries a label key
   (`holdout*`, `gold*`, `ground_truth`, `human_rating`, `human_label`,
   `answer_key`, `correct_option`, `expected_winner`), a split assignment
   (`split`), or a split value (`holdout`/`development`/`validation`/
   `confirmatory`) at any depth, and also rejects PII. The machine panel is
   qualified from exactly these blinded artifacts, so the boundary is enforced
   in code, not in prose. The test asserts nine leak shapes, plus a leaky ballot
   and a leaky receipt, are all rejected.
3. **No prohibited claim reachable.** `claim-scan` refuses any file containing a
   registry-prohibited label or status (bytes, so prose counts), or setting a
   forbidden certification flag true — both as raw bytes (`flag = true` in a
   report, `flag: true` in YAML) and structurally in JSON (so a value split
   across lines cannot slip past the byte regex). `emit` runs `claim-scan` on
   every artifact before writing, so a spec that smuggles a prohibited label
   through an accepted field fails and leaves no file behind. The script source
   contains neither prohibited literal, because the vocabulary is read from the
   registry at run time. The two test files do spell the tokens out — that is
   deliberate: the tests are the independent hard-coded check, and they would
   not catch a registry that silently dropped a token if they read it from the
   same registry the code reads. This document avoids the literals so that it,
   too, passes `claim-scan`.

## Red then green

The two tests were written first and run against today's behaviour before any
implementation existed:

```
$ bash tests/test-hcm-v2-privacy.sh
tests/test-hcm-v2-privacy.sh: line 23: …/bin/polylane-taste-consent.sh: No such file or directory
privacy exit=1
$ bash tests/test-hcm-v2-claim-safety.sh
tests/test-hcm-v2-claim-safety.sh: line 19: …/bin/polylane-taste-consent.sh: No such file or directory
claim exit=1
```

Because "the file does not exist yet" is a weak red, each guard was then
mutation-tested: the implementation was broken one guard at a time and the
tests re-run. Every mutation must be killed.

| mutation | result |
|---|---|
| holdout scan inverted | killed |
| PII scan inverted | killed |
| prohibited-token grep disabled | killed |
| certification-flag byte regex disabled | killed |
| certification-flag JSON check disabled | killed |
| contract drift assertion removed (`governance_requirements_are_external`) | killed |
| enrolment-nonce opacity check removed | killed |
| overwrite guard removed | killed |
| `study_id` binding to the lock removed | killed |
| external requirements emitted `satisfied: true` | killed |
| `emit` scans skipped | killed |

Two mutations survived the first battery — the byte-regex path for a
certification flag, and the nonce-opacity rule (both were masked by a redundant
check). Tests were added for each (a non-JSON report that sets a certification flag
true, a
multi-line JSON flag, and a PII-free but sequential enrolment id) and both
mutations are now killed. That is the honest reason the suites are 62 and 26
assertions rather than fewer.

## Fresh counts (run 2026-08-19T15:00:56Z, this worktree)

```
$ bash tests/test-hcm-v2-privacy.sh
PASS test-hcm-v2-privacy.sh (62 assertions)

$ bash tests/test-hcm-v2-claim-safety.sh
PASS test-hcm-v2-claim-safety.sh (26 assertions)

$ shellcheck -S warning bin/polylane-taste-consent.sh tests/test-hcm-v2-privacy.sh tests/test-hcm-v2-claim-safety.sh
shellcheck: clean

$ jq -r '.prohibited_outputs | (.claim_labels + .statuses) | unique[]' \
    docs/polylane/taste-certification/contracts/EVIDENCE-CLAIM-REGISTRY.v3.json |
  while IFS= read -r t; do grep -c -F -- "$t" bin/polylane-taste-consent.sh || true; done
0
0        # one line per prohibited token: neither appears in the script

$ bin/polylane-taste-consent.sh external-open "$D/ext.json" && jq -c '{status,authority,satisfied,requirements:(.requirements|length)}' "$D/ext.json"
{"status":"EXTERNAL-EVIDENCE-OPEN","authority":"EXTERNAL_TARGET_MATCHED","satisfied":false,"requirements":14}

$ bash tests/test-install-fresh.sh        # existing suite that enumerates bin/*.sh
test-install-fresh.sh: 63 pass, 0 fail
```

Environment: `jq-1.8.2`, `GNU bash 3.2.57(1)-release (arm64-apple-darwin25)`.
`tests/run.sh` and doctor rehearsals were not run — the integrator and
coordinator own those.

## External dependencies — open, never satisfied

m32.8a is external. The ethics review that approves this consent flow is not
something this repository can perform, so `external-open` emits all 14 registry
requirements — `ethics_privacy_determination`, `consent`, `compensation`,
`population_frame`, `locale_quotas`, `tasks`, `viewports`, `randomization`,
`exclusions`, `retention`, `withdrawal`, `ballots`, `analysis`,
`governance_owner` — each `satisfied: false, evidence: "EXTERNAL"`, under
`status: EXTERNAL-EVIDENCE-OPEN`, `satisfied: false`. There is no code path that
can set any of them true: the value is a literal `false` in the emitter, and the
test fails if a single requirement is emitted otherwise.

Compliance framing (from the `legal:compliance-check` lens, not legal advice):
the consent artifact is the *record* of a lawful basis, not the basis itself;
the withdrawal artifact is the erasure/objection path; data minimisation is
structural (exact key set, opaque id) rather than promised. What remains outside
this lane and outside this repository: the ethics/DPIA determination, the
retention schedule and its enforcement, the compensation terms, the population
frame and locale quotas, and a named governance owner. Nothing here should be
read as an approval of any of those.

## Limitations

- **The PII scan is a heuristic backstop, not the guarantee.** The guarantee is
  structural: an exact spec key set plus a mandatory opaque nonce, so identifying
  data has no field to arrive in. The scan (identifying key tokens; email,
  telephone, and IPv4 value shapes) catches what a future caller might add. A
  novel identifier shape — a locale-specific national id in a free-text field —
  would pass the scan; it would still have to get past the exact key set first.
  The telephone rule deliberately ignores strings longer than 17 characters so
  digests and nonces are not flagged.
- **`blind-check` is a boundary, not a router.** It rejects an artifact handed to
  it; it cannot force a producer to hand its artifacts over. Wiring the stimulus,
  ballot, and receipt emitters through it belongs to the corpus lane and the
  integrator.
- **`claim-scan` proves no *prohibited token* is emitted.** It does not judge
  whether a permitted claim is warranted; the evidence DAG derives effective
  authority, and this lane deliberately mints nothing.
- **No study result exists.** Every artifact here is derived from a spec or from
  the contract. Nothing in this lane simulates a human judgment, a recruited
  participant, a consent signature, or a study outcome, and no fixture in the
  tests is presented as one.
- **Timestamps are supplied, not read from the clock**, so records are
  deterministic and reproducible. Callers must supply RFC 3339 UTC.

## Skill evidence

SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/test-driven-development/SKILL.md | plugin-cache | 1657109997-9015
SKILL-READ: legal:compliance-check | /Users/leonardo/.codex/plugins/cache/claude-cowork/legal/1.3.0/skills/compliance-check/SKILL.md | plugin-cache | 1175060322-14694

SKILL-EVIDENCE: superpowers:test-driven-development — helped: its "verify RED —
watch it fail, for the expected reason" rule is what exposed that a
file-not-found red proves almost nothing here. That pushed the mutation battery,
which found two guards (the certification-flag byte regex and the nonce-opacity
rule) that no test actually exercised — both were masked by a redundant check
and would have shipped untested.

SKILL-EVIDENCE: legal:compliance-check — helped: its data-subject-rights and
DPA/retention checklists set the field list for the consent record. Two concrete
consequences: withdrawal became a first-class emitted artifact with its own
schema and destruction `effect` (an erasure path, not a footnote), and
`retention`, `compensation`, and `governance_owner` are carried as explicitly
open external requirements rather than being quietly treated as covered by the
consent record. Its "this is not legal advice; escalate to counsel" framing is
why the external section states the ethics determination is outside this
repository rather than implying the pipeline satisfies it.
