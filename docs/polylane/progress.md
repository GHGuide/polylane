# Polylane progress

Generated mechanically from `max-state.json`. Conversation summaries are not authoritative.

## Cycle 3

subgoals: 5/8 done · criteria: 3/6 done · 57%

**Route:** `CONTINUE m2.1  rehearse canary green both cases, wired into doctor`

## Open autonomous work

- `m2.1` [open, w5] — rehearse canary green both cases, wired into doctor
- `m4.1` [open, w4] — suite + shellcheck + marker/parity contracts all green
- `m5.1` [open, w5] — tiny 2-lane claude self-run completes to GO

## External/user evidence

- None

## Blocked

- None

## Criteria

- `c1` [done] — fresh-clone install works on both platforms
- `c2` [open] — suite green + shellcheck clean
- `c3` [open] — rehearse canary GO+NO-GO green
- `c4` [done] — docs executable as written
- `c5` [open] — real 2-lane self-run reaches GO unattended
- `c6` [done] — versioned graph execution is correct, recoverable, auditable, and benchmark-efficient

## Acceptance checks

- Total: 8
- Pass: 5
- Fail: 0
- Unchecked: 3
  - `m2.1` [unchecked] — cd "${REPO:-/Users/leonardo/Downloads/polylane}" && bin/polylane-rehearse.sh go >/dev/null 2>&1 && bin/polylane-rehearse.sh nogo >/dev/null 2>&1
  - `m4.1` [unchecked] — cd "${REPO:-/Users/leonardo/Downloads/polylane}" && tests/run.sh 2>/dev/null | grep -q "0 failed" && shellcheck -S warning bin/*.sh
  - `m5.1` [unchecked] — cd "${REPO:-/Users/leonardo/Downloads/polylane}" && test -f docs/polylane/selfrun-proof.md && grep -q "Outcome: GO" docs/polylane/selfrun-proof.md
