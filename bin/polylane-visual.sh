#!/usr/bin/env bash
# polylane-visual.sh — deterministic visual-work detection and packet gates.
set -euo pipefail

usage() {
  echo "usage: polylane-visual.sh detect|prepare|validate <manifest> [references.json]" >&2
}

# --- content-addressing helpers (schema 2) --------------------------------
# Canonicalization is fixed so external producers and this validator agree:
#   text leaf  -> sha256(exact bytes, no trailing newline)   [jq -j]
#   object/arr -> sha256(compact, sorted keys, no newline)    [jq -cS | tr -d]
sha256_hex() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'
  else echo "VISUAL: no sha256 tool" >&2; return 2; fi
}
file_sha256() { sha256_hex < "$1"; }
text_hash()  { jq -j "$2" "$1" | sha256_hex; }
canon_hash() { jq -cS "$2" "$1" | tr -d '\n' | sha256_hex; }

detect_ui() {
  local manifest="$1" evidence
  [ -f "$manifest" ] || { echo "VISUAL: manifest does not exist: $manifest" >&2; return 2; }
  command -v jq >/dev/null 2>&1 || { echo "VISUAL: jq required" >&2; return 2; }
  evidence=$(jq -r '[.lanes[]? | (.name // ""), (.activity // ""), (.own_globs[]? // "")] | join(" ")' "$manifest")
  case "$evidence" in
    *ui*|*UI*|*visual*|*Visual*|*.css*|*.tsx*|*.jsx*|*.vue*|*.svelte*|*component*) printf '%s\n' ui ;;
    *) printf '%s\n' non-ui ;;
  esac
}

project_root_for_manifest() {
  local manifest="$1" manifest_dir
  manifest_dir=$(cd "$(dirname "$manifest")" && pwd -P) || return 1
  case "$manifest_dir" in
    */.polylane) dirname "$manifest_dir" ;;
    *) printf '%s\n' "$manifest_dir" ;;
  esac
}

packet_path_for_manifest() {
  local root
  root=$(project_root_for_manifest "$1") || return 1
  printf '%s/docs/polylane/design/references.json\n' "$root"
}

valid_packet_shape() {
  local packet="$1" relevant_required
  jq -e '
    . as $packet
    | ($packet.references | map(.id)) as $reference_ids
    | ($packet.directions | map(.id)) as $direction_ids
    | $packet.winner as $winner
    | .schema == 1
    and (.intensity | IN("economy", "balanced", "max"))
    and (.references | type == "array")
    and ($reference_ids | length == (unique | length))
    and ([.references[] | select(.kind == "wildcard")] | length == 1)
    and (.directions | type == "array" and length == 3)
    and ($direction_ids | length == (unique | length))
    and (.council | type == "array" and length == 3)
    and ([.council[].direction] | sort == ($direction_ids | sort))
    and (.winner | type == "string" and ($direction_ids | index($winner)) != null)
    and all(.references[];
      (.id | type == "string" and length > 0)
      and (.kind == "relevant" or .kind == "wildcard")
      and (.source_url | type == "string" and test("^https?://[^[:space:]]+$"))
      and (.desktop_screenshot | type == "string" and length > 0 and (startswith("/") | not) and (contains("..") | not))
      and (.mobile_screenshot | type == "string" and length > 0 and (startswith("/") | not) and (contains("..") | not))
      and (.dimensions as $dimensions | ($dimensions | type == "object")
        and all(["hierarchy","typography","palette","spatial_rhythm","interaction","motion","signature_ideas"][];
          . as $key | ($dimensions[$key] | type == "string" and length > 0)))
      and all([.borrow, .transform, .avoid][]; type == "array" and length > 0 and all(.[]; type == "string" and length > 0)))
    and all(.directions[];
      (.id | type == "string" and length > 0)
      and (.summary | type == "string" and length > 0)
      and (.sources | type == "array" and length >= 2 and length == (unique | length))
      and all(.sources[]; . as $source | type == "string" and ($reference_ids | index($source)) != null))
    and all($reference_ids[];
      . as $source
      | ([$packet.directions[].sources[] | select(. == $source)] | length) < ($packet.directions | length))
    and all(.council[]; (.direction | type == "string") and (.score | type == "number"))
    and ([.council[] | select(.direction == $winner) | .score][0]
         == ([.council[].score] | max))
  ' "$packet" >/dev/null 2>&1 || return 1
  relevant_required=$(jq -r '.intensity | if . == "economy" then 3 elif . == "balanced" then 4 else 5 end' "$packet")
  [ "$(jq '[.references[] | select(.kind == "relevant")] | length' "$packet")" = "$relevant_required" ]
}

