# polylane — agent context

## Mission
One command turns an idea into a built, verified product via parallel file-isolated
lanes. The one thing: a stranger's first run works — flawlessly, unattended.

## Stack + key decisions
Pure bash 3.2 + jq + tmux; no runtime deps beyond `git` and an agent CLI
(`claude`, `codex`, or `aider`). Claude skill at repo root; Codex skill assembled by
`codex/install.sh` from the same sources (decision 002 — do not restructure).
Lanes are interactive tmux panes, never headless (decision 001).
All durable loop state lives in `docs/polylane/`; `.polylane/` is per-cycle scratch.

## Run / build / test
```bash
tests/run.sh                      # full suite (all tests/test-*.sh)
shellcheck -S warning bin/*.sh    # every script must stay clean
bin/polylane-doctor.sh            # environment preflight
bin/polylane-doctor.sh --rehearse # live end-to-end canary (GO + NO-GO)
```
Install (Claude): clone to `~/.claude/skills/polylane`. Install (Codex): `codex/install.sh`.

## Conventions
bash-3.2 safe (no assoc arrays) · `set -euo pipefail` · main-guarded helpers so tests
source functions · every fix ships a regression test · markers/docs must satisfy
`bin/polylane-markers.sh check-docs references/` and `tests/test-skill-parity.sh`.

## Status
Self-hosting marathon certified COMPLETE in cycle 10: 25/25 subgoals, 22/22
criteria, full suite, ShellCheck, fresh installs, and live GO/NO-GO rehearsal green.
Evidence and future informational experiments live in `docs/polylane/`
(`INDEX.md` is the front page).

## Cycle-16 evidence gates
For profile-aware work, use the typed domain discovery/grader and the deterministic
source-pinned trial helpers in [references/evidence-driven-domain-autonomy.md](references/evidence-driven-domain-autonomy.md).
Run accelerated soak faults locally; 6/12/24-hour soaks are resumable operator
certifications, not CI waits. Prepared action receipts are approval-bound simulations
only: the repository never authorizes execution, and trading remains paper research.
