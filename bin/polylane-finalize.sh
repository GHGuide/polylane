#!/usr/bin/env bash
# Worker-owned, transactional v3 handoff finalizer. Bash 3.2 + jq.
set -euo pipefail
LC_ALL=C
export LC_ALL

usage() {
  echo "usage: polylane-finalize.sh [transition] --project-root ROOT --worktree WT --lane NAME --run-id RUN --role builder|integrator [--verdict VALUE] [--to QUIESCING|DONE]" >&2
  exit 2
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  else return 1; fi
}

valid_name() { printf '%s' "$1" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*$'; }
now_epoch() { printf '%s' "${POLYLANE_NOW_EPOCH:-$(date +%s)}"; }

MODE=finalize
[ "${1:-}" = transition ] && { MODE=transition; shift; }
PROJECT_ROOT=${POLYLANE_PROJECT_ROOT:-}
WORKTREE=${POLYLANE_SOURCE_ROOT:-$PWD}
LANE=${POLYLANE_WORKER_ID:-}
RUN_ID=${POLYLANE_WORKER_RUN_ID:-}
ROLE=${POLYLANE_WORKER_ROLE:-}
VERDICT=""
TO_STATE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --project-root) PROJECT_ROOT=${2:-}; shift 2 ;;
    --worktree) WORKTREE=${2:-}; shift 2 ;;
    --lane) LANE=${2:-}; shift 2 ;;
    --run-id) RUN_ID=${2:-}; shift 2 ;;
    --role) ROLE=${2:-}; shift 2 ;;
    --verdict) VERDICT=${2:-}; shift 2 ;;
    --to) TO_STATE=${2:-}; shift 2 ;;
    *) usage ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "polylane-finalize: jq is required" >&2; exit 2; }
valid_name "$LANE" || usage
valid_name "$RUN_ID" || usage
case "$ROLE" in builder|integrator) : ;; *) usage ;; esac
[ -d "$PROJECT_ROOT" ] && [ -d "$WORKTREE" ] || usage
PROJECT_ROOT=$(cd "$PROJECT_ROOT" && pwd -P)
WORKTREE=$(cd "$WORKTREE" && pwd -P)
STATE_DIR="$PROJECT_ROOT/.polylane/finalization/$RUN_ID"
STATE_FILE="$STATE_DIR/$LANE.json"
LOCK="$STATE_FILE.lock"

state_transition() {
  local to=$1 head=${2:-} marker_sha=${3:-} verdict_sha=${4:-} from tmp epoch
  mkdir -p "$STATE_DIR"
  while ! mkdir "$LOCK" 2>/dev/null; do sleep 0.05; done
  trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT INT TERM
  from=WORKING
  [ ! -s "$STATE_FILE" ] || from=$(jq -r '.state // "WORKING"' "$STATE_FILE")
  case "$from:$to" in
    WORKING:WORKING|WORKING:HANDOFF_PENDING|HANDOFF_PENDING:HANDOFF_PENDING|HANDOFF_PENDING:HANDOFF_COMMITTED|HANDOFF_COMMITTED:QUIESCING|QUIESCING:QUIESCING|QUIESCING:DONE|DONE:DONE) : ;;
    *) echo "polylane-finalize: invalid lifecycle transition $from -> $to" >&2; rmdir "$LOCK"; trap - EXIT INT TERM; return 1 ;;
  esac
  epoch=$(now_epoch)
  tmp=$(mktemp "$STATE_DIR/.${LANE}.XXXXXX")
  if [ -s "$STATE_FILE" ]; then
    jq --arg state "$to" --arg head "$head" --arg marker_sha "$marker_sha" \
      --arg verdict_sha "$verdict_sha" --argjson epoch "$epoch" '
      .state=$state | .transition_epoch=$epoch |
      (if $head!="" then .handoff_head=$head else . end) |
      (if $marker_sha!="" then .marker_sha256=$marker_sha else . end) |
      (if $verdict_sha!="" then .verdict_sha256=$verdict_sha else . end) |
      .transitions += [{state:$state,epoch:$epoch}]
    ' "$STATE_FILE" > "$tmp"
  else
    jq -cn --arg run "$RUN_ID" --arg lane "$LANE" --arg role "$ROLE" --arg state "$to" \
      --arg worktree "$WORKTREE" --arg head "$head" --argjson epoch "$epoch" '
      {version:3,run:$run,lane:$lane,role:$role,worktree:$worktree,state:$state,
       implementation_head:$head,handoff_head:"",marker_sha256:"",verdict_sha256:"",
       transition_epoch:$epoch,transitions:[{state:$state,epoch:$epoch}]}
    ' > "$tmp"
  fi
  mv "$tmp" "$STATE_FILE"
  rmdir "$LOCK"
  trap - EXIT INT TERM
}

