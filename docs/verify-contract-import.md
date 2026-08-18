# verify — lane `contract-import` (run `c43-recovery-20260818-a1`, target m32.6)

Import of the frozen cycle-42a v3 contract work from the immutable handoff
`4851bc12e22ab2260c2baeb1d28c69d3ddebd23d`, reconciled with main's post-outage
fixes. All commands below were run fresh in this worktree; counts are the
observed output, not estimates.

## Provenance

| ref | commit |
|---|---|
| handoff (import source) | `4851bc12e22ab2260c2baeb1d28c69d3ddebd23d` |
| main at lane start | `b6772b17a964f4bd82415409d77f1dfddfaf58b6` |
| merge-base(main, handoff) | `5a4357c9b1e0153f80bb428c81cf835985f28025` |
| lane HEAD at import | `279139d98da959be0fcf016bb337347bd59677da` |

The two frozen hashes recorded in `docs/polylane/cycle-42a-outcome.md` were
re-derived from `4851bc1` and both match, confirming the import source is the
handoff and not a WIP tip above it:

- `52c99513054a658f30277856ab04f7d810b672af870717721c86a80a4e93a033`
  = `4851bc1:docs/status-taste-contract-integrator.md` (the "status SHA-256")
- `4eb179e6c543b04e181efa996815b8623821c8bb2a678ab720889e3d98e5fee2`
  = `4851bc1:docs/verify-integration.md` (the "integration-evidence SHA-256")

Neither `5e0066a` nor `1e89f4f` was read or imported from.

## Imported paths and SHA-256 (worktree bytes)

All eight `git checkout 4851bc1 -- …` targets were **absent** on main, so each is
a pure add with no reconciliation required. Every contract JSON was additionally
verified byte-identical to its `4851bc1` blob (`git cat-file blob` vs worktree).

### Contract payloads — `docs/polylane/taste-certification/contracts/`

| SHA-256 | file | blob matches `4851bc1` |
|---|---|---|
| `689ab890c339966b15f32a22f309a564f92d1ff34b354184425ffef0f8e41c34` | `CONTRACT-LOCK.v3.json` | yes |
| `00b2dc076bf74c2b511ef780f1cda796730ad4704a9d1ccb1f397f4d025864da` | `EVIDENCE-CLAIM-REGISTRY.v3.json` | yes |
| `b90e2148bc7cd1ee36d3f7dcf2b7b23eed63b9b5f2057943bb120cbb1c6438d2` | `evidence-dag-v3.schema.json` | yes |
| `8ff293fa72cc32ae52c3bf40a82fd4e67d06a2e24b534b0a323b97bd1cc5d7ee` | `evidence-policy-v3.json` | yes |
| `3b8d5fdeb31721caac38696464d84eb4157179d6bd0f06df4948a72bf689542e` | `execution-v3.example.json` | yes |
| `3175f71c2c07e0682f71485cb05b91df7cdc8f82ac47de07b0f4746e77d52db8` | `execution-v3.schema.json` | yes |
| `df881837618901c66ab9761788f00fc1e10091548a9f5e9f84afde727abd7fd9` | `source-calibration-v3.example.json` | yes |
| `651150db701f7aaf8d7d8201126f8e477a8d80880fc293ab96af03cec662bd9e` | `source-calibration-v3.schema.json` | yes |

### Executables and tests (pure adds)

| SHA-256 | file |
|---|---|
| `66164a629b76ce42de17fab8764275d6d154ffba305a657c9d327c696aa11b4a` | `bin/polylane-evidence-dag.sh` |
| `c64bbb0cc9181306f3dba97734ff5f030c8b332e749375c2700ea4d6ba30eb91` | `bin/polylane-finalize.sh` |
| `e16e52c37a108d1c4610a505f3c70e18e1fb2d4ecc729030f6c03c50b42637bb` | `bin/polylane-taste-execution-contract.sh` |
| `47c674b77203bb5f2cfdfce615c374a3d7318524ad28b4a10babaf55633a57e4` | `bin/polylane-taste-source-contract.sh` |
| `d09805179ff0def2f756b2b795a99f49a0456226ceb359692369565674e706b4` | `tests/test-evidence-dag.sh` |
| `c3846f43787ed72a35b9574b94e207177df2d4f075d93884e383ad2ffb6011c4` | `tests/test-finalization-watchdog.sh` |
| `f91907b832c8c6bef1298f7395197b37d6288532aa1bf9faa335fee722a64e60` | `tests/test-taste-execution-contract-v3.sh` |
| `d7d53c4ef2e24713a06386270881d559703e70bd94566bda332280a9540b2be2` | `tests/test-taste-source-contract-v3.sh` |

