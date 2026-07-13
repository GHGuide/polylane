#!/usr/bin/env bash
# polylane-claudemem.sh — the bridge to Claude Code's cross-run memory. Facts are
# written in Claude memory format (frontmatter + body), indexed once each in
# MEMORY.md, namespaced polylane-*, recall-able by query, and secrets are refused.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
CLM="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-claudemem.sh"

make_tmpdir
D="$TEST_TMPDIR/mem"

# add writes a fact file + a valid Claude-memory frontmatter
F=$("$CLM" "$D" add "test-cmd" "how to run the suite" "Run tests/run.sh from repo root." project)
assert_ok       "add-creates-file"   test -f "$F"
assert_contains "add-frontmatter"    "name: polylane-test-cmd" "$(cat "$F")"
assert_contains "add-type"           "type: project"           "$(cat "$F")"
assert_contains "add-body"           "tests/run.sh"            "$(cat "$F")"

# slug is normalized + polylane-prefixed
assert_ok "add-slug-prefixed" test -f "$D/polylane-test-cmd.md"

# indexed exactly once, even after a re-add (idempotent)
"$CLM" "$D" add "test-cmd" "updated desc" "new body" project >/dev/null
assert_eq "index-single-line" "1" "$(grep -c 'polylane-test-cmd.md' "$D/MEMORY.md")"
assert_contains "index-updated-desc" "updated desc" "$(cat "$D/MEMORY.md")"

# a second distinct fact -> two index lines
"$CLM" "$D" add "carving" "UI markup+JS in one lane" "Else the button id never lands." feedback >/dev/null
assert_eq "index-two-facts" "2" "$(grep -c '](polylane-' "$D/MEMORY.md")"

# recall matches on body text
assert_contains "recall-hit" "button id never lands" "$("$CLM" "$D" relevant "button id")"
assert_contains "recall-miss" "no matching" "$("$CLM" "$D" relevant "zzzznope")"

# list shows both
assert_contains "list-shows-cmd"     "polylane-test-cmd" "$("$CLM" "$D" list)"
assert_contains "list-shows-carving" "polylane-carving"  "$("$CLM" "$D" list)"

# secrets tripwire: refuse + non-zero, write nothing
assert_fail "secret-refused" "$CLM" "$D" add "leak" "an api_key fact" "value is sk-abcd" project
assert_ok   "secret-not-written" test '!' -f "$D/polylane-leak.md"

# unknown command errors
assert_rc "unknown-cmd-rc2" 2 "$CLM" "$D" bogus

finish
