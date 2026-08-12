# Source/calibration operator runbook — m32.4

Run family: `c41-source-calibration-*`. Audience: a stranger reproducing the
source acquisition and judge-calibration campaign on a fresh machine.

This runbook never promises success. Every phase can end honestly in
`UNKNOWN` or `EXTERNAL-EVIDENCE-OPEN`; that is a valid, publishable outcome.
Nothing here instructs you to copy, export, or reuse any credential, cookie,
or personal browser profile — doing so is forbidden by the frozen protocol
(`docs/polylane/taste-certification/PROTOCOL.md`).

## 1. What exists vs. what is planned

Every command below is labeled. Validate labels against your checkout before
trusting them (`docs/verify-source-runbook.md` shows how).

| Label | Meaning |
|---|---|
| REAL | Script/test exists in this tree at this document's commit and its usage line was exercised. |
| PLANNED | Owned by a sibling Cycle-41 lane (`docs/polylane/cycle-41-plan.md` lane carve); not in this tree until the integrator merges it. Do not report a PLANNED step as executed. |
| EXTERNAL | Lives outside this repo entirely (Harvard Dataverse, DataONE, model providers, Chrome, the network). |

REAL in this tree now:

- `bin/polylane-taste-source.sh` — `verify-cache` / `build` / `secondary` / `canary`
- `benchmarks/taste-live/tools/dataverse-acquire.mjs` — `--selftest` / `discover` / `fetch`
- `bin/polylane-taste-judge-run.sh` — `run <manifest> <run-dir>`
- `bin/polylane-taste-judge-parse.sh`, `bin/polylane-taste-calibration-live.sh`,
  `bin/polylane-taste-calibrate.sh` (v1, fixture-grade), `bin/polylane-taste-corpus.sh`
- Tests: `tests/test-taste-source-live.sh`, `tests/test-taste-judge-run.sh`,
  `tests/test-taste-calibration-live.sh`, `tests/test-taste-calibrate.sh`

PLANNED (sibling lanes; names from the cycle-41 plan): DataONE metadata
adapter, frozen source-manifest freezer, resumable multi-file download
campaign, cache-integrity/quarantine reporter, ratings normalizer,
corpus selector, pair builder, calibration-campaign driver,
independent calibration audit, panel freeze, benchmark preflight
(`bin`/`tests` names ending in `-dataone-metadata`, `-source-freeze`,
`-download-campaign`, `-cache-integrity`, `-ratings-normalize`,
`-corpus-select`, `-pair-builder`, `-calibration-campaign`,
`-calibration-audit`, `-panel-freeze`, `-benchmark-preflight`).
Where a PLANNED step is required, this runbook shows the frozen contract it
must satisfy so you can recognize the real thing when it lands.

## 2. Prerequisites

- macOS or Linux with Bash ≥ 3.2 (scripts are Bash-3.2 safe), `git`, `awk`.
- `jq` ≥ 1.6.
- SHA-256 tool: `shasum` or `sha256sum` on PATH.
- Node ≥ 22 (adapter needs the global `fetch` and `WebSocket`). Check: `node --version`.
- Google Chrome or Chromium. If not auto-found, set `CHROME_BIN=/path/to/chrome`.
- `tmux` (observation only; any version).
- Network egress to `dataverse.harvard.edu` (EXTERNAL; may be WAF-challenged at any time).
- Model provider access for the judge campaign (EXTERNAL; provider adapters are declared inside sealed work-unit manifests, never installed silently).
- Disk: see §4 before downloading.

Sanity check (REAL, hermetic, no network):

```bash
node benchmarks/taste-live/tools/dataverse-acquire.mjs --selftest
bash tests/test-taste-source-live.sh
```

## 3. Exact cache boundary

Binary source assets never enter Git. They live in one operator-chosen
content-addressed cache directory, referred to as `CACHE_DIR` below.
Recommended location: outside the repo, e.g. `~/.cache/polylane-taste-source`.

Exact layout (enforced by both the Bash core and the Node adapter):

```
CACHE_DIR/objects/<first-2-hex-of-sha256>/<full-64-hex-sha256>
```

- Object name IS its SHA-256; the hex is validated, so no path separator or
  traversal segment can appear. Symlinks, empty files, and checksum
  mismatches are rejected by `verify-cache`.
- In-flight writes use `<path>.part` then an atomic rename. A crash leaves
  only `.part` litter, never a partial object at a final path.
- Inside Git go ONLY: plans, manifests, receipts, raw textual model
  responses, and audit evidence (compact JSON/text). If a file in the repo
  looks like image bytes, that is a defect, not a convenience.

## 4. Disk estimate method

Estimate before downloading; do not discover the bill by filling the disk.

