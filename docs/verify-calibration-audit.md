# Verify — calibration-audit (independent panel calibration auditor)

Run: `c41-source-calibration-20260812-a1` · Lane: `calibration-audit`

## Repair reflection (attempt 1)

1. **What went wrong:** the prior attempt spent its whole session on startup exploration —
   interactive permission prompts and a failing PreToolUse hook on its very first shell
   commands — and ended without writing the auditor, the test, or any status file.
2. **Root cause:** it began with broad environment/log probes that tripped confirmation
   dialogs it could not answer autonomously, so it never entered the red-test → implement
   loop before the session died.
3. **Different approach now:** go straight to TDD with minimal, non-interactive shell use —
   write the failing test first, implement `bin/polylane-taste-calibration-audit.sh` against
   it, verify with the focused test plus ShellCheck, commit, and only then write evidence.

---

## Subject under verification

- `bin/polylane-taste-calibration-audit.sh` — independent panel calibration
  auditor (`taste-calibration-audit/v1`, receipt
  `polylane.taste.calibration-audit.v1`).
- `tests/test-taste-calibration-audit.sh` — 21 red-first assertions:
  independent arithmetic first, then the adversarial receipt matrix.

The auditor is a **pure verifier** (bash 3.2 + jq + awk). It never invokes a
model, never repairs evidence, and never re-runs a judge
(`EXTERNAL-EVIDENCE` boundary).

## 1. What the auditor audits

Input: a panel manifest binding, per judge configuration, three artifacts by
path + sha256 under one artifact root:

| Artifact | Schema | Produced by |
|---|---|---|
| calibration input | `taste-calibration/v2` input | calibration-campaign lane |
| eligibility receipt | `polylane.taste.judge-eligibility.v2` | live validator |
| session ledger | `taste-calibration-sessions/v1` | calibration-campaign lane |

Session ledger shape (closed): `{schema_version, judge_id, sessions:[{unit_id,
role: primary|mirror, session_id, response_sha256}]}` — exactly one entry per
unit×role, each bound to the recomputed raw-response digest.

None of the three artifacts is trusted. The auditor recomputes, from raw
evidence resolved relative to the calibration input's own directory (identical
semantics to the upstream validator):

- **correctness** — gold from the hash-bound human holdout labels file, votes
  re-parsed from hash-verified raw responses with the pinned parser
  (`polylane.taste.response-parser/v1`, digest recomputed from its byte-frozen
  spec, never imported);
- **Wilson 95% lower bound** — `(p + z²/2n − z·√((p(1−p)+z²/4n)/n)) / (1+z²/n)`
  with `z = 1.959963984540054`;
- **exact side probe** — two-sided exact binomial p at 0.5 over scored units;
- **mirror contradictions** — scored units whose primary and mirror verdicts
  name different stimuli;
- **raw-response closure** — declared digests must match recomputed file/inline
  bytes; a declared path that cannot produce matching bytes is
  `SYNTHETIC_RECEIPT`;
- **session uniqueness** — 1:1 unit×role coverage, response-digest binding,
  no duplicate session ids in a ledger, primary≠mirror session per unit, and
  no session id shared across configurations (panel-level `SESSION_REUSE`);
- **parser / invocation / config hashes** — freeze block, per-ballot
  invocations, and receipt configuration identity must all agree;
- **holdout binding** — labels digest, per-unit image/label joins, stimulus-id
  sets, source snapshot, tuning/holdout disjointness;
- **classification** — `production` iff every image and both raw responses of
  every unit are hash-matched regular files; inline/sha-only stays
  `fixture_only` and can never enter the production panel count.

## 2. Frozen gates (constants in the script, never inputs)

| Gate | Threshold | Reject code |
|---|---|---|
| units | ≥ 24 | `ACCURACY_FLOOR` |
| correct | ≥ 17 | `ACCURACY_FLOOR` |
| Wilson LCB (95%) | ≥ 0.50 | `WILSON_FLOOR` |
| side probe n | ≥ 12 | `SIDE_BIAS` |
| side probe exact p | ≥ 0.05 | `SIDE_BIAS` |
| mirror probe n | ≥ 8 | `MIRROR_INSTABILITY` |
| mirror contradictions | ≤ 1 | `MIRROR_INSTABILITY` |
| panel production configs | ≥ 5 | `PANEL_FLOOR` |

A configuration is eligible only when **every** gate passes and no structural,
binding, session, or receipt cross-check code fired.

## 3. Receipt cross-check (adversarial)

The emitted per-configuration receipt is compared against the recomputed
truth — divergence can only lower the outcome, never raise it:

- recomputed `units/correct/wilson/side/mirror/classification/eligible/production`
  vs receipt claims → `RECEIPT_MISMATCH`;
- receipt bound to a different calibration input, judge id, or frozen
  provider/model/prompt/sampling/adapter/snapshot identity → `STALE_CONFIG`;
- receipt parser digest ≠ pinned parser → `PARSER_CHANGED`;
- receipt labels digest ≠ recomputed labels digest → `HOLDOUT_BINDING`;
- receipt with `human_certified != false`, `machine_not_human != true`, or a
  claim other than `HUMAN_CALIBRATED_MACHINE` → `HUMAN_CLAIM`, which also
  poisons the panel.

## 4. Claim ceiling

`HUMAN_CALIBRATED_MACHINE` is emitted **only at panel level** (`panel.claim`),
only when ≥ 5 eligible production configurations survive with no cross-config
session reuse and no human-claim escalation. Per-configuration entries carry
no claim string. The audit receipt hard-codes `human_certified: false` and
`machine_not_human: true` on every path, including all failure paths.

## 5. Verification evidence

```
$ bash tests/test-taste-calibration-audit.sh
PASS test-taste-calibration-audit assertions=21

$ shellcheck -S warning bin/polylane-taste-calibration-audit.sh
(clean)
```

Independent arithmetic spot checks encoded in the test:

- Wilson LCB for 17/24 = 0.508323 (recomputed, matches gate margin over 0.50);
- Wilson LCB for 24/24 = 1/(1+z²/24) = 0.862024 (p=1 collapses the interval);
- balanced 12/24 side split is an exact tie → two-sided exact binomial p
  clamps to 1.000000;
- 13/24 side split → p = 0.838820.

## SKILL-EVIDENCE

- SKILL-EVIDENCE: superpowers:test-driven-development — helped: the full
  21-assertion suite was written and run red (auditor absent) before any
  implementation; two wrong hand-computed constants in the test were caught
  against the recomputed truth.
- SKILL-EVIDENCE: engineering:testing-strategy — helped: shaped the pyramid of
  independent arithmetic assertions first, then boundary gates, then the
  adversarial receipt matrix as the security-boundary layer.
- SKILL-EVIDENCE: engineering:debug — helped: the reproduce→isolate→diagnose
  loop localized the inline-fixture failure to `IFS=$'\t' read` collapsing
  empty TSV fields; fixed by switching the extraction delimiter to the non-whitespace `\u001f` unit separator.
- SKILL-EVIDENCE: operations:risk-assessment — helped: the adversarial matrix
  (stale config, changed holdout, tampered numbers, human-claim escalation,
  synthetic bindings, session reuse) was enumerated as a risk register before
  writing tests, so every high-impact forgery path has a reject code.

