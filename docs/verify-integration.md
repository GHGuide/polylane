# verify — lane `integrator` (run `c43c-recovery-20260819-a1`, target m32.6)

Integration of this run's fresh precheck evidence and the prior run's fully
verified candidate onto the integrator branch, with fresh re-verification of
the imported v3 contracts, the ported runtime deltas, main's post-handoff
fixes, and the frozen m32.6 focused acceptance. Every count and hash below is
observed output from commands run fresh in this worktree during this lane —
nothing is carried over from the precheck, builder, or prior-integrator
reports, which were read and then independently re-derived.

## Branch tips, ancestry, and merges

| ref | commit |
|---|---|
| `main` == lane HEAD at start | `37079b303115a8f3bd6460ce061632731aa909fe` |
| `lane/c43c-precheck` tip at merge | `c9ee548e751477e10579b70db7f46b6253a0cf04` |
| `lane/c43-integrator` (candidate) tip at merge | `f16e19649557042ecf242c4c22d4371c050514b0` |
| merge-base(main, candidate) | `b6772b17a964f4bd82415409d77f1dfddfaf58b6` |
| merge 1 (`--no-ff`, ort, zero conflicts): precheck | `16ad45b` |
| merge 2 (`--no-ff`, ort, zero conflicts): candidate | `72be7a4` |

