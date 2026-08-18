# Verify — lane generate-live (`bin/polylane-taste-generate.sh`)

Isolated fixed-model **builder-campaign runner**. One frozen manifest fixes
run / brief / arm / direction / prompt / model / effort / output-root / deadline
before launch. For every `(brief × arm)` it invokes a declared builder adapter
in an isolated config+output workspace, produces a static offline site, and
emits three tamper-evident receipts (**source / build / compute**) plus a
**blinded `taste-candidate/v1`** record consumable by the downstream capture
lane. Resume is idempotent. **No winner is ever chosen here.**

Run `run=c40-live-harness-20260812-a3`: `51 pass, 0 fail`; ShellCheck `-S warning`
clean on both owned scripts (via `bin/polylane-check.sh` cache).

---

## 1. Contract seams (consumed / produced)

- **Consumes** frozen *prompt units* — each arm names `prompt_path` +
  `prompt_sha256` (relative to the manifest dir). The runner recomputes the hash
  and **refuses** a changed prompt; it never authors briefs or prompts (those
  paths are FORBIDDEN).
- **Produces** `taste-candidate/v1` with exactly the nine keys the capture lane
  requires (`bin/polylane-visual-capture.sh` `candidate_shape`):
  `brief_sha256, build_receipt_sha256, candidate_id, created_at,
  dependency_lock_sha256, design_lock_sha256, direction_id, schema_version,
  source_revision`. `candidate_id` is `cand-<16hex>` (also satisfies the threat
  lane's `^cand-[a-z0-9]{16}$`).
- **Derivations** (all recomputed, all bound): `design_lock_sha256` = the frozen
  prompt hash; `source_revision` = the content-addressed tree hash (= 64-hex,
  satisfies the downstream git-sha shape); `build_receipt_sha256` = SHA-256 of
  the build receipt; `dependency_lock_sha256` = SHA-256 of the sorted declared
  dependency list. `brief_sha256` passes through pinned (briefs are not ours).
- **No hidden winner:** the blinded candidate carries no provider, model,
  effort, role, rank, or score. `model`/`effort` live only in the build/compute
  receipts (audit trail), never in the candidate or the site source. Winner
  resolution happens only downstream at the blinded ballot
  (`bin/polylane-taste-ballot.sh`).

---

## 2. Fake campaign replay (fixture-only)

`EXTERNAL-EVIDENCE`: a fake builder exercises the machinery but can **never**
mint a production candidate — production needs a coordinator-owned allowlist
pinning the real builder identity + model + effort. Everything below is
fixture-only.

```bash
GEN=bin/polylane-taste-generate.sh
W=$(mktemp -d); mkdir -p "$W/campaign/prompts"
sha() { shasum -a 256 "$1" | awk '{print $1}'; }
for d in base c1 c2 c3; do printf 'Build Acme storefront — %s.\n' "$d" > "$W/campaign/prompts/$d.txt"; done

# hermetic builder: a distinct static offline site per direction
cat > "$W/builder.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
out="$POLYLANE_BUILD_OUTPUT"; dir="$POLYLANE_BUILD_DIRECTION_ID"; cfg="$POLYLANE_BUILD_CONFIG"; mkdir -p "$out/about"
printf '<!doctype html><html lang=en><meta charset=utf-8><title>Acme %s</title><link rel=stylesheet href=app.css><main><p>The %s storefront: real catalog, working checkout.</p><a href="/about">About</a></main><script src=app.js></script>' "$dir" "$dir" > "$out/index.html"
printf 'body{margin:2rem;color:#1a1a2%s}\n' "${dir: -1}" > "$out/app.css"
printf 'document.title="Acme %s";\n' "$dir" > "$out/app.js"
printf '<!doctype html><title>About %s</title><h1>About</h1><p>Small team, delightful commerce.</p>' "$dir" > "$out/about/index.html"
printf '{"dependencies":[],"usage":{"tokens_input":128,"tokens_output":690,"tokens_total":818}}\n' > "$cfg/build-meta.json"
EOF
chmod +x "$W/builder.sh"

cat > "$W/campaign/campaign.json" <<J
{"schema_version":"taste-generate-campaign/v1","run_id":"demo","output_root":"$W/out","deadline_seconds":900,
 "builder":{"adapter_id":"builder-cli","adapter_version":"0.0.1","command_sha256":"$(sha "$W/builder.sh")","model":"claude-opus-4-8","effort":"xhigh"},
 "briefs":[{"brief_id":"brief-shop","brief_sha256":"$(printf shop | shasum -a 256 | awk '{print $1}')","required_routes":["/","/about"],
  "arms":[{"arm_id":"arm-base","role":"baseline","direction_id":"base","prompt_path":"prompts/base.txt","prompt_sha256":"$(sha "$W/campaign/prompts/base.txt")"},
          {"arm_id":"arm-c1","role":"current","direction_id":"c1","prompt_path":"prompts/c1.txt","prompt_sha256":"$(sha "$W/campaign/prompts/c1.txt")"},
          {"arm_id":"arm-c2","role":"current","direction_id":"c2","prompt_path":"prompts/c2.txt","prompt_sha256":"$(sha "$W/campaign/prompts/c2.txt")"},
          {"arm_id":"arm-c3","role":"current","direction_id":"c3","prompt_path":"prompts/c3.txt","prompt_sha256":"$(sha "$W/campaign/prompts/c3.txt")"}]}]}
J

$GEN run "$W/campaign/campaign.json" -- "$W/builder.sh"
# → builds 4 candidates (1 baseline + 3 current); prints "campaign complete … (no winner selected)"
$GEN verify "$W/out/brief-shop/arm-c1"        # standalone re-verification
```

Isolation: each candidate builds in its own `mktemp` workspace with `HOME`,
`XDG_CONFIG_HOME`, `XDG_CACHE_HOME`, `TMPDIR`, `CLAUDE_CONFIG_DIR` pointed at a
fresh per-candidate config dir — **no shared chat context** bleeds across
candidates. Ambient API credentials in the environment are preserved (isolation
is about conversation state, not creds). The clean tree is hashed in temp and
atomically moved into place, so no *dirty template* can contaminate a receipt.

---

## 3. Idempotent resume

`candidate.json` is written **last**, atomically, as the completion marker.
Resume calls `verify` on each existing candidate:

- **Verifies →** skipped, byte-for-byte untouched (`resume-is-byte-idempotent`).
- **Fails (partial / torn / crashed / forged) →** the dir is removed and the
  candidate is rebuilt from clean.

A mid-campaign crash (one arm exits non-zero) leaves **no** partial candidate for
the failed arm and does not touch the good arms; the campaign exits non-zero.
Re-running with a working builder fills only the missing arm and leaves the
completed ones byte-identical (`resume-after-crash-*`). Failed candidates are the
only work a resume redoes.

---

## 4. Exact receipt examples

Real output for `arm-base`, `TASTE_NOW=2026-08-12T00:00:00Z`
(`validator.fingerprint` and absolute `builder.command_path` elided; each is a
real SHA-256 / canonical path in the on-disk file).

**Blinded candidate** (`candidate.json`) — the seam; no identity, no winner:

```json
{
  "schema_version": "taste-candidate/v1",
  "candidate_id": "cand-3103f96d413a2f27",
  "brief_sha256": "e9be9dcaec372fbae339c33827ff30b2f4b9936eb7e0faee13b3fca3846b26c2",
  "design_lock_sha256": "ae6b1c7c40d89a9ab34b1b5a01166195e215f1943cb0f50bbd909742f19b663b",
  "direction_id": "base",
  "source_revision": "db0e2efcebd6da7840d5860e5d349dc868bc94bcf858fc0fd6e39aa9a2998fae",
  "dependency_lock_sha256": "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945",
  "build_receipt_sha256": "4c5942b35a2b80452230acef9b6096737f0f7c9d76ebf18c91782d16b31b5f95",
  "created_at": "2026-08-12T00:00:00Z"
}
```

**Source receipt** (`source-receipt.json`) — recomputed inventory + offline
verdict:

```json
{
  "schema_version": "taste-source-receipt/v1",
  "classification": "fixture",
  "candidate_id": "cand-3103f96d413a2f27",
  "entry": "index.html",
  "files": [
    {"path": "about/index.html", "sha256": "05be58a0…28a6", "bytes": 107},
    {"path": "app.css",          "sha256": "d4017808…b732", "bytes": 54},
    {"path": "app.js",           "sha256": "a315fbf7…bd53", "bytes": 34},
    {"path": "index.html",       "sha256": "cf66c392…e962b", "bytes": 336}
  ],
  "file_count": 4,
  "source_sha256": "db0e2efc…8fae",
  "dependencies": [],
  "dependency_lock_sha256": "4f53cda1…b945",
  "offline": true, "placeholder_free": true, "provenance_clean": true,
  "reason_codes": []
}
```

**Build receipt** (`build-receipt.json`) — builder identity + prompt binding +
functional-start result (routes exposed):

```json
{
  "schema_version": "taste-build-receipt/v1",
  "classification": "fixture",
  "candidate_id": "cand-3103f96d413a2f27",
  "role": "baseline",
  "builder": {"adapter_id": "builder-cli", "adapter_version": "0.0.1", "command_sha256": "136a7f8f…c8f8"},
  "prompt": {"path": "prompts/base.txt", "sha256": "ae6b1c7c…663b"},
  "brief_sha256": "e9be9dca…26c2",
  "model": "claude-opus-4-8", "effort": "xhigh", "exit_status": 0,
  "functional_start": {
    "started": true, "entry": "index.html", "entry_ok": true,
    "required_routes": ["/", "/about"],
    "routes": [{"route": "/", "file": "index.html"}, {"route": "/about", "file": "about/index.html"}],
    "routes_present": true
  },
  "source_sha256": "db0e2efc…8fae",
  "dependency_lock_sha256": "4f53cda1…b945",
  "source_receipt_sha256": "49099549…e473",
  "executed_at": "2026-08-12T00:00:00Z", "reason_codes": []
}
```

**Compute receipt** (`compute-receipt.json`) — CLI binary/version, timing, usage:

```json
{
  "schema_version": "taste-compute-receipt/v1",
  "classification": "fixture",
  "candidate_id": "cand-3103f96d413a2f27",
  "builder": {"command_sha256": "136a7f8f…c8f8", "version": "0.0.1"},
  "model": "claude-opus-4-8", "effort": "xhigh",
  "timing": {"started_at": "2026-08-12T00:00:00Z", "ended_at": "2026-08-12T00:00:00Z", "duration_ms": 41, "deadline_seconds": 900},
  "usage": {"tokens_input": 128, "tokens_output": 690, "tokens_total": 818},
  "usage_source": "builder-reported", "executed_at": "2026-08-12T00:00:00Z", "reason_codes": []
}
```

**Tamper-evident chain:** candidate → `build_receipt_sha256` → build receipt →
`source_receipt_sha256` → source receipt → recomputed `source_sha256` over the
live tree. `verify` recomputes every link, so editing any receipt breaks the
binding above it (see §5).

---

## 5. Safety attacks (all rejected — fail-closed)

Each row is a red-first test in `tests/test-taste-generate-live.sh`.

| Attack | Guard | Test |
|---|---|---|
| Builder exceeds deadline | portable watchdog TERM→KILL, arm fails closed | `timeout-builder-fails-closed` |
| Builder exits non-zero | non-zero → recorded failure, no candidate | `nonzero-builder-fails-campaign` |
| No entry `index.html` | required entry check | `missing-entry-index-rejected` |
| Required route not built | `resolve_route` for every `required_routes` | `missing-required-route-rejected` |
| Dirty template droppings (`node_modules/`, `.git/`) | build-tool dropping scan | `dirty-template-droppings-rejected` |
| Remote asset / font / API URL | `has_remote_reference` (offline hard rule) | `network-asset-reference-rejected` |
| `xmlns` namespace URI (not a fetch) | scan targets `src`/`href`/`url()`/`fetch` only | `namespace-uri-not-treated-as-network-asset` (passes) |
| Placeholder-only screen | visible-text length + stub-phrase scan | `placeholder-only-screen-rejected` |
| Hidden provenance (model id / generator meta) | `has_hidden_provenance` | `hidden-provenance-rejected` |
| Changed frozen prompt | recompute vs pinned `prompt_sha256` | `changed-frozen-prompt-rejected` |
| Swapped builder binary (changed model) | recompute vs pinned `command_sha256` | `changed-builder-model-sha-rejected` |
| Identical output across a brief's arms | distinct `source_revision` per brief | `duplicate-source-across-arms-rejected` |
| Symlinked output root | not-a-symlink check | `symlinked-output-root-rejected` |
| Planted in-tree symlink (path escape) | `find -type l` reject (build **and** verify) | `in-tree-symlink-escape-rejected` |
| Prompt-path traversal (`../`) | `safe_relative_regular_file` + shape | `manifest-prompt-traversal-rejected` |
| Forged build receipt body | `build_receipt_sha256` mismatch | `forged-build-receipt-breaks-candidate-binding` |
| Forged source hash (+ re-pointed candidate) | recompute source tree, mismatch | `forged-source-hash-caught-by-recompute` |
| Torn write / partial candidate | `verify` fails → rebuilt | `torn-write-fails-verify`, `…is-rebuilt-on-resume` |
| Wrong baseline/current mix, dup direction, unknown schema | `manifest_shape` | `manifest-*-rejected` |
| Fixture self-promoting to production | coordinator-owned allowlist required | `production-without-allowlist-blocked` |
| Unlisted builder posing as authorized | allowlist entry must pin path/ver/sha/model/effort | `production-unlisted-builder-blocked` |

Blinding is asserted directly: no `model`/`provider`/`winner`/`rank`/`score` in
any candidate, no winner/champion/rank file, no model id in site source
(`blinded-*`).

---

## 6. Compute-accounting limitations (honest)

- **Token/usage is builder-reported, never synthesized.** Usage appears only if
  the builder writes `build-meta.json` (`{usage:{tokens_input,tokens_output,
  tokens_total}}`) to its isolated config dir; otherwise `usage: null,
  usage_source: "unavailable"`. The runner will not fabricate token counts —
  fabricated usage would be fake evidence.
- **`duration_ms` is real wall-clock** (`epoch_ms` around the build), independent
  of `TASTE_NOW`. The `started_at`/`ended_at` timestamps are the RFC3339 clock
  and are override-frozen by `TASTE_NOW` for deterministic replay, so they can be
  equal while `duration_ms` is a true positive.
- **Functional-start is static route resolution by default** — entry present +
  each `required_route` resolves to a produced file (`/`→`index.html`,
  `/x`→`x.html`|`x/index.html`). It proves the artifact *exposes* the routes, not
  that a server serves them; a live serve+probe is intentionally out of scope for
  a deterministic offline harness (adds ports/flakiness). This is the
  deploy-checklist "expose required routes" applied to a static offline artifact.
- **URL / placeholder / provenance scans are regex heuristics, not parsers**
  (marked `ponytail:` in-code with the ceiling). They catch the fixture attacks
  above; a real builder smuggling references past them would need a full
  HTML/CSS parser to close — noted as the upgrade path.
- **Fixture ≠ production.** Every receipt is `classification: "fixture"` unless a
  coordinator-owned `taste-generate-allowlist/v1` authorizes the exact builder
  identity + model + effort. This lane cannot promote itself.

---

## 7. Reproduce the verification

```bash
bash tests/test-taste-generate-live.sh          # 51 pass, 0 fail
bin/polylane-check.sh "$PWD/.polylane/check-cache/generate-live" -- \
  shellcheck -S warning bin/polylane-taste-generate.sh tests/test-taste-generate-live.sh
```

---

## 8. Skill receipts

- `SKILL-READ: engineering:deploy-checklist | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/deploy-checklist/SKILL.md | 85ca53dc471970e3e12c36ec814ebf5f6cb9419016c55adb05ff34789bae3be9`
- `SKILL-READ: ponytail:ponytail | /Users/leonardo/.codex/plugins/cache/ponytail/ponytail/4.9.0/.openclaw/skills/ponytail/SKILL.md | dd240060d5734a58fe2783916a63f9401fed75c5f87742dd663a66f9ed4c8c65`
- `SKILL-READ: sites:sites-building | /Users/leonardo/.codex/plugins/cache/openai-bundled/sites/0.1.34/skills/sites-building/SKILL.md | 4b4205ea86f86158e9067c7200b0c3a42dede1f2e877e016888bf2355bd2f184`

- `SKILL-EVIDENCE: engineering:deploy-checklist — helped: shaped the build receipt's functional_start block ("verify it starts and exposes required routes") into a concrete per-route resolution check, and framed the static-vs-live serve limitation in §6.`
- `SKILL-EVIDENCE: ponytail:ponytail — helped: kept the runner to one script with shared guards (single safe_relative_regular_file, one verify path reused by resume and the verify subcommand) instead of a per-check framework; each cut corner carries a ponytail: ceiling comment (regex URL/placeholder scans, watchdog process-group ceiling).`
- `SKILL-EVIDENCE: sites:sites-building — helped: its offline, self-contained, no-model-authored-remote-asset ethos is exactly the candidate-source hard rule (static HTML/CSS/JS, no remote asset/font/API URL); its Next.js/vinext/Cloudflare build flow was out of scope for the runner and unused there.`
