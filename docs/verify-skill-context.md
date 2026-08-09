# Skill-context verification

## Exact selected skill reads

SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md | 1657109997-9015

SKILL-READ: engineering:documentation | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/documentation/SKILL.md | 177552282-1507

SKILL-READ: operations:process-optimization | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/process-optimization/SKILL.md | 2420769291-1288

## Red / green

- Red: `bash tests/test-skill-delivery.sh` initially reported 31 pass, 4 fail. The missing contract failures were stale `SKILL-DELIVERY`, low-salience selected-record placement, missing `SKILL-READ` receipt instruction, and missing final use-evidence instruction.
- Green: `bash tests/test-skill-delivery.sh` reports 44 pass, 0 fail; `bash tests/test-prompt-compiler.sh` reports 16 pass, 0 fail; `shellcheck -S warning bin/polylane-promptopt.sh` is silent.

## Exact output contract

`bin/polylane-promptopt.sh compile-selected SOURCE KIT LANE OUTPUT` accepts only typed selected records for the named lane. It deterministically sorts and deduplicates exact `id`/`path` pairs, retains `source`, `fingerprint`, and `reason`, rejects conflicting immutable duplicates and more than four records, and never loads a `SKILL.md` body.

It removes pre-authored `SELECTED-SKILL`, `SKILL-DELIVERY`, and `SKILL-RECEIPTS` lines from the source prompt. Immediately after `Read only the named kit once...`, it regenerates:

1. `SKILL-DELIVERY: exact selected records for lane <lane>; no discovery or inventory.`
2. One `SELECTED-SKILL: id | path | source | fingerprint | reason` line per trusted selected record.
3. `SKILL-RECEIPTS` requiring `SKILL-READ: id | path | fingerprint` and final `SKILL-EVIDENCE: id — helped|unused|hurt: specific observation` for every selected skill.

Ordinary and integrator compilation carry no selected record or read-receipt contract; an unselected integrator lane is rejected by `compile-selected`.

## Token impact

For this lane's three selected records, the generated delivery block is 1,033 bytes: an estimated 345 tokens using `ceil(bytes/3)`, or 1,033 conservative budget tokens. The focused fixture verifies the compiled prompt remains within the 10,000-token contract. The contract is one delivery line, three typed records, and one receipt line; it replaces stale tail records instead of duplicating them.

## Relay / interface note

Fixed runtime handoff: builders must call `polylane-promptopt.sh compile-selected SOURCE KIT LANE OUTPUT` after ordinary normalization; integrators continue to use ordinary `compile`. There was no active runtime-resilience agent registered in the canonical relay at handoff time, so this committed interface note is the durable relay; no runtime-owned file was edited.

## Selected skill evidence

SKILL-EVIDENCE: superpowers:test-driven-development — helped: the first compiled-prompt fixture failed on all four missing observable-contract behaviors before the minimal compiler change.

SKILL-EVIDENCE: engineering:documentation — helped: it shaped the concise exact receipt and final evidence wording that the compiler tests now assert verbatim.

SKILL-EVIDENCE: operations:process-optimization — helped: it kept the planner-to-builder handoff to one fixed compiler command and five salient generated lines rather than adding discovery work.
