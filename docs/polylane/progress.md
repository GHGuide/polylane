# Polylane progress

Generated mechanically from `max-state.json`. Conversation summaries are not authoritative.

## Cycle 2

subgoals: 4/8 done · criteria: 1/6 done · 35%

**Route:** `CONTINUE m6.3  graph scheduler becomes authoritative after parity and stays within the frozen benchmark budget`

## Open autonomous work

- `m2.1` [open, w5] — rehearse canary green both cases, wired into doctor
- `m4.1` [open, w4] — suite + shellcheck + marker/parity contracts all green
- `m5.1` [open, w5] — tiny 2-lane claude self-run completes to GO
- `m6.3` [open, w8] — graph scheduler becomes authoritative after parity and stays within the frozen benchmark budget

## External/user evidence

- None

## Blocked

- None

## Criteria

- `c1` [open] — fresh-clone install works on both platforms
- `c2` [open] — suite green + shellcheck clean
- `c3` [open] — rehearse canary GO+NO-GO green
- `c4` [done] — docs executable as written
- `c5` [open] — real 2-lane self-run reaches GO unattended
- `c6` [open] — versioned graph execution is correct, recoverable, auditable, and benchmark-efficient

## Acceptance checks

- Total: 8
- Pass: 2
- Fail: 0
- Unchecked: 6
  - `m1.1` [unchecked] — bash tests/test-install-fresh.sh >/dev/null 2>&1
  - `m2.1` [unchecked] — cd /Users/leonardo/Downloads/polylane && bin/polylane-rehearse.sh go >/dev/null 2>&1 && bin/polylane-rehearse.sh nogo >/dev/null 2>&1
  - `m3.1` [unchecked] — cd /Users/leonardo/Downloads/polylane && bash tests/test-docs-truth.sh >/dev/null 2>&1
  - `m4.1` [unchecked] — cd /Users/leonardo/Downloads/polylane && tests/run.sh 2>/dev/null | grep -q "0 failed"
  - `m5.1` [unchecked] — cd /Users/leonardo/Downloads/polylane && test -f docs/polylane/selfrun-proof.md && grep -q "Outcome: GO" docs/polylane/selfrun-proof.md
  - `m6.3` [unchecked] — cd "${REPO:-/Users/leonardo/Downloads/polylane}" && bash tests/test-graph-benchmark.sh >/dev/null 2>&1 && bash tests/test-graph-authority.sh >/dev/null 2>&1 && bash tests/test-runtime-survival.sh >/dev/null 2>&1
