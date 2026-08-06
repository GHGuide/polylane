#!/usr/bin/env bash
# Outcome learning belongs to the manifest's project, never the observer cwd.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

ADVANCED="$(cd "$(dirname "$0")/.." && pwd)/bin/polylane-advanced.sh"
if ! command -v jq >/dev/null 2>&1; then
  pass "outcome-rooting-skipped-no-jq"; finish; exit 0
fi

make_tmpdir
PROJECT="$TEST_TMPDIR/canonical-project"
MANIFEST="$PROJECT/.polylane/run.json"
OBSERVER="$TEST_TMPDIR/observer-cwd"
mkdir -p "$PROJECT/.polylane" "$OBSERVER"
cat > "$MANIFEST" <<'JSON'
{"base":"main","lanes":[{"name":"alpha","model":"gpt","own_globs":["src/**"]}]}
JSON

( cd "$OBSERVER" && "$ADVANCED" record "$MANIFEST" GO )
CANONICAL_OUTCOMES="$PROJECT/docs/polylane/outcomes.jsonl"
assert_ok "outcomes-rooted-at-manifest-project" test -s "$CANONICAL_OUTCOMES"
assert_eq "observer-cwd-has-no-local-outcomes" "no" "$( [ -e "$OBSERVER/docs/polylane/outcomes.jsonl" ] && printf yes || printf no )"
assert_eq "canonical-outcome-count" "1" "$(jq -s 'length' "$CANONICAL_OUTCOMES")"

OVERRIDE="$TEST_TMPDIR/explicit/outcomes.jsonl"
OVERRIDE_HUBS="$TEST_TMPDIR/explicit/hubs.txt"
POLYLANE_OUTCOMES="$OVERRIDE" POLYLANE_HUBS="$OVERRIDE_HUBS" \
  assert_ok "explicit-outcome-path-overrides-canonical" "$ADVANCED" record "$MANIFEST" GO
assert_ok "explicit-outcome-path-written" test -s "$OVERRIDE"
assert_eq "explicit-override-does-not-add-canonical" "1" "$(jq -s 'length' "$CANONICAL_OUTCOMES")"

finish
