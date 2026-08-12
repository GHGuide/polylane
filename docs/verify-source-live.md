# Source-live verification — browser-backed Dataverse acquisition

Lane `source-live`, run `c40-live-harness-20260812-a3`.

`bin/polylane-taste-source.sh` turns a **pinned acquisition plan** and a
**caller-supplied, content-addressed cache** into the taste calibration corpus:
it joins raw ratings, aggregate ratings, and images, deterministically splits the
result, and emits a corpus manifest (consumable by `bin/polylane-taste-corpus.sh`)
plus a receipt that binds every provenance fact. The Bash core is hermetic and
never touches the network. The only networked component is the explicit external
adapter `benchmarks/taste-live/tools/dataverse-acquire.mjs`, reached solely
through the guarded `canary` command.

## Trust boundary

```
pinned plan.json ─┐
                  ├─► polylane-taste-source.sh (Bash 3.2, hermetic)
content cache  ───┘        │  verify-cache · join · split · receipt
                           ▼
                  manifest.json + receipt.json      (fixture / primary / secondary-audit)

                  canary ──► dataverse-acquire.mjs ──► warmed Chrome ──► Harvard Dataverse API
                  (guarded; real bytes or UNKNOWN — never a fixture PASS)
```

- **Bash never fetches.** A missing Chrome, network, or real bytes is `UNKNOWN`
  with `EXTERNAL-EVIDENCE-OPEN`, never a fixture fallback.
- **Cache paths are content-addressed and caller-supplied**:
  `<CACHE>/objects/<sha[0:2]>/<sha>`. The sha is hex-validated, so a path is never
  attacker-controlled (no separators, no traversal).
- **No caller-authored eligibility.** The plan may not carry booleans or any key
  named `eligible|certified|trusted|verified|approved`. Eligibility is *derived*
  from checkable evidence, never asserted.
- **No silent substitution.** A `secondary-audit` (TASTE) plan cannot be built as
  the primary corpus, and `build` refuses it.

## Commands

```bash
# Hermetic build (fixture or primary plan)
bin/polylane-taste-source.sh verify-cache CACHE_DIR PLAN.json
bin/polylane-taste-source.sh build        CACHE_DIR PLAN.json MANIFEST.json RECEIPT.json

# Separately labelled TASTE secondary audit
bin/polylane-taste-source.sh secondary    CACHE_DIR PLAN.json MANIFEST.json RECEIPT.json

# Guarded live one-file canary (real Chrome + network)
POLYLANE_SOURCE_LIVE=1 POLYLANE_SOURCE_CANARY_FILE=<datafile-id> \
  bin/polylane-taste-source.sh canary CACHE_DIR PLAN.json CANARY.json

# Focused test + ShellCheck (cached wrapper)
bash tests/test-taste-source-live.sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/source-live" -- \
  shellcheck -S warning bin/polylane-taste-source.sh tests/test-taste-source-live.sh
```

## Focused test output (fixture, hermetic)

```
PASS test-taste-source-live assertions=40
CHECK-CACHE: PASS source=400097702:467 ... shellcheck ... bin/polylane-taste-source.sh tests/test-taste-source-live.sh
```

The 40 assertions cover: a happy build; **the built manifest passing the frozen
`polylane-taste-corpus.sh validate`** (schema reuse); receipt provenance binding;
determinism (two builds byte-identical); the external adapter `--selftest`
(`SELFTEST-OK n=10`); and every rejection below.

## Contract example — receipt binding (fixture)

A `build` of a three-domain fixture (seed `c40-doc`, 1 calibration + 1 holdout per
domain) emits this receipt. Every HARD-CONTRACT fact is present and checkable:

```json
{
  "schema_version": "taste-source-acquisition/v1",
  "status": "BUILT",
  "classification": "fixture",
  "tool": { "id": "polylane-taste-source",
            "fingerprint": "77f58b109df7f640b6513f02c2df8bdf4da9206340cf86b2a6b5533e1527bb10" },
  "reproduction": "bin/polylane-taste-source.sh build CACHE plan.json manifest.json receipt.json",
  "split": { "seed": "c40-doc", "calibration_per_domain": 1, "holdout_per_domain": 1 },
  "raw_support": { "min": 5, "max": 5, "records": 6 },
  "sources": [ {
    "id": "doc-src",
    "dataset_pid": "doi:10.7910/DVN/9FKSQI", "dataset_version": "2.0",
    "spdx": "CC0-1.0",
    "license_url": "https://creativecommons.org/publicdomain/zero/1.0/legalcode",
    "license_sha256": "b3251314fd7d17daef787b384ff518aba74ccf5f9759902a8a043dbbc81859c2",
    "metadata_sha256": "d740e7687d1f187d78accd9cf83805d8ca7fa689bfd99c2fec07724a594195bf",
    "aggregate_sha256": "c949219ef9d9910f49105594b8780e748c95c228bf831978f3782feebafeebc7",
    "raw_sha256": "5212e80154137a51f4c9ea15a563425a08e392bc2c13ab6228144c3e7294ac72"
  } ],
  "manifest_sha256": "d67bee1aaaceca600e2cabed648c1c1b4893515353f42423136e1e30b7f769aa",
  "records": 6, "reason_codes": []
}
```

The manifest it produces carries `source_ref: "doi:10.7910/DVN/9FKSQI@2.0"`,
`source_sha256` = the pinned dataset-metadata hash, an allow-listed `license_receipt`,
and a balanced `calibration`/`holdout` split — accepted by
`polylane-taste-corpus.sh validate`.

## Negative cases (all fail closed)