valid_packet_shape_v2() {
  local packet="$1" relevant_required
  jq -e '
    def okkeys($a): (keys_unsorted - $a) == [];
    def hex64: type == "string" and test("^[0-9a-f]{64}$");
    def relpath: type == "string" and length > 0
      and (startswith("/") | not) and (contains("..") | not)
      and (contains("\\") | not) and (contains("//") | not)
      and test("^[A-Za-z0-9._/-]+$");
    def noinject: (contains("$(") | not) and (contains("`") | not)
      and (contains("${") | not) and (contains("\n") | not) and (contains("\r") | not);
    def optext: type == "string" and length > 0 and noinject;
    def opid: optext and test("^[a-z0-9][a-z0-9_-]*$") and (length <= 64);
    . as $p
    | (.references | map(.id)) as $rids
    | (.directions | map(.id)) as $dids
    | ((.references | map(.desktop_sha256)) + (.references | map(.mobile_sha256))) as $shots
    | (.schema == 2)
    and okkeys(["schema","intensity","winner","goal","references","directions","council","design_lock","design_lock_sha256"])
    and (.intensity | IN("economy","balanced","max"))
    and (.winner == null)
    and (.goal | type == "object"
      and okkeys(["ultimate_goal","subgoal","ultimate_goal_sha256","subgoal_sha256","audience","product","domain","task"])
      and (.ultimate_goal | optext) and (.subgoal | optext)
      and (.ultimate_goal_sha256 | hex64) and (.subgoal_sha256 | hex64)
      and (.audience | optext) and (.product | optext) and (.domain | optext) and (.task | optext))
    and (.references | type == "array" and length > 0)
    and ($rids | length == (unique | length))
    and ([.references[] | select(.kind == "wildcard")] | length == 1)
    and all(.references[];
      okkeys(["id","kind","source_url","access_date","provenance","product_fit","observed","desktop_screenshot","mobile_screenshot","desktop_sha256","mobile_sha256","dimensions","borrow","transform","avoid"])
      and (.id | opid)
      and (.kind == "relevant" or .kind == "wildcard")
      and (.source_url | type == "string" and test("^https?://[^[:space:]]+$"))
      and (.access_date | type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$"))
      and (.provenance | optext) and (.product_fit | optext)
      and (.observed | type == "array" and length > 0 and all(.[]; optext))
      and (.desktop_screenshot | relpath) and (.mobile_screenshot | relpath)
      and (.desktop_sha256 | hex64) and (.mobile_sha256 | hex64)
      and (.dimensions as $d | ($d | type == "object"
        and okkeys(["hierarchy","typography","palette","spatial_rhythm","interaction","motion","signature_ideas"])
        and all(["hierarchy","typography","palette","spatial_rhythm","interaction","motion","signature_ideas"][];
          . as $k | ($d[$k] | optext))))
      and all([.borrow, .transform, .avoid][]; type == "array" and length > 0 and all(.[]; optext)))
    and ($shots | length == (unique | length))
    and (.directions | type == "array" and length == 3)
    and ($dids | length == (unique | length))
    and all(.directions[];
      okkeys(["id","product_thesis","source_synthesis","token_system","layout_model","motion_model","signature_moment","anti_goals","risk","audience_fit","sources","candidate_slot"])
      and (.id | opid)
      and (.product_thesis | optext) and (.source_synthesis | optext)
      and (.token_system | optext) and (.layout_model | optext) and (.motion_model | optext)
      and (.signature_moment | optext) and (.risk | optext) and (.audience_fit | optext)
      and (.anti_goals | type == "array" and length > 0 and all(.[]; optext))
      and (.candidate_slot | type == "string" and test("^slot-[0-9]+$"))
      and (.sources | type == "array" and length >= 2 and (length == (unique | length)))
      and all(.sources[]; . as $s | ($rids | index($s)) != null))
    and ([.directions[].candidate_slot] | length == (unique | length))
    and ([.directions[] | [(.signature_moment | ascii_downcase | gsub("^\\s+|\\s+$";"")),
                           (.token_system | ascii_downcase | gsub("^\\s+|\\s+$";"")),
                           (.layout_model | ascii_downcase | gsub("^\\s+|\\s+$";""))]]
         | length == (unique | length))
    and all($rids[]; . as $s
      | ([$p.directions[].sources[] | select(. == $s)] | length) < ($p.directions | length))
    and (.council | type == "array" and length == 3)
    and all(.council[]; okkeys(["direction","score"]) and (.direction | type == "string") and (.score | type == "number"))
    and ([.council[].direction] | sort == ($dids | sort))
    and (.design_lock | type == "object"
      and okkeys(["direction","tokens","responsive_hierarchy","reduced_motion","asset_intent","copy_intent","signature","anti_goals","goal_hash","source_packet_hash"])
      and (.direction as $w | ($dids | index($w)) != null)
      and (.tokens as $t | ($t | type == "object"
        and okkeys(["color","type","spacing","radius","elevation","interaction"])
        and all(["color","type","spacing","radius","elevation","interaction"][];
          . as $k | ($t[$k] | (type == "string" and length > 0) or (type == "object" and length > 0)))))
      and (.responsive_hierarchy | optext) and (.reduced_motion | optext)
      and (.asset_intent | optext) and (.copy_intent | optext) and (.signature | optext)
      and (.anti_goals | type == "array" and length > 0 and all(.[]; optext))
      and (.goal_hash | hex64) and (.source_packet_hash | hex64))
    and (.design_lock.goal_hash == .goal.ultimate_goal_sha256)
    and ([.council[] | select(.direction == $p.design_lock.direction) | .score][0]
         == ([.council[].score] | max))
    and (.design_lock_sha256 | hex64)
  ' "$packet" >/dev/null 2>&1 || return 1
  relevant_required=$(jq -r '.intensity | if . == "economy" then 3 elif . == "balanced" then 4 else 5 end' "$packet")
  [ "$(jq '[.references[] | select(.kind == "relevant")] | length' "$packet")" = "$relevant_required" ]
}

# Verify the content-addressed chain: stored hashes must equal recomputed ones.
verify_packet_hashes() {
  local packet="$1"
  [ "$(text_hash "$packet" '.goal.ultimate_goal')" = "$(jq -r '.goal.ultimate_goal_sha256' "$packet")" ] || return 1
  [ "$(text_hash "$packet" '.goal.subgoal')" = "$(jq -r '.goal.subgoal_sha256' "$packet")" ] || return 1
  [ "$(canon_hash "$packet" '.references')" = "$(jq -r '.design_lock.source_packet_hash' "$packet")" ] || return 1
  [ "$(canon_hash "$packet" '.design_lock')" = "$(jq -r '.design_lock_sha256' "$packet")" ] || return 1
}

packet_schema() { jq -r '.schema // empty' "$1" 2>/dev/null; }

validate_packet() {
  case "$(packet_schema "$(packet_path_for_manifest "$1")")" in
    2) validate_packet_v2 "$1"; return ;;
  esac
  local manifest="$1" root packet image winner sources summary decision
  root=$(project_root_for_manifest "$manifest") || return 1
  packet=$(packet_path_for_manifest "$manifest") || return 1
  [ -f "$packet" ] || { echo "VISUAL: missing reference packet: $packet" >&2; return 2; }
  valid_packet_shape "$packet" || { echo "VISUAL: invalid reference packet" >&2; return 2; }
  while IFS= read -r image; do
    [ -f "$root/$image" ] && [ ! -L "$root/$image" ] || {
      echo "VISUAL: missing or unsafe screenshot evidence: $image" >&2; return 2;
    }
  done < <(jq -r '.references[] | .desktop_screenshot, .mobile_screenshot' "$packet")
  [ -s "$root/docs/polylane/design/VISUAL-BRIEF.md" ] || {
    echo "VISUAL: missing VISUAL-BRIEF.md" >&2; return 2;
  }
  [ -s "$root/docs/polylane/design/DESIGN-DECISION.md" ] || {
    echo "VISUAL: missing DESIGN-DECISION.md" >&2; return 2;
  }
  winner=$(jq -r '.winner' "$packet")
  sources=$(jq -r --arg winner "$winner" '.directions[] | select(.id == $winner) | .sources | join(", ")' "$packet")
  summary=$(jq -r --arg winner "$winner" '.directions[] | select(.id == $winner) | .summary' "$packet")
  decision="$root/docs/polylane/design/DESIGN-DECISION.md"
  grep -Fqx "winner: $winner" "$decision" &&
    grep -Fqx "sources: $sources" "$decision" &&
    grep -Fqx "summary: $summary" "$decision" || {
      echo "VISUAL: frozen DESIGN-DECISION.md does not match reference packet" >&2; return 2;
    }
}

