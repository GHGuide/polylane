#!/usr/bin/env bash
# polylane-certify.sh — named, repeatable cycle-integration certification.
# Focused mode is a fast, hermetic seam matrix. Terminal mode adds one fresh
# whole-suite, installation, ShellCheck, and supervised GO/NO-GO rehearsal.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

usage() {
  echo "usage: polylane-certify.sh focused|terminal" >&2
  exit 2
}

announce() { printf 'CERTIFY LAYER: %s\n' "$1"; }

tests() {
  local layer="$1" test
  shift
  announce "$layer"
  for test in "$@"; do bash "$ROOT/tests/$test"; done
}

command_layer() {
  local layer="$1"
  shift
  announce "$layer"
  "$@"
}

focused() {
  tests discovery \
    test-discovery-graph.sh \
    test-product-benchmark.sh
  tests planning/prompt \
    test-orchestration-contract.sh \
    test-promptopt.sh \
    test-promptlint.sh \
    test-prompt-compiler.sh \
    test-cycle-13-contract.sh
  tests model-policy \
    test-model-policy.sh \
    test-intensity.sh \
    test-models.sh
  tests skill-routing \
    test-scout.sh \
    test-scout-catalog.sh \
    test-scout-outcomes.sh \
    test-skill-acquire.sh
  tests graph/runtime/recovery \
    test-graph-authority.sh \
    test-runtime-recovery.sh \
    test-runtime-refresh.sh \
    test-runtime-survival.sh
  tests integration/learning \
    test-prime-hybrid-integration.sh \
    test-workers.sh \
    test-refine.sh \
    test-cycle.sh
  tests self-hosting-truth test-cycle-14-contract.sh
  tests install/parity test-skill-parity.sh
  command_layer ShellCheck shellcheck -S warning \
    "$ROOT/bin/polylane-run.sh" \
    "$ROOT/bin/polylane-model-policy.sh" \
    "$ROOT/bin/polylane-skill-catalog.sh" \
    "$ROOT/bin/polylane-hooks.sh" \
    "$ROOT/bin/polylane-certify.sh"
  announce 'rehearsal (terminal-only)'
}

terminal() {
  focused
  tests install/parity test-installers.sh test-install-fresh.sh
  command_layer ShellCheck shellcheck -S warning "$ROOT/bin/"*.sh
  command_layer rehearsal env POLYLANE_MIN_DISK_GB=0 bash "$ROOT/bin/polylane-doctor.sh" --rehearse
  command_layer integration/learning bash "$ROOT/tests/run.sh"
}

case "${1:-}" in
  focused) focused ;;
  terminal) terminal ;;
  *) usage ;;
esac
