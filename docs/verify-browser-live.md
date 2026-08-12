# Verify — browser-live (Cycle 40, run c40-live-harness-20260812-a3)

Lane owns: `bin/polylane-taste-browser.sh`,
`benchmarks/taste-live/tools/browser-capture.mjs`,
`tests/test-taste-browser-live.sh`, `docs/verify-browser-live.md`,
`docs/status-browser-live.md`.

Goal: a real Chrome/Playwright capture adapter plus a fail-closed Bash wrapper
that execute a **frozen offline** route/state/action matrix and emit complete
browser provenance — screenshot PNG, serialized DOM, replayable action trace,
console + network logs, output hashes, and a live dependency receipt.

This lane **grades nothing**: no pixel decode, no taste. It renders and hashes;
the decoder/pixels lane consumes the PNGs downstream (its `taste-capture-manifest/v1`
+ `taste-adapter-receipt/v1` are a separate contract). Decoder, task, and
accessibility adapters are separate lanes; this lane touches none of them.

## Commands and outputs

- `bash tests/test-taste-browser-live.sh` → **`39 pass, 0 fail`** (5:11 wall,
  real Chrome). 27 hermetic fail-closed assertions + **12 live real-browser**
  assertions (`PASS live-*`).
- `bin/polylane-check.sh .../check-cache/browser-live -- shellcheck -S warning
  bin/polylane-taste-browser.sh tests/test-taste-browser-live.sh` → **PASS**
  (ShellCheck 0.11.0, `-S warning`, clean).
- `node --check benchmarks/taste-live/tools/browser-capture.mjs` → **OK**.
- `git diff --check` (owned files) → **clean**.

## Live dependency receipt (EXTERNAL-EVIDENCE — real, not faked)

A standalone production capture against the real toolchain emitted
`dependency-receipt.json`:

| Dependency | Declared / observed |
|---|---|
| Chrome | `Google Chrome 151.0.7922.137` (prefix-pinned `Google Chrome `), sha256 `6c7eafce…18c9` |
| Playwright | module `playwright` **1.60.0** at `/Users/leonardo/node_modules/playwright` |
| Node | `v22.19.0` |
| Adapter | `browser-capture.mjs` sha256 `08b19680…8f36` (plan-pinned `command_sha256`) |
| Environment | `color_scheme=light, dpr=1, locale=en-US, timezone=UTC` |
| Source revision | `8925996b…` (from candidate; freshness lower bound) |

The wrapper refuses to run unless all four are real: the Chrome binary exists,
is executable, non-symlink, and self-reports a version matching the pinned
prefix; the Playwright module resolves and its version equals the pinned value;
Node reports a version; and the adapter's SHA-256 equals the plan's
`command_sha256`.

## Live production-capture matrix (real Chrome render)

One route (`/app.html`) × two states (`default`, `filled`) × two viewports,
rendered by real Chromium and **independently decoded with `sips`** (a decoder
outside this lane) — proving native-size, real pixels, not resized/source assets:

| capture | viewport | dims (sips) | state | png sha256 (head) |
|---|---|---|---|---|
| cap-001 | desktop | **1440×900** | default | `ab1892d51996…` |
| cap-002 | mobile  | **390×844**  | default | `ffc0e50a4cd3…` |
| cap-003 | desktop | **1440×900** | filled  | `b6ad3293257d…` |
| cap-004 | mobile  | **390×844**  | filled  | `86fc6d7bc5b2…` |

- 4/4 screenshot hashes **distinct** (`unique == length`) — no duplicate render.
- `filled` action trace is replayable: `navigate → fill → click → settle`.
- Every capture: `console_error_count=0`, `network_error_count=0`,
  `blocked_nonloopback_count=0` (clean, fully offline).
- `authorization.json` is `fixture_only: true` — the lane authorizes nothing
  beyond a local fixture render.

## HARD CONTRACT — clause-by-clause enforcement

- **Fixed browser identity** — `executable_path`, `expected_version_prefix`,
  `playwright_module`, `playwright_version`, adapter `command_sha256`, and
  `profile_sha256` are all plan-pinned and checked before any launch.
- **Frozen profile** — the wrapper derives the canonical profile
  (`chromium/headless/dpr=1/locale/timezone/color_scheme/reduced_motion/per-capture-css-px`)
  and requires the plan's `profile_sha256` to equal it; then requires the
  **adapter's** echoed profile (`jq -Sc`) to hash to the same value per capture.
  Drift on either side fails closed (`rejects-profile-sha-drift`).
- **Viewports** — desktop `1440×900` and mobile `390×844` are hard-coded in the
  matrix loop; the adapter's declared dims must match, and the PNG's real IHDR
  dims (walked in `png_structure`) must equal the viewport
  (`rejects-wrong-viewport`, `live-desktop-png-is-1440x900`).
