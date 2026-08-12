STATUS: provider-hooks DONE run=c39-visual-loop-20260812-a1

Fresh-install executable hooks, authoritative taste-protocol packaging, and
stale-removal/rollback safety landed and verified.

- Hook fragments no longer assume `<target>/bin/polylane-hooks.sh`. A single
  self-locating helper (`polylane-hooks.sh locate`) plus a project-scoped
  renderer (`render claude|codex`) resolve the actual installed helper by
  absolute path with sha256 provenance; guarded fail-safe execs no-op when the
  helper is absent. Provider output schemas unchanged; Stop still blocks only on
  current run/lane evidence and avoids recursion.
- Claude installer packages `docs/polylane/taste-certification/PROTOCOL.md` into
  `references/taste-certification-protocol.md` with a checksum/provenance
  sidecar, asserts all visual/taste helpers executable, and cleans staging on
  build failure (atomic swap + rollback + source==dest reinstall retained).
- VERIFY (all green): tests/test-hooks.sh (53/0), tests/test-installers.sh (80/0),
  tests/test-install-fresh.sh (63/0), `shellcheck -S warning` on
  bin/polylane-hooks.sh + claude-code/install.sh clean, `git diff --check` clean.
- Evidence + SKILL receipts: docs/verify-provider-hooks.md.
- DEFERRED: Codex install parity (protocol packaging + helper asserts + staging
  cleanup) relayed to codex-parity (seq 9); legacy assets/settings-hook-snippet.json
  relayed to integrator (seq 10). Both outside this lane's write boundary.
