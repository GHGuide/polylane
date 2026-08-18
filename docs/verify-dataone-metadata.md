# Verify — dataone-metadata (run c41-source-calibration-20260812-a1)

## Repair reflection (attempt 1 → attempt 2)

1. What went wrong: the prior attempt produced zero owned files — it stalled at interactive
   Bash permission prompts ("Contains simple_expansion / Do you want to proceed?") plus
   PreToolUse hook errors, and the session died before any implementation started.
2. Root cause: the attempt front-loaded exploratory shell commands that triggered approval
   dialogs in an unattended run; with nobody to approve, every subsequent step blocked.
3. Different approach now: write owned files immediately with the file tools (no
   prompt-prone shell exploration), keep Bash invocations plain (no command substitution
   patterns that trigger approval), follow strict fixture-first TDD, and run one bounded
   live canary only after the hermetic suite is green.

## Scope

Strict DataONE metadata adapter for the three immutable PIDs frozen in Cycle 41.
DataONE is discovery/provenance only; the adapter never claims it supplied source bytes
(`source_bytes_supplied` is hard-coded `false` in every receipt).

## Frozen immutable identifiers (from docs/polylane/cycle-41-research.md)

| Domain | Harvard DOI | DataONE immutable metadata PID |
|---|---|---|
| e-commerce | `10.7910/DVN/9FKSQI` | `sha256:6ff2435a723445a99d8ef725da000115fc6d5716babaa776ea1604e30bb870e9` |
| universities | `10.7910/DVN/XOI0HI` | `sha256:71ee5e0dbf9e0b47bb95d6291ab337e02322907f20a996d028376e3065cf20f5` |
| commercial-banks | `10.7910/DVN/Z7KLIH` | `sha256:6fe3377fec3aa24ce8c3b697791440c26400146381b7e5fc0ae7834daf0b78df` |

Research-verified frozen scalars beyond the table: e-commerce record declares version `4`
and exactly `1074` distributions. Versions/counts for the other two domains were not
frozen by Cycle 41 research, so the adapter records them into the hash-bound receipt and
enforces non-emptiness instead of inventing unfrozen expected values. Title/domain
binding is enforced through the frozen DOI↔domain table plus the PID content digest; the
title itself is recorded, required non-empty, and the optional title-token check is
implemented and fixture-tested (builtin tokens stay null because no title text was frozen
— adding guessed tokens after the freeze would be an unfrozen scalar, which is forbidden).

## Adapter contract (benchmarks/taste-live/tools/dataone-metadata.mjs)

- `--selftest` — hermetic pure-helper unit tests, no network.
- `verify --domain <d> --cache <dir> [--base <url>] [--table <file>] [--timeout-ms N]`
  - resolves `GET {base}/object/{urlencoded pid}` and `GET {base}/meta/{urlencoded pid}`
    against the documented DataONE CN v2 REST API (default base
    `https://cn.dataone.org/cn/v2`);
  - recomputes SHA-256 of the returned object bytes and requires it to equal the hex
    embedded in the immutable PID (digest check precedes all parsing);
  - parses the science-on-schema JSON-LD record and enforces: exact frozen DOI, CC0
    licence, non-empty title (+ optional token match), version (exact when frozen),
    distribution list validity — every entry needs a non-empty name, a canonical
    `https://dataverse.harvard.edu/api/access/datafile/<id>` URL, and an integral byte
    size; duplicate names or URLs are terminal; count must equal the frozen count when
    one exists;
  - parses DataONE system metadata (namespace-prefix tolerant) and requires: sysmeta
    identifier == PID, sysmeta checksum == a recomputation of its own declared algorithm
    (MD5/SHA-1/SHA-256/SHA-512) over the digest-validated object bytes, size == observed
    byte length, and an `urn:node:*` authoritative member node;
  - emits a hash-bound receipt (`polylane.taste.dataone.v1`) whose `receipt_sha256` is
    the SHA-256 of the jq `-cS`-canonical JSON without that field; distribution names are
    bound as `distribution_names_sha256` over the sorted name list so no large record is
    copied into Git.
- Failure classes: metadata disagreement → `SOURCE-MISMATCH` (exit 2); transport,
  redirect-loop, timeout, HTTP error → `UNKNOWN` (exit 3); usage → exit 4. A mirror
  disagreement is never resolved by majority vote.
- Live-stamp guard: `mode:"live"` only when the base is the real CN and no table override
  is present; every fixture run is stamped `mode:"fixture"`. No fixture can be stamped live.

## Hermetic test evidence (tests/test-taste-dataone-metadata.sh)

