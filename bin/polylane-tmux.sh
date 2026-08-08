#!/usr/bin/env bash
# polylane-tmux.sh — deterministic, per-run tmux server isolation.
#
# A tmux server inherits the environment and host permissions of the process
# that first created it. Reusing the default server can therefore strand new
# lanes behind stale macOS permissions or an unrelated parent client. Every
# nonce-bound Polylane run gets its own socket parent and explicitly drops an
# inherited TMUX client binding. Legacy manifests without run_id keep the
# caller's server for backward compatibility.

polylane_tmux_safe_run_id() {
  printf '%s' "$1" | LC_ALL=C tr -c 'A-Za-z0-9_.-' '_'
}

polylane_tmux_default_root() {
  local run_id safe parent digest
  run_id="${1:-}"
  [ -n "$run_id" ] || return 1
  safe=$(polylane_tmux_safe_run_id "$run_id")
  safe=$(printf '%.20s' "$safe")
  digest=$(printf '%s' "$run_id" | cksum | awk '{print $1}')
  # Keep the socket short. macOS limits AF_UNIX paths to roughly 104 bytes and
  # its default TMPDIR is already long before tmux adds /tmux-<uid>/default.
  parent="${POLYLANE_TMUX_PARENT:-/tmp}"
  parent=${parent%/}
  printf '%s/polylane-tmux-%s-%s\n' "$parent" "$safe" "$digest"
}

# polylane_tmux_configure RUN_ID [ensure]
# POLYLANE_TMUX_TMPDIR is the explicit override. Otherwise nonce-bound runs use
# a deterministic root, so the runner, supervisor, and read-only observers all
# reconnect to the same private server after process or conversation restarts.
# `ensure` creates the socket parent; observers and dry-runs omit it and remain
# read-only. POLYLANE_TMUX_AUTO prevents a nested run from mistaking its parent's
# automatically derived root for an explicit user override.
polylane_tmux_configure() {
  local run_id="${1:-}" ensure="${2:-}" root
  if [ -n "${POLYLANE_TMUX_TMPDIR:-}" ] && [ "${POLYLANE_TMUX_AUTO:-0}" != "1" ]; then
    root="$POLYLANE_TMUX_TMPDIR"
  elif [ -n "$run_id" ]; then
    root=$(polylane_tmux_default_root "$run_id") || return 1
    POLYLANE_TMUX_TMPDIR="$root"
    POLYLANE_TMUX_AUTO=1
    export POLYLANE_TMUX_TMPDIR POLYLANE_TMUX_AUTO
  else
    # Legacy manifests intentionally retain their existing tmux server.
    return 0
  fi
  case "$root" in ''|/) echo "polylane-tmux: unsafe socket root: $root" >&2; return 2 ;; esac
  if [ "$ensure" = ensure ]; then
    mkdir -p "$root" || return 1
    chmod 700 "$root" 2>/dev/null || true
  fi
  TMUX_TMPDIR="$root"
  export TMUX_TMPDIR
  unset TMUX
}

polylane_tmux_watch_command() {
  local session="$1"
  if [ -n "${TMUX_TMPDIR:-}" ]; then
    printf 'env -u TMUX TMUX_TMPDIR=%q tmux attach -t %q' "$TMUX_TMPDIR" "$session"
  else
    printf 'tmux attach -t %q' "$session"
  fi
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then
  case "${1:-}" in
    root)  polylane_tmux_default_root "${2:?usage: polylane-tmux.sh root <run-id>}" ;;
    watch) polylane_tmux_configure "${2:-}" && polylane_tmux_watch_command "${3:?usage: polylane-tmux.sh watch <run-id> <session>}" ;;
    *) echo "usage: polylane-tmux.sh root <run-id> | watch <run-id> <session>" >&2; exit 2 ;;
  esac
fi
