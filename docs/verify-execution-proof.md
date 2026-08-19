# Verification — lane `execution-proof`, run `c44-defect-controls-20260819-a1`

Scope: two frozen v3 controls in the execution-contract boundary. No taste or human
certification claim is minted, implied, or upgraded by this work; both defects remain
`OPEN` in `EVIDENCE-CLAIM-REGISTRY.v3.json`, which this lane is forbidden to edit.

Authorities read (never modified):
`docs/polylane/taste-certification/contracts/CONTRACT-LOCK.v3.json`,
`EVIDENCE-CLAIM-REGISTRY.v3.json`, `execution-v3.schema.json`, `execution-v3.example.json`.

Baseline commit at which RED was reproduced: `c989d7c`.

---

## Defect 1 — `c42b-missing-consumed-stdin-proof`

**Boundary:** prompt delivery provenance.

**`required_v3_control` (verbatim from the registry):**

> Delivered and consumed stdin SHA-256 and byte count match and are bound by a successful
> stdin adapter receipt and request receipt.

**Disposition (verbatim):** "blocks affected request and every descendant from evidence
promotion until repaired and regression-tested".

### What was already satisfied, and what was not

Reading `bin/polylane-taste-execution-contract.sh` at `c989d7c`, the first two limbs of the
control were already enforced:

| Limb | Existing check | Status at `c989d7c` |
|---|---|---|
| delivered/consumed SHA-256 and byte count match | `PROMPT_HASH_DISCONTINUITY` | enforced |
| adapter invocation succeeded, proof kind pinned | `FORGED_RECEIPT`, `STDIN_PROOF_REQUIRED` | enforced |
| request receipt binds the same chain | `REQUEST_PROMPT_MISMATCH`, `REQUEST_ADAPTER_MISMATCH` | enforced |

The gap was that nothing constrained the *receipt itself*. Six forgeries were probed
directly against the shipped validator; every one was accepted:

```
ACCEPTED  dup-invocation-id
ACCEPTED  dup-receipt-sha
ACCEPTED  receipt-equals-payload
ACCEPTED  receipt-equals-request-receipt
ACCEPTED  divergent-adapter-binary
ACCEPTED  binary-equals-receipt
```

Two forgery classes defeat the control's binding limb:

1. **Receipt reuse.** Two prompts sharing one `invocation_id` or one `receipt_sha256`
   describe one adapter invocation attesting two different delivered byte streams. The
   second delivery is then promoted with no consumed-stdin proof of its own — literally the
   defect's name — while `PROMPT_HASH_DISCONTINUITY` and `REQUEST_ADAPTER_MISMATCH` still
   pass, because both are keyed on `prompt_id` and never compare prompts to each other.
2. **Tautological receipt.** A `receipt_sha256` equal to `delivered_sha256`,
   `stdin_sha256`, `request_receipt_sha256`, or `adapter_binary_sha256` restates a value
   the manifest already carries. It is an echo of the claim, not an attestation of it, so
   "bound by a successful stdin adapter receipt" is satisfied only in form.

### How the implementation satisfies the control

New check `CONSUMED_STDIN_PROOF` in `bin/polylane-taste-execution-contract.sh`, placed
before `REQUEST_PROMPT_MISMATCH` so a forged receipt is reported at its own boundary:

```jq
([.prompts[].stdin_adapter.invocation_id] | length == (unique | length))
and ([.prompts[].stdin_adapter.receipt_sha256] | length == (unique | length))
and all(.prompts[]; .stdin_adapter as $adapter
  | ([$adapter.delivered_sha256,$adapter.stdin_sha256,$adapter.request_receipt_sha256,$adapter.adapter_binary_sha256]
     | index($adapter.receipt_sha256)) == null)
```

Each adapter invocation and each adapter receipt is single-use, and a receipt may not be a
restatement of any value it attests. Together with the pre-existing checks, all three limbs
of the control text are now enforced, and the test asserts all three rather than only the
new clauses.

The stated disposition is met by the validator's existing failure mode: `validate` rejects
the whole manifest on the first failing check, so the affected request and every descendant
of it — builds, captures, stimuli, judge responses, ballots — are refused promotion together.
No partial-admission path exists.

### Clause withdrawn after checking it against the frozen contract

A third clause was drafted requiring one `adapter_binary_sha256` per pinned `adapter_id`.
The frozen `execution-v3.example.json` ships `4444…` for `prompt-baseline` and `9999…` for
`prompt-current` under the single pinned id `polylane-stdin-adapter/v1`. The example is
frozen m32.7 acceptance and is authority, so the implementation was reconciled to it and the
clause was removed, along with its assertion (`pinned-adapter-id-cannot-cover-two-binaries`).
The failing run below records this: `frozen-example-keeps-consumed-stdin-proof` reported
`INVALID CONSUMED_STDIN_PROOF` while that clause was present. Divergent adapter binaries
therefore remain unconstrained — see Limitations.