validate_packet_v2() {
  local manifest="$1" root packet dir image want got
  root=$(project_root_for_manifest "$manifest") || return 1
  packet=$(packet_path_for_manifest "$manifest") || return 1
  [ -f "$packet" ] || { echo "VISUAL: missing reference packet: $packet" >&2; return 2; }
  valid_packet_shape_v2 "$packet" || { echo "VISUAL: invalid reference packet" >&2; return 2; }
  verify_packet_hashes "$packet" || { echo "VISUAL: packet hash chain does not verify" >&2; return 2; }
  # Screenshots must be real, unlinked files whose bytes match the recorded hash.
  while IFS=$'\t' read -r image want; do
    [ -f "$root/$image" ] && [ ! -L "$root/$image" ] || {
      echo "VISUAL: missing or unsafe screenshot evidence: $image" >&2; return 2; }
    got=$(file_sha256 "$root/$image")
    [ "$got" = "$want" ] || { echo "VISUAL: stale screenshot (hash mismatch): $image" >&2; return 2; }
  done < <(jq -r '.references[] | (.desktop_screenshot + "\t" + .desktop_sha256), (.mobile_screenshot + "\t" + .mobile_sha256)' "$packet")
  dir="$root/docs/polylane/design"
  [ -s "$dir/VISUAL-BRIEF.md" ] || { echo "VISUAL: missing VISUAL-BRIEF.md" >&2; return 2; }
  [ -f "$dir/DESIGN-LOCK.json" ] || { echo "VISUAL: missing DESIGN-LOCK.json" >&2; return 2; }
  # Frozen lock must be byte-identical (canonically) to the packet's design lock.
  [ "$(canon_hash "$dir/DESIGN-LOCK.json" '.')" = "$(jq -r '.design_lock_sha256' "$packet")" ] || {
    echo "VISUAL: frozen DESIGN-LOCK.json does not match reference packet" >&2; return 2; }
  [ -f "$dir/TOURNAMENT-INPUT.json" ] || { echo "VISUAL: missing TOURNAMENT-INPUT.json" >&2; return 2; }
  jq -e --slurpfile p "$packet" '
    ([.candidates[].slot] | sort == ($p[0].directions | map(.candidate_slot) | sort))
    and ([.candidates[].direction] | sort == ($p[0].directions | map(.id) | sort))
    and (.winner == null)
    and all(.candidates[]; .winner == false and .status == "unrendered")
    and (.design_lock_sha256 == $p[0].design_lock_sha256)
  ' "$dir/TOURNAMENT-INPUT.json" >/dev/null 2>&1 || {
    echo "VISUAL: tournament skeleton does not bind the packet directions" >&2; return 2; }
}

