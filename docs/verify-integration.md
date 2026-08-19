# verify-integration — run `c44-defect-controls-20260819-a1`

Integrator, branch `lane/c44-integrator`. Merges the three cycle-44 control
lanes and certifies that the five frozen v3 defect controls coexist correctly
in one tree. This run implements controls only: no taste or human certification
claim is minted, implied, or upgraded, and every `implementation_defects`
status in `EVIDENCE-CLAIM-REGISTRY.v3.json` remains `OPEN` in the merged tree
(verified by `jq` after the final merge: 5 × `OPEN`).

## Branch tips and ancestry

All tips read live at integration time, not from memorized hashes.

| ref | tip |
|---|---|
| `main` | `3c475dbeafd1082dcd403b56e8081e54b668a4da` |
| `lane/c44-prompt-chain` | `7f341f737ce9ae751eb22f0d03a149baee04dfba` |
| `lane/c44-execution-proof` | `0efab6e176406f957d40978c915b624f5799eb21` |
| `lane/c44-comparator` | `1d154b07e9307c7a38c9699299692c4ae6da81f0` |

Ancestry proven with `git merge-base`: all three lanes fork from
`c989d7cce445748c696cd6434f0837ca2eeb4df2`, which is an ancestor of `main`.
`main` is one commit ahead of the fork point (`3c475db`, the mid-cycle
wrapped-path safe-read fix); the integrator branch started at `main`'s tip, so
every lane merge carries that fix plus the lane's work.

## Merges

Zero conflicts; the three lanes own disjoint file sets by plan.

| commit | merge |
|---|---|
| `862220322420f07cbc26477ef201007a422218f3` | prep: clear stale prior-run integrator handoff files (owned) |
| `3bb53b38e11e0dbaca1bf4d5e5fbef1fdcdb0b8b` | `lane/c44-prompt-chain` — typed-section dedupe + immutable finalist retention |
| `24048c1f46bdce18ea42d86c7604b941e621447f` | `lane/c44-execution-proof` — consumed-stdin receipt integrity + single run-mode vocabulary |
| `d0106a68ff3916c9e88f349ae7afd9c2aba4ad0d` | `lane/c44-comparator` — validated-win-only comparator tally |

**Repairs: none.** No conflict resolution, no code changes by the integrator.

## Reject-scan (all lanes admitted)

- **Contract/schema/status edits:** `git diff --name-only c989d7c..<lane>` for
  each lane contains no file under
  `docs/polylane/taste-certification/contracts/`, no `*.schema.json`, no
  `CONTRACT-LOCK`/`EVIDENCE-CLAIM-REGISTRY`, no `max-state.json`, no
  `SKILL.md`, no `references/`. All five registry statuses stay `OPEN`.
- **Weakened/deleted checks:** every deleted line across the three changed
  `bin/` scripts was read. The only removed validation clauses are (a) the
  ballot's outright rejection of ties/abstentions — which *is* the
  denominator-shrinkage defect, replaced by a stronger typed, fail-closed
  classification that still refuses every laundering direction (10 dedicated
  rejection assertions), and (b) the prompts `rm -f` of delivered artifacts —
  which *is* the deletion defect. Dispatch rewrites in
  `polylane-taste-execution-contract.sh` and `polylane-taste-ballot.sh`
  preserve the pre-existing verbs' arity checks and exit codes (covered by
  usage regressions in the lanes' suites).
- **Regression tests genuinely gate their controls:** spot-checked by real
  reverts, not mentally — see below.

## Revert spot-checks (control removed ⇒ test fails)

Each implementing script was replaced by its `c989d7c` (pre-control) bytes, the
lane's tests were run, and the merged version restored (`git status` clean vs
`HEAD` afterwards):

