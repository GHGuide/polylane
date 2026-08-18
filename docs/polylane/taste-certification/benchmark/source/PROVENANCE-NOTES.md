# Source provenance notes — c41-source-calibration-20260812-a1

All evidence in this directory derives from live public CC0 Harvard Dataverse
objects cached content-addressed at the operator cache root (never in Git),
cross-corroborated by live DataONE immutable-PID receipts. No credential,
cookie, or personal browser profile was used at any point.

## Acquired source objects (live, content-addressed)

| Object | Dataset | File id | SHA-256 |
|---|---|---|---|
| dataset envelope e-commerce | doi:10.7910/DVN/9FKSQI v4.0 | — | `17ef075975cd9173ccc82e8ae18b4533dcd7b62b35d39f00109c2ffb4c29f092` |
| dataset envelope universities | doi:10.7910/DVN/XOI0HI v4.0 | — | `14a57bc125a471f4ef58ad4333192b739ebebbb7ad4a522e6da00b5829806e64` |
| dataset envelope banks | doi:10.7910/DVN/Z7KLIH v4.0 | — | `c608ee19002b19f927691e6ba83ddf43dd63c9670ddf6b6e4ab97dfd8b420fa2` |
| ratings.raw.fashion.txt | 9FKSQI | 7219108 | `9c14d098c48ff45cec2dd91d5832a14f50ca589c7f00fab9163077c1bcfa557d` |
| ratings.raw.homeware.txt | 9FKSQI | 7219101 | `cfd69aac9b2797d9a54eac3f8760b1ed073ba2fc26a7974a3ef0adf2eb622842` |
| ratings.avg.fashion.txt | 9FKSQI | 7219104 | `ab02f666c26c7536eea6ab2c0961dffe0d8b006f9f1b7c9ef3f75584c0fef544` |
| ratings.avg.homeware.txt | 9FKSQI | 7219107 | `241557dd62ab634eea8c7e8b5ded3ac9dadf7ba061aabd0ff7a74bb43fc87911` |
| demographics.fashion.txt | 9FKSQI | 7265546 | `34f2bca2a789f0f9619f4a2938cf4e0c737e67289441e89980d436efedb6586c` |
| demographics.homeware.txt | 9FKSQI | 7265548 | `d81bf8b3f2cbddca31fcd92b1f386737dfd5c8721c0318a906b22696bc99da78` |
| ratings.raw.unis.txt | XOI0HI | 7219660 | `0c4405a608c674a7af0544b4d595b473574bb6dc3d07bfc2681f2f852712d15d` |
| ratings.avg.unis.txt | XOI0HI | 7219662 | `f49883a772ec82af3790d0bc32f9633abacc683c6d54f1cc09f48be93453c2db` |
| demographics.unis.txt | XOI0HI | 7265547 | `4bbe4bc7be7a374d30ea54b2bc1fc0d72a01bedf13120c0fae0a4a19e213c309` |
| ratings.raw.banks.txt | Z7KLIH | 7219666 | `a4201b2977052fe74841b874d68bf2ff4630a66d229ab2a5e2a57a69d4f8aeef` |
| ratings.avg.banks.txt | Z7KLIH | 7219665 | `56721f7b915faa61b6a78100a3f6da6bf44d4aabf02b94688f15722c2266a46a` |
| demographics.banks.txt | Z7KLIH | 7265549 | `9f7966c9e89dddfdc60bcb79e0eac1afbbbcdf480bbe275ec4946bd8c58ca78b` |

DataONE immutable metadata receipts (live, `urn:node:HD`, distribution counts
1074/1066/1040 matching the Harvard envelopes exactly) are cached under the
operator cache root at `receipts/dataone-*.json`.

## Reproduced source pipeline (verified bit-level against the release)

Per compliant session: average duplicate exposures per (stimulus, dimension,
training-flag); standardize over ALL those dup-means — training items included
in the basis — using the sample standard deviation; the published per-page
value is the mean of the non-training standardized values over compliant
(susCheat=FALSE) sessions. Verification coverage over every finite published
aggregate cell (including finite siblings of NA rows and training-only
stimuli):

| Subset | Finite cells | Verified | Mismatched | Max abs error |
|---|---|---|---|---|
| e-commerce/fashion | 3315 | 3315 | 0 | 0.000000 |
| e-commerce/homeware | 3063 | 3063 | 0 | 0.000000 |
| universities | 6354 | 6354 | 0 | 0.000000 |
| commercial banks | 6196 | 6196 | 0 | 0.004141 |

## Recorded release anomalies (never silently repaired)

1. `ratings.raw.banks.txt` contains one byte-identical repeated row
   (`b825.jpg` / US / session `23a15b0d7ceb876f`). Verbatim repeats collapse
   losslessly; distinct excess rows remain terminal.
2. `ratings.avg.banks.txt` repeats the `b428.jpg` row verbatim (lines
   429–430). Identical aggregate repeats collapse losslessly; conflicting
   repeats remain terminal.
3. Banks residuals: 72 AVG-dimension cells differ by up to 0.004141 from the
   dup-mean pipeline, consistent with the publisher having included one
   compliant duplicate exposure twice in that session's standardization
   basis. All residuals sit far inside the frozen 0.01 tolerance; recorded
   here as a publisher quirk, not repaired.

## Label scope

`label_dimension` is `AE` (visual aesthetics) throughout: the source's AVG
column is family resemblance, not an average. Any machine-judge claim built
on these labels is scoped to human-calibrated visual-aesthetic preference and
carries `human_certified:false` unconditionally.
