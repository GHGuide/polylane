# Verify — doctor-tests lane

Target: `bin/polylane-doctor.sh` (READ-ONLY, not edited).
Owned file created: `tests/test-doctor.sh`.

## Coverage (each behavior = one assertion)

- exit contract: exit 0 on all-pass / exit 1 on any FAIL
  (`exit-code-tracks-fail-presence`, `manifest-missing-exit1`,
  `invalid-json-exit1`, `bad-prompt-file-exit1`, `insane-worktree-exit1`,
  `tmux-collision-exit1`)
- PASS / WARN / FAIL table lines rendered (`table-header`,
  `table-column-header`, `summary-line-format`, PASS/FAIL/WARN hint strings)
- deps check (`deps-required-row`, `deps-optional-row`)
- manifest-validity check (`manifest-valid-json-pass`,
  `manifest-prompt-files-pass`, `manifest-worktree-sane-pass`,
  `invalid-json-fail`, `bad-prompt-file-fail`, `insane-worktree-fail`)
- disk check (`disk-check-row`)
- tmux session-collision check (`tmux-check-runs`, `tmux-session-free`,
  `tmux-session-collision`)
- git lane collision WARN (`lane-collisions-clean-pass`,
  `worktree-collision-warn`)
- usage / unknown-option surface (`help-exit0`, `help-shows-usage`,
  `unknown-opt-exit1`, `unknown-opt-msg`)

Environment-coupled checks (jq-gated manifest parsing, tmux probing) are
guarded with a skip-pass, same shape as `tests/test-memory.sh`, so the file
stays green on hosts lacking those tools. Fixtures are built under
`$TEST_TMPDIR`. The CLI is invoked (never sourced) and never mutated.

## Evidence — `bash tests/run.sh`

```
test-doctor.sh: 28 pass, 0 fail
SUMMARY: 166 passed, 0 failed, 11 test files
run.sh exit rc=0
```

- `tests/test-doctor.sh`: **28 pass, 0 fail**
- New suite total: **166 passed, 0 failed, 11 test files** (was 10 files /
  138 assertions before this lane).
- `tests/run.sh` exits **0** (whole suite green).