File modes were carried from the handoff index verbatim
(`test-evidence-dag.sh` and `test-taste-execution-contract-v3.sh` are `100644`,
the other two `100755`). `tests/run.sh:16` invokes every test through
`"${BASH:-bash}" "$t"`, so the mode is not load-bearing.

## Port decisions for the four shared files

No file was wholesale-overwritten. Every port was computed against the
merge-base so main's post-handoff work is preserved by construction.

### `bin/polylane-memory.sh` — applied the handoff delta directly

`git diff main 4851bc1 -- bin/polylane-memory.sh` contains **only** the c42a
`--evidence-kind` extension (main made no post-handoff change to this file), so
`git apply` of that diff is identical to a port and cannot drop main work.
Applied with `git apply --check` first; 30 insertions / 13 deletions.

What landed: `--evidence-kind autonomous|external` on `add-accept` and
`check-accept`, the mixed-kind refusal on a sub-goal, kind-scoping of the
memoization fingerprint and of the `--key` dedupe channel (`$_kind:$_key:…`
rather than `$_key:…`), and kind display in `unmet-accept` / `regressions`.

Post-port SHA-256: `726e1ceac471b595268eb522c14788a4b27f10466c0c6193bd4622c6ffb46fd8`.

### `tests/test-contract-acceptance.sh` — applied the handoff delta directly

Same situation: the `main → 4851bc1` diff is purely additive (a shellcheck
directive plus 53 lines of new assertions covering evidence-kind routing,
mixed-kind rejection, `EXTERNAL-EVIDENCE-OPEN` not masking a failed autonomous
check, and the m32.4 source-pinned certificate predicate). Applied as-is.

Post-port SHA-256: `f5757fd56fc5f72d7985f7053c351754e872b2e7486eaf3e4a18ae39d645e072`.

### `bin/polylane-run.sh` and `bin/polylane-supervisor.sh` — three-way merge

These are the only genuinely divergent files. Both sides changed them:

- `merge-base → main`: 21 insertions total (`fb0a7b0` supervisor dying-words,
  `9060a63` login-expired lane parking + doctor auth preflight, `3a3e3d8`
  model-detection / `claude-opus-5`).
- `merge-base → 4851bc1`: 422 changed lines in the runner, 47 in the supervisor.

Port method: `git diff <merge-base> 4851bc1 -- <both files> | git apply -3`.
Feeding the **base-relative** diff (not the `main`-relative one) is what makes
this a port rather than an overwrite — a `main → 4851bc1` diff would have
carried main's additions as *deletions*. `git apply -3` reported both files
applied cleanly; zero conflict markers remain
(`grep -c '^<<<<<<<\|^=======$\|^>>>>>>>'` = 0 in each).

Every main-side gain was then re-confirmed present by grep in the merged files:

| main gain | evidence in merged file |
|---|---|
| login-expired lane parking | `bin/polylane-run.sh` — `Login expired` branch in `startup_check` |
| parked lanes skip respawn | `bin/polylane-run.sh` — `lane_needs_decision "$name" && continue` in `health_check` |
| model detection / opus-5 ladder | `bin/polylane-run.sh:3419` fallback ladder includes `claude-opus-5` |
| opus-5 pricing | `bin/polylane-run.sh:5202` `claude-opus-5*) echo 25` |
| supervisor dying words | `bin/polylane-supervisor.sh` — `last_err` (6 refs), `last error:` in all three report paths |
| doctor `check_auth` | `bin/polylane-doctor.sh` untouched by this lane (3 refs intact) |

Post-port SHA-256: runner
`e2e18ad2e05b6e65b02eb19ad37ab5e5f437993744b50a4bb47f0fa12ac7f477`, supervisor
`d0cee637fa8a74f839a9fa7c397a73bbe744c9621bf394472e2e5b59c1e0f312`.

The runner delta is not prose-only: `finalization_state_file` /
`finalization_state_get` / `finalization_transition` and the `lane_done`
READY-handoff path now drive `bin/polylane-finalize.sh transition`
(`bin/polylane-run.sh:2490-2510`), which is the lifecycle half of m32.6.

## Fresh test counts

Every command below was run in this worktree after the import.

### Imported v3 checks

