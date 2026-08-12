STATUS: judge-claude DONE run=c40-live-harness-20260812-a3

Lane: judge-claude — isolated noninteractive Claude visual-judge adapter.

Delivered:
- bin/polylane-taste-judge-claude.sh — invoke + verify; provider-native bounded
  argv; isolated config/session state; taste-judge-claude-receipt/v1 binding CLI
  bin/version/command hash, prompt+schema hashes, ordered image SHA-256s,
  composite request hash, raw stdout/stderr hashes + escrowed sidecars, exit
  status, timed_out, start/end UTC+epoch, redacted env key-names. Never parses a
  preference; never decides eligibility/winner/certification.
- benchmarks/taste-live/prompts/judge-claude-system.md — pointwise-before-choice,
  hidden identities, no author/provider speculation, abstain on insufficient
  evidence, untrusted screenshot text ignored as instructions.
- tests/test-taste-judge-claude.sh — 54/54 pass. Fake-CLI matrix: success,
  abstain, malformed, timeout, non-zero, missing binary, changed
  model/prompt/image, shell-injection, secret-redaction, provenance tamper.
- docs/verify-judge-claude.md — attack results, exact contract, no-secret check,
  skill receipts + evidence.

Verification: bash tests/test-taste-judge-claude.sh -> 54 pass 0 fail;
shellcheck -S warning on adapter+test -> PASS.

Classification: every produced receipt is fixture_only. Live Claude smoke is
EXTERNAL-EVIDENCE-OPEN, owned by the deferred taste-live-integrator, not this
lane. Relay request posted to calibration-live for the canonical shared
response-schema path + schema_version.

FORBIDDEN paths untouched; only owned files staged and committed.
