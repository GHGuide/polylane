# verify — lane: models

Target: `tests/test-models.sh` covering `bin/polylane-models.sh` (CLI: help/usage,
arg/exit-code contract, fallback list, API-probe branch via mock curl + real jq).

## Evidence — `bash tests/run.sh`

My file:

```
== test-models.sh ==
PASS models-help-h-rc0
PASS models-help-long-rc0
PASS models-help-usage-section
PASS models-help-purpose
PASS models-fallback-rc0
PASS models-fallback-line-count
PASS models-fallback-first-fable
PASS models-fallback-has-opus
PASS models-fallback-has-sonnet
PASS models-fallback-has-haiku
PASS models-unknown-arg-rc0
PASS models-probe-first-api-id
PASS models-probe-second-api-id
PASS models-probe-success-rc0
PASS models-probe-httpfail-fallback
PASS models-probe-httpfail-rc0
test-models.sh: 16 pass, 0 fail
```

Suite total:

```
SUMMARY: 203 passed, 0 failed, 15 test files
```

`test-models.sh` = **16 pass, 0 fail**. New suite total: **203 passed, 0 failed, 15 test files**.

## Coverage map

| bin/polylane-models.sh behavior | assertion(s) |
|---|---|
| `-h` / `--help` exit 0 | models-help-h-rc0, models-help-long-rc0 |
| usage text (USAGE section + stated purpose) | models-help-usage-section, models-help-purpose |
| no key → curated fallback, exit 0 | models-fallback-rc0 |
| fallback is exactly the 4 curated ids | models-fallback-line-count |
| newest-family-first ordering | models-fallback-first-fable |
| each fallback id present | models-fallback-has-{opus,sonnet,haiku} |
| unknown arg tolerated, still exit 0 | models-unknown-arg-rc0 |
| probe success → prints API ids in order, exit 0 | models-probe-first-api-id, models-probe-second-api-id, models-probe-success-rc0 |
| probe HTTP failure → falls back, exit 0 | models-probe-httpfail-fallback, models-probe-httpfail-rc0 |
| jq absent → skip-pass (guarded, like test-memory.sh) | models-probe-skipped-no-jq (jq present here, so probe ran) |

Probe branch is exercised deterministically with a mock `curl` on PATH (no network);
`jq` is the machine's real binary and is skip-passed when unavailable.
