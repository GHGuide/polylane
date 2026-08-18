#!/usr/bin/env bash
#
# polylane-models.sh — print available agent model ids, one per line.
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
#   bin/polylane-models.sh codex --tiers # supported tier order
#   -h | --help                     # usage, exit 0

set -uo pipefail

# Curated fallback — the models polylane tunes against, newest-family first.
FALLBACK=(claude-fable-5 claude-opus-5 claude-opus-4-8 claude-sonnet-5 claude-haiku-4-5)
CODEX_FALLBACK="gpt-5.6-terra"
CODEX_TIERS=$'gpt-5.6-luna\ngpt-5.6-terra\ngpt-5.6-sol'

usage() {
  cat <<'EOF'
polylane-models.sh — print available Claude model ids, one per line.

USAGE:
  bin/polylane-models.sh [claude|codex] [--tiers]
                                  print models for the selected agent
  codex --tiers                   print supported Codex tiers in rank order
  -h, --help                      show this help and exit 0

Probes https://api.anthropic.com/v1/models when ANTHROPIC_API_KEY is set and
curl+jq exist. On any failure (no key, no tool, network/HTTP error, empty
result) it prints the curated fallback list. Always exits 0.
EOF
}

fallback() {
  # stderr marker lets automation tell a live probe from a curated guess;
  # stdout stays pure model ids for manifest generators.
  echo "MODELS-FALLBACK: curated list (no live probe)" >&2
  printf '%s\n' "${FALLBACK[@]}"
}

codex_models() {
  local cache ids max_days
  cache="${POLYLANE_CODEX_MODELS_CACHE:-${CODEX_HOME:-$HOME/.codex}/models_cache.json}"
  if [ -f "$cache" ] && command -v jq >/dev/null 2>&1; then
    # Real codex-cli caches store launchable ids under .models[].slug (the .id
    # field holds unrelated strings like "priority"); some older caches used
    # .models[].id. Read slug first, fall back to id, and keep only gpt/codex
    # ids so a stray field or a claude id never becomes a launch target.
    ids=$(jq -r '.models[]? | (.slug? // .id? // empty)' "$cache" 2>/dev/null \
      | awk '/^(gpt|codex)-[[:alnum:]._-]+$/ && !seen[$0]++')
    if [ -n "$ids" ]; then
      # A stale cache silently pins vanished models; find -mtime is BSD+GNU safe.
      max_days="${POLYLANE_MODELS_MAX_AGE_DAYS:-30}"
      if [ -n "$(find "$cache" -mtime +"$max_days" 2>/dev/null)" ]; then
        echo "MODELS-STALE: cache older than ${max_days}d — run codex once to refresh" >&2
      fi
      printf '%s\n' "$ids"
      return 0
    fi
  fi
  printf '%s\n' "$CODEX_FALLBACK"
}

main() {
  case "${1:-}:${2:-}" in
    -h:*|--help:*) usage; exit 0 ;;
    codex:--tiers) printf '%s\n' "$CODEX_TIERS"; return 0 ;;
    codex:*) codex_models; return 0 ;;
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
