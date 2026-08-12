# Cycle 39 integration verification — taste-integrator

Run: `c39-visual-loop-20260812-a1`. Branch: `lane/c39-taste-integrator`.
Base (never mutated): `candidate/c31-terminal-cert`.

This is the only current-run verdict document; the sentinel is its final line.

## 1. Merged lane tips (current tips, not cached launch SHAs)

All 15 lanes branch from the shared launch commit `2393f69`; every merge was a
`--no-ff` merge of the lane's current tip into this integration branch.

| Lane branch | Merged tip |
|---|---|
| lane/c39-receipt-producers | `916d83c` |
| lane/c39-certificate-v2 | `27e7216` |
| lane/c39-tournament-engine | `7d999c9` |
| lane/c39-taste-memory | `d73fa36` |
| lane/c39-packet-intelligence | `9650404` |
| lane/c39-quality-adapter | `158f0c2` |
| lane/c39-runner-wiring | `850ffc1` |
| lane/c39-prompt-contract | `17020de` |
| lane/c39-visual-doc-contract | `f5e03c7` |
| lane/c39-claude-contract | `69dbafa` |
| lane/c39-codex-parity | `5e23f77` |
| lane/c39-provider-hooks | `f5cdfc4` |
| lane/c39-capture-hardening | `e2a3cbc` |
| lane/c39-a11y-evidence | `b065671` |
| lane/c39-stimulus-evidence | `68506d2` |

The 15-way carve was file-disjoint: exactly one source file (`SKILL.md`) was
touched by two lanes (claude-contract's rendered-tournament contract + codex-parity's
`../references`→`references` installed-link fix). Git's 3-way merge auto-resolved it
because the edits fell in different regions; the merged `SKILL.md` carries both the
full UI/taste-tournament obligation block and the package-root-relative links. No
merge produced a conflict.

## 2. Relay (read before and after merging)

Start-of-run `pending` showed 28 lane↔lane requests; all were builder-to-builder
schema negotiations that had already converged (receipt-producers↔certificate-v2 subset
validation + stats byte-rule seq22–26; runner-wiring↔quality-adapter authoritative alias
seq15/19; runner-wiring↔prompt-contract UI-version seq3/5/17; a11y-evidence field paths
seq11–14; taste-memory positional CLI seq27) plus one request addressed to
`taste-integrator`:

- **seq28 (coordinator → taste-integrator)**: a clean, committed, current-run DONE whose
  Claude CLI pane stayed live at an empty input had no quiescing path, hanging the runner
  at 0/N. Requested a narrowly-guarded auto-quiesce + a regression.
- **seq29 (coordinator → taste-integrator)**: root-caused the `test-lane-done-live` fallout
  of a naive quiesce (marker written inside the fixture worktree) and prescribed keeping the
  once-marker outside the lane worktree (PROJECT_ROOT, else the manifest directory) plus an
  anti-dirty assertion.

Both handled — see Repair 4 and `tests/test-taste-runner-e2e.sh` §B. An ack was posted to
the coordinator. The end-of-run `pending` read is recorded in §9.

## 3. Integration repairs (each documented)

A previously green lane test is not evidence after integration: independent lanes built
against sibling *launch-point* versions of files they did not own. Four seams surfaced
when the real merged binaries met each other.

### Repair 1 — `bin/polylane-taste-corpus.sh` (receipt-producers), jq-1.8.2 precedence
`and ([.records[].domain] | unique) as $domains | (...)` binds `$domains` to the boolean
result of the preceding `and`-chain (not the domain array) under jq 1.8.2, so
`$domains | length` raised `boolean (true) has no length` and rejected every valid corpus
manifest. Fix: wrap the domain sub-expression in parentheses so the `as` binding is scoped
inside one `and` operand. Verified: the corpus producer emits `taste-corpus-receipt/v1`
`VALIDATED` on the validator-receipts fixture; `test-taste-validator-receipts.sh` 38/0.
Root-cause swept `bin/*.sh` for the same shape — the only other `as $x` uses
(`polylane-taste-corpus.sh:41`, `polylane-taste.sh:464`) are already parenthesised/top-level.

