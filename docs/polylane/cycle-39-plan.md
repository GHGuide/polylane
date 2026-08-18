# Cycle 39 plan — production-authoritative rendered taste loop

## Target

`m32.3`: integrate a fail-closed three-candidate rendered tournament, trusted visual
evidence, durable bounded repair, evidence-scoped taste memory, provider-native prompt
contracts, and fresh-install parity. This cycle closes the production chain; it does
not claim that the later multi-brief old-versus-new benchmark has passed.

## Frozen acceptance

Cycle 39 is GO only when the integrated tree passes all of these commands:

```bash
bash tests/test-taste-validator-receipts.sh
bash tests/test-taste-certification.sh
bash tests/test-visual-capture.sh
bash tests/test-taste-a11y.sh
bash tests/test-taste-stimulus.sh
bash tests/test-visual-tournament.sh
bash tests/test-taste-tournament.sh
bash tests/test-tournament-capture-seam.sh
bash tests/test-champion-persistence.sh
bash tests/test-graph-tournament.sh
bash tests/test-taste-memory.sh
bash tests/test-taste-memory-security.sh
bash tests/test-taste-memory-advice.sh
bash tests/test-visual-taste-memory-integration.sh
bash tests/test-visual-intelligence.sh
bash tests/test-visual-quality.sh
bash tests/test-taste-runner-gate.sh
bash tests/test-promptlint.sh
bash tests/test-prompt-compiler.sh
bash tests/test-claude-taste-contract.sh
bash tests/test-visual-loop-integration.sh
bash tests/test-skill-parity.sh
bash tests/test-codex-taste-install.sh
bash tests/test-hooks.sh
bash tests/test-installers.sh
bash tests/test-install-fresh.sh
bash tests/test-taste-production-chain.sh
bash tests/test-taste-runner-e2e.sh
shellcheck -S warning bin/*.sh codex/install.sh claude-code/install.sh
```

Positive production-chain tests must use decoded image bytes and validator-produced
receipts. Header-only images, nonexistent fixture paths, caller-authored `pass`, prose
verdicts, aliased judges, forged human labels, or an omitted UI contract may never
authorize promotion.

## Fifteen-way implementation carve

| Lane | Exclusive responsibility |
|---|---|
| receipt-producers | hash-bound pixel, corpus, calibration, ballot, statistics, and threat receipts; remove caller-derived canonical choices |
| certificate-v2 | consume and verify the complete producer chain; bind candidate, exact subject revision, run, eligible principals, fixture boundary, and validator-chain digest |
| tournament-engine | three same-base candidates, complete blind round-robin Condorcet selection, durable event replay, two repair reservations, CAS champion persistence, and exclusive candidate-group scope |
| taste-memory | project-rooted append-only contrast memory admitted only from whole human-certified studies; bounded advisory retrieval with a memory-blind arm |
| packet-intelligence | strict reference/direction/design-lock schemas; no winner before rendering; meaningful structural divergence |
| quality-adapter | authoritative tournament/certificate adapter; legacy evidence can never be a fallback from a taste failure |
| runner-wiring | automatic UI classification, mandatory current-HEAD taste gate, bounded repairs, incumbent preservation, and post-promotion memory record |
| prompt-contract | manifest-derived UI scalars survive optimization; provider syntax is native; builders cannot self-certify |
| visual-doc-contract | provider-neutral planning and prompt doctrine with explicit implementation/evidence/review ownership |
| claude-contract | concise Claude-native executable contract and truthful claim boundaries |
| codex-parity | Codex-native contract, working installed links, script parity, and clean-install execution |
| provider-hooks | fresh-install executable hooks, protocol packaging, stale-removal/rollback safety |
| capture-hardening | pinned browser/decoder identity, replayable matrices, independent decode, tamper-evident capture receipts |
| a11y-evidence | trusted per-capture/state keyboard, semantics, contrast, reflow, target, and motion evidence |
| stimulus-evidence | coordinator-owned anonymized stimuli with OCR/DOM leakage scans, sealed orientation, and escrow binding |

The integrator merges all current lane tips, reconciles schemas, creates the two
cross-module production-chain tests, attacks every trust boundary, and repairs only
on its integration branch.

## Authoritative tournament contract

- Lock one goal, brief, reference packet, three meaningfully divergent directions,
  design locks, source revision, capture plan, and tournament policy before building.
- Render all three candidates in isolated worktrees. Run deterministic task,
  accessibility, provenance, capture-matrix, pixel, OCR/DOM, and injection gates first.
- Judge exactly the three pairs (`1–2`, `1–3`, `2–3`) with pointwise-first, sealed,
  identity-hidden A/B and B/A groups. Require complete matches and a unique Condorcet
  winner; ties, cycles, quorum gaps, or ambiguous evidence yield `REPLAN`.
- Persist an append-only hash-chained event log. Reserve each repair token before work;
  at most two compatible challengers may be tried. Stale parent, lock drift, repeated
  pixels, nonmaterial change, regression, oscillation, or interrupted evidence retains
  the incumbent.
- The local tournament label is `SELECTED_NOT_CERTIFIED`. Only the later ten-or-more
  brief benchmark may emit `TASTE-CERTIFIED`; only real eligible humans may set
  `human_certified:true`.
- Atomically update the champion with compare-and-swap generation and previous pointer.
  Tournament losers never merge into the ordinary integration join.

## Receipt and security contract

- Every schema rejects unknown/duplicate keys; IDs use a strict opaque alphabet; no
  receipt value reaches `eval`, shell code, glob expansion, or executable memory.
- Artifact references are safe repository-relative regular files with no symlink
  component and a recomputed lowercase SHA-256 digest.
- The compiler verifies a transitive content-addressed chain to the exact current
  candidate revision and run. A shape-compatible receipt from another run fails.
- Human labels require externally verifiable panel provenance and principal identity;
  aliases of one principal/configuration count once. Machine judges may be
  human-calibrated but cannot mint human certification.
- The coordinator—not the builder—owns anonymization, evidence validation, judging,
  tournament selection, and promotion.

## Guardrails

- Pure Bash 3.2 + jq remains the core. Optional browser, decoder, OCR, and accessibility
  adapters are pinned and receipted; unavailable evidence is `UNKNOWN`, never PASS.
- Generic visual motifs are review signals, never proof of AI authorship or copying.
- No real human panel, deployment, publication, package install into user roots, or
  claim of global aesthetic superiority is authorized in this cycle.
- Do not mark `m32.4`, `m32.5`, or `c84`–`c90` done. The real rendered benchmark and
  fresh-provider terminal certification remain later gates.
