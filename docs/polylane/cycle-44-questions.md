# Cycle 44 emergent questions

No user decision is required before cycle 45.

1. Which cycle owns flipping `implementation_defect_registry` statuses from
   OPEN to FIXED, and what re-certifies the lock afterwards — a fresh
   `freeze_sha256` plus a full terminal gate, or a narrower re-attestation?
2. The five controls are now enforced in code but the registry still advertises
   them as OPEN. Does a consumer reading the registry (rather than the code)
   risk treating repaired evidence as blocked?
3. Should the frozen acceptance for a control-implementation cycle also assert
   the *absence* of the defect's failure mode end to end (an integration-level
   negative test), rather than only the unit-level control?