### Repair 2 — `tests/test-taste-certification.sh` (certificate-v2), stale calibration input
`make_cal_templates` built calibration input against the launch-point calibrate producer,
missing `.calibration.holdout_corpus_receipt_sha256` and `.judge.{model_version,
system_prompt_sha256,sampling_sha256}` that receipt-producers' hardened
`polylane-taste-calibrate.sh` now requires (exact judge key set, held-out corpus binding).
Fix: supply the full judge identity + corpus receipt binding. The 24 fixture units already
score 24/24 correct, so the receipt is `eligible`, `judge_configuration.kind:"machine"`.
Verified: `test-taste-certification.sh` passes end to end.

### Repair 3 — `tests/test-visual-loop-integration.sh` (codex-parity), Claude-side parity
Two `both()` parity assertions failed on the Claude side: (a) `safe-admission` —
claude-contract's "quarantine → audit → isolated benchmark → pinned arm" wraps across two
physical lines, and `both()` grepped per-line; (b) `blind-comparison` — Claude states the
obligation as "anonymized candidates … identity-hidden … mirrored judges" while the pattern
demanded "anonymized screenshots … blind". Fix (matching codex-parity's own
`codex_native` flatten approach): flatten both installed contracts before grep, and broaden
`blind-comparison` to accept either provider's faithful wording (still requires an
anonymization term AND a blind/mirror/identity-hidden qualifier). No `SKILL.md` prose was
weakened; both platforms still carry the obligation. Verified: 40/0.

### Repair 4 — `bin/polylane-run.sh` (runner-wiring), seq28 auto-quiesce (+ seq29)
`lane_done` proved a clean/committed/scope-valid/current-run DONE and then rejected it
solely because `lane_completion_worker_live` was true, with no path to close the finished
pane → the run hangs forever. Added `quiesce_done_pane`/`pane_send_exit`: only when
contract-v2 + current-run + the pane maps to this lane, send exactly one tracked `/exit`
(durable once-marker, never re-sent, never respawned) and stay "not done" this poll so the
next poll observes the exited pane and completes. Dirty/stale/marker-mismatched/symlinked
panes never reach this point, so it can only close a genuinely finished agent.

The coordinator's **seq29** flagged (and I had independently hit) the marker-location
hazard: the once-marker must live in coordinator scratch *outside* the lane worktree, else
the first live poll dirties the tree and every later poll rejects the clean DONE. Final
design per seq29: the marker base is `PROJECT_ROOT` when set (always, and distinct from
every worktree, in a real run) and otherwise the manifest's directory (a coordinator-scratch
sibling of the worktree); it is never written under `$wt`. `pane_send_exit` is a no-op when
no tmux session is bound, so the marker path stays testable in sourced fixtures. Verified:
`test-taste-runner-gate.sh` 43/0; `test-lane-done-live.sh` 18/0; the full `lane_done`
cluster (`test-lane-done`, `test-marker-contract`, `test-status-marker-normalization`,
`test-verdict-repair`, `test-supervisor`, `test-state`, `test-clear-markers`) green;
`test-taste-runner-e2e.sh` §B proves progress + idempotency + dirty/stale immunity + a
`quiesce-does-not-dirty-lane-worktree` assertion.

## 4. Transitive receipt chain (real decoded pixels → certificate)

`tests/test-taste-production-chain.sh` builds the chain from real PNG bytes and asserts
every link recomputes its own digests; no shape-compatible or cross-run receipt crosses a
boundary.

| Link | Producer/validator | Binds (recomputed) | Rejects |
|---|---|---|---|
| decoded pixels | pinned `tools/decode-png` adapter | PNG structure+CRC → decoded-pixel SHA-256 + adapter receipt | non-PNG, bad CRC, header-only |
| capture matrix | `polylane-taste-pixels.sh verify` | candidate_source_revision, decoded-pixel set (4 unique), manifest SHA-256, freshness window | symlink/traversal (`UNSAFE_PATH`), duplicate render (`DUPLICATE_RENDER`), wrong viewport (`VIEWPORT_MISMATCH`), stale (`STALE_CAPTURE`), synthetic (`SYNTHETIC_PLACEHOLDER`), missing decoder (`DECODER_UNAVAILABLE`), incomplete matrix (rc 2), duplicate JSON key (rc 2) |
| pixel receipt | `taste-pixels-receipt/v1` | status derived `VERIFIED` (never caller), subject.candidate_source_revision, inputs.capture_manifest_sha256 | fail-closed: a rejected verify writes no receipt |
| certificate | `polylane-taste.sh certify` | evidence-manifest closure, run identity | duplicate `run_id` key, garbage/cross-run manifest |
| taste memory | `polylane-taste-memory.sh record` | claim_label must be `HUMAN_CERTIFIED` + `human_certified:true` | `SELECTED_NOT_CERTIFIED`, `HUMAN_CALIBRATED_MACHINE`, traversal ledger |

