STATUS: capture-hardening DONE run=c39-visual-loop-20260812-a1

Lane: capture-hardening (Cycle 39). Owned + committed:
bin/polylane-visual-capture.sh, tests/test-visual-capture.sh,
docs/verify-capture-hardening.md, docs/status-capture-hardening.md.

Verification (see docs/verify-capture-hardening.md):
- bash tests/test-visual-capture.sh -> 35 pass, 0 fail (9 written RED-first)
- shellcheck -S warning bin/polylane-visual-capture.sh -> clean
- git diff --check -> clean
- independent consumer: bin/polylane-taste-pixels.sh -> VERIFIED captures=4

Delivered:
- Coordinator-owned allowlist trust boundary (env POLYLANE_CAPTURE_ALLOWLIST):
  production requires pinned canonical adapter path, version, command/profile/
  decoder SHA-256, environment, and source revision; fixture_only:false BLOCKS
  without a match (no fallback to fixture or exact-hash).
- Independent decode: pinned decoder run per screenshot, decoded pixels/dims
  bound to browser-declared RGBA + full PNG-structure walk (rejects text,
  IHDR-only, RGBA mismatch).
- Duplicate/near-duplicate: metadata-only (decoded-SHA uniqueness) and one-pixel
  (frozen >1-pixel byte threshold) evasion rejected.
- Future-dated output rejected; production rendered-state lock enforced.
- Atomic publish with brief/design/decoder/profile-chained per-capture +
  aggregate receipts and taste-capture-authorization/v1.
- capture-manifest.json schema BYTE-COMPATIBLE (pixel/a11y/stimulus unaffected).

Relays: interface note to certificate-v2 (seq20, authorization.json);
ACK to a11y-evidence (seq13, manifest unchanged). No pending work addressed to
this lane remains.

DEFERRED: certificate-v2 binding of publish/authorization.json remains a
consumer seam (relayed seq20, unconfirmed). No producer change pending.
