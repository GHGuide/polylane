# Cycle 15 integration verification

Run: `c15-domain-general-20260808` · integrator branch: `lane/c15-integrator`.

## Merged evidence and seam repairs

Merged `faa7f4d` (domain contract) and `85dc6a6` (project runtime), then inspected
their diffs and lane verification records. Integration repaired three seams:

- Made `tests/test-project-generality.sh` executable so the prescribed direct focused command is runnable.
- Added `polylane-project.sh gate <PROJECT_PROFILE.md> <profile.json>` so the durable review record and machine profile must agree before goal decomposition or lane carving.
- Restored the required literal Codex manifest identity (`"agent": "codex"`) and made the profile-record, machine-form, gate, route, and trading-safety promises parity-tested in both entrypoints.
- Restored the concise skill entrypoints' complete visual-intelligence contract after
  the full matrix exposed six dropped obligations: safe candidate admission, automatic
  council selection, product-specific visual/copy direction, blind comparison, bounded
  repair, and certification.

The actual cycle profile passes:

```bash
bin/polylane-project.sh gate docs/polylane/PROJECT_PROFILE.md docs/polylane/PROJECT_PROFILE.json
# project profile gate valid: kind=mixed
```

## Focused current-run matrix

```bash
bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" -- tests/test-project-generality.sh
# 1..35; PASS
bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" -- bash tests/test-skill-parity.sh
# 48 pass, 0 fail
bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" -- bash tests/test-visual-loop-integration.sh
# 28 pass, 0 fail
bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" -- bash tests/test-installers.sh
# 34 pass, 0 fail
bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" -- bin/polylane-markers.sh check-docs references/
# PASS
```

The corpus validates and creates non-overlapping owned artifact lanes for all seven
profiles: software app, trading strategy research, literature review, incident-response
playbook, content campaign, dataset-quality pipeline, and mixed/custom work. The custom
fixture explicitly accepts an unlisted industry when it supplies deliverables and evidence.
The adversarial trading mutation to `"execution":"autonomous-live"` is rejected with
`trading profiles cannot declare autonomous live execution`; the fixture defaults to
research/backtest/data-quality/peer-review evidence and an approval-required manual action.

Provider parity is **48/0**. Fresh copied-checkout installation is **34/0**: the Codex
package contains its standalone skill and all shared helpers, the Claude package contains
its separate skill and helpers, and the installed runner checksums match. No dedicated
skill validator is present under `bin/` or `tests/`; marker validation covered the linked
progressive-disclosure references.

## Terminal boundary

The integrator has finished all source and focused repairs. The outer runner now owns
the single frozen terminal acceptance:

```bash
bash tests/run.sh && shellcheck -S warning bin/*.sh
```

The suite contains **101 test files**; ShellCheck covers **52** `bin/*.sh` scripts.
This handoff is deliberately not a GO claim: the runner must record the authoritative
`m15.1` terminal result before promotion.

## External boundary

No live trade, spending, publication, production deployment, third-party message, or
manual/physical action was performed. The pre-existing `m12.4`/`c28` ten-product rendered
old-vs-new blind visual corpus remains the only external evidence item. It is not a pass
for cycle 15 or a claim that the visual work was completed.

POLYLANE-VERDICT: READY-FOR-HOST-GATE run=c15-domain-general-20260808
