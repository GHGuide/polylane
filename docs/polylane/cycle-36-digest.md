# Cycle 36 digest — installer truth and one verdict path

Cycle 36 merges the exact nonce-matched verdict-path recovery tip. It restores
the proven staged replacement installers for Claude Code and Codex, including
legacy-package cleanup, rollback preservation, byte-identical Codex discovery
roots, and a Claude source-equals-destination install. Fresh hermetic checks pass
42/0 and 57/0.

The compiler now distinguishes builder and integrator finalization. A builder
writes its own status marker; an integrator's only current-run sentinel belongs
in `docs/verify-integration.md`, while `docs/status-integrator.md` remains
verdict-free. Fresh path, lint, provider-contract, orchestration, syntax,
ShellCheck, marker, and parity evidence is green. This is a focused recovery:
no terminal gate, promotion, cleanup, live install, or external visual evidence
was consumed.
