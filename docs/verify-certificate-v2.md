# Verify — certificate-v2 (Cycle 39, run c39-visual-loop-20260812-a1)

Production taste-certificate compiler: `bin/polylane-taste.sh certify` now
dispatches on the manifest schema. `taste-evidence-manifest/v1` keeps compiling
for compatibility but is permanently fixture-marked; `taste-evidence-manifest/v2`
is the production path that consumes the complete hash-bound validator chain and
emits a deterministic `taste-certificate/v2` current-subject promotion
certificate.

## Commands and outputs

```text
$ bash tests/test-taste-certification.sh
PASS: taste certification compiler
(exit 0; ~2m30s: five hermetic ten-brief/50-group/100-judge chains plus 24
adversarial mutations, each compiled end to end)

$ shellcheck -S warning bin/polylane-taste.sh
(exit 0, no findings)

$ shellcheck -S warning tests/test-taste-certification.sh
(exit 0, no findings)

$ git diff --check
(exit 0, clean)
```

Both verification commands are cached under
`.polylane/check-cache/certificate-v2` via `bin/polylane-check.sh`
(`CHECK-CACHE: PASS` for the focused suite and the compiler ShellCheck run).

## v1 / v2 authority table

| Property | v1 `certify` (compat) | v2 `certify` (production) |
|---|---|---|
| Manifest schema | `taste-evidence-manifest/v1` | `taste-evidence-manifest/v2`, closed key set (caller can never smuggle `status`, `score`, or `winner`) |
| Invocation | `certify MANIFEST CERT` | `certify MANIFEST CERT SUBJECT_ROOT` |
| Certificate schema | `taste-certificate/v1` with `fixture_only:true, production:false` always | `taste-certificate/v2` with `fixture_only:false` only when every receipt is production-grade |
| Runner-gate authority | **None.** A current runner gate must reject any certificate that is not `taste-certificate/v2` with `status=TASTE-CERTIFIED` and `fixture_only:false` | Sole promotion authority |
| Artifact trust | Shape-only: declared paths are parsed, digests inside receipts are not recomputed | Every referenced path is safe/relative/regular/non-symlinked, duplicate-key-free JSON, and its SHA-256 is recomputed and matched against the manifest |
| Receipt trust | Shape-compatible JSON accepted | Receipt `input_sha256` (or `group_sha256` / `capture_manifest_sha256`) must equal the recomputed digest of the exact raw artifact in this manifest; cross-checked values (winner, capture_count, record_count, brief-win counts) must match the compiler's own recomputation |
| Subject binding | Per-brief unique revisions, not tied to the repo | Single `subject_revision` = integrator HEAD or proven ancestor; commits after it may only touch `declared_evidence_paths`; merge commits in the range fail closed |
| Losing briefs | Any lost brief added a fatal `BRIEF_NOT_WON` | Up to three losses recorded in `briefs_lost`; fatal only below the 7-win floor |

## Validator chain (consumed receipts)

