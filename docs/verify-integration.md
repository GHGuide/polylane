# Cycle 13 integration verification

Run: `c13-perfection-20260808` on `lane/c13-integrator`.

## Integration and cross-lane review

All current lane tips are clean ancestors of this branch: model policy
`a6ca988`, skill intelligence `822a765`, prompt compiler `c0d8ca1`, and
lifecycle hooks `1cf08fd`. `git diff --check 9ffffd9..HEAD` is clean and the
four builder worktrees are clean. The merged runner resolves policy before
launch, compiles launch-only prompts before preflight, writes skill-use audits
after verification, and keeps hooks optional to the supervisor.

## Fresh commands and results

Every repeatable check used `bin/polylane-check.sh` with
`$PWD/.polylane/check-cache/integrator`.

```sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator/acceptance-focused-cycle13" -- \
  bash bin/polylane-memory.sh "$PWD/docs/polylane/max-state.json" check-accept \
  --cycle 13 --targets m13.1,m13.2,m13.3,m13.4,m13.5 --focused
bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator/test-cycle-13-contract" -- \
  bash tests/test-cycle-13-contract.sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator/test-skill-parity" -- \
  bash tests/test-skill-parity.sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator/test-installers" -- \
  bash tests/test-installers.sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator/terminal-full-suite" -- \
  env POLYLANE_MIN_DISK_GB=0 bash tests/run.sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator/terminal-shellcheck" -- \
  shellcheck -S warning bin/*.sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator/terminal-fresh-install" -- \
  bash tests/test-install-fresh.sh
```

Focused frozen acceptance passed for all five m13 targets. The hermetic vague
brief contract passed **38/0**; semantic parity **43/0**; installer parity
**34/0**. The current full suite passed **1,778/0 across 96 files**;
ShellCheck is clean for every `bin/*.sh`; fresh Claude/Codex installs passed
**37/0**. The new focused seam counts were model policy **15/0**, intensity
**20/0**, models **21/0**, catalog **26/0**, scout **26/0**, outcomes **18/0**,
acquisition **16/0**, prompt optimizer **9/0**, prompt lint **22/0**, compiler
**12/0**, hooks **29/0**, workers **45/0**, and cycle routing **18/0**.
`bash bin/polylane-certify.sh focused` also passed its named discovery,
planning/prompt, model-policy, skill-routing, graph/runtime/recovery,
integration/learning, install/parity, and ShellCheck layers; rehearsal is
explicitly terminal-only.

The durable goal state now marks c30–c34 and m13.1–m13.5 `done`. Their focused
and terminal acceptance records are `pass`, including the coordinator-owned
physical rehearsal.

## Observable contracts

Before launch, Claude balanced resolves builder `claude-sonnet-5/high`,
mechanical `claude-sonnet-5/medium`, security `claude-opus-4-8/high`, and
integrator `claude-fable-5/xhigh`. Codex performance with a CLI override
resolves builder `gpt-5.6-sol/high`, mechanical `gpt-5.6-terra/medium`,
security `gpt-5.6-terra/high`, and integrator `gpt-5.6-sol/xhigh`. Thus the
manifest is effective, CLI intent is applied first, and role safety clamps are
final and printed.

The frozen prompt fixture compiles from **991 bytes / 331** local compatibility
estimate to **957 bytes / 319**: one 34-byte repeated non-contract line is
removed and frozen contracts compare equal. These are deterministic local
estimates, not provider token or quality claims. Catalog recommendations remain
metadata-only until planning selects a kit; `use-audit` records a missing verify
file as `unused`. Acquisition still requires authorization, quarantine, audit,
benchmark, pin, project install, and rollback metadata.

Both installed packages include project-scoped hook fragments only. Codex
SessionStart emits bounded `hookSpecificOutput.additionalContext`; Claude emits
the same bounded context in `systemMessage`; a stale Stop marker returns one
structured `block` decision. The supervisor remains the runtime authority.

## Continuity, skill evidence, and external proof

The local durable inbox is empty. The refinement queue is empty; both eligible
records have already been explicitly declined in
`docs/polylane/harness/refinement-decisions.jsonl` because neither demonstrated
a new bounded local fix. The resulting route is `NEEDS-USER` only for the
external m12.4 rendered corpus; there is no remaining autonomous implementation
item.

| Lane | SKILL-EVIDENCE observed from its verification |
| --- | --- |
| model policy | `test-driven-development`, `systematic-debugging`, `system-design`, and `process-optimization`: unused (no resolved kit path). |
| skill intelligence | `test-driven-development`, `verification-before-completion`, `skill-creator`, and `writing-skills`: helped. |
| prompt compiler | `test-driven-development`, `verification-before-completion`, `caveman-compress`, and `write-spec`: helped. |
| lifecycle hooks | `test-driven-development`, `systematic-debugging`, `system-design`, and `risk-assessment`: unused (no resolved kit path). |
| integrator | `polylane`: helped by context, inbox, refinements, cache, and routing; `code-review`, `verification-before-completion`, `risk-assessment`, and `testing-strategy`: unused (no resolved kit path). |

The sandboxed integrator correctly could not create a host tmux socket, so the
outer coordinator executed the required rehearsal. The preserved pre-repair
attempt remains in `docs/verify-integration-attempt-1.md`:

```sh
env -u TMUX POLYLANE_MIN_DISK_GB=0 bash bin/polylane-doctor.sh --rehearse
```

The host result was:

```text
REHEARSE-GO contract-v3=1 ready=1 promoted=1 terminal_gates=1 cleaned=1 leaks=0
REHEARSE-NOGO contract-v3=1 promoted=0 evidence=1 retained=1 bounded=1 cleaned=1
rehearse: both contract-v3 cases passed — supervised lifecycle is sound
```

The exact frozen terminal acceptance then exited 0 and recorded `m13.5` as
`pass`. Historical c28 rendered ten-product comparison evidence remains
external and has not been converted to PASS.

POLYLANE-VERDICT: EXTERNAL-EVIDENCE-OPEN run=c13-perfection-20260808