- **Deterministic settle** — no wall-clock sleeps: the adapter disables
  animation/transition/caret, awaits `document.fonts.ready`, then two rAFs. The
  action trace records a `settle` step; the wrapper requires it plus `navigate`.
- **Offline after bootstrap** — the adapter `context.route('**/*')` continues
  only loopback (`127.0.0.1`/`localhost`/`::1`) plus `data:`/`about:`/`blob:`,
  and **aborts + records** everything else. The wrapper recomputes
  `blocked_nonloopback_count` from the network log, rejects a lying count, and
  fails if it is non-zero — reported **before** console errors (an aborted
  egress also surfaces as a console error; the block is the headline gate). Live
  proof: `live-blocks-nonloopback-fetch` with a page that `fetch()`es
  `example.com`.
- **Complete provenance** — screenshot, DOM, action trace, console, network
  are all written, path-checked (single-segment, non-symlink, mutually
  distinct), and SHA-256'd into `capture-manifest.json`; the dependency receipt
  and authorization are emitted alongside.
- **Anti-forgery** — every count the adapter declares is **recomputed** by the
  wrapper from the raw logs and rejected on mismatch
  (`rejects-console-error-count-mismatch`); artifacts may not be aliased
  (`rejects-aliased-artifacts`) or point at `result.json`
  (`rejects-fabricated-artifact`); a text file masquerading as a PNG is rejected
  by the full chunk walk (`rejects-non-png-screenshot`).
- **No stale / no caller success on partial** — `captured_at` must be
  `>= candidate.created_at` and `<= now` (`rejects-stale-source`,
  `rejects-future-dated`); the whole run is staged in an atomic temp dir and
  only `mv`'d into place after the **entire** matrix passes, with rollback of
  any pre-existing output (`rejects-partial-matrix`,
  `partial-preserves-existing-output`).
- **No symlinks** — plan, output dir, adapter, Chrome binary, and every artifact
  are `[ ! -L ]`-checked (`rejects-symlinked-plan`, `rejects-symlinked-output`).

## Failure-injection matrix (all reject; each is an assertion)

Hermetic (bash+`sips` FAKE adapter, wrapper logic under test): wrong viewport,
wrong route, wrong state, stale source, future-dated, aliased artifacts,
fabricated artifact, non-PNG screenshot, console-error-count mismatch, non-zero
console errors, non-loopback network, partial matrix (+ rollback), symlinked
plan, symlinked output, adapter-SHA drift, missing Chrome, missing Playwright,
profile-SHA drift.

Live (REAL `.mjs` adapter, real Chrome): completes the desktop/mobile/state/
action matrix; blocks a non-loopback `fetch`; rejects a console-error page; rejects
an uncaught page error (crash); rejects a missing route (404); times out on a hung
page (`while(true){}`, 4s nav budget). Dependency receipt verified real.

## Availability behavior

On a host without Chrome or a resolvable Playwright module the suite records one
honest skip (`browser-live-skipped-missing-chrome-or-playwright`) and stays green
— live evidence is produced only where the real dependencies exist (here they do,
so all 12 `live-*` ran). This run was on a host with both present.

## Relay

Start and pre-completion relays run
`bin/polylane-coordinate.sh pending "$POLYLANE_COORDINATION_FILE"`. No request was
addressed to `browser-live`; adjacent lanes' interfaces (task op allowlist, judge
receipt-only adapter, prompts spec) were noted but require no browser-live action.
This lane exposes its capture provenance (`taste-browser-live-manifest/v1` +
`dependency-receipt.json`) for the decoder/pixels lane to consume; it never
decodes or grades.

## SKILL-EVIDENCE

- SKILL-READ: engineering:debug | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/debug/SKILL.md | 303222582-4074
- SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279

- SKILL-EVIDENCE: engineering:debug — helped: applied its reproduce→isolate→
  root-cause frame to confirm each of the five live failure injections
  (phone-home, console-error, uncaught crash, 404, hung page) reproduces
  deterministically against a local fixture page and fails at the intended
  boundary — not a downstream symptom. Concretely it validated the contract
  ordering that a page which both phones home **and** errors is rejected on the
  non-loopback **block** first (headline gate), with the console error as the
  secondary signal, rather than fixing the symptom the caller happens to see.
- SKILL-EVIDENCE: engineering:testing-strategy — helped: its pyramid + "cover
  error handling, edge cases, security boundaries; frontend = interaction/
  viewport/offline" guidance maps 1:1 onto the two-adapter design — a many/fast
  hermetic FAKE adapter for the fail-closed unit matrix, and a few/slow/high-
  confidence REAL `.mjs` adapter for the live integration matrix. It flagged that
  a hermetic-only suite cannot prove real offline enforcement, which is why the
  live `live-blocks-nonloopback-fetch` case exercises real Chromium request
  interception rather than a simulated count.