```text
                         taste-evidence-manifest/v2  (closed schema)
                                      |
        +---------- every entry: safe path + recomputed SHA-256 ----------+
        |                                                                 |
  coordinator artifacts                                     validator receipt pairs
  ---------------------                                     -----------------------
  brief locks (taste-brief/v1)                 pixel      taste-pixels-receipt/v1
  candidates (taste-candidate/v1) ----+          |          input_sha256 -> capture manifest,
  capture manifests + screenshots     |          |          .output.capture_count cross-check
  mirrored groups (closed schema,     |        corpus     taste-corpus-receipt/v1
    identity-scan, A/B+B/A,           |          |          input_sha256 -> corpus manifest,
    distinct judges)                  |          |          .output.record_count cross-check
  sameness sidecars                   |       calibrate   taste-calibration/v1 (per judge,
  provenance escrow (judges +         |          |          >=17/24, Wilson>=.50, probes; genuine
    generation bound, hidden          |          |          producer output cloned in tests)
    from ballots)                     |        ballot     taste-ballot-validation/v1|v2
  reference packet + 3 directions     |          |          group_sha256 -> raw group; v1 or
  ballots.json (brief votes)          |          |          fixture_only!=false => FIXTURE_EVIDENCE
  threat manifest                     |        stats      polylane.taste.stats.v1
  repair ledger                       |          |          input_sha256 -> jq -cS canonical ballots
        |                             |          |          (incl. trailing newline, relay-resolved);
        |                             |          |          counts == recomputed brief wins
        v                             |       hard gate   taste-hard-gate/v1 (task/a11y/state/
  subject_revision ————— git: HEAD or ancestor,  |          specificity; capture_manifest_sha256 bound)
  goal_sha256, design_lock_sha256     |        review     taste-cross-brief-review/v2 (sidecar bound)
                                      |        repair     taste-repair-ledger/v2 (<=2, count==entries)
                                      |        threat     taste-threat-receipt/v1|v2 (clean, 4 axes)
                                      v
                          taste-certificate/v2 (atomic write, even on failure;
                          nonzero exit unless TASTE-CERTIFIED; sorted unique
                          verdict_reason_codes; evidence + validator chain digests)
```

Per the receipt-producers relay contract, producer receipts are validated by
required-field + hash-binding (subset) checks, so their hash-bound envelope keys
(`classification`, `validator{id,fingerprint}`, `executed_at`, `inputs`,
`subject`, `output`, …) pass through untouched. The manifest envelope and the
coordinator-owned ballot-group records stay closed-key. Cycle-39 producer
ballots are `taste-ballot-validation/v1` with `fixture_only:true` by hard
constraint: they validate structurally but always emit `FIXTURE_EVIDENCE`, so no
production certificate can be minted this cycle — hermetic v2 tests prove
closure logic, not the later real benchmark.

## Production floors and threshold cases

`TASTE-CERTIFIED` requires: >=10 varied briefs (unique id/category/task/lock
digest), >=5 eligible independent calibrated mirrored groups per brief, >=7
brief wins, group-level preference >=0.70 with 95% Wilson lower bound >0.50
(z=1.959964), zero task/accessibility/state/provenance regressions, clean threat
review, <=2 valid repairs, and a claim label at least as strong as
`required_claim`.

| Case (10 briefs x 5 groups) | wins/groups | preference | Wilson LCB | brief wins | Result |
|---|---|---|---|---|---|
| all won 5-0 | 50/50 | 1.00 | 0.92865240 | 10 | `TASTE-CERTIFIED` |
| 7 won 5-0, 3 lost 2-3 | 41/50 | 0.82 | 0.69203946 | 7 | `TASTE-CERTIFIED`, `briefs_lost` records the 3 losses, no fatal code |
| 6 won 5-0, 4 lost 2-3 | 38/50 | 0.76 | 0.62587316 | 6 | `BRIEF_WIN_FLOOR` only (floors pass — proves the win floor is independent) |
| 8 won 3-2, 2 lost 1-4 | 26/50 | 0.52 | 0.38511745 | 8 | `PREFERENCE_FLOOR` + `WILSON_FLOOR` (win floor passes) |

Claim ladder: all deciding judges human-calibrated machine =>
`HUMAN_CALIBRATED_MACHINE` (`human_calibrated:true`, `human_certified:false`);
`HUMAN_CERTIFIED` only when every deciding judge's eligibility receipt is
`kind:human`. `required_claim:HUMAN_CERTIFIED` over machine evidence fails with
`CLAIM_NOT_MET` — a stronger required claim is never silently weakened.

## Adversarial coverage (each blocked with the exact code, honest failure certificate, no partial temp files)

