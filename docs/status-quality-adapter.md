STATUS: quality-adapter DONE run=c39-visual-loop-20260812-a1

## Delivered

Authoritative `certify PROJECT_ROOT RECORD_JSON VERDICT_JSON [ATTEMPT]` mode on
`bin/polylane-visual-quality.sh`. Derives `visual-quality-verdict/v2` solely from
hash-bound producer receipts + a real capture verification. Legacy `run` and
`benchmark` modes byte-for-byte unchanged; legacy lens statuses never certify.

- Invokes `polylane-taste-pixels.sh verify` for trusted decoded-pixel evidence.
- Strictly validates + hash-binds the tournament receipt and re-derives the
  Condorcet winner (caller winner/status/pass fields are untrusted).
- Hard vetoes: function, accessibility, state coverage, provenance/injection.
- Bounded repair (attempt 0|1|2): unchanged/third/ungrounded → halted, incumbent
  preserved. Adapter absence → external, never pass.
- Emits immutable hashes, selected/incumbent decision, grounded repair targets,
  SELECTED_NOT_CERTIFIED label, human_claim=false (fixtures never mint human cert).

## Verification (all green)

- `tests/test-visual-quality.sh`: 37 pass, 0 fail (7 legacy compat + 13-case
  adversarial matrix + positive real-capture record).
- `shellcheck -S warning bin/polylane-visual-quality.sh`: clean.
- `git diff --check`: clean.

Evidence + attack matrix + reason-code table + SKILL-EVIDENCE: docs/verify-quality-adapter.md.

## Relay

Handled seq1 (runner-wiring, COUNTER) and seq12 (a11y-evidence, CONFIRM). One
open item: DEFERRED authoritative-alias-wire — runner-wiring consumer surface
awaits their field confirm; integrator reconciles. Canonical `certify` complete.
