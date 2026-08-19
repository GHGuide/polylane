#!/usr/bin/env bash
# Regression test for defect c42b-run-mode-vocabulary-mismatch.
#
# Required v3 control (EVIDENCE-CLAIM-REGISTRY.v3.json, verbatim):
#   "Run mode values use one contract-v3 vocabulary at producer, validator,
#    storage, and lifecycle boundaries."
#
# One vocabulary means one source. CONTRACT-LOCK.v3.json is that source: its
# lifecycle.authoritative_sequence and lifecycle.allowed_transitions are frozen.
# The execution-contract binary must serve those values rather than keep a
# second copy that can drift, and must refuse any value outside them.
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT/bin/polylane-taste-execution-contract.sh"
LOCK="$ROOT/docs/polylane/taste-certification/contracts/CONTRACT-LOCK.v3.json"
EXAMPLE="$ROOT/docs/polylane/taste-certification/contracts/execution-v3.example.json"
PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); printf 'ok %d - %s\n' "$PASS" "$1"; }
not_ok() { FAIL=$((FAIL + 1)); printf 'not ok - %s: %s\n' "$1" "$2" >&2; }

assert_accepts() {
  name=$1
  shift
  if output=$("$SCRIPT" "$@" 2>&1); then
    ok "$name"
  else
    not_ok "$name" "refused a frozen contract-v3 value: $output"
  fi
}

assert_rejects() {
  name=$1 code=$2
  shift 2
  if output=$("$SCRIPT" "$@" 2>&1); then
    not_ok "$name" "accepted a value outside the contract-v3 vocabulary: $output"
  elif printf '%s' "$output" | grep -F "$code" >/dev/null; then
    ok "$name"
  else
    not_ok "$name" "expected $code, got: $output"
  fi
}

# The served vocabulary is byte-identical to the frozen lock, in order.
expected=$(jq -r '.lifecycle.authoritative_sequence[]' "$LOCK")
if actual=$("$SCRIPT" run-mode-vocabulary 2>&1); then
  if [ "$actual" = "$expected" ]; then
    ok "vocabulary-is-served-from-the-frozen-lock"
  else
    not_ok "vocabulary-is-served-from-the-frozen-lock" "expected [$expected], got [$actual]"
  fi
else
  not_ok "vocabulary-is-served-from-the-frozen-lock" "$actual"
fi

# Reconciled to the lock, never the reverse: no second copy of the vocabulary
# may live in the implementation, or the two can drift apart again.
copies=0
while IFS= read -r state; do
  if grep -F "$state" "$SCRIPT" >/dev/null 2>&1; then
    copies=$((copies + 1))
    printf 'hardcoded run-mode state in implementation: %s\n' "$state" >&2
  fi
done <<EOF
$expected
EOF
if [ "$copies" -eq 0 ]; then
  ok "implementation-keeps-no-second-copy-of-the-vocabulary"
else
  not_ok "implementation-keeps-no-second-copy-of-the-vocabulary" "$copies state name(s) hardcoded"
fi

# Every transition the lock allows is accepted, and only those.
while IFS= read -r transition; do
  from=${transition%%->*}
  to=${transition##*->}
  assert_accepts "allows-$from-to-$to" run-mode-transition "$from" "$to"
done < <(jq -r '.lifecycle.allowed_transitions[]' "$LOCK")

assert_rejects "refuses-skipping-the-handoff-states" RUN_MODE_TRANSITION \
  run-mode-transition WORKING DONE
assert_rejects "refuses-reopening-a-committed-handoff" RUN_MODE_TRANSITION \
  run-mode-transition HANDOFF_COMMITTED WORKING
assert_rejects "refuses-restarting-a-finished-run" RUN_MODE_TRANSITION \
  run-mode-transition DONE QUIESCING

# Values from any other run-mode vocabulary are refused at the vocabulary
# boundary, not silently mapped onto a contract-v3 state.
assert_rejects "refuses-foreign-running-state" RUN_MODE_VOCABULARY \
  run-mode-transition RUNNING DONE
assert_rejects "refuses-foreign-completed-state" RUN_MODE_VOCABULARY \
  run-mode-transition QUIESCING COMPLETED
assert_rejects "refuses-case-folded-state" RUN_MODE_VOCABULARY \
  run-mode-transition working HANDOFF_PENDING
assert_rejects "refuses-empty-state" RUN_MODE_VOCABULARY \
  run-mode-transition WORKING ""

# Adding the run-mode boundary must not disturb frozen m32.7 acceptance.
if output=$("$SCRIPT" validate "$EXAMPLE" 2>&1); then
  case $output in
    VALID\ execution-v3\ *) ok "frozen-example-still-validates" ;;
    *) not_ok "frozen-example-still-validates" "unexpected output: $output" ;;
  esac
else
  not_ok "frozen-example-still-validates" "$output"
fi

printf '1..%d\n' $((PASS + FAIL))
if [ "$FAIL" -ne 0 ]; then
  printf '%d test(s) failed\n' "$FAIL" >&2
  exit 1
fi