if [ "$MODE" = transition ]; then
  case "$TO_STATE" in QUIESCING|DONE) : ;; *) usage ;; esac
  CURRENT=$(jq -r '.state // ""' "$STATE_FILE" 2>/dev/null || true)
  HEAD=$(jq -r '.handoff_head // ""' "$STATE_FILE" 2>/dev/null || true)
  [ -n "$CURRENT" ] && [ -n "$HEAD" ] || exit 1
  state_transition "$TO_STATE" "$HEAD"
  exit $?
fi

case "$VERDICT" in
  '') [ "$ROLE" = builder ] || usage ;;
  GO|READY-FOR-HOST-GATE|EXTERNAL-EVIDENCE-OPEN|NO-GO) [ "$ROLE" = integrator ] || usage ;;
  *) usage ;;
esac
git -C "$WORKTREE" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 1
MARKER_REL="docs/status-$LANE.md"
if [ "$ROLE" = integrator ]; then EVIDENCE_REL=docs/verify-integration.md
else EVIDENCE_REL="docs/verify-$LANE.md"; fi
[ -s "$WORKTREE/$EVIDENCE_REL" ] && [ ! -L "$WORKTREE/$EVIDENCE_REL" ] || {
  echo "polylane-finalize: missing regular evidence file $EVIDENCE_REL" >&2; exit 1;
}

# A pending transaction is recovered only by this worker-owned helper. Restore
# its two owned handoff paths to the recorded implementation tip, then rebuild.
RECOVERING=0
if [ -s "$STATE_FILE" ] && [ "$(jq -r '.state // ""' "$STATE_FILE")" = HANDOFF_PENDING ]; then
  RECOVERING=1
  IMPL_HEAD=$(jq -r '.implementation_head // ""' "$STATE_FILE")
  git -C "$WORKTREE" cat-file -e "$IMPL_HEAD^{commit}" 2>/dev/null || exit 1
  if git -C "$WORKTREE" cat-file -e "$IMPL_HEAD:$EVIDENCE_REL" 2>/dev/null; then
    git -C "$WORKTREE" show "$IMPL_HEAD:$EVIDENCE_REL" > "$WORKTREE/$EVIDENCE_REL"
  fi
  if git -C "$WORKTREE" cat-file -e "$IMPL_HEAD:$MARKER_REL" 2>/dev/null; then
    git -C "$WORKTREE" show "$IMPL_HEAD:$MARKER_REL" > "$WORKTREE/$MARKER_REL"
  else
    rm -f "$WORKTREE/$MARKER_REL"
  fi
  git -C "$WORKTREE" reset -q HEAD -- "$MARKER_REL" "$EVIDENCE_REL" 2>/dev/null || true
fi

DIRTY=$(git -C "$WORKTREE" status --porcelain --untracked-files=all --ignore-submodules=all)
DIRTY=$(printf '%s\n' "$DIRTY" | awk '$0 != "?? .polylane-prompt.txt" && $0 != "?? graphify-out"')
[ -z "$DIRTY" ] || { echo "polylane-finalize: implementation/evidence must be committed before handoff" >&2; exit 1; }
IMPL_HEAD=$(git -C "$WORKTREE" rev-parse HEAD)
[ "$RECOVERING" = 1 ] || state_transition WORKING "$IMPL_HEAD"
state_transition HANDOFF_PENDING "$IMPL_HEAD"

