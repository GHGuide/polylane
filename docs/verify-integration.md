# Cycle 40 integration verification — live taste-study harness

Run: `c40-live-harness-20260812-a3` · lane: `taste-live-integrator` ·
integrator HEAD `0d9ca25c46cfc1658428da97b882c2aa637d8028`.
Target `m32.4a` (engineering harness only; `m32.4` and any taste certificate stay
open). Baseline skill revision preserved: `0b802ad13ada13a0dc7cc702a526ed17d3348851`.

Scope executed: merge fifteen builder tips, repair the one cross-module seam that
blocked a live provider smoke, prove the frozen matrix, run the real
source/Claude/Codex/parser smokes, and emit the sole nonce-bearing verdict. No
threshold, baseline, brief, or split was changed; no `human_certified:true`; no
fixture was substituted for a blocked external dependency.

## 1. Merged tips — exact provenance

All fifteen builder branch tips are ancestors of the integrator HEAD (verified with
`git merge-base --is-ancestor`). Builders are inputs, not authorities; each tip's
diff and verify/status marker were read before use.

| # | Lane | Branch tip |
|---|------|-----------|
| 1 | source-live | `6836bea` |
| 2 | calibration-live | `320be0f` |
| 3 | judge-claude | `2cec70f` |
| 4 | judge-codex | `82ff8db` |
| 5 | judge-runner | `f98fbf6` |
| 6 | ballot-live | `96f57f9` |
| 7 | browser-live | `e70cc73` |
| 8 | decode-live | `0caf72f` |
| 9 | a11y-live | `d32ffbd` |
| 10 | task-live | `0603c44` |
| 11 | corpus-20 | `287f0f7` |
| 12 | prompts-live | `b79a8b4` |
| 13 | generate-live | `f0c2c5f` |
| 14 | study-live | `b36a27f` |
| 15 | protocol-live | `4fa6e92` |

## 2. Cross-module seam repair

### 2.1 judge-claude adapter — auth-breaking isolation replaced with `--safe-mode`

**Defect (found while running the live Claude smoke, not by a builder claim).** The
adapter isolated session state by redirecting `HOME`/`CLAUDE_CONFIG_DIR`/
`XDG_CONFIG_HOME` to a fresh empty dir. On this host (and any host whose Claude
auth lives in the macOS keychain / real config, not an `ANTHROPIC_API_KEY` env
var) that made the real CLI return `Not logged in · Please run /login` — a genuine
live receipt, but never a real judgement. The isolation broke auth for no gain.

**Repair.** Keep the caller's real `HOME` (auth resolves) and isolate via the
CLI's own `--safe-mode` (disables CLAUDE.md, skills, plugins, hooks, MCP, custom
commands/agents, auto-memory; sets `CLAUDE_CODE_SAFE_MODE=1`) plus
`--no-session-persistence`. The bounded read-only surface is unchanged:
`--print --permission-mode plan --allowedTools '' --safe-mode
--no-session-persistence --append-system-prompt <sys> -p <data>`. `ARGV_TEMPLATE`
was bumped `claude/print/json/plan/v1` → `.../plan/safe/v2` so a `request_sha256`
can never silently mean two argv shapes; the receipt `environment` block now
records `isolation_mode:"safe-mode", safe_mode:true, no_session_persistence:true,
home_overridden:false`. Secret redaction (names-only env provenance, digest-
redacted argv) is untouched.

**Regression assertions added** (`tests/test-taste-judge-claude.sh`, now
**61 pass / 0 fail**, +7): `argv-has-safe-mode`, `argv-has-no-session-persistence`,
`cli-received-safe-mode`, `home-not-overridden` (fake CLI sees the caller `HOME`),
`no-config-dir-override` (no throwaway `polylane-judge-claude` dir),
`receipt-safe-mode`, `receipt-home-not-overridden`. Post-repair
`shellcheck -S warning` on the adapter and its test is clean. No other test or
producer consumes the adapter's receipt (verified by grep), so the bump is
self-contained.

### 2.2 Seam scan

- No git conflict markers in `bin`/`tests`/`benchmarks`/`docs` (the one `====`
  hit is a decorative underline inside a data fixture, not a merge marker).
- Schema-version producer/consumer seams consistent: `taste-calibration/v2`
  (produced by `calibration-live`, consumed by the `polylane-taste.sh` certificate),
  `taste-ballot-validation/v2` (produced by `ballot-live`, consumed by the same),
  `taste-judge-response/v1` (parser + ballot).
- The study→calibration/ballot production boundary is proven by the passing e2e
  (§3): a genuine `calibration:fixture` producer receipt is rejected
  (`CALIBRATION_NOT_PRODUCTION`) and a Cycle-39 fixture ballot is rejected
  (`FIXTURE_EVIDENCE`) in the deciding roles.

## 3. Frozen test results

