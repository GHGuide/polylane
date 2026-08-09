# Handoff-contract verification

## Red → green

- RED: `bash tests/test-handoff-contract.sh` initially reported 16 failures: no
  advertised finalization block, no executable refinement queue instruction, and no
  strict runtime-finalization requirement.
- RED: `bash tests/test-promptlint.sh` initially accepted a compiled runtime prompt
  with its finalization block removed.
- GREEN: cached focused checks pass: 23 handoff assertions, 27 prompt-lint assertions
  (including missing and reordered finalization), 59 Claude/Codex parity assertions,
  60 prime-hybrid assertions, and 40 refinement assertions.
- GREEN: `shellcheck -S warning bin/polylane-promptlint.sh` and `git diff --check`
  pass.

## Executable command audit

Prime-hybrid prompt guidance now runs exactly:

```bash
"$POLYLANE_PROJECT_ROOT/bin/polylane-refine.sh" queue "$POLYLANE_HARNESS_DIR"
```

then one real `propose` or `decline` invocation per eligible item. The conceptual
`propose-or-decline` phrase is explicitly not a subcommand, and the handoff test
rejects any advertised `polylane-refine.sh propose-or-decline` invocation.

## Claude/Codex parity

Both skills carry the same ordered `POLYLANE-RUNTIME-FINALIZE` protocol and executable
refinement queue flow. `tests/test-skill-parity.sh` confirms both additions.

## Required integration dependency

`tests/test-orchestration-contract.sh` is currently red (2 assertions): the forbidden
runner-owned compiler injects `POLYLANE-RUNTIME-RELAY` and `POLYLANE-RUNTIME-DONE`, but
does not yet inject `POLYLANE-RUNTIME-FINALIZE`. The new strict generated-prompt lint
therefore correctly rejects its compiled prompt. This lane intentionally did not edit
`bin/polylane-run.sh`; that injection belongs to the runtime-finality interface.

## Exact diff scope

Changed owned paths: `bin/polylane-promptlint.sh`, both skills, the three prompt/planning
references, the four focused contract tests, and this verification record. No runner,
tmux, state, supervisor, base-branch, status marker, or external-evidence artifact was changed.

## Skill receipts

- SKILL-READ: engineering:documentation | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/documentation/SKILL.md | 1d469418f786a05be83d2a05f04d68788aeed584d13863a650f5ad73c6c4cf50
- SKILL-EVIDENCE: engineering:documentation — helped: kept the command audit and
  verification record reader-oriented and executable.
- SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md | bf1b8216e523851a411e91d429a7c1c2a173e79d88957bc78e348218d50edd54
- SKILL-EVIDENCE: superpowers:test-driven-development — helped: the handoff and strict
  lint regressions were observed red before implementation and green afterward.

## DEFERRED

DEFERRED: runner compilation injection — runtime-finality must inject the finalization
block before a truthful DONE marker can be written.
