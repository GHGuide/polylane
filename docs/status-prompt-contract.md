STATUS: prompt-contract DONE run=c39-visual-loop-20260812-a1

Manifest-derived UI prompt scalars (UI-CONTRACT, UI-IMPLEMENT, UI-CONTENT,
UI-EVIDENCE, UI-REVIEW-BOUNDARY) are now exact-once frozen scalars in the prompt
compiler and linter: they survive optimization, lose the frozen-contract
comparison if stripped or weakened, and cannot be duplicated or self-certified.
Provider syntax leakage (Claude idioms in Codex prompts, Codex launch syntax in
Claude prompts) is rejected; UI classification and agent come only from the
manifest (surface:"ui" + versioned ui_contract). Non-UI prompts stay backward
compatible.

Verification: tests/test-prompt-compiler.sh 36/0, tests/test-promptlint.sh 54/0,
shellcheck -S warning clean, git diff --check clean. Evidence and frozen-scalar
list in docs/verify-prompt-contract.md. Relay seq3 (runner-wiring) answered:
version is the ui_contract=v<n> token on UI-CONTRACT, also via
`polylane-promptopt.sh ui-version`.
