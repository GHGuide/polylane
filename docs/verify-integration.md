# verify — lane `integrator` (run `c43-recovery-20260818-a1`, target m32.6)

Integration of `lane/c43-contract-import` onto the integrator branch, with fresh
verification of the imported v3 contracts, the ported runtime deltas, and the
frozen m32.6 focused acceptance. Every count below is observed output from
commands run fresh in this worktree during this lane, not carried over from the
builder's report.

## Branch tips and merge

| ref | commit |
|---|---|
| `lane/c43-integrator` pre-merge (== `main`) | `b6772b17a964f4bd82415409d77f1dfddfaf58b6` |
| `lane/c43-contract-import` tip at merge | `77a83b33c7d3fde581a57e32d1ebeaa2521bddca` |
| merge-base(main, contract-import) | `279139d98da959be0fcf016bb337347bd59677da` |
| merge commit (`--no-ff`, ort, zero conflicts) | `1feb098cca80261a8d5327b266376cd743e45da1` |
| import handoff source | `4851bc12e22ab2260c2baeb1d28c69d3ddebd23d` |

The lane tip moved mid-session: the builder's handoff was `6d8048f`, and the
host added `77a83b3` ("import the 4851bc1 test-lane-done-live update the lane
scoping missed") at 23:35 local, minutes after this lane's first ref read. Per
the brief ("current branch tip, not a memorized hash") the merge was taken from
the live ref; `HEAD^2 = 77a83b3` confirms the repair commit is included.

## Relay request handled

`contract-import` relayed (seq=1) a scope gap: the c42a lifecycle delta to
`bin/polylane-run.sh` needs a paired 4-line assertion update in
`tests/test-lane-done-live.sh`, which no c43 lane owns. Handling:

- Host commit `77a83b3` had already applied it on the lane branch. I verified
  the applied hunk is exactly the `main → 4851bc1` delta for that file and that
  the resulting file is **byte-identical** to the `4851bc1` blob
  (`eebfa0c7a0bfed9e282e9ffbed4c9dabb464bfefbee37336c4af03906d49da3e` both
  sides). No divergent or hand-rewritten variant slipped in.
- A `decision` event was appended to the relay recording the resolution; no
  ownership extension was needed and no further repair was required. The
  builder-reported blocker assertion (`runtime-integrator-verdict-has-canonical-path`)
  now passes: `test-lane-done-live.sh` is 18 pass / 0 fail (was 17/1 in the
  builder's worktree).

## Import verified as port, not overwrite

Ancestry: `main` is **not** an ancestor of the lane branch (it forked at
`279139d`, one commit before `b6772b1`), so the merge — not the import — is
what reconciles `b6772b1`. Checked both sides independently by grep on the
lane tip and then on the merged files:

| main's post-handoff gain | lane tip (pre-merge) | merged worktree |
|---|---|---|
| doctor `check_auth` | 3 refs | 3 refs |
| login-expired parking (`Login expired` in run.sh) | present | present |
| parked lanes skip respawn (`lane_needs_decision`) | 4 refs | 4 refs |
| model detection / `claude-opus-5` ladder + pricing | 2 refs | 2 refs |
| supervisor dying-words (`last_err`) | 6 refs | 6 refs |
| `b6772b1` safe-read auto-approve (`approval_is_safe_read`) | 0 refs (forked before it) | 3 refs (restored by merge) |
| imported lifecycle (`finalization_transition`) | 5 refs | 5 refs |

The one main-side fix the lane branch could not contain (`b6772b1`) is present
after the merge alongside the imported lifecycle helpers — nothing was
overwritten in either direction. `git diff --check` clean; `bin/polylane-seams.sh
scan .` rc=0.

## Imported-contract SHA-256s, cross-checked

Both frozen hashes in `docs/polylane/cycle-42a-outcome.md` were re-derived
from `4851bc1` in this worktree and match exactly:

- status SHA-256 `52c99513054a658f30277856ab04f7d810b672af870717721c86a80a4e93a033`
  = sha256(`4851bc1:docs/status-taste-contract-integrator.md`)
- integration-evidence SHA-256 `4eb179e6c543b04e181efa996815b8623821c8bb2a678ab720889e3d98e5fee2`
  = sha256(`4851bc1:docs/verify-integration.md`)

All 16 imported artifacts were re-hashed from the **merged worktree** and each
is byte-identical to its `4851bc1` blob and to the hash in the builder's
`docs/verify-contract-import.md` tables:

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
`726e1cea…46fd8` and `bin/polylane-supervisor.sh` `d0cee637…e0f312` match the
builder's post-port hashes; `bin/polylane-run.sh` is
`0dd7013bc5127ae6a87d6faff0e8cced29c2d1db484d44b90b0c93cfdebf8370`, which
intentionally differs from the builder's hash because the merge layered
`b6772b1`'s safe-read/unpark delta on top; `tests/test-lane-done-live.sh`
`eebfa0c7…49da3e` equals the `4851bc1` blob.

## Fresh test totals — frozen m32.6 focused acceptance

The command was taken verbatim from `docs/polylane/max-state.json`
(`.accept[] | select(.sid=="m32.6") | .cmd`) and run **once** through
`bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator"` on the merged
tree. Cache result: `CHECK-CACHE: PASS source=2859499042:14317`, full log
`.polylane/check-cache/integrator/2121586317-894.output`. **Overall rc=0** —
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
| `tests/test-lane-done-live.sh` | **18 pass, 0 fail** (builder's blocker cleared) |
| `tests/test-supervisor.sh` | 38 pass, 0 fail |
| `shellcheck -S warning` (8 scripts incl. merged run.sh/supervisor/memory) | clean (chain continued) |
| `tests/run.sh` (full suite) | **SUMMARY: 4070 passed, 0 failed, 173 test files** |
| `bin/polylane-markers.sh check-docs references/` | clean |
| `tests/test-skill-parity.sh` | 72 pass, 0 fail |
| `git diff --check` | clean (chain rc=0) |

The builder's two full-suite failures are both resolved in this run:
`test-lane-done-live.sh` by the `77a83b3` repair, and
`test-graph-benchmark.sh` (a load-induced wall-clock flake per the builder's
3× standalone re-runs) did not recur — the suite is 0 failed with zero `not ok`
lines in the log.

## Limitations

- The remaining m32.6 certification is the coordinator's **host-owned terminal
  gate**; nothing here claims it. This lane produced a certified candidate at
  merge commit `1feb098` only.
- `tests/test-graph-benchmark.sh` carries a timing-sensitive assertion
  (`benchmark-warm-append-under-250ms`). Green here on an unloaded host; a
  loaded host-gate run could still flake it, which would be load, not a
  regression from this merge.
- The three TAP-format imported tests (43/95/60 assertions) are excluded from
  `tests/run.sh`'s `PASS`-line tally but are gated by exit code
  (`tests/run.sh:24`); their 198 assertions are counted in the per-link table
  above, not in the 4070.
- The relay's `pending` view lists request events forever (no consumed flag);
  seq=1 remains visible by design. The appended `decision` event is the durable
  record that it was handled.
- No provider installs, no external actions, no subagents, no writes outside
  the integrator branch and the two owned handoff docs.

## Skill receipts and evidence

- SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
- SKILL-READ: superpowers:verification-before-completion | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/verification-before-completion/SKILL.md | 1896692335-3646

SKILL-EVIDENCE: engineering:testing-strategy — unused: the test plan for this
lane is frozen by the m32.6 acceptance command in `docs/polylane/max-state.json`
and the brief's seams-first cadence, so there were no coverage or
test-architecture decisions left for the skill to shape; the cheap-before-
expensive ordering (grep symbol checks, then seams, then the one cached suite
run) was already mandated by TEST-CADENCE.

SKILL-EVIDENCE: superpowers:verification-before-completion — helped: it forced
independent re-derivation instead of trusting the builder's report, which
surfaced a real discrepancy — the builder's verify file states it never edited
`tests/test-lane-done-live.sh`, yet the branch diff showed a 4-line change to
exactly that file. Following "agent said success → verify independently" led to
the host commit `77a83b3` (made minutes into this session), and to proving the
applied hunk equals the `4851bc1` delta byte-for-byte before accepting the
merge; it also kept the acceptance claim tied to this run's fresh rc=0 log
rather than the builder's pre-repair rc=1 numbers.

POLYLANE-VERDICT: READY-FOR-HOST-GATE run=c43-recovery-20260818-a1
