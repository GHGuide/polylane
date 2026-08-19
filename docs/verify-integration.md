# verify — lane `integrator` (run `c43d-recovery-20260819-a1`, target m32.6) — repair round 1

Repair round after the host gate rejected attempt 1 (its evidence is preserved
committed at `docs/verify-integration-attempt-1.md`). Every count and hash
below is observed output from commands run fresh in this worktree during this
round; nothing is carried over from the precheck, builder, prior-integrator,
or attempt-1 reports, which were read and then independently re-derived.

## What the host gate rejected, and the proven root causes

The host gate re-ran the frozen m32.6 focused acceptance in this worktree
(canonical record `docs/polylane/host-gate-failures/c43d-recovery-20260819-a1.{md,acceptance.jsonl}`
at the project root, 04:51 local): `tests/run.sh` ended
`SUMMARY: 4074 passed, 1 failed` with sole failed file
`tests/test-worker-canonical-state.sh`, and an untracked
`docs/polylane/host-gate-failures/shadow-run.acceptance.jsonl` appeared inside
this worktree mid-suite. Both causes were reproduced deterministically before
repair:

1. **Lock-steal race in `bin/polylane-workers.sh` `acquire_lock`.** Between
   `mkdir "$LOCK_DIR"` and the `created_at` stamp write, a contender read the
   missing stamp as epoch-0, computed the microseconds-old lock as stale,
   stole it, and the live holder died with `lost worker lock before history
   append` (rc≠0). Widening the gap to 1s in an instrumented copy made 3 of 4
   concurrent `send` calls fail — exactly the concurrent rc=0 assertions
   `test-worker-canonical-state.sh` checks. Load-sensitive: 0 failures in 30
   plain runs, deterministic under the widened gap. This is a real product
   race (all four `acquire_lock` call sites share it), not a test-env issue.
2. **Host-gate environment leaking into nested tests.** The gate's acceptance
   subshell exports `REPO`, `REPO_ROOT` (= this worktree),
   `POLYLANE_EFFICIENCY_PROOF`, `POLYLANE_EXPECTED_RUN_ID`, and the
   `POLYLANE_ACCEPT_FAILURE_*` trio into the m32.6 command.
   `polylane-memory.sh _accept_run` already unsets the failure trio for nested
   commands, but not `REPO_ROOT`; `tests/test-graph-shadow.sh`'s intentional
   `false` acceptance fixture (`RUN_ID=shadow-run`, phase `focused`) then
   captured `failure_root="$REPO_ROOT"` from the inherited value and wrote
   real host-gate evidence into the actual checkout. Reproduced byte-for-byte
   (same `shadow-run`/`focused`/`false` record) by running the test with
   `REPO_ROOT` exported; zero leak without it — which is why attempt 1's
   direct invocation (no such exports) ran 4075/0 while the gate's identical
   command failed.

## Repairs (this round's only source changes, commit `6382be3`)

- `bin/polylane-workers.sh` — an unstamped lock dir is aged by its own mtime
  (`stat -f %m` / `stat -c %Y` guarded, falling back to "fresh") instead of
  epoch-0; the mkdir→stamp gap can no longer be stolen, while crashed-owner
  TTL stealing (old mtime) is preserved. Post-fix forced-gap rerun: 4/4
  concurrent sends rc=0, history seqs unique. `shellcheck -S warning` clean.
- `tests/helpers.sh` — unsets `REPO REPO_ROOT POLYLANE_ACCEPT_FAILURE_ROOT
  POLYLANE_ACCEPT_FAILURE_RUN_ID POLYLANE_ACCEPT_FAILURE_PHASE
  POLYLANE_EFFICIENCY_PROOF POLYLANE_EXPECTED_RUN_ID` before any test logic,
  making all 142 helpers-based tests hermetic against the gate environment.
  The 31 non-helpers tests were swept for those variables: the three matches
  (`test-taste-certification.sh`, `test-taste-study-live.sh`,
  `test-taste-live-harness-e2e.sh`, the last sourcing the second as a
  library) all assign `REPO` locally. Re-running `test-graph-shadow.sh` under
  the full simulated gate env: 52 pass / 0 fail, zero leak.
- `tests/test-workers.sh` — regression test: a fresh unstamped `.lock` dir
  must make a contender wait, not steal. Red-green verified: with the
  `acquire_lock` fix stashed the new assertion fails
  ("contender finished instantly — stole a fresh unstamped lock", 48/1);
  restored it passes (49/0).
- The leaked `shadow-run.acceptance.jsonl` was removed from this worktree
  (reproduced and documented above; the canonical root keeps the host gate's
  own records, which are runner-owned and untouched).

