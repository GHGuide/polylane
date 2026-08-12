STATUS: ratings-normalize DONE run=c41-source-calibration-20260812-a1

# Lane ratings-normalize — final status

Commit: `23a2298` on `lane/c41-ratings-normalize`.

## Delivered

- `bin/polylane-taste-ratings.sh` — strict normalizer for the actual
  Miniukovich–Figl raw (`stimulusId,isDuplicate,rating,isTraining,dimension,sessionId`,
  integer `[-3,3]`/`NA`) and aggregate (`stimulusId` + `TYP,AVG,EXMPL,AE,US,TRU`)
  tab-separated schemas, bound by header name. Preserves native standardized
  labels and all six dimensions; joins only proven stimulus ids; computes
  raw-session support, or compliant-session support plus a pinned recompute of
  the documented aggregation pipeline within the frozen `0.01` tolerance when a
  compliant-session list is supplied (the released raw schema carries no
  compliance flag, and the tool says so instead of guessing). Frozen
  `min_support=5`. Schema drift, nonfinite values, malformed rows, duplicate
  aggregate stimuli, unknown sessions, unstandardizable sessions, and empty
  results hard-fail; weak support, missing joins, nonfinite aggregates,
  not-in-aggregate stimuli, and out-of-tolerance aggregates are explicit
  per-stimulus exclusions. Canonical `taste-ratings-normalize/v1` output plus
  optional hash-bound receipt.
- `tests/test-taste-ratings-normalize.sh` — hermetic, table-driven; 70
  assertions covering schema/header drift, reordered headers, malformed rows,
  NA handling, training rows, duplicate re-ratings, support, joins, tolerance
  recompute and mismatch, session-list integrity, zero-variance sessions,
  no-usable-records, file hygiene, CRLF, determinism, receipt binding.
- `docs/verify-ratings-normalize.md` — contract, fail/exclude taxonomy,
  pinned standardization definition, integrator stop conditions, risk register.

## Verification (executed this run)

- `bash tests/test-taste-ratings-normalize.sh` → `ok - 70 assertions`
- `shellcheck -S warning bin/polylane-taste-ratings.sh` → clean
- Relay `pending` at start and finalize: no requests addressed to
  ratings-normalize; durable inbox empty (`[]`).

## Honest boundaries

Fixtures only in this lane; the integrator validates against real rating
files. Quoted or headerless real files will fail closed as schema drift by
design. No human certification claimed anywhere.

## Skill receipts

SKILL-READ: engineering:debug | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/debug/SKILL.md | 303222582-4074
SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
SKILL-READ: operations:risk-assessment | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md | 3889652016-1630
SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/test-driven-development/SKILL.md | 1657109997-9015

SKILL-EVIDENCE: superpowers:test-driven-development — helped: full RED first (script absent, suite failed), then GREEN; the RED run also exposed a real positional-parameter clobbering bug (`set --` overwrote `$3/$4`) before any commit.
SKILL-EVIDENCE: engineering:testing-strategy — helped: shaped the table-driven coverage split (schema boundaries, data integrity, error handling) into the 19 case groups instead of ad-hoc assertions.
SKILL-EVIDENCE: operations:risk-assessment — helped: produced the verify-doc risk register; the "wrong pinned standardization definition" risk drove the fail-closed tolerance design.
SKILL-EVIDENCE: engineering:debug — unused: the single bug fell out of the failing test directly; no structured debugging session was needed.