| command | rc | assertions |
|---|---|---|
| `bash tests/test-taste-execution-contract-v3.sh` | 0 | 43 ok, 0 not ok (`1..43`) |
| `bash tests/test-evidence-dag.sh` | 0 | `ok - evidence-dag-v3 (95 assertions)` |
| `bash tests/test-taste-source-contract-v3.sh` | 0 | `ok - taste-source-contract-v3 (60 assertions)` |
| `bash tests/test-finalization-watchdog.sh` | 0 | 18 PASS, 0 FAIL |
| `bash tests/test-contract-acceptance.sh` | 0 | 42 PASS, 0 FAIL |

### Runner / supervisor regression set (must-stay-green)

| command | rc | counts |
|---|---|---|
| `bash tests/test-supervisor.sh` | 0 | 38 PASS, 0 FAIL |
| `bash tests/test-auth-park.sh` | 0 | 8 PASS, 0 FAIL |
| `bash tests/test-doctor-auth.sh` | 0 | 8 PASS, 0 FAIL |
| `bash tests/test-models.sh` | 0 | 32 PASS, 0 FAIL |
| `bash tests/test-lane-done.sh` | 0 | 27 PASS, 0 FAIL |
| `bash tests/test-verdict-repair.sh` | 0 | 61 PASS, 0 FAIL |
| `bash tests/test-lane-done-live.sh` | **1** | 17 PASS, **1 FAIL** — see blocker below |

Additional paired-delta files checked because their `4851bc1` versions differ
from main's: `tests/test-hooks.sh` 53 PASS/0 FAIL, `tests/test-memory.sh`
62 PASS/0 FAIL, `tests/test-accept-dedupe.sh` 29 PASS/0 FAIL,
`tests/test-project-generality.sh` rc=0 (`1..35`),
`tests/test-certify-economy.sh` 6 PASS/0 FAIL. All main versions, all green
against the ported sources.

### Static gates from the m32.6 command

| command | rc |
|---|---|
| `shellcheck -S warning bin/polylane-taste-execution-contract.sh bin/polylane-evidence-dag.sh bin/polylane-taste-source-contract.sh bin/polylane-finalize.sh bin/polylane-memory.sh bin/polylane-run.sh bin/polylane-supervisor.sh assets/verify-gate.sh` | 0 |
| `bin/polylane-markers.sh check-docs references/` | 0 |
| `bash tests/test-skill-parity.sh` | 0 (72 PASS, 0 FAIL) |
| `git diff --check` | 0 |
| `bash -n` on all seven touched/imported bin scripts | 0 each |

### Full m32.6 focused acceptance

The frozen command was taken verbatim from `docs/polylane/max-state.json`
(`.accept[] | select(.sid=="m32.6") | .cmd`) and run once via `eval`.

**Result: rc=1 — NOT passing.** It short-circuits at the eighth link,
`tests/test-lane-done-live.sh`. Every stage before it passed:

```
1..43                                          # test-taste-execution-contract-v3.sh
ok - evidence-dag-v3 (95 assertions)           # test-evidence-dag.sh
ok - taste-source-contract-v3 (60 assertions)  # test-taste-source-contract-v3.sh
test-finalization-watchdog.sh: 18 pass, 0 fail
test-contract-acceptance.sh:   42 pass, 0 fail
test-verdict-repair.sh:        61 pass, 0 fail
test-lane-done.sh:             27 pass, 0 fail
test-lane-done-live.sh:        17 pass, 1 fail   <-- stops here, rc=1
```

The `&&` chain never reached `tests/test-supervisor.sh`, `shellcheck`,
`tests/run.sh`, `bin/polylane-markers.sh check-docs`,
`tests/test-skill-parity.sh`, or `git diff --check` — but every one of those was
run independently in this worktree and is green (tables above, plus the full
suite below). The single blocker is documented in the next section.

### Full suite (`tests/run.sh`), run separately

```
SUMMARY: 4060 passed, 2 failed, 173 test files
FAILED FILES: test-graph-benchmark.sh test-lane-done-live.sh
```

- `test-lane-done-live.sh` — the known blocker below.
- `test-graph-benchmark.sh` — `benchmark-warm-append-under-250ms`, a wall-clock
  perf assertion on `bin/polylane-graph-events.sh`. That script is **not touched
  by this lane**. The failure did not reproduce: re-run 3× unloaded after the
  suite finished, 17 PASS / 0 FAIL each time. It failed inside the suite because
  other lane work was competing for CPU on this host. Load-induced flake, not a
  regression from the import.

Excluding those two files the suite is 4060 assertions green.


## Blocker: one assertion outside this lane's OWN set

`tests/test-lane-done-live.sh` fails exactly one assertion,
`runtime-integrator-verdict-has-canonical-path`, and this failure is caused by
the import — it is green on main (`b6772b1`, verified by running the test in a
throwaway worktree of main: rc=0, 0 FAIL).