No frozen acceptance check, scope, or product decision was weakened: the
frozen m32.6 command is unchanged, all its checks still run, and the repairs
add assertions (4075 → 4077).

## Branch tips, ancestry, and merges (re-proven fresh this round)

| ref | commit |
|---|---|
| lane HEAD before this round's repairs | `fc16599` (harness WIP checkpoint of attempt-1 evidence) |
| `main` | `7e4e35e8e4def5a10278b71a49041216059abf65` |
| `lane/c43d-precheck` tip | `6dc76a40292610d25c4f97e316a2c1bf36466081` |
| `lane/c43c-integrator` (candidate) tip | `9b0f8cb973b5f6b646a9724c7e6823479f22817a` |
| merge 1 (`--no-ff`, zero conflicts): precheck | `a575321` |
| merge 2 (`--no-ff`, 3 conflicts, resolved in attempt 1): candidate | `27e2615` |
| this round's repair commit | `6382be3` |

`git merge-base --is-ancestor` exit 0 re-verified this round for all five
input refs against HEAD: `main`, `lane/c43d-precheck`, `lane/c43c-integrator`,
`lane/c43-integrator`, `lane/c43-contract-import`. The brief named
`lane/c43b-precheck`; that run was cleaned up before this run launched and no
such branch exists — this run's precheck lane is `lane/c43d-precheck`
(status file carries this run's nonce), merged per the brief's controlling
"current branch tips, not memorized hashes" rule. Both verify files were read:
`lane/c43d-precheck:docs/verify-precheck.md` (4 PASS / 1 FAIL, the FAIL being
the predicted `pane_wedged()` conflict, resolved and closed in attempt 1) and
`lane/c43c-integrator:docs/verify-integration.md` (the prior run's
READY-FOR-HOST-GATE evidence, historical at its merged ref). The brief's
`docs/verify-import-verify.md` exists on no ref; the builder's actual evidence
is `docs/verify-contract-import.md`, cross-checked in attempt 1.

## Candidate did not lose main's post-handoff fixes (re-grepped fresh)

| main's post-handoff fix | merged tree (this round) |
|---|---|
| doctor `check_auth` preflight | 3 refs in `bin/polylane-doctor.sh` |
| login-expired parking (`Login expired`) | 2 refs in `bin/polylane-run.sh` |
| safe-read approvals (`approval_is_safe_read`) | 3 refs in `bin/polylane-run.sh` |
| parked lanes skip respawn (`lane_needs_decision`) | 4 refs in `bin/polylane-run.sh` |
| supervisor dying-words (`last_err`) | 6 refs in `bin/polylane-supervisor.sh` |
| model detection / `claude-opus-5` ladder | 2 refs in `bin/polylane-run.sh` |
| `37079b3` usage-limit stall (`usage-credits`) | 4 refs in `bin/polylane-run.sh` |
| `7e4e35e` tool-child immunity (`pane_tool_child_running`) | 3 refs in `bin/polylane-run.sh`; `test-wedge.sh` 37/0 in this round's log |
| imported lifecycle (`finalization_transition`) | 5 refs in `bin/polylane-run.sh` |

## Imported-contract SHA-256s, re-derived fresh this round

Both frozen hashes in `docs/polylane/cycle-42a-outcome.md` re-derived from
`4851bc1` and matched exactly:
`52c99513054a658f30277856ab04f7d810b672af870717721c86a80a4e93a033`
= sha256(`4851bc1:docs/status-taste-contract-integrator.md`) and
`4eb179e6c543b04e181efa996815b8623821c8bb2a678ab720889e3d98e5fee2`
= sha256(`4851bc1:docs/verify-integration.md`).

All 16 imported artifacts re-hashed from the worktree this round; every one
matches the builder's `docs/verify-contract-import.md` tables (the 8 contract
JSONs live under `docs/polylane/taste-certification/contracts/`):

