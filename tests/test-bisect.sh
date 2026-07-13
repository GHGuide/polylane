#!/usr/bin/env bash
# polylane-bisect.sh — delta-debug isolation of the minimal failing lane subset.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$(cd "$(dirname "$RUNNER")" && pwd)/polylane-bisect.sh"

# single culprit: any subset containing c fails
verify_subset() { case ",$1," in *,c,*) return 1 ;; *) return 0 ;; esac; }
assert_eq "bisect-single" "POLYLANE-SALVAGE: green=a,b,d culprit=c" "$(salvage a b c d)"

# two independent culprits: fails iff c OR e present -> both isolated, both dropped
verify_subset() { case ",$1," in *,c,*|*,e,*) return 1 ;; *) return 0 ;; esac; }
got=$(salvage a b c d e)
assert_eq "bisect-double-green" "green=a,b,d" "$(printf '%s\n' "$got" | grep -oE 'green=[a-z,]*')"
# culprit set is exactly {c,e} regardless of discovery order
assert_contains "bisect-double-cul-c" "c" "$(printf '%s\n' "$got" | grep -oE 'culprit=.*')"
assert_contains "bisect-double-cul-e" "e" "$(printf '%s\n' "$got" | grep -oE 'culprit=.*')"

# all green (defensive): full set promoted, no culprit
verify_subset() { return 0; }
assert_eq "bisect-all-green" "POLYLANE-SALVAGE: green=a,b,c culprit=" "$(salvage a b c)"

# CLI guard: <3 lanes refused
assert_rc "bisect-guard-lt3" 2 "$(cd "$(dirname "$RUNNER")" && pwd)/polylane-bisect.sh" salvage a b
finish
