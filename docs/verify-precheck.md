# verify — lane precheck (run c43c-recovery-20260819-a1)

Lane: `precheck` · run `c43c-recovery-20260819-a1` · worktree
`/Users/leonardo/Downloads/polylane/.polylane/worktrees/c43c-precheck`
(branch `lane/c43c-precheck`).

Purpose: fresh, read-only re-proof that the verified cycle-43 candidate
`lane/c43-integrator` is intact, content-addressed, and mergeable onto current
`main`, so the integrator can land it and the host gate can certify with zero
restarts. This lane merges nothing and mutates no source, test, or state file.

Prior-run context (read, not re-derived): engineering passed end to end; the run
failed only on host efficiency eligibility —
`docs/polylane/host-gate-failures/c43-recovery-20260818-a1.md` records
`run=c43-recovery-20260818-a1 · when=2026-08-19 00:05:37 · runtime efficiency
eligibility failed before the terminal boundary: restarts=1>0`.

Reference commits at the time of these checks:
`main = 37079b303115a8f3bd6460ce061632731aa909fe`,
`b6772b1 = b6772b17a964f4bd82415409d77f1dfddfaf58b6`.

## SKILL-READ

- SKILL-READ: superpowers:systematic-debugging | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/systematic-debugging/SKILL.md | 4111822586-9465
- SKILL-READ: superpowers:verification-before-completion | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/verification-before-completion/SKILL.md | 1896692335-3646

## Check 1 — candidate contains current main's fixes

Command:

```
git merge-base --is-ancestor b6772b1 lane/c43-integrator; echo "exit=$?"
```

Fresh output, verbatim:

```
exit=0
```

