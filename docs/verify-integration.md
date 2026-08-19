# verify — lane `integrator` (run `c43e-recovery-20260819-a1`, target m32.6)

Fresh integration of the c43 candidate onto current `main`. Every count and
hash below is observed output from commands run fresh in this worktree
(`.polylane/worktrees/c43e-integrator`) during this lane; the precheck,
c43d-integrator, and contract-import reports were read and then independently
re-derived, never copied. Prior-run status/verify files arriving via the merge
remain committed as historical evidence; this file and
`docs/status-integrator.md` are the only current-run handoff artifacts.

## Branch tips and merges (current tips, verified fresh — not memorized hashes)

| ref | commit |
|---|---|
| `main` | `1ca5262afbe091eb44b55587f3448236d8f13e14` |
| `lane/c43e-precheck` tip | `376bd44b063f3b7f295854c94cc10bcb7f4d5977` |
| `lane/c43d-integrator` (candidate) tip | `6579bc242811c7e1ccfe89deec6fc1a5bdf0f66f` |
| merge 1 (`--no-ff`, zero conflicts): precheck | `0fc695f` |
| merge 2 (`--no-ff`, 3 conflicts, resolved below): candidate | `d38794e` |
| lane HEAD after merges | `d38794ed0d5d1cdcb7c9a79081d8434fac2e5786` |

The brief named `lane/c43b-precheck`; no such branch exists on any ref — that
run was cleaned up before this run launched. This run's fresh precheck lane is
`lane/c43e-precheck` (its `docs/status-precheck.md` carries this run's nonce
`c43e-recovery-20260819-a1`), merged under the brief's controlling "current
branch tips, not memorized hashes" rule. The brief's
`docs/verify-import-verify.md` likewise exists on no ref; the builder's actual
import evidence is `docs/verify-contract-import.md`, present in the merged tree.

Ancestry, proven with `git merge-base --is-ancestor` before merging:

