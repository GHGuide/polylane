# Verify — calibration-campaign (c41-source-calibration-20260812-a1)

## Repair reflection (attempt 1 → attempt 2)

1. What went wrong: the prior attempt produced zero owned files — it stalled at interactive
   Bash permission prompts and PreToolUse hook errors before any test or script was written,
   and the session died without a commit.
2. Root cause: the prior run burned its whole budget on environment churn (prompt-blocked
   compound commands, repeated log reads) instead of writing the RED test and controller
   early; nothing durable existed when it was cut off.
3. Different approach now: write the failing test file and controller immediately with the
   dedicated Write/Edit tools (no prompt-prone shell heredocs), run the focused test +
   ShellCheck as the only loop, and commit as soon as the suite is green.

## Verification evidence

Run: `c41-source-calibration-20260812-a1` · Lane: `calibration-campaign` · Date: 2026-08-13

Deliverable: `bin/polylane-taste-calibration-campaign.sh` — the production calibration
campaign controller over the Cycle 40 isolated judge runner (`polylane-taste-judge-run.sh`)
and frozen `taste-judge-workunit/v1` manifests. It executes a frozen
`taste-calibration-campaign/v1` plan and enforces, fail-closed and before any adapter
invocation: unique work-unit ids and session ids (no shared ballot channel), pointwise
phase strictly before pairwise (including across resumes), primary/mirror pairs with
flipped A/B orientations in distinct sessions, provider/model/config pinning by adapter
fingerprint, and blindness (candidate/provider/model identity never in an adapter-visible
image path). Terminal outcomes (voted, abstained, failed-infra, failed-parse) are sealed
into an append-only hash-chained ledger binding manifest, adapter fingerprint, raw
response hash, and invocation-request hash. Resume is idempotent: sealed units — failed
ones included — replay from the ledger and are never re-invoked. The campaign summary
carries `decides_eligibility:false`; eligibility belongs to the calibration audit.

Commands and observed results:

```
$ bash tests/test-taste-calibration-campaign.sh
test-taste-calibration-campaign.sh: 47 pass, 0 fail

$ shellcheck -S warning bin/polylane-taste-calibration-campaign.sh tests/test-taste-calibration-campaign.sh
(clean, rc 0)
```

Test cadence covered (all fake providers; builder makes no real model calls):
order (pointwise before pairwise), isolation (per-unit run dirs, foreign campaign dir,
tampered ledger), duplicate session, duplicate work unit, mirror orientation, provider
pin mismatch, identity leak in image path, bounded infra retry (exactly two calls),
timeout (sealed failed-infra), malformed output (failed-parse, never retried), partial
resume (only unsealed units run; chain re-verifies), full-rerun idempotence, abstention
(substantive rc 0), and the no-eligibility guarantee. Watched RED first (rc 4 / missing
controller), then GREEN, per TDD.

SKILL-EVIDENCE: superpowers:test-driven-development — helped: RED run exposed a real
fixture defect (mirror-group ids shorter than the frozen `^mg-[a-z0-9-]{2,}$` regex)
before any controller code existed.
SKILL-EVIDENCE: engineering:testing-strategy — helped: shaped the single hermetic
integration-style suite around business-critical paths (ordering, isolation, resume)
instead of per-function unit noise.
SKILL-EVIDENCE: engineering:debug — helped: reproduce-isolate loop on the rc-4 plan
rejection pinned the failure to `validate_manifest_shape` on `mg-q`, not the controller.
SKILL-EVIDENCE: operations:risk-assessment — helped: the fail-closed guard list
(retry storms, shared sessions, ledger tamper, identity leak) was written as a risk
register first and became the pre-invocation check set.

SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/test-driven-development/SKILL.md | 1657109997-9015
SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
SKILL-READ: engineering:debug | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/debug/SKILL.md | 303222582-4074
SKILL-READ: operations:risk-assessment | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md | 3889652016-1630

