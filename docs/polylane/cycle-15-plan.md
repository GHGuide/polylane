# Cycle 15 plan — domain-general project execution

## Locked outcome

Polylane accepts a goal for any repository-backed project—not only an app—and
derives the right deliverables, evidence, lanes, skills, safety gates, and finish
condition. Software remains one project profile. Trading/research, operations,
content, and data work must execute without being rewritten as UI features or a
fictional deploy.

## Project contract

Every new run creates `docs/polylane/PROJECT_PROFILE.md` before the goal tree. It
locks the project kind, intended outcome, concrete deliverables, stakeholders,
constraints, available evidence, verification method, risk tier, and real-world
actions requiring approval. A deterministic profile helper validates the machine
form before lane derivation.

The initial profile adapters are:

- software/product — source, builds, tests, user paths, deployment evidence;
- trading/quant research — hypothesis, data provenance, leakage-free backtest,
  costs/slippage, out-of-sample robustness, risk limits, and paper execution;
- research/analysis — question, sources, method, reproducibility, uncertainty,
  and citation-backed conclusions;
- operations/business — process map, SOP/artifacts, dry run, KPI, controls, and
  stakeholder approval gates;
- content/creative — audience, artifact set, editorial/factual rubric, variants,
  and publication approval;
- data/automation — schemas, quality checks, transformations, sample outputs,
  repeatability, monitoring, and rollback;
- custom — explicit deliverables and evidence without forcing a preset.

Live trades, transfer of funds, publication, production deployment, legal approval,
messages to third parties, and other consequential external actions remain approval
gates. Polylane may prepare, simulate, backtest, dry-run, and verify everything that
does not cross that boundary.

## Lane carve

| Lane | Owns | Frozen evidence |
|---|---|---|
| `domain-contract` | Claude/Codex skill entrypoints, triggering metadata, durable project docs, discovery, profile reference | non-app prompts trigger and create a project profile; both providers stay semantically aligned |
| `project-runtime` | profile validator, planning/lane/prompt/skill routing, cross-domain corpus and tests | trading, research, operations, content/data, software, and custom fixtures produce suitable deliverables/evidence/safety gates |
| `integrator` | merge, cross-lane repair, install/parity, full certification | focused corpus, full suite, ShellCheck, fresh installs, no regression to app/UI specialization |

## Frozen checks

- Focused: `bash tests/test-project-generality.sh`
- Terminal: `bash tests/run.sh && shellcheck -S warning bin/*.sh`
- Installation/parity: `bash tests/test-skill-parity.sh && bash tests/test-installers.sh`

The run uses `balanced` intensity. Both builder lanes use the one available Codex
model at `high`; the integrator safety clamp uses `xhigh`.
