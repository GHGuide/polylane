STATUS: dataone-metadata DONE run=c41-source-calibration-20260812-a1

- Adapter: benchmarks/taste-live/tools/dataone-metadata.mjs (strict DataONE CN v2
  discovery/provenance for the three frozen immutable PIDs; hash-bound
  polylane.taste.dataone.v1 receipts; source_bytes_supplied always false).
- Tests: tests/test-taste-dataone-metadata.sh — hermetic, 19 checks, PASS; selftest OK.
- Live canary: e-commerce PID resolved live, mode:"live", exit 0 — DOI 10.7910/DVN/9FKSQI,
  CC0, version 4, 1074 canonical Harvard distributions, content digest equals PID hex,
  member node urn:node:HD, receipt_sha256
  8ef3310fe26a9d1a6ec6834096d6156a096824ec46e7633d759b4fd138c23b1f. Two canary runs total
  (first exposed a sysmeta-parser defect, fixed via TDD); fully disclosed in
  docs/verify-dataone-metadata.md.
- Evidence: docs/verify-dataone-metadata.md (repair reflection, frozen IDs, contract,
  test output, canary receipts, SKILL-EVIDENCE lines).
