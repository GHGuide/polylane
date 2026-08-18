# Primary-source audit — canonical bytes, mirrors, and transport facts

Run: `c41-source-calibration-20260812-a1`
Lane: `source-protocol`

This audit fixes the source-identity boundary for the primary taste-calibration
corpus. It records what was actually observed on the acquisition path, separates
the canonical byte source from its metadata mirror, and freezes the substitution
and claim rules that no later result may relax. It asserts no certificate, no
completed corpus acquisition, and no human certification.

## 1. Canonical source identity — Harvard Dataverse bytes

The only canonical corpus bytes are Harvard Dataverse data-file bytes for the
three Miniukovich–Figl CC0 releases:

| Domain | Harvard DOI |
|---|---|
| commercial banks | `10.7910/DVN/Z7KLIH` |
| e-commerce | `10.7910/DVN/9FKSQI` |
| universities | `10.7910/DVN/XOI0HI` |

A downloaded object is admissible only when it binds, together: the Harvard
file id, the canonical Dataverse URL, the declared size and checksum from the
dataset metadata, and a locally recomputed SHA-256 over the received bytes.
The dataset-metadata JSON envelope itself may contain volatile fields; its
digest dates an observation and never substitutes for per-file checksums.

Observed binding (recorded 2026-08-12 by the Cycle-41 research lane): a cleared
Chrome session returned the canonical dataset envelope for dataset id `6830013`,
release `4.0`, 669,754 bytes, SHA-256
`17ef075975cd9173ccc82e8ae18b4533dcd7b62b35d39f00109c2ffb4c29f092` at
observation, listing 1,074 files. Cycle 40 additionally recorded one byte-exact
canary file download (`ratings.avg.fashion.txt`) in a cleared same-context
session.

## 2. DataONE — immutable metadata mirror, never a byte substitute

DataONE independently indexes immutable metadata objects for all three
releases. Per DataONE identifier semantics, a registered identifier always
refers to the same sequence of bytes, which is what makes these useful as
tamper-evident provenance anchors:

| Domain | DataONE immutable metadata PID |
|---|---|
| e-commerce | `sha256:6ff2435a723445a99d8ef725da000115fc6d5716babaa776ea1604e30bb870e9` |
| universities | `sha256:71ee5e0dbf9e0b47bb95d6291ab337e02322907f20a996d028376e3065cf20f5` |
| commercial banks | `sha256:6fe3377fec3aa24ce8c3b697791440c26400146381b7e5fc0ae7834daf0b78df` |

The e-commerce object was observed (2026-08-12) as a 236,669-byte
science-on-schema JSON-LD record naming the canonical DOI, the CC0 licence,
version `4`, and 1,074 distributions. The other two PIDs are recorded
identities; their payloads were not independently re-fetched by this lane, and
that gap stays an open verification item rather than an assumed fact.

Role boundary: DataONE is a provenance/discovery mirror. It may corroborate
Harvard metadata and improve availability; it can never redefine Harvard's
bytes, labels, licence, or file identities. Any disagreement between Harvard
and DataONE metadata is `SOURCE-MISMATCH` and terminal for the affected
manifest — there is no majority vote among metadata sources.

## 3. Observed transport facts — WAF, readiness, redirect

Recorded observations (2026-08-12, single observing host; these are dated
facts, not guarantees of future behaviour):

- Bare HTTP requests to all four documented Dataverse metadata/export variants
  returned an empty HTTP `202` WAF challenge. Cycle-40 notes attribute the
  challenge to AWS WAF; the shipped detector also treats Akamai-style signals
  (`AkamaiGHost` server header, 403/406/429/503, challenge bodies) as blocks.
  The load-bearing fact is the challenge behaviour, not the vendor identity,
  which this audit does not claim to have established.
- A fresh headless Chrome context with an ephemeral temporary profile cleared
  the challenge; the canonical dataset endpoint then answered (observed after a
  ten-second warm-up). Readiness is a poll-for-valid-JSON-envelope condition,
  not a universal fixed delay — see §4 for the shipped-versus-frozen gap.
- An in-page `fetch()` of a data file fails after Dataverse redirects to object
  storage, because the redirected response is cross-origin. This is a transport
  limitation, not missing data. Approved directions: a same-browser CDP
  download, or a narrowly scoped handoff of the fresh ephemeral WAF session to
  a normal HTTP download.
- Forbidden under every direction: inspecting, persisting, logging, or copying
  any personal browser profile, user cookie, API key, or credential. A
  challenge/CAPTCHA that does not clear is `UNKNOWN`, never a bypass target.
- The Cycle-40 unattended run's source canary itself received a WAF `202`, so
  no real 180+72 corpus was acquired then; that run closed
  `EXTERNAL-EVIDENCE-OPEN`, which remains the honest state of corpus
  acquisition at this writing.

## 4. Shipped implementation versus frozen Cycle-41 design

Shipped in this tree (Cycle 40): `bin/polylane-taste-source.sh` — a hermetic
Bash core (`verify-cache`, `build`, `secondary`, `canary`) that never fetches,
verifies a content-addressed cache (hex-validated object names, symlink/
partial/checksum rejection), and emits `taste-source-plan/v1`-validated
receipts (`taste-source-receipt/v1`, `taste-source-acquisition/v1`,
`taste-source-canary/v1`). The only network path is the explicit external
adapter `benchmarks/taste-live/tools/dataverse-acquire.mjs`: headless Chrome
with an ephemeral temp `--user-data-dir`, WAF detection returning a structured
`UNKNOWN` receipt, same-context fetch so clearance cookies apply, and atomic
`.part`-then-rename publication.

