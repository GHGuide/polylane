# STORY SO FAR — corpus through cycle 1

## Earlier (one line each)
(none)

## Recent (verbatim, last 3 cycles)

===== cycle 1 =====
# Cycle 1 digest — install-test + docs-truth

## Built
- tests/test-install-fresh.sh (20 assertions): hermetic fresh-clone install proof for BOTH
  layouts — fake-HOME Claude copy install; codex/install.sh into a fake ~/.codex; asserts
  SKILL.md frontmatter, >=20 executable scripts, references/assets present; PINS the
  cp -R reinstall nesting bug (references/references must not appear); memory helper runs
  standalone from each installed location.
- tests/test-docs-truth.sh (16 assertions): every path/command README + AGENTS.md +
  install-helpers reference must exist and be executable; no drift between README and
  reference docs.
- AGENTS.md at repo root (orchestrator): mission, settled decisions 001/002, verified
  run/build/test commands, conventions, status. polylane now satisfies the shippability
  gate it imposes on built apps.
- fix: --dry-run no longer mutates durable state (finalize_cycle_state DRY_RUN guard)
  + tests/test-dryrun-pure.sh. A preview had stamped target subgoals done, which killed
  two real launches at "target must be open".
- fix: scout now detects plugin-cache installs (superpowers/ponytail/caveman) so lane
  kits can be armed 2 predefined + 2 lane-specific.

## Verified
- Merged tree: 730 tests, 0 failed, 54 files. Seam scan clean. Promoted to main.

## Known issue (UNDIAGNOSED — do not guess)
Both lanes finished green and committed, then their docs/status-<lane>.md markers
disappeared from the worktrees; the runner respawned the finished lanes and reported
"FAILED after retries" -> HALTED. An empirical probe of the --resume path (valid
current-run marker + real runner + --resume) PRESERVED the marker, so resume is
exonerated. Cause unknown. Work was salvaged by merging the verified branches manually.
Next cycle should reproduce with pane logging before trusting long unattended runs.