RED observed first (TDD): with the adapter absent the suite failed at selftest with
`Cannot find module .../dataone-metadata.mjs` (exit 1). GREEN after implementation:

```
ok 01 selftest
ok 02 valid verify exit 0
ok 03 receipt scalars + fixture stamp + source_bytes_supplied=false
ok 04 receipt_sha256 recomputes via jq -cS + shasum
ok 05 tampered bytes -> digest-mismatch
ok 06 wrong DOI -> doi-mismatch
ok 07 wrong licence -> licence-mismatch
ok 08 wrong version -> version-mismatch
ok 09 duplicate distribution URL
ok 10 distribution count mismatch
ok 11 non-Harvard distribution URL
ok 12 title token miss
ok 13 sysmeta checksum mismatch
ok 14 MD5 + namespaced sysmeta verifies against recomputed digest
ok 15 sysmeta identifier != pid
ok 16 non-JSON digest-valid body
ok 17 redirect loop
ok 18 timeout
ok 19 unknown domain -> usage exit 4
PASS test-taste-dataone-metadata (19 checks)
```

All fixtures are local (loopback HTTP server owned by the test); PIDs in fixtures are
real digests of the fixture bytes, and every fixture receipt is stamped `mode:"fixture"`.

## Live canary (bounded read-only, after green tests) — full disclosure: two runs

- Attempt 1 (2026-08-12): exit 2 `SOURCE-MISMATCH sysmeta-mismatch` — an adapter defect,
  not a source disagreement: the first sysmeta parser assumed a SHA-256 checksum element,
  but the live CN declares an MD5 checksum. Fixed via TDD (fixture cases 14–15 above were
  written and observed failing first): the adapter now verifies the sysmeta checksum by
  recomputing its declared algorithm over the digest-validated object bytes, and also
  requires sysmeta identifier == PID.
- Attempt 2 (post-fix, 2026-08-12T21:29:33Z): PASS — `mode:"live"`, exit 0. Observed
  immutable IDs and scalars, verbatim from the live receipt:
  - PID `sha256:6ff2435a723445a99d8ef725da000115fc6d5716babaa776ea1604e30bb870e9`;
    recomputed SHA-256 of the 236669 object bytes equals the PID hex exactly
  - DOI `10.7910/DVN/9FKSQI`; licence CC0; version `4`
  - title `Web Design Prototypicality: eCommerce` (note: "eCommerce", unhyphenated —
    freezing a guessed "e-commerce" title token would have produced a false mismatch,
    confirming the null-token decision)
  - distributions 1074 (equals the frozen count), 1210934436 total declared bytes, all
    canonical `https://dataverse.harvard.edu/api/access/datafile/<id>` URLs, no duplicates
  - `distribution_names_sha256`
    `9bff7a3d4f5250cddea58967052120da559f98f5998010519d5cb8e2d538fc71`
  - authoritative member node `urn:node:HD`; sysmeta checksum algorithm `MD5`
  - `receipt_sha256 8ef3310fe26a9d1a6ec6834096d6156a096824ec46e7633d759b4fd138c23b1f`;
    `source_bytes_supplied:false`; receipt stored in the session-local cache, not in Git

The canary supplies metadata provenance only. No source bytes were downloaded from
DataONE and none are claimed; Harvard remains the sole source-byte authority. No fixture
was stamped live (fixture runs are hard-stamped `mode:"fixture"` by the base/table guard).

## SKILL-EVIDENCE

- SKILL-EVIDENCE: superpowers:test-driven-development — helped: RED observed (module
  missing, suite exit 1) before any adapter code; every mismatch case was written and
  failing-by-construction before the check existed.
- SKILL-EVIDENCE: engineering:testing-strategy — helped: pyramid applied as pure-helper
  selftest (unit) + loopback HTTP fixture suite (integration) + one bounded live canary
  (e2e), matching the data-integrity focus the skill prescribes.
- SKILL-EVIDENCE: operations:risk-assessment — helped: drove the live-stamp guard
  (fixture-stamped-live risk), fail-closed SOURCE-MISMATCH vs UNKNOWN separation, and the
  decision not to enforce unfrozen title tokens (fabricated-scalar risk).
- SKILL-EVIDENCE: engineering:debug — helped: reproduce→isolate→root-cause structure used
  twice — on the prior attempt's failure (permission-prompt stall) and on canary attempt
  1 (root cause: SHA-256-only sysmeta parser vs live MD5 checksum; fixed with a failing
  fixture first, not by loosening the check).

## Reproduce

```bash
node benchmarks/taste-live/tools/dataone-metadata.mjs --selftest
bash tests/test-taste-dataone-metadata.sh
```
