# Cycle 30 emergent questions

These questions are informational and do not broaden Cycle 30 or block the fresh
Cycle 31 terminal certificate.

1. Should focused-proof receipts remain process-local after Cycle 31?
   - Recommended: keep the receipt one-use and process-local; it avoids stale
     cross-run cache authority while removing only the immediate READY duplicate.
   - Alternative: persist a nonce-bound receipt with exact source and definition
     fingerprints for crash recovery.
   - Go deeper next round: fault the runner between focused proof and terminal
     eligibility, then compare rerun cost with stale-proof risk.
2. Should promotion blockers gain a structured companion artifact?
   - Recommended: keep the current bounded report reason until a real consumer
     needs aggregation; the report already preserves exact operator guidance.
   - Alternative: add one runner-owned JSON receipt containing blocker kind, safe
     path, retained branch, and base tip.
   - Go deeper next round: test filenames with control bytes, Markdown tokens, and
     maximum filesystem lengths across report and notification consumers.
3. Should evidence authority use explicit file descriptors instead of environment
   variables?
   - Recommended: retain cleared child environments because they are portable to
     Bash 3.2 and the isolation contract is now regression-tested.
   - Alternative: pass a capability file or descriptor only to the top-level
     checker.
   - Go deeper next round: model nested checker trees and interrupted atomic writes
     before increasing implementation complexity.
