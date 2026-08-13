# Execution contract v3 freeze verification

Run: `c42a-taste-contracts-20260813-a2`
Lane: `execution-contract-freeze`
Target: `m32.6`

## Result

The canonical `taste-execution-contract/v3` trust boundary is executable and passes
all focused checks. The manifest is strict at every object boundary, rejects
noncanonical JSON, and fingerprints the exact canonical file bytes. Validation proves
internal consistency and byte-digest continuity; it does not authenticate fixture
receipts, run producers, certify taste, or claim human certification.

The independent sample unit is the preregistered brief lineage. Three paired build
replicates, two browser states/viewports, mirrored stimuli, repeated machine judge
invocations, and target-human ballots remain measurements attached to that unit and
cannot increase `independent_brief_count`.

## Contract coverage

- Strict identities cover preregistration, leakage-family keys, source cohort and
  immutable revision, direction lock, model/effort/profile/base-lineage
  fingerprint, equal-compute arms, prompts, requests, replicates, candidate trees,
  browser captures, blinded stimuli, probabilistic judge responses, human studies,
  participants, consents, governance receipts, ballots, and ancestry.
- Prompt provenance preserves distinct source, compiled, delivered, and consumed-stdin
  byte identities. Delivered and stdin digests and byte counts must match; the stdin
  adapter binary, invocation, receipt, and request binding are mandatory. Paths and
  environment variables are not accepted proof fields.
- Source revision SHA-256 is recomputed from exact immutable revision bytes. Model
  configuration SHA-256 is recomputed from canonical configuration bytes excluding
  only the fingerprint field. Requests bind the frozen configuration, source
  revision, prompt consumption receipt, provider identity, direction, inputs, and
  exact request bytes; builds and captures continue that artifact chain.
- Split leakage closes over brief lineage, template, asset pack, generation run,
  generation seed, source example, and visual-near-duplicate cluster. Different
  splits may share none of those identities.
- Ancestry must contain every object identity exactly once, contain every required
  direct dependency, use only declared nodes, have exactly the declared roots, and
  remain acyclic.

## TDD evidence

The first focused run was intentionally RED because the validator, schema, and example
did not yet exist. Subsequent RED cycles demonstrated that source-revision digest
substitution, model-fingerprint substitution, dangling references, duplicate judge
invocations, ballot/stimulus mismatch, missing direct ancestry, unsafe top-level
execution while sourced, and cross-brief stimulus capture were accepted before their
minimal gates were added. Every such mutation is retained as a regression assertion.

The final suite contains 43 assertions. Adversarial cases include unknown keys, unsafe
artifact paths, source/compiled/delivered/consumed prompt discontinuity, path-only
consumption, failed or forged receipts, provider substitution, unequal compute,
incorrect build cardinality, repeated-measure n inflation, duplicate IDs, split-family
leakage, stale source/model revisions, missing hashes, dangling references, broken
candidate ancestry, mismatched mirrors, invalid probability mass, self-lineage judges,
duplicate judge invocations, duplicate participant exposure, missing consent or
governance, ballot/stimulus mismatch, incomplete ancestry, cycles, and noncanonical
serialization.

## Normative artifact digests

All values are lowercase SHA-256 over exact file bytes:

```text
e16e52c37a108d1c4610a505f3c70e18e1fb2d4ecc729030f6c03c50b42637bb  bin/polylane-taste-execution-contract.sh
3175f71c2c07e0682f71485cb05b91df7cdc8f82ac47de07b0f4746e77d52db8  docs/polylane/taste-certification/contracts/execution-v3.schema.json
3b8d5fdeb31721caac38696464d84eb4157179d6bd0f06df4948a72bf689542e  docs/polylane/taste-certification/contracts/execution-v3.example.json
f91907b832c8c6bef1298f7395197b37d6288532aa1bf9faa335fee722a64e60  tests/test-taste-execution-contract-v3.sh
```

The validator's `fingerprint` result for the normative example is
`3b8d5fdeb31721caac38696464d84eb4157179d6bd0f06df4948a72bf689542e`,
identical to the independently computed exact-file digest.

## Focused verification

Commands:

```bash
bash tests/test-taste-execution-contract-v3.sh
shellcheck -S warning bin/polylane-taste-execution-contract.sh
```

Final output:

```text
ok 1 - normative-example-validates
ok 2 - validator-is-safe-to-source
ok 3 - schema-is-strict-draft-2020-12
ok 4 - schema-closes-unknown-keys-at-every-object
ok 5 - example-is-canonical-json
ok 6 - fingerprint-binds-exact-canonical-bytes
ok 7 - unknown-top-level-key
ok 8 - unsafe-artifact-path
ok 9 - prompt-delivered-consumed-discontinuity
ok 10 - prompt-path-only-is-not-consumption
ok 11 - request-does-not-bind-consumed-prompt
ok 12 - request-does-not-bind-adapter-receipt
ok 13 - adapter-failed
ok 14 - provider-substituted-request-receipt
ok 15 - provider-receipt-signature-missing
ok 16 - unequal-arm-token-budget
ok 17 - unequal-arm-replicates
ok 18 - wrong-build-cardinality
ok 19 - repeated-measures-cannot-inflate-n
ok 20 - duplicate-brief-id
ok 21 - split-family-leakage
ok 22 - stale-source-revision
ok 23 - source-revision-digest-binds-exact-revision-bytes
ok 24 - stale-model-revision
ok 25 - model-fingerprint-binds-full-config
ok 26 - missing-candidate-tree-hash
ok 27 - duplicate-request-id
ok 28 - dangling-direction-reference
ok 29 - request-source-revision-discontinuity
ok 30 - candidate-tree-chain-break
ok 31 - mirrored-orientation-copies-new-captures
ok 32 - stimulus-captures-cannot-cross-briefs
ok 33 - probabilities-must-sum-to-one
ok 34 - judge-cannot-vote-on-own-lineage
ok 35 - repeated-judge-invocations-are-distinct
ok 36 - participant-sees-brief-only-once
ok 37 - ballot-binds-stimulus-orientation
ok 38 - human-ballot-requires-consent
ok 39 - human-ballot-requires-governance
ok 40 - ancestry-must-be-complete
ok 41 - ancestry-must-include-direct-dependencies
ok 42 - ancestry-must-be-acyclic
ok 43 - noncanonical-json-rejected
1..43
```

ShellCheck produced no output and exited zero.

## Evidence and claim ceiling

No external evidence was needed. The normative example is explicitly fixture-grade.
It can exercise validation and deterministic fingerprint behavior but can never prove
a live provider call, real browser run, actual participant, consent, governance
approval, human calibration, human certification, or taste certification.

## Skill receipts

SKILL-READ: engineering:system-design | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/system-design/SKILL.md | 2894978985-1310

SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279

SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/test-driven-development/SKILL.md | 1657109997-9015

## Skill evidence

SKILL-EVIDENCE: engineering:system-design — helped: forced explicit component,
data-flow, identity, failure, and trust-boundary decisions before the schema shape was
frozen; the direct ancestry-edge checks came from treating each receipt transition as
an API boundary.

SKILL-EVIDENCE: engineering:testing-strategy — helped: organized fast contract tests
around critical integrity, security, cardinality, and cross-reference boundaries while
keeping live providers and humans outside this fixture-only lane.

SKILL-EVIDENCE: superpowers:test-driven-development — helped: the missing-tool RED run
and later targeted RED mutations caught unbound revision/configuration digests,
incomplete direct ancestry, unsafe source execution, and cross-brief stimulus leakage
before the implementation was finalized.

## DEFERRED

DEFERRED: none
