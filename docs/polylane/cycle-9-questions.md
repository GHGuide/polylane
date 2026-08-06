# Cycle 9 questions — autonomous defaults

The user explicitly requested implementation of all eight proposed improvements, so no core
scope question remains. Polylane autonomous mode took these recommended defaults:

- **Intensity:** `performance`; builders use `gpt-5.6-terra` at high effort and the sole
  integrator uses `gpt-5.6-sol` at xhigh effort.
- **Benchmark:** ship a small versioned cross-product corpus and a mock adapter now; preserve a
  real Codex adapter seam for release canaries instead of spending four uncontrolled app builds
  before the harness is testable.
- **Discovery:** persist a typed question/answer graph; the model still writes creative options,
  while the helper enforces deep/bold branching, contradictions, and resumability.
- **Worker profile:** lean Codex workers default to explicit, ephemeral, user-config-free startup;
  the manifest can opt back into normal user configuration when a project genuinely needs it.
- **Quality:** three independent manifest-defined judges are required for the new quality route;
  deterministic commands are the default, model judges remain opt-in.
- **Advanced helpers:** risk/seam/outcome hooks run mechanically; champion selection and salvage
  run only when their explicit manifest contracts are present because they add spend or require a
  project-specific verifier.
- **Skill kits:** smallest useful installed kit wins; GitHub search was attempted for all four
  lane activities but was unavailable, so no unreviewed candidate enters a prompt.
- **Control room:** text and JSON are two renderings of the same canonical one-shot snapshot.

No relevant product-idea question emerged before building: the current work is infrastructure
needed to measure future creative improvements, so inventing a new product direction would be
scope drift.
