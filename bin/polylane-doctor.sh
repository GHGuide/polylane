#!/usr/bin/env bash
#
# polylane-doctor.sh — preflight diagnostics for a polylane run.
#
# CONTRACT (frozen — other lanes depend on this):
#   CLI:  bin/polylane-doctor.sh [manifest.json]
#   exit: 0 = no FAIL (WARNs allowed) · 1 = any FAIL
#
# Renders a PASS/WARN/FAIL table, one row per check, each with a one-line
# fix hint. Checks: required deps (tmux jq git claude; shellcheck optional),
# git repo + uncommitted-work orphan warning + lane branch/worktree collisions,
# manifest (exists, valid JSON, prompt_files exist non-empty, worktree paths
# sane), disk free (WARN <5GB, FAIL <1GB), tmux session collision
# (POLYLANE_SESSION, default 'polylane'), claude on PATH + version.
# bash-3.2 safe; never mutates anything.

usage() {
  cat <<'EOF'
polylane-doctor.sh — preflight diagnostics for a polylane run

USAGE:
  bin/polylane-doctor.sh [manifest.json]

ARGS:
  [manifest.json]  manifest to validate (default: <repo-root>/.polylane/run.json;
                   if the default is absent that is a WARN, but a manifest you
                   pass explicitly must exist or it is a FAIL)

CHECKS:
  deps       tmux, jq, git, claude required; shellcheck optional (WARN)
  git        inside a repo; uncommitted work (orphan risk) = WARN;
             manifest lane branches/worktrees that already exist = WARN
  manifest   exists, valid JSON, every prompt_file exists and is non-empty,
             worktree paths sane
  disk       free space: WARN < 5GB, FAIL < 1GB
  tmux       session name collision on POLYLANE_SESSION (default 'polylane')
  claude     on PATH and reports a version

EXIT:
  0  no FAIL rows (WARNs allowed)
  1  at least one FAIL
EOF
}

TMUX_SESSION="${POLYLANE_SESSION:-polylane}"

# Row store — parallel indexed arrays (bash-3.2 safe, no assoc arrays).
R_STATUS=(); R_NAME=(); R_HINT=()
N_FAIL=0; N_WARN=0

row() { # STATUS CHECK-NAME HINT/DETAIL
  R_STATUS+=("$1"); R_NAME+=("$2"); R_HINT+=("$3")
  case "$1" in
    FAIL) N_FAIL=$((N_FAIL + 1)) ;;
    WARN) N_WARN=$((N_WARN + 1)) ;;
  esac
}

# --- deps ---------------------------------------------------------------------

check_deps() {
  local d hint
  for d in tmux jq git claude; do
    if command -v "$d" >/dev/null 2>&1; then
      row PASS "dep: $d" "$(command -v "$d")"
    else
      case "$d" in
        tmux)   hint="brew install tmux" ;;
        jq)     hint="brew install jq" ;;
        git)    hint="xcode-select --install" ;;
        claude) hint="npm install -g @anthropic-ai/claude-code" ;;
      esac
      row FAIL "dep: $d" "missing — $hint"
    fi
  done
  if command -v shellcheck >/dev/null 2>&1; then
    row PASS "dep: shellcheck (optional)" "$(command -v shellcheck)"
  else
    row WARN "dep: shellcheck (optional)" "missing — brew install shellcheck (lint only, not required to run)"
  fi
}

# --- git repo + orphans ---------------------------------------------------------

REPO_ROOT=""

check_git() {
  if ! command -v git >/dev/null 2>&1; then
    row FAIL "git: repository" "git missing — install it, then re-run doctor"
    return 0
  fi
  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
  if [ -z "$REPO_ROOT" ]; then
    row FAIL "git: repository" "not inside a git repo — cd into the project or git init"
    return 0
  fi
  row PASS "git: repository" "$REPO_ROOT"

  local dirty paths extra=""
  dirty=$(git status --porcelain 2>/dev/null | grep -c . || true)
  if [ "${dirty:-0}" -gt 0 ] 2>/dev/null; then
    # list the orphans (first 3) so the operator sees WHAT is at risk, not just a count
    paths=$(git status --porcelain 2>/dev/null | sed 's/^...//' | head -3 | tr '\n' ' ')
    [ "$dirty" -gt 3 ] && extra="… "
    row WARN "git: working tree" "$dirty uncommitted: ${paths}${extra}— commit/stash orphan work before launching lanes"
  else
    row PASS "git: working tree" "clean"
  fi
}

# --- manifest -------------------------------------------------------------------

MANIFEST=""
MANIFEST_OK=0   # 1 once the manifest parses — gates the deeper sub-checks

