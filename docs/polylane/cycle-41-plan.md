# Cycle 41 plan — acquire and calibrate the real primary taste corpus

Run: `c41-source-calibration-20260812-a1`
Target: `m32.4`
Base: `codex/taste-certification` after Cycle 40's verified live-harness promotion
Mode: autonomous maximum-assurance, 15 file-isolated Claude Code builders plus one integrator

## Outcome

Turn the Cycle 40 source/calibration harness into a resumable real campaign. Acquire and
hash the frozen three-domain source metadata, ratings, and selected 252 images; build the
frozen calibration/holdout split and unambiguous mirrored pairs; execute independent
provider judge calibration; and commit only compact receipts, manifests, raw textual
responses, and audit evidence. Binary source assets remain in a content-addressed local
cache outside Git.

The integrator must run the real campaign after merging. If the source and enough judges
pass every frozen gate, it writes a production `taste-calibration/v2` panel for the next
generation cycle. If an external source/provider remains unavailable, it preserves all
verified engineering and exact receipts under `EXTERNAL-EVIDENCE-OPEN`. It may not shrink
the corpus, change thresholds, use fixtures, promote TASTE into the primary track, or
claim human certification.

## Lane carve

1. `dataverse-transport` — make Chrome readiness deterministic; implement a real
   same-session CDP/download path for redirected files; never read a personal profile.
2. `dataone-metadata` — immutable DataONE discovery/resolve adapter and strict DOI,
   licence, version, distribution, and member-node receipts.
3. `source-freeze` — reconcile Harvard + DataONE metadata into a fail-closed frozen
   source manifest; disagreement is terminal.
4. `download-campaign` — resumable, bounded-concurrency selected-file campaign with
   atomic content-addressed publication and no retry storms.
5. `cache-integrity` — cache inventory, SHA/size/checksum verification, quarantine
   reporting, and deterministic resume planning.
6. `ratings-normalize` — parse the actual raw/aggregate source schemas without lossy
   guessing; bind native-scale human labels and valid-rater support.
7. `corpus-select` — deterministic 60/24-per-domain split with no leakage, duplicates,
   missing images, weak labels, or post-result replacement.
8. `pair-builder` — deterministic unambiguous held-out mirrored pair construction,
   bootstrap interval rule, side probes, and frozen pair manifest.
9. `calibration-campaign` — execute isolated provider work units, unique sessions,
   bounded retries/abstention, and hash-bound raw response ledgers.
10. `calibration-audit` — independently recompute correctness, Wilson, side-bias,
    mirror contradictions, configuration identity, and eligibility.
11. `panel-freeze` — frozen machine-panel configuration and claim ceiling; no fabricated
    model versions, independence, or human provenance.
12. `benchmark-preflight` — one deterministic gate proving source, split, pairs, panel,
    cache, providers, and disk are ready before the expensive 20-brief generation wave.
13. `source-adversary` — attack mirror substitution, duplicate ids, checksum drift,
    traversal/symlink cache entries, partial downloads, challenge HTML, and receipt replay.
14. `source-runbook` — operator reproduction, cache location, tmux observability,
    recovery, expected duration, and honest stop conditions.
15. `source-protocol` — primary-source research update and exact certification boundary;
    reconcile implementation with the frozen protocol and authoritative citations.

The deferred `taste-calibration-integrator` merges all tips, repairs seams, runs focused
and full verification, executes a fresh real source campaign and provider calibration,
writes compact evidence under `docs/polylane/taste-certification/benchmark/`, and emits
the sole nonce-bound verdict.

## Frozen implementation contracts

- The transport waits on an observed valid Dataverse JSON envelope, not a magic sleep.
- Data-file redirects are handled by browser/CDP or a fresh ephemeral session handoff;
  user cookies and credentials are forbidden and never logged.
- Every network operation has a deadline, bounded retry class, atomic `.part` publish,
  and resumable content digest. Deterministic source errors are not retried forever.
- Metadata cross-check requires exact DOI/domain/licence/version/file identity. DataONE
  augments availability; it cannot redefine Harvard's bytes or labels.
- Selection happens before judge output. Calibration and holdout are disjoint by object
  digest and source id. A failed item is not silently replaced after results.
- Every model invocation uses the Cycle 40 isolated adapters and stores a redacted,
  hash-bound receipt. Pointwise happens before pairwise; mirrored sessions are unique.
- `human_certified` remains false throughout this cycle.

## Acceptance

Focused lane tests must be hermetic. The integrator additionally runs:

```bash
bash tests/test-taste-dataverse-transport.sh &&
bash tests/test-taste-dataone-metadata.sh &&
bash tests/test-taste-source-freeze.sh &&
bash tests/test-taste-download-campaign.sh &&
bash tests/test-taste-cache-integrity.sh &&
bash tests/test-taste-ratings-normalize.sh &&
bash tests/test-taste-corpus-select.sh &&
bash tests/test-taste-pair-builder.sh &&
bash tests/test-taste-calibration-campaign.sh &&
bash tests/test-taste-calibration-audit.sh &&
bash tests/test-taste-panel-freeze.sh &&
bash tests/test-taste-benchmark-preflight.sh &&
bash tests/test-taste-source-adversarial.sh &&
bash tests/test-taste-source-campaign-e2e.sh &&
bash tests/test-taste-source-live.sh &&
bash tests/test-taste-calibration-live.sh &&
bash tests/test-taste-live-harness-e2e.sh &&
tests/run.sh &&
shellcheck -S warning bin/*.sh codex/install.sh claude-code/install.sh &&
bin/polylane-markers.sh check-docs references/ &&
bash tests/test-skill-parity.sh &&
git diff --check
```

Production success additionally requires a non-fixture source receipt for all three
domains, exactly 180+72 selected source images, frozen pair manifests, and at least five
eligible machine judge configurations whose `taste-calibration/v2` receipts pass the
registered audit. Otherwise the correct cycle verdict is `EXTERNAL-EVIDENCE-OPEN`.

