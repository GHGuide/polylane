# Cycle 16 integration verification

Run: `c16-evidence-autonomy-20260809-a1`  
Branch: `lane/c16-integrator`

## Exact merged inputs

- `lane/c16-domain-runtime` at `c929c99`
- `lane/c16-learning-economy` at `a1c7622`
- `lane/c16-trials-soak` at `3449e63`

All three tips are ancestors of this branch. Their status and verification documents,
the bounded context packet (read once), and the canonical relay history were reviewed.
The one Cycle-16 inbox message was acknowledged through `polylane-workers.sh` and its
required scout admission seam is covered by the fresh contract test.

## Reproduced local evidence

```text
bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" -- bash tests/test-domain-runtime.sh
PASS 75/0
bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" -- bash tests/test-learning-economy.sh
PASS 56/0
bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" -- bash tests/test-domain-trials.sh
PASS 15/0
bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" -- bash tests/test-soak.sh
PASS 21/0
bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" -- bash tests/test-cycle-16-contract.sh
PASS 28/0
bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" -- bash tests/test-agent-adapter.sh
PASS 49/0
bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" -- bash tests/test-skill-parity.sh
PASS 57/0
bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" -- bash tests/test-installers.sh
PASS 50/0
shellcheck -S warning bin/*.sh
PASS no warnings
bin/polylane-seams.sh scan "$PWD"
PASS no seam output
bin/polylane-markers.sh check-docs references/
PASS no marker output
bin/polylane-project.sh validate docs/polylane/PROJECT_PROFILE.json
PASS kind=mixed
```

`tests/test-cycle-16-contract.sh` exercises successful and failing profile grades,
path traversal refusal, material/non-material post-cycle discovery, unbenchmarked scout
arming refusal, measured economy application, unknown telemetry receipt truth, runner
commit of the final grade before promotion, and both provider semantics. It is behavioral
coverage, not a documentation grep substitute.

## Package truth and risks

Codex and Claude installers each copy their own entrypoint plus the same Bash helper and
reference package. The fresh installer check proved the seven new helpers and the domain
autonomy reference in both packages; the existing shared-core checksum still matches.
No provider packages were combined.

The remaining bounded risks are operator-owned: a real 6/12/24-hour soak, an explicitly
requested read-only live canary, and any consequential action require their own evidence.
`SKIP` is not `PASS`; unknown telemetry is not optimizer input; and trading remains
paper-only. The historical external visual corpus `m12.4`/`c28` was left unchanged.

## Host-only terminal gate

Run once in the coordinator after this commit, not in this sandbox:

```bash
POLYLANE_MIN_DISK_GB=0 bash tests/run.sh && \
shellcheck -S warning bin/*.sh && \
bash tests/test-skill-parity.sh && \
bash tests/test-installers.sh && \
POLYLANE_MIN_DISK_GB=0 bin/polylane-doctor.sh --rehearse
```

POLYLANE-VERDICT: READY-FOR-HOST-GATE run=c16-evidence-autonomy-20260809-a1
