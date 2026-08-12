# Verify: download-campaign lane

Lane deliverable: `benchmarks/taste-live/tools/taste-download-campaign.mjs` — a
resumable, bounded-concurrency selected-file download campaign built around the
transport contract, for run `c41-source-calibration-20260812-a1`.

## What it does

- Reads a frozen selected-file plan (`--plan`): per source (`source_id`, `pid`)
  a list of files with `file_id`, optional `declared_size`, `declared_md5`
  (Dataverse's declared checksum), and optional expected `sha256`.
- Establishes exactly **one fresh transport session per source**; fetch
  concurrency (default 3) fans out only after that session is valid.
- Verifies every downloaded object against declared size, declared md5, and
  expected SHA-256, then publishes it atomically (`.part` + `rename`) at
  `<cache>/objects/<sha256[0:2]>/<sha256>`. A partial or corrupt download is
  never visible at a final path.
- Appends every event to an append-only JSONL receipt: `campaign_start`,
  `session`, `duplicate`, `skip_valid`, `attempt`, `corrupt`, `fetch_ok`,
  `failed` (`class`: `retryable` | `fatal` | `corrupt` | `session`),
  `deadline`, `done`.
- Resumes without redownloading: an object whose recomputed digest and declared
  identity still verify is receipted `skip_valid` and the transport is not
  invoked at all. A tampered or missing cached object is redownloaded and
  atomically repaired.
- Bounds all retries: per-file `--max-attempts` (default 3) with linear
  backoff; deterministic (`FATAL`) transport answers are never retried;
  crashes/timeouts/garbled output are retryable within the same bound. The
  queue is exactly the selected pending files — nothing is ever re-enqueued
  beyond an item's own attempt budget, so no retry storm is possible.
- Every transport operation has a hard per-op deadline (`--op-timeout-ms`,
  default 120000); an optional whole-campaign `--deadline-ms` stops scheduling
  new work, receipts the remaining ids, and exits open for a later resume.
- Exit codes: `0` complete, `3` open/incomplete (`UNKNOWN`, never a fixture
  PASS), `2` usage.

## Transport contract

The campaign shells out to one executable (`--transport`); in production that
is the `dataverse-transport` lane's browser/CDP adapter, in tests a hermetic
fake. Stdout carries a one-line JSON status:

```
<transport> session --source <id> --pid <pid>
  -> {"status":"OK","session":"<token>"} | {"status":"RETRYABLE"|"FATAL","reason":...}
<transport> fetch --session <token> --source <id> --pid <pid> --file <id> --out <path>
  -> writes bytes to <path>; {"status":"OK"} | {"status":"RETRYABLE"|"FATAL","reason":...}
```

No cookies, credentials, or profile data cross this boundary — only the opaque
session token the transport itself issued for the fresh ephemeral session.

## How to verify (hermetic, no network)

```bash
node benchmarks/taste-live/tools/taste-download-campaign.mjs --selftest
bash tests/test-taste-download-campaign.sh
```

The focused test drives the tool against a fake transport and covers: happy
path with session-before-fetch ordering and per-source session tokens, bounded
concurrency (max observed in-flight ≤ `--concurrency`), full resume with zero
transport calls and an untouched append-only receipt prefix, duplicate plan
entries fetched once, truncated bytes never published with bounded attempts,
corruption on the first attempt recovering within the retry budget, retryable
failures stopping at exactly `--max-attempts`, fatal failures stopping after
one attempt, a hanging transport bounded by the per-op deadline, a campaign
deadline that schedules nothing and later resumes to completion, session
failure marking files `class:"session"` with no fetches, interruption
atomicity (a crashed transport leaves zero finalized objects; resume publishes
the real bytes and clears `.part` debris), and a tampered cache object being
re-verified and redownloaded.

## Expected storage and throughput (no invented measurements)

- Storage is bounded by the declared sizes in the frozen source manifest for
  the 252 selected images (180 calibration + 72 held-out, 60/24 per domain)
  plus the metadata/ratings files — the campaign downloads selected files
  only, never the full 3,156-screenshot corpus. Exact byte totals come from
  the `source-freeze` manifest's declared sizes; this lane does not invent
  them.
- Throughput depends on the real WAF warm-up, network, and the per-source
  session cost; no measured rate is claimed here. The integrator's single real
  campaign run owns the measured wall-time, byte, and retry numbers, which its
  receipt (`fetch_ok.bytes`, `attempts`, timestamps) records verbatim.
- Defaults chosen for the real run: concurrency 3, max-attempts 3, per-op
  timeout 120 s, backoff 500 ms — bounded worst case per file is 3 attempts
  regardless of failure mix.
