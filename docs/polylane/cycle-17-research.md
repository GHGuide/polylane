# Cycle 17 research — recovery evidence

Cycle 17 required no new external-source research. Its evidence base was the preserved
Cycle-16 terminal transcript, the failing contract fixtures, the live Codex JSONL lane
logs, and direct source inspection of `domain_grade_gate`, `gate_with_repairs`,
`lane_terminal_turn`, `arm-recommendation`, and the public skill benchmark gate.

The investigation established two actionable causes: graph/verdict fixtures had become
non-hermetic after a new pre-verdict domain grader, and selected-skill arming trusted a
caller-supplied recommendation instead of revalidating exact fingerprint/domain/lane
shape receipts. It also proved stale `agent_message` output is progress rather than a
terminal turn boundary. Those findings were implemented and reproduced in Cycle 17; the
later host-resource/retry failures are preserved as Cycle-18 inputs, not rewritten here.