| script reverted | test | result without control |
|---|---|---|
| `bin/polylane-taste-prompts.sh` | `test-taste-prompt-integrity.sh` | FAIL (rc=127, `locked_bytes: command not found`, dedupe assertions fail) |
| `bin/polylane-taste-prompts.sh` | `test-taste-artifact-retention.sh` | FAIL (rc=1, retention chain absent) |
| `bin/polylane-taste-execution-contract.sh` | `test-taste-delivery-provenance.sh` | FAIL (rc=1, `5 test(s) failed` — matches lane-documented RED exactly) |
| `bin/polylane-taste-execution-contract.sh` | `test-taste-run-mode.sh` | FAIL (rc=1, `16 test(s) failed` — matches lane-documented RED exactly) |
| `bin/polylane-taste-ballot.sh` | `test-taste-comparator-outcome.sh` | FAIL (rc=2, tally absent, non-wins vanish) |

No test passes without its control implemented; no control lacks a test that
demonstrably failed first (each lane additionally documents its original RED
run, and execution-proof/comparator REDs reproduce byte-for-byte here).

## Seams

- `git diff --check c989d7c d0106a6` — clean.
- Cross-module read of the three merged boundaries together:
  - `polylane-taste-execution-contract.sh` dispatch keeps
    `validate`/`fingerprint` shapes unchanged and adds
    `run-mode-vocabulary`/`run-mode-transition`; the frozen dual-validator
    acceptance command is unaffected (fingerprint below unchanged).
  - `taste-prompt-consumed/v1` (`consumed-receipt.json`, prompt-compile
    boundary) and the manifest `stdin_adapter` receipt fields (execution
    boundary) share no file, schema version, or key path — no collision, and
    prompt-chain explicitly disclaims the downstream stdin-proof claim that
    execution-proof enforces.
  - `polylane-taste-ballot.sh` `tally` binds its own validator fingerprint;
    its callers (`polylane-visual-tournament.sh`, `polylane-taste.sh`) are
    covered by pre-existing suites, all green in the full run.
- Shellcheck fresh at the merged tree: the three changed `bin/` scripts clean
  at `-S warning`. Two SC1007 notes in
  `tests/test-taste-delivery-provenance.sh` / `tests/test-taste-run-mode.sh`
  come from the pre-existing repo idiom `CDPATH= cd` (identical line in
  `tests/test-run-stats.sh`, `tests/test-taste-execution-contract-v3.sh`); the
  frozen terminal shellcheck gate covers `bin/*.sh` only, so this matches
  convention and gates.

## Frozen m32.7 focused acceptance (exactly as recorded in `docs/polylane/max-state.json`, sid `m32.7`, tier `focused`)

All six commands run fresh on the merged tree through
`bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator"`:

| command | fresh result |
|---|---|
| `bash tests/test-taste-prompt-integrity.sh` | **34 pass, 0 fail** |
| `bash tests/test-taste-delivery-provenance.sh` | **14 ok, 1..14, rc=0** |
| `bash tests/test-taste-comparator-outcome.sh` | **49 pass, 0 fail** |
| `bash tests/test-taste-artifact-retention.sh` | **42 pass, 0 fail** |
| `bash tests/test-taste-run-mode.sh` | **18 ok, 1..18, rc=0** |
| execution + source example-manifest validators | `VALID execution-v3 3b8d5fdeb31721caac38696464d84eb4157179d6bd0f06df4948a72bf689542e` + `SOURCE-CONTRACT-V3-OK` |

The execution example fingerprint is unchanged from the freeze — no contract
byte moved this cycle.

## Full suite

`POLYLANE_MIN_DISK_GB=0 bash tests/run.sh` on the merged tree:
**4237 passed, 0 failed, 180 test files** (rc=0). Pre-merge main was 4110/175;
the five new lane suites account for the growth, and every pre-existing suite
stays green.

## Per-defect table

