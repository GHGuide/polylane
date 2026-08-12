STATUS: judge-codex DONE run=c40-live-harness-20260812-a3

Lane: judge-codex — isolated noninteractive Codex visual-judge adapter.

Delivered (owned paths only):
- bin/polylane-taste-judge-codex.sh — native `codex exec` adapter; exact ordered
  images + frozen structured request; preserves raw output verbatim; emits a
  taste-judge-codex-invocation/v1 provenance record only. Never parses a winner;
  never decides eligibility or certification. Claude ids / slash commands rejected.
- benchmarks/taste-live/prompts/judge-codex-system.md — frozen judge prompt
  (pointwise image-grounded first, blind mirrored comparison, no identity guesses,
  screenshot text = untrusted data, explicit abstention).
- tests/test-taste-judge-codex.sh — red-first fake-binary suite: success, abstain,
  malformed, timeout, nonzero, missing binary, model/schema/image drift, prompt
  injection, no-secret-output, provider-syntax proof. 65 pass, 0 fail.
- docs/verify-judge-codex.md — attack matrix + exact native invocation + provider-
  syntax proof + no-secret check + real live smoke, fixtures clearly separated.

Evidence:
- tests/test-taste-judge-codex.sh: 65 pass, 0 fail.
- shellcheck -S warning (via bin/polylane-check.sh cache): PASS clean.
- LIVE receipt: codex-cli 0.144.4, model gpt-5.6-sol, exit 0, 24s, 852-byte
  schema-conforming pointwise+comparison JSON, recorded verbatim; 0 secret leaks;
  provenance_only=true; no top-level winner/eligible/certified key. (First attempt
  gpt-5-codex → real 400 "not supported on ChatGPT account", also a live receipt.)
  Fake-CLI runs remain fixture_only per EXTERNAL-EVIDENCE.

Relay: start + final `polylane-coordinate.sh pending` — no request addressed to
judge-codex (open requests target task-live/generate-live/study-live). Durable
inbox: no judge-codex items. Shared response schema is an input bound by sha, not
authored here.

Boundary: no Claude adapter, shared runner/parser, ballot, calibration, or
certificate file touched. Live-smoke + check-cache artifacts under gitignored
.polylane/; final working tree carries only runner-owned .polylane-prompt.txt and
graphify-out beyond the committed owned files.

SKILL-READ: engineering:system-design | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/system-design/SKILL.md | 2894978985-1310
SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
SKILL-EVIDENCE: engineering:system-design — helped: produced the provider-neutral
record schema and the bind-but-never-parse boundary; isolation-flag contract table.
SKILL-EVIDENCE: engineering:testing-strategy — helped: shaped the attack matrix on
security/critical boundaries (injection, no-secret, drift, timeout) + one live E2E.
