# Verify: source-freeze compiler

Lane: `source-freeze` (Cycle 41, `m32.4`). Deliverable:
`bin/polylane-taste-source-freeze.sh` — a hermetic, Bash-3.2-safe compiler
that reconciles canonical Harvard Dataverse receipts with immutable DataONE
receipts for exactly the three frozen Miniukovich–Figl DOIs and emits one
deterministic frozen acquisition plan. It never fetches; it consumes
caller-supplied receipt files only.

## Frozen source table

| Domain | Harvard DOI | DataONE immutable PID |
|---|---|---|
| `e-commerce` | `doi:10.7910/DVN/9FKSQI` | `sha256:6ff2435a723445a99d8ef725da000115fc6d5716babaa776ea1604e30bb870e9` |
| `universities` | `doi:10.7910/DVN/XOI0HI` | `sha256:71ee5e0dbf9e0b47bb95d6291ab337e02322907f20a996d028376e3065cf20f5` |
| `commercial-banks` | `doi:10.7910/DVN/Z7KLIH` | `sha256:6fe3377fec3aa24ce8c3b697791440c26400146381b7e5fc0ae7834daf0b78df` |

The table is hard-coded in the compiler. Receipts for any other DOI, PID, or
domain are rejected. Licence is frozen to `CC0-1.0` on both sides.

## Commands

```bash
bin/polylane-taste-source-freeze.sh compile HARVARD_DIR DATAONE_DIR OUT_PLAN.json
bin/polylane-taste-source-freeze.sh verify  HARVARD_DIR DATAONE_DIR PLAN.json
```

- `HARVARD_DIR/<domain>.json` — one `taste-harvard-receipt/v1` per domain,
  produced by the `dataverse-transport` lane from the observed canonical
  Dataverse dataset envelope.
- `DATAONE_DIR/<domain>.json` — one `taste-dataone-receipt/v1` per domain,
  produced by the `dataone-metadata` lane from the immutable DataONE object.
- `compile` refuses to overwrite an existing plan (a second compile onto the
  same path is treated as a post-freeze mutation attempt).
- `verify` recompiles from the receipts and requires the frozen plan to match
  byte for byte, and independently rechecks `freeze_sha256` against the plan
  body. Any drift in the plan or its inputs fails closed.

## Receipt contracts (strict keys, fail closed)

`taste-harvard-receipt/v1` (canonical byte/label authority):

```json
{
  "receipt_version": "taste-harvard-receipt/v1",
  "doi": "doi:10.7910/DVN/9FKSQI",
  "domain": "e-commerce",
  "dataset_version": "4.0",
  "endpoint": "https://dataverse.harvard.edu/api/datasets/...",
  "metadata_sha256": "<64 hex — sha256 of the observed dataset JSON envelope>",
  "license": {"spdx": "CC0-1.0", "url": "https://...", "sha256": "<64 hex>"},
  "files": [
    {"file_id": "…", "name": "…", "role": "raw|aggregate|image",
     "sha256": "<64 hex>", "size": 1234}
  ]
}
```

`taste-dataone-receipt/v1` (independent provenance mirror):

```json
{
  "receipt_version": "taste-dataone-receipt/v1",
  "pid": "sha256:<64 hex — must equal the frozen PID>",
  "doi": "doi:10.7910/DVN/9FKSQI",
  "domain": "e-commerce",
  "dataset_version": "4",
  "member_node": "urn:node:…",
  "license": {"spdx": "CC0-1.0", "url": "https://..."},
  "distributions": [
    {"file_id": "…", "name": "…", "sha256": "<64 hex>", "size": 1234}
  ]
}
```

Reconciliation requires, per domain:

- DOI equals the frozen DOI on both sides; DataONE PID equals the frozen PID.
- Domain labels match the frozen domain on both sides.
- Licence is exactly `CC0-1.0` on both sides.
- Dataset versions agree after normalization (a single trailing `.0` is
  dropped, so Harvard `4.0` matches DataONE `4`; `3` versus `4.0` is drift).
- File identity agrees exactly: the sorted `{file_id, name, sha256, size}`
  projection of Harvard `files` must equal the sorted DataONE `distributions`.
  A missing, extra, renamed, resized, or re-hashed file is `SOURCE-MISMATCH`
  — never a majority vote. DataONE augments availability; it cannot redefine
  Harvard's bytes or labels.
- File ids and names are unique within each receipt.
- Exactly one `raw` and one `aggregate` ratings file and at least one `image`
  per domain (the selected acquisition inputs).
- No caller-authored trust bits anywhere: any boolean, or any key named
  `eligible|certified|trusted|verified|approved` (case-insensitive), rejects
  the receipt. Eligibility is computed downstream, never asserted by inputs.
- Receipts must be regular files (no symlinks) with valid JSON.

## Plan output

`taste-source-freeze-plan/v1`, canonical serialization (`jq -S`, sources
sorted by domain, images sorted by `file_id`), so identical receipts always
produce byte-identical plans. Each source records the frozen identity
(`domain`, `doi`, `dataone_pid`, normalized `dataset_version`, `license`),
the provenance hashes (`harvard_metadata_sha256`, `harvard_endpoint`,
`dataone_member_node`), and the selected acquisition inputs
(`acquisition.raw`, `acquisition.aggregate`, `acquisition.images[]`, each
with `file_id`, `name`, `sha256`, `size`). `freeze_sha256` is the SHA-256 of
the `jq -cS` body without that field.

Failures print `SOURCE-FREEZE-INVALID: …` (mismatches additionally say
`SOURCE-MISMATCH`) and exit 1; a failed compile never leaves a partial plan.

## Verification

```bash
bash tests/test-taste-source-freeze.sh
shellcheck -S warning bin/polylane-taste-source-freeze.sh
```

The test is hermetic (fixture receipts only, no network) and covers: happy
path, canonical/deterministic recompile, replay via `verify`, post-freeze
mutation of plan and inputs, overwrite refusal, missing domains on either
side, DOI/PID/domain/licence/version/file-identity disagreements, duplicate
file ids and names, trust-bit rejection, strict-key and shape violations,
role quotas, broken JSON, and symlinked receipts.

## Known ceilings and risks

- The frozen table is intentionally hard-coded; changing datasets requires a
  new protocol freeze, not a flag (fail-closed by design).
- Version normalization only drops one trailing `.0`. If Harvard ever reports
  `4.0.0`-style versions the compiler fails closed rather than guessing.
- Sibling lanes own receipt production; if their emitted field names differ,
  the integrator reconciles the seam against this contract (receipts are the
  interface, and this file is the authoritative schema for this lane).
- Real-corpus quota (180+72 images) is enforced downstream by
  `corpus-select`/`benchmark-preflight`; this compiler enforces identity
  agreement and the one-raw/one-aggregate/some-images acquisition shape.