prepare_packet_v2() {
  local manifest="$1" source="$2" root dir dest
  root=$(project_root_for_manifest "$manifest") || return 1
  valid_packet_shape_v2 "$source" || { echo "VISUAL: invalid reference fixture" >&2; return 2; }
  verify_packet_hashes "$source" || { echo "VISUAL: fixture hash chain does not verify" >&2; return 2; }
  dir="$root/docs/polylane/design"
  mkdir -p "$dir"
  dest="$dir/references.json"
  cp "$source" "$dest"
  jq -S '.design_lock' "$dest" > "$dir/DESIGN-LOCK.json"
  jq -cS '{
    schema: 2,
    goal_hash: .goal.ultimate_goal_sha256,
    subgoal_hash: .goal.subgoal_sha256,
    source_packet_hash: .design_lock.source_packet_hash,
    design_lock_sha256: .design_lock_sha256,
    capture_states: ["desktop","mobile","empty","loading","error","hover","focus","flow"],
    winner: null,
    candidates: ([.directions[] | {
      slot: .candidate_slot, direction: .id, status: "unrendered", winner: false,
      captures: {desktop:null,mobile:null,empty:null,loading:null,error:null,hover:null,focus:null,flow:null}
    }] | sort_by(.slot))
  }' "$dest" > "$dir/TOURNAMENT-INPUT.json"
  {
    printf '# Visual brief (schema 2)\n\n'
    printf 'goal: %s\n' "$(jq -r '.goal.ultimate_goal' "$dest")"
    printf 'subgoal: %s\n' "$(jq -r '.goal.subgoal' "$dest")"
    printf 'intensity: %s\n' "$(jq -r '.intensity' "$dest")"
    printf 'locked-direction: %s\n\n' "$(jq -r '.design_lock.direction' "$dest")"
    jq -r '.references[] | "- \(.id) [\(.kind)] @\(.access_date): borrow=\(.borrow|join(", ")); transform=\(.transform|join(", ")); avoid=\(.avoid|join(", "))"' "$dest"
  } > "$dir/VISUAL-BRIEF.md"
  validate_packet_v2 "$manifest"
}

