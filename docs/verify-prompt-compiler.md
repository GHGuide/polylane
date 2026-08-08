# Prompt compiler verification — cycle 13

## Scope

`polylane-promptopt.sh` compiles immutable prompt input into normalized typed
blocks. It preserves first-seen order, removes only byte-for-byte-identical
normalized material, and never writes the source prompt or invents an
instruction. Scalar hard contracts are exact-once: a repeated equal value is a
duplicate and unequal values are a conflict.

`metrics` retains `bytes`, `tokens`, `estimated_tokens`, and
`token_estimate_method` for compatibility. `tokens` is the deterministic
`ceil(bytes/3)` local compatibility estimate. Budget enforcement uses the
separate `conservative_token_estimate` byte bound. Neither is provider billing
or a model-quality claim.

Exit codes: `2` usage/input, `3` missing hard contract, `4` budget, `5`
duplicate/conflicting scalar, and `7` frozen comparison behavior loss.

## RED

Before implementation, the focused prompt tests could not execute `compile` or
`compare`; the optimizer only exposed `metrics` and `check`, and its `tokens`
field was a whitespace-word count. The first harness attempt also exposed that
the new test files are non-executable, so focused checks are invoked explicitly
with `bash`.

## GREEN

Fresh focused evidence:

```text
test-promptopt.sh: 9 pass, 0 fail
test-promptlint.sh: 22 pass, 0 fail
test-prompt-economy.sh: 19 pass, 0 fail
test-prompt-compiler.sh: 12 pass, 0 fail
shellcheck -S warning bin/polylane-promptopt.sh bin/polylane-promptlint.sh: rc=0
```

## Frozen before/after size record

Fixture: `benchmarks/prompt-optimization/fixtures/valid-source.txt`.

| Prompt | Bytes | Compatibility estimate | Conservative budget estimate |
| --- | ---: | ---: | ---: |
| Source | 991 | 331 | 991 |
| Compiled | 957 | 319 | 957 |

The compiled result removes one repeated non-contract line (34 bytes) while
preserving the strict labels and both selected skill lists verbatim.

## Frozen corpus outcomes

| Case | Expected | Fresh result |
| --- | --- | --- |
| valid | WIN | `compare` rc=0, frozen contracts equivalent |
| duplicate | DUPLICATE | `compile` rc=5; reports `GOAL` and its value |
| contradictory | CONFLICT | `compile` rc=5; reports `GOAL` and both values |
| over-budget | BUDGET | `check ... 1` rc=4 with conservative estimate 763 |
| missing-contract | MISSING | `compile` rc=3; `external-evidence` missing |
| behavior-loss | LOSS | `compare` rc=7; challenger required behavior differs |

The corpus is static at `benchmarks/prompt-optimization/`; no provider or model
evaluation was run. Its comparison is a frozen functional contract gate, not an
external quality result.

SKILL-EVIDENCE: read /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md
SKILL-EVIDENCE: read /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/verification-before-completion/SKILL.md
SKILL-EVIDENCE: read /Users/leonardo/.codex/plugins/cache/caveman/caveman/local/skills/caveman-compress/SKILL.md
SKILL-EVIDENCE: read /Users/leonardo/.codex/plugins/cache/claude-cowork/product-management/1.2.0/skills/write-spec/SKILL.md
