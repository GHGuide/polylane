#!/usr/bin/env bash
#
# polylane-digest.sh <baseline-ref> [repo-root]
#
# Read-only. Dumps a raw change inventory since <baseline-ref> — commits, diffstat,
# new files, and per-lane verify summaries — for the polylane-max orchestrator to
# condense into a ~50-bullet "what this cycle made" report. Never edits anything.
#
# bash-3.2 safe.

set -euo pipefail

usage() { echo "usage: polylane-digest.sh <baseline-ref> [repo-root]" >&2; exit 2; }
[ $# -ge 1 ] || usage
case "$1" in -h|--help) usage ;; esac

BASE="$1"
ROOT="${2:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT" || { echo "polylane-digest: cannot cd $ROOT" >&2; exit 1; }

git rev-parse --verify "$BASE" >/dev/null 2>&1 || {
  echo "polylane-digest: unknown baseline ref '$BASE'" >&2; exit 1; }

echo "# Change inventory since $BASE  (repo: $ROOT)"
echo

echo "## Commits"
git log --oneline "$BASE"..HEAD 2>/dev/null || echo "(none)"
echo

echo "## Files changed (diffstat)"
git diff --stat "$BASE"..HEAD 2>/dev/null || echo "(none)"
echo

echo "## New files"
git diff --name-status "$BASE"..HEAD 2>/dev/null | awk '$1=="A"{print "  + "$2}' || true
echo

echo "## Verify-file summaries (evidence per lane)"
found=0
for f in docs/verify-*.md; do
  [ -f "$f" ] || continue
  found=1
  echo "### $f"
  grep -v '^[[:space:]]*$' "$f" 2>/dev/null | head -3
  grep -hiE 'PASS|GO\b|DONE|shipped|added|fixed|implemented' "$f" 2>/dev/null | head -6
  echo
done
[ "$found" = "1" ] || echo "(no docs/verify-*.md present)"

echo "## Report (if the run wrote one)"
[ -f docs/polylane-report.md ] && sed -n '1,40p' docs/polylane-report.md || echo "(no docs/polylane-report.md)"