### Red-then-green evidence

RED is reproducible: the new test was run against the `c989d7c` validator
(`git show HEAD:bin/polylane-taste-execution-contract.sh`) with the real `docs/` tree.

```
$ bash tests/test-taste-delivery-provenance.sh          # against the c989d7c validator
ok 1 - frozen-example-keeps-consumed-stdin-proof
ok 2 - delivered-and-consumed-digests-must-match
ok 3 - delivered-and-consumed-byte-counts-must-match
ok 4 - adapter-must-restate-the-consumed-byte-count
ok 5 - failed-adapter-invocation-proves-nothing
ok 6 - adapter-proof-kind-is-pinned
not ok - one-delivery-cannot-reuse-another-adapter-invocation: accepted a manifest with no consumed-stdin proof
not ok - one-delivery-cannot-reuse-another-adapter-receipt: accepted a manifest with no consumed-stdin proof
not ok - receipt-cannot-restate-the-delivered-payload: accepted a manifest with no consumed-stdin proof
not ok - receipt-cannot-restate-the-request-receipt: accepted a manifest with no consumed-stdin proof
not ok - receipt-cannot-restate-the-adapter-binary: accepted a manifest with no consumed-stdin proof
ok 7 - request-must-cite-the-adapter-receipt
ok 8 - adapter-must-cite-the-request-receipt
ok 9 - request-must-cite-the-consumed-bytes
1..14
5 test(s) failed
exit=1
```

Intermediate RED, with the withdrawn adapter-binary clause in place — the frozen example
itself was refused, which is what forced the clause out:

```
not ok - frozen-example-keeps-consumed-stdin-proof: INVALID CONSUMED_STDIN_PROOF
```

GREEN, current tree:

```
$ bash tests/test-taste-delivery-provenance.sh
ok 1 - frozen-example-keeps-consumed-stdin-proof
... (14 assertions)
ok 14 - request-must-cite-the-consumed-bytes
1..14
exit=0
```

---

## Defect 2 — `c42b-run-mode-vocabulary-mismatch`

**Boundary:** execution lifecycle mode.

**`required_v3_control` (verbatim from the registry):**

> Run mode values use one contract-v3 vocabulary at producer, validator, storage, and
> lifecycle boundaries.

**Disposition (verbatim):** "blocks affected run from contract-v3 validation until repaired
and regression-tested".

### Why the reconciliation takes this shape

Two facts about the frozen contracts constrained the design, and both were checked before
any code was written:

1. `execution-v3.schema.json` declares `"additionalProperties": false` at the manifest root,
   with a fixed 21-key `required` list. Carrying run mode as a new top-level manifest key
   would make every manifest schema-invalid. The schema is frozen and read-only, so that
   route is closed.
2. `grep -rn 'run_mode\|runMode\|RUN_MODE'` over `bin/`, `tests/`, `docs/polylane/taste-certification/`
   and `.polylane/` returns nothing. There is no run-mode vocabulary in the execution
   contract at all today — that absence is the mismatch. Meanwhile
   `bin/polylane-finalize.sh:62` carries its own hand-written copy of the transition table,
   which is the second copy that can drift from the lock.

The lock is authority and is reconciled *to*, never *from*: `lifecycle.authoritative_sequence`
(`WORKING`, `HANDOFF_PENDING`, `HANDOFF_COMMITTED`, `QUIESCING`, `DONE`) and
`lifecycle.allowed_transitions` (8 entries) are read at runtime and never restated in the
implementation.

### How the implementation satisfies the control

`bin/polylane-taste-execution-contract.sh` gains two verbs that serve the one vocabulary
from the one source:

- `run-mode-vocabulary` — prints `lifecycle.authoritative_sequence` from
  `CONTRACT-LOCK.v3.json`, in order, one state per line. This is what a producer, a storage
  writer, or a lifecycle transition should read instead of hardcoding states.
- `run-mode-transition FROM TO` — rejects `RUN_MODE_VOCABULARY` if either state is outside
  the frozen sequence (checked first, so a foreign value is refused at the vocabulary
  boundary rather than mapped onto a contract-v3 state), then rejects `RUN_MODE_TRANSITION`
  if `FROM->TO` is not in `lifecycle.allowed_transitions`.

The lock path resolves relative to the script; a missing lock, a symlinked lock, or an
unreadable lifecycle block rejects `CONTRACT_LOCK_UNAVAILABLE` / `CONTRACT_LOCK_UNREADABLE`
rather than falling back to a default vocabulary.

