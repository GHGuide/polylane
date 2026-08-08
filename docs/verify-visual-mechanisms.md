# Visual mechanisms verification

Commit `9eff86f` implements the executable cycle-12 mechanisms.

## Test-first evidence

- `bash tests/test-visual-intelligence.sh`: initially failed because packet
  generation, dominant-source rejection, and frozen-decision validation were
  absent; final result 9 pass, 0 fail.
- `bash tests/test-skill-acquire.sh`: initially failed because the quarantine
  auditor and admission path were absent; final result 12 pass, 0 fail.
- `bash tests/test-visual-quality.sh`: initially failed because the quality gate
  and benchmark command were absent and later exposed an empty-verdict bug; final
  result 4 pass, 0 fail.
- `bash tests/test-scout.sh`: 25 pass, 0 fail.
- `bash tests/test-judges.sh`: 9 pass, 0 fail.
- `bash tests/test-advanced-runtime.sh`: 19 pass, 0 fail.
- `bash tests/test-graph-quality-loop.sh`: 4 pass, 0 fail.
- `bash -n` and `shellcheck -S warning` passed for every owned or directly
  affected script.

The deterministic fixtures prove reference breadth and design locking,
quarantine/benchmark/project installation/rollback, required visual evidence,
unanimous lenses, bounded repairs, and benchmark rejection thresholds.

## External evidence

This repository change implements the pipeline. It does not claim that a live
product website, remote skill, browser screenshot set, or multimodal judge run
was produced in this lane. Those artifacts are mandatory when a future UI cycle
uses the pipeline and cannot be replaced by these fixtures.

## Follow-on visual gate hardening (`c12-visual-20260808`)

### RED

- `bin/polylane-check.sh "$PWD/.polylane/check-cache/visual-mechanisms" -- bash tests/test-visual-quality.sh`
  failed because non-anonymized evidence was accepted and a benchmark could call
  a score tradeoff that lost polish a decisive win.
- `bin/polylane-check.sh "$PWD/.polylane/check-cache/visual-mechanisms" -- bash tests/test-graph-quality-loop.sh`
  failed because an explicit `visual_quality` request produced neither the
  `visual-quality`/`visual-repair` nodes nor the two-attempt loop.
- `bin/polylane-check.sh "$PWD/.polylane/check-cache/visual-mechanisms" -- bash tests/test-advanced-runtime.sh`
  failed because the runner had no opt-in visual quality boundary or typed,
  two-repair halt path.

### GREEN

- `bash tests/test-visual-quality.sh`: 6 pass, 0 fail.
- `bash tests/test-graph-quality-loop.sh`: 7 pass, 0 fail.
- `bash tests/test-advanced-runtime.sh`: 24 pass, 0 fail.
- All directly affected subsystem files passed through the lane check cache:
  visual intelligence (9), skill acquire (12), visual quality (6), scout (25),
  judges (9), advanced runtime (24), and graph quality loop (7): 92 pass, 0 fail.
- `bash -n bin/polylane-run.sh bin/polylane-graph.sh bin/polylane-visual-quality.sh`
  passed; `git diff --check` passed.

### Scope diff

- `bin/polylane-visual-quality.sh`: requires anonymized judge input and counts
  decisive benchmark wins only when both distinction and polish improve.
- `bin/polylane-graph.sh`: adds opt-in visual gate and bounded repair graph nodes.
- `bin/polylane-run.sh`: executes the opt-in visual evidence gate, produces a
  typed visual repair prompt, and blocks promotion after two repairs.
- `tests/test-visual-quality.sh`, `tests/test-graph-quality-loop.sh`, and
  `tests/test-advanced-runtime.sh`: behavioral coverage for each boundary.

### Remaining external evidence

Live websites, remote candidate repositories, browser-captured screenshots, and
multimodal model judgments remain external evidence. The deterministic fixture
seams prove local gating without claiming any unavailable live proof.
