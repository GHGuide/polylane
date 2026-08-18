# Verify — dataverse-transport (c41-source-calibration-20260812-a1)

## Repair reflection (attempt 1)

1. What went wrong: the prior session confirmed RED (adapter still had the magic
   `sleep(1500)` warm-up) and then attempted one monolithic "adapter v2: full rewrite of
   the live section" that never completed; the session also stalled on interactive shell
   permission prompts for compound commands, so no implementation, verification, or
   status file was ever committed.
2. Root cause: an all-at-once rewrite of the entire live Chrome/CDP section put every
   behavior change into a single unreviewable step with no intermediate green state, and
   prompt-triggering compound shell invocations blocked the autonomous loop before the
   rewrite could land.
3. Different approach now: keep the RED test as the spec and land the adapter in small
   verified increments — (a) pure failure-taxonomy + readiness-envelope helpers with
   selftest coverage, (b) observed JSON readiness replacing the sleep, (c) CDP
   `Browser.setDownloadBehavior`/`downloadProgress` download path, (d) resumable
   content-addressed fetch — running the node selftest and the focused bash test after
   each increment, using only simple non-interactive shell commands.

## What changed

`benchmarks/taste-live/tools/dataverse-acquire.mjs` (adapter v2):

- Observed readiness replaces the magic 1.5 s warm-up: `waitForReadiness` polls
  `GET {base}/api/info/version` inside the fresh page every 500 ms until
  `isReadyEnvelope` observes HTTP 200 with a parseable `{"status":"OK"}` JSON envelope.
  The only clock is the existing `withTimeout` deadline
  (`POLYLANE_SOURCE_CANARY_TIMEOUT_MS`, default 30 s), so a persistent challenge ends
  as a bounded `UNKNOWN`, never a guessed sleep.
- Redirected data files download through the browser's own pipeline in the same fresh
  ephemeral Chrome context: `Browser.setDownloadBehavior` (`allowAndName`, events on)
  plus `Browser.downloadWillBegin`/`Browser.downloadProgress` completion, triggered by
  `Page.navigate` to the datafile URL. Chrome follows the cross-origin object-store
  redirect natively; no cookie, credential, or profile is inspected, persisted, or
  logged (receipts carry only status/class/ids/digests).
- Frozen failure taxonomy via exported `classifyFailure`: `challenge` (WAF/CAPTCHA,
  incl. an interstitial page rendered instead of a download), `timeout` (deadline),
  `redirect` (download canceled mid-redirect), `checksum` (bytes disagree with the
  declared digest), `transport` (spawn/CDP/socket/anything else). Every `UNKNOWN`
  receipt now carries `"class":...`.
- Resumable fetch: when `--sha256` is given and the content-addressed object already
  verifies, the adapter returns `{"status":"OK","resumed":true,...}` with zero network;
  a tampered/empty cached object falls through to the live path (and fails closed).
- Ephemeral-context hygiene unchanged: fresh `--user-data-dir` under tmp, SIGKILL
  cleanup on every exit path (including `process.exit` from `unknown()`).

`tests/test-taste-dataverse-transport.sh`: extended hermetic spec (RED first) covering
the no-magic-sleep contract, readiness probe, CDP download markers, session hygiene,
failure-class taxonomy, bounded timeout, and resumable-fetch behavior. No network, no
real Chrome required.

## Verification (exact commands and results)

```
$ node benchmarks/taste-live/tools/dataverse-acquire.mjs --selftest
SELFTEST-OK n=20
$ bash tests/test-taste-dataverse-transport.sh
PASS test-taste-dataverse-transport assertions=31
```

RED was observed before implementation:

```
$ bash tests/test-taste-dataverse-transport.sh   # before adapter v2
FAIL: adapter still contains a magic warm-up sleep   (rc=1)
```

shellcheck is not applicable to the `.mjs` adapter; the bash test file follows the
existing suite conventions (`set -euo pipefail`, mktemp + trap).

## External evidence — one bounded real canary (2026-08-13)

Hermetic tests passed first. Canary of the repaired seam, both operations bounded by
`POLYLANE_SOURCE_CANARY_TIMEOUT_MS=90000`, cache in a session scratchpad outside Git:

1. `discover --pid doi:10.7910/DVN/9FKSQI` → `{"status":"OK","kind":"metadata",
   "metadata_sha256":"17ef075975cd9173ccc82e8ae18b4533dcd7b62b35d39f00109c2ffb4c29f092",
   "version":"4.0",...}` — the metadata SHA-256 is byte-identical to the value frozen
   in `docs/polylane/cycle-41-research.md`, and readiness was observed (no fixed delay).
2. `fetch --file 7228385` (DemographicsSurvey.md, smallest listed file) →
   `{"status":"OK","kind":"datafile","resumed":false,"bytes":1467,
   "sha256":"155027693b4d066dfd4b24ff168382c6d73314c17d7138ac15230a64463e00a5"}` via the
   CDP download path through the object-store redirect. Local
   `md5 = c87cd09c50d5804f31ca06ddf23cc0be` equals Dataverse's declared md5 for that
   file id — byte-exact transport confirmed.
3. Resume re-run with `CHROME_BIN=/nonexistent` and the same `--sha256` →
   `{"status":"OK","resumed":true,...}` (rc=0, zero network, no browser launched).

No challenge was encountered; had one appeared it would have been recorded as
`UNKNOWN` with `"class":"challenge"` per the frozen contract.

## Skill receipts

SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/test-driven-development/SKILL.md | 1657109997-9015
SKILL-READ: engineering:debug | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/debug/SKILL.md | 303222582-4074
SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
SKILL-READ: operations:risk-assessment | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md | 3889652016-1630

SKILL-EVIDENCE: superpowers:test-driven-development — helped: RED (`FAIL: adapter still
contains a magic warm-up sleep`) was reproduced before any adapter change, and each
increment was verified green via selftest before the next.
SKILL-EVIDENCE: engineering:debug — helped: the reproduce→isolate→diagnose structure
pinned the prior attempt's root cause (monolithic rewrite + interactive permission
stalls) before choosing the incremental repair.
SKILL-EVIDENCE: engineering:testing-strategy — helped: shaped the pyramid — many
hermetic pure-helper selftests, one hermetic contract/behavior bash test, exactly one
live canary at the top.
SKILL-EVIDENCE: operations:risk-assessment — helped: identified session-material
leakage, retry storms, and challenge misclassification as the material risks; mitigated
with ephemeral-profile-only sessions, a single bounded canary, and the explicit
five-class failure taxonomy.
