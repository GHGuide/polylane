# Cycle 41 research lock — primary corpus transport and calibration

Run: `c41-source-calibration-20260812-a1`

This cycle begins from the frozen Cycle 40 protocol. It may improve transport,
normalization, campaign execution, and verification, but it may not change the
primary datasets, split sizes, seed, judge thresholds, study briefs, builder model,
or final taste thresholds after seeing results.

## Newly verified source facts

Harvard Dataverse's documented dataset and data-file APIs are the canonical source
interfaces. Bare HTTP requests to all four documented metadata/export variants return
an empty HTTP 202 WAF response on this host. A fresh real Chrome context does eventually
clear that challenge: after a ten-second warm-up, the canonical dataset endpoint returned
669,754 bytes of JSON for dataset id `6830013`, release `4.0`, with SHA-256
`17ef075975cd9173ccc82e8ae18b4533dcd7b62b35d39f00109c2ffb4c29f092` at observation.
The production adapter must poll for readiness instead of assuming ten seconds is a
universal delay.

An in-page `fetch()` of a data file fails after Dataverse redirects to object storage,
because the redirected response is cross-origin. That is a transport limitation, not
missing data. The approved implementation directions are a same-browser CDP download or
a narrowly scoped handoff of the fresh ephemeral WAF session to a normal HTTP download.
No personal browser profile, user cookie, API key, or credential may be inspected,
persisted, logged, or copied. Challenge/CAPTCHA failure remains `UNKNOWN`.

DataONE independently indexes immutable metadata objects for all three Harvard releases:

| Domain | Harvard DOI | DataONE immutable metadata PID |
|---|---|---|
| e-commerce | `10.7910/DVN/9FKSQI` | `sha256:6ff2435a723445a99d8ef725da000115fc6d5716babaa776ea1604e30bb870e9` |
| universities | `10.7910/DVN/XOI0HI` | `sha256:71ee5e0dbf9e0b47bb95d6291ab337e02322907f20a996d028376e3065cf20f5` |
| commercial banks | `10.7910/DVN/Z7KLIH` | `sha256:6fe3377fec3aa24ce8c3b697791440c26400146381b7e5fc0ae7834daf0b78df` |

The e-commerce DataONE object resolves to a 236,669-byte science-on-schema JSON-LD
record naming the canonical DOI, CC0 licence, version `4`, and 1,074 distributions.
DataONE is a provenance/discovery mirror, not a silent source replacement: downloaded
data bytes must still bind the Harvard file id, canonical URL, declared size/checksum,
and a locally recomputed SHA-256. A mirror disagreement is `SOURCE-MISMATCH`, never a
majority vote between metadata sources.

## Frozen evidence and claim boundary

- Primary corpus: Miniukovich–Figl CC0 releases above; 3,156 homepage screenshots and
  human ratings across three domains.
- Split: 180 calibration and 72 held-out images, 60/24 per domain, from the frozen seed.
- Eligibility: 24 deterministic unambiguous mirrored pairs per judge; at least 17
  correct; Wilson lower bound at least 0.50; side-probe exact p at least 0.05; fewer
  than two mirror contradictions.
- TASTE remains a separately receipted secondary audit and cannot fill a primary quota.
- Machine judges can attain only `HUMAN_CALIBRATED_MACHINE` with
  `human_certified:false`. No software or model may emit `human_certified:true` without
  deciding ballots from recruited isolated humans.
- A transport failure, unavailable model, insufficient eligible panel, or incomplete
  source quota is `EXTERNAL-EVIDENCE-OPEN`/`UNKNOWN`; fixtures never enter production.

## Primary references

- Dataverse Native API: https://guides.dataverse.org/en/6.8/api/native-api.html
- Dataverse Data Access API: https://guides.dataverse.org/en/4.9.4/api/dataaccess.html
- DataONE immutable identifier semantics: https://dataone-architecture-documentation.readthedocs.io/en/latest/design/PIDs.html
- DataONE resolver: https://dataoneorg.github.io/api-documentation/services/piri_service.html
- Dataset article and collection method: https://pmc.ncbi.nlm.nih.gov/articles/PMC10823051/