prepare_packet() {
  case "$(packet_schema "$2")" in
    2) prepare_packet_v2 "$1" "$2"; return ;;
  esac
  local manifest="$1" source="$2" root dest dir winner
  root=$(project_root_for_manifest "$manifest") || return 1
  [ -f "$source" ] || { echo "VISUAL: reference fixture does not exist: $source" >&2; return 2; }
  valid_packet_shape "$source" || { echo "VISUAL: invalid reference fixture" >&2; return 2; }
  dir="$root/docs/polylane/design"
  mkdir -p "$dir"
  dest="$dir/references.json"
  cp "$source" "$dest"
  winner=$(jq -r '.winner' "$dest")
  {
    printf '# Visual brief\n\n'
    printf 'intensity: %s\n' "$(jq -r '.intensity' "$dest")"
    printf 'winner: %s\n\n' "$winner"
    jq -r '.references[] | "- \(.id): borrow=\(.borrow | join(", ")); transform=\(.transform | join(", ")); avoid=\(.avoid | join(", "))"' "$dest"
  } > "$dir/VISUAL-BRIEF.md"
  {
    printf '# Frozen design decision\n\n'
    printf 'winner: %s\n' "$winner"
    jq -r --arg winner "$winner" '.directions[] | select(.id == $winner) | "sources: \(.sources | join(", "))\nsummary: \(.summary)"' "$dest"
  } > "$dir/DESIGN-DECISION.md"
  validate_packet "$manifest"
}

main() {
  case "${1:-}" in
    detect) [ $# -eq 2 ] || { usage; return 2; }; detect_ui "$2" ;;
    prepare) [ $# -eq 3 ] || { usage; return 2; }; prepare_packet "$2" "$3" ;;
    validate) [ $# -eq 2 ] || { usage; return 2; }; validate_packet "$2" ;;
    *) usage; return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
