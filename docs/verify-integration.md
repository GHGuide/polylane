# Cycle 4 integration verification

Run: `walk-c4-20260806-210324`

## Locked goal and ancestry

`codex/walk-c4-integrator` is the active branch. `main` was not checked out or modified.

```text
runtime tip:   3d41c2bdaddb486cb8f7c041664ab8de51caa592
rehearsal tip: 838f01cde5e601ac8f3ded864b67eabdc7837eb9
HEAD:          f4cd17bb6c04decd69191cd47444c3890e95b210 plus integration repairs
runtime_exact_tip_merged=0
rehearsal_exact_tip_merged=0
```

Write-set audit: runtime contributed `bin/polylane-run.sh`, cleanup/report/pane tests, runtime evidence, and status; rehearsal contributed doctor/rehearse scripts, rehearsal test/evidence, and status. Their fork write-sets did not overlap. The two merge commits are `cad1097` then `f4cd17b`.

## Commands and results

```text
python3 graphify-out/q.py cleanup|pane_stalled|write_report|rehearse|contract_acceptance_gate
  Located runner functions and focused tests; graph authority: graph@07777660.

bin/polylane-check.sh /Users/leonardo/Downloads/polylane/.polylane/check-cache/integrator -- ...
  Host denied mkdir for canonical cache path. Local worktree cache used for every subsequent check.

bash tests/test-cleanup.sh
  12 pass, 0 fail.
bash tests/test-pane-stalled.sh
  5 pass, 0 fail.
bash tests/test-write-report.sh
  23 pass, 0 fail.
bash tests/test-agent-adapter.sh
  39 pass, 0 fail.
bash tests/test-rehearse.sh
  1 pass, 0 fail with live rehearsal gated off.

bash bin/polylane-doctor.sh --rehearse
  == rehearse: GO ==
  REHEARSE-GO contract-v2=1 promoted=0 cleaned=1 leaks=0
  REHEARSE GO FAILED

bash tests/run.sh
  SUMMARY: 943 passed, 11 failed, 62 test files.
  test-installers.sh: 6 failures; sandbox denies repo .codex/ creation.
  test-session-resume.sh: 5 failures; tmux Unix socket access denied.

shellcheck -S warning bin/*.sh
  exit 0; no warnings.

bin/polylane-seams.sh scan "$PWD"
  exit 0; no SEAM-DANGLING output.
```

## Contract and review

- Cleanup test proves committed runtime status markers are removed from the promoted fixture while unmerged recovery branches remain.
- Pane test rejects usage-limit prose and source text; it accepts only actionable credits or upgrade controls.
- Report test accepts structured current-run sections and rejects arbitrary lane prose, historical deferred evidence, and shell output.
- Rehearsal repair now writes actual v2 manifest keys, durable state, frozen focused/terminal acceptance, structured lane kits, strict prompts, nonce-bound committed markers, and authoritative graph/event witnesses. GO merges both builder tips. NO-GO retains evidence/session/worktrees until fixture cleanup and is bounded to three launches.
- Engineering review: no new correctness, security, performance, or maintainability defect found in the integration repairs. Verdict: Needs Discussion because mandatory live tmux gates cannot run on this host.
- Ponytail review: `bin/polylane-rehearse.sh:L27-36: shrink: repeated CODEX_SKILLS_DIR prefixes. Export once inside fixture setup.` Net: `-6` lines possible. No deletion applied during correctness integration.

## DEFERRED

DEFERRED: host sandbox blocks tmux Unix sockets and repo-scoped `.codex/` writes; this prevents the required live GO/NO-GO rehearsal and a clean full suite.

POLYLANE-VERDICT: NO-GO run=walk-c4-20260806-210324
