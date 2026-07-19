# ADR 002 — Keep the current layout: Claude at root, Codex as a thin overlay

- **Status:** accepted
- **Cycle:** 0

## Decision
Do NOT restructure into shared-core + claude-code/ + codex/ packages. The repo stays as it is: SKILL.md + bin/ + references/ at the root (Claude Code), with codex/install.sh assembling the Codex skill as a thin overlay from those same sources.

## Why
The restructure's stated benefits were reliability gaps, and every one of them was fixed IN PLACE at far lower risk: agent-aware preflight AND doctor (a codex manifest no longer demands claude), explicit agent announce (no more silent claude default), mechanical --effort, and resume-on-respawn. Moving every file would churn 24 helpers + 516 tests + two live installs to buy layout aesthetics, and the single source of truth (codex regenerates from the root SKILL.md) already prevents the drift a split is meant to solve.

## Consequences
Platform differences stay in the per-agent launcher inside the shared engine (agent_template / agent_procs / agent_bin). codex/install.sh remains the packaging seam. The three restructure plan docs are stamped STATUS: DEFERRED so no future session executes them. Revisit only if the single-root layout starts costing something real.
