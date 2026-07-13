#!/usr/bin/env bash
# polylane-markers.sh — the ONE place the DONE / VERDICT wire-format strings are
# constructed. lane_done/parse_verdict in polylane-run.sh and every references/*.md
# that teaches an agent what to write MUST agree with this file, byte-for-byte.
# tests/test-marker-contract.sh asserts that agreement, so format drift (the real
# nonce-vs-bare STATUS bug) turns into a red test instead of a silent forever-poll.
#
#   markers done <name> [run_id]        -> the status-file first line
#   markers verdict GO|NO-GO [run_id]   -> the integrator verdict sentinel line
#   markers template done               -> the doc-facing template (<lane>/<RUN_ID> placeholders)
#   markers template verdict
#   markers check-docs <refs-dir>       -> exit 1 iff any references/*.md teaches a
#                                          STATUS:/POLYLANE-VERDICT line that is NOT
#                                          the canonical nonce template
# Pure bash-3.2, main-guarded (tests source the functions).
set -euo pipefail

# marker_done NAME [RUN_ID] : nonce form iff RUN_ID non-empty, else legacy bare form.
marker_done() {
  local name="$1" run="${2:-}"
  if [ -n "$run" ]; then printf 'STATUS: %s DONE run=%s' "$name" "$run"
  else printf 'STATUS: %s DONE' "$name"; fi
}

# marker_verdict GO|NO-GO [RUN_ID]
marker_verdict() {
  local v="$1" run="${2:-}"
  if [ -n "$run" ]; then printf 'POLYLANE-VERDICT: %s run=%s' "$v" "$run"
  else printf 'POLYLANE-VERDICT: %s' "$v"; fi
}

# The doc-facing canonical forms — the literal placeholders every reference doc MUST use.
tmpl_done()    { printf 'STATUS: <lane> DONE run=<RUN_ID>'; }
tmpl_verdict() { printf 'POLYLANE-VERDICT: GO run=<RUN_ID>'; }

# check_docs DIR : every markdown line that quotes a STATUS:/POLYLANE-VERDICT literal
# in backticks must contain the canonical nonce token (`run=<RUN_ID>` or `run=$RUN_ID`
# or `run=`). A backticked STATUS:/POLYLANE-VERDICT literal WITHOUT any run= tag is the
# drift bug -> reported + non-zero exit.
check_docs() {
  local dir="$1" rc=0 line
  while IFS= read -r line; do
    case "$line" in *run=*) : ;; *)
      printf 'DOC-MARKER-DRIFT: %s\n' "$line"; rc=1 ;; esac
  done < <(grep -rhoE '`STATUS: [^`]*DONE[^`]*`|`POLYLANE-VERDICT:[^`]*`' "$dir" 2>/dev/null || true)
  return $rc
}

if [ "${BASH_SOURCE[0]:-}" = "${0}" ]; then
  case "${1:-}" in
    done)     shift; marker_done "$@" ;;
    verdict)  shift; marker_verdict "$@" ;;
    template) case "${2:-}" in done) tmpl_done ;; verdict) tmpl_verdict ;;
                *) echo "usage: polylane-markers.sh template done|verdict" >&2; exit 2 ;; esac ;;
    check-docs) shift; check_docs "${1:?usage: check-docs <refs-dir>}" ;;
    *) echo "usage: polylane-markers.sh done <name> [run_id] | verdict GO|NO-GO [run_id] | template done|verdict | check-docs <dir>" >&2; exit 2 ;;
  esac
fi