mkdir -p "$WORKTREE/docs"
MARKER="STATUS: $LANE DONE run=$RUN_ID"
MARKER_TMP=$(mktemp "$WORKTREE/docs/.status-${LANE}.XXXXXX")
printf '%s\n' "$MARKER" > "$MARKER_TMP"
mv "$MARKER_TMP" "$WORKTREE/$MARKER_REL"
[ "${POLYLANE_FINALIZE_INTERRUPT:-}" != after-marker ] || exit 75

if [ "$ROLE" = integrator ]; then
  VERDICT_TMP=$(mktemp "$WORKTREE/docs/.verify-integration.XXXXXX")
  awk -v run="$RUN_ID" '
    $0 ~ "^[[:space:]]*POLYLANE-VERDICT:.*[[:space:]]run=" run "[[:space:]]*$" { next }
    { print }
  ' "$WORKTREE/$EVIDENCE_REL" > "$VERDICT_TMP"
  printf 'POLYLANE-VERDICT: %s run=%s\n' "$VERDICT" "$RUN_ID" >> "$VERDICT_TMP"
  mv "$VERDICT_TMP" "$WORKTREE/$EVIDENCE_REL"
fi

git -C "$WORKTREE" add -f -- "$MARKER_REL"
[ "$ROLE" != integrator ] || git -C "$WORKTREE" add -f -- "$EVIDENCE_REL"
STAGED=$(git -C "$WORKTREE" diff --cached --name-only)
printf '%s\n' "$STAGED" | awk -v marker="$MARKER_REL" -v evidence="$EVIDENCE_REL" \
  'NF && $0!=marker && $0!=evidence { bad=1 } END { exit bad }' || exit 1
git -C "$WORKTREE" commit -qm "polylane: finalize $LANE handoff run=$RUN_ID" -- "$MARKER_REL" "$EVIDENCE_REL"
HANDOFF_HEAD=$(git -C "$WORKTREE" rev-parse HEAD)
[ "$(git -C "$WORKTREE" show "HEAD:$MARKER_REL")" = "$MARKER" ] || exit 1
[ "$(git -C "$WORKTREE" show "HEAD:$MARKER_REL" | wc -l | tr -d ' ')" = 1 ] || exit 1
if [ "$ROLE" = integrator ]; then
  LAST=$(git -C "$WORKTREE" show "HEAD:$EVIDENCE_REL" | tail -n 1)
  [ "$LAST" = "POLYLANE-VERDICT: $VERDICT run=$RUN_ID" ] || exit 1
  [ "$(git -C "$WORKTREE" show "HEAD:$EVIDENCE_REL" | grep -Ec "^[[:space:]]*POLYLANE-VERDICT:.*[[:space:]]run=${RUN_ID}[[:space:]]*$")" = 1 ] || exit 1
fi
DIRTY=$(git -C "$WORKTREE" status --porcelain --untracked-files=all --ignore-submodules=all)
DIRTY=$(printf '%s\n' "$DIRTY" | awk '$0 != "?? .polylane-prompt.txt" && $0 != "?? graphify-out"')
[ -z "$DIRTY" ] || exit 1
MARKER_SHA=$(sha256_file "$WORKTREE/$MARKER_REL")
VERDICT_SHA=""
[ "$ROLE" != integrator ] || VERDICT_SHA=$(sha256_file "$WORKTREE/$EVIDENCE_REL")
state_transition HANDOFF_COMMITTED "$HANDOFF_HEAD" "$MARKER_SHA" "$VERDICT_SHA"
printf 'HANDOFF_COMMITTED lane=%s run=%s head=%s\n' "$LANE" "$RUN_ID" "$HANDOFF_HEAD"
