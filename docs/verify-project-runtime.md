# Project-runtime verification

## RED

Command:

```text
bin/polylane-check.sh "$PWD/.polylane/check-cache/project-runtime" -- bash tests/test-project-generality.sh
```

Initial result before implementation:

```text
tests/test-project-generality.sh: line 20: .../bin/polylane-project.sh: No such file or directory
not ok - validate app
CHECK-CACHE: FAIL rc=1 ... — repair source before retry
```

## GREEN

After adding `bin/polylane-project.sh` and the domain-neutral references:

```text
ok - validate app
ok - validate trading-strategy-research
ok - validate literature-review
ok - validate incident-response-playbook
ok - validate content-campaign
ok - validate dataset-quality-pipeline
ok - validate mixed-custom
ok - compile mixed-custom into non-overlapping file-isolated artifact lanes
ok - accept custom industry without an allowlist
ok - reject autonomous live trading
ok - reject missing evidence modes
ok - require explicit approval actions for high risk
1..32
CHECK-CACHE: PASS
```

## Validated profiles

`bin/polylane-project.sh validate` accepts version-1 profiles for:

- software app: source and runbook, automated-test/build/manual-demo evidence;
- trading strategy research: notebook and analysis, backtest/data-quality/peer-review evidence;
- literature review: synthesis and source matrix, citation-audit/coverage-review evidence;
- incident response: runbook and configuration, tabletop/dry-run/peer-review evidence;
- content campaign: brief and media, editorial/brand/link-check evidence;
- dataset quality pipeline: dataset and analysis, data-quality/reproducible-run evidence;
- mixed custom project: analysis, runbook, and media, with an unlisted industry accepted through `custom`/`mixed`.

`brief` emits sorted validated JSON, preserving the outcome, every deliverable's
artifact path, evidence modes, risk tier, and external-action policy. Those paths
compile through the real `polylane-scope.sh check-static` gate as non-empty,
non-overlapping lane `own_globs`; no lane is invented for work without a changed
artifact and evidence.

## External-action boundary

The trading fixture uses an approval-required manual action. Mutating it to
`"execution":"autonomous-live"` is rejected with:

```text
polylane-project: trading profiles cannot declare autonomous live execution
```

High and consequential profiles require at least one consequential,
approval-required action and policy mode `approval-required`. Prompts permit only
simulations, samples, dry runs, backtests, and prepared artifacts unless explicit
authority and evidence authorize an external action.

## Installer implications

No installer or skill entrypoint change is required: the runtime helper is a
Bash-3.2 executable under `bin/`, and its only runtime dependency is the existing
`jq` prerequisite. Fresh installs receive the same helper with the repository;
prompts select installed skills only and never install an unreviewed suggestion.

SKILL-EVIDENCE: superpowers:test-driven-development — the missing runtime command
was exposed by the focused corpus before implementation, then the smallest validator
was added to make the same test green.

SKILL-EVIDENCE: superpowers:verification-before-completion — RED and cached GREEN
outputs are recorded here; no success claim depends on prose alone.

SKILL-EVIDENCE: engineering:testing-strategy — the corpus covers seven distinct
project outcomes plus missing evidence, unsafe trading, high-risk approval, and
custom-industry boundary cases.

SKILL-EVIDENCE: product-management:product-brainstorming — profiles are expressed
as outcome, deliverables, evidence, risk, and action policy instead of an assumed
software implementation shape.

## DEFERRED

DEFERRED: none