check_manifest() {
  local explicit="$1"

  if [ ! -f "$MANIFEST" ]; then
    if [ "$explicit" = "1" ]; then
      row FAIL "manifest: exists" "not found: $MANIFEST — run /polylane to emit it"
    else
      row WARN "manifest: exists" "no $MANIFEST — run /polylane first (env checks still valid)"
    fi
    return 0
  fi
  row PASS "manifest: exists" "$MANIFEST"

  if ! command -v jq >/dev/null 2>&1; then
    row WARN "manifest: valid JSON" "jq missing — cannot validate (fix the dep FAIL above)"
    return 0
  fi
  if ! jq empty "$MANIFEST" 2>/dev/null; then
    row FAIL "manifest: valid JSON" "invalid JSON — re-emit with /polylane or fix by hand"
    return 0
  fi
  row PASS "manifest: valid JSON" "parses clean"
  MANIFEST_OK=1

  # PROJECT_ROOT anchors relative prompt_file paths, same rule as polylane-run.sh
  # abs_prompt(): parent of the manifest's own directory.
  local mdir project_root
  mdir=$(cd "$(dirname "$MANIFEST")" 2>/dev/null && pwd)
  project_root=$(cd "$mdir/.." 2>/dev/null && pwd)

  local n i name pf wt lane_total
  lane_total=$(jq '.lanes | length' "$MANIFEST" 2>/dev/null || echo 0)

  # prompt files: every lane's + the integrator's must exist and be non-empty.
  local pf_bad=0
  n="$lane_total"
  for ((i = 0; i < n; i++)); do
    name=$(jq -r ".lanes[$i].name // \"lane$i\"" "$MANIFEST")
    pf=$(jq -r ".lanes[$i].prompt_file // \"\"" "$MANIFEST")
    case "$pf" in ""|/*) : ;; *) pf="$project_root/$pf" ;; esac
    if [ -z "$pf" ] || [ ! -s "$pf" ]; then
      row FAIL "manifest: prompt_file ($name)" "missing/empty: ${pf:-unset} — /polylane phase 6 must emit it"
      pf_bad=1
    fi
  done
  name=$(jq -r '.integrator.name // "integrator"' "$MANIFEST")
  pf=$(jq -r '.integrator.prompt_file // ""' "$MANIFEST")
  case "$pf" in ""|/*) : ;; *) pf="$project_root/$pf" ;; esac
  if [ -z "$pf" ] || [ ! -s "$pf" ]; then
    row FAIL "manifest: prompt_file ($name)" "missing/empty: ${pf:-unset} — /polylane phase 6 must emit it"
    pf_bad=1
  fi
  [ "$pf_bad" = "0" ] && row PASS "manifest: prompt files" "all $((lane_total + 1)) exist and are non-empty"

  # worktree paths sane: set, not /, not the manifest's own project root.
  # Anchor = project_root (parent of .polylane), NOT the caller's repo root:
  # doctor may legally run from inside a lane worktree the manifest lists.
  local wt_bad=0
  for ((i = 0; i < n; i++)); do
    name=$(jq -r ".lanes[$i].name // \"lane$i\"" "$MANIFEST")
    wt=$(jq -r ".lanes[$i].worktree // \"\"" "$MANIFEST")
    if [ -z "$wt" ] || [ "$wt" = "/" ] || [ "$wt" = "${project_root:-__none__}" ]; then
      row FAIL "manifest: worktree ($name)" "insane path: '${wt:-unset}' — must be a dedicated dir, not / or the project root"
      wt_bad=1
    fi
  done
  wt=$(jq -r '.integrator.worktree // ""' "$MANIFEST")
  if [ -z "$wt" ] || [ "$wt" = "/" ] || [ "$wt" = "${project_root:-__none__}" ]; then
    row FAIL "manifest: worktree (integrator)" "insane path: '${wt:-unset}' — must be a dedicated dir, not / or the project root"
    wt_bad=1
  fi
  [ "$wt_bad" = "0" ] && row PASS "manifest: worktree paths" "all $((lane_total + 1)) sane"
}

# --- branch / worktree collisions (needs git + parsed manifest) -------------------

check_collisions() {
  [ "$MANIFEST_OK" = "1" ] || return 0
  [ -n "$REPO_ROOT" ] || return 0
  command -v git >/dev/null 2>&1 || return 0

  local n i br wt name hits=0
  n=$(jq '.lanes | length' "$MANIFEST" 2>/dev/null || echo 0)
  for ((i = 0; i < n; i++)); do
    name=$(jq -r ".lanes[$i].name // \"lane$i\"" "$MANIFEST")
    br=$(jq -r ".lanes[$i].branch // \"\"" "$MANIFEST")
    wt=$(jq -r ".lanes[$i].worktree // \"\"" "$MANIFEST")
    if [ -n "$br" ] && git show-ref --verify --quiet "refs/heads/$br"; then
      row WARN "git: branch collision ($name)" "branch '$br' exists — runner reuses it (not re-forked from base); delete it for a fresh lane"
      hits=1
    fi
    if [ -n "$wt" ] && { [ -e "$wt" ] || git worktree list --porcelain 2>/dev/null | grep -qF "worktree $wt"; }; then
      row WARN "git: worktree collision ($name)" "path '$wt' exists — runner skips add and reuses it; remove with: git worktree remove --force '$wt'"
      hits=1
    fi
  done
  [ "$hits" = "0" ] && row PASS "git: lane collisions" "no pre-existing lane branches or worktrees"
}

# --- disk -----------------------------------------------------------------------

check_disk() {
  local avail_kb gb
  avail_kb=$(df -Pk . 2>/dev/null | awk 'NR==2 {print $4}')
  if ! [ "${avail_kb:-x}" -ge 0 ] 2>/dev/null; then
    row WARN "disk: free space" "could not read df output — check disk manually"
    return 0
  fi
  gb=$((avail_kb / 1048576))
  if [ "$avail_kb" -lt 1048576 ]; then
    row FAIL "disk: free space" "only ${gb}GB free (<1GB) — worktrees need room; free space first"
  elif [ "$avail_kb" -lt 5242880 ]; then
    row WARN "disk: free space" "${gb}GB free (<5GB) — one worktree per lane adds up; consider freeing space"
  else
    row PASS "disk: free space" "${gb}GB free"
  fi
}

# --- tmux session collision -------------------------------------------------------

check_tmux_session() {
  command -v tmux >/dev/null 2>&1 || return 0   # dep FAIL already covers absence
  if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    row FAIL "tmux: session '$TMUX_SESSION'" "already exists — tmux kill-session -t '$TMUX_SESSION' or set POLYLANE_SESSION=<other>"
  else
    row PASS "tmux: session '$TMUX_SESSION'" "name free"
  fi
}

# --- claude version ----------------------------------------------------------------

check_claude() {
  command -v claude >/dev/null 2>&1 || return 0  # dep FAIL already covers absence
  local v
  v=$(claude --version 2>/dev/null | head -1)
  if [ -n "$v" ]; then
    row PASS "claude: version" "$v"
  else
    row FAIL "claude: version" "claude found but --version failed — reinstall: npm install -g @anthropic-ai/claude-code"
  fi
}

# --- render -------------------------------------------------------------------------

render() {
  local i total="${#R_STATUS[@]}" pass
  pass=$(( total - N_FAIL - N_WARN ))
  echo "== polylane doctor =="
  printf '%-4s  %-38s  %s\n' "STAT" "CHECK" "FIX / DETAIL"
  printf '%-4s  %-38s  %s\n' "----" "--------------------------------------" "------------"
  for ((i = 0; i < total; i++)); do
    printf '%-4s  %-38s  %s\n' "${R_STATUS[$i]}" "${R_NAME[$i]}" "${R_HINT[$i]}"
  done
  echo
  echo "$pass PASS · $N_WARN WARN · $N_FAIL FAIL"
}

# --- main ----------------------------------------------------------------------------

doctor_main() {
  local explicit=0
  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    --rehearse)
      # the "dry-run the whole flow" button: run the hermetic mock-agent canary
      # end-to-end (GO + NO-GO) with the REAL runner, catching marker/nonce seam drift.
      local rh; rh="$(dirname "$0")/polylane-rehearse.sh"
      [ -x "$rh" ] || { echo "polylane-doctor: rehearse helper not found at $rh" >&2; exit 1; }
      echo "== rehearse: GO =="; "$rh" go || { echo "REHEARSE GO FAILED" >&2; exit 1; }
      echo "== rehearse: NO-GO =="; "$rh" nogo || { echo "REHEARSE NO-GO FAILED" >&2; exit 1; }
      echo "rehearse: both cases passed — pipeline plumbing is sound"; exit 0 ;;
    -*)        echo "polylane-doctor: unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac

  if [ -n "${1:-}" ]; then
    MANIFEST="$1"; explicit=1
  fi

  check_deps
  check_git

  if [ -z "$MANIFEST" ]; then
    MANIFEST="${REPO_ROOT:-.}/.polylane/run.json"
  fi

  check_manifest "$explicit"
  check_collisions
  check_disk
  check_tmux_session
  check_claude
  render

  [ "$N_FAIL" -eq 0 ] && exit 0
  exit 1
}

# Only run when executed directly (sourceable, same pattern as polylane-run.sh).
if [ "${BASH_SOURCE[0]:-}" = "${0}" ]; then
  doctor_main "$@"
fi
