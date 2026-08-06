#!/usr/bin/env bash
# test-docs-truth.sh — the docs must not lie.
#
# Proves that the paths, scripts, flags, and install commands the README,
# AGENTS.md, and references/install-helpers.md quote are REAL: files exist,
# scripts are executable, flags are handled, and the install paths don't drift
# between the primary doc and the reference. Hermetic — no network, no installs;
# we verify that what the docs point at EXISTS, never run it.
#
# When a doc lies (a promised file/script/anchor is absent) this test fails RED
# on purpose — that is the signal for the next cycle to fix the doc, not for
# this test to be weakened. See docs/parallel-status.md for any live lie.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

REPO="$(cd "$TESTS_DIR/.." && pwd)"
README="$REPO/README.md"
AGENTS="$REPO/AGENTS.md"
HELP="$REPO/references/install-helpers.md"
SKILL="$REPO/SKILL.md"

# --- 1. every repo path the README fenced blocks point at exists --------------
# The Quickstart runs ./codex/install.sh; the body links the reference + LICENSE.
# (Runtime outputs like docs/polylane-report.md are generated, not committed —
#  they are deliberately not asserted here.)
for rel in codex/install.sh references/install-helpers.md LICENSE; do
  if [ -e "$REPO/$rel" ]; then pass "readme-path:$rel"
  else fail "readme-path:$rel" "README references $rel but it is missing"; fi
done
# The install flag the Quickstart uses (--user) must be a real flag.
if grep -qF -- '--user' "$REPO/codex/install.sh"; then pass "readme-flag:codex-install--user"
else fail "readme-flag:codex-install--user" "README runs 'codex/install.sh --user' but the script has no --user"; fi

# --- 2. every bin/polylane-*.sh named in README or AGENTS.md is real+executable
# Bare 'polylane-run.sh' etc. map to bin/<name>. Grep tolerates a missing
# AGENTS.md (empty match) so section 3 owns that failure, not this one.
scripts=$(cat "$README" "$AGENTS" 2>/dev/null \
  | grep -oE '(bin/)?polylane-[a-z-]+\.sh' | sed 's#^bin/##' | sort -u)
for s in $scripts; do
  f="$REPO/bin/$s"
  if [ -f "$f" ] && [ -x "$f" ]; then pass "bin-exec:$s"
  else fail "bin-exec:$s" "doc names bin/$s but it is missing or not executable"; fi
done

# --- 3. AGENTS.md is the cross-agent context anchor SKILL.md promises ---------
# SKILL.md certifies a shippable repo carries a root AGENTS.md with real
# run/build/test commands. polylane is self-hosting, so its own root must too.
# Absent today -> RED on purpose (a lie SKILL.md tells about itself).
if [ -s "$AGENTS" ]; then pass "agents-md-present"
else fail "agents-md-present" "no root AGENTS.md — SKILL.md requires a shippable repo to have one (self-hosting lie; fix next cycle)"; fi
if [ -f "$AGENTS" ] && grep -qF 'tests/run.sh' "$AGENTS"; then pass "agents-md-cites-runsh"
else fail "agents-md-cites-runsh" "AGENTS.md must cite the real test command tests/run.sh"; fi
# ...and the command it must cite genuinely exists and runs.
if [ -f "$REPO/tests/run.sh" ] && [ -x "$REPO/tests/run.sh" ]; then pass "runsh-exec"
else fail "runsh-exec" "tests/run.sh missing or not executable"; fi

# --- 4. install paths don't drift between README and the reference ------------
# The ~/.claude/skills/polylane clone line must be byte-identical in the primary
# doc (SKILL.md) and the reference; README's own install command + brew deps
# line must reappear verbatim in the reference too.
clone='git clone https://github.com/GHGuide/polylane ~/.claude/skills/polylane'
if grep -qF "$clone" "$HELP"; then pass "install-clone-in-reference"
else fail "install-clone-in-reference" "reference lost the ~/.claude/skills/polylane clone line"; fi
if grep -qF "$clone" "$SKILL"; then pass "install-clone-matches-skill"
else fail "install-clone-matches-skill" "SKILL.md clone line drifted from the reference"; fi
for phrase in 'codex/install.sh' 'brew install tmux jq'; do
  if grep -qF "$phrase" "$README" && grep -qF "$phrase" "$HELP"; then pass "no-drift:$phrase"
  else fail "no-drift:$phrase" "'$phrase' not verbatim in both README and install-helpers"; fi
done

# The canonical contract example declares a Codex agent, so every advertised
# model in that example must be a Codex model. A Claude id here gets copied into
# generated manifests even when the probe itself is correctly agent-aware.
schema_example=$(awk '/^```json$/{capture=1; next} capture && /^```$/{exit} capture' "$REPO/.polylane/SCHEMA.md")
if printf '%s\n' "$schema_example" | jq -e '
  .agent == "codex"
  and ([.available_models[], .integrator.model, .lanes[].model]
       | all(.[]; type == "string" and startswith("gpt-")))
' >/dev/null 2>&1; then
  pass "schema-codex-model-family"
else
  fail "schema-codex-model-family" "Codex manifest example contains a non-gpt model id"
fi

finish
