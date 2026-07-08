#!/usr/bin/env bash
#
# polylane-notify.sh — macOS banner + sound for polylane run events.
#
# CONTRACT (frozen — the runner depends on this):
#   CLI:    bin/polylane-notify.sh <event> <message>
#   events: done | go | no-go | halt | stall
#   exit:   ALWAYS 0 — never breaks a `set -e` caller (the runner)
#   non-macOS (no osascript): quiet no-op, still exit 0
#
# Sounds: go=Glass · no-go=Basso · halt=Basso · done=Ping · stall=Sosumi
# bash-3.2 safe.

usage() {
  cat <<'EOF'
polylane-notify.sh — macOS notification + sound per polylane run event

USAGE:
  bin/polylane-notify.sh <event> <message>

EVENTS (sound):
  done    Ping    — a lane finished
  go      Glass   — integrator verdict GO
  no-go   Basso   — integrator verdict NO-GO
  halt    Basso   — run halted (lane failed after retries)
  stall   Sosumi  — a lane looks stuck

BEHAVIOR:
  Always exits 0 (safe under set -e callers). Quiet no-op when osascript
  is absent (non-macOS). Unknown events still notify, without a sound.
EOF
}

notify_main() {
  case "${1:-}" in
    -h|--help) usage; return 0 ;;
  esac

  # Non-macOS / no osascript: quiet no-op.
  command -v osascript >/dev/null 2>&1 || return 0

  local event="${1:-}" msg="${2:-}" sound="" script=""
  if [ -z "$event" ]; then
    usage >&2
    return 0
  fi

  case "$event" in
    go)         sound="Glass"  ;;
    no-go|halt) sound="Basso"  ;;
    done)       sound="Ping"   ;;
    stall)      sound="Sosumi" ;;
    *)          sound=""       ;;   # unknown event: banner, no sound
  esac

  # AppleScript double-quoted string escaping: backslash first, then quotes.
  msg=${msg//\\/\\\\}
  msg=${msg//\"/\\\"}
  local sub="$event"
  sub=${sub//\\/\\\\}
  sub=${sub//\"/\\\"}

  script="display notification \"$msg\" with title \"polylane\" subtitle \"$sub\""
  [ -n "$sound" ] && script="$script sound name \"$sound\""

  osascript -e "$script" >/dev/null 2>&1 || true
  return 0
}

notify_main "$@"
exit 0
