#!/usr/bin/env bash
# polylane-outcomes.sh — cross-run lane-outcome memory keyed by a mechanical lane-shape
# signature, so the recurring CARVING mistake (two lanes both needing the router / global
# CSS / entrypoint) becomes a free pre-spend static check, and model choice stops being
# re-decided from scratch every cycle.
#
# Signature: b<n_globs>:hub<k>:crowd<0|1>
#   n_globs = count of own_globs ; k = how many match the learned hub registry ;
#   crowd   = 1 iff any glob spans a broad dir (contains ** or a bare top-level *)
#
# Stores (default docs/polylane/outcomes.jsonl + docs/polylane/hubs.txt):
#   record <lane> <sig> <model> <verdict>      append one lane outcome
#   predict <manifest>                         RISK <lane> <pct> <hub-reason>; exit 5 over threshold
#   tune <sig>                                 cheapest model that historically cleared this shape
#   hub add <path> | hub list                  manage the hub-file registry
# Pure bash-3.2 + jq; main-guarded.
set -euo pipefail
command -v jq >/dev/null 2>&1 || { echo "polylane-outcomes: jq required" >&2; exit 1; }

OUT_F="${POLYLANE_OUTCOMES:-docs/polylane/outcomes.jsonl}"
HUB_F="${POLYLANE_HUBS:-docs/polylane/hubs.txt}"
RISK_THRESHOLD="${POLYLANE_RISK_THRESHOLD:-50}"   # percent NO-GO above which predict trips
RISK_MIN_SAMPLES="${POLYLANE_RISK_MIN_SAMPLES:-2}"   # need >= this many outcomes before a shape is "risky" (else UNKNOWN, not flagged)

_hubs() { [ -s "$HUB_F" ] && grep -v '^[[:space:]]*$' "$HUB_F" || true; }

# _count SIG : how many recorded outcomes exist for this shape (0 if none / no file).
_count() {
  [ -s "$OUT_F" ] || { printf '0'; return; }
  jq -s --arg s "$1" 'map(select(.sig==$s)) | length' "$OUT_F"
}

# signature GLOB... -> b<n>:hub<k>:crowd<0|1>
signature() {
  local n=0 k=0 crowd=0 g hub
  for g in "$@"; do
    n=$((n+1))
    case "$g" in *'**'*|*/'*'|'*'/*|'*') crowd=1 ;; esac
    while IFS= read -r hub; do
      [ -z "$hub" ] && continue
      case "$g" in *"$hub"*) k=$((k+1)); break ;; esac
    done <<EOF
$(_hubs)
EOF
  done
  printf 'b%s:hub%s:crowd%s' "$n" "$k" "$crowd"
}

record() {
  local lane="$1" sig="$2" model="$3" verdict="$4" ts
  ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo "?")
  mkdir -p "$(dirname "$OUT_F")" 2>/dev/null || true
  jq -cn --arg l "$lane" --arg s "$sig" --arg m "$model" --arg v "$verdict" --arg t "$ts" \
    '{lane:$l,sig:$s,model:$m,verdict:$v,ts:$t}' >> "$OUT_F"
}

# Laplace-smoothed NO-GO rate for a signature (percent, integer)
_nogo_pct() {
  local sig="$1"
  [ -s "$OUT_F" ] || { printf '0'; return; }
  jq -s --arg s "$sig" '
    map(select(.sig==$s)) as $m
    | ($m|length) as $n
    | ($m|map(select(.verdict=="NO-GO"))|length) as $bad
    | (100 * ($bad+1) / ($n+2)) | floor' "$OUT_F"
}

predict() {
  local mf="$1" lane sig pct rc=0 globs hub reason
  for lane in $(jq -r '.lanes[].name' "$mf"); do
    globs=$(jq -r --arg n "$lane" '.lanes[]|select(.name==$n)|.own_globs[]?' "$mf")
    # shellcheck disable=SC2086
    sig=$(signature $globs)
    # an UNSEEN/thinly-seen shape is UNKNOWN, not risky — needs real history to flag
    # (else the Laplace prior alone reports ~50% and trips the gate on brand-new shapes).
    [ "$(_count "$sig")" -ge "$RISK_MIN_SAMPLES" ] || continue
    pct=$(_nogo_pct "$sig")
    reason="shape $sig"
    for hub in $(_hubs); do
      printf '%s\n' "$globs" | grep -qF "$hub" && { reason="hub file '$hub'"; break; }
    done
    if [ "$pct" -ge "$RISK_THRESHOLD" ]; then
      echo "RISK $lane ${pct}% ($reason)"; rc=5
    fi
  done
  return $rc
}

# tune SIG : cheapest model (haiku<sonnet<opus<fable) that has EVER cleared this shape.
tune() {
  local sig="$1"
  [ -s "$OUT_F" ] || { echo "claude-haiku-4-5"; return; }
  local winner
  winner=$(jq -rs --arg s "$sig" '
    def rank: {"claude-haiku-4-5":1,"claude-sonnet-5":2,"claude-opus-4-8":3,"claude-fable-5":4};
    map(select(.sig==$s and .verdict=="GO"))
    | map(.model) | unique
    | sort_by(rank[.] // 99) | .[0] // empty' "$OUT_F")
  [ -n "$winner" ] && printf '%s\n' "$winner" || echo "claude-sonnet-5"
}

hub() {
  case "${1:-}" in
    add) mkdir -p "$(dirname "$HUB_F")" 2>/dev/null || true
         grep -qxF "${2:?hub add <path>}" "$HUB_F" 2>/dev/null || printf '%s\n' "$2" >> "$HUB_F" ;;
    list) _hubs ;;
    *) echo "usage: polylane-outcomes.sh hub add <path> | hub list" >&2; return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "${0}" ]; then
  case "${1:-}" in
    record)  shift; record "$@" ;;
    predict) shift; predict "$@" ;;
    tune)    shift; tune "$@" ;;
    hub)     shift; hub "$@" ;;
    signature) shift; signature "$@" ;;
    *) echo "usage: polylane-outcomes.sh record <lane> <sig> <model> <verdict> | predict <manifest> | tune <sig> | hub add|list" >&2; exit 2 ;;
  esac
fi
