#!/usr/bin/env bash
# doctor must check the AGENT THIS RUN USES — requiring `claude` for a codex manifest
# made doctor FAIL a healthy codex run (a gap the codex-first design doc named).
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
DOC="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-doctor.sh"
. "$DOC"

# agent_bin maps each profile to the executable that must exist
assert_eq "bin-claude" "claude" "$(agent_bin claude)"
assert_eq "bin-codex"  "codex"  "$(agent_bin codex)"
assert_eq "bin-gpt"    "codex"  "$(agent_bin gpt)"
assert_eq "bin-aider"  "aider"  "$(agent_bin aider)"
assert_eq "bin-default" "claude" "$(agent_bin '')"

command -v jq >/dev/null 2>&1 || { pass "doctor-agent-skipped-no-jq"; finish; exit 0; }
make_tmpdir

# doctor_agent resolves from the manifest
printf '{"agent":"codex","lanes":[]}\n' > "$TEST_TMPDIR/codex.json"
MANIFEST="$TEST_TMPDIR/codex.json" assert_eq "agent-from-manifest" "codex" "$(MANIFEST="$TEST_TMPDIR/codex.json" doctor_agent)"
# absent agent field -> claude (documented default)
printf '{"lanes":[]}\n' > "$TEST_TMPDIR/bare.json"
assert_eq "agent-default-claude" "claude" "$(MANIFEST="$TEST_TMPDIR/bare.json" doctor_agent)"
# env overrides the manifest
assert_eq "agent-env-overrides" "aider" "$(POLYLANE_AGENT=aider MANIFEST="$TEST_TMPDIR/codex.json" doctor_agent)"

finish
