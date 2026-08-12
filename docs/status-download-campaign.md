STATUS: download-campaign DONE run=c41-source-calibration-20260812-a1

# Lane status: download-campaign

Delivered `benchmarks/taste-live/tools/taste-download-campaign.mjs`, a resumable
selected-file download campaign around the transport contract, with hermetic
focused test `tests/test-taste-download-campaign.sh` and verification doc
`docs/verify-download-campaign.md`. Implementation commit: `e577be9`.

## Contract coverage

- One fresh transport session per source; fetch concurrency (bounded worker
  pool, default 3) starts only after the session is valid.
- Declared size + declared md5 + expected SHA-256 verified before atomic
  `.part` + rename publish at `objects/<sha[0:2]>/<sha>`; partial/corrupt bytes
  never reach a final path; tampered cached objects are re-verified and
  atomically repaired.
- Retries classified retryable/fatal/corrupt/session; per-file attempts bounded
  by `--max-attempts`; FATAL never retried; queue is exactly the selected
  pending files — no retry storm, no unbounded queue.
- Per-op deadline (`--op-timeout-ms`) kills hung transports; campaign
  `--deadline-ms` stops scheduling, receipts remaining ids, exits 3 open.
- Append-only JSONL receipt (`campaign_start`/`session`/`duplicate`/
  `skip_valid`/`attempt`/`corrupt`/`fetch_ok`/`failed`/`deadline`/`done`);
  resume re-verifies digests and never redownloads or touches the transport
  for valid objects; earlier receipt lines are never rewritten.

## Verification (ran, green)

- `node benchmarks/taste-live/tools/taste-download-campaign.mjs --selftest` → `SELFTEST-OK n=20`
- `bash tests/test-taste-download-campaign.sh` → `PASS test-taste-download-campaign assertions=63`
  (also cached via `polylane-check.sh`; test script shellcheck-clean at -S warning)
- Mutation probe (fatal→retryable) failed the suite as expected, then was reverted.
- TDD: test written first and observed failing (tool absent); tamper test
  observed failing and exposed a real publish bug (existing-object guard
  skipped repair), fixed by always atomic-renaming.

## Boundary honesty

- No real campaign executed here; the integrator owns the single real run.
- Storage/throughput: bounded by frozen-manifest declared sizes for the 252
  selected images; no measured numbers invented — the real run's receipt
  records bytes/attempts/timestamps verbatim.

## Skill evidence

- SKILL-EVIDENCE: superpowers:test-driven-development — helped: test-first plus the added tamper case caught a real publish bug (dest-exists guard prevented repair of a tampered cached object) before any real run.
- SKILL-EVIDENCE: engineering:testing-strategy — helped: shaped the pyramid split — 20 pure-helper selftest checks under a hermetic fake-transport integration test, matching the lane's mandated failure-mode list.
- SKILL-EVIDENCE: engineering:debug — helped: reproduce→isolate→fix loop on the tamper failure (re-ran with the failing assertion, isolated to the publish guard, single-line root-cause fix).
- SKILL-EVIDENCE: operations:risk-assessment — helped: drove explicit mitigations for the high-impact risks (retry storm → bounded per-file attempts and fixed queue; hung transport → per-op kill deadline; partial publish → atomic rename; silent fixture pass → exit 3 UNKNOWN).