The brief named `lane/c43b-precheck`; that run was cleaned up before this run
launched and no such branch exists. This run's precheck lane is
`lane/c43c-precheck` (its `docs/status-precheck.md` first line carries this
run's nonce `run=c43c-recovery-20260819-a1`), and per the brief's controlling
rule — "merge current branch tips, not memorized hashes" — that live tip is
what was merged. The candidate tip `f16e196` matches the hash the precheck
lane verified (READY sentinel on line 178, intact content addresses,
conflict-free merge-tree onto `main`).

After both merges, all four input refs are ancestors of HEAD
(`git merge-base --is-ancestor` exit 0 for each): `main`,
`lane/c43c-precheck`, `lane/c43-integrator`, `lane/c43-contract-import`.

## Both verify files read

- `lane/c43c-precheck:docs/verify-precheck.md` — five read-only checks, all
  PASS/RECORDED; proves candidate integrity and textual mergeability, and
  explicitly defers semantic verification and the `4851bc1` hash-equality
  proof to this lane (its limitations 1, 2, 4). Both deferred items are closed
  below.
- `lane/c43-integrator:docs/verify-integration.md` — the prior run's 178-line
  evidence ending `POLYLANE-VERDICT: READY-FOR-HOST-GATE
  run=c43-recovery-20260818-a1`; historical, left committed in history. The
  file at this path now carries this run's evidence; the prior content remains
  at the merged ref. (The brief named the builder file
  `docs/verify-import-verify.md`; no such path exists on any branch — the
  builder's actual evidence is `docs/verify-contract-import.md`, read from the
  candidate ref.)

## Candidate did not lose main's post-handoff fixes

The candidate forked from `main` at `b6772b1`, so the one commit it could not
contain is `37079b3` (model-specific usage-limit stall detection). Checked
every named fix by grep in the **merged worktree**:

| main's post-handoff fix | merged tree |
|---|---|
| doctor `check_auth` preflight | 3 refs in `bin/polylane-doctor.sh` |
| login-expired parking (`Login expired`) | 2 refs in `bin/polylane-run.sh` |
| safe-read approvals (`approval_is_safe_read`) | 3 refs in `bin/polylane-run.sh` |
| parked lanes skip respawn (`lane_needs_decision`) | 4 refs in `bin/polylane-run.sh` |
| supervisor dying-words (`last_err`) | 6 refs in `bin/polylane-supervisor.sh` |
| model detection / `claude-opus-5` ladder | 2 refs in `bin/polylane-run.sh` |
| `37079b3` usage-limit stall (`usage-credits`) | 4 refs in `bin/polylane-run.sh`; `tests/test-pane-stalled.sh` present, 3 refs, 21 pass / 0 fail |
| imported lifecycle (`finalization_transition`) | 5 refs in `bin/polylane-run.sh` |

Nothing was overwritten in either direction: the merge combined `37079b3`
(main side) with the imported lifecycle + ported deltas (candidate side).

## Imported-contract SHA-256s, cross-checked fresh

Both frozen hashes in `docs/polylane/cycle-42a-outcome.md` were re-derived
from `4851bc1` in this worktree and match exactly:

- status SHA-256 `52c99513054a658f30277856ab04f7d810b672af870717721c86a80a4e93a033`
  = sha256(`4851bc1:docs/status-taste-contract-integrator.md`)
- integration-evidence SHA-256 `4eb179e6c543b04e181efa996815b8623821c8bb2a678ab720889e3d98e5fee2`
  = sha256(`4851bc1:docs/verify-integration.md`)

All 16 imported artifacts were re-hashed from the merged worktree; every one
is byte-identical to the hash in the builder's `docs/verify-contract-import.md`
tables (and, for the two the precheck lane addressed, to its recorded values):

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

Ported shared files in the merged tree: `bin/polylane-memory.sh`
`726e1ceac471b595268eb522c14788a4b27f10466c0c6193bd4622c6ffb46fd8` and
`tests/test-contract-acceptance.sh`
`f5757fd56fc5f72d7985f7053c351754e872b2e7486eaf3e4a18ae39d645e072` match the
builder's post-port hashes; `bin/polylane-supervisor.sh`
`d0cee637fa8a74f839a9fa7c397a73bbe744c9621bf394472e2e5b59c1e0f312` matches the
prior integrator's merged hash; `tests/test-lane-done-live.sh`
`eebfa0c7a0bfed9e282e9ffbed4c9dabb464bfefbee37336c4af03906d49da3e` is
byte-identical to the `4851bc1` blob (re-derived both sides this session).
`bin/polylane-run.sh` is
`35d8115b05ecb496fad65c87de0a742e5a47f5bcef47f7d3e652af2b3fb70ec1`, which
intentionally differs from the prior run's `0dd7013b…` because this merge
layers `37079b3`'s stall-detection delta on top of the same base.

## Relay request handled

The only pending request is `contract-import → integrator` seq=1 (the
`tests/test-lane-done-live.sh` 4-line needle swap) from run
`c43-recovery-20260818-a1`. It was resolved before this run: host commit
`77a83b3`, contained in the merged candidate, applied exactly the
`main → 4851bc1` delta. This lane re-proved the merged file byte-identical to
the `4851bc1` blob (hash above), watched the blocker assertion pass fresh
(`test-lane-done-live.sh`: 18 pass / 0 fail), and appended a `decision` event
to this run's relay recording the resolution. No ownership extension needed;
no repair needed. The `pending` view lists request events forever by design,
so seq=1 remains visible; the decision event is the durable record. No other
requests addressed to `integrator` at start, mid-run, or at the final read.

## Seams and repairs

`bin/polylane-seams.sh scan .` rc=0 and `git diff --check` clean, both run
before the acceptance chain. **No repairs were needed this run** — zero merge
conflicts, zero test failures, zero shellcheck findings.

## Fresh test totals — frozen m32.6 focused acceptance

The command was taken verbatim from `docs/polylane/max-state.json`
(`.accept[] | select(.sid=="m32.6") | .cmd`) and run **once to completion**
through `bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator"` on the
merged tree. A first attempt was killed at the harness's 10-minute tool
timeout (SIGTERM, rc=143) mid-suite; it cached **nothing** (no `.result`
entry — verified before relaunch, so no poisoned failure entry exists) and the
relaunched run is the sole and complete evidence. Cache receipt:
`CHECK-CACHE: PASS source=2445884898:185`, result file `2500133966-895.result`
= `2445884898:185|0`, full 5334-line log
`.polylane/check-cache/integrator/2500133966-895.output`. **Overall rc=0** —
the `&&` chain completed through every link:

| link | result |
|---|---|
| `tests/test-taste-execution-contract-v3.sh` | `1..43`, 43 ok / 0 not ok |
| `tests/test-evidence-dag.sh` | `ok - evidence-dag-v3 (95 assertions)` |
| `tests/test-taste-source-contract-v3.sh` | `ok - taste-source-contract-v3 (60 assertions)` |
| `tests/test-finalization-watchdog.sh` | 18 pass, 0 fail |
| `tests/test-contract-acceptance.sh` | 42 pass, 0 fail |
| `tests/test-verdict-repair.sh` | 61 pass, 0 fail |
| `tests/test-lane-done.sh` | 27 pass, 0 fail |
| `tests/test-lane-done-live.sh` | 18 pass, 0 fail |
| `tests/test-supervisor.sh` | 38 pass, 0 fail |
| `shellcheck -S warning` (8 scripts incl. merged run.sh/supervisor/memory) | clean (chain continued) |
| `tests/run.sh` (full suite) | **SUMMARY: 4073 passed, 0 failed, 173 test files** |
| `bin/polylane-markers.sh check-docs references/` | clean |
| `tests/test-skill-parity.sh` | 72 pass, 0 fail |
| `git diff --check` | clean (chain rc=0) |

The suite total is 4073 vs the prior run's 4070: the three new passes are
`37079b3`'s `tests/test-pane-stalled.sh` assertions (21 pass / 0 fail in this
log), present here because this merge includes `37079b3` and the prior run's
candidate predates it. Same 173 files. Zero `not ok` lines in the log; all 22
`FAIL`-word hits were inspected and every one is fixture text inside passing
tests (promote-failure fixtures, `TASTE-A11Y`/`TASTE-TASK` negative-case
fixtures, and `FAIL=0` counters).