The `validate` and `fingerprint` verbs are unchanged in behaviour and argument shape; only
the usage text gained two lines. Bad invocations still exit 64.

The single-source property is asserted structurally, not just by agreement: the test greps
the implementation for each state name served by the lock and fails if any appears. A second
copy in this file cannot be introduced without turning the test red.

### Red-then-green evidence

RED against the `c989d7c` validator (verbs absent, so every vocabulary and transition
assertion fails on `usage:` / exit 64):

```
$ bash tests/test-taste-run-mode.sh                     # against the c989d7c validator
not ok - vocabulary-is-served-from-the-frozen-lock: usage: polylane-taste-execution-contract.sh validate|fingerprint MANIFEST.json
ok 1 - implementation-keeps-no-second-copy-of-the-vocabulary
not ok - allows-WORKING-to-WORKING: refused a frozen contract-v3 value: usage: ...
not ok - allows-WORKING-to-HANDOFF_PENDING: refused a frozen contract-v3 value: usage: ...
not ok - allows-HANDOFF_PENDING-to-HANDOFF_PENDING: refused a frozen contract-v3 value: usage: ...
not ok - allows-HANDOFF_PENDING-to-HANDOFF_COMMITTED: refused a frozen contract-v3 value: usage: ...
not ok - allows-HANDOFF_COMMITTED-to-QUIESCING: refused a frozen contract-v3 value: usage: ...
not ok - allows-QUIESCING-to-QUIESCING: refused a frozen contract-v3 value: usage: ...
not ok - allows-QUIESCING-to-DONE: refused a frozen contract-v3 value: usage: ...
not ok - allows-DONE-to-DONE: refused a frozen contract-v3 value: usage: ...
not ok - refuses-skipping-the-handoff-states: expected RUN_MODE_TRANSITION, got: usage: ...
not ok - refuses-reopening-a-committed-handoff: expected RUN_MODE_TRANSITION, got: usage: ...
not ok - refuses-restarting-a-finished-run: expected RUN_MODE_TRANSITION, got: usage: ...
not ok - refuses-foreign-running-state: expected RUN_MODE_VOCABULARY, got: usage: ...
not ok - refuses-foreign-completed-state: expected RUN_MODE_VOCABULARY, got: usage: ...
not ok - refuses-case-folded-state: expected RUN_MODE_VOCABULARY, got: usage: ...
not ok - refuses-empty-state: expected RUN_MODE_VOCABULARY, got: usage: ...
ok 2 - frozen-example-still-validates
1..18
16 test(s) failed
exit=1
```

`implementation-keeps-no-second-copy-of-the-vocabulary` passes at RED because the verbs do
not exist yet; it is a guard against reintroducing a copy, not a defect reproduction.

GREEN, current tree:

```
$ bash tests/test-taste-run-mode.sh
ok 1 - vocabulary-is-served-from-the-frozen-lock
ok 2 - implementation-keeps-no-second-copy-of-the-vocabulary
ok 3 - allows-WORKING-to-WORKING
... (18 assertions, 8 of them one per lock transition)
ok 18 - frozen-example-still-validates
1..18
exit=0

$ bin/polylane-taste-execution-contract.sh run-mode-vocabulary
WORKING
HANDOFF_PENDING
HANDOFF_COMMITTED
QUIESCING
DONE
```

---

## Fresh counts — every command run for this verification

Run against the current tree, worktree
`/Users/leonardo/Downloads/polylane/.polylane/worktrees/c44-execution-proof`.

| Command | Result |
|---|---|
| `bash tests/test-taste-delivery-provenance.sh` | rc=0 — 14 ok, `1..14`, 0 failed |
| `bash tests/test-taste-run-mode.sh` | rc=0 — 18 ok, `1..18`, 0 failed |
| `bash tests/test-taste-execution-contract-v3.sh` | rc=0 — 43 ok, `1..43`, 0 failed |
| `bash tests/test-taste-source-contract-v3.sh` | rc=0 — `ok - taste-source-contract-v3 (60 assertions)` |
| `bin/polylane-taste-execution-contract.sh validate docs/.../execution-v3.example.json` | `VALID execution-v3 3b8d5fdeb31721caac38696464d84eb4157179d6bd0f06df4948a72bf689542e` |
| `bin/polylane-taste-source-contract.sh validate docs/.../source-calibration-v3.example.json` | `SOURCE-CONTRACT-V3-OK` |
| `bin/polylane-taste-execution-contract.sh fingerprint docs/.../execution-v3.example.json` | `3b8d5fdeb31721caac38696464d84eb4157179d6bd0f06df4948a72bf689542e` |
| `shellcheck -S warning bin/polylane-taste-execution-contract.sh bin/polylane-evidence-dag.sh bin/polylane-taste-source-contract.sh bin/polylane-finalize.sh bin/polylane-memory.sh bin/polylane-run.sh bin/polylane-supervisor.sh assets/verify-gate.sh` (lock acceptance command, verbatim) | rc=0 — 0 findings |
| `bash -n bin/polylane-taste-execution-contract.sh` | rc=0 |
| usage regressions: no args / `validate` with no manifest / `bogus x` / `run-mode-transition WORKING` | all exit 64 |