Root cause, not symptom: the c42a delta to `bin/polylane-run.sh`
(`inject_runtime_prompt_contract`, line 970) replaces the integrator
`POLYLANE-RUNTIME-FINALIZE` block so the worker invokes
`bin/polylane-finalize.sh` instead of hand-writing the verdict sentinel. That is
the lifecycle contract m32.6 exists to freeze, so it must land. `4851bc1`
updated the two integrator assertions in `tests/test-lane-done-live.sh` in the
same commit — the delta is one atomic artifact:

```
-  "write the only current-run POLYLANE-VERDICT sentinel as the final line of docs/verify-integration.md" \
+  'polylane-finalize.sh" --project-root' \
...
-  "never write a POLYLANE-VERDICT line in docs/status-integrator.md" \
+  "worker-invoked finalizer alone writes the only current-run POLYLANE-VERDICT sentinel" \
```

`tests/test-lane-done-live.sh` is not in this lane's OWN set, and
`docs/polylane/recovery-c43/c43-integrator.txt:16` shows the integrator owns
only its branch and its two handoff docs — so no c43 lane owns this file. That
is a gap in the cycle-43 lane scoping, not a defect in the import.

I did not edit the file (FORBIDDEN) and I did not reword the imported prompt
text to make main's stale needle match, because rephrasing frozen
content-addressed prose to satisfy a test is a symptom fix that would also break
the handoff's own replacement needle when it is eventually applied.

**Relayed** to `integrator` via
`bin/polylane-coordinate.sh request … contract-import integrator …` with the
exact repair. Repair command for whoever owns it:

```bash
git diff main 4851bc1 -- tests/test-lane-done-live.sh | git apply -
```

Until that lands, the m32.6 focused acceptance command cannot reach `tests/run.sh`:
`tests/test-lane-done-live.sh` is chained with `&&` and short-circuits the rest.

## Limitations

- **The m32.6 focused acceptance does not pass.** It stops at
  `tests/test-lane-done-live.sh` with rc=1. This lane cannot fix it without
  writing a FORBIDDEN file; the exact one-line repair and the relay are above.
  Everything else in the command was run independently and is green.
- The `test-graph-benchmark.sh` perf assertion is timing-sensitive under host
  load. It is green standalone (3/3) but can flake inside a loaded full-suite
  run; do not read a green suite as proof that it is deterministic.
- Three imported tests (`test-taste-execution-contract-v3.sh`,
  `test-evidence-dag.sh`, `test-taste-source-contract-v3.sh`) emit TAP
  (`ok - …`) rather than this repo's `PASS ` convention, so `tests/run.sh`'s
  assertion tally does not include their 198 assertions. They are still gated
  correctly: each exits non-zero on failure and `tests/run.sh:24` fails a file on
  `rc -ne 0`, so a regression cannot pass silently. Left as imported — the files
  are content-addressed artifacts and reformatting them would break provenance.
- No provider, network, install, or browsing action was taken. All git reads were
  of local refs. No doctor rehearsal was run (host owns the terminal boundary).
- No subagents were spawned.
- `bin/polylane-doctor.sh` was read-only here; its `check_auth` is untouched by
  this lane and its test is green.

## Skill evidence

- SKILL-READ: superpowers:systematic-debugging | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/systematic-debugging/SKILL.md | 4111822586-9465
- SKILL-READ: superpowers:verification-before-completion | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/verification-before-completion/SKILL.md | 1896692335-3646

SKILL-EVIDENCE: superpowers:systematic-debugging — helped: its "check recent
changes / find working examples" phase is what stopped me from patching the
`test-lane-done-live.sh` failure at the symptom. I first reproduced the test on
a clean throwaway worktree of `main` (rc=0), which proved the import caused it,
then traced it back through `inject_runtime_prompt_contract` to the c42a
lifecycle rewrite and found the paired assertion update inside the same handoff
commit. The tempting quick fix — rewording the imported prompt so main's old
needle matched — would have satisfied the test while silently corrupting a
content-addressed artifact and planting a failure for whoever later applies the
handoff's own test delta.

SKILL-EVIDENCE: superpowers:verification-before-completion — helped: three of
the imported v3 tests returned rc=0 with `0 pass, 0 fail` under this repo's
`^PASS ` counting. The gate function ("does the output actually confirm the
claim?") made me open the raw output instead of recording a green, which
surfaced the TAP-vs-PASS format difference, the real 43/95/60 assertion counts,
and — more importantly — sent me to `tests/run.sh:24` to confirm those files are
still gated by exit code rather than silently uncounted.
