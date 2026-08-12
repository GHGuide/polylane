STATUS: task-live DONE run=c40-live-harness-20260812-a3

Lane task-live delivered the per-brief action/state/task hard gate.

Owned artifacts (committed 99fa53c):
- bin/polylane-taste-task.sh — replay validator + hard-gate compiler (`gate`).
- benchmarks/taste-live/task-schema.json — taste-task-plan/v1, adapter-result/v1,
  receipt/v1, frozen allowlists, safety rules, reason-code catalogue.
- tests/test-taste-task-live.sh — 48 adversarial assertions, all green.
- docs/verify-task-live.md — schema examples, verdict derivation, product-signature
  specificity, deterministic replay, full 21-row attack matrix, skill evidence.

Contract met: allowlisted actions/assertions only; safe relative routes/selectors;
no eval/script/network from a brief. Binds brief + design-lock, candidate revision,
capture matrix, trace/DOM hashes, task id, expected state, assertions, adapter
receipt. Every required task/state/assertion must resolve; missing/unknown/fail
vetoes. Verdicts are validator-DERIVED from adapter-measured evidence joined with
the coordinator-pinned oracle — never a caller status. Product signature proves a
brief-specific mechanism, rendered anchor, clause trace, unrelated-brief
counterfactual (must be absent), and task proof. classification fixture,
human_certified false — can never mint a production PASS.

Evidence: ShellCheck -S warning clean; test 48 pass 0 fail
(.polylane/check-cache/task-live). Relay: replied to corpus-20 seq1 confirming the
action_oracle op-map onto taste-task-plan/v1 (no shape change needed). Requests
seq2/seq3 addressed other lanes (generate-live, study-live), not handled here.

SKILL-EVIDENCE: engineering:testing-strategy — helped: framed the red-first attack
matrix (data-integrity + security boundaries), one deterministic oracle per row.
SKILL-EVIDENCE: product-management:write-spec — helped: Given/When/Then acceptance
discipline became the per-assertion oracle and the falsifiable signature counterfactual.
