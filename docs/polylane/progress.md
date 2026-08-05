# Polylane progress

Generated mechanically from `max-state.json`. Conversation summaries are not authoritative.

## Cycle 1

subgoals: 2/5 done · criteria: 0/5 done · 20%

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

- `c1` [open] — fresh-clone install works on both platforms
- `c2` [open] — suite green + shellcheck clean
- `c3` [open] — rehearse canary GO+NO-GO green
- `c4` [open] — docs executable as written
- `c5` [open] — real 2-lane self-run reaches GO unattended

## Acceptance checks

- Total: 5
- Pass: 0
- Fail: 0
- Unchecked: 5
  - `m1.1` [unchecked] — bash tests/test-install-fresh.sh >/dev/null 2>&1
  - `m2.1` [unchecked] — cd /Users/leonardo/Downloads/polylane && bin/polylane-rehearse.sh go >/dev/null 2>&1 && bin/polylane-rehearse.sh nogo >/dev/null 2>&1
  - `m3.1` [unchecked] — cd /Users/leonardo/Downloads/polylane && bash tests/test-docs-truth.sh >/dev/null 2>&1
  - `m4.1` [unchecked] — cd /Users/leonardo/Downloads/polylane && tests/run.sh 2>/dev/null | grep -q "0 failed"
  - `m5.1` [unchecked] — cd /Users/leonardo/Downloads/polylane && test -f docs/polylane/selfrun-proof.md && grep -q "Outcome: GO" docs/polylane/selfrun-proof.md
