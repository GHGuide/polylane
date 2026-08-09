# Cycle 16 integration verification

Run: `c16-evidence-autonomy-20260809-a1`  
Branch: `lane/c16-integrator`

## Merged inputs and durable state

The exact builder tips `c929c99` (`lane/c16-domain-runtime`), `a1c7622`
(`lane/c16-learning-economy`), and `3449e63` (`lane/c16-trials-soak`) are
ancestors of this integrator branch. The bounded context packet was read exactly
once. The durable inbox was queried through `polylane-workers.sh`; its available
entries were historical Cycle-15 relay records and required no current action.
`bin/polylane-refine.sh queue docs/polylane/harness` returned `[]`: both eligible
Cycle-16 refinement items have explicit canonical-harness declines.

## Reproduced local evidence

```text
bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" -- bash tests/test-domain-runtime.sh
PASS 76/0
bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" -- bash tests/test-learning-economy.sh
PASS 57/0
bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" -- bash tests/test-domain-trials.sh
PASS 15/0
bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" -- bash tests/test-soak.sh
PASS 21/0
bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" -- bash tests/test-cycle-16-contract.sh
PASS 29/0
bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" -- bash tests/test-agent-adapter.sh
PASS 49/0
bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" -- bash tests/test-skill-parity.sh
PASS 57/0
bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" -- bash tests/test-installers.sh
PASS 50/0
bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" -- shellcheck -S warning bin/*.sh
PASS no warnings
bin/polylane-seams.sh scan "$PWD"
PASS no seam output
bin/polylane-markers.sh check-docs references/
PASS no marker output
bin/polylane-project.sh validate docs/polylane/PROJECT_PROFILE.json
PASS kind=mixed
```

The canonical focused-acceptance run also passed and recorded `m16.1` through
`m16.4` focused checks. It marked `m16.1`–`m16.3` and criteria `c41`–`c50` done;
`m16.4` remains doing because its terminal acceptance is intentionally unchecked.

The cross-contract test exercises executable grader registration before launch,
bundle-grade PASS and failure paths, profile traversal and profile-symlink refusal,
material/non-material post-cycle discovery, unbenchmarked scout arming refusal,
measured economy application, durable recommendation logging, honest unknown telemetry,
and runner tracking of a final profile grade. It then asserts the same required
semantics on both provider contracts; it is not advertising-only coverage.

## Adversarial review and package boundaries

The review covered malformed JSON, missing `jq`, quoted manifest values, locale-stable
checksums, temp-file cleanup, stale/altered receipt payloads, traversal and symlinks,
secret-shaped preview fields, bounded read-only canaries, duplicate records, concurrent
skill-benchmark writes, thin samples, and false `PASS`/`SKIP`. A profile file or its
parent may no longer escape the project through a symlink; direct bundle calls also
reject a symlinked profile. The benchmark regression proves two concurrent submissions
of one receipt remain one ledger row. Economy scoring uses accepted receipts with verified
criteria/subgoal deltas, median token/time scores, availability, and role clamps; a
quality value without verified progress cannot win.

Claude remains the root shared package and Codex remains a thin, native overlay with
its own entrypoint and installed `scripts/` layout. No package was combined. The named
verification, code-review, Ponytail, and documentation kits were inaccessible in this
environment; their verification/review/documentation intent was applied directly.

Fresh provider parity passed **57/0**. A copied isolated checkout installed both packages
and passed **50/0**, including all new helpers/reference, standalone Codex source, no
Claude-only Codex contract, and byte-identical shared runner core.

## Remaining host-only terminal gate

Run this command once from the coordinator after this branch is committed. The local
integrator did not run the full suite, live rehearsal, a live canary, or a 6/12/24-hour
wait.

```bash
POLYLANE_MIN_DISK_GB=0 bash tests/run.sh && \
shellcheck -S warning bin/*.sh && \
bash tests/test-skill-parity.sh && \
bash tests/test-installers.sh && \
POLYLANE_MIN_DISK_GB=0 bin/polylane-doctor.sh --rehearse
```

The optional read-only live canary may be `SKIP`, never `PASS`. Any 6/12/24-hour soak
is resumable operator certification, and action previews remain approval-bound
simulations; trading remains paper research.

POLYLANE-VERDICT: READY-FOR-HOST-GATE run=c16-evidence-autonomy-20260809-a1
