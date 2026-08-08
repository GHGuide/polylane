STATUS: skill-intelligence DONE run=c13-perfection-20260808

Implemented m13.2 in the owned lane files.

- `polylane-skill-catalog.sh` creates a deterministic trusted-root/plugin-cache
  metadata index and produces 1–3 explainable evidence-ranked candidates.
- `polylane-scout.sh` exposes catalog index, recommendation, and use-audit
  commands while retaining existing v2 kit behavior.
- Acquisition requires explicit authorization and records pin, hashes, and
  rollback readiness in the project lock.
- Verify-file evidence is mechanically recorded; omitted records become
  `unused` outcomes.

Focused verification and RED/GREEN evidence: `docs/verify-skill-intelligence.md`.
