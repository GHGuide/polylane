# Project profiles — route by outcome, not by implementation habit

Polylane supports any project whose work, decisions, and evidence can live in a
repository. Before decomposition, choose the closest profile below (or a mixed
profile), write `docs/polylane/PROJECT_PROFILE.md`, and load only that profile's
questions and validation. The profile selects deliverables and proof; it never
authorizes a consequential external action.

## Required profile record

Keep `PROJECT_PROFILE.md` short and concrete:

```md
# Project profile
Outcome: <the durable change or answer wanted>
Profile: <one of the routes below; mixed if necessary>
Deliverables: <repository-backed artifacts>
Stakeholders: <owners, users, reviewers, affected parties>
Constraints: <time, budget, policy, privacy, tools, scope>
Evidence: <commands, source provenance, review, measurements, or manual proof>
Risk: <harm, uncertainty, reversibility, dependencies>
External actions: <none, or action + authority owner + required proof>
Finish conditions: <observable criteria and explicit external boundaries>
```

Unknowns stay explicit. An `external` finish condition is not a pass: continue all
independent work, preserve the blocker and requested authority, and never invent
the missing proof.

## Routes

### Software

Deliver a working change, operating instructions, tests, and user-path evidence.
Ask about users, interfaces, data, integrations, compatibility, and deployment.
Use [visual-intelligence.md](visual-intelligence.md) only when the work includes a
user-facing UI. Validate focused behavior, regressions, accessibility where relevant,
and install/run or package evidence.

### Trading / quantitative research

Default to a research artifact, reproducible data provenance, backtest,
walk-forward or out-of-sample evidence, and paper-trading plan—not a promise of
profit. Record universe, timestamps, source/licensing, assumptions, leakage checks,
fees, slippage, drawdown, robustness/sensitivity, and risk limits. A live trade,
broker action, capital allocation, or investment recommendation needs explicit user
authority and actual execution evidence; simulation or paper results never imply it.

### Research / analysis

Deliver a scoped question, method, source ledger, synthesized findings, uncertainty,
and reproducible analysis. Ask about audience, decision use, source quality,
inclusion/exclusion rules, conflicts, privacy, and citation style. Distinguish facts,
inferences, and unresolved evidence; do not call a literature review legal, medical,
or policy approval without the required qualified review.

### Operations / business

Deliver a decision-ready playbook, workflow, roles, controls, metrics, and rollout or
handoff plan. Ask about owners, service levels, current process, dependencies,
approvals, reversibility, and escalation. Drafting a process is not sending messages,
changing production systems, purchasing, hiring, or committing an organization—those
need named authority and outcome evidence.

### Content / creative

Deliver a brief, source/rights record, audience and channel plan, drafts/assets,
review criteria, and publishing checklist. Ask about voice, claims, brand, rights,
approvals, audience, and success signals. Treat a scheduled or published item as
external until its URL, platform record, or equivalent evidence exists and the user
authorized publication.

### Data / automation

Deliver schemas, source provenance, transformations, validation, observability, and
reproduction instructions. Ask about owners, refresh cadence, quality thresholds,
PII/secrets, retention, destination, failure handling, and rollback. Validate sample
and edge cases, lineage, idempotence, and cost/rate limits. Writes to live data or
automation targets require explicit authority and execution evidence.

### Custom / mixed

Name the component profiles and their dependencies. Keep one outcome and shared
finish conditions, then apply each component's evidence and safety gates. Do not let
a software subtask erase research uncertainty or turn a drafted external action into
a completed one.

## Completion language

Say what the evidence proves: “backtest completed under recorded assumptions,”
“playbook approved by <name>,” or “dataset validated by <command>.” Do not say
“profitable,” “approved,” “deployed,” “published,” “sent,” “executed,” or “live”
without the actual evidence and the required authority.