Result: PASS. `b6772b1` ("auto-approve safe file reads; unpark lanes once their
dialog is answered") is an ancestor of the candidate, so the candidate already
contains that fix.

Scope note (not a check result, recorded so the integrator is not surprised):
`main` has advanced past `b6772b1` to `37079b3` ("detect the model-specific
usage-limit screen as an actionable stall"). Only `b6772b1` was named for this
ancestry check, and only `b6772b1` was tested. Check 3 below is what covers the
newer main commit, and it does so by merge, not by ancestry.

## Check 2 — candidate hash and READY sentinel

Commands:

```
git rev-parse lane/c43-integrator
git show lane/c43-integrator:docs/verify-integration.md | tail -5
git show lane/c43-integrator:docs/verify-integration.md | wc -l
git show lane/c43-integrator:docs/verify-integration.md | tail -1 | cat -ve
```

Fresh output, verbatim:

```
f16e19649557042ecf242c4c22d4371c050514b0
```

```
applied hunk equals the `4851bc1` delta byte-for-byte before accepting the
merge; it also kept the acceptance claim tied to this run's fresh rc=0 log
rather than the builder's pre-repair rc=1 numbers.

POLYLANE-VERDICT: READY-FOR-HOST-GATE run=c43-recovery-20260818-a1
```

```
     178
```

```
POLYLANE-VERDICT: READY-FOR-HOST-GATE run=c43-recovery-20260818-a1$
```

Result: PASS. Full candidate hash is
`f16e19649557042ecf242c4c22d4371c050514b0`, matching the expected `f16e1969…`
prefix. `docs/verify-integration.md` at that ref is 178 lines and its final line
(line 178, `$` = end of line, no trailing blank) is exactly the
`POLYLANE-VERDICT: READY-FOR-HOST-GATE run=c43-recovery-20260818-a1` sentinel for
the prior run.

## Check 3 — merge cleanliness onto current main

Commands:

```
MB=$(git merge-base main lane/c43-integrator); echo "merge-base=$MB"
git merge-tree "$MB" main lane/c43-integrator   # legacy 3-arg form, as specified
git merge-tree --write-tree --name-only main lane/c43-integrator; echo "exit=$?"
```

Fresh output, verbatim (legacy form; 5004 lines of diff withheld, conflict scan
shown in full):

```
merge-base=b6772b17a964f4bd82415409d77f1dfddfaf58b6
exit=0
--- conflict markers count ---
1
--- lines ---
    5004
--- grep 'changed in both' ---
747:changed in both
--- grep conflict markers ---
(no output)
```

Context at line 747, verbatim:

```
changed in both
  base   100755 8be779c6bb1a251e889b629a20a625890f2fe608 bin/polylane-run.sh
  our    100755 68470519265c2185e92e94545d66b15e4d17133a bin/polylane-run.sh
  their  100755 9bef10bab3386304d11afa8e9ac276b241c0d7ce bin/polylane-run.sh
```

Fresh output, verbatim (modern form, git version 2.51.2):

```
exit=0
23ac1bae9c059187ab4f6ce9b16f226f5bbf01d3
```

Result: PASS — the merge is conflict-free.

Reading, stated explicitly because the legacy output is easy to misread: the
legacy `git merge-tree` `changed in both` header for `bin/polylane-run.sh` means
both sides edited that file, **not** that they conflict; a real conflict would
appear as `<<<<<<<` / `=======` / `>>>>>>>` markers inside the emitted content,
and a scan for those markers returned nothing. The modern
`git merge-tree --write-tree` form is authoritative on this question: it exited
`0` and printed only the merged tree OID
`23ac1bae9c059187ab4f6ce9b16f226f5bbf01d3` with no conflicted-file list, which is
git's contract for a clean merge. The merge-base is `b6772b1`, i.e. the candidate
and current `main` diverged at exactly the commit checked in Check 1, and main's
one newer commit `37079b3` merges cleanly with the candidate.

## Check 4 — content addresses of the frozen v3 contracts

Command:

```
for f in CONTRACT-LOCK.v3.json EVIDENCE-CLAIM-REGISTRY.v3.json; do
  p="docs/polylane/taste-certification/contracts/$f"
  git show "lane/c43-integrator:$p" | shasum -a 256
done
```

Fresh output, verbatim (with git blob OID and byte count recorded alongside):

```
docs/polylane/taste-certification/contracts/CONTRACT-LOCK.v3.json
689ab890c339966b15f32a22f309a564f92d1ff34b354184425ffef0f8e41c34  (stdin)
  git-blob-oid: 3e5643e92b574649e28d98525aa9d747465ba7ab
  bytes: 18604
docs/polylane/taste-certification/contracts/EVIDENCE-CLAIM-REGISTRY.v3.json
00b2dc076bf74c2b511ef780f1cda796730ad4704a9d1ccb1f397f4d025864da  (stdin)
  git-blob-oid: a13c934cdd9f63f976e8594e221ea94101369fc0
  bytes: 7715
```

Result: RECORDED (this check has no pass/fail target in the lane brief — it
establishes the addresses, it does not compare them).

- `CONTRACT-LOCK.v3.json` SHA-256 `689ab890c339966b15f32a22f309a564f92d1ff34b354184425ffef0f8e41c34`
- `EVIDENCE-CLAIM-REGISTRY.v3.json` SHA-256 `00b2dc076bf74c2b511ef780f1cda796730ad4704a9d1ccb1f397f4d025864da`

These are SHA-256 over the file content as it exists at
`lane/c43-integrator` (`git show` output piped to `shasum`), not over the git
blob object header, so they are directly comparable to any downstream
`shasum -a 256 <path>` taken from a checkout of that ref.

## Check 5 — free disk

Command:

```
df -g .
```

Fresh output, verbatim:

```
Filesystem   1G-blocks Used Available Capacity  iused     ifree %iused  Mounted on
/dev/disk3s5       460  398        29    94% 15590558 311186280    5%   /System/Volumes/Data
```

Result: PASS. 29 GB available on the volume backing this worktree, against a
2 GB floor and against the 1 GB level at which the prior run was killed. Headroom
is 14.5× the floor. The volume is at 94% capacity, so the margin is real but not
generous; a second multi-hour run on the same host should re-check rather than
assume.

## Verdict

All five checks ran fresh in this lane and none contradicted the candidate:

| # | Check | Result |
|---|---|---|
| 1 | `b6772b1` ancestor of `lane/c43-integrator` | PASS (exit 0) |
| 2 | candidate `f16e1969…`, final line is READY sentinel | PASS |
| 3 | merge onto current `main` | PASS — conflict-free |
| 4 | SHA-256 of both v3 contracts | RECORDED |
| 5 | free disk vs 2 GB floor | PASS — 29 GB |

The candidate `f16e19649557042ecf242c4c22d4371c050514b0` is intact,
content-addressed, and mergeable onto `main` at
`37079b303115a8f3bd6460ce061632731aa909fe`.

## Limitations

Stated plainly, because each one bounds what the table above may be read to
mean:

1. **This lane proves mergeability, not correctness.** No test was run, no suite,
   no shellcheck, no acceptance. The engineering verdict rests entirely on the
   prior run's `docs/verify-integration.md` at the candidate ref, which this lane
   read but did not re-execute. The lane's TEST-CADENCE permits exactly these five
   checks and nothing else.
2. **Check 4 records hashes; it does not compare them.** The lane brief asked for
   the SHA-256 of the two v3 contracts and supplied no expected values, and the
   cadence forbade adding a sixth check, so no comparison against the frozen
   c42a handoff `4851bc1` was performed here. "Content-addressed" is therefore
   established in the sense that stable addresses now exist on the record — an
   equality proof against `4851bc1` remains open and belongs to whoever holds the
   expected values.
3. **Check 1 tested `b6772b1` only.** `main` has since advanced to `37079b3`,
   which is *not* an ancestor of the candidate. That is expected and is not a
   defect: Check 3 shows it merges cleanly. But no ancestry claim is made about
   `37079b3`, and anyone reading Check 1 as "the candidate contains all of main"
   would be over-reading it.
4. **Check 3 is a merge-tree simulation, not a merge.** It proves git can produce
   a merged tree without textual conflict. It says nothing about semantic
   conflict — e.g. both sides editing `bin/polylane-run.sh` in ways that combine
   cleanly at the text level but interact badly at runtime. That risk is real
   here specifically because `bin/polylane-run.sh` is the one file changed on both
   sides. Post-merge test execution is the only thing that closes it, and that is
   the integrator's job, not this lane's.
5. **Disk is a point-in-time reading.** 29 GB free was true when Check 5 ran. The
   prior run's kill was caused by consumption *during* a multi-hour run, so this
   reading bounds the starting condition only, not the run.
6. **The failure that actually sank the prior run is untouched by this lane.**
   `restarts=1>0` is a runtime-efficiency property of the *next* run, not a
   property of the candidate. Nothing in these five checks makes a restart less
   likely; they only remove candidate-integrity questions as a possible cause of
   one.

## SKILL-EVIDENCE

- SKILL-EVIDENCE: superpowers:systematic-debugging — helped: Check 3's legacy
  `git merge-tree` emitted a `changed in both` header for `bin/polylane-run.sh`,
  which reads as a conflict at a glance and would have produced a false
  "conflicted" verdict. The skill's Phase 1 rule — read the error/output
  carefully rather than pattern-matching, and gather evidence at the boundary
  before concluding — is what drove scanning the emitted content for actual
  `<<<<<<<`/`=======`/`>>>>>>>` markers (none) and then confirming with the
  authoritative `--write-tree` form (exit 0, tree OID, no conflict list) instead
  of reporting the header. Phase 3's "one hypothesis, test minimally" shaped that
  as a single decisive second command rather than a pile of guesses.
- SKILL-EVIDENCE: superpowers:verification-before-completion — helped: the gate
  function forced every claim in this document to name the command that proves
  it and to carry that command's fresh output verbatim, including the ones that
  were tempting to assert from memory — the candidate hash was quoted only after
  `git rev-parse` ran in this lane, and the sentinel was confirmed with
  `tail -1 | cat -ve` rather than eyeballed from a `tail -5`. It is also why
  Check 4 is labelled RECORDED rather than PASS: no expected value was available
  to verify against, and the skill's rule against implying success without
  evidence made an honest label the only option.
