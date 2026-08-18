# Cycle 26 plan — transactional repair and terminal report certification

## Goal

Make terminal outcomes atomic and observable: no strict-scalar repair failure can
destroy a valid handoff, no immutable runtime failure consumes the expensive terminal
gate, and every completed GO/NO-GO reaches exactly one fresh report. Then certify the
entire Cycle 24–26 candidate in a new process with zero restarts.

Frozen base: `7854a1f` (`candidate/c26-base`).

## Frozen lanes

| Lane | OWN | Required outcome |
| --- | --- | --- |
| `terminal-finality` | runner/supervisor terminal and repair paths; prompt finality guidance; focused regression tests; lane evidence | Make integrator repair prompts scalar-safe; validate a replacement prompt before any checkpoint/evidence deletion; add a cheap pre-terminal efficiency eligibility gate; guarantee terminal reporting despite graph/telemetry finalization errors; preserve current-run evidence on failed admission/resume. |
| `integrator` | exact-tip merge, bounded cross-lane seam fixes, Cycle 26 evidence | Merge the exact builder tip, independently audit transaction ordering and report/supervisor behavior, prove all prior pane/inbox/custom-policy contracts, then emit READY only when the coordinator can run the terminal boundary once. |

## Frozen interfaces

- `build_integrator_repair_prompt` may append ordinary repair prose but no second
  `DELEGATION`, `CHECK-CACHE`, or other strict scalar label.
- `repair_integrator_verdict` must build and strictly admit its new prompt before it
  checkpoints the branch, archives/removes verdict files, updates runtime prompt state,
  or respawns a pane. Admission failure leaves HEAD, status, verdict, and pane intact.
- A source-green integrator does not reinterpret restart counters. It emits
  `READY-FOR-HOST-GATE`; the runner owns runtime eligibility and terminal checks.
- The runner rejects known-ineligible restart/supervisor/launch telemetry before
  incrementing `terminal_gates` or running expensive terminal acceptance.
- Once autonomous repair is exhausted or impossible, report publication is attempted
  before returning nonzero even if graph finalization, optional learning, notification,
  or telemetry recording fails.
- A fresh NO-GO report is terminal to the supervisor. A missing report remains
  recoverable, but resume cannot destroy committed current-run evidence merely because
  replacement-prompt admission fails.
- Marker nonce, marker-last commit, live-agent completion gate, post-completion scope
  gate, pane-local identity, run-scoped inbox, custom model policy, and legacy behavior
  remain unchanged.

## Frozen verification

The builder starts from a deterministic red reproduction of the Cycle 25 chain and
runs only focused tests plus changed-script ShellCheck. The integrator reruns all
repair/report/supervisor tests and the Cycle 24/25 identity, inbox, prompt, scope, and
policy matrices. It audits direct Graphify queries and confirms no Graphify skill read.

The coordinator then consumes exactly one terminal gate:

```bash
POLYLANE_MIN_DISK_GB=0 tests/run.sh && \
shellcheck -S warning bin/*.sh && \
bash tests/test-skill-parity.sh && \
bash tests/test-installers.sh && \
POLYLANE_MIN_DISK_GB=0 bin/polylane-doctor.sh --rehearse
```

GO additionally requires two launches total (one builder plus integrator), zero lane
restarts, zero supervisor restarts, exactly one terminal gate, known nonzero token
telemetry, successful promotion and cleanup, pane-local identity immediately after
launch, and a current-run report. Any repair mutation before admission, duplicate
scalar, reportless terminal exit, supervisor revival, second gate, or incomplete
cleanup is NO-GO. No push, deployment, publication, purchase, live action, or trading
execution is authorized.

## Target tree

This run targets every still-open Cycle 24/25 capability (`m21.1`–`m22.3`) plus
`m23.1`–`m23.3`, and criteria `c57`–`c62`, because only a fresh terminal certification
can honestly close the accumulated source work.

