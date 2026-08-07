STATUS: worker-continuity DONE run=prime-c11-20260807T103930Z

Persistent worker capsules, bounded resume packets, durable inbox/ack history,
and idempotent read-only relay import are implemented and locally verified.

Implementation: `3b64f89a2082d0efbc41c6839c81cc5163fe67ae`.
Verification: `bash tests/test-workers.sh` (45 pass), `bash -n`, and ShellCheck
for `bin/polylane-workers.sh` all pass.
