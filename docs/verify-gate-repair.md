# Cycle 27 gate-repair verification

Run: `c27-gate-repair-20260810-a1`

## Red evidence

- `tests/test-manifest-validation.sh` reproduced the optional-integrator bug:
  `good-manifest-rc0` expected `0`, got `1`.
- `tests/test-status-marker-normalization.sh` reproduced the three scope failures:
  exact committed near-miss, completed DONE contract, and health normalization.
- The strengthened dry-run fixture initially stopped before preview completion;
  its full contract-v2 launch now reaches the virtual-pane completion boundary
  without a tmux session.
- Diagnosis note: `POLYLANE_PROJECT_ROOT` is the immutable runtime control root,
  while this lane is the source worktree. The staged `./graphify-out/q.py`
  snapshot is therefore queried from the source worktree; failure evidence is
  explicitly passed the canonical project root rather than inferred from a
  worker's current directory.

## Green focused verification

- m24.1: `bash tests/test-manifest-validation.sh && bash tests/test-cycle-13-contract.sh && bash tests/test-scout.sh && bash tests/test-orchestration-contract.sh && bash tests/test-dryrun-pure.sh` — **124 pass, 0 fail**.
- m24.2: `bash tests/test-status-marker-normalization.sh && bash tests/test-lane-done.sh && bash tests/test-lane-done-live.sh && bash tests/test-scope.sh` — **78 pass, 0 fail**.
- m24.3: `bash tests/test-memory.sh && bash tests/test-contract-acceptance.sh && bash tests/test-verdict-repair.sh && bash tests/test-write-report.sh` — **178 pass, 0 fail**.
- `shellcheck -S warning bin/polylane-run.sh bin/polylane-scout.sh bin/polylane-memory.sh` — clean (zero output).
- All commands ran through `.polylane/check-cache/gate-repair`; the terminal full suite and doctor rehearsal were not run.

## Trust invariants reviewed

- Empty or absent integrator kits are no-ops. Any armed role triggers the same cardinality, installed-resolution, canonical trusted-path, source, fingerprint, duplicate-path, and four-skill checks as a builder.
- Dry-run uses virtual pane indices, never tags a nonexistent pane, creates no tmux session, and returns after its launch preview. Real launches still require pane tagging.
- Completion scope admits only the runner's final, two-path, current-run status rename: regular files, exact commit subject, one unambiguous source, byte-identical blobs, and no unrelated path. All other status deletions and ordinary out-of-scope paths remain rejected.
- Failed acceptance commands retain an atomic, bounded current-run JSON tail in canonical `docs/polylane/host-gate-failures/`; phase, command, return code, UTC timestamp, and output are JSON data. Host-gate records and reports link only a regular current-run evidence file. Passing checks create no durable failure file.

## Diff review

`git diff --check` passed. Reviewed only the owned runner, scout, memory, focused tests, and this verification record. Expected remaining scratch at handoff: `.polylane-prompt.txt` and `graphify-out`.

## Skill receipts

SKILL-READ: superpowers:systematic-debugging | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/systematic-debugging/SKILL.md | 4111822586-9465

SKILL-EVIDENCE: superpowers:systematic-debugging — helped: reproduced both terminal regressions before tracing their scout, normalization, scope, and host-evidence boundaries.

SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md | 1657109997-9015

SKILL-EVIDENCE: superpowers:test-driven-development — helped: empty-kit, preview-completion, marker-scope, and durable failure-tail assertions were written and observed red before their production repairs.
