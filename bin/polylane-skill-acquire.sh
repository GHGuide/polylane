#!/usr/bin/env bash
# polylane-skill-acquire.sh — project-scoped, evidence-backed skill admission.
set -euo pipefail

usage() {
  echo "usage: polylane-skill-acquire.sh audit|benchmark|admit|rollback ..." >&2
}

audit_write() {
  local output="$1" status="$2" reason="$3" candidate="$4" source="$5"
  mkdir -p "$(dirname "$output")"
  jq -n --arg status "$status" --arg reason "$reason" --arg candidate "$candidate" \
    --slurpfile source "$source" '{schema:1,status:$status,reason:$reason,candidate:$candidate,source:$source[0]}' > "$output"
}

unsafe_content_reason() {
  local candidate="$1" source="$2"
  if find "$candidate" -type l -print -quit | grep -q .; then printf '%s\n' symlink; return; fi
  if find "$candidate" -type f -perm -111 -print -quit | grep -q .; then printf '%s\n' executable-file; return; fi
  while IFS= read -r file; do
    grep -Iq '' "$file" || { printf '%s\n' binary; return; }
  done < <(find "$candidate" -type f -print | LC_ALL=C sort)
  if find "$candidate" -type f \( -name 'install.sh' -o -name 'postinstall.sh' -o -name 'preinstall.sh' \) -print -quit | grep -q . ||
     grep -RInE '"(preinstall|install|postinstall|prepare)"[[:space:]]*:' "$candidate" >/dev/null 2>&1; then
    printf '%s\n' install-hook; return
  fi
  if grep -RInE 'BEGIN( RSA| OPENSSH)? ?PRIVATE KEY|AKIA[0-9A-Z]{16}|api[_-]?key[[:space:]]*[:=]|password[[:space:]]*[:=]' "$candidate" >/dev/null 2>&1; then
    printf '%s\n' secret-material; return
  fi
  if grep -RInEi 'ignore (all |any |the )?(previous|above) instructions|system prompt|higher[- ]authority|developer message|you are now' "$candidate" >/dev/null 2>&1; then
    printf '%s\n' prompt-injection; return
  fi
  if grep -RInE 'rm[[:space:]]+-[A-Za-z]*r|git[[:space:]]+reset[[:space:]]+--hard|mkfs|dd[[:space:]]+if=|:[[:space:]]*\(\)[[:space:]]*\{' "$candidate" >/dev/null 2>&1; then
    printf '%s\n' destructive-command; return
  fi
  if grep -RInE '(^|[[:space:]])(sudo|chmod[[:space:]]+777)|>[[:space:]]*(/|~|\$HOME)|(/etc/|/usr/local/)' "$candidate" >/dev/null 2>&1; then
    printf '%s\n' broad-host-write; return
  fi
  if grep -RInE '\b(curl|wget|nc|ssh)[[:space:]]' "$candidate" >/dev/null 2>&1 &&
     ! jq -e '.network_justification | type == "string" and length > 0' "$source" >/dev/null 2>&1; then
    printf '%s\n' unexplained-network; return
  fi
  printf '%s\n' ''
}

audit_candidate() {
  local candidate="$1" source="$2" output="$3" reason
  [ -d "$candidate" ] && [ ! -L "$candidate" ] || { echo "ACQUIRE: candidate must be a real directory" >&2; return 2; }
  jq -e '
    (.id | type == "string" and test("^[A-Za-z0-9._-]+$"))
    and (.repository | type == "string" and test("^https://"))
    and (.revision | type == "string" and test("^[0-9a-fA-F]{40,64}$"))
    and (.license | type == "string" and length > 0)
    and (.authorized == true)
  ' "$source" >/dev/null 2>&1 || { audit_write "$output" failed unresolved-source "$candidate" "$source"; return 1; }
  [ -f "$candidate/SKILL.md" ] && [ -f "$candidate/LICENSE" ] || {
    audit_write "$output" failed missing-skill-or-license "$candidate" "$source"; return 1;
  }
  reason=$(unsafe_content_reason "$candidate" "$source")
  if [ -n "$reason" ]; then
    audit_write "$output" failed "$reason" "$candidate" "$source"
    return 1
  fi
  audit_write "$output" passed admitted-for-benchmark "$candidate" "$source"
}

benchmark_candidate() {
  local fixture="$1" output="$2" status=failed reason=invalid-benchmark
  jq -e '
    (.fixture_id | type == "string" and length > 0)
    and (.minimum_improvement | type == "number" and . > 0)
    and all([.without_candidate, .with_candidate][];
      type == "object" and (.score | type == "number") and (.accessibility | type == "number"))
  ' "$fixture" >/dev/null 2>&1 || {
    jq -n --arg status "$status" --arg reason "$reason" '{schema:1,status:$status,reason:$reason}' > "$output"; return 1;
  }
  if jq -e '(.with_candidate.score - .without_candidate.score) >= .minimum_improvement and .with_candidate.accessibility >= .without_candidate.accessibility' "$fixture" >/dev/null; then
    status=passed; reason=measurable-improvement
  else
    reason=no-improvement-or-accessibility-regression
  fi
  jq --arg status "$status" --arg reason "$reason" '
    {schema:1,status:$status,reason:$reason,fixture_id,
     without_candidate,with_candidate,minimum_improvement,
     improvement:(.with_candidate.score - .without_candidate.score),
     accessibility_delta:(.with_candidate.accessibility - .without_candidate.accessibility)}
  ' "$fixture" > "$output"
  [ "$status" = passed ]
}

