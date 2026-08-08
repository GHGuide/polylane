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
