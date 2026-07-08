#!/usr/bin/env bash
# abs_prompt PATH -> absolute paths pass through untouched; relative paths are
# anchored at PROJECT_ROOT (frozen contract — fixes the empty-pane seed bug).

. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
. "$RUNNER"

PROJECT_ROOT="/proj/root"

assert_eq "abs-passthrough"       "/abs/prompts/int.txt" "$(abs_prompt /abs/prompts/int.txt)"
assert_eq "abs-root-slash"        "/"                    "$(abs_prompt /)"
assert_eq "rel-anchored"          "/proj/root/.polylane/lanes/a.txt" "$(abs_prompt .polylane/lanes/a.txt)"
assert_eq "rel-bare-name"         "/proj/root/prompt.txt" "$(abs_prompt prompt.txt)"
assert_eq "rel-dot-prefix"        "/proj/root/./lanes/a.txt" "$(abs_prompt ./lanes/a.txt)"

# anchor follows PROJECT_ROOT, not cwd
PROJECT_ROOT="/elsewhere"
assert_eq "rel-follows-project-root" "/elsewhere/lanes/b.txt" "$(abs_prompt lanes/b.txt)"

finish
