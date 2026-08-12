STATUS: calibration-live DONE run=c40-live-harness-20260812-a3

Lane: calibration-live · Cycle 40 · claude-opus-4-8 @ xhigh

## Shipped (owned paths only)
- bin/polylane-taste-calibration-live.sh — taste-calibration/v2 validator,
  receipt polylane.taste.judge-eligibility.v2. Recomputes gold (bound human
  holdout labels), votes (pinned parser over hash-matched raw responses),
  eligibility (frozen thresholds), and production-vs-fixture_only (real
  hash-matched files). Fail-closed; no success receipt after a failed link.
- tests/test-taste-calibration-live.sh — 22 red-first assertions (4 positive +
  18 reject); one case per contract reject class.
- docs/verify-calibration-live.md — positive/negative matrix, exact formulas
  (Wilson LCB, two-sided exact binomial side probe, mirror contradictions),
  receipt closure, machine-not-human claim semantics.

## HARD CONTRACT met
24 unique held-out mirrored units; >=17 correct; Wilson LCB >= 0.50; side probe
n>=12, exact p>=0.05; mirror probe n>=8, <2 contradictions. Freeze pins
provider/model/version/system-prompt/sampling/source/adapter/parser + orientation.
Rejects: tuning/holdout overlap, duplicate prompt/image, one-sided/unparseable
response, response hash mismatch, changed parser/invocation, identity leak,
invalid abstention, orientation not mirrored, stale source, unknown fields,
shape-compatible synthetic receipts, labels digest tamper.

Claim frozen: HUMAN_CALIBRATED_MACHINE, human_certified:false,
machine_not_human:true. This lane mints the calibration receipt only — never a
certificate; cannot mark m32.4 complete.

## Evidence
- bash tests/test-taste-calibration-live.sh -> PASS assertions=22
- shellcheck -S warning bin/polylane-taste-calibration-live.sh -> clean
- shellcheck -S warning tests/test-taste-calibration-live.sh -> clean
- Implementation + verification commit: 2c3cd50

## Relay
Start + final relay: no requests addressed to calibration-live (pending were to
task-live / generate-live / study-live). Durable inbox empty for this lane.
Receipt-closure seam (corpus liveness, panel identity, live-smoke) handed to
study-live / the integrator per the receipt's declared evidence closure.

## Skill receipts
SKILL-READ: data:statistical-analysis | /Users/leonardo/.codex/plugins/cache/claude-cowork/data/1.1.0/skills/statistical-analysis/SKILL.md | 2702170626-10434
SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
SKILL-EVIDENCE: data:statistical-analysis — helped: finite-sample caution kept
the exact two-sided binomial side probe and a Wilson LCB (not normal-approx)
near the 0.50 floor, on the held-out n.
SKILL-EVIDENCE: engineering:testing-strategy — helped: security/data-integrity
boundary focus shaped an 18-case reject matrix over trivial-helper unit tests.
