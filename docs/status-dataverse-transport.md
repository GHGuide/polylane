STATUS: dataverse-transport DONE run=c41-source-calibration-20260812-a1

- Adapter v2: observed JSON readiness (waitForReadiness on api/info/version), no magic sleep.
- Redirected data files: same-session CDP download (Browser.setDownloadBehavior + downloadProgress).
- Failure taxonomy in every UNKNOWN receipt: challenge / timeout / redirect / transport / checksum.
- Bounded and resumable: withTimeout deadline on every live op; verified content-addressed objects resume with zero network.
- Hermetic verification: SELFTEST-OK n=20; PASS test-taste-dataverse-transport assertions=31.
- Bounded live canary: discover metadata SHA matches frozen research value; file 7228385 downloaded byte-exact (declared md5 match); resume path confirmed offline.
- No profile, cookie, credential, or session material inspected, persisted, or logged; no spoofing; challenge remains UNKNOWN.
- Evidence: docs/verify-dataverse-transport.md