Both frozen m32.7 acceptance gates named in the lane brief hold: the execution-contract
validator still returns `VALID` for `execution-v3.example.json`, and the source-contract
validator still passes for `source-calibration-v3.example.json`. The example's SHA-256 is
unchanged, because no contract JSON was touched.

Blast radius check: `grep -rl 'consumed_stdin\|stdin_adapter' tests/ bin/` and
`grep -rln 'polylane-taste-execution-contract' bin/ tests/` return only the owned validator,
the pre-existing `tests/test-taste-execution-contract-v3.sh`, and the two new suites. No
other suite exercises the changed file. `tests/run.sh` and doctor rehearsals were not run —
those boundaries belong to the integrator and coordinator.

---

## Limitations

1. **Divergent adapter binaries stay unconstrained.** The frozen example ships two different
   `adapter_binary_sha256` values under one pinned `adapter_id`, so a validator clause
   requiring one binary per adapter id would fail frozen acceptance. Whether that is intended
   fixture variation or a latent defect is a contract question, not an implementation one; it
   is out of this lane's authority to decide and is left for the registry owner.
2. **The run-mode control is served, not yet consumed everywhere.** This lane owns only the
   execution-contract boundary. `bin/polylane-finalize.sh:62` still carries its own copy of
   the transition table, and `bin/polylane-run.sh` its own `DONE` literals; both are
   FORBIDDEN paths for this lane. The single vocabulary now exists and is enforced where the
   contract boundary can enforce it, but pointing the producer, storage, and lifecycle call
   sites at `run-mode-vocabulary` / `run-mode-transition` requires a lane that owns those
   files. Until that happens the two copies can still drift — the copy in the *execution
   contract* cannot.
3. **Run mode is not carried in the manifest.** `execution-v3.schema.json` is frozen with
   `additionalProperties: false`, so a manifest cannot declare its run mode without breaking
   schema validity. The vocabulary is therefore enforced at the verb boundary rather than as
   a manifest field.
4. **Receipt independence is structural, not cryptographic.** The validator can prove a
   receipt digest is unique and is not a restatement of the values it attests. It cannot
   verify that the digest is a real adapter receipt over the real bytes — no receipt payload
   is present in the manifest to recompute. A fabricated but well-formed digest still passes.
5. **Both defects remain `OPEN` in the registry.** Flipping a defect status is forbidden to
   this lane and would in any case require the disposition's "repaired *and* regression-tested"
   judgement to be made by the registry owner.
6. No live provider calls, network access, installs, or browsing were used. No taste or human
   certification claim was minted, implied, or upgraded.

---

## Skills

SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/test-driven-development/SKILL.md | 1657109997-9015
SKILL-READ: superpowers:systematic-debugging | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/systematic-debugging/SKILL.md | 4111822586-9465

SKILL-EVIDENCE: superpowers:test-driven-development — helped: the skill's "verify RED, and check it fails for the expected reason" step is what caught the withdrawn adapter-binary clause. The clause turned `frozen-example-keeps-consumed-stdin-proof` red, and because the skill requires reading the failure rather than the pass count, the contradiction with frozen m32.7 acceptance surfaced immediately instead of after a green-looking partial run. Its "watch it fail first" rule also drove reproducing RED against the `c989d7c` validator rather than quoting a remembered failure.

SKILL-EVIDENCE: superpowers:systematic-debugging — helped: Phase 1 "gather evidence at each boundary before proposing fixes" changed the outcome for defect 1. Reading the validator suggested the consumed-stdin control was already complete (`PROMPT_HASH_DISCONTINUITY` plus `FORGED_RECEIPT` plus `REQUEST_ADAPTER_MISMATCH` cover the literal control text). Running six mutation probes instead of trusting that reading showed all six accepted, which located the actual gap — receipt reuse and tautological receipts — rather than a symptom-level fix. The same rule applied to defect 2 produced the two blocking facts (`additionalProperties: false`; zero `run_mode` occurrences) before any design was committed, which ruled out the obvious new-manifest-key approach that would have broken frozen acceptance.