1. Run `discover` (§5.1) for each of the three dataset DOIs.
2. Sum declared file sizes from the cached dataset metadata JSON. For a
   Dataverse native-API envelope the sizes are at
   `.data.latestVersion.files[].dataFile.filesize` — verify the path against
   the actual envelope you cached, releases differ:

```bash
jq '[.data.latestVersion.files[].dataFile.filesize] | add' "$CACHE_DIR/objects/<aa>/<metadata-sha>"
```

3. Only 252 selected images (180 calibration + 72 holdout, 60/24 per domain)
   plus per-source metadata/aggregate/raw objects are required — sum only the
   selected file ids once the frozen selection exists; the full corpus is
   ~3,156 screenshots and is NOT required.
4. Multiply by 2 for `.part` staging and quarantine headroom, and check
   `df -h` on the cache filesystem.

## 5. Phase commands

Conventions: `PLAN.json` is a `taste-source-plan/v1` document (pinned DOIs,
versions, SPDX licences, per-object sha256s, three domains, split seed —
schema enforced fail-closed by `validate_plan` in `bin/polylane-taste-source.sh`;
plans carry no self-declared eligibility). Frozen study constants
(`docs/polylane/cycle-41-research.md`) may not change after results:

| Constant | Frozen value |
|---|---|
| Domains / DOIs | e-commerce `10.7910/DVN/9FKSQI`, universities `10.7910/DVN/XOI0HI`, commercial banks `10.7910/DVN/Z7KLIH` (CC0) |
| Split | 180 calibration + 72 holdout, 60/24 per domain, deterministic from frozen seed |
| Judge eligibility | 24 unambiguous mirrored pairs; ≥ 17 correct; Wilson LCB ≥ 0.50; side-probe exact p ≥ 0.05; < 2 mirror contradictions |

### 5.1 Discover (REAL, EXTERNAL network)

```bash
node benchmarks/taste-live/tools/dataverse-acquire.mjs discover \
  --pid doi:10.7910/DVN/9FKSQI --cache "$CACHE_DIR"
```

Warms a fresh ephemeral headless Chrome context (WAF clearance), fetches the
dataset JSON, stores it content-addressed, prints `{status:"OK", sha256, bytes}`.
Any WAF challenge / missing Chrome / timeout prints a structured `UNKNOWN`
and exits non-zero. Default per-operation deadline 30 s
(`POLYLANE_SOURCE_CANARY_TIMEOUT_MS` to override).

### 5.2 Freeze the source manifest (PLANNED — `source-freeze` lane)

Contract: reconcile Harvard metadata with the DataONE immutable metadata PIDs
(provenance mirror only) into one frozen `PLAN.json`. Exact
DOI/domain/licence/version/file identity must agree; any disagreement is
terminal `SOURCE-MISMATCH` — never a majority vote, never a silent mirror
substitution. Until this lane merges, no primary plan exists and every
downstream primary phase is blocked; that state is `EXTERNAL-EVIDENCE-OPEN`.

### 5.3 Download (single file REAL; campaign PLANNED)

Single file (REAL):

```bash
node benchmarks/taste-live/tools/dataverse-acquire.mjs fetch \
  --pid doi:10.7910/DVN/9FKSQI --file <FILE_ID> --cache "$CACHE_DIR" [--sha256 <expected>]
```

Guarded one-file canary through the Bash core (REAL; refuses to run unless
explicitly enabled):

```bash
POLYLANE_SOURCE_LIVE=1 POLYLANE_SOURCE_CANARY_FILE=<FILE_ID> \
  bash bin/polylane-taste-source.sh canary "$CACHE_DIR" PLAN.json canary-receipt.json
```

Exit 3 + `EXTERNAL-EVIDENCE-OPEN`/`UNKNOWN` on stderr when disabled, Chrome
missing, or bytes not acquired — never a fixture PASS.

Full 252-file campaign (PLANNED — `download-campaign` lane): resumable,
bounded concurrency, per-operation deadlines, bounded retry classes
(deterministic source errors are not retried forever), atomic `.part`
publish. Cross-origin data-file redirects are handled by same-browser CDP
download or a narrowly scoped handoff of the fresh ephemeral WAF session —
never via personal cookies or credentials.

### 5.4 Verify cache (REAL)

```bash
bash bin/polylane-taste-source.sh verify-cache "$CACHE_DIR" PLAN.json
```

Fails closed on the first missing, empty/partial, symlinked, or
checksum-mismatched object (`TASTE-SOURCE-INVALID: ...` on stderr). Cache
these expensive re-checks when nothing changed:

```bash
bin/polylane-check.sh "$PWD/.polylane/check-cache/" -- \
  bash bin/polylane-taste-source.sh verify-cache "$CACHE_DIR" PLAN.json
```

