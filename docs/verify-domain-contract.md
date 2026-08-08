# Verify — domain-neutral contract

## Trigger examples: before → after

| Project | Before (app-only trigger) | After (required route and truthful evidence) |
| --- | --- | --- |
| Trading strategy research | “Build an app for my trading idea.” | “Research and backtest a mean-reversion strategy.” Select trading/quant; record data provenance, leakage checks, costs/slippage, drawdown, robustness, risk limits, backtest/walk-forward or paper evidence. Never claim profit or a live trade. |
| Literature review | No clear trigger unless an app was requested. | “Review the literature on battery recycling methods.” Select research/analysis; deliver question, source ledger, method, findings, uncertainty, citations, and reproducible analysis. |
| Operations playbook | “Build an internal tool.” | “Create an incident-handoff playbook for support.” Select operations/business; deliver workflow, roles, controls, metrics, approval and escalation plan. Drafting it is not sending it or changing operations. |
| Dataset pipeline | “Build a data app.” | “Create a reproducible pipeline for our survey dataset.” Select data/automation; deliver schema, lineage, transforms, validation, observability, and rerun instructions. Live destination writes require authority and evidence. |
| Content campaign | “Build a marketing app.” | “Plan and prepare a launch content campaign.” Select content/creative; deliver brief, rights/provenance, assets, review criteria, channel plan, and publishing checklist. It is not published without authority and platform evidence. |
| Custom mixed project | “Build a dashboard.” | “Analyze retention, prepare an executive playbook, and prototype the supporting tool.” Select custom/mixed; profile each component and preserve the strictest evidence and safety boundary. |
| App | “Build an app that helps teams coordinate.” | “Build an app that helps teams coordinate.” Select software; deliver working behavior, operating instructions, tests, and user-path evidence. Load Visual Intelligence only if it has a user-facing UI. |

## Contract assertions

- Both entrypoints describe any repository-backed project, not only a software/app build.
- Both entrypoints require `docs/polylane/PROJECT_PROFILE.md` before goal decomposition and
  link [project-types.md](../references/project-types.md).
- Discovery orders questions as outcome/profile/evidence/risk, then loads only relevant
  profile questions while preserving recommended, deeper, and bold routes.
- Documentation requires operating instructions, provenance, reproduction/validation,
  decisions, and handoff rather than only built-app commands.
- Trading is research-first; consequential action requires explicit authority and actual proof.
- UI Visual Intelligence is conditional on user-facing UI work.

## SKILL-EVIDENCE

- `skill-creator`: kept the provider entrypoints concise and moved domain variants into one
  directly linked progressive-disclosure router, while preserving triggering metadata.
- `product-management:write-spec`: supplied the profile fields—outcome, deliverables,
  stakeholders, constraints, evidence, risk, external actions, and finish conditions—as the
  durable pre-decomposition contract.
- `superpowers:test-driven-development`: drove the implementation from existing parity and
  marker checks, with exact assertions for the new domain contract where no sibling test exists.
- `superpowers:verification-before-completion`: required focused checks, line-count limits,
  parity, marker validation, and explicit evidence before this lane reports DONE.
