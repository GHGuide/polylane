#!/usr/bin/env bash
# polylane-models.sh — print available model ids, one per line. Exercised as a
# CLI (it runs on invocation), asserting output + exit codes. bash-3.2 safe.
#
# The probe branch (curl+jq → Anthropic /v1/models) is covered with a mock `curl`
# on PATH and the machine's real `jq`; it is skip-passed when jq is unavailable.
# The codex branch is covered against the REAL cache shape: launchable ids live
# in .models[].slug while .id holds unrelated strings ("priority") — reading .id
# was exactly the fixture-drift bug that pinned every codex run to one model.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
MODELS="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-models.sh"

# --- help / usage contract ---------------------------------------------------
OUT_HELP=$("$MODELS" --help 2>&1)

assert_rc       "models-help-h-rc0"        0 "$MODELS" -h
assert_rc       "models-help-long-rc0"     0 "$MODELS" --help
assert_contains "models-help-usage-section" "USAGE:"                          "$OUT_HELP"
assert_contains "models-help-purpose"       "print available Claude model ids" "$OUT_HELP"

# --- fallback list (no key → curated ids, exit 0) ----------------------------
# stdout carries ONLY model ids (manifest generators consume it); the curated
# marker goes to stderr so automation can tell a probe from a guess.
OUT_FB=$(env -u ANTHROPIC_API_KEY "$MODELS" 2>/dev/null)
ERR_FB=$(env -u ANTHROPIC_API_KEY "$MODELS" 2>&1 >/dev/null)

assert_rc       "models-fallback-rc0"        0 env -u ANTHROPIC_API_KEY "$MODELS"
assert_eq       "models-fallback-line-count" "5"               "$(printf '%s\n' "$OUT_FB" | grep -c .)"
assert_eq       "models-fallback-first-fable" "claude-fable-5" "$(printf '%s\n' "$OUT_FB" | head -n1)"
assert_contains "models-fallback-has-opus5"  "claude-opus-5"   "$OUT_FB"
assert_contains "models-fallback-has-opus48" "claude-opus-4-8" "$OUT_FB"
assert_contains "models-fallback-has-sonnet" "claude-sonnet-5"  "$OUT_FB"
assert_contains "models-fallback-has-haiku"  "claude-haiku-4-5" "$OUT_FB"
assert_contains "models-fallback-marker"     "MODELS-FALLBACK"  "$ERR_FB"

# Unknown args carry no strict validation — best-effort, still exits 0.
assert_rc       "models-unknown-arg-rc0"     0 env -u ANTHROPIC_API_KEY "$MODELS" bogus-arg

# --- Codex mode: REAL cache shape (.models[].slug; .id is noise) -------------
make_tmpdir
CODEX_FIXTURE="$TEST_TMPDIR/codex-home"
mkdir -p "$CODEX_FIXTURE"
cat > "$CODEX_FIXTURE/models_cache.json" <<'EOF2'
{"client_version":"0.99.0","etag":"x","fetched_at":"2026-08-18T12:49:11Z","models":[
 {"slug":"gpt-5.6-sol","id":"priority"},
 {"slug":"gpt-5.6-terra","id":"priority"},
 {"slug":"codex-auto-review","id":"priority"},
 {"slug":"claude-sonnet-5","id":"priority"},
 {"slug":"gpt-5.6-terra","id":"priority"}]}
EOF2

OUT_CODEX=$(CODEX_HOME="$CODEX_FIXTURE" "$MODELS" codex 2>/dev/null)
assert_eq       "models-codex-slug-first"   "gpt-5.6-sol"       "$(printf '%s\n' "$OUT_CODEX" | head -n1)"
assert_contains "models-codex-slug-second"  "gpt-5.6-terra"     "$OUT_CODEX"
assert_contains "models-codex-codex-family" "codex-auto-review" "$OUT_CODEX"
assert_eq       "models-codex-dedupes"      "3"                 "$(printf '%s\n' "$OUT_CODEX" | grep -c .)"
case "$OUT_CODEX" in
  *claude-*) fail "models-codex-cache-excludes-claude" "output=$OUT_CODEX" ;;
  *) pass "models-codex-cache-excludes-claude" ;;
esac
case "$OUT_CODEX" in
  *priority*) fail "models-codex-ignores-id-noise" "output=$OUT_CODEX" ;;
  *) pass "models-codex-ignores-id-noise" ;;
esac

