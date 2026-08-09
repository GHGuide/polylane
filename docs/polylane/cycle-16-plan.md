# Cycle 16 plan — evidence-driven domain autonomy

## Locked outcome

Polylane must do more than route non-software projects through generic files. It must
execute domain-appropriate, provenance-bearing work; grade it with profile-specific
checks; learn only from accepted outcomes; spend model effort where it produces verified
progress; and survive long unattended runs. The same mechanisms must be available from
the Claude and Codex packages.

## Ten frozen requirements

1. Run real cross-domain trials backed by recorded public-source snapshots and optional
   live canaries, rather than relying only on invented fixtures.
2. Add declarative domain tool adapters with capabilities, dependency checks, provenance,
   side-effect classes, and deterministic offline fallbacks.
3. Add profile-aware graders, including temporal leakage, costs, robustness, and
   overfitting checks for trading research.
4. Learn from accepted evidence and expose sample size/confidence instead of treating
   worker activity as success.
5. Benchmark skill candidates on a lane-shaped task before they may become a recommended
   or armed default.
6. Add a resumable accelerated soak/fault harness and a real 6–24 hour wall-clock mode.
7. Optimize verified progress per token and minute across model, effort, lane count, and
   context budget, with safe clamps for thin evidence.
8. Seed discovery with domain-specific question trees and preserve the deeper-follow-up
   option until additional answers stop changing the plan.
9. Validate profile-specific final deliverable bundles, not a generic “files exist” claim.
10. Produce an impact preview and simulation receipt before every consequential external
    action; execution remains approval-required.

## Lane carve

| Lane | Exclusive write set | Frozen evidence |
|---|---|---|
| `domain-runtime` | new domain runtime, question, grading, deliverable, and action-preview helpers plus focused tests and fixtures | `bash tests/test-domain-runtime.sh` |
| `learning-economy` | outcome/skill evidence extensions, empirical optimizer, and focused tests | `bash tests/test-learning-economy.sh` |
| `trials-soak` | real-domain trial corpus/runner, soak and fault injection, and focused tests | `bash tests/test-domain-trials.sh && bash tests/test-soak.sh` |
| `integrator` | merge and repair; shared Claude/Codex contracts, docs, installation parity, and terminal certification | focused cycle contract, full suite, ShellCheck, installers, and live GO/NO-GO rehearsal |

The builders do not edit shared skill entrypoints or common reference files. The
integrator owns those seams after all three tips merge. Runtime tests are deterministic
offline; explicitly enabled live canaries may refresh source receipts but can never be a
CI or completion dependency.

## Execution policy

- Agent: Codex in isolated interactive tmux worktrees.
- Intensity: `balanced`; the currently available Codex model is used at high effort for
  builders and xhigh for the independent integrator.
- Prime-hybrid context, worker ledger, prompt compiler, skill-use receipts, and current-run
  nonce markers remain mandatory.
- No live trade, publication, production deploy, payment, third-party message, or other
  consequential action is authorized by this cycle.

## Terminal acceptance

```bash
POLYLANE_MIN_DISK_GB=0 bash tests/run.sh
shellcheck -S warning bin/*.sh
bash tests/test-skill-parity.sh
bash tests/test-installers.sh
POLYLANE_MIN_DISK_GB=0 bin/polylane-doctor.sh --rehearse
```

