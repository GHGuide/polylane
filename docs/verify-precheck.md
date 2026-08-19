# verify — lane `precheck` (run `c43d-recovery-20260819-a1`, target m32.6)

Fresh, read-only re-proof of the verified cycle-43 candidate `lane/c43c-integrator`
against the current state of `main`. Every command below was run once, fresh, in
this worktree during this lane; every output block is verbatim. This lane merged
nothing, edited no source, ran no tests, and took no external action.

Worktree HEAD at lane start: `7e4e35e8e4def5a10278b71a49041216059abf65` (== `main`).

**Headline: four of five checks pass; check 3 fails.** The candidate is intact and
content-addressed, but it is **not** conflict-free against `main` as `main` stands
now. Exactly one conflict, in one file, in one hunk — characterised in full below.

---

## Check 1 — candidate contains current main's fixes

The brief pins the ancestor as `b6772b1`. That commit is no longer `main`'s tip:
`main` advanced to `7e4e35e` (via `37079b3`) after the brief was written, so the
check was run against the pinned commit **and** against the live tip, because the
brief's stated intent is "current main's fixes".

```
$ git merge-base --is-ancestor b6772b1 lane/c43c-integrator; echo "rc=$?"
rc=0

$ git merge-base --is-ancestor 7e4e35e lane/c43c-integrator; echo "rc=$?"
rc=1

$ git merge-base --is-ancestor 37079b3 lane/c43c-integrator; echo "rc=$?"
rc=0

$ git rev-parse main HEAD b6772b1
7e4e35e8e4def5a10278b71a49041216059abf65
7e4e35e8e4def5a10278b71a49041216059abf65
b6772b17a964f4bd82415409d77f1dfddfaf58b6
```

**PASS as specified, with a material qualification.** `b6772b1` (auto-approve safe
file reads; unpark lanes) — rc=0, contained. `37079b3` (model-specific usage-limit
stall detection) — rc=0, contained. `7e4e35e` (a live agent running a tool
subprocess is never a wedged pane) — rc=1, **not contained**. `7e4e35e` landed on
`main` after the candidate branched. This is not a defect in the candidate; it is
the reason check 3 fails, and the two findings share a single root cause.

## Check 2 — candidate hash and READY sentinel

```
$ git rev-parse lane/c43c-integrator
9b0f8cb973b5f6b646a9724c7e6823479f22817a
```

Full hash: **`9b0f8cb973b5f6b646a9724c7e6823479f22817a`** — matches the `9b0f8cb9…`
prefix the brief named.

```
$ git show lane/c43c-integrator:docs/verify-integration.md | tail -n 1
POLYLANE-VERDICT: READY-FOR-HOST-GATE run=c43c-recovery-20260819-a1

$ git show lane/c43c-integrator:docs/verify-integration.md | grep -n . | tail -n 3
220:5334-line log, classifying all 22 `FAIL`-word hits as fixture text rather than
221:letting a grep count stand unexplained.
223:POLYLANE-VERDICT: READY-FOR-HOST-GATE run=c43c-recovery-20260819-a1
```

**PASS on hash; PASS on sentinel form; MISMATCH on the run nonce.** The final line
(223 of 223) is a well-formed `READY-FOR-HOST-GATE` sentinel, but it carries
`run=c43c-recovery-20260819-a1`, not the brief's `run=c43-recovery-20260818-a1`.

The brief's nonce is stale, not wrong evidence. `c43-recovery-20260818-a1` was the
run **before** last; its evidence is a separate 178-line file still reachable at
`lane/c43-integrator:docs/verify-integration.md`, and the c43c integrator's own
report cites it as historical. The candidate under test here is the c43c product,
which merged both the c43c precheck and the `c43-recovery-20260818-a1` candidate
`f16e196`. So the sentinel is the correct one for this candidate; the brief simply
names the older run. **The integrator should expect `c43c-recovery-20260819-a1`.**

## Check 3 — merge onto current main

Run with both engines. The 3-arg form the brief names is a trivial-merge
simulation, so the result was re-derived with `--write-tree`, which runs the real
`ort` merge and is still read-only (it writes an object, touches no ref or
worktree).

```
$ MB=$(git merge-base main lane/c43c-integrator); echo "$MB"
37079b303115a8f3bd6460ce061632731aa909fe

$ git merge-tree "$MB" main lane/c43c-integrator > /tmp/mt.txt; echo "rc=$?"
rc=0
output bytes: 657443  lines: 5372
```

Stanza census of that output — the 3-arg form always exits 0, so conflicts must be
read out of the body, not the exit code:

```
added in remote      21
added in local        0
added in both         0
changed in both       1
removed in remote     0
removed in local      0
removed in both       0
merged                5

+<<<<<<< : 1
+======= : 1
+>>>>>>> : 1
```

