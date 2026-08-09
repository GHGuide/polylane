# Verification — optional domain gate

## Skill receipts

SKILL-READ: superpowers:systematic-debugging | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/systematic-debugging/SKILL.md | 4111822586-9465

SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md | 1657109997-9015

SKILL-READ: superpowers:verification-before-completion | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/verification-before-completion/SKILL.md | 1896692335-3646

## Reproduction and correction

Original failure from the preserved Cycle 18 integration rehearsal:

```text
ADVANCED: domain-grader=not-requested
fatal: pathspec 'docs/polylane/domain-runtime/bundle.json' did not match any files
```

The helper returns zero both for a requested grade that passes and for an optional grade that is not requested. `domain_grade_gate` then unconditionally appended integration evidence and staged the default bundle and grade paths. The correction returns after the successful helper invocation when the manifest has no enabled `domain_runtime`, before any durable post-processing. It does not inspect the helper's human-readable output or recreate grading, bundle, or path-validation logic.

## Red / green evidence

Red command, before the runner correction:

```text
bin/polylane-check.sh "$PWD/.polylane/check-cache/optional-domain-gate" -- bash tests/test-cycle-16-contract.sh
test-cycle-16-contract.sh: 32 pass, 3 fail
```

The red fixture was a clean Git repository with a valid generic manifest containing no `domain_runtime`. It proved the exact defect: gate exit failure, an amended `docs/verify-integration.md`, and a dirty repository after Git rejected the absent default bundle. The other two assertions already held: the helper result included `ADVANCED: domain-grader=not-requested`, and neither bundle nor grade file was created.

Green commands, after the one-condition wrapper correction:

```text
bin/polylane-check.sh "$PWD/.polylane/check-cache/optional-domain-gate" -- bash tests/test-cycle-16-contract.sh
test-cycle-16-contract.sh: 35 pass, 0 fail

bin/polylane-check.sh "$PWD/.polylane/check-cache/optional-domain-gate" -- bash tests/test-verdict-repair.sh
test-verdict-repair.sh: 40 pass, 0 fail

bin/polylane-check.sh "$PWD/.polylane/check-cache/optional-domain-gate" -- shellcheck -S warning bin/polylane-run.sh
CHECK-CACHE: PASS
```

The generic no-domain fixture now proves all absent-path requirements: `domain_grade_gate` exits 0; its captured result is exactly the explicit `not-requested` outcome; no bundle or grade file exists; `docs/verify-integration.md` remains only `POLYLANE-VERDICT: GO run=c16-generic`; `HEAD` is unchanged; and the repository remains clean.

The pre-existing requested-domain fixture was intentionally unchanged and remains green. It still creates and commits `docs/polylane/domain-runtime/bundle.json` and `grade.json`, and records `DOMAIN-GRADER: PASS` in integration evidence.

## Skill evidence

SKILL-EVIDENCE: superpowers:systematic-debugging — helped: the helper-to-wrapper trace isolated the success-state conflation before any production edit.

SKILL-EVIDENCE: superpowers:test-driven-development — helped: the clean generic fixture failed with the original Git pathspec and evidence side effects before the one-condition correction.

SKILL-EVIDENCE: superpowers:verification-before-completion — helped: fresh focused contract, verdict-repair, and ShellCheck commands confirmed the requested and absent paths before commit.
