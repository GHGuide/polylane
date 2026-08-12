STATUS: taste-memory DONE run=c39-visual-loop-20260812-a1

## Lane: taste-memory (Cycle 39)

Durable, project-scoped, evidence-only taste memory. Learns only from whole closed
HUMAN_CERTIFIED studies whose candidates passed every hard gate; returns bounded,
comparable, non-executable, advisory-only design lessons. Never authorises promotion,
never executes a stored string, never substitutes for capture or certification.

### Delivered (owned paths only)
- `bin/polylane-taste-memory.sh` — Bash 3.2 CLI, `main` guard, verbs `init` / `record` /
  `recommend` / `audit`.
- `tests/test-taste-memory.sh` (15), `tests/test-taste-memory-security.sh` (21),
  `tests/test-taste-memory-advice.sh` (14), `tests/test-visual-taste-memory-integration.sh` (16)
  — 66 assertions, all green.
- `docs/verify-taste-memory.md` — outputs, ledger/retrieval examples, diversity proof,
  poisoning matrix, trust model, SKILL-READ receipts + SKILL-EVIDENCE.

### Verification (this worktree)
- `shellcheck -S warning bin/polylane-taste-memory.sh` — clean.
- `git diff --check` — clean.
- Full lane replay — 66/66 pass.

### Contract highlights
- Admits only a whole `HUMAN_CERTIFIED` study (schema `taste-study-closure/v1`): ≥10 gated
  briefs, both candidates pass function/a11y/capture/context/provenance, clean threat scan.
  Machine-calibrated/evaluated outcomes are rejected (diagnostics only).
- Recomputes every closure/certificate/aggregate/reference/direction/candidate/capture/
  pixel/hard-gate/threat digest; derives winner/loser from bound aggregates; never trusts a
  caller winner/pass/hash label.
- Append-only hash-chained JSONL under a project `docs/polylane/` path; atomic, stale-lock-safe,
  idempotent; symlink/traversal/malformed/dup-key/dup-event/partial-line rejected.
- Stores opaque, non-executable pattern atoms only (no raw web text, prompts, code, secrets,
  candidate identity). Every stored/returned string is untrusted data.
- `recommend`: deterministic advisory JSON with opaque atom ids; requires ≥12 briefs / ≥4
  studies / ≥4 tasks / no study >34% / ≥70% same-sign / Wilson >0.50 before a directional
  lesson; else insufficient/conflicted/out-of-scope/none. Reserves a memory-blind arm +
  wildcard, caps source reuse, bounds count/bytes, `safe_to_promote:false`.
- `audit` fails closed on broken chain, invalid predecessor, tamper, impossible promotion,
  duplicate run/event, or unsafe stored content. No command edits an installed skill or
  global memory.

### Relay
- Startup: no requests addressed to taste-memory.
- Finalize: answered runner-wiring seq2 — CONFIRMED the `record` verb (post-verified,
  fail-closed); COUNTERED the flag/single-record proposal: interface is positional
  (`record LEDGER PROMOTION_RECEIPT`), payload must be a whole HUMAN_CERTIFIED study (a
  single-project SELECTED_NOT_CERTIFIED promotion is fail-closed rejected by design), and
  `--receipt-sha256` is not trusted (all digests recomputed, contrast derived).

### Skill evidence
- engineering:architecture — helped (ADR frame → self-contained content-addressed closure receipt).
- engineering:testing-strategy — helped (boundary/adversarial coverage → four-file split, 66 assertions).
- operations:risk-assessment — helped (likelihood×impact register → the poisoning matrix).
- productivity:memory-management — helped conceptually, storage format deliberately rejected
  (opaque atoms, not raw text). Details in docs/verify-taste-memory.md.

DEFERRED: none