## Limitations

- The remaining m32.6 certification is the coordinator's **host-owned
  terminal gate**; nothing here claims it. This lane produced a certified
  candidate at merge commit `72be7a4` only.
- `tests/test-graph-benchmark.sh` carries a timing-sensitive assertion
  (`benchmark-warm-append-under-250ms`). Green in this log on the suite run; a
  loaded host-gate run could still flake it, which would be load, not a
  regression from this merge.
- The three TAP-format imported tests (43/95/60 assertions) are gated by exit
  code in `tests/run.sh` but excluded from its `PASS`-line tally; their 198
  assertions are counted in the per-link table, not in the 4073.
- The prior run's actual host-gate failure was `restarts=1>0` — a runtime
  property of the run, not of the candidate. This lane cannot make a restart
  less likely; it only re-proves candidate integrity.
- Prior-run status/verify files arrived via the merge and are historical
  evidence at their merged refs; the working-tree copies of
  `docs/verify-integration.md` and `docs/status-integrator.md` now carry this
  run's nonce.
- No provider installs, no external actions, no subagents, no writes outside
  the integrator branch and the two owned handoff docs.

## Skill receipts and evidence

- SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
- SKILL-READ: superpowers:verification-before-completion | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/verification-before-completion/SKILL.md | 1896692335-3646

SKILL-EVIDENCE: engineering:testing-strategy — unused: the test plan is frozen
by the m32.6 acceptance command in `docs/polylane/max-state.json` and the
brief's seams-first cadence, so no coverage or test-architecture decision
remained for the skill to shape; the lane added no tests and changed no test
strategy.

SKILL-EVIDENCE: superpowers:verification-before-completion — helped: three
concrete places. (1) It forced independent re-derivation of all 19 artifact
hashes and both frozen c42a hashes from `4851bc1` in this worktree instead of
accepting the precheck/builder/prior-integrator tables — which is exactly the
equality proof the precheck lane's limitation 2 left open. (2) When the first
acceptance attempt died at the 10-minute tool timeout, the "no completion
claims without fresh evidence" rule meant treating rc=143 as no evidence at
all: the cache dir was inspected to confirm no poisoned `.result` entry before
relaunching, and only the completed rerun's rc=0 log is cited. (3) The
"read full output, count failures" step drove the `not ok`/`FAIL` scans of the
5334-line log, classifying all 22 `FAIL`-word hits as fixture text rather than
letting a grep count stand unexplained.

POLYLANE-VERDICT: READY-FOR-HOST-GATE run=c43c-recovery-20260819-a1
