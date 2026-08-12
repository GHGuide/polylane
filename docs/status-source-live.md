STATUS: source-live DONE run=c40-live-harness-20260812-a3

## Delivered
- bin/polylane-taste-source.sh — hermetic Bash 3.2 acquisition/split core
  (verify-cache · build · secondary · guarded canary).
- benchmarks/taste-live/tools/dataverse-acquire.mjs — explicit external Chrome/CDP
  Dataverse adapter (warms real context; WAF/missing-Chrome/network -> UNKNOWN).
- tests/test-taste-source-live.sh — red-first focused test.
- docs/verify-source-live.md — commands, contract example, negatives, source facts,
  live-canary evidence.

## Evidence
- Focused test: PASS test-taste-source-live assertions=40.
- ShellCheck -S warning: clean on owned shell (via bin/polylane-check.sh cache).
- Manifest accepted by the frozen bin/polylane-taste-corpus.sh validate (schema reuse).
- Contract bound in taste-source-acquisition/v1 receipt: dataset pid/version, licence
  (CC0-1.0) receipt, metadata/aggregate/raw SHA-256, split seed, raw-support>=5,
  reproduction command, manifest_sha256.
- Rejections proven: duplicate/missing image, raw/aggregate disagreement, <5 raw
  ratings, changed source metadata, partial cache, path escape, symlink, wrong domain
  quotas, caller-authored eligibility, primary/secondary substitution, unguarded canary.

## Live canary (real, non-fixture)
- node .../dataverse-acquire.mjs discover --pid doi:10.7910/DVN/9FKSQI ->
  {"status":"UNKNOWN","reason":"discover failed: WAF challenge (status 202)","waf":true} (exit 3).
- Real warmed Chrome reached Harvard Dataverse; Akamai returned a 202 interstitial.
- EXTERNAL-EVIDENCE-OPEN: frozen per-file digests/versions await a 200-status canary;
  no digests fabricated, no fixture PASS.

## Relay
- Start + final relay: no request addressed to source-live; durable inbox empty.

## Skill evidence
- SKILL-EVIDENCE: data:validate-data — helped: join/dedup/reasonableness checks became
  fail-closed assertions (raw↔aggregate agreement, >=5 raw support, duplicate-image, rating range).
- SKILL-EVIDENCE: deep-research — helped: provenance discipline drove receipt binding and
  the truthful live-canary provenance capture (real UNKNOWN over asserted acquisition).
- SKILL-EVIDENCE: legal:compliance-check — helped: allow-listed SPDX licence receipt gate and
  TASTE secondary-audit quarantine (no silent substitution of the CC0 primary corpus).
