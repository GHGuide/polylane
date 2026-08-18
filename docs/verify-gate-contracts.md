# Gate-contract verification — Cycle 17

Run: `c17-recovery-cert-20260809-a1`
Scope: `tests/test-graph-authority.sh`, `tests/test-verdict-repair.sh`, and
`tests/test-wedge.sh` only.

## Root cause and repair

`gate_with_repairs` now requires `domain_grade_gate && merge_gate`. The
graph-authority test's final mock flow replaced `merge_gate` but left the real
domain gate active. Its ambient manifest/evidence preconditions failed before
the mock merge gate could run, so the test observed neither of its expected
`merge:` records. The fixture now explicitly stubs `domain_grade_gate` only in
that mock-only block. The actual runtime invariant remains behaviorally tested:
the verdict-repair flow counts the production loop's calls to the grade gate and
requires one call before each of its three merge attempts.

The liveness fixture now exercises the real `lane_terminal_turn` classifier
with an append-only log containing an old `agent_message`. It proves that the
message is progress rather than a terminal boundary: a live high-effort lane at
the normal restart threshold remains inside its 40-check grace window. Existing
assertions retain the complementary boundary contract: a completion/error is
terminal only while it is the newest turn boundary, and a later `turn.started`
clears the older terminal result.

## Red evidence

Initial focused reproduction:

```text
bash tests/test-graph-authority.sh
FAIL authority-gate-repair-eventually-go — expected rc 0, got 1
FAIL authority-gate-before-every-verifier-action — merge records absent
test-graph-authority.sh: 54 pass, 2 fail

bash tests/test-verdict-repair.sh
test-verdict-repair.sh: 35 pass, 0 fail

bash tests/test-wedge.sh
test-wedge.sh: 26 pass, 0 fail
```

While strengthening the domain-call assertion, the first attempt used
`assert_ok`, whose command runs in a subshell. The counter therefore stayed at
zero despite the runner calling the stub. The stateful case now invokes
`gate_with_repairs` directly and asserts its return code plus the counter.

## Green evidence

All repeated checks used the lane cache as required:

```text
bin/polylane-check.sh "$PWD/.polylane/check-cache/gate-contracts" -- bash tests/test-graph-authority.sh
PASS 56/0

bin/polylane-check.sh "$PWD/.polylane/check-cache/gate-contracts" -- bash tests/test-verdict-repair.sh
PASS 36/0

bin/polylane-check.sh "$PWD/.polylane/check-cache/gate-contracts" -- bash tests/test-wedge.sh
PASS 27/0
```

No full suite was run; it remains the coordinator's terminal gate.

SKILL-EVIDENCE: superpowers:systematic-debugging — unused: the requested skill is not installed; direct reproduction isolated the missing domain-gate fixture.
SKILL-EVIDENCE: engineering:testing-strategy — unused: the requested skill is not installed; focused red/green checks preserved runtime call and boundary assertions.
SKILL-EVIDENCE: engineering:incident-response — unused: the requested skill is not installed; evidence records the compatibility seam and its smallest repair.
