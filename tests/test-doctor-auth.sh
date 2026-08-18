#!/usr/bin/env bash
# AUTH PREFLIGHT — an expired provider login turns every lane into an unanswerable
# "Login expired · Please run /login" pane; the wedge detector then respawns into the
# same screen until the restart cap halts the run with a misleading diagnosis
# (observed live 2026-08-18: Claude OAuth dead + codex quota exhausted at once).
# Doctor must catch it BEFORE any worktree/pane exists, with the exact remedy.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
DOC="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-doctor.sh"
. "$DOC"

make_tmpdir
BIN="$TEST_TMPDIR/bin"; mkdir -p "$BIN"

run_auth() { # AGENT -> captured rows
  R_STATUS=(); R_NAME=(); R_HINT=(); N_FAIL=0; N_WARN=0
  PATH="$BIN:$PATH" POLYLANE_AGENT="$1" check_auth
  local i out=""
  for i in "${!R_STATUS[@]}"; do out="$out${R_STATUS[$i]} ${R_NAME[$i]} ${R_HINT[$i]}"$'\n'; done
  printf '%s' "$out"
}

# --- claude: logged in -> PASS ------------------------------------------------
cat > "$BIN/claude" <<'SH'
#!/bin/sh
[ "$1 $2" = "auth status" ] && { printf '{"loggedIn": true, "authMethod": "claude.ai"}\n'; exit 0; }
exit 1
SH
chmod +x "$BIN/claude"
OUT=$(run_auth claude)
assert_contains "claude-auth-ok-pass" "PASS claude: auth" "$OUT"

# --- claude: logged out -> FAIL naming the exact remedy -----------------------
cat > "$BIN/claude" <<'SH'
#!/bin/sh
[ "$1 $2" = "auth status" ] && { printf '{"loggedIn": false, "authMethod": "none"}\n'; exit 0; }
exit 1
SH
chmod +x "$BIN/claude"
OUT=$(run_auth claude)
assert_contains "claude-auth-expired-fail" "FAIL claude: auth" "$OUT"
assert_contains "claude-auth-fail-remedy"  "/login" "$OUT"

# --- claude: CLI too old for `auth status` -> WARN, never a false FAIL --------
cat > "$BIN/claude" <<'SH'
#!/bin/sh
echo "Unknown command: auth" >&2; exit 1
SH
chmod +x "$BIN/claude"
OUT=$(run_auth claude)
assert_contains "claude-auth-unknown-warn" "WARN claude: auth" "$OUT"

# --- codex: logged in -> PASS -------------------------------------------------
cat > "$BIN/codex" <<'SH'
#!/bin/sh
[ "$1 $2" = "login status" ] && { echo "Logged in using ChatGPT"; exit 0; }
exit 1
SH
chmod +x "$BIN/codex"
OUT=$(run_auth codex)
assert_contains "codex-auth-ok-pass" "PASS codex: auth" "$OUT"

# --- codex: logged out -> FAIL with remedy ------------------------------------
cat > "$BIN/codex" <<'SH'
#!/bin/sh
[ "$1 $2" = "login status" ] && { echo "Not logged in"; exit 1; }
exit 1
SH
chmod +x "$BIN/codex"
OUT=$(run_auth codex)
assert_contains "codex-auth-expired-fail" "FAIL codex: auth" "$OUT"
assert_contains "codex-auth-fail-remedy"  "codex login" "$OUT"

# --- custom agent command -> auth is the operator's problem, no rows ----------
R_STATUS=(); N_FAIL=0; N_WARN=0
POLYLANE_AGENT_CMD="./my-agent" check_auth
assert_eq "custom-agent-cmd-skipped" "0" "${#R_STATUS[@]}"

finish
