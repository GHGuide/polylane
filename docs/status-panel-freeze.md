STATUS: panel-freeze DONE run=c41-source-calibration-20260812-a1

Froze the machine-panel configuration `benchmarks/taste-live/calibration/panel.v1.json`
(schema `polylane.taste.panel/v1`): six slots spanning both real adapters —
`polylane-taste-judge-claude` (claude-fable-5, claude-opus-5, claude-sonnet-5) and
`polylane-taste-judge-codex` (gpt-5-codex high, gpt-5 high, gpt-5 medium) — with unique
slot/judge/session identities, exact SHA-256 bindings for system prompts, the
taste-judge-response/v1 schema, and per-slot sampling canonicals.

Claim ceiling is HUMAN_CALIBRATED_MACHINE with human certification in forbidden_claims.
The static file carries no eligibility/human/trust/independence booleans and no model or
CLI versions; `runtime_observed_fields` defers those to taste-calibration/v2 receipts,
so only the calibration campaign/audit can ever call a slot eligible. Correlation is
documented honestly: two distinct families, same-family agreement never replication,
gpt-5 high/medium near-duplicates, cross-family training-data correlation stated.
Abstention policy records seven classes; abstentions never become votes; an
insufficient panel is EXTERNAL-EVIDENCE-OPEN, never a fixture.

Test-first evidence: `tests/test-taste-panel-freeze.sh` failed red on the missing panel,
then passed; its 20-case tamper matrix rejects each mutation for its specific reason
(spot-checked), and shellcheck -S warning is clean. Focused verification recorded in
`docs/verify-panel-freeze.md` with SKILL-EVIDENCE for all four selected skills.

SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/test-driven-development/SKILL.md | 1657109997-9015
SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
SKILL-READ: engineering:debug | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/debug/SKILL.md | 303222582-4074
SKILL-READ: operations:risk-assessment | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md | 3889652016-1630