| # | Injected fault | Rejected by |
|---|----------------|-------------|
| 1 | missing image mapping for a rated stimulus | image-join (`missing image`) |
| 2 | two stimuli share one image sha | manifest uniqueness (`duplicate-image`) |
| 3 | raw mean diverges > 0.5 from aggregate | `disagree:<id>` |
| 4 | fewer than five valid raw ratings | `raw-support:<id>` |
| 5 | tampered cached metadata (changed source metadata) | `verify_object` checksum |
| 6 | truncated / partial cache object | `verify_object` empty/checksum |
| 7 | path escape / non-hex sha (`../../etc/passwd`) | `obj_path` hex guard |
| 8 | symlinked cache object (content matches) | `verify_object` symlink guard |
| 9 | domain short of its quota | `wrong-domain-quota` |
| 10 | caller-authored eligibility (`"eligible": true`) | plan no-boolean / no-trust-key |
| 11 | `secondary-audit` plan built as primary | classification gate |
| 12 | `fixture` plan built via `secondary` | classification gate |
| 13 | live canary without the guard | `EXTERNAL-EVIDENCE-OPEN`, no receipt |

## Source / version / licence facts

Primary calibration source — the three CC0 Miniukovich–Figl Harvard Dataverse
releases (persistent IDs pinned; byte-level versions and file digests are frozen
**from the source API by a successful canary**, see below):

| Source id | Persistent ID | Declared licence |
|-----------|---------------|------------------|
| `DVN/9FKSQI` | `doi:10.7910/DVN/9FKSQI` | CC0-1.0 |
| `DVN/XOI0HI` | `doi:10.7910/DVN/XOI0HI` | CC0-1.0 |
| `DVN/Z7KLIH` | `doi:10.7910/DVN/Z7KLIH` | CC0-1.0 |

- Access host: `https://dataverse.harvard.edu` (dataset metadata via
  `/api/datasets/:persistentId/`, bytes via `/api/access/datafile/<id>`), fronted
  by an Akamai WAF that blocks bare API clients — hence the warmed-Chrome
  requirement.
- Licence receipt is an allow-listed SPDX id + URL + SHA-256; only
  `CC0-1.0 / CC-BY-4.0 / CC-BY-SA-4.0 / MIT / Apache-2.0` pass.
- **TASTE** at repository SHA `731a7f588d433214c6d864d2e9f47978d91aed6b` is a
  **separate secondary audit** (`classification: secondary-audit`) and cannot
  silently replace a failed primary corpus.

> Real per-file SHA-256 and Dataverse version numbers are **not fabricated here**.
> They are `EXTERNAL-EVIDENCE-OPEN` until a successful live canary records them
> from actual bytes (the current environment is WAF-blocked — see below).

## Live canary evidence (real, NOT a fixture)

A real warmed Chrome context was launched (headless, CDP over the Node `WebSocket`
global) and performed a **same-context** fetch of the real Harvard Dataverse
metadata API for `doi:10.7910/DVN/9FKSQI`. Verbatim adapter output:

```
$ node benchmarks/taste-live/tools/dataverse-acquire.mjs discover \
    --pid doi:10.7910/DVN/9FKSQI --cache <scratch>
{"status":"UNKNOWN","reason":"discover failed: WAF challenge (status 202)","waf":true,"pid":"doi:10.7910/DVN/9FKSQI"}
# node exit 3
```

This is genuine external evidence: Chrome reached the live endpoint and received
an HTTP **202** Akamai "under attack" interstitial rather than the JSON envelope.
The adapter classified it as a WAF challenge and **failed closed to `UNKNOWN`** —
no bytes were cached, no manifest was minted. Per the cycle-40 rule, a blocked
source yields a precise external-evidence receipt and **never** a fixture PASS.
Frozen version/file digests therefore remain `EXTERNAL-EVIDENCE-OPEN` for this
run; they are populated only by a canary that returns real 200-status bytes whose
SHA-256 matches the plan pin.

Everything under *Focused test output*, *Contract example*, and *Negative cases*
above is **fixture** evidence (synthetic assets with real checksums). The block in
this section is the **only** live, non-fixture evidence.

## Skill receipts

SKILL-READ: data:validate-data | /Users/leonardo/.codex/plugins/cache/claude-cowork/data/1.1.0/skills/validate-data/SKILL.md | 1311249913-14916

SKILL-READ: deep-research | /Users/leonardo/.agents/skills/deep-research/SKILL.md | 3883242303-4343

SKILL-READ: legal:compliance-check | /Users/leonardo/.codex/plugins/cache/claude-cowork/legal/1.3.0/skills/compliance-check/SKILL.md | 1175060322-14694

## Skill evidence

SKILL-EVIDENCE: data:validate-data — helped: its join/dedup/denominator/reasonableness catalog became fail-closed assertions — raw↔aggregate mean agreement (± 0.5), ≥ 5 valid raw ratings per stimulus, duplicate-image detection, and 1–5 rating-range sanity are all recomputed from source bytes, never trusted.

SKILL-EVIDENCE: deep-research — helped: its provenance-and-citation discipline shaped the receipt — pinned dataset pid/version, metadata/aggregate/raw SHA-256, licence receipt, and an exact reproduction command are all bound, and the live canary captures real source provenance (or a truthful UNKNOWN) rather than asserting acquisition.

SKILL-EVIDENCE: legal:compliance-check — helped: its use-boundary framing drove the licence gate — an allow-listed SPDX receipt with URL + SHA-256 is mandatory, and the TASTE secondary audit is labelled and quarantined so a CC0 primary corpus can never be silently substituted.
