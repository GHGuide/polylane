#!/usr/bin/env bash
# polylane-models.sh — print available Claude model ids, one per line. Exercised
# as a CLI (it runs on invocation), asserting output + exit codes. bash-3.2 safe.
#
# The probe branch (curl+jq → Anthropic /v1/models) is covered with a mock `curl`
# on PATH and the machine's real `jq`; it is skip-passed when jq is unavailable.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
MODELS="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-models.sh"

# --- help / usage contract ---------------------------------------------------
OUT_HELP=$("$MODELS" --help 2>&1)

assert_rc       "models-help-h-rc0"        0 "$MODELS" -h
assert_rc       "models-help-long-rc0"     0 "$MODELS" --help
assert_contains "models-help-usage-section" "USAGE:"                          "$OUT_HELP"
assert_contains "models-help-purpose"       "print available Claude model ids" "$OUT_HELP"

# --- fallback list (no key → curated ids, exit 0) ----------------------------
# Force the fallback branch by clearing ANTHROPIC_API_KEY so no network is hit.
OUT_FB=$(env -u ANTHROPIC_API_KEY "$MODELS" 2>&1)

assert_rc       "models-fallback-rc0"        0 env -u ANTHROPIC_API_KEY "$MODELS"
assert_eq       "models-fallback-line-count" "4"               "$(printf '%s\n' "$OUT_FB" | grep -c .)"
assert_eq       "models-fallback-first-fable" "claude-fable-5" "$(printf '%s\n' "$OUT_FB" | head -n1)"
assert_contains "models-fallback-has-opus"   "claude-opus-4-8"  "$OUT_FB"
assert_contains "models-fallback-has-sonnet" "claude-sonnet-5"  "$OUT_FB"
assert_contains "models-fallback-has-haiku"  "claude-haiku-4-5" "$OUT_FB"

# Unknown args carry no strict validation — best-effort, still exits 0.
assert_rc       "models-unknown-arg-rc0"     0 env -u ANTHROPIC_API_KEY "$MODELS" bogus-arg

# --- probe branch (mock curl + real jq) --------------------------------------
# The script only reaches the probe when both curl and jq exist; we shadow curl
# with a mock but need real jq to parse the JSON, so skip-pass when jq is absent.
if ! command -v jq >/dev/null 2>&1; then
  pass "models-probe-skipped-no-jq"
  finish
  exit 0
fi

make_tmpdir
OKDIR="$TEST_TMPDIR/ok"
FAILDIR="$TEST_TMPDIR/fail"
mkdir -p "$OKDIR" "$FAILDIR"

# mock curl (success): ignore args, emit a valid /v1/models JSON body
cat > "$OKDIR/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s' '{"data":[{"id":"claude-probe-alpha"},{"id":"claude-probe-beta"}]}'
EOF
chmod +x "$OKDIR/curl"

# mock curl (failure): exit non-zero like --fail on an HTTP error, print nothing
cat > "$FAILDIR/curl" <<'EOF'
#!/usr/bin/env bash
exit 22
EOF
chmod +x "$FAILDIR/curl"

# probe success → prints the API ids (not the fallback), in order, exit 0
OUT_OK=$(PATH="$OKDIR:$PATH" ANTHROPIC_API_KEY=fake-key "$MODELS" 2>&1)
assert_eq       "models-probe-first-api-id"  "claude-probe-alpha" "$(printf '%s\n' "$OUT_OK" | head -n1)"
assert_contains "models-probe-second-api-id" "claude-probe-beta"  "$OUT_OK"
assert_rc       "models-probe-success-rc0"   0 env "PATH=$OKDIR:$PATH" ANTHROPIC_API_KEY=fake-key "$MODELS"

# probe HTTP failure → curated fallback, exit 0
OUT_FAIL=$(PATH="$FAILDIR:$PATH" ANTHROPIC_API_KEY=fake-key "$MODELS" 2>&1)
assert_contains "models-probe-httpfail-fallback" "claude-opus-4-8" "$OUT_FAIL"
assert_rc       "models-probe-httpfail-rc0"  0 env "PATH=$FAILDIR:$PATH" ANTHROPIC_API_KEY=fake-key "$MODELS"

finish
