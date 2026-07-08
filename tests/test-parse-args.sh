#!/usr/bin/env bash
# parse_args — frozen CLI: <manifest.json> [--dry-run] [--yes]
# [--intensity <preset>] [--model lane=id]... ; unknown flag / missing
# manifest / bad flag value -> exit 2; -h/--help -> exit 0.

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

# args_state ARGS... -> "DRY_RUN|YES|MANIFEST|INTENSITY|n_overrides|ov0,ov1"
# (runs parse_args in a subshell so its exits cannot kill the test file)
args_state() {
  ( parse_args "$@" 2>/dev/null \
    && printf '%s|%s|%s|%s|%s|%s' \
         "$DRY_RUN" "$YES" "$MANIFEST" "$INTENSITY" \
         "${#MODEL_OVERRIDES[@]}" "${MODEL_OVERRIDES[*]:-}" )
}

assert_eq "args-manifest-only" "0|0|m.json||0|" "$(args_state m.json)"
assert_eq "args-dry-run"       "1|0|m.json||0|" "$(args_state m.json --dry-run)"
assert_eq "args-yes"           "0|1|m.json||0|" "$(args_state m.json --yes)"
assert_eq "args-both-flags"    "1|1|m.json||0|" "$(args_state --dry-run --yes m.json)"

# --intensity: separate-value and = forms
assert_eq "args-intensity"     "0|0|m.json|balanced|0|" "$(args_state m.json --intensity balanced)"
assert_eq "args-intensity-eq"  "0|0|m.json|max|0|"      "$(args_state m.json --intensity=max)"

# --model: repeatable, both forms, order preserved
assert_eq "args-model-repeat" "0|0|m.json||2|alpha=claude-opus-4-8 beta=claude-haiku-4-5" \
  "$(args_state m.json --model alpha=claude-opus-4-8 --model=beta=claude-haiku-4-5)"

# error exits — all must be exactly 2
assert_rc "args-none-exit2"            2 parse_args
assert_rc "args-unknown-flag-exit2"    2 parse_args m.json --bogus
assert_rc "args-missing-manifest-exit2" 2 parse_args --dry-run
assert_rc "args-extra-positional-exit2" 2 parse_args m.json extra.json
assert_rc "args-intensity-no-value-exit2" 2 parse_args m.json --intensity

# help exits 0
assert_rc "args-help-exit0" 0 parse_args -h
assert_rc "args-long-help-exit0" 0 parse_args --help

# -- terminator: next arg taken as manifest even if flag-shaped
assert_eq "args-dashdash-manifest" "0|0|--weird.json||0|" "$(args_state -- --weird.json)"

finish
