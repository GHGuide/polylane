STATUS: a11y-live DONE run=c40-live-harness-20260812-a3

Lane: a11y-live (Cycle 40). Pinned live accessibility runner + engine + adversarial suite.

Owned deliverables (committed b01df63):
- bin/polylane-taste-a11y-live.sh — trusted runner; pins engine, binds inputs, recomputes verdict.
- benchmarks/taste-live/tools/accessibility.mjs — pinned WCAG 2.1 AA rule engine (per-criterion, no verdict).
- tests/test-taste-a11y-live.sh — 46 assertions / 23 scenarios, browser-free.
- docs/verify-a11y-live.md — provenance, scope limits, full matrix, regression + missing-evidence proof.

Evidence:
- tests/test-taste-a11y-live.sh: 46 pass, 0 fail.
- node accessibility.mjs --selfcheck: SELFCHECK OK.
- shellcheck -S warning (runner + test): clean (rc 0).
- red-first: broken engine build -> ENGINE_FAILED; same inputs on pinned engine -> PASS.

Contract honored: engine pinned by package/version/source-hash; source revision + every DOM/action digest + capture/receipt timestamps bound; status derived only from exact rule outcomes and scripted keyboard/reflow/motion checks (no caller pass); baseline regression veto; manual exceptions require frozen id + rationale + scope + reviewer boundary + pre-study timestamp (automation never approves; drift rejected). Unavailable engine or unmeasurable rule -> UNKNOWN; manual criteria -> EXTERNAL; never PASS. Automation is scoped evidence, not accessibility proof for everyone.

Relay: no request addressed to a11y-live. Staged only owned paths; tree clean except runner-owned .polylane-prompt.txt and graphify-out.
