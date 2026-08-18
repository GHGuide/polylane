# Verify — tournament-engine (Cycle 39, run c39-visual-loop-20260812-a1)

Fail-closed visual candidate tournament: a Bash-3.2 `taste-tournament/v1` controller
that preserves the best verified incumbent and promotes only a unique Condorcet
winner selected from genuinely divergent, fully rendered, goal-and-design-lock-bound
candidates. Durable state (an append-only hash-chained event log + an atomic CAS
champion registry) is authoritative; caller JSON is never trusted.

Owned files:
- `bin/polylane-visual-tournament.sh` — the controller (lock / run / reserve / repair /
  select / champion / state / verify-log / aggregate-match / check-captures).
- `bin/polylane-scope.sh` — extended with the typed exclusive candidate group.
- `tests/test-visual-tournament.sh`, `tests/test-taste-tournament.sh`,
  `tests/test-tournament-capture-seam.sh`, `tests/test-champion-persistence.sh`,
  `tests/test-graph-tournament.sh`.

The controller **composes** the frozen Cycle-38 validators — it re-executes
`polylane-taste-pixels.sh verify` per candidate and `polylane-taste-ballot.sh
validate` per mirrored group — and never re-implements their checks. Real
decoded-PNG fixtures are produced through `polylane-visual-capture.sh` (the
declared browser/decoder adapter boundary), so positive cases run on genuine
decoded pixels and validator-produced receipts, not header-only stand-ins.

## Command outputs

```
$ bash tests/test-visual-tournament.sh
test-visual-tournament.sh: 20 pass, 0 fail
$ bash tests/test-taste-tournament.sh
test-taste-tournament.sh: 13 pass, 0 fail
$ bash tests/test-tournament-capture-seam.sh
test-tournament-capture-seam.sh: 9 pass, 0 fail
$ bash tests/test-champion-persistence.sh
test-champion-persistence.sh: 29 pass, 0 fail        # ~2m48s (real PNG + real ballots)
$ bash tests/test-graph-tournament.sh
test-graph-tournament.sh: 15 pass, 0 fail
$ bash tests/test-scope.sh                            # regression: existing scope contract intact
test-scope.sh: 29 pass, 0 fail
$ shellcheck -S warning bin/polylane-visual-tournament.sh bin/polylane-scope.sh
SHELLCHECK CLEAN
$ git diff --check
DIFF-CHECK CLEAN
```

Per TEST-CADENCE the combined Cycle-39 suite and the live benchmark are left to
the integrator/coordinator. Per EXTERNAL-EVIDENCE these fixtures prove protocol
behavior only; no human panel, deployment, or real old-versus-new benchmark is
claimed. The local label is always `SELECTED_NOT_CERTIFIED`; the separate
certified registry is never written by this lane (asserted:
`champ-losing-repair-no-certified-registry`, `visual-no-separate-certified-registry`).

## Schema / receipts

Durable artifacts under `STATE_DIR`:
- `events.log` — one compact JSON object per line, each with `seq`, `kind`,
  `recorded_at`, `previous_event_sha256`, `payload`, `event_sha256`, where
  `event_sha256 = SHA-256(seq ␟ kind ␟ recorded_at ␟ previous ␟ canonical(payload))`.
  Event kinds: `TOURNAMENT_LOCKED`, `CANDIDATE_VERIFIED`, `MATCH_AGGREGATED`,
  `SELECTION`, `CHAMPION_ADVANCED`, `REPAIR_RESERVED`, `REPAIR_RESULT`, `REPLAN`.
- `champion.json` — `taste-champion-registry/v1`: `generation`, `champion_candidate_id`,
  `label:"SELECTED_NOT_CERTIFIED"`, `run_id`, `previous_generation_sha256`, `advanced_at`.
- `receipts/` — immutable (never overwritten) candidate, match, selection,
  repair-result, and champion receipts.