- `main` (`1ca5262`) IS an ancestor of `lane/c43e-precheck` (rc=0).
- `main` is NOT an ancestor of `lane/c43d-integrator` (rc=1); merge-base is
  `7e4e35e`. The gap is exactly one commit — `1ca5262` ("CPU burn … quiesce
  /exit retries") — which landed on `main` after the c43d handoff. Every named
  post-handoff fix commit (`279139d`, `b6772b1`, `37079b3`, `7e4e35e`) IS an
  ancestor of the candidate (all rc=0). The candidate lost nothing; it merely
  predates `1ca5262`, and this lane's HEAD carried `1ca5262`, so merge 2
  reconciles both sides.

Both verify files were read in full before merging:
`lane/c43e-precheck:docs/verify-precheck.md` (4 PASS / 1 FAIL — the FAIL being
its correct merge-ort prediction of exactly the two `bin/polylane-run.sh`
conflicts resolved below; its SHA-256 spot-checks re-derived here) and
`lane/c43d-integrator:docs/verify-integration.md` (repair round 1, m32.6 chain
rc=0, suite 4077/0/173 on the candidate tree; its full hash tables re-derived
here).

## Conflict resolutions (this lane's only source edits)

Merge 2 stopped on 3 conflicts, resolved in `d38794e`:

1. **`bin/polylane-run.sh` — `quiesce_done_pane` (~line 2672).** `main`'s
   bounded-retry counter (`POLYLANE_QUIESCE_MAX`, `1ca5262`) kept verbatim,
   then the candidate's contract-gated lifecycle call
   (`ORCHESTRATION_CONTRACT >= 3` → `finalization_transition … QUIESCING`)
   appended before `pane_send_exit` — matching the candidate's own
   marker-then-transition-then-send ordering. Neither side's behavior dropped;
   `main`'s surviving comment above the hunk documents the bounded-retry
   rationale the resolution preserves.
2. **`bin/polylane-run.sh` — `pane_wedged` (~line 3851).** The candidate's
   structure kept (pre-v3 body wrapped in `ORCHESTRATION_CONTRACT < 3`, v3
   durable-fingerprint path after it), with `main`'s work signal swapped in:
   `pane_tool_child_running "$idx"` → `pane_burning_cpu "$name" "$idx"`
   inside the `< 3` branch (the `1ca5262` fix — MCP servers cannot mask idle
   agents). The candidate's wider `local` list is a superset of `main`'s and
   was kept as-is. The v3 path intentionally left untouched (property of both
   parents; see limitations).
3. **`docs/status-precheck.md` + `docs/verify-precheck.md` (add/add).** This
   run's fresh c43e versions kept (current nonce); the c43d-precheck versions
   remain reachable in history via the merge's second parent.

After resolution: zero conflict markers, `bash -n` clean,
`shellcheck -S warning bin/polylane-run.sh` clean.

## Candidate did not lose main's post-handoff fixes (grepped fresh, merged tree)

| fix | evidence in merged tree |
|---|---|
| doctor `check_auth` preflight | 3 refs in `bin/polylane-doctor.sh` |
| login-expired parking (`Login expired`) | 2 refs in `bin/polylane-run.sh` |
| safe-read approvals (`approval_is_safe_read`) | 3 refs in `bin/polylane-run.sh` |
| parked lanes skip respawn (`lane_needs_decision`) | 4 refs in `bin/polylane-run.sh` |
| supervisor dying-words (`last_err`) | 6 refs in `bin/polylane-supervisor.sh` |
| model detection (`claude-opus-5` ladder) | 2 refs in `bin/polylane-run.sh` |
| `37079b3` usage-limit stall (`usage-credits`) | 4 refs in `bin/polylane-run.sh` |
| `1ca5262` CPU-burn work signal (`pane_burning_cpu`) | 3 refs in `bin/polylane-run.sh`; `test-wedge.sh` 38/0 |
| `1ca5262` bounded quiesce (`POLYLANE_QUIESCE_MAX`) | 1 ref in `bin/polylane-run.sh`; `test-taste-runner-e2e.sh` 23/0 |
| imported v3 lifecycle (`finalization_transition`) | 5 refs in `bin/polylane-run.sh` |

## Imported-contract SHA-256s, re-derived fresh and cross-checked

Both frozen hashes in `docs/polylane/cycle-42a-outcome.md` re-derived from the
immutable handoff `4851bc1` and matched exactly:

- `52c99513054a658f30277856ab04f7d810b672af870717721c86a80a4e93a033`
  = sha256(`4851bc1:docs/status-taste-contract-integrator.md`)
- `4eb179e6c543b04e181efa996815b8623821c8bb2a678ab720889e3d98e5fee2`
  = sha256(`4851bc1:docs/verify-integration.md`)

All 16 imported artifacts re-hashed from the merged worktree; every one is
byte-identical to the precheck's spot-checks and the c43d/builder tables
(contract JSONs under `docs/polylane/taste-certification/contracts/`):

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

Ported/shared files in the merged tree: `bin/polylane-supervisor.sh`
`d0cee637fa8a74f839a9fa7c397a73bbe744c9621bf394472e2e5b59c1e0f312`,
`bin/polylane-memory.sh`
`726e1ceac471b595268eb522c14788a4b27f10466c0c6193bd4622c6ffb46fd8`,
`bin/polylane-workers.sh`
`a8a57d0a5ea1fe809102a56a84ad1102290c14d622605936c7f9bdc58c45ae3f`,
`tests/helpers.sh`
`9c4e7e1968523948b5e54e8feb58f9e345e2b4678b2a1d49d207ee824ac8dc76`,
`tests/test-workers.sh`
`f6a6a41b783150b5a2f6af6e5dce0ac4b2d5874fe7f88678581be0b6d1df3dac`,
`tests/test-lane-done-live.sh`
`eebfa0c7a0bfed9e282e9ffbed4c9dabb464bfefbee37336c4af03906d49da3e`
(still byte-identical to the `4851bc1` blob) — all byte-identical to the c43d
record. `bin/polylane-run.sh` is necessarily new after the conflict
resolution:
`18ebbc92a4667950f32a2e22ab7121439091170c970200026e9587ec1e50e298`
(candidate `8e371d1f…` + `1ca5262`'s bounded quiesce and CPU-burn deltas).
None of the 16 imported artifacts was touched by the resolutions.

## Relay requests handled

Start-of-lane and final `pending` reads both list only the historical
`contract-import → integrator` seq=1 request (run `c43-recovery-20260818-a1`,
the `test-lane-done-live.sh` needle swap); `pending` lists request events
forever by design. Verified already satisfied in the merged tree — both
needles present (`polylane-finalize.sh" --project-root` ×1, the
worker-invoked-finalizer sentinel line ×1), imported via candidate ancestry
including host commit `77a83b3` — and a decision event recording this was
appended to the relay this lane. The durable worker inbox holds 18
relay-imported messages, all from completed prior runs (c15, c37, c38, c42a);
zero messages carry this run's `run_id`. No autonomous work was addressed to
this lane on either channel.

## Seams

`bin/polylane-seams.sh scan .` rc=0 and `git diff --check` clean, run after
the merge resolutions and before the acceptance chain.

## Fresh test totals — frozen m32.6 focused acceptance

Command taken verbatim from `docs/polylane/max-state.json`
(`.accept[] | select(.sid=="m32.6") | .cmd`) and run **once to completion**
through `bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator"` on the
merged tree. The merge changed the source fingerprint, so the cache correctly
re-ran live (`CHECK-CACHE: RUN` → `CHECK-CACHE: PASS source=1985302630:185`),
full 5341-line log
`.polylane/check-cache/integrator/3151446088-895.output`. **Overall rc=0** —
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
| `tests/run.sh` (full suite) | **SUMMARY: 4080 passed, 0 failed, 173 test files** |
| `bin/polylane-markers.sh check-docs references/` | clean (chain continued) |
| `tests/test-skill-parity.sh` | 72 pass, 0 fail |
| `git diff --check` | clean (chain rc=0) |

Zero `not ok` lines in the whole log. The suite total is 4080 vs the c43d
candidate's 4077; the +3 delta is fully attributed to `1ca5262`'s own test
additions in the only two test files it touched — `tests/test-wedge.sh`
(37→38, the CPU-burn assertion) and `tests/test-taste-runner-e2e.sh` (+2, the
bounded-retry quiesce assertions, 23/0 in this log) — now counted because the
merged tree contains `1ca5262`, which the candidate tree did not. Same 173
files.

## Limitations

- The remaining m32.6 certification is the coordinator's **host-owned
  terminal gate**; nothing here claims it. This lane produced a certified
  candidate at `d38794e` (merge of `376bd44` + `6579bc2` with conflicts
  resolved) only.
- The two `pane_wedged`/`quiesce_done_pane` resolutions are proven by the
  frozen suite (which includes `1ca5262`'s and the candidate's regression
  tests together going green on the merged code), not by a new live wedge
  rehearsal. The v3 durable-fingerprint `pane_wedged()` path still has no
  tool-child/CPU-burn guard — a property of both parents, unchanged here and
  covered by no frozen test; carried forward from the c43d record, not
  repaired, since no owned frozen check fails on it.
- The three TAP-format imported tests (43/95/60 assertions) are gated by exit
  code in `tests/run.sh` but excluded from its `PASS`-line tally; their 198
  assertions appear in the per-link table, not in the 4080.
- c43d's flagged residuals stand unchanged: `_accept_run` still forwards
  `REPO_ROOT` to nested commands (hermeticity fix lives in
  `tests/helpers.sh`), and `tests/test-graph-benchmark.sh` remains
  timing-sensitive under load (green in this log).
- Restart telemetry is the runner's; this lane cannot alter the run's
  efficiency accounting, only certify candidate integrity.
- No provider installs, no external actions, no subagents, no writes outside
  the integrator branch and the two owned handoff docs. Runner-owned
  untracked `.polylane-prompt.txt` and `graphify-out` left untouched.

## Skill receipts and evidence

- SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
- SKILL-READ: superpowers:verification-before-completion | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/verification-before-completion/SKILL.md | 1896692335-3646

Both fingerprints recomputed from the files as read (`cksum < SKILL.md`) and
matching the brief's selected records.

SKILL-EVIDENCE: engineering:testing-strategy — helped: its "focus on
data integrity and error handling, skip trivial coverage" framing set this
lane's verification order — hash-integrity of the 16 frozen artifacts and the
ancestry/fix-survival checks ran before any test, and the merge conflict
resolutions were validated by the existing frozen regression suites (both
parents' assertions green together on the merged code) instead of by writing
new redundant tests over unchanged behavior.

SKILL-EVIDENCE: superpowers:verification-before-completion — helped: three
concrete places. (1) The 4077→4080 suite delta was traced to `1ca5262`'s two
touched test files (`git show 1ca5262 --stat`, per-file 37→38 and 23/0
counts) before the suite was called clean, rather than assumed benign.
(2) The relay seq=1 request was answered only after grepping both exact
needles in the merged `tests/test-lane-done-live.sh` (1 hit each), not from
the candidate's report that it was resolved. (3) The acceptance claim waited
for `CHECK-CACHE: PASS` plus a zero `not ok` grep over the full 5341-line
log; the interim "cache miss, running" state was reported as in-progress,
not success.

POLYLANE-VERDICT: READY-FOR-HOST-GATE run=c43e-recovery-20260819-a1
