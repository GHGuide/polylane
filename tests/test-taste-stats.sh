#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
STATS="$ROOT/bin/polylane-taste-stats.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_eq() {
  [ "$1" = "$2" ] || fail "expected '$1', got '$2'"
}

run_ok() {
  printf '%s' "$1" | LC_ALL=C "$STATS" aggregate
}

run_bad() {
  if printf '%s' "$1" | LC_ALL=C "$STATS" aggregate >/tmp/polylane-taste-stats.out 2>/tmp/polylane-taste-stats.err; then
    fail "expected rejection"
  fi
}

valid_70=$(cat <<'JSON'
{"schema":"polylane.taste.ballots.v1","ballots":[
{"brief_id":"b01","vote":"candidate"},{"brief_id":"b02","vote":"candidate"},
{"brief_id":"b03","vote":"candidate"},{"brief_id":"b04","vote":"candidate"},
{"brief_id":"b05","vote":"candidate"},{"brief_id":"b06","vote":"candidate"},
{"brief_id":"b07","vote":"candidate"},{"brief_id":"b08","vote":"baseline"},
{"brief_id":"b09","vote":"baseline"},{"brief_id":"b10","vote":"baseline"}
]}
JSON
)

output=$(run_ok "$valid_70")
valid_70_output=$output
assert_eq "$output" "$(printf '%s\n' "$output" | jq -cS .)"
assert_eq "$(printf '%s\n' "$output" | jq -r '.schema')" "polylane.taste.stats.v1"
assert_eq "$(printf '%s\n' "$output" | jq -r '.sample_unit')" "brief"
assert_eq "$(printf '%s\n' "$output" | jq -r '.brief_count')" "10"
assert_eq "$(printf '%s\n' "$output" | jq -r '.preference_rate')" "0.7"
assert_eq "$(printf '%s\n' "$output" | jq -r '.pass')" "false"
assert_eq "$(printf '%s\n' "$output" | jq -r '.wilson_lower_bound > 0.39 and .wilson_lower_bound < 0.40')" "true"

all_wins=$(cat <<'JSON'
{"schema":"polylane.taste.ballots.v1","ballots":[
{"brief_id":"a","vote":"candidate"},{"brief_id":"b","vote":"candidate"},
{"brief_id":"c","vote":"candidate"},{"brief_id":"d","vote":"candidate"},
{"brief_id":"e","vote":"candidate"},{"brief_id":"f","vote":"candidate"},
{"brief_id":"g","vote":"candidate"},{"brief_id":"h","vote":"candidate"},
{"brief_id":"i","vote":"candidate"},{"brief_id":"j","vote":"candidate"}
]}
JSON
)
output=$(run_ok "$all_wins")
assert_eq "$(printf '%s\n' "$output" | jq -r '.pass')" "true"
assert_eq "$(printf '%s\n' "$output" | jq -r '.wilson_lower_bound > 0.72 and .wilson_lower_bound < 0.73')" "true"

ties=$(cat <<'JSON'
{"schema":"polylane.taste.ballots.v1","ballots":[
{"brief_id":"one","vote":"candidate"},{"brief_id":"two","vote":"baseline"},
{"brief_id":"three","vote":"tie"}
]}
JSON
)
output=$(run_ok "$ties")
assert_eq "$(printf '%s\n' "$output" | jq -r '.candidate_wins, .baseline_wins, .ties, .preference_rate' | tr '\n' ' ')" "1 1 1 0.5 "
assert_eq "$(printf '%s\n' "$output" | jq -r '.pass')" "false"

run_bad '{"schema":"polylane.taste.ballots.v1","ballots":[{"brief_id":"one","vote":"candidate"},{"brief_id":"one","vote":"baseline"}]}'
run_bad '{"schema":"polylane.taste.ballots.v1","ballots":[]}'
run_bad '{"schema":"polylane.taste.ballots.v1","ballots":[{"brief_id":"one","vote":"candidate"}],"counts":{"candidate_wins":999}}'
run_bad '{"schema":"polylane.taste.ballots.v1","ballots":[{"brief_id":"one","vote":"candidate"}],"brief_count":1}'
run_bad '{"schema":"polylane.taste.ballots.v1","ballots":[{"brief_id":"one","vote":"candidate","weight":"1.0.0"}]}'
run_bad '{"schema":"polylane.taste.ballots.v1","ballots":[{"brief_id":"one","vote":"candidate","weight":1e999}]}'
run_bad '{"schema":"polylane.taste.ballots.v1","ballots":[{"brief_id":"one","vote":"candidate"}],"calibration":NaN}'
run_bad '{"schema":"polylane.taste.ballots.v1","ballots":[{"brief_id":"one","vote":"candidate"}],"calibration":Infinity}'
run_bad '{"schema":"polylane.taste.ballots.v1","schema":"polylane.taste.ballots.v1","ballots":[{"brief_id":"one","vote":"candidate"}]}'
run_bad '{"schema":"polylane.taste.ballots.v1","ballots":[{"brief_id":"one","brief_id":"replayed","vote":"candidate"}]}'

locale_output=$(printf '%s' "$valid_70" | LC_ALL=de_DE.UTF-8 "$STATS" aggregate 2>/dev/null || true)
assert_eq "$locale_output" "$valid_70_output"

printf 'PASS: taste stats\n'
