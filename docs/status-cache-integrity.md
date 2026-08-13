STATUS: cache-integrity DONE run=c41-source-calibration-20260812-a1

# Status — cache-integrity lane (Cycle 41)

Delivered `bin/polylane-taste-cache.sh` (inventory / plan-resume / quarantine),
`tests/test-taste-cache-integrity.sh` (57 assertions, hermetic, adversarial-first),
and `docs/verify-cache-integrity.md`. Commit `6620226` on `lane/c41-cache-integrity`.

## Verification (run on this host, GNU bash 3.2.57, ShellCheck 0.11.0)

- `bash tests/test-taste-cache-integrity.sh` → `OK: 57 assertions`, exit 0.
- `shellcheck -S warning bin/polylane-taste-cache.sh` → clean.
- Malicious-path and interrupted-cache tests were written first and watched fail
  (TDD RED) before implementation; one real defect (leaked `*.scan.$$` temp file
  on failed runs) was caught by a new failing assertion and fixed.

## Guarantees

- Inventory distinguishes `missing/absent` and `missing/interrupted-partial`
  (.part sidecar) from `corrupt/{symlink,not-regular,empty,checksum-mismatch}`;
  read-only; exit 4 on dirty cache with an atomic sorted report.
- `plan-resume` emits byte-identical, sha-sorted download work for exactly the
  missing+corrupt set; ok objects never re-downloaded.
- Quarantine acts only on an explicit `taste-cache-integrity/v1` report, only on
  `corrupt` entries, re-verifies each object first, and moves — never deletes —
  into `$CACHE/quarantine/`. No user cache object is deleted or rewritten anywhere.
- Boundary proof: 64-hex validation before path construction plus an explicit
  under-root pattern check; traversal ids, hostile reports, and symlinked cache
  roots all rejected; an outside-cache sentinel survives the whole suite.

## Skill receipts

- SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/test-driven-development/SKILL.md | 9bf54057abb7
- SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | ebfdb1c894cd
- SKILL-READ: engineering:debug | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/debug/SKILL.md | 5a663df718f1
- SKILL-READ: operations:risk-assessment | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md | af09a37328ba

- SKILL-EVIDENCE: superpowers:test-driven-development — helped: RED-first suite
  caught the temp-file leak on failed inventory runs before it shipped.
- SKILL-EVIDENCE: engineering:testing-strategy — helped: focused coverage on
  security boundaries, error handling, and data integrity (malicious paths,
  every rejection class, determinism) instead of trivial paths.
- SKILL-EVIDENCE: engineering:debug — helped: leak diagnosis followed
  reproduce→isolate→fix (spot-check reproduced the dropping, trap fixed the
  root cause in both scan callers, regression assertion added).
- SKILL-EVIDENCE: operations:risk-assessment — helped: framed the lane's top
  risks (boundary escape, silent deletion of user bytes, stale-report
  quarantine) and each got an explicit mitigation plus a test.

## Relay

Coordination relay checked at start and before completion: no pending requests,
no claims, empty durable inbox. No cross-lane work was addressed to this lane.