# legacy caches that DID store launchable ids under .id keep working
cat > "$CODEX_FIXTURE/models_cache.json" <<'EOF2'
{"models":[{"id":"gpt-5.6-terra"},{"id":"gpt-5.5-mini"}]}
EOF2
OUT_LEGACY=$(CODEX_HOME="$CODEX_FIXTURE" "$MODELS" codex 2>/dev/null)
assert_eq       "models-codex-legacy-id-first" "gpt-5.6-terra" "$(printf '%s\n' "$OUT_LEGACY" | head -n1)"
assert_contains "models-codex-legacy-id-second" "gpt-5.5-mini" "$OUT_LEGACY"

# explicit cache-path override beats CODEX_HOME (hermetic callers need this)
ALT="$TEST_TMPDIR/alt-cache.json"
printf '%s\n' '{"models":[{"slug":"gpt-9.9-test"}]}' > "$ALT"
OUT_OVERRIDE=$(CODEX_HOME="$CODEX_FIXTURE" POLYLANE_CODEX_MODELS_CACHE="$ALT" "$MODELS" codex 2>/dev/null)
assert_eq "models-codex-cache-override" "gpt-9.9-test" "$OUT_OVERRIDE"

# stale cache (mtime older than POLYLANE_MODELS_MAX_AGE_DAYS) warns on stderr
# but still prints the ids — a warning must never blank a working model list.
touch -t 202501010000 "$ALT"
OUT_STALE=$(POLYLANE_CODEX_MODELS_CACHE="$ALT" "$MODELS" codex 2>/dev/null)
ERR_STALE=$(POLYLANE_CODEX_MODELS_CACHE="$ALT" "$MODELS" codex 2>&1 >/dev/null)
assert_eq       "models-codex-stale-still-lists" "gpt-9.9-test" "$OUT_STALE"
assert_contains "models-codex-stale-warns"       "MODELS-STALE" "$ERR_STALE"
ERR_FRESH=$(POLYLANE_CODEX_MODELS_CACHE="$ALT" POLYLANE_MODELS_MAX_AGE_DAYS=99999 "$MODELS" codex 2>&1 >/dev/null)
case "$ERR_FRESH" in
  *MODELS-STALE*) fail "models-codex-age-env-respected" "stderr=$ERR_FRESH" ;;
  *) pass "models-codex-age-env-respected" ;;
esac

EMPTY_CODEX_HOME="$TEST_TMPDIR/no-codex-cache"
OUT_CODEX_FALLBACK=$(CODEX_HOME="$EMPTY_CODEX_HOME" "$MODELS" codex 2>/dev/null)
assert_eq "models-codex-current-fallback" "gpt-5.6-terra" "$OUT_CODEX_FALLBACK"

# The resolver's published Codex family is ordered, not a Claude alias.
OUT_CODEX_TIERS=$(CODEX_HOME="$EMPTY_CODEX_HOME" "$MODELS" codex --tiers 2>&1)
assert_eq "models-codex-tier-order" $'gpt-5.6-luna\ngpt-5.6-terra\ngpt-5.6-sol' "$OUT_CODEX_TIERS"

# --- probe branch (mock curl + real jq) --------------------------------------
if ! command -v jq >/dev/null 2>&1; then
  pass "models-probe-skipped-no-jq"
  finish
  exit 0
fi

make_tmpdir
OKDIR="$TEST_TMPDIR/ok"
FAILDIR="$TEST_TMPDIR/fail"
mkdir -p "$OKDIR" "$FAILDIR"

cat > "$OKDIR/curl" <<'EOF2'
#!/usr/bin/env bash
printf '%s' '{"data":[{"id":"claude-probe-alpha"},{"id":"claude-probe-beta"}]}'
EOF2
chmod +x "$OKDIR/curl"

cat > "$FAILDIR/curl" <<'EOF2'
#!/usr/bin/env bash
exit 22
EOF2
chmod +x "$FAILDIR/curl"

OUT_OK=$(PATH="$OKDIR:$PATH" ANTHROPIC_API_KEY=fake-key "$MODELS" 2>&1)
assert_eq       "models-probe-first-api-id"  "claude-probe-alpha" "$(printf '%s\n' "$OUT_OK" | head -n1)"
assert_contains "models-probe-second-api-id" "claude-probe-beta"  "$OUT_OK"
assert_rc       "models-probe-success-rc0"   0 env "PATH=$OKDIR:$PATH" ANTHROPIC_API_KEY=fake-key "$MODELS"

OUT_FAIL=$(PATH="$FAILDIR:$PATH" ANTHROPIC_API_KEY=fake-key "$MODELS" 2>/dev/null)
assert_contains "models-probe-httpfail-fallback" "claude-opus-5" "$OUT_FAIL"
assert_rc       "models-probe-httpfail-rc0"  0 env "PATH=$FAILDIR:$PATH" ANTHROPIC_API_KEY=fake-key "$MODELS"

finish
