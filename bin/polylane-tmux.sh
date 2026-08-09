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

polylane_tmux_canonical_path() {
  local path="${1:-}"
  [ -d "$path" ] || return 1
  (cd "$path" 2>/dev/null && pwd -P)
}

# polylane_tmux_tag_pane SESSION PANE RUN_ID LANE WORKTREE
# Pane-local ownership survives agent cwd drift and is scoped to a run nonce.
polylane_tmux_tag_pane() {
  local session="${1:-}" pane="${2:-}" run_id="${3:-}" lane="${4:-}" worktree="${5:-}" canonical
  [ -n "$session" ] && [ -n "$pane" ] && [ -n "$run_id" ] && [ -n "$lane" ] || return 2
  canonical=$(polylane_tmux_canonical_path "$worktree") || return 1
  tmux set-option -p -t "$session:0.$pane" @polylane_run_id "$run_id" || return 1
  tmux set-option -p -t "$session:0.$pane" @polylane_lane "$lane" || return 1
  tmux set-option -p -t "$session:0.$pane" @polylane_worktree "$canonical"
}

# polylane_tmux_find_pane SESSION RUN_ID WORKTREE
# Full matching tags are authoritative. Cwd is only a migration fallback for a
# pane with no Polylane identity options whatsoever; partial or stale tags fail
# closed rather than being silently adopted by a different run.
polylane_tmux_find_pane() {
  local session="${1:-}" run_id="${2:-}" worktree="${3:-}" canonical idx pane_path tagged_run tagged_lane tagged_worktree legacy_idx="" conflict=0
  [ -n "$session" ] || return 2
  canonical=$(polylane_tmux_canonical_path "$worktree") || return 1
  while IFS='|' read -r idx pane_path; do
    [ -n "$idx" ] || continue
    pane_path=$(polylane_tmux_canonical_path "$pane_path" 2>/dev/null || true)
    # tmux format expansion falls back from an absent pane option to a session
    # option with the same name. Query the pane option namespace directly so a
    # tagged session does not make a fully untagged legacy pane look partial.
    tagged_run=$(tmux show-options -p -v -t "$session:0.$idx" @polylane_run_id 2>/dev/null || true)
    tagged_lane=$(tmux show-options -p -v -t "$session:0.$idx" @polylane_lane 2>/dev/null || true)
    tagged_worktree=$(tmux show-options -p -v -t "$session:0.$idx" @polylane_worktree 2>/dev/null || true)
    if [ -n "$tagged_run$tagged_lane$tagged_worktree" ]; then
      if [ -n "$tagged_run" ] && [ -n "$tagged_lane" ] && [ -n "$tagged_worktree" ] && \
        [ "$tagged_run" = "$run_id" ] && [ "$tagged_worktree" = "$canonical" ]; then
        printf '%s' "$idx"
        return 0
      fi
      if [ "$tagged_worktree" = "$canonical" ] || [ "$pane_path" = "$canonical" ]; then conflict=1; fi
      continue
    fi
    [ "$pane_path" = "$canonical" ] && legacy_idx="$idx"
  done < <(tmux list-panes -t "$session:0" -F '#{pane_index}|#{pane_current_path}' 2>/dev/null || true)
  [ "$conflict" = 0 ] && [ -n "$legacy_idx" ] && { printf '%s' "$legacy_idx"; return 0; }
  return 1
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then
  case "${1:-}" in
    root)  polylane_tmux_default_root "${2:?usage: polylane-tmux.sh root <run-id>}" ;;
    watch) polylane_tmux_configure "${2:-}" && polylane_tmux_watch_command "${3:?usage: polylane-tmux.sh watch <run-id> <session>}" ;;
    *) echo "usage: polylane-tmux.sh root <run-id> | watch <run-id> <session>" >&2; exit 2 ;;
  esac
fi