Shell-metacharacter `candidate_id` is stored as inert data — running verify with
`candidate_id="a; touch …/PWNED #"` creates no `PWNED` file: no receipt value reaches a
shell/`eval`.

## 5. Attacks executed and results

`tests/test-taste-production-chain.sh` (35/0) — cross-module seams, real binaries, one
mutation per link: header-only PNG, symlink evidence, path traversal, duplicate render,
wrong viewport, stale capture, synthetic placeholder, unknown/unavailable decoder,
incomplete state matrix, duplicate JSON key, shell-metachar id no-eval, rejected-verify
writes-no-receipt, compiler duplicate-run-id, compiler garbage manifest, UI-contract
omission, builder self-verdict, hooks blank-target locate+render, memory
SELECTED_NOT_CERTIFIED / HUMAN_CALIBRATED_MACHINE / traversal-ledger rejection, quality
certify fail-closed on hostile record, tournament fail-closed on missing escrow, a11y
fail-closed + no-receipt on untrusted input, stimulus fail-closed on missing spec.

`tests/test-taste-runner-e2e.sh` (20/0) — hermetic promotion canary + seq28 quiesce:
valid preflight → authoritative PASS → memory records the promoted receipt once; blocked
authority despite a prose GO promotes nothing and records nothing (incumbent preserved);
committed-DONE live pane → one tracked `/exit` → completes; dirty/stale panes never
quiesced; `/exit` is idempotent.

The exhaustive per-module attack matrices remain in the frozen owner tests and were rerun
against the merged tree (§6): forged escrow orientation / reused-aliased-self judge / fake
human label / 6-of-10 & 7-of-10 thresholds / cross-run receipt-chain mutation
(`test-taste-certification.sh`); tie / 1-1-1 cycle / quorum gap / no strict majority
(`test-taste-tournament.sh`); durable event replay across restarts, two-token repair cap,
third/unchanged/oscillating repair, CAS generation + previous-pointer, lock drift
(`test-champion-persistence.sh`, `test-graph-tournament.sh`); caller-`pass` accessibility,
regression veto, forged/stale adapter (`test-taste-a11y.sh`); OCR/DOM identity + prompt-
injection leakage, sealed escrow (`test-taste-stimulus.sh`); legacy-cannot-rescue-a-taste-
failure (`test-visual-quality.sh`); UI scalars survive optimization + builder-cannot-self-
certify (`test-promptlint.sh`, `test-prompt-compiler.sh`); Claude-syntax-in-Codex + broken
installed links + clean-install execution (`test-skill-parity.sh`,
`test-codex-taste-install.sh`, `test-visual-loop-integration.sh`); blank-target hook
execution + protocol packaging + stale-removal (`test-hooks.sh`, `test-install-fresh.sh`,
`test-installers.sh`).

## 6. Frozen acceptance results (merged + repaired tree)

Every frozen command in `docs/polylane/cycle-39-plan.md` was run once on the final
merged+repaired tree. **28/28 test scripts PASS; shellcheck, `git diff --check`,
`polylane-markers.sh check-docs references/`, and `polylane-seams.sh scan "$PWD"` all
clean.**

```
PASS test-taste-validator-receipts     PASS test-visual-quality
PASS test-taste-certification          PASS test-taste-runner-gate
PASS test-visual-capture               PASS test-promptlint
PASS test-taste-a11y                   PASS test-prompt-compiler
PASS test-taste-stimulus               PASS test-claude-taste-contract
PASS test-visual-tournament            PASS test-visual-loop-integration
PASS test-taste-tournament             PASS test-skill-parity
PASS test-tournament-capture-seam      PASS test-codex-taste-install
PASS test-champion-persistence         PASS test-hooks
PASS test-graph-tournament             PASS test-installers
PASS test-taste-memory                 PASS test-install-fresh
PASS test-taste-memory-security        PASS test-taste-production-chain
PASS test-taste-memory-advice          PASS test-taste-runner-e2e
PASS test-visual-taste-memory-integration
PASS test-visual-intelligence
PASS shellcheck -S warning bin/*.sh codex/install.sh claude-code/install.sh
PASS git diff --check
PASS bin/polylane-markers.sh check-docs references/
PASS bin/polylane-seams.sh scan "$PWD"
== FROZEN TOTAL FAILS: 0 ==
```