Quarantine reporting and resume planning are PLANNED (`cache-integrity`
lane). Manual recovery today: delete the named bad object file, re-fetch it
(§5.3), re-run `verify-cache`.

### 5.5 Select / split (REAL core; upstream normalization PLANNED)

```bash
bash bin/polylane-taste-source.sh build "$CACHE_DIR" PLAN.json manifest.json receipt.json
```

Joins raw ratings, aggregate ratings, and images from the cache; enforces
≥ 5 valid raters per stimulus, 1–5 rating range, raw-vs-aggregate agreement
within 0.5, no duplicate ids/images, exact per-domain quota; then performs
the deterministic seeded split (sha256(seed|id) ordering). Emits the corpus
manifest plus a `taste-source-acquisition/v1` receipt. `build` refuses
`classification:"secondary-audit"` plans; the TASTE secondary audit uses the
separate `secondary` subcommand and can never fill a primary quota. Parsing
the actual raw/aggregate source schemas into the join shape is PLANNED
(`ratings-normalize`, `corpus-select` lanes).

### 5.6 Pair building (PLANNED — `pair-builder` lane)

Contract: deterministic, unambiguous, held-out mirrored pairs; bootstrap
interval rule; side probes; frozen pair manifest. Calibration and holdout
stay disjoint by object digest and source id; a failed item is never
replaced after results exist.

### 5.7 Calibrate judges (execution wrapper REAL; live provider adapters and campaign driver PLANNED)

One sealed work unit (REAL):

```bash
bash bin/polylane-taste-judge-run.sh run workunit-manifest.json "$RUN_DIR"
```

CAS-claimed run dir keyed to the manifest hash; at most one retry and only
for infrastructure failure; completed runs replay idempotently. Exit codes:
0 voted/abstained · 1 infra · 2 parse · 3 isolation refusal · 4 malformed
manifest. Pointwise before pairwise; every mirrored session unique.

Eligibility receipt (REAL validator):

```bash
bash bin/polylane-taste-calibration-live.sh calibration-input.json eligibility-receipt.json [artifact-root]
```

Recomputes everything (gold from bound human holdout labels, votes re-parsed
from hash-verified raw responses with the pinned parser — print its digest
with `bash bin/polylane-taste-calibration-live.sh parser-sha`), applies the
frozen thresholds, and classifies `production` only when every image and
response resolves to real hash-matched files under `artifact-root`. Inline
responses stay `fixture_only`. `bin/polylane-taste-calibrate.sh` is the v1
fixture-grade compiler; it never yields production evidence.

### 5.8 Audit (PLANNED — `calibration-audit` lane)

Contract: independent recomputation of correctness, Wilson bound, side bias,
mirror contradictions, configuration identity, and eligibility — separate
code path from §5.7.

### 5.9 Preflight (PLANNED — `benchmark-preflight` lane)

Contract: one deterministic gate proving source, split, pairs, panel, cache,
providers, and disk are all ready BEFORE the expensive 20-brief generation
wave. Do not start the generation wave without it.

## 6. Observation with tmux

Long phases run inside tmux so disconnects don't kill them and everything is
logged:

```bash
tmux new-session -d -s taste-src
tmux pipe-pane -t taste-src -o 'cat >> "$HOME/taste-src-$(date +%Y%m%d).log"'
tmux send-keys -t taste-src 'cd <repo> && <phase command>' C-m
tmux attach -t taste-src        # watch; detach with Ctrl-b d — the job keeps running
```

Watch cache growth from a second pane: `watch -n 60 'du -sh "$CACHE_DIR"; df -h "$CACHE_DIR" | tail -1'`.

## 7. Receipts

Every phase that succeeds OR fails leaves a compact JSON receipt; commit
receipts, never binaries.

| Receipt | Producer | Key fields |
|---|---|---|
| `taste-source-canary/v1` | `canary` | dataset_pid, file_id, bytes, sha256, tool fingerprint |
| `taste-source-acquisition/v1` | `build`/`secondary` | classification, split, per-domain quota, raw support, per-source sha256s, manifest_sha256, reproduction command |
| judge run receipt | `polylane-taste-judge-run.sh` | sealed manifest hash, adapter fingerprint, raw response, terminal outcome |
| `taste-calibration/v2` | `polylane-taste-calibration-live.sh` | recomputed correct/Wilson/side/mirror numbers, parser sha, classification, `eligible`, always `human_certified:false` |

Existing live-harness evidence lives under
`docs/polylane/taste-certification/live-harness/` (Cycle-40 receipts,
including the WAF-202 source canary that kept the corpus OPEN).

## 8. Resumability and interruption recovery

