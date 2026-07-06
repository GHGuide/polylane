#!/usr/bin/env bash
#
# polylane-models.sh — print available Claude model ids, one per line.
#
# Probes the Anthropic /v1/models API when ANTHROPIC_API_KEY is set and curl+jq
# are available; on missing key, missing tool, network/HTTP failure, or empty
# result it prints a curated fallback list instead. Best-effort: always prints
# at least the fallback ids and exits 0.
#
# Consumed by the `polylane` skill to fill the manifest's "available_models".
# See .polylane/SCHEMA.md.
#
#   bin/polylane-models.sh          # one model id per line, exit 0
#   -h | --help                     # usage, exit 0

set -uo pipefail

# Curated fallback — the models polylane tunes against, newest-family first.
FALLBACK=(claude-fable-5 claude-opus-4-8 claude-sonnet-5 claude-haiku-4-5)

usage() {
  cat <<'EOF'
polylane-models.sh — print available Claude model ids, one per line.

USAGE:
  bin/polylane-models.sh          probe the Anthropic API, else print fallback
  -h, --help                      show this help and exit 0

Probes https://api.anthropic.com/v1/models when ANTHROPIC_API_KEY is set and
curl+jq exist. On any failure (no key, no tool, network/HTTP error, empty
result) it prints the curated fallback list. Always exits 0.
EOF
}

fallback() { printf '%s\n' "${FALLBACK[@]}"; }

main() {
  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
  esac

  # No key or missing tooling → fallback.
  if [ -z "${ANTHROPIC_API_KEY:-}" ] \
     || ! command -v curl >/dev/null 2>&1 \
     || ! command -v jq  >/dev/null 2>&1; then
    fallback
    return 0
  fi

  # Probe. --fail makes HTTP errors non-zero (→ empty → fallback); --max-time
  # keeps a hung endpoint from stalling the caller.
  local ids
  ids=$(curl -s --fail --max-time 10 https://api.anthropic.com/v1/models \
          -H "x-api-key: $ANTHROPIC_API_KEY" \
          -H "anthropic-version: 2023-06-01" 2>/dev/null \
        | jq -r '.data[].id' 2>/dev/null)

  if [ -n "$ids" ]; then
    printf '%s\n' "$ids"
  else
    fallback
  fi
}

main "$@"