| SHA-256 | file |
|---|---|
| `689ab890c339966b15f32a22f309a564f92d1ff34b354184425ffef0f8e41c34` | `contracts/CONTRACT-LOCK.v3.json` |
| `00b2dc076bf74c2b511ef780f1cda796730ad4704a9d1ccb1f397f4d025864da` | `contracts/EVIDENCE-CLAIM-REGISTRY.v3.json` |
| `b90e2148bc7cd1ee36d3f7dcf2b7b23eed63b9b5f2057943bb120cbb1c6438d2` | `contracts/evidence-dag-v3.schema.json` |
| `8ff293fa72cc32ae52c3bf40a82fd4e67d06a2e24b534b0a323b97bd1cc5d7ee` | `contracts/evidence-policy-v3.json` |
| `3b8d5fdeb31721caac38696464d84eb4157179d6bd0f06df4948a72bf689542e` | `contracts/execution-v3.example.json` |
| `3175f71c2c07e0682f71485cb05b91df7cdc8f82ac47de07b0f4746e77d52db8` | `contracts/execution-v3.schema.json` |
| `df881837618901c66ab9761788f00fc1e10091548a9f5e9f84afde727abd7fd9` | `contracts/source-calibration-v3.example.json` |
| `651150db701f7aaf8d7d8201126f8e477a8d80880fc293ab96af03cec662bd9e` | `contracts/source-calibration-v3.schema.json` |
| `66164a629b76ce42de17fab8764275d6d154ffba305a657c9d327c696aa11b4a` | `bin/polylane-evidence-dag.sh` |
| `c64bbb0cc9181306f3dba97734ff5f030c8b332e749375c2700ea4d6ba30eb91` | `bin/polylane-finalize.sh` |
| `e16e52c37a108d1c4610a505f3c70e18e1fb2d4ecc729030f6c03c50b42637bb` | `bin/polylane-taste-execution-contract.sh` |
| `47c674b77203bb5f2cfdfce615c374a3d7318524ad28b4a10babaf55633a57e4` | `bin/polylane-taste-source-contract.sh` |
| `d09805179ff0def2f756b2b795a99f49a0456226ceb359692369565674e706b4` | `tests/test-evidence-dag.sh` |
| `c3846f43787ed72a35b9574b94e207177df2d4f075d93884e383ad2ffb6011c4` | `tests/test-finalization-watchdog.sh` |
| `f91907b832c8c6bef1298f7395197b37d6288532aa1bf9faa335fee722a64e60` | `tests/test-taste-execution-contract-v3.sh` |
| `d7d53c4ef2e24713a06386270881d559703e70bd94566bda332280a9540b2be2` | `tests/test-taste-source-contract-v3.sh` |

Ported/shared files unchanged by this round and matching attempt-1:
`bin/polylane-run.sh` `8e371d1fc2c39d5534f7e8a9156f480b115bc07582aaf1343c45166a577d29e7`,
`bin/polylane-supervisor.sh` `d0cee637fa8a74f839a9fa7c397a73bbe744c9621bf394472e2e5b59c1e0f312`,
`bin/polylane-memory.sh` `726e1ceac471b595268eb522c14788a4b27f10466c0c6193bd4622c6ffb46fd8`,
`tests/test-lane-done-live.sh` `eebfa0c7a0bfed9e282e9ffbed4c9dabb464bfefbee37336c4af03906d49da3e`
(still byte-identical to the `4851bc1` blob). This round's repaired files:
`bin/polylane-workers.sh` `a8a57d0a5ea1fe809102a56a84ad1102290c14d622605936c7f9bdc58c45ae3f`,
`tests/helpers.sh` `9c4e7e1968523948b5e54e8feb58f9e345e2b4678b2a1d49d207ee824ac8dc76`,
`tests/test-workers.sh` `f6a6a41b783150b5a2f6af6e5dce0ac4b2d5874fe7f88678581be0b6d1df3dac`.
None of the 16 imported artifacts was touched by the repairs.

## Relay requests handled

Start-of-round and final `pending` reads both list only the historical
`contract-import → integrator` seq=1 request from run `c43-recovery-20260818-a1`
(the `test-lane-done-live.sh` needle swap). It was resolved before this run by
host commit `77a83b3` and re-proven in attempt 1; integrator decision events
seq=2, 3, and 4 are on the durable relay. The `pending` view lists request
events forever by design. The durable worker inbox
(`polylane-workers.sh inbox … integrator`) holds 18 relay-imported messages,
all from completed prior runs (c15, c37, c38, c42a) with no `run_id` matching
this run — historical, no autonomous work addressed to this round.

## Seams

`bin/polylane-seams.sh scan .` rc=0 and `git diff --check` clean, run after
the repairs and before the acceptance chain.

## Fresh test totals — frozen m32.6 focused acceptance

Command taken verbatim from `docs/polylane/max-state.json`
(`.accept[] | select(.sid=="m32.6") | .cmd`) — byte-identical to the command
in the host gate's failure record — and run **once to completion** through
`bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator"` on the
repaired tree as a background task. The repairs changed the source
fingerprint (attempt-1 `2914121584:184` → `946330686:19003`), so the cache
correctly re-ran rather than replaying the cached pass. Receipt:
`CHECK-CACHE: PASS source=946330686:19003`, full 5338-line log
`.polylane/check-cache/integrator/3069206089-895.output`. **Overall rc=0** —
the `&&` chain completed through every link:

| link | result |
|---|---|
| `tests/test-taste-execution-contract-v3.sh` | `1..43`, 0 `not ok` |
| `tests/test-evidence-dag.sh` | `ok - evidence-dag-v3 (95 assertions)` |
| `tests/test-taste-source-contract-v3.sh` | `ok - taste-source-contract-v3 (60 assertions)` |
| `tests/test-finalization-watchdog.sh` | 18 pass, 0 fail |
| `tests/test-contract-acceptance.sh` | 42 pass, 0 fail |
| `tests/test-verdict-repair.sh` | 61 pass, 0 fail |
| `tests/test-lane-done.sh` | 27 pass, 0 fail |
| `tests/test-lane-done-live.sh` | 18 pass, 0 fail |
| `tests/test-supervisor.sh` | 38 pass, 0 fail |
| `shellcheck -S warning` (8 frozen scripts) | clean (chain continued) |
| `tests/run.sh` (full suite) | **SUMMARY: 4077 passed, 0 failed, 173 test files** |
| `bin/polylane-markers.sh check-docs references/` | clean (chain continued) |
| `tests/test-skill-parity.sh` | 72 pass, 0 fail |
| `git diff --check` | clean (chain rc=0) |

The suite total is 4077 vs attempt-1's 4075: the two new passes are this
round's regression assertions in `tests/test-workers.sh`
(`workers-unstamped-fresh-lock-not-stolen`,
`workers-unstamped-lock-holder-proceeds-after-release`; 49 pass / 0 fail vs
47 prior). Same 173 files. Zero `not ok` lines; every `FAIL`-word hit in the
log was inspected and is fixture text inside passing tests (merge-failure
fixtures, health-failure fixtures, `TASTE-A11Y: FAIL` attack fixtures). The
previously failing `test-worker-canonical-state.sh` is 23 pass / 0 fail, and
was additionally re-run under the simulated gate environment (exported
`REPO_ROOT`, proof vars): 23 pass / 0 fail.

## Limitations

- The remaining m32.6 certification is the coordinator's **host-owned
  terminal gate**; nothing here claims it. This round produced a repaired
  certified candidate at `6382be3` (merge `27e2615` + repairs) only.
- The lock race was proven with a deliberately widened window; the natural
  window is microseconds, so the host-gate failure attribution is a proven
  mechanism plus matching symptom (`lost worker lock` → concurrent rc≠0 →
  that file's assertions), not a capture of the original scheduler
  interleaving itself. No other mechanism reproduced any failure in that
  file (30/30 plain, all env permutations green).
- The gate-env hermeticity fix is in `tests/helpers.sh` (test side).
  `polylane-memory.sh _accept_run` still passes `REPO_ROOT` through to
  nested commands; a future non-helpers test that consults it could
  re-introduce a leak. Flagged, not repaired here — `_accept_run` is inside
  frozen-shellchecked `bin/polylane-memory.sh` and the minimal fix that
  makes the observed failure impossible lives with the tests.
- `tests/test-graph-benchmark.sh` remains timing-sensitive under load
  (green in this log); the v3 durable-fingerprint `pane_wedged()` path still
  has no tool-child guard (property of both parents, no frozen test covers
  it) — both carried over from attempt-1, unchanged.
- The three TAP-format imported tests (43/95/60 assertions) are gated by exit
  code in `tests/run.sh` but excluded from its `PASS`-line tally; their 198
  assertions are counted in the per-link table, not in the 4077.
- Attempt-1's restart-count concern stands: this lane cannot make the run's
  restart telemetry smaller; it only re-proves candidate integrity.
- No provider installs, no external actions, no subagents, no writes outside
  the integrator branch and the two owned handoff docs.

## Skill receipts and evidence

- SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
- SKILL-READ: superpowers:verification-before-completion | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/verification-before-completion/SKILL.md | 1896692335-3646

SKILL-EVIDENCE: engineering:testing-strategy — helped: its "data integrity
and error handling over trivial coverage" framing shaped the regression test
into a deterministic behavioral check (a fresh unstamped lock must make a
contender wait) instead of a timing-replay of the race, and its gap-analysis
step drove the sweep proving all 31 non-helpers test files assign `REPO`
locally rather than assuming the helpers fix covered everything.

SKILL-EVIDENCE: superpowers:verification-before-completion — helped: four
concrete places. (1) Both root causes were reproduced before any fix was
written (forced 1s lock gap → 3/4 concurrent sends fail; exported
`REPO_ROOT` → byte-identical `shadow-run` leak record). (2) The regression
test was red-green verified by stashing the fix (48/1 red) and restoring it
(49/0 green), per its TDD pattern. (3) The 4075→4077 delta was attributed to
the two named new assertions before claiming the suite clean, and every
`FAIL`-word hit in the 5338-line log was inspected. (4) All 16 imported
hashes, both frozen c42a hashes, ancestry for five refs, and the
post-handoff-fix greps were re-derived fresh this round instead of citing
attempt-1.
