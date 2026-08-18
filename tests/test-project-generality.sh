#!/usr/bin/env bash
# Focused contract tests for domain-neutral project profiles.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PROJECT="$ROOT/bin/polylane-project.sh"
FIXTURES="$ROOT/benchmarks/project-generality/profiles"
PROFILE_RECORD="$ROOT/benchmarks/project-generality/PROJECT_PROFILE.md"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/polylane-project-generality.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0

ok() { printf 'ok - %s\n' "$1"; pass=$((pass + 1)); }
not_ok() { printf 'not ok - %s\n' "$1" >&2; fail=$((fail + 1)); }

assert_ok() {
  local name="$1"
  shift
  if "$@" >"$TMP/out" 2>"$TMP/err"; then
    ok "$name"
  else
    cat "$TMP/err" >&2
    not_ok "$name"
  fi
}

assert_fail() {
  local name="$1" expected="$2"
  shift 2
  if "$@" >"$TMP/out" 2>"$TMP/err"; then
    not_ok "$name (unexpected success)"
  elif grep -F "$expected" "$TMP/err" >/dev/null; then
    ok "$name"
  else
    cat "$TMP/err" >&2
    not_ok "$name (missing: $expected)"
  fi
}

for profile in "$FIXTURES"/*.json; do
  name=$(basename "$profile" .json)
  assert_ok "validate $name" "$PROJECT" validate "$profile"
  assert_ok "brief $name" "$PROJECT" brief "$profile"
  "$PROJECT" brief "$profile" >"$TMP/brief.json"
  if jq -e '
    .outcome != ""
    and (.deliverables | length > 0)
    and (.deliverables | all(.[]; .artifact != "" and .path != ""))
    and (.evidence_modes | length > 0)
    and .external_action_policy.mode
  ' "$TMP/brief.json" >/dev/null; then
    ok "brief preserves outcome, artifacts, evidence, and action boundary for $name"
  else
    not_ok "brief preserves outcome, artifacts, evidence, and action boundary for $name"
  fi
  jq '{lanes: [.deliverables | to_entries[] | {name: ("artifact-" + (.key | tostring)), own_globs: [.value.path]}]}' "$TMP/brief.json" >"$TMP/lanes.json"
  if "$ROOT/bin/polylane-scope.sh" check-static "$TMP/lanes.json" >"$TMP/out" 2>"$TMP/err"; then
    ok "compile $name into non-overlapping file-isolated artifact lanes"
  else
    cat "$TMP/err" >&2
    not_ok "compile $name into non-empty file-isolated artifact lanes"
  fi
done

assert_ok "gate durable PROJECT_PROFILE.md before goal decomposition" \
  "$PROJECT" gate "$PROFILE_RECORD" "$FIXTURES/app.json"

grep -v '^Evidence:' "$PROFILE_RECORD" >"$TMP/incomplete-project-profile.md"
assert_fail "reject incomplete PROJECT_PROFILE.md record" "PROJECT_PROFILE.md requires Evidence" \
  "$PROJECT" gate "$TMP/incomplete-project-profile.md" "$FIXTURES/app.json"

jq '.outcome = "A different outcome"' "$FIXTURES/app.json" >"$TMP/mismatched-profile.json"
assert_fail "reject mismatched human and machine profile outcomes" \
  "PROJECT_PROFILE.md Outcome must match the machine profile outcome" \
  "$PROJECT" gate "$PROFILE_RECORD" "$TMP/mismatched-profile.json"

jq '.kind = "custom" | .domains = ["unlisted-industry"]' "$FIXTURES/mixed-custom.json" >"$TMP/custom.json"
assert_ok "accept custom industry without an allowlist" "$PROJECT" validate "$TMP/custom.json"

jq '.external_action_policy.actions[0].execution = "autonomous-live"' "$FIXTURES/trading-strategy-research.json" >"$TMP/unsafe-trading.json"
assert_fail "reject autonomous live trading" "trading profiles cannot declare autonomous live execution" "$PROJECT" validate "$TMP/unsafe-trading.json"

jq 'del(.evidence_modes)' "$FIXTURES/app.json" >"$TMP/missing-evidence.json"
assert_fail "reject missing evidence modes" "evidence_modes must be a non-empty array" "$PROJECT" validate "$TMP/missing-evidence.json"

jq '.risk_tier = "high" | .external_action_policy = {"mode":"not-needed","actions":[]}' "$FIXTURES/app.json" >"$TMP/high-risk.json"
assert_fail "require explicit approval actions for high risk" "high-risk profiles require approval-required external actions" "$PROJECT" validate "$TMP/high-risk.json"

printf '1..%s\n' "$((pass + fail))"
[ "$fail" -eq 0 ]
