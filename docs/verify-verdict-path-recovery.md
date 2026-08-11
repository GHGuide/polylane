# Verdict-path recovery verification

## Skill receipts

SKILL-READ: engineering:debug | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/debug/SKILL.md | e50bb92cbcb2715139f3a3cb9ff282a8f0f9ae794f8f35d81338654e2601d32a

SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md | bf1b8216e523851a411e91d429a7c1c2a173e79d88957bc78e348218d50edd54

## Initial evidence

`docs/polylane/cycle-36-research.md` retains the Cycle 35 live reproduction: the
integrator wrote `POLYLANE-VERDICT: GO run=c35-install-upgrade-20260811-a1` to
`docs/status-integrator.md`, while the canonical `docs/verify-integration.md` had
no sentinel and the runner therefore returned `NO-GO`.

The prescribed red-first regression was retained: Cycle 36's plan records the two
pre-repair assertions, and the watched current run of `bash tests/test-lane-done-live.sh`
passes them after existing bootstrap commit `0a8c9a6`. The source has not been
changed for that already-green contract pending focused proof of a defect.

## Repair evidence

`0a8c9a6` was inspected rather than rewritten. Its role argument reaches runtime
prompt compilation, its integrator contract names `docs/verify-integration.md` as
the final-line sentinel location, and the focused compiler contract passed; no
focused proof justified changing the bootstrap repair.

The Cycle 35 installer tests were imported before their implementation. Against the
old installers, `test-install-fresh.sh` failed `codex-both-no-legacy-root` and
`codex-both-no-legacy-engine`; `test-installers.sh` also failed stale Codex/Claude
package checks and Claude source-equals-destination replacement. The implementation
paths `codex/install.sh` and `claude-code/install.sh` now exactly match `028a4bb`.
They stage and validate a complete package before atomically replacing a legacy
package, and retain rollback material until replacement succeeds.

The compiler remains role-aware: builders write only their own status handoff;
integrators write their only current-run sentinel as the final line of
`docs/verify-integration.md` and keep `docs/status-integrator.md` verdict-free.
`polylane-promptlint.sh` now rejects both a missing integrator boundary and an
explicit second sentinel destination. All advertised Claude/Codex/planning prompt
contracts state the same two-file boundary.

## Verification

- `bash tests/test-install-fresh.sh` — 42 pass, 0 fail (cached source fingerprint
  `3547558080:47959`)
- `bash tests/test-installers.sh` — 57 pass, 0 fail (same cached fingerprint);
  verifies clean replacements and byte-identical Codex discovery roots.
- `bash tests/test-lane-done-live.sh` — 18 pass, 0 fail; the compiled integrator
  has the canonical verdict path and a verdict-free status file.
- `bash tests/test-promptlint.sh` — 35 pass, 0 fail; strict lint rejects missing
  and contradictory integrator boundaries.
- `bash tests/test-handoff-contract.sh` — 58 pass, 0 fail; every provider-facing
  handoff source advertises the canonical two-file rule.
- `bash tests/test-orchestration-contract.sh` — 14 pass, 0 fail.
- `bash tests/test-skill-parity.sh` — 59 pass, 0 fail;
  `bin/polylane-markers.sh check-docs references/` passed silently.
- `bash -n` passed for all changed shell files; warning-level ShellCheck passed
  through the lane check cache.

SKILL-EVIDENCE: engineering:debug — helped: the retained transcript and canonical
`parse_verdict` path isolated the late generic handoff instruction as the defect,
so the runner gate was not widened.

SKILL-EVIDENCE: superpowers:test-driven-development — helped: the imported stale
installer regressions were watched fail before `028a4bb` implementation was applied,
and new missing/contradictory-boundary assertions failed before the lint repair.

## DEFERRED

DEFERRED: the ten-product blind human visual corpus remains external and unrelated to
this autonomous installer/verdict-path recovery.
