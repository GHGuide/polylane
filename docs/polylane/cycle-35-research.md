# Cycle 35 research — installed upgrade truth

The fresh installed-path audit found a deterministic local defect after Cycle 34:
`codex/install.sh --user` updated the current package files but retained obsolete
top-level files and an old `bin/` engine in `~/.agents/skills/polylane`. The installer
claims that both Codex roots stay synchronized, so an overlay that leaves executable
legacy content is not sufficient. The existing fresh-install tests cover nesting and
entrypoint checks but do not seed a dirty legacy destination or compare complete package
inventories.

The Codex doctor result is not a source defect: without a manifest or
`POLYLANE_AGENT=codex`, the shared doctor intentionally defaults to Claude. Real Codex
manifests select Codex and are already covered by `tests/test-doctor-agent.sh`.

No external research or skill installation is needed. The repair is a local packaging
contract with hermetic upgrade fixtures.
