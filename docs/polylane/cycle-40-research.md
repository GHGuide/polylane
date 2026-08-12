# Cycle 40 research lock — live corpus and panel boundary

The primary source remains Miniukovich and Figl's released homepage-evaluation corpus:
3,156 full-page pages across commercial banking, e-commerce, and universities with raw
and filtered aggregate ratings from 3,319 sessions. Its paper documents the `[-3,3]`
rating scale, compliance filtering, within-participant standardization, and per-page
aggregation. The three Dataverse records declare CC0 1.0. Direct API calls currently
receive an AWS WAF `202`, but a real Chrome session completes the challenge; a same-context
API request then returned dataset id `6830013`, release version `4.0`, 1,074 files, and a
byte-exact download of `ratings.avg.fashion.txt`. Cycle 40 must productize that path as an
explicit browser adapter, not bypass or hide it.

The pinned TASTE release is useful as an orthogonal secondary audit because its parquet
contains 14,460 evaluator ranking rows over 644 images, five evaluators per group, and
dimensions including preference, typography, color harmony, and visual hierarchy. It is
not silently interchangeable with the protocol's primary three-domain corpus; each source
keeps its own provenance, scale, split, and receipt.

Research-backed controls retained for the live panel are: pointwise observation before
pairwise choice, hidden candidate/provider identity, mirrored side order across different
sessions, frozen human-label holdout, exact side-bias and contradiction screens, multiple
provider/model configurations, abstention on insufficient evidence, and a Wilson lower
bound. Machine sessions remain correlated diagnostics rather than proof of independent
humans. The strongest honest label available without recruited deciding people is
`HUMAN_CALIBRATED_MACHINE`.

Primary references:

- Miniukovich & Figl, dataset article and methods: https://pmc.ncbi.nlm.nih.gov/articles/PMC10823051/
- e-commerce release: https://doi.org/10.7910/DVN/9FKSQI
- university release: https://doi.org/10.7910/DVN/XOI0HI
- commercial-bank release: https://doi.org/10.7910/DVN/Z7KLIH
- TASTE release: https://huggingface.co/datasets/purvanshi/TASTE
