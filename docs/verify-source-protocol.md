# Verification — lane source-protocol (run c41-source-calibration-20260812-a1)

Scope: reconcile the shipped Cycle-40 harness and frozen Cycle-41 acquisition
design with `docs/polylane/taste-certification/{RESEARCH,PROTOCOL}.md`, add
`SOURCE-AUDIT.md`, remove stale future-tense claims. No thresholds changed; no
certificate claimed; `human_certified` stays false everywhere.

## Commands run (2026-08-13, base 80efcce)

- `bash tests/test-taste-protocol-live.sh` → **80 pass, 0 fail** (was 69 pass
  pre-change; the growth is new named-bin checks from the shipped-as table).
  One intermediate RED: `named-bin:bin/polylane-taste-prompts.sh` — the shipped
  file exists but has no exec bit; doc now states that fact instead of implying
  an executable. Re-run GREEN.
- Stale-claim grep over the three owned taste-certification docs for
  `not in this tree|not yet merged|absent from this tree|Do not read the "live
  adapter" column`: remaining hits only describe **Cycle-41** lanes, which are
  genuinely not in this tree. All Cycle-40 stale future-tense claims removed.
- `git diff --check` → clean.
- Implementation-name checks against current files: every bin named in the
  updated docs exists (`ls -l`); `taste-ballot-validation/v2` is produced by
  `bin/polylane-taste-ballot-live.sh` (not the fixture validator);
  `bin/polylane-taste-source.sh` carries `taste-source-plan/v1`,
  `taste-source-acquisition/v1`, `taste-source-canary/v1`;
  `dataverse-acquire.mjs` confirms WAF detection → structured `UNKNOWN`,
  ephemeral temp `--user-data-dir`, fixed 1.5 s clearance sleep (the
  shipped-versus-frozen readiness-poll gap recorded in SOURCE-AUDIT §4), and
  atomic `.part` publication.

## Primary-source URL checks (read-only, 2026-08-13, bounded claims)

| URL | Verified claim |
|---|---|
| https://guides.dataverse.org/en/6.8/api/native-api.html | Documents dataset JSON, version listing, file listing, and metadata export endpoints. |
| https://guides.dataverse.org/en/4.9.4/api/dataaccess.html | Documents `/api/access/datafile/{id}` and bundled file downloads. |
| https://dataone-architecture-documentation.readthedocs.io/en/latest/design/PIDs.html | States a registered identifier always refers to the same sequence of bytes. |
| https://dataoneorg.github.io/api-documentation/services/piri_service.html | Documents the PIRI resolver (canonical IRIs, HTTP 302 redirects). |
| https://pmc.ncbi.nlm.nih.gov/articles/PMC10823051/ | Miniukovich–Figl homepage-evaluation dataset article: 1,033 + 1,064 + 1,059 = 3,156 homepages, ~3,319 raters, compliance filtering. |

## Recorded uncertainty (not asserted as fact)

- WAF vendor identity is not established: Cycle-40 notes say AWS WAF; the
  shipped detector also matches Akamai-style signals. Docs record the observed
  challenge behaviour only.
- Two of three DataONE metadata payloads (universities, banks) were not
  independently re-fetched; their PIDs are recorded identities with an open
  verification item (SOURCE-AUDIT §2).
- The dataset-envelope SHA-256 is an observation-time digest, not a dataset
  pin; per-file checksums are the binding rule.

## Observed repo facts for the integrator (not fixable from this lane)

- `bin/polylane-taste-prompts.sh` and `bin/polylane-taste-a11y-live.sh` are
  mode 644 (no exec bit); every other shipped taste bin is 755. Docs state
  this; a chmod is outside this lane's owned paths.

## Skill receipts

SKILL-READ: deep-research | /Users/leonardo/.agents/skills/deep-research/SKILL.md | 3883242303-4343
SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
SKILL-READ: operations:risk-assessment | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md | 3889652016-1630
SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/test-driven-development/SKILL.md | 1657109997-9015

SKILL-EVIDENCE: deep-research — helped: enforced source-identity discipline and the citation/uncertainty ledger pattern (URL checks with bounded per-source claims; explicit recorded-uncertainty section).
SKILL-EVIDENCE: engineering:testing-strategy — helped: scoped verification to the doc-contract layer (protocol/doc contract test + targeted stale-claim greps) instead of the full suite, per test cadence.
SKILL-EVIDENCE: operations:risk-assessment — helped: produced SOURCE-AUDIT §7's source-risk register (likelihood/impact/mitigation/status per risk).
SKILL-EVIDENCE: superpowers:test-driven-development — helped: RED first (stale-claim grep hits and the named-bin failure observed before edits), then doc changes, then GREEN re-run; adapted to docs where the pre-existing contract test is the failing-test harness.
