#!/usr/bin/env bash
# pane_stalled requires a live credits/upgrade decision, never prose alone.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

make_tmpdir
FAKE_BIN="$TEST_TMPDIR/bin"
mkdir -p "$FAKE_BIN"
cat > "$FAKE_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${PANE_TEXT:-}"
EOF
chmod +x "$FAKE_BIN/tmux"
PATH="$FAKE_BIN:$PATH"
TMUX_SESSION="pane-stalled-test"

export PANE_TEXT='Source prose says usage limit, but no action is offered.'
assert_fail "pane-stalled-prose-usage-limit-is-not-paywall" pane_stalled 0

export PANE_TEXT="printf '%s' '\\''usage limit|Switch to usage credits'"
assert_fail "pane-stalled-source-line-is-not-paywall" pane_stalled 0

export PANE_TEXT='Usage limit reached. Switch to usage credits to continue. [1] Switch [2] Cancel'
assert_ok "pane-stalled-credits-decision-is-paywall" pane_stalled 0

export PANE_TEXT='You need more capacity. Upgrade your plan. [1] Upgrade [2] Cancel'
assert_ok "pane-stalled-upgrade-decision-is-paywall" pane_stalled 0

export PANE_TEXT='Build passed: usage limit fixture mentioned in test output.'
assert_fail "pane-stalled-passing-output-is-not-paywall" pane_stalled 0

finish
