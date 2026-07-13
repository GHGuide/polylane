#!/usr/bin/env bash
# polylane-rehearse.sh — hermetic dry-run of the WHOLE pipeline with a mock agent.
# In a throwaway repo, seed a 2-lane + integrator run.json (fresh nonce, disjoint
# own_globs), put a mock agent that writes each lane's DONE marker + the integrator's
# verdict via polylane-markers.sh, run the REAL polylane-run.sh, and assert the
# pipeline reaches the expected end state. Two cases: GO (report says GO, base
# promoted) and NO-GO (report says the verdict was withheld). Catches marker/nonce
# seam drift as a red canary BEFORE real spend — the thing unit tests can't: the
# nonce the runner bakes must equal what the mock writes and what the runner reads.
#   rehearse [go|nogo]     (default go)
# Exits 77 (skip) if tmux is unavailable.
set -euo pipefail
BIN="$(cd "$(dirname "$0")" && pwd)"
RUN="$BIN/polylane-run.sh"; MARK="$BIN/polylane-markers.sh"

command -v tmux >/dev/null 2>&1 || { echo "rehearse: tmux required (skipping)"; exit 77; }
command -v git  >/dev/null 2>&1 || { echo "rehearse: git required" >&2; exit 2; }

rehearse() {
  local want="${1:-go}" root sess rid rc=0
  root=$(mktemp -d "${TMPDIR:-/tmp}/polylane-rehearse.XXXXXX")
  sess="plrh-$$"
  rid="rh$(date +%s)"
  # shellcheck disable=SC2064  # expand root/sess NOW into the trap
  trap "tmux kill-session -t '$sess' 2>/dev/null || true; rm -rf '$root'" RETURN

  ( cd "$root"
    git init -q -b main .; git config user.email t@t; git config user.name t
    echo "seed" > seed.txt; git add -A; git commit -qm seed
    # mock agent: the {prompt} it receives is a FILE PATH containing the lane name;
    # write the marker the runner polls into the CURRENT worktree (pane cd's there).
    cat > mockagent <<MOCK
#!/usr/bin/env bash
# NOTE 1: markers MUST end with a newline — lane_done does 'read -r first || return 1',
# so a newline-less marker file reads as EOF -> not-done -> the runner polls forever.
# NOTE 2: a real agent (claude) STAYS ALIVE after writing its marker; if the mock
# exited, tmux would close its pane and the runner couldn't add the integrator pane
# ("can't find pane: N"). So write the marker, then sleep (the trap kills the session).
prompt="\$*"; mkdir -p docs
case "\$prompt" in
  *lane-a*) { "$MARK" done lane-a "$rid"; echo; } > docs/status-lane-a.md ;;
  *lane-b*) { "$MARK" done lane-b "$rid"; echo; } > docs/status-lane-b.md ;;
  *integrator*)
     # the integrator, like a lane, must write its OWN status DONE marker (the runner
     # polls it) AND the verdict file (merge_gate reads it).
     { "$MARK" done integrator "$rid"; echo; } > docs/status-integrator.md
     if [ "$want" = go ]; then { "$MARK" verdict GO "$rid"; echo; } > docs/verify-integration.md
     else { "$MARK" verdict NO-GO "$rid"; echo; } > docs/verify-integration.md; fi ;;
esac
exec sleep 600
MOCK
    chmod +x mockagent
    mkdir -p .polylane/lanes
    printf 'build lane-a: write a/x\n'        > .polylane/lanes/lane-a.txt
    printf 'build lane-b: write b/y\n'        > .polylane/lanes/lane-b.txt
    printf 'integrator: verify + verdict\n'   > .polylane/lanes/integrator.txt
  )
  cat > "$root/.polylane/run.json" <<JSON
{ "base":"main","run_id":"$rid",
  "integrator":{"name":"integrator","model":"m","effort":"h","branch":"pl/int","worktree":"$root/wt-int","prompt_file":"$root/.polylane/lanes/integrator.txt"},
  "lanes":[
    {"name":"lane-a","model":"m","effort":"h","branch":"pl/a","worktree":"$root/wt-a","prompt_file":"$root/.polylane/lanes/lane-a.txt","own_globs":["a/**"]},
    {"name":"lane-b","model":"m","effort":"h","branch":"pl/b","worktree":"$root/wt-b","prompt_file":"$root/.polylane/lanes/lane-b.txt","own_globs":["b/**"]}
  ] }
JSON

  # run the REAL runner (positional manifest + --yes) with the mock as the agent
  ( cd "$root"
    PATH="$root:$PATH" \
    POLYLANE_AGENT_CMD="$root/mockagent {model} {prompt}" \
    POLYLANE_SESSION="$sess" POLYLANE_POLL_INTERVAL=2 POLYLANE_HEALTH_INTERVAL=9999 \
      "$RUN" "$root/.polylane/run.json" --yes >/dev/null 2>&1 || true )

  local report="$root/docs/polylane-report.md"
  if [ "$want" = go ]; then
    grep -qE 'Outcome:\*\*[[:space:]]*GO|^\*\*GO\*\*' "$report" 2>/dev/null || rc=1
    echo "REHEARSE-GO rc=$rc"
  else
    # NO-GO: report exists and does NOT claim GO (verdict withheld, nothing promoted)
    { [ -f "$report" ] && ! grep -qE 'Outcome:\*\*[[:space:]]*GO' "$report"; } || rc=1
    echo "REHEARSE-NOGO rc=$rc"
  fi
  return "$rc"
}

if [ "${BASH_SOURCE[0]:-}" = "${0}" ]; then
  case "${1:-go}" in go|nogo) rehearse "$1" ;; *) echo "usage: polylane-rehearse.sh [go|nogo]" >&2; exit 2 ;; esac
fi