- The cache is content-addressed: re-running any fetch of already-present
  bytes is a no-op; nothing is downloaded twice.
- Kill/crash/power-loss mid-download leaves only `.part` files. Recovery:
  re-run the same command. Stale `.part` litter is safe to delete.
- `verify-cache` is the resume planner available today: it names the first
  bad/missing object; delete-and-refetch, repeat until clean.
- Judge runs resume via the run-dir claim: a completed unit replays its
  terminal exit without re-invoking the provider; a partial run finalizes
  from the sealed receipt. Never delete a claimed run dir to "retry" a vote —
  that fabricates independence; a refused dir (exit 3) means use a new dir
  with the correct manifest.
- Receipts are written via temp-file + atomic rename; a half-written receipt
  at a final path should not exist and must be treated as tampering.

## 9. Challenge / CAPTCHA rule

If Dataverse (or any source) answers with a WAF challenge, CAPTCHA, 202/403
interstitial, or challenge HTML: the result is `UNKNOWN`. Full stop.

- Never solve a challenge by hand and feed the resulting bytes to the cache.
- Never import, copy, or replay personal browser profiles, cookies, API
  keys, or credentials to get past it; the adapter always launches a fresh
  ephemeral profile in a temp dir.
- Never cache a challenge page as data (the adapter detects and refuses this).
- Correct operator action: wait, re-run later, record the `UNKNOWN` receipt.
  Persistent unavailability is reported as `EXTERNAL-EVIDENCE-OPEN`, not
  worked around.

## 10. Provider failures (judge campaign)

- Infrastructure failure (timeout, adapter missing, nonzero exit): at most
  one retry per unit, then the unit is terminally failed-infra. No retry
  storms.
- A parse failure or substantive vote is never retried — retrying after
  seeing output is result-shopping.
- Abstention (`FINAL: ABSTAIN`) is a valid substantive outcome.
- A judge missing thresholds is `ineligible`, not an error; the panel needs
  at least five eligible configurations for `taste-calibration/v2`
  production. Fewer ⇒ `EXTERNAL-EVIDENCE-OPEN`. Do not lower thresholds,
  shrink the corpus, or substitute fixtures to force a panel.

## 11. Expected long-running phases

Honest expectations; none of these is promised to finish:

- Download campaign: 252 files behind a WAF with per-session warm-up and
  30 s per-operation deadlines — plan for hours, possibly spread over days
  if challenges recur. Resumable throughout.
- Calibration campaign: per judge configuration, pointwise passes then 24
  mirrored pairs = dozens of provider calls; multiply by panel size. Minutes
  to hours per judge depending on provider latency/quotas.
- `verify-cache` over the full corpus re-hashes every object: minutes; use
  the check-cache wrapper (§5.4) for unchanged re-runs.

## 12. Security boundaries

- Fresh ephemeral Chrome profile per operation (`--user-data-dir` in a temp
  dir); a personal profile is never read. Do not "help" by logging into
  anything in that browser.
- No credential, cookie, token, or API key is inspected, persisted, logged,
  or copied into receipts. Provider keys used by live adapters stay in the
  environment of the adapter process and out of every artifact.
- Cache object names are hex-validated: traversal and symlink entries are
  rejected, not normalized.
- The Bash core never touches the network; only the declared Node adapter
  does. If any other component starts fetching, that is a protocol breach.
- Run as a normal user; nothing here needs root.

## 13. Honest labels and stop conditions

| Label | Meaning |
|---|---|
| `UNKNOWN` | External step could not produce real bytes/answers (WAF, no Chrome, timeout). Not a failure of the protocol; never converted to a pass. |
| `EXTERNAL-EVIDENCE-OPEN` | Engineering verified, external evidence still missing (source quota, eligible panel). The honest cycle verdict when the world doesn't cooperate. |
| `SOURCE-MISMATCH` | Harvard/DataONE identity disagreement or checksum drift. Terminal for that source; investigate, never vote. |
| `fixture` / `fixture_only:true` | Hermetic test evidence. Never enters production claims. |
| `production` | Every binding recomputed over real hash-matched files. |
| `HUMAN_CALIBRATED_MACHINE` | Strongest claim a machine judge can earn here: it matched human holdout labels. |
| `human_certified:false` | Always, in every receipt this campaign can produce. No software, model, or operator action in this runbook can yield `human_certified:true`; that requires deciding ballots from recruited isolated humans, which do not exist in this system. |

Stop and record (do not improvise) when: a plan fails validation, a checksum
mismatches, a mirror disagrees, the disk estimate exceeds free space, a
challenge persists across retries spread over days, or the eligible panel is
short. Preserving exact receipts of a blocked state is a successful operator
outcome.
