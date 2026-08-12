STATUS: browser-live DONE run=c40-live-harness-20260812-a3

Implementation: `4068823` (`feat(browser-live): fail-closed Chrome/Playwright live capture harness`).

Real chromium-via-Playwright capture adapter (`benchmarks/taste-live/tools/browser-capture.mjs`) and fail-closed Bash wrapper (`bin/polylane-taste-browser.sh`) execute a frozen offline route/state/action matrix at desktop (1440x900) and mobile (390x844) and emit complete provenance — screenshot PNG, DOM, replayable action trace, console + network logs, output hashes, live dependency receipt — while grading no pixels or taste.

Verified: `tests/test-taste-browser-live.sh` → 39 pass, 0 fail (27 hermetic fail-closed + 12 live real-Chrome injections); ShellCheck `-S warning` clean (both scripts); `node --check` OK; `git diff --check` clean. Live receipt: Chrome 151.0.7922.137 + Playwright 1.60.0 + Node v22.19.0; four native-size distinct PNGs independently `sips`-decoded, all captures clean/offline. Evidence in `docs/verify-browser-live.md`.

Relay: no request addressed to `browser-live`.