Known shipped-versus-frozen gaps (Cycle-41 lanes, not in this tree; recorded
so the docs do not overstate the shipped adapter):

- The shipped adapter waits a fixed 1.5-second clearance interval before its
  same-context request; the frozen Cycle-41 contract requires polling for an
  observed valid Dataverse JSON envelope instead of any fixed sleep
  (`dataverse-transport` lane).
- The shipped adapter has no CDP/session-handoff path for object-storage
  redirected data files (`dataverse-transport` lane).
- DataONE discovery/resolve receipts, the reconciled fail-closed frozen source
  manifest, the resumable download campaign, and the calibration campaign are
  frozen Cycle-41 designs (`dataone-metadata`, `source-freeze`,
  `download-campaign`, `calibration-campaign` and sibling lanes), not shipped
  code here.

## 5. Frozen substitution rules

1. Canonical bytes are Harvard Dataverse data-file bytes only, admitted under
   the four-way binding in §1.
2. DataONE corroborates; it never substitutes. Metadata disagreement is
   `SOURCE-MISMATCH`, terminal, with no majority vote.
3. Fixture bytes never stand in for a blocked download. A blocked or failed
   acquisition yields a precise receipt and `EXTERNAL-EVIDENCE-OPEN`/`UNKNOWN`.
4. TASTE (Hugging Face `purvanshi/TASTE`, pinned repository SHA
   `731a7f588d433214c6d864d2e9f47978d91aed6b`) is a separately receipted
   secondary audit and never fills any primary-corpus quota.
5. A source substitution of any kind is a new manifest version, never a repair
   of an existing result; a failed item is never silently replaced after
   results exist.
6. Selection precedes judge output; calibration and holdout stay disjoint by
   object digest and source id.

## 6. Frozen claim rules

- All preregistered thresholds stand unchanged: 180 calibration + 72 held-out
  images, 60/24 per domain from the frozen seed; judge eligibility 24
  deterministic mirrored pairs, at least 17 correct, Wilson lower bound at
  least 0.50, side-probe exact `p >= 0.05`, fewer than two mirror
  contradictions; study target 20 briefs with hard floor 10, at least 7 brief
  wins, pooled preference at least 0.70 with 95% Wilson lower bound strictly
  above 0.50; zero accessibility regressions; at most two targeted repairs.
- The strongest label any machine panel may attain is
  `HUMAN_CALIBRATED_MACHINE`; the `human_certified` field stays false
  throughout this cycle, and no software or model may emit a human-certified
  claim without deciding ballots from recruited isolated humans.
- No taste certificate exists at this writing. A transport failure, unavailable
  model, insufficient eligible panel, or incomplete source quota is
  `EXTERNAL-EVIDENCE-OPEN`/`UNKNOWN`, never a lowered gate.

## 7. Source-risk register

| Risk | Likelihood | Impact | Mitigation | Status |
|---|---|---|---|---|
| Mirror substitution or metadata drift between Harvard and DataONE | Low | High | Four-way byte binding; `SOURCE-MISMATCH` terminal; no majority vote | Mitigated by rule; enforcement lives in `source-freeze` (Cycle 41) |
| WAF policy change re-blocks acquisition | Medium | High | Structured `UNKNOWN` receipts; readiness polling; no bypass or spoofing; honest `EXTERNAL-EVIDENCE-OPEN` close | Accepted (external) |
| Envelope volatility mistaken for tamper evidence | Medium | Medium | Bind per-file checksums, not envelope digests; envelope digest dates observations only | Mitigated in this audit's rules |
| Credential or profile leakage via browser transport | Low | High | Ephemeral temp profile; forbidden inspection/persistence/logging of user state | Mitigated in shipped adapter; re-audited per change |
| Post-result threshold or substitution drift | Low | High | Preregistration in PROTOCOL/RESEARCH; doc-contract test; new-manifest-version rule | Mitigated |

## 8. Primary documentation (verified reachable 2026-08-13)

- Dataverse Native API (dataset JSON, versions, file listing, export):
  https://guides.dataverse.org/en/6.8/api/native-api.html
- Dataverse Data Access API (`/api/access/datafile/{id}`, bundled downloads):
  https://guides.dataverse.org/en/4.9.4/api/dataaccess.html
- DataONE identifier semantics (an identifier always refers to the same
  sequence of bytes):
  https://dataone-architecture-documentation.readthedocs.io/en/latest/design/PIDs.html
- DataONE resolution (PIRI) service:
  https://dataoneorg.github.io/api-documentation/services/piri_service.html
- Dataset article and collection method (3,156 homepages: 1,033 banking,
  1,064 shopping, 1,059 university; ~3,319 raters; compliance filtering):
  https://pmc.ncbi.nlm.nih.gov/articles/PMC10823051/
- Harvard Dataverse releases: https://doi.org/10.7910/DVN/Z7KLIH ;
  https://doi.org/10.7910/DVN/9FKSQI ; https://doi.org/10.7910/DVN/XOI0HI

Version-pinned guide URLs are the cited identities; newer guide versions
document the same APIs but are not silently swapped into citations.
