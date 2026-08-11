# Cycle 38 taste-certification integration verification

Run: `c38-taste-engine-20260811-a1`
Scope: executable mechanics for `m32.2`, not a real benchmark or a human-panel result.

## Exact merged tips

| Lane | Tip |
| --- | --- |
| capture-engine | `e3693085292fcf582213a1c886ceacef8260386d` |
| pixel-verifier | `60ae57bfce8ea0c461549c117234e881e3a61709` |
| calibration-corpus | `497e8b4f4c0ece2eb01215f839dea6fcfd247fbd` |
| judge-calibration | `6d1d5ed4dc354a26c89d0c03d47ba288c6f1aabd` |
| blind-ballot | `8b7b15acd931ccd106907897bb06d6ceb2cdd65c` |
| stats-engine | `d81a23277e906628c95267b57d9178497aebfe9e` |
| cert-aggregator | `67f3b9b66a60e3f896bbdd2beaaf2093463ef0eb` |
| threat-engine | `6feb0afcb71fc9800b9b7c2693056ea302b14e42` |

## Integrated seam evidence

- Capture now publishes the exact pixel-verifier matrix fields, capture-local artifact paths, a declared decoder, and an aggregate browser receipt whose source-revision digest and every PNG output are bound.
- Pixel verification resolves evidence relative to its manifest, keeps decoder commands source-root-relative, checks decoder dimensions, and rejects duplicate JSON keys as well as linked/traversing artifacts.
- Calibration receipts carry a computed stable `judge_id` and `machine` kind; certificate consumption binds that identity to each eligible ballot judge.
- The certificate consumes the threat engine's actual clean four-axis receipt, not obsolete caller-supplied `prompt_injection` or `provenance` fields.
- Public compiler, calibration, pixel, threat, and stats inputs reject duplicate JSON keys. The compiler derives its status and thresholds from receipts and atomically replaces any prior certificate.

The hermetic capture fixture invokes capture and then the independent pixel verifier against its published manifest (`captures=2`). It proves interface and provenance mechanics only; its declared adapters are local fixtures, not a claim that a real browser or external decoder ran.

## Threat matrix

| Attack | Enforced failure boundary |
| --- | --- |
| Header-only/fake pixels | PNG structure, declared decoder, non-background and diversity checks |
| Symlink or traversal | Component-by-component regular-file checks |
| Stale capture/receipt | Source revision, commit time, capture time, and receipt-time checks |
| Caller-supplied pass/score | Closed certificate index and recomputed thresholds |
| Weak, biased, or self-attested judge | Held-out Wilson, side/mirror probes, stable identity, eligibility recomputation |
| Order bias, leakage, abstention abuse | Pointwise seals, A/B+B/A mirrors, opaque identities, independent judges |
| Duplicate prompt/key or malformed number | Strict stream duplicate detection; typed vote/score/statistics validation |
| Template sameness false positive | Cross-brief blinded review trigger only; no copying/authorship conclusion |
| Function or accessibility regression | Non-compensatory hard veto and blocked threat receipt |

## Verification commands and assertions

All commands below ran through `bin/polylane-check.sh "$PWD/.polylane/check-cache/integrator" -- …` after the seam repairs:

```bash
tests/test-visual-capture.sh       # 19 pass, including capture -> pixel seam
tests/test-taste-pixels.sh         # 10 pass
tests/test-taste-corpus.sh         # 7 assertions
tests/test-taste-calibrate.sh      # pass, duplicate prompt/key and numeric attacks
tests/test-taste-ballot.sh         # 11 pass
tests/test-taste-stats.sh          # pass, malformed/duplicate inputs rejected
tests/test-taste-certification.sh  # pass, atomic derived certificate fixture
tests/test-taste-threat.sh         # 13 pass
shellcheck -S warning bin/polylane-visual-capture.sh bin/polylane-taste-pixels.sh \
  bin/polylane-taste-corpus.sh bin/polylane-taste-calibrate.sh \
  bin/polylane-taste-ballot.sh bin/polylane-taste-stats.sh \
  bin/polylane-taste.sh bin/polylane-taste-threat.sh
bin/polylane-markers.sh check-docs references/
bin/polylane-seams.sh scan .
git diff --check
```

The frozen `m32.2` acceptance is exactly its required visual-capture and certificate focused tests plus ShellCheck for `bin/polylane-taste.sh` and `bin/polylane-visual-capture.sh`; it is included in the final cached pass.

## Honest external boundaries

No corpus download, licensed external corpus validation, real browser run, human panel, deciding human ballot, 20-brief benchmark, publication, deployment, or promotion is claimed. `HUMAN_CERTIFIED` remains unavailable without that external evidence chain. The positive certificate fixture is explicitly hermetic mechanics evidence and labels its machine path `human_certified: false`.

## Selected-skill receipt and evidence

SKILL-READ: engineering:code-review | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/code-review/SKILL.md | 6303932f1b301c614a6f5a0099cd87a19e1cd1b7cbfa1a1e11e996edbca6426b

SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 5c5e95830754bbdd838213fa05fc8f07523f591fd558fd3c86031ffd479f7a9e

SKILL-READ: operations:risk-assessment | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md | 82e29810a762c396a56f92bbd5c5afd252f7a07c6be69a246c28f7b82c4086d9

SKILL-READ: ponytail:ponytail-review | /Users/leonardo/.codex/plugins/cache/ponytail/ponytail/4.9.0/.openclaw/skills/ponytail-review/SKILL.md | 76addbc1c5293d5a2da42828f4bff1cee5050492d06c194354df2f6329398df5

SKILL-EVIDENCE: engineering:code-review — helped: exposed the incompatible capture/pixel, calibration/ballot, and threat/certificate schemas before they could create a false green.

SKILL-EVIDENCE: engineering:testing-strategy — helped: added the capture-to-pixel seam test and red assertions for duplicate prompt/key and malformed ballot input.

SKILL-EVIDENCE: operations:risk-assessment — helped: prioritized receipt freshness, traversal, leakage, weak-judge, and accessibility vetoes as fail-closed gates.

SKILL-EVIDENCE: ponytail:ponytail-review — helped: kept the repair to versioned fields and existing executables; no new dependency, framework, or speculative service was introduced.

## Pending final handoff

Final cached verification, relay/inbox drain, refinement decisions, and the current-run verdict handoff follow this evidence record.
