STATUS: generate-live DONE run=c40-live-harness-20260812-a3

# Lane generate-live — isolated fixed-model builder-campaign runner

## Delivered
- `bin/polylane-taste-generate.sh` — consumes one frozen
  `taste-generate-campaign/v1` manifest; per `(brief × arm)` runs a declared
  builder adapter in an isolated config+output workspace and emits
  source/build/compute receipts + a blinded `taste-candidate/v1` (the capture
  lane's seam). Idempotent resume, tamper-evident hash chain, no hidden winner.
- `tests/test-taste-generate-live.sh` — **51 pass, 0 fail**. Red-first fixture
  builders cover success, timeout, nonzero, missing files, dirty template,
  network asset, changed prompt/model, duplicate candidates, symlink/path
  escape, partial crash/resume, forged build receipt, manifest shape, and the
  fixture→production trust boundary.
- `docs/verify-generate-live.md` — replay, idempotent resume, exact receipt
  examples, safety-attack table, compute-accounting limitations, skill receipts.

## Verification
- `bash tests/test-taste-generate-live.sh` → `51 pass, 0 fail`.
- `bin/polylane-check.sh "$PWD/.polylane/check-cache/generate-live" -- shellcheck -S warning bin/polylane-taste-generate.sh tests/test-taste-generate-live.sh` → PASS.
- Implementation + evidence committed on `lane/c40-generate-live` (`6fc8ca6`).

## Contract adherence
- HARD CONTRACT: one manifest fixes run/brief/arm/direction/prompt/model/effort/
  output-root/deadline before launch; isolated config+output per candidate (no
  shared chat context); candidate source is static offline HTML/CSS/JS with no
  remote asset/font/API URL, placeholder-only screen, or hidden provenance;
  prompt/source/dependency/build hashes, CLI binary/version, timing, and
  token/usage (when builder-reported) recomputed; functional-start = required
  routes exposed. Never chooses a champion.
- EXTERNAL-EVIDENCE respected: fixture-only by default; production classification
  requires a coordinator-owned `taste-generate-allowlist/v1`. No real generation
  run yet (the 20-brief corpus is out of this lane's scope, per the launch
  contract).
- Wrote only the four OWN paths. Relay checked at start and before completion; no
  request was addressed to generate-live (the one pending request targets
  `task-live`).

## Skill receipts
- `SKILL-READ: engineering:deploy-checklist | .../deploy-checklist/SKILL.md | 85ca53dc471970e3e12c36ec814ebf5f6cb9419016c55adb05ff34789bae3be9`
- `SKILL-READ: ponytail:ponytail | .../ponytail/SKILL.md | dd240060d5734a58fe2783916a63f9401fed75c5f87742dd663a66f9ed4c8c65`
- `SKILL-READ: sites:sites-building | .../sites-building/SKILL.md | 4b4205ea86f86158e9067c7200b0c3a42dede1f2e877e016888bf2355bd2f184`
- `SKILL-EVIDENCE: engineering:deploy-checklist — helped: shaped the build receipt's functional_start (starts + exposes required routes) and the static-vs-live limitation note.`
- `SKILL-EVIDENCE: ponytail:ponytail — helped: one script, shared guards, one reused verify path; each cut corner carries a ponytail: ceiling comment.`
- `SKILL-EVIDENCE: sites:sites-building — helped: offline/self-contained/no-remote-asset ethos is the candidate-source hard rule; its Next.js build flow was unused for the runner.`
