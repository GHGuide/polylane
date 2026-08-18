#!/usr/bin/env bash
# test-codex-taste-install.sh — prove a FRESH clean install of the Codex skill is
# actually runnable, not merely present. Everything happens under a throwaway
# $HOME; the real ~/.codex and ~/.agents are never touched.
#
# This lane owns the CODEX-SPECIFIC install guarantees:
#   1. every installed Markdown doc link resolves from the package root (the
#      `../references/` source form 404s once SKILL.md and references/ are siblings);
#   2. the focused visual/taste helpers execute from where they were installed;
#   3. installed helper + protocol bytes hash-match the repository source, and both
#      discovery roots ship byte-identical copies of them.
# Shared installer rollback / stale-removal cases live in test-install-fresh.sh
# (owned by provider-hooks); this file does not duplicate them.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

REPO="$(cd "$TESTS_DIR/.." && pwd)"
command -v jq >/dev/null 2>&1 || { pass "codex-taste-install-skipped-no-jq"; finish; exit; }
make_tmpdir

# hashof FILE — content hash for byte-identity proof (sha256 preferred, cksum fallback).
hashof() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  else cksum "$1" | awk '{print $1 ":" $2}'; fi
}

# --- fresh install into BOTH discovery roots ---------------------------------
HOME_DIR="$TEST_TMPDIR/fresh-home"
mkdir -p "$HOME_DIR/.codex/skills" "$HOME_DIR/.agents/skills"
assert_ok "codex-taste-install" env HOME="$HOME_DIR" bash "$REPO/codex/install.sh" --user

CODEX_ROOT="$HOME_DIR/.codex/skills/polylane"
AGENTS_ROOT="$HOME_DIR/.agents/skills/polylane"
assert_ok "codex-taste-codex-root"  test -f "$CODEX_ROOT/SKILL.md"
assert_ok "codex-taste-agents-root" test -f "$AGENTS_ROOT/SKILL.md"

# --- 1. every installed doc link resolves from the package root --------------
link_fail=0
for link in $(grep -oE '\]\(([a-zA-Z0-9._/-]+\.md)\)' "$CODEX_ROOT/SKILL.md" | sed 's/](//; s/)//'); do
  case "$link" in
    /*|*..*) fail "codex-taste-link-$link" "escapes package root"; link_fail=1 ;;
    *) test -f "$CODEX_ROOT/$link" || { fail "codex-taste-link-$link" "unresolved"; link_fail=1; } ;;
  esac
done
assert_ok "codex-taste-no-dotdot-link" sh -c "! grep -q '](\.\./' '$CODEX_ROOT/SKILL.md'"
[ "$link_fail" -eq 0 ] && pass "codex-taste-links-resolve"

# --- 2. focused visual/taste helpers execute from the installed package ------
# No-arg invocation must reach the arg parser and print its own usage banner
# (fail-closed, non-zero rc). That proves the installed copy runs end to end,
# not just that the file exists.
TASTE_HELPERS="polylane-visual polylane-visual-quality polylane-taste \
polylane-taste-pixels polylane-promptlint polylane-taste-ballot polylane-taste-stats"
for h in $TASTE_HELPERS; do
  installed="$CODEX_ROOT/scripts/$h.sh"
  if [ ! -x "$installed" ]; then fail "codex-taste-run-$h" "not installed executable"; continue; fi
  assert_ok "codex-taste-syntax-$h" bash -n "$installed"
  out="$(bash "$installed" </dev/null 2>&1)"; rc=$?
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi "usage: $h"; then
    pass "codex-taste-run-$h"
  else
    fail "codex-taste-run-$h" "no usage banner (rc=$rc)"
  fi
done

# --- 3. installed helper + protocol bytes match source, both roots identical --
PROTOCOL="references/visual-intelligence.md references/prompt-blocks.md"
for h in $TASTE_HELPERS; do
  src="$REPO/bin/$h.sh"; ins="$CODEX_ROOT/scripts/$h.sh"; agt="$AGENTS_ROOT/scripts/$h.sh"
  assert_eq "codex-taste-hash-src-$h"  "$(hashof "$src")" "$(hashof "$ins")"
  assert_eq "codex-taste-hash-both-$h" "$(hashof "$ins")" "$(hashof "$agt")"
done
for p in $PROTOCOL; do
  base="$(basename "$p")"
  assert_eq "codex-taste-protocol-src-$base"  "$(hashof "$REPO/$p")"        "$(hashof "$CODEX_ROOT/$p")"
  assert_eq "codex-taste-protocol-both-$base" "$(hashof "$CODEX_ROOT/$p")"  "$(hashof "$AGENTS_ROOT/$p")"
done

finish