| Check | Result |
|---|---|
| `tests/test-taste-live-harness-e2e.sh` (cross-module seam) | **PASS** (`PASS: taste live-harness e2e`, via check-cache) |
| `tests/test-taste-judge-claude.sh` (post-repair) | **61 pass / 0 fail** |
| `shellcheck -S warning bin/*.sh codex/install.sh claude-code/install.sh` | **clean** (rc 0, 0 findings) |
| Full merged suite | **3887 pass / 0 fail / 152 files** (`FULLSUITE PASS`) |
| `git diff --check` | clean |
| stray current-run verdict sentinel in tree | none |
| `human_certified:true` claimed anywhere | none (only guard/doc text that rejects it) |

The full suite was green before the §2.1 repair. That repair changed only the
judge-claude adapter + its test; nothing else invokes the adapter and no committed
golden receipt binds its `request_sha256`, so the focused re-verification (61/0) and
the clean frozen ShellCheck leave the 3887/0 total intact.

## 4. Live-smoke evidence — real, non-fixture

All artifacts and their SHA-256 are committed under
`docs/polylane/taste-certification/live-harness/` (`SHA256SUMS.txt`). Every record
below is real; none is a fixture.

### Provider / config identity

| Component | Observed |
|---|---|
| Claude CLI | `2.1.228 (Claude Code)`, model `claude-opus-4-8`, keychain auth + `--safe-mode` |
| Codex CLI | `codex-cli 0.144.4`, model `gpt-5.6-sol`, ChatGPT auth via `CODEX_HOME=$HOME/.codex` |
| Browser | `Google Chrome 151.0.7922.137` via Playwright `1.60.0` (Node) |
| Source adapter | `benchmarks/taste-live/tools/dataverse-acquire.mjs` → warmed Chromium → Harvard Dataverse |

### 4.1 Primary-corpus canary — EXTERNAL-EVIDENCE-OPEN (WAF-blocked)

```
node benchmarks/taste-live/tools/dataverse-acquire.mjs discover \
  --pid doi:10.7910/DVN/9FKSQI --cache <scratch>
{"status":"UNKNOWN","reason":"discover failed: WAF challenge (status 202)","waf":true,...}
```

Real Chrome reached the live endpoint and received an Akamai HTTP-202 "under
attack" interstitial (independently reproduced with `curl … /api/info/version` =
202). No bytes cached, no manifest minted. Primary Dataverse source bytes and their
frozen digests stay `EXTERNAL-EVIDENCE-OPEN`; **no fixture substitution**. Receipt:
`source-canary-receipt.json` (`3aa61766…`).

### 4.2 Exploratory non-holdout image pair — real Chrome render

One brief (`freight-dispatch`, logistics, non-holdout) rendered as a baseline vs
current pair by real Google Chrome 151, native 1000×640, distinct bytes:

- `exploratory-A-baseline.png` `91ea41bde9fa…` (plain serif board)
- `exploratory-B-current.png` `12b3bf3f8fab…` (polished dark control board)

### 4.3 Claude visual-judge — real live receipt

```
POLYLANE_TASTE_JUDGE_LIVE=1 CLAUDE_BIN=$(command -v claude) \
  bin/polylane-taste-judge-claude.sh invoke --model claude-opus-4-8 \
    --system benchmarks/taste-live/prompts/judge-claude-system.md \
    --schema judge-response-schema.json --request judge-stimulus.json \
    --image exploratory-A-baseline.png --image exploratory-B-current.png \
    --out claude-live-receipt.json
```

`status:ok classification:live exit:0 duration:78s safe_mode:true stdout_parses_json:true`.
Receipt `claude-live-receipt.json` (`41bf0994…`); model judgement
`claude-judgement.json` (`e36e2ad1…`): schema `taste-judge-response/v1`, all 8
pointwise scores for both positions, 8+8 observations, `choice:"B"`
(A.color 2 vs B.color 6). The adapter recorded raw bytes only; it parsed no winner.

### 4.4 Codex visual-judge — real live record

```
CODEX_HOME=$HOME/.codex POLYLANE_JUDGE_CODEX_MODEL=gpt-5.6-sol \
POLYLANE_JUDGE_CODEX_SCHEMA=judge-response-schema.json \
POLYLANE_JUDGE_CODEX_BRIEF=judge-brief.txt \
POLYLANE_JUDGE_CODEX_RECORD=codex-live-record.json \
  bin/polylane-taste-judge-codex.sh invoke \
    exploratory-A-baseline.png exploratory-B-current.png
```

`codex-cli 0.144.4 exit:0` (first pass exposed my own malformed scratch schema —
the API's deterministic `invalid_json_schema` (missing root `type`) — which was
fixed to a valid strict JSON Schema and rerun; that schema error was **not** treated
as external evidence). Record `codex-live-record.json` (`721dfc2c…`); judgement
`codex-judgement.json` (`ec1e9960…`): schema `taste-judge-response/v1`, `choice:"B"`
(A.color 2 vs B.color 6). No winner parsed by the adapter; no secret in the record.

Provider isolation held: Codex argv carries no Claude/slash syntax; Claude argv
carries `--safe-mode`. Distinct providers, distinct processes, distinct auth.

### 4.5 Deterministic parser — pointwise before pairwise

Both real responses driven through `bin/polylane-taste-judge-parse.sh` against a
schema-valid `taste-judge-workunit/v1` manifest (`judge-workunit-manifest.json`):