Full suite (`tests/run.sh`, all 136 `test-*.sh`) was then run once on the same unchanged
tree: **SUMMARY: 3201 passed, 0 failed, 136 test files.** The only failure observed during an earlier *concurrent* run
(`test-graph-benchmark.sh` → `benchmark-warm-append-under-250ms`) was a wall-clock timing
assertion blown by running two suites at once; it passes 17/0 in isolation and touches
none of the changed files. The `test-lane-done-live.sh` regression from Repair 4's first
draft (a quiesce marker written into the lane worktree) was fixed and re-verified 18/0
before this run.

## 7. Provider parity / fresh-install proof

`test-visual-loop-integration.sh` installs the Codex skill fixture into a blank repo
(`codex/install.sh --repo`) and asserts both the installed `SKILL.md` (Claude) and the
generated `.codex/skills/polylane/SKILL.md` (Codex-native) carry the same rendered-tournament
obligations, that every installed doc link resolves from the package root, and that the
shared `references/visual-intelligence.md` is the executable consumer boundary.
`test-install-fresh.sh` + `test-hooks.sh` prove both packaged hook fragments render + execute
from a blank project using the packaged helper (no `bin/polylane-hooks.sh` in the target),
and that the authoritative protocol ships in both packages. `test-codex-taste-install.sh`
proves clean Codex install execution and Codex-native (not Claude) syntax.

## 8. Remaining external boundaries (unchanged this cycle)

Hermetic tests prove the engineering chain but cannot mint the real-evidence claims:

- No real human panel, so no `HUMAN_CERTIFIED` and no `human_certified:true`. Every local
  tournament outcome is `SELECTED_NOT_CERTIFIED`; machine judges may be
  `human_calibrated:true` but never `human_certified:true`.
- No live browser/decoder/OCR/accessibility adapter run against a real rendered product —
  fixtures are pinned + receipted; an unavailable adapter is `UNKNOWN`, never PASS.
- No ≥10-varied-brief old-versus-new benchmark, deployment, publication, remote push, or
  install into real user skill roots. `m32.4`, `m32.5`, and `c84`–`c90` remain **not done**.
- Panel identity authenticity/independence and IP/non-copying conclusions remain external.

## 9. Relay (post-merge) and skills

Final `pending` read: the two requests addressed to `taste-integrator` (seq28, seq29) are
both handled (Repair 4) and acknowledged back to the coordinator; all other pending requests
are builder-to-builder and already converged. docs/parallel-status.md is post-cycle evidence
only, never the live relay.

SKILL-READ: engineering:code-review | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/code-review/SKILL.md | 936987158-4285
SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
SKILL-READ: operations:risk-assessment | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md | 3889652016-1630
SKILL-READ: ponytail:ponytail-review | /Users/leonardo/.codex/plugins/cache/ponytail/ponytail/4.9.0/.openclaw/skills/ponytail-review/SKILL.md | 3445243857-2118

SKILL-EVIDENCE: engineering:code-review — helped: its security/correctness lens (injection, path traversal, deserialization, edge cases) directly shaped the production-chain attack set — shell-metachar id no-eval, `UNSAFE_PATH` symlink/traversal, duplicate-JSON-key rejection, and fail-closed-writes-no-receipt.
SKILL-EVIDENCE: engineering:testing-strategy — helped: the pyramid framed the split — module owner tests stay unit/integration; the two new files are the cross-module integration chain (`production-chain`) and the e2e promotion canary (`runner-e2e`); trust boundaries and error handling covered, trivial paths skipped.
SKILL-EVIDENCE: operations:risk-assessment — helped: likelihood×impact triage kept the seq28 change in the 5k-line runner to the smallest guarded diff and drove the "merge all tips before repairing" ordering so a repair never masked a real seam.
SKILL-EVIDENCE: ponytail:ponytail-review — helped: enforced reuse of the pixels PNG factory and owner-test fixtures over reinventing them, and citing owner tests instead of duplicating ~1500 lines; the quiesce helper is the minimum working diff, not a new subsystem.

## 10. Verdict

Every frozen engineering gate passes on the merged, repaired, unchanged tree. This proves
the engineering chain only; no external human/benchmark/deployment evidence was created, so
`m32.4`, `m32.5`, and `c84`–`c90` remain not done.

POLYLANE-VERDICT: GO run=c39-visual-loop-20260812-a1