Confirmed independently with the `ort` engine (git 2.51.2):

```
$ git merge-tree --write-tree --name-only main lane/c43c-integrator; echo "rc=$?"
2efdd3f5e787654996eb0a9238d4a77559131cd8
bin/polylane-run.sh
rc=1

$ git merge-tree --write-tree --messages main lane/c43c-integrator
2efdd3f5e787654996eb0a9238d4a77559131cd8
100755 68470519265c2185e92e94545d66b15e4d17133a 1	bin/polylane-run.sh
100755 4c7faaa663c5e8939db211b8be0eb9e5b35f6477 2	bin/polylane-run.sh
100755 26e80ba8f5f12703eeab89a20f118d8da865788a 3	bin/polylane-run.sh

CONFLICT (content): Merge conflict in bin/polylane-run.sh
```

**FAIL — the merge is NOT conflict-free.** Both engines agree: exactly one
conflicted path, `bin/polylane-run.sh`; 21 files add cleanly, 5 merge cleanly, 0
deletions. The conflict is a single hunk at lines 3816–3833 of the ort-merged
blob, inside `pane_wedged()`:

```
<<<<<<< main
  local name="$1" idx="$2" h prev cnt limit
  if pane_agent_live "$idx"; then
    lane_active_command "$name" && return 1
    pane_tool_child_running "$idx" && { wedge_cnt_set "$name" 0; return 1; }
    if lane_terminal_or_idle "$name" "$idx"; then
      h=$(lane_durable_activity_hash "$name")
=======
  local name="$1" idx="$2" h prev cnt epoch now limit interval state_dir state_file tmp
  if [ "${ORCHESTRATION_CONTRACT:-0}" -lt 3 ] 2>/dev/null; then
    if pane_agent_live "$idx"; then
      lane_active_command "$name" && return 1
      if lane_terminal_or_idle "$name" "$idx"; then
        h=$(lane_durable_activity_hash "$name")
      else
        h=$(tmux capture-pane -t "$TMUX_SESSION:0.$idx" -p 2>/dev/null | cksum | cut -d' ' -f1)
      fi
>>>>>>> lane/c43c-integrator
```

Root cause, traced rather than guessed: both sides edited the same opening lines of
`pane_wedged` after the merge-base `37079b3`. `main`'s side is commit `7e4e35e`,
which inserts the `pane_tool_child_running` immunity guard. The candidate's side is
the imported c42a lifecycle rework, which re-indents the same block inside a new
`ORCHESTRATION_CONTRACT < 3` legacy branch and widens the `local` declaration. The
textual collision and check 1's `rc=1` are the same single fact seen twice.

Observation for the integrator, offered as evidence and not as a repair (this lane
owns no source file): the two sides are **additive, not contradictory**. A
resolution that keeps only the candidate's side silently drops `7e4e35e` and
reintroduces the wedge-kill-during-tool-subprocess bug that cost the prior run its
restart. The tool-child guard needs to survive into the resolved function, and the
`ORCHESTRATION_CONTRACT >= 3` path needs the same consideration. `main` also
carries `tests/test-wedge*` coverage for that guard, so a resolution that drops it
should fail the suite rather than pass quietly — but that is the integrator's to
run and prove, not this lane's to assert.

## Check 4 — content addresses of the frozen v3 contracts

```
689ab890c339966b15f32a22f309a564f92d1ff34b354184425ffef0f8e41c34  docs/polylane/taste-certification/contracts/CONTRACT-LOCK.v3.json (bytes=18604)
00b2dc076bf74c2b511ef780f1cda796730ad4704a9d1ccb1f397f4d025864da  docs/polylane/taste-certification/contracts/EVIDENCE-CLAIM-REGISTRY.v3.json (bytes=7715)
```

Both read from `lane/c43c-integrator` via `git show … | shasum -a 256`.

**PASS — recorded, and both match independently.** These two values are
byte-identical to the ones the c43c integrator recorded in its own hash table
(`689ab890…`, `00b2dc07…`), derived there from the merged worktree rather than from
the ref. Two independent derivations agreeing is the content-addressing proof the
goal asks for: the frozen v3 contracts are intact in the candidate.

## Check 5 — free disk

```
$ df -g .
Filesystem   1G-blocks Used Available Capacity  iused     ifree %iused  Mounted on
/dev/disk3s5       460  398        29    94% 15613713 307807320    5%   /System/Volumes/Data
```

**PASS — 29 GB available against a 2 GB floor**, 27 GB of headroom. The prior run
died at 1 GB free; that condition is not present now. Capacity reads 94% used,
which is worth watching but is far above the floor. A full m32.6 acceptance run
plus check-cache output should be budgeted against this figure, not against the
percentage.

---

## Summary

