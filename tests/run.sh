#!/usr/bin/env bash
# tests/run.sh — run every tests/test-*.sh, print per-test PASS/FAIL + summary.
# Plain bash-3.2, no framework. Exit 0 iff every test in every file passes.

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"

total_pass=0
total_fail=0
files=0
failed_files=""

for t in "$TESTS_DIR"/test-*.sh; do
  [ -f "$t" ] || continue
  files=$((files + 1))
  name=$(basename "$t")
  echo "== $name =="
  out=$("${BASH:-bash}" "$t" 2>&1)
  rc=$?
  printf '%s\n' "$out"
  p=$(printf '%s\n' "$out" | grep -c '^PASS ')
  f=$(printf '%s\n' "$out" | grep -c '^FAIL ')
  total_pass=$((total_pass + p))
  total_fail=$((total_fail + f))
  if [ "$rc" -ne 0 ] || [ "$f" -gt 0 ]; then
    failed_files="$failed_files $name"
  fi
  echo
done

if [ "$files" -eq 0 ]; then
  echo "SUMMARY: no test files found in $TESTS_DIR"
  exit 1
fi

echo "SUMMARY: $total_pass passed, $total_fail failed, $files test files"
if [ -n "$failed_files" ]; then
  echo "FAILED FILES:$failed_files"
  exit 1
fi
exit 0