missing receipt (`RECEIPT_MISSING`) · forged shape-compatible receipt
contradicting its raw input (`RECEIPT_BINDING`) · tampered artifact
(`HASH_MISMATCH`) · fixture-only ballot receipt, fixture-relabelled manifest,
and c39 v1 producer ballots (`FIXTURE_EVIDENCE`, certificate `fixture_only:true`)
· stale capture revision with fully rebound downstream receipts
(`STALE_REVISION`) · subject unknown to the repo (`SUBJECT_REVISION_INVALID`) ·
undeclared source commit after subject (`UNDECLARED_POST_EVIDENCE_COMMIT`) ·
missing candidate id / caller status / caller winner (`MANIFEST_INVALID`) ·
same judge in one group and judge reuse across groups
(`JUDGE_NOT_INDEPENDENT`) · two aliases of one judge configuration deciding a
group (`JUDGE_ALIAS`) · uncalibrated deciding judge (`JUDGE_NOT_CALIBRATED`) ·
4 groups (`BALLOT_QUORUM`) · 9 briefs (`BRIEF_QUORUM`) · duplicate rendered
pixels (`DUPLICATE_RENDER`) · mirrored exposures disagreeing
(`SIDE_ORDER_CONTRADICTION`) · accessibility row failure (`ACCESSIBILITY_VETO`,
`accessibility_regressions:1`) · three repairs (`REPAIR_BUDGET`) · stats
receipt claiming more wins than the chain shows (`STATS_MISMATCH`) · numeric
field as string (`RECEIPT_SCHEMA`) · dirty threat review (`THREAT_GATE`) ·
machine evidence against a required human claim (`CLAIM_NOT_MET`).

Determinism: recompiling the same chain byte-compares equal (`jq -cS` identity
asserted in the test); `verdict_reason_codes` are unique and sorted.

## Skill evidence

SKILL-READ: data:statistical-analysis | /Users/leonardo/.codex/plugins/cache/claude-cowork/data/1.1.0/skills/statistical-analysis/SKILL.md | 2702170626-10434
SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
SKILL-READ: operations:risk-assessment | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md | 3889652016-1630
SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.claude/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md | 1657109997-9015

SKILL-EVIDENCE: superpowers:test-driven-development — helped: the rewritten test
was authored first and watched fail at the v1 fixture-marking assertion before
any compiler code changed; the relay-driven producer-schema change was likewise
test-first (fixtures updated, red at `CAPTURE_INVALID`, then compiler).
SKILL-EVIDENCE: data:statistical-analysis — helped: the threshold-case table was
designed from the Wilson interval mechanics (p>=0.70 at n>=50 already implies
LCB>0.50, so the Wilson-floor attack had to co-fire with the preference floor at
26/50 rather than pretend an unreachable isolated case exists); effect-size vs
significance framing shaped reporting both `preference_rate` and
`wilson_lower_bound` in the certificate.
SKILL-EVIDENCE: engineering:testing-strategy — helped: coverage was planned as
one positive hermetic chain per claim ladder plus exactly one adversarial
mutation per trust boundary (transport, binding, git ancestry, judges, floors,
vetoes, budget, claim), rather than per-function unit noise.
SKILL-EVIDENCE: operations:risk-assessment — helped: the trust boundaries were
enumerated as a risk register first (forged receipt, alias judges, threshold
gaming, fixture relabeling, undeclared commits), which is where the
rebind-cascade attacks (stale revision hidden behind rebound downstream
receipts) came from.

## DEFERRED

DEFERRED: hard-gate producer — the compiler consumes protocol-shaped
`taste-hard-gate/v1`; mapping from a11y-evidence `taste-a11y-receipt/v1` (and
task/state runners) into that aggregate is integrator-owned.
DEFERRED: review/repair receipt producers — `taste-cross-brief-review/v2` and
`taste-repair-ledger/v2` shapes are defined and enforced here (subset +
binding), but no lane emits them yet this cycle.
DEFERRED: optional `taste-capture-authorization/v1` binding offered by
capture-hardening is not yet consumed; promotion-time binding is a follow-up
once the runner gate wires production capture allowlists.
