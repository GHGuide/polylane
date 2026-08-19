# verify — lane `precheck` (run `c43e-recovery-20260819-a1`, target m32.6)

Read-only precheck of the cycle-43 candidate `lane/c43d-integrator`. Every
command below was run fresh in this worktree
(`/Users/leonardo/Downloads/polylane/.polylane/worktrees/c43e-precheck`) during
this lane; nothing is carried over from the c43/c43c/c43d precheck or
integrator reports. Those reports were read for context and then independently
re-derived. This lane merges nothing and edits no source file.

**Headline: 4 of 5 checks PASS. Check 3 FAILS — the candidate does not merge
cleanly onto current `main`.** One upstream commit (`1ca5262`) landed on `main`
after the candidate's merge-base and collides with it in two hunks of
`bin/polylane-run.sh`. Both collisions are semantically reconcilable, but they
require an explicit resolution by the integrator; `git merge` will stop.

---

## Check 1 — candidate contains current main's fixes (ancestor test)

```
$ git merge-base --is-ancestor b6772b1 lane/c43d-integrator
rc=0
```

**PASS.** `b6772b1` ("auto-approve safe file reads; unpark lanes once their
dialog is answered") is an ancestor of the candidate.

The brief frames this as "candidate contains current main's fixes". `b6772b1`
is no longer `main`'s tip, so the stronger question was also asked fresh:

```
$ git rev-parse main
1ca5262afbe091eb44b55587f3448236d8f13e14
$ git merge-base --is-ancestor main lane/c43d-integrator
rc=1
```

Current `main` is **not** an ancestor. The exact gap:

```
$ git log --oneline main ^lane/c43d-integrator
1ca5262 fix: CPU burn (not child presence) proves work; quiesce /exit retries
```

Exactly one commit, and it touches `bin/polylane-run.sh`. This is the direct
cause of the check-3 failure below.

## Check 2 — candidate hash and READY sentinel

```
$ git rev-parse lane/c43d-integrator
6579bc242811c7e1ccfe89deec6fc1a5bdf0f66f
```

Full hash recorded: **`6579bc242811c7e1ccfe89deec6fc1a5bdf0f66f`**.

Tip commit:

```
$ git log -1 --format='%H%n%an%n%ad%n%s' lane/c43d-integrator
6579bc242811c7e1ccfe89deec6fc1a5bdf0f66f
GHGuide
Wed Aug 19 05:31:51 2026 +0300
handoff: integrator READY-FOR-HOST-GATE for c43d-recovery-20260819-a1 (repair round 1)
```

Final line of `git show lane/c43d-integrator:docs/verify-integration.md`:

```
POLYLANE-VERDICT: READY-FOR-HOST-GATE run=c43d-recovery-20260819-a1
```

**PASS on substance, with two brief-vs-artifact identifier mismatches recorded
verbatim rather than papered over:**

| the brief says | observed |
|---|---|
| tip is `6579bc29…` | tip is `6579bc24…` — the first 7 chars (`6579bc2`) agree, the 8th does not |
| sentinel is for run `c43-recovery-20260818-a1` | sentinel is for run `c43d-recovery-20260819-a1` |

Both mismatches are the brief's identifiers being stale, not the artifact being
wrong: the candidate is self-consistent (the tip commit subject, the verify
document body, and the sentinel all name `c43d-recovery-20260819-a1`, the run
that produced it). The named host-gate record
`docs/polylane/host-gate-failures/c43-recovery-20260818-a1.md` does not exist in
this worktree; it exists only at the project root (untracked there, mode 0600),
alongside `c43c-…` and `c43d-…` records. Its content:

```
# Host gate failure

run=c43-recovery-20260818-a1
when=2026-08-19 00:05:37

runtime efficiency eligibility failed before the terminal boundary: restarts=1>0
```

and the newer one, which repeats the same failure mode for the run that
actually produced this candidate:

```
# Host gate failure

run=c43d-recovery-20260819-a1
when=2026-08-19 13:58:29

runtime efficiency eligibility failed before the terminal boundary: restarts=1>0
acceptance_output=docs/polylane/host-gate-failures/c43d-recovery-20260819-a1.acceptance.jsonl
```

So the prior-run summary in the brief ("only host efficiency eligibility failed,
restarts=1>0") is confirmed to hold for **two** consecutive runs, not one.

## Check 3 — merge conflict-free? **NO**

The brief's command, run verbatim:

```
$ MB=$(git merge-base main lane/c43d-integrator); echo "$MB"
7e4e35e8e4def5a10278b71a49041216059abf65
$ git merge-tree "$MB" main lane/c43d-integrator
rc=0   (5973 lines of output)
$ grep -cE '^<<<<<<<' <output>
0
```

Legacy three-argument `git merge-tree` reports **one** `changed in both` entry
(`bin/polylane-run.sh`, base `4c7faaa`, ours `27bf9f2`, theirs `db4b301`) and
emits **zero** conflict markers. Taken alone this reads as "conflict-free".

**It is not.** Legacy `merge-tree` is a per-hunk diff reporter, not the merge
engine. The engine `git merge` actually uses is merge-ort, exposed read-only as
`--write-tree`. Run fresh on the same two refs (git 2.51.2):

```
$ git merge-tree --write-tree main lane/c43d-integrator
rc=1
bba50c6441ff4b741f976bd689abbcbde4c601b5

Auto-merging bin/polylane-run.sh
CONFLICT (content): Merge conflict in bin/polylane-run.sh
```

Conflict hunks in the resulting merged blob:

```
$ git show bba50c6441ff4b741f976bd689abbcbde4c601b5:bin/polylane-run.sh \
    | grep -nE '^(<<<<<<<|=======|>>>>>>>)'
2672:<<<<<<< main
2678:=======
2683:>>>>>>> lane/c43d-integrator
3851:<<<<<<< main
3858:=======
3869:>>>>>>> lane/c43d-integrator
```

**Verdict: the merge is NOT conflict-free — 2 content conflicts, both in
`bin/polylane-run.sh`, both introduced by `1ca5262`.** The two hunks verbatim:

### Conflict 1 — `quiesce_done_pane`, around line 2672

```
  mkdir -p "$state_dir" 2>/dev/null || return 1
<<<<<<< main
  sent=0
  [ -s "$marker" ] && IFS= read -r sent < "$marker" 2>/dev/null
  case "$sent" in ''|*[!0-9]*) sent=0 ;; esac
  [ "$sent" -lt "${POLYLANE_QUIESCE_MAX:-5}" ] || return 1
  printf '%s\n' "$((sent + 1))" > "$marker"
=======
  : > "$marker"
  if [ "${ORCHESTRATION_CONTRACT:-0}" -ge 3 ] 2>/dev/null; then
    finalization_transition "$wt" "$name" QUIESCING || return 1
  fi
>>>>>>> lane/c43d-integrator
  pane_send_exit "$idx"
```

`main` replaced the one-shot marker with a bounded retry counter; the candidate
kept the one-shot marker and added the v3 `finalization_transition … QUIESCING`
lifecycle call. The two changes are orthogonal in intent — neither side deletes
what the other adds — so a resolution keeping `main`'s counter *and* the
candidate's contract-gated transition is available. Note that `main`'s own
comment block immediately above the conflict (retained cleanly by the merge)
already documents the bounded-retry rationale and cites the c43d integrator
nine-hour hang, so dropping `main`'s side would contradict the surviving comment.

### Conflict 2 — `pane_wedged`, around line 3851

```
pane_wedged() {
<<<<<<< main
  local name="$1" idx="$2" h prev cnt limit
  if pane_agent_live "$idx"; then
    lane_active_command "$name" && return 1
    pane_burning_cpu "$name" "$idx" && { wedge_cnt_set "$name" 0; return 1; }
    if lane_terminal_or_idle "$name" "$idx"; then
      h=$(lane_durable_activity_hash "$name")
=======
  local name="$1" idx="$2" h prev cnt epoch now limit interval state_dir state_file tmp
  if [ "${ORCHESTRATION_CONTRACT:-0}" -lt 3 ] 2>/dev/null; then
    if pane_agent_live "$idx"; then
      lane_active_command "$name" && return 1
      pane_tool_child_running "$idx" && { wedge_cnt_set "$name" 0; return 1; }
      if lane_terminal_or_idle "$name" "$idx"; then
        h=$(lane_durable_activity_hash "$name")
      else
        h=$(tmux capture-pane -t "$TMUX_SESSION:0.$idx" -p 2>/dev/null | cksum | cut -d' ' -f1)
      fi
>>>>>>> lane/c43d-integrator
    else
      h=$(tmux capture-pane -t "$TMUX_SESSION:0.$idx" -p 2>/dev/null | cksum | cut -d' ' -f1)
    fi
```

Structural, not just textual: the candidate wraps the whole pre-v3 body in an
`ORCHESTRATION_CONTRACT < 3` guard and re-indents it, which shifts the `if/else`
nesting the two sides share. On top of that, `main` swapped the work signal from
`pane_tool_child_running` (child-process presence, `7e4e35e` — which *is* in the
candidate) to `pane_burning_cpu` (CPU-burn delta, `1ca5262` — which is not), and
widened the local declaration list differently from the candidate. A resolution
must keep `main`'s `pane_burning_cpu` call inside the candidate's contract-gated
branch, and reconcile the two `local` lines.

Neither conflict touches any of the 16 frozen imported v3 contract artifacts.

## Check 4 — SHA-256 of the two frozen v3 contract blobs

```
$ git show lane/c43d-integrator:docs/polylane/taste-certification/contracts/CONTRACT-LOCK.v3.json | shasum -a 256
689ab890c339966b15f32a22f309a564f92d1ff34b354184425ffef0f8e41c34
$ git show lane/c43d-integrator:docs/polylane/taste-certification/contracts/EVIDENCE-CLAIM-REGISTRY.v3.json | shasum -a 256
00b2dc076bf74c2b511ef780f1cda796730ad4704a9d1ccb1f397f4d025864da
```

| SHA-256 | blob at `lane/c43d-integrator` |
|---|---|
| `689ab890c339966b15f32a22f309a564f92d1ff34b354184425ffef0f8e41c34` | `docs/polylane/taste-certification/contracts/CONTRACT-LOCK.v3.json` |
| `00b2dc076bf74c2b511ef780f1cda796730ad4704a9d1ccb1f397f4d025864da` | `docs/polylane/taste-certification/contracts/EVIDENCE-CLAIM-REGISTRY.v3.json` |

**PASS.** Both are byte-identical to the values the c43d integrator recorded in
`lane/c43d-integrator:docs/verify-integration.md`, re-derived here independently
from the ref rather than copied. The v3 contract content is intact and
content-addressed.

## Check 5 — free disk

```
$ df -g .
Filesystem   1G-blocks Used Available Capacity  iused     ifree %iused  Mounted on
/dev/disk3s5       460  400        25    95% 15708459 264350680    6%   /System/Volumes/Data

$ df -k . | awk 'NR==2{printf "available_KiB=%s available_GiB=%.2f\n",$4,$4/1048576}'
available_KiB=26435068 available_GiB=25.21
```

**PASS.** 25 GiB free, 12.6× the 2 GiB floor and well clear of the 1 GiB level
at which the prior run was killed. The volume is at 95% capacity, so this is
headroom on a nearly-full disk — it satisfies the floor now but is not a large
absolute margin if another process writes heavily during the gate.

---

## Summary

| # | check | result |
|---|---|---|
| 1 | `b6772b1` ancestor of candidate | **PASS** (rc=0); current `main` `1ca5262` is *not* an ancestor — 1 commit ahead |
| 2 | candidate hash + READY sentinel | **PASS** — `6579bc242811c7e1ccfe89deec6fc1a5bdf0f66f`, sentinel present; brief's `6579bc29…` prefix and `c43-recovery-20260818-a1` run-id are both stale |
| 3 | merge conflict-free | **FAIL** — merge-ort rc=1, 2 content conflicts in `bin/polylane-run.sh` (legacy `merge-tree` shows none; it is not the merge engine) |
| 4 | frozen contract SHA-256s | **PASS** — both match the integrator's recorded values |
| 5 | free disk ≥ 2 GB | **PASS** — 25.21 GiB |

The goal stated for this lane was to prove the candidate "intact,
content-addressed, and mergeable onto current main". Intact: yes (check 4).
Content-addressed: yes (check 4). **Mergeable onto current main: no** — the
integrator must resolve `1ca5262` against the candidate's two `bin/polylane-run.sh`
regions before landing. Both resolutions are additive (keep `main`'s bounded
quiesce retry and CPU-burn work signal, keep the candidate's
`ORCHESTRATION_CONTRACT >= 3` lifecycle gating), so no product decision is
forced, but the merge is not zero-touch and a "zero-restart, zero-conflict"
plan that assumes otherwise will stall at the merge step.

## Limitations

- Every result above is from read-only commands against local refs. No merge,
  no checkout, no source edit, no test run, no network, no provider call, no
  subagent. `git merge-tree --write-tree` writes a tree object into the object
  database and mutates no ref, index, or working file; it is the only way to get
  merge-ort's verdict without performing a merge.
- Check 3's conflict analysis proves `git merge` will stop. It does **not**
  prove that any particular resolution builds, passes the frozen m32.6 focused
  acceptance, or preserves either side's behavior — that is the integrator's
  work and requires running the suite.
- No claim is made here about the *engineering* state of the candidate. The
  c43d integrator's `SUMMARY: 4077 passed, 0 failed` was read but not re-run;
  in any case that total was measured on the candidate tree, not on a
  candidate-plus-`1ca5262` merge, which does not yet exist.
- Check 5 is a point-in-time reading. Free space can fall during the gate; the
  volume is 95% full.
- The brief's `docs/polylane/host-gate-failures/c43-recovery-20260818-a1.md` is
  absent from every ref reachable here; only the project-root untracked copy was
  read. Its content is quoted in full above so the record is complete.
- Relay: the start-of-lane and final `pending` reads both returned exactly one
  request, seq=1 from `contract-import` **to `integrator`** (run
  `c43-recovery-20260818-a1`, the `test-lane-done-live.sh` needle swap). Nothing
  is addressed to `precheck`. The durable worker inbox has no `precheck`
  identity in this run (`polylane-workers.sh inbox "$POLYLANE_PROJECT_ROOT"
  precheck` → `worker identity is absent: precheck`, rc=0), so no autonomous
  work was owed to this lane from either channel.

## Skill receipts and evidence

- SKILL-READ: superpowers:systematic-debugging | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/systematic-debugging/SKILL.md | 4111822586-9465
- SKILL-READ: superpowers:verification-before-completion | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/verification-before-completion/SKILL.md | 1896692335-3646

Both fingerprints were recomputed from the files as read
(`cksum < SKILL.md`) and match the values the brief selected.

SKILL-EVIDENCE: superpowers:systematic-debugging — helped: its Phase 1
"gather evidence at each component boundary before concluding" rule is what
turned check 3 from a false PASS into the lane's actual finding. Legacy
`git merge-tree` returned rc=0 with zero conflict markers, which satisfies the
brief's literal command and would have been reported as conflict-free. The
skill's instruction to trace the mechanism rather than trust one layer's
output prompted a second, independent probe at the layer that actually
performs the merge (`--write-tree`, merge-ort), which returned rc=1 and two
`CONFLICT (content)` hunks. Its "check recent changes" step then localized the
cause to a single commit (`git log main ^candidate` → `1ca5262`) instead of
leaving the conflict unexplained, and "read errors completely" is why both
hunks were extracted verbatim from the merged blob rather than summarized.

SKILL-EVIDENCE: superpowers:verification-before-completion — helped: three
concrete places. (1) Its Iron Law blocked reporting check 2 as a clean PASS
when the observed tip was `6579bc24…` against the brief's `6579bc29…` and the
sentinel named `c43d-recovery-20260819-a1` against the brief's
`c43-recovery-20260818-a1`; both deltas are recorded as observed rather than
rounded to the expected value. (2) Its "partial check proves nothing" line is
why the check-1 ancestor test was not left at `b6772b1` rc=0 — the brief's
stated *intent* ("candidate contains current main's fixes") was tested against
the real `main` tip, which is what exposed the one-commit gap that check 3 then
confirmed as a hard conflict. (3) Its rule against success wording without
fresh evidence shaped the summary: "mergeable onto current main" is stated as
NO with the rc and hunk output attached, and the c43d integrator's 4077-pass
figure is explicitly marked as read-not-re-run rather than cited as this lane's
evidence.