| defect id | required v3 control (registry, verbatim-verified) | implementing lane | proving test | fresh result |
|---|---|---|---|---|
| `c42b-unsafe-whole-document-prompt-dedupe` | Deduplication is restricted to typed sections and cannot alter mandatory locked bytes. | `prompt-chain` | `tests/test-taste-prompt-integrity.sh` | 34 pass, 0 fail |
| `c42b-optimized-prompt-deletion` | The frozen finalist prompt bytes and their source, compiled, delivered, and consumed receipt chain remain immutable and addressable after promotion. | `prompt-chain` | `tests/test-taste-artifact-retention.sh` | 42 pass, 0 fail |
| `c42b-missing-consumed-stdin-proof` | Delivered and consumed stdin SHA-256 and byte count match and are bound by a successful stdin adapter receipt and request receipt. | `execution-proof` | `tests/test-taste-delivery-provenance.sh` | 14 ok, rc=0 |
| `c42b-run-mode-vocabulary-mismatch` | Run mode values use one contract-v3 vocabulary at producer, validator, storage, and lifecycle boundaries. | `execution-proof` | `tests/test-taste-run-mode.sh` | 18 ok, rc=0 |
| `c42b-comparator-pseudo-win` | Only a validated outcome equal to win increments wins; ties, abstentions, missing evidence, and invalid evidence remain non-wins in the fixed denominator. | `comparator` | `tests/test-taste-comparator-outcome.sh` | 49 pass, 0 fail |

## Coordination relay

Start-of-run and pre-completion relay both returned one pending request:
`contract-import → integrator`, seq 1, dated 2026-08-18 — a **cycle-43/m32.6**
scope-gap request for a 4-line needle swap in `tests/test-lane-done-live.sh`.
Already satisfied on `main` before this run: both requested needles are present
(`grep -c` = 2) and `bash tests/test-lane-done-live.sh` passes fresh at
**18 pass, 0 fail**. Stale; no action required this run. No
current-run requests addressed to the integrator exist.

## Limitations

- **All five registry defect statuses remain `OPEN`.** Flipping a status
  re-freezes a hashed contract; that decision belongs to the registry owner /
  host gate, not this run. Nothing here upgrades any claim — the controls are
  implemented and regression-tested, which is exactly what the dispositions
  require before any flip.
- **External evidence: none.** No network, installs, live provider calls, or
  browsing. No taste or human certification claim minted, implied, or
  upgraded.
- Lane-declared limitations carry through unchanged and unresolved, notably:
  the run-mode vocabulary is served and enforced at the execution-contract
  boundary but `bin/polylane-finalize.sh` still carries its own transition
  table copy (FORBIDDEN path for the lane and outside this cycle's plan);
  divergent `adapter_binary_sha256` values under one pinned adapter id remain
  unconstrained because the frozen example ships that shape; the ballot
  denominator is a caller-supplied input bound to the lock's constants at the
  benchmark-runner boundary, not inside `tally`; `taste-ballot-validation/v1`
  receipts carry no self-hash; ballot v2
  (`bin/polylane-taste-ballot-live.sh`) still fails closed on ties and
  abstentions and is out of this cycle's scope.
- "Typed section" and "mandatory locked byte" are definitions local to
  `bin/polylane-taste-prompts.sh` (the v3 schemas define neither); a later
  contract version defining them differently forces re-reconciliation.
- The terminal-tier acceptance command is the host gate's boundary; its
  constituent parts were run here (full suite, shellcheck over changed
  scripts, `git diff --check`) but the gate itself decides GO.

## Skill receipts

SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.codex/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/test-driven-development/SKILL.md | 1657109997-9015

SKILL-EVIDENCE: superpowers:test-driven-development — helped: its rule "test passes immediately means you're testing existing behaviour" is why the reject-scan used real reverts instead of the permitted mental spot-check. Replacing each script with its `c989d7c` bytes reproduced the lanes' documented RED signatures exactly (`5 test(s) failed` provenance, `16 test(s) failed` run-mode, rc=127 integrity), which upgraded "the lane says the test failed first" into integrator-verified evidence for all five controls.

SKILL-EVIDENCE: engineering:testing-strategy — helped: its "contract tests for consumers" item shaped the seam pass. For each changed script I enumerated consumers (`polylane-promptopt.sh` callers, `polylane-visual-tournament.sh`/`polylane-taste.sh` for the ballot, the frozen dual-validator acceptance for the execution contract) and checked each is exercised by a pre-existing green suite plus the unchanged example fingerprint — which is what makes "validate/fingerprint unchanged" a verified claim rather than a lane assertion.