| Judge | classify | pointwise sealed | pairwise sealed | derived winner |
|---|---|---|---|---|
| Claude | `vote` | 2026-08-12T20:26:29Z | 20:26:30Z | `stim-12b3bf3f8fab` (B) |
| Codex | `vote` | 2026-08-12T20:26:29Z | 20:26:30Z | `stim-12b3bf3f8fab` (B) |

Pointwise records were sealed strictly before the pairwise record (the required
ordering), each `record_sha256` recomputed, and the winner **derived from the raw
choice through the sealed display order** — never read from a caller. Both
independent providers resolved to candidate B (the current render).

### 4.6 Production ballot-v2 — correctly NOT minted

The HARD CONTRACT mints a production `taste-ballot-validation/v2` **iff all links
validate**. They do not: a production ballot requires a serving judge proven
eligible by a `taste-calibration/v2` (`classification:"production"`) receipt, which
is computed on the held-out Dataverse mirrored pairs — and that corpus is
WAF-blocked (§4.1). No production calibration ⇒ no production ballot ⇒ no live study
certificate. No ballot receipt was minted and no fixture was substituted. The
smoke proves the **harness** (render → two live providers → deterministic parse →
derived winner), not calibration or study preference.

## 5. Fixture boundary

Fixtures never cross into a deciding role: the e2e (§3) proves a real
`calibration:fixture` producer receipt and a Cycle-39 fixture ballot are both
rejected by the live study compiler; the judge adapters mint `classification:live`
only under `POLYLANE_TASTE_JUDGE_LIVE=1` with a real CLI, and every fake-CLI
receipt is `fixture_only`. The live records in §4 are the only live evidence; all
suite fixtures remain fixtures.

## 6. Remaining external work (why EXTERNAL-EVIDENCE-OPEN)

The engineering harness is complete and proven live for every locally available
provider (real Chrome render, real Claude judgement, real Codex judgement,
deterministic parse, fail-closed source canary). The single blocked dependency is
the **primary Miniukovich–Figl Harvard Dataverse corpus**: the live acquisition is
behind an Akamai WAF (HTTP 202), so real source bytes → held-out calibration →
`taste-calibration/v2` → production ballot-v2 → live study certificate all remain
externally open. Per the frozen plan a blocked corpus yields a precise external-
evidence receipt and `EXTERNAL-EVIDENCE-OPEN`, never a fixture pass. `m32.4` stays
open until a canary returns real 200-status bytes matching the plan pins and the
real study certificate passes; this cycle changes no baseline, brief, split, or
threshold.

## 7. Skill receipts

- SKILL-READ: engineering:code-review | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/code-review/SKILL.md | 936987158-4285
- SKILL-READ: engineering:testing-strategy | /Users/leonardo/.codex/plugins/cache/claude-cowork/engineering/1.2.0/skills/testing-strategy/SKILL.md | 2811424084-1279
- SKILL-READ: operations:risk-assessment | /Users/leonardo/.codex/plugins/cache/claude-cowork/operations/1.3.0/skills/risk-assessment/SKILL.md | 3889652016-1630
- SKILL-READ: ponytail:ponytail-review | /Users/leonardo/.codex/plugins/cache/ponytail/ponytail/4.9.0/.openclaw/skills/ponytail-review/SKILL.md | 3445243857-2118

- SKILL-EVIDENCE: engineering:code-review — helped: its security/trust-boundary lens drove the §2.1 finding — the adapter's config-isolation was reviewed against the actual auth path and shown to break a real live invocation while adding no isolation the `--safe-mode` flag doesn't already give; secret-redaction was re-checked (names-only env, digest-redacted argv) before accepting the repair.
- SKILL-EVIDENCE: engineering:testing-strategy — helped: its "few E2E / many focused, cover error+security boundaries" split shaped the smoke plan — one cross-module e2e plus focused adapter regressions, and the live tier run once against real CLIs with the deterministic schema/parse boundary asserted rather than trivially exercised.
- SKILL-EVIDENCE: operations:risk-assessment — helped: ranking external/cross-module failure modes put the WAF-blocked corpus and provider auth at the top; that framing is why the verdict is `EXTERNAL-EVIDENCE-OPEN` with a precise receipt instead of a forced GO or a fixture downgrade.
- SKILL-EVIDENCE: ponytail:ponytail-review — helped: kept the §2.1 repair minimal — delete the throwaway-dir machinery and lean on the CLI's own `--safe-mode` rather than adding a credential-shuttling layer; net negative lines with the same isolation guarantee, one runnable regression left behind.

## 8. Verdict

Fifteen tips merged and ancestry-verified; the one auth-breaking seam repaired and
regression-locked; frozen matrix, full suite (3887/0), ShellCheck, diff-check,
marker/parity, and seam scan green; real source canary, real Chrome render, real
Claude and Codex judgements, and the deterministic pointwise-before-pairwise parse
all recorded as non-fixture evidence. The sole open item is the WAF-blocked primary
Dataverse corpus, which by contract blocks production calibration/ballot/study and
yields external-evidence-open — never a fixture pass. The engineering harness is
proven; the real study certificate remains external.
