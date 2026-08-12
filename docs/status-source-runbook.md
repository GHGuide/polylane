STATUS: source-runbook DONE run=c41-source-calibration-20260812-a1

Deliverables committed:
- docs/polylane/taste-certification/SOURCE-RUNBOOK.md — operator runbook for the
  m32.4 source/calibration campaign: prerequisites, exact cache boundary
  (CACHE_DIR/objects/<2-hex>/<sha256>, binaries never in Git), disk estimate
  method, discover/freeze/download/verify/select/pair/calibrate/audit/preflight
  commands with REAL vs PLANNED vs EXTERNAL labels, tmux observation, receipt
  schemas, resumability, interruption recovery, challenge/CAPTCHA rule (UNKNOWN,
  never bypass), provider-failure policy, expected long phases, security
  boundaries, honest labels. No success promises; no credential copying;
  human_certified stays false throughout.
- docs/verify-source-runbook.md — executed verification: 16/16 REAL paths exist,
  11/11 PLANNED paths absent, usage lines and adapter --selftest exercised,
  hermetic tests test-taste-source-live.sh and test-taste-calibration-live.sh
  PASS via the check cache, stale-claim greps clean, frozen constants match
  code and research lock. Skill receipts and SKILL-EVIDENCE included.

Evidence class: all verification is local/hermetic; external campaign phases
remain EXTERNAL-EVIDENCE-OPEN as required. Relay and inbox empty at start and
finalize; no cross-lane requests handled.
