#!/usr/bin/env bash
# PreToolUse(Grep|Glob) nudge — steer navigation to the graphify query helper
# instead of grepping/globbing to discover where things are. Non-blocking.
DIR="${CLAUDE_PROJECT_DIR:-.}"
if [ -f "$DIR/graphify-out/q.py" ]; then
  cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"graphify-out/q.py exists. For NAVIGATION (where is X / who calls Y / what does Z use / what's near it / what's in file F) run:  python3 graphify-out/q.py <symbol>   (subcommands: callers | uses | near | file | community; add --json for machine-readable output). Each hit is id + file:line + community in ~100 bytes instead of reading whole files — far cheaper than grep+Read for discovery. Use Grep/Glob ONLY to confirm an exact string right before an edit, not to find where code lives. If the graph looks stale, run /graphify-auto first (free)."}}
JSON
fi
exit 0
