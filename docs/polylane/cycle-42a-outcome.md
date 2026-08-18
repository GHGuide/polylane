# Cycle 42A outcome — immutable NO-GO, fresh-nonce recovery required

Run: `c42a-taste-contracts-20260813-a2`  
Target: `m32.6`  
Historical handoff: `4851bc12e22ab2260c2baeb1`  
Outcome: `NO-GO`

All four builders completed and the integrator assembled the executable v3 execution,
evidence, source-calibration, statistics, and lifecycle contracts. The focused
contract checks passed in the worker checkout. The worker's full suite then reached
three host-capability tests that require loopback binding or a private tmux socket;
the isolated worker host rejected those operations. The integrator correctly
committed a nonce-bound NO-GO rather than claiming success.

The handoff is historical and immutable. Its exact status SHA-256 is
`52c99513054a658f30277856ab04f7d810b672af870717721c86a80a4e93a033`; its exact
integration-evidence SHA-256 is
`4eb179e6c543b04e181efa996815b8623821c8bb2a678ab720889e3d98e5fee2`.
Later automated repair attempts exhausted Codex quota and created WIP checkpoints,
but they do not supersede that handoff.

On the normal host, the three capability tests passed individually and the complete
suite passed 4,049 assertions across 170 files with zero failures at candidate
`1e89f4f182b43fef7aa1b62bcdc9ed364c10aabe`. That is diagnostic
`PRECHECK_ONLY` evidence. It proves the sandbox explanation; it does not convert the
old NO-GO into GO and does not authorize promotion of a different commit.

Recovery therefore starts from a new run ID under orchestration contract v3. It must
import only content-addressed implementation artifacts, create fresh worker-owned
handoffs, execute the frozen host gate at the exact candidate, archive finalization
receipts, and promote only if that fresh run reaches GO.