hashes_json() {
  local candidate="$1"
  (
    cd "$candidate"
    find . -type f -print | LC_ALL=C sort | while IFS= read -r file; do
      printf '%s\t%s\n' "${file#./}" "$(cksum "$file" | awk '{print $1 "-" $2}')"
    done
  ) | jq -Rn '[inputs | split("\t") | {path:.[0],hash:.[1]}]'
}

admit_candidate() {
  local project="$1" candidate="$2" source="$3" fixture="$4" id quarantine audit benchmark install_root dest lock rollback hashes
  [ -d "$project" ] && [ ! -L "$project" ] || { echo "ACQUIRE: project must be a real directory" >&2; return 2; }
  id=$(jq -r '.id // ""' "$source" 2>/dev/null) || return 2
  case "$id" in ''|*[!A-Za-z0-9._-]*) echo "ACQUIRE: invalid skill id" >&2; return 2 ;; esac
  quarantine=$(mktemp -d "${TMPDIR:-/tmp}/polylane-skill.XXXXXX") || return 1
  trap 'rm -rf "$quarantine"' RETURN
  cp -R "$candidate" "$quarantine/content"
  audit="$quarantine/audit.json"; benchmark="$quarantine/benchmark.json"
  audit_candidate "$quarantine/content" "$source" "$audit" || { trap - RETURN; rm -rf "$quarantine"; return 1; }
  benchmark_candidate "$fixture" "$benchmark" || { trap - RETURN; rm -rf "$quarantine"; return 1; }
  install_root="$project/.polylane/skills"; dest="$install_root/$id"
  [ ! -e "$dest" ] || { echo "ACQUIRE: skill already admitted: $id" >&2; trap - RETURN; rm -rf "$quarantine"; return 1; }
  mkdir -p "$install_root"
  cp -R "$quarantine/content" "$dest"
  hashes=$(hashes_json "$dest")
  lock="$project/docs/polylane/design/SKILL-LOCK.json"; rollback="$project/.polylane/skill-rollback/$id"
  mkdir -p "$(dirname "$lock")" "$(dirname "$rollback")"
  [ -f "$lock" ] || printf '%s\n' '{"schema":1,"skills":[]}' > "$lock"
  jq --arg id "$id" --arg installed "$dest" --arg rollback "$rollback" --argjson hashes "$hashes" \
    --slurpfile audit "$audit" --slurpfile benchmark "$benchmark" '
      .schema = 1 | .skills = (.skills // [])
      | .skills += [{id:$id,status:"admitted",installed_path:$installed,rollback_path:$rollback,
          revision:$audit[0].source.revision,repository:$audit[0].source.repository,
          license:$audit[0].source.license,authorization:{authorized:$audit[0].source.authorized},
          rollback_ready:true,hashes:$hashes,audit:$audit[0],benchmark:$benchmark[0]}]
    ' "$lock" > "$lock.tmp" && mv "$lock.tmp" "$lock"
  trap - RETURN
  rm -rf "$quarantine"
}

rollback_skill() {
  local project="$1" id="$2" dest rollback lock
  case "$id" in ''|*[!A-Za-z0-9._-]*) echo "ACQUIRE: invalid skill id" >&2; return 2 ;; esac
  dest="$project/.polylane/skills/$id"; rollback="$project/.polylane/skill-rollback/$id"; lock="$project/docs/polylane/design/SKILL-LOCK.json"
  [ -d "$dest" ] && [ ! -L "$dest" ] || { echo "ACQUIRE: admitted skill does not exist: $id" >&2; return 1; }
  mkdir -p "$(dirname "$rollback")"
  [ ! -e "$rollback" ] || { echo "ACQUIRE: rollback evidence already exists: $id" >&2; return 1; }
  mv "$dest" "$rollback"
  jq --arg id "$id" '(.skills // []) |= map(if .id == $id then .status="rolled_back" else . end)' "$lock" > "$lock.tmp" && mv "$lock.tmp" "$lock"
}

main() {
  case "${1:-}" in
    audit) [ $# -eq 4 ] || { usage; return 2; }; audit_candidate "$2" "$3" "$4" ;;
    benchmark) [ $# -eq 3 ] || { usage; return 2; }; benchmark_candidate "$2" "$3" ;;
    admit) [ $# -eq 5 ] || { usage; return 2; }; admit_candidate "$2" "$3" "$4" "$5" ;;
    rollback) [ $# -eq 3 ] || { usage; return 2; }; rollback_skill "$2" "$3" ;;
    *) usage; return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
