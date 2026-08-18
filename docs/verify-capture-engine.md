# Capture engine verification

## Commands

```bash
bin/polylane-check.sh "$PWD/.polylane/check-cache/capture-engine" -- bash tests/test-visual-capture.sh
bin/polylane-check.sh "$PWD/.polylane/check-cache/capture-engine" -- shellcheck -S warning bin/polylane-visual-capture.sh
```

## Focused evidence

`tests/test-visual-capture.sh`: 17 assertions, 0 failures.

The hermetic declared adapter is executed four times for one route and two
locked states: each `route × state` is captured at 1440×900 and 390×844. It
emits real PNGs sized with `sips`, matching fixed-size RGBA evidence, DOM and
replayable action trace. The capture engine publishes four independently
hashed `taste-adapter-receipt/v1` receipts and one atomic
`taste-capture-manifest/v1`.
Each capture has the manifest-relative `screenshot_path` (`captures/<capture-id>/screenshot.png`) alongside its independent PNG digest for downstream pixel verification.

Rejection evidence covers a missing adapter, an adapter that stops before the
declared matrix completes, failed navigation, mismatched receipted viewport,
artifact-receipt fabrication, aliased artifact paths, and stale timestamps. A
failed matrix leaves an existing output sentinel unchanged.

SKILL-READ: design:accessibility-review | /Users/leonardo/.codex/plugins/cache/claude-cowork/design/1.2.0/skills/accessibility-review/SKILL.md | ef42982af0d51238dda2ab16d08626712891bdd41864876c32d1e7b13fb3124f
SKILL-READ: engineering:debug | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/debug/SKILL.md | e50bb92cbcb2715139f3a3cb9ff282a8f0f9ae794f8f35d81338654e2601d32a
SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 5c5e95830754bbdd838213fa05fc8f07523f591fd558fd3c86031ffd479f7a9e
SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md | bf1b8216e523851a411e91d429a7c1c2a173e79d88957bc78e348218d50edd54

SKILL-EVIDENCE: design:accessibility-review — helped: capture-plan state coverage stays explicit, including focus-capable states; the command makes no accessibility PASS claim.
SKILL-EVIDENCE: engineering:debug — helped: red runs isolated validator shape, PNG byte-order, and JSONL row-serialization faults.
SKILL-EVIDENCE: engineering:testing-strategy — helped: tests cover the live happy path plus independent adapter, matrix, navigation, dimension, provenance, and freshness failures.
SKILL-EVIDENCE: superpowers:test-driven-development — helped: the absent command was exercised by an adversarial red test before implementation; every repair reran the focused test through the check cache.

## DEFERRED

No real browser is installed or claimed. The hermetic adapter proves only the
capture contract; a browser-backed adapter and its environment receipt remain
required for any live certification.