Input contracts (all exact-key, unknown/duplicate keys rejected):
`taste-tournament-lock/v1` (frozen goal/brief/reference/direction/design-lock digests,
base revision, capture-plan digest, exactly three opaque candidate ids, pair list
`1-2,1-3,2-3`, `min_groups>=5`, `repair_budget==2`); `taste-tournament/v1` (3-way
initial / 2-way repair; candidates carry only index + safe relative capture_root,
capture_manifest, hard_gate — **no** winner/status/pass/score field can exist);
`taste-tournament-escrow/v1` (post-seal reveal of exactly the pair's two stimuli,
hash-bound to every group's `candidate_ids_escrow_sha256`); `taste-hard-gate/v1`
(task/accessibility/state/product vetoes, `overall==PASS`, bound to the manifest sha).

## State machine

```
NEW ──lock──▶ LOCKED ──run(3-way, all vetoes, blind round-robin)──▶
      unique Condorcet winner ─▶ CANDIDATE_VERIFIED×3, MATCH_AGGREGATED×3,
                                 SELECTION, CHAMPION_ADVANCED(gen 0)  ─▶ SELECTED
      cycle / tie / missing match / any veto fail ─▶ (no champion) REPLAN/NOT-CERTIFIED

SELECTED ──reserve(attempt=used+1, ≤budget, parent==champion, lock unchanged)──▶ REPAIR_RESERVED
REPAIR_RESERVED ──repair(2-way incumbent vs challenger)──▶
      challenger wins & new pixels ─▶ CHAMPION_ADVANCED(gen+1, prev pointer) ─▶ SELECTED
      material loss (budget remains) ─▶ REPAIR_RESULT(RETAINED) ─▶ SELECTED (retry allowed)
      unchanged / oscillation / plateau(loss on last attempt) ─▶ REPAIR_RESULT(REPLAN) ─▶ REPLAN

Any tamper (skipped seq, mutated payload, truncated line) ─▶ verify-log/state fail closed.
```

The champion advances **only** by compare-and-swap: `advance_champion` locks the
state dir, requires the on-disk `generation` to equal the event-projected expected
generation, writes `previous_generation_sha256 = SHA-256(prior champion.json)`, and
renames atomically. A registry that moved under the controller fails closed
(`champ-concurrent-cas-fails`).

## Restart / CAS proof

Projection is pure replay of the verified chain (no hidden state), so a restart
re-derives identical state, and a repair token reserved before work survives the
restart — the budget cannot be reset.

```
$ polylane-visual-tournament.sh lock  s lock.json <now>      → TOURNAMENT: LOCKED
$ polylane-visual-tournament.sh state s   # replay #1        → phase=LOCKED repairs_reserved=0 champion_generation=-1
$ polylane-visual-tournament.sh state s   # replay #2        → identical (pure replay, restart-safe)
$ polylane-visual-tournament.sh verify-log s                 → TOURNAMENT: LOG-OK
# tamper one payload byte:
$ polylane-visual-tournament.sh state s                      → rc=1 (fail-closed)
$ polylane-visual-tournament.sh verify-log s                 → TOURNAMENT: LOG_CORRUPT (rc=2)
```

CAS generation + previous-pointer chaining is proved end-to-end by the champion
test on real PNG fixtures:
`champ-gen0-prev-pointer-zero` (gen 0 previous = 64 zeros) →
`champ-first-repair-prev-points-at-gen0` (gen 1 previous = SHA-256 of gen-0 registry) →
`champ-second-repair-gen2`; and durability by
`champ-reservation-is-durable` + `champ-budget-not-reset-by-re-reserve` +
`champ-third-repair-refused`.

## Attack matrix

| Attack | Test case(s) | Mechanism |
|---|---|---|
| prose pass | `visual-rejects-caller-prose-pass` | exact-key `taste-tournament/v1`; no code reads a `pass`/`verdict` |
| caller-selected winner | `visual-rejects-caller-supplied-winner` | winner is derived; a `winner` key is a rejected unknown key |
| score / LOC bypass | `visual-rejects-caller-score-loc-bypass` | no score/LOC/margin path; extra keys rejected |
| two / four candidates | `visual-rejects-two-candidates`, `visual-rejects-four-candidates` | shape requires exactly 3 (indices 1..3) bound to the lock |
| same pixels (cross-candidate) | `visual-rejects-cross-candidate-identical-pixels`, `seam-rejects-cross-candidate-identical` | union of decoded-pixel digests must be unique across candidates |
| stale source | `visual-rejects-stale-source`, `seam-rejects-stale-source` | manifest `candidate_source_revision` must equal frozen base; pixel verifier also binds git HEAD |
| lock mismatch | `visual-rejects-design-lock-mismatch` | design-lock digest must equal the frozen lock |
| missing match | `visual-rejects-missing-match` | shape requires all three pairs `1-2,1-3,2-3` |
| 1-1-1 cycle | `visual-cycle-yields-replan`, `visual-cycle-no-champion` | Condorcet needs one candidate winning both matches; cycle → REPLAN, no champion |
| failed hard gate | `visual-rejects-failed-hard-gate`, `visual-badgate-no-champion` | deterministic task/a11y/state/product veto precedes taste |
| missing / linked / traversal / tampered / placeholder captures | `seam-rejects-missing-manifest`, `seam-rejects-symlinked-manifest`, `seam-rejects-path-traversal`, `seam-rejects-tampered-screenshot`, `seam-rejects-symlinked-capture-root`, `seam-rejects-hardgate-manifest-mismatch` | safe repo-relative resolution (no symlink/traversal) + composed pixel verifier + hard-gate provenance |
| weak / aliased judge | `taste-rejects-ineligible-judge`, `taste-rejects-aliased-judge-across-match` | ballot validator eligibility + distinct exposure judges across the match |
| ballot reuse | `taste-rejects-reused-ballot-group` (in-match), run-level `no_ballot_reuse` (group/pointwise id uniqueness) | reused group repeats judges → rejected; cross-match ids must be unique |
| A/B order flip | `taste-rejects-ab-order-flip` | mirror exposures must agree on canonical choice |
| identity leakage / injection / discussion | `taste-rejects-identity-leakage`, `taste-rejects-prompt-injection`, `taste-rejects-shared-channel-discussion` | delegated ballot validator flags |
| escrow tamper | `taste-rejects-escrow-mismatch`, `taste-rejects-escrow-not-revealing-pair` | escrow file hash must equal every group's escrow digest and reveal exactly the pair |
| tie / quorum gap | `taste-rejects-tie-no-strict-majority`, `taste-rejects-quorum-gap` | strict majority (> half), ≥5 eligible groups; no margin tie-break |
| skipped event | `champ-detects-skipped-event` | contiguous `seq` required |
| chain mutation | `champ-detects-chain-mutation` | recomputed `event_sha256` must match |
| interrupted projection | `champ-detects-interrupted-projection-verify/-state` | truncated final line fails JSON/chain check |
| stale parent | `champ-rejects-stale-parent` | reservation parent must equal current champion |
| attempt gap | `champ-rejects-attempt-gap`, `champ-cannot-re-reserve-with-pending-token` | attempt must equal reservations+1; no pending double-reserve |
| third repair | `champ-third-repair-refused` | attempt > budget refused (durable ledger) |
| unchanged repair | `champ-unchanged-repair-replan` | challenger pixels must differ from stored champion render |
| oscillation | `champ-oscillation-replan` | challenger equal to any prior champion → REPLAN |
| concurrent / stale CAS | `champ-concurrent-cas-fails` | on-disk generation must equal expected before advance |
| losing-repair champion immutability | `champ-losing-repair-generation-unchanged`, `champ-losing-repair-registry-byte-identical`, `champ-losing-repair-no-certified-registry` | a non-promoting repair mutates nothing; certified registry never written |
| candidate-group scope isolation | `graph-static-allows-three-same-base-candidates`, `graph-static-rejects-ordinary-into-candidate-scope`, `graph-candidates-rejects-two/four/ghost/nonmember-selected/member-escaping-shared-scope`, `graph-integration-tip-is-the-single-selected` | three same-base lanes overlap only inside the declared exclusive group; ordinary lanes may not; exactly one selected tip reaches integration |

Zero-repair selection on real decoded PNGs: `visual-zero-repair-selects-condorcet-winner`.
First/second-repair promotion on real decoded PNGs: `champ-first-repair-gen1`,
`champ-second-repair-gen2`.

## Skills

SKILL-READ: data:statistical-analysis | /Users/leonardo/.codex/plugins/cache/claude-cowork/data/1.1.0/skills/statistical-analysis/SKILL.md | 2702170626-10434
SKILL-READ: design:design-critique | /Users/leonardo/.codex/plugins/cache/claude-cowork/design/1.2.0/skills/design-critique/SKILL.md | 2647275183-3923
SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
SKILL-READ: superpowers:test-driven-development | /Users/leonardo/.claude/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/test-driven-development/SKILL.md | 1657109997-9015

SKILL-EVIDENCE: superpowers:test-driven-development — helped: red-first exposed real defects that tests-after would have masked. The scope test failed with `SCOPE-OVERLAP` on the three same-base candidates before the extension existed; the first controller run failed with `candidate ids/order != frozen lock`, pinpointing a `jq -r` array formatting bug in the lock binding; and the badgate case surfaced a capture-timing bug (fixture built after `NOW`). Each fix followed a watched failure.

SKILL-EVIDENCE: engineering:testing-strategy — helped: shaped the pyramid — a broad base of fast, isolated attack cases (graph 15, taste 13, seam 9 run in <1 min total) plus a few slow, high-confidence e2e cases (visual zero-repair, champion repair chain) on real PNG + real ballots. It also drove the decision to cache the expensive initial run once and clone the gen-0 state for the durability scenarios, keeping coverage high without re-paying the render cost.

SKILL-EVIDENCE: data:statistical-analysis — helped: reinforced treating the ≥5-group quorum and strict-majority resolution as non-compensatory coverage floors, not a taste score — so ties yield "no strict majority" and there is deliberately no margin/score/LCB tie-break in selection. Directly informed the `taste-rejects-tie-no-strict-majority` and `taste-rejects-quorum-gap` cases; its forecasting/outlier material was not applicable to this lane.

SKILL-EVIDENCE: design:design-critique — unused: it is an interactive human-facing critique framework (Figma/screenshot review output) with no executable seam in a fail-closed protocol lane. Its "name the specific region/state, not a vague adjective" principle mirrors the protocol's requirement that pointwise observations cite a capture/region/brief-clause (honored by the fixtures), but no design review was performed or needed here.

## DEFERRED

DEFERRED: none