| # | check | result |
|---|---|---|
| 1 | `b6772b1` is ancestor of candidate | **PASS** (rc=0); `7e4e35e` is **not** (rc=1) |
| 2 | candidate SHA + READY sentinel | **PASS** on `9b0f8cb973b5f6b646a9724c7e6823479f22817a`; sentinel present, nonce is `c43c-recovery-20260819-a1` not the brief's `c43-recovery-20260818-a1` |
| 3 | merge onto `main` conflict-free | **FAIL** — 1 conflict, `bin/polylane-run.sh`, `pane_wedged()`, lines 3816–3833 |
| 4 | v3 contract SHA-256s | **PASS** — both recorded, both match the integrator's independent derivation |
| 5 | free disk ≥ 2 GB | **PASS** — 29 GB |

The candidate is intact and content-addressed. It is **not** zero-touch mergeable
onto `main` at `7e4e35e`; landing it requires one deliberate semantic resolution in
`pane_wedged()`. The goal's "zero restarts" condition is not threatened by disk.

## Limitations

1. **Read-only, textual, and structural only.** This lane ran no tests, no
   shellcheck, no acceptance command, and no build. Nothing here speaks to whether
   the candidate's code is *correct* — only to what it contains, what it hashes to,
   and how it collides with `main`. Semantic verification is the integrator's.
2. **Check 3 predicts, it does not perform.** `merge-tree --write-tree` simulates
   the merge `main` would produce today. If `main` advances before the integrator
   merges, the prediction expires and must be re-run against the new tip.
3. **The conflict resolution is unverified by this lane.** The observation about
   keeping `7e4e35e`'s tool-child guard is read from the two sides of the hunk. It
   is a reading of the diff, not a tested claim, and carries no assertion that any
   particular resolution passes the suite.
4. **The `4851bc1` frozen-hash equality proof is not attempted here.** Check 4
   records the two contract hashes the brief named and cross-checks them against
   the integrator's table; it does not re-derive the c42a status and
   integration-evidence hashes from `4851bc1`.
5. **One named input document does not exist.** The brief directs a read of
   `docs/polylane/host-gate-failures/c43-recovery-20260818-a1.md`. That path is
   absent from the worktree, from `main`, and from `lane/c43c-integrator`; the
   directory holds only `c21-final-cert-…`, `c22-terminal-cert-…`, and
   `c41-source-calibration-….acceptance.jsonl`. The prior run's failure mode was
   instead read from `lane/c43c-integrator:docs/verify-integration.md`, which
   states it directly: `restarts=1>0`, a runtime property of the run rather than of
   the candidate. No substitute was invented.
6. **Check-cache unused.** `bin/polylane-check.sh` is for repeated expensive
   checks; all five checks here are sub-second local git and `df` reads, run once
   each, so caching them would have added indirection and a staleness risk with no
   saving. Every figure above is from a fresh execution.
7. **Relay:** the only pending request is `contract-import → integrator` seq=1,
   addressed to the integrator and already resolved in a prior run. Nothing was
   addressed to `precheck` at lane start or at the final read.

## Skill receipts and evidence

- SKILL-READ: superpowers:systematic-debugging | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/systematic-debugging/SKILL.md | 4111822586-9465
- SKILL-READ: superpowers:verification-before-completion | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/verification-before-completion/SKILL.md | 1896692335-3646

Both fingerprints were recomputed from the files as read (`cksum`) and match the
values the brief selected, so the receipts attest the exact bytes consulted.

SKILL-EVIDENCE: superpowers:systematic-debugging — helped: its Iron Law stopped a
wrong verdict. My first conflict scan used one broad regex and returned "3", a
number that would have supported either a clean or a conflicted reading. Phase 1's
"read the error carefully, don't skip past it" forced decomposing that count into
per-pattern censuses, which showed the 3 was `changed in both` plus one real
`+<<<<<<<`/`+>>>>>>>` pair — one genuine conflict, not three, and not zero. Phase
1's "check recent changes" then traced the conflict back to `7e4e35e` and joined it
to check 1's `rc=1` as one root cause rather than two unrelated anomalies, which is
what makes the finding actionable instead of merely alarming.

SKILL-EVIDENCE: superpowers:verification-before-completion — helped: twice
concretely. (1) The gate function's "what command proves this claim?" rejected the
3-arg `merge-tree`'s `rc=0` as proof of mergeability — that form exits 0 regardless
— and drove the independent `--write-tree` ort re-derivation, whose `rc=1` is the
evidence actually cited. Had I let the exit code stand, this report would have
claimed "conflict-free" and sent the integrator into a surprise conflict. (2) Its
"agent/report said success ≠ verified" stance meant check 4's hashes were derived
here from the ref rather than copied from the integrator's table, so the agreement
between the two is a real cross-check rather than a restatement.

POLYLANE-PRECHECK: CANDIDATE-INTACT MERGE-CONFLICTED run=c43d-recovery-20260819-a1
