#!/usr/bin/env bash
# polylane-taste-generate.sh — isolated fixed-model builder-campaign runner.
#
# Consumes one frozen campaign manifest (taste-generate-campaign/v1) that pins
# run/brief/arm/direction/prompt/model/effort/output-root/deadline BEFORE launch,
# then for every (brief x arm) invokes a declared builder adapter in an isolated
# config+output workspace to produce a static offline site, and emits three
# tamper-evident receipts (source / build / compute) plus a BLINDED
# taste-candidate/v1 record consumable by the downstream capture lane.
#
# Trust model (mirrors polylane-visual-capture.sh): a fixture builder can never
# become a production oracle by flipping a flag. Production authorization comes
# only from a coordinator-owned allowlist (POLYLANE_GENERATE_ALLOWLIST) that pins
# the builder path, version, command SHA-256, model, and effort. Every candidate
# recomputes its own prompt/source/dependency/build hashes; a shape-compatible
# forgery cannot slot into the candidate chain because each hash binds the next.
#
# This runner NEVER ranks candidates, names a winner, or writes provider/model
# identity into the blinded candidate or the site source. Winner resolution
# happens only downstream at the blinded ballot. Resume is idempotent: a
# candidate whose receipts still verify is skipped; a partial/forged/crashed one
# is rebuilt from clean.
set -euo pipefail

# Static-site route entry the campaign requires every build to expose.
ENTRY_FILE="index.html"
# Minimum non-whitespace visible characters before a screen counts as real (not
# a placeholder-only stub).
MIN_VISIBLE_CHARS=40

usage() {
  cat <<'USAGE' >&2
usage:
  polylane-taste-generate.sh run    <campaign.json> -- <builder-adapter> [args...]
  polylane-taste-generate.sh verify <candidate-dir>
USAGE
}

die() { echo "TASTE-GENERATE: $*" >&2; return 2; }

sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
sha256_text() { printf '%s' "$1" | shasum -a 256 | awk '{print $1}'; }
rfc3339_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }
now_ts() { printf '%s' "${TASTE_NOW:-$(rfc3339_utc)}"; }
epoch_ms() { python3 -c 'import time;print(int(time.time()*1000))'; }

# Multi-segment repository-relative regular file with no symlink component and no
# traversal — the single guard every declared or produced path routes through.
safe_relative_regular_file() {
  local root="$1" path="$2" part prefix old_ifs
  case "$path" in ""|/*|*'//'*) return 1 ;; esac
  prefix="$root"
  old_ifs=$IFS; IFS='/'
  for part in $path; do
    [ -n "$part" ] && [ "$part" != . ] && [ "$part" != .. ] || { IFS=$old_ifs; return 1; }
    prefix="$prefix/$part"
    [ ! -L "$prefix" ] || { IFS=$old_ifs; return 1; }
  done
  IFS=$old_ifs
  [ -f "$root/$path" ] && [ ! -L "$root/$path" ]
}

regular_json_without_duplicate_keys() {
  local file="$1" duplicates
  [ -f "$file" ] && [ ! -L "$file" ] || return 1
  jq -e . "$file" >/dev/null 2>&1 || return 1
  duplicates=$(jq --stream -r 'select(length == 2) | .[0] | map(tostring) | join("")' "$file" 2>/dev/null | LC_ALL=C sort | uniq -d)
  [ -z "$duplicates" ]
}

# One manifest fixes everything before launch: run, briefs, arms, directions,
# prompts, model, effort, output root, and deadline. Exactly one baseline and
# three current arms per brief; every id and every hash is well-formed and
# unique in its scope. Trust booleans other than fixture_only are forbidden.
manifest_shape() {
  jq -e '
    ((keys - ["fixture_only"]) == ["briefs","builder","deadline_seconds","output_root","run_id","schema_version"])
    and (.fixture_only // true | type == "boolean")
    and .schema_version == "taste-generate-campaign/v1"
    and (.run_id | type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]*$"))
    and (.output_root | type == "string" and length > 0)
    and (.deadline_seconds | type == "number" and floor == . and . > 0)
    and (.builder | type == "object" and keys == ["adapter_id","adapter_version","command_sha256","effort","model"]
      and all([.adapter_id,.adapter_version,.model,.effort][]; type == "string" and length > 0)
      and (.command_sha256 | type == "string" and test("^[0-9a-f]{64}$")))
    and (.briefs | type == "array" and length > 0)
    and all(.briefs[];
      type == "object" and keys == ["arms","brief_id","brief_sha256","required_routes"]
      and (.brief_id | type == "string" and test("^brief-[a-z0-9]{3,}$"))
      and (.brief_sha256 | type == "string" and test("^[0-9a-f]{64}$"))
      and (.required_routes | type == "array" and length > 0 and (unique | length == length)
        and all(.[]; type == "string" and test("^/[^[:space:]]*$")))
      and (.arms | type == "array" and length == 4
        and ([.[] | select(.role == "baseline")] | length == 1)
        and ([.[] | select(.role == "current")] | length == 3)
        and ([.[].arm_id] | length == (unique | length))
        and ([.[].direction_id] | length == (unique | length))
        and all(.[];
          type == "object" and keys == ["arm_id","direction_id","prompt_path","prompt_sha256","role"]
          and (.arm_id | type == "string" and test("^arm-[a-z0-9][a-z0-9-]*$"))
          and (.role | IN("baseline","current"))
          and (.direction_id | type == "string" and length > 0)
          and (.prompt_path | type == "string" and length > 0 and (startswith("/") | not) and (contains("..") | not))
          and (.prompt_sha256 | type == "string" and test("^[0-9a-f]{64}$")))))
    and ([.briefs[].brief_id] | length == (unique | length))
    and ([paths(type == "boolean")] | map(.[-1]) | unique - ["fixture_only"] == [])
  ' "$1" >/dev/null 2>&1
}

candidate_id_for() { # run_id brief_id arm_id -> cand-<16hex>
  printf 'cand-%s' "$(sha256_text "$1"$'\n'"$2"$'\n'"$3" | cut -c1-16)"
}

# Canonical content revision of a built tree: sha256 over "<sha>  <relpath>\n"
# lines, sorted by path. Doubles as source_revision (64-hex satisfies the
# downstream git-sha shape). Prints the digest, or returns 1 on any unsafe file.
source_tree_sha256() {
  local root="$1" rel listing
  listing=$(cd "$root" && find . -type f | LC_ALL=C sort) || return 1
  local out=""
  while IFS= read -r rel; do
    rel=${rel#./}
    [ -n "$rel" ] || continue
    safe_relative_regular_file "$root" "$rel" || return 1
    out="$out$(sha256_file "$root/$rel")  $rel"$'\n'
  done <<EOF
$listing
EOF
  sha256_text "$out"
}

# Resolve a required route to a produced file. "/" -> index.html; "/x" -> x.html
# or x/index.html; "/x/" -> x/index.html; "/x.html" -> x.html. Echoes the
# relative file on success.
resolve_route() {
  local root="$1" route="$2" rel candidate
  case "$route" in
    /) rel="$ENTRY_FILE" ;;
    */) rel="${route#/}index.html" ;;
    *.html|*.htm) rel="${route#/}" ;;
    *)
      candidate="${route#/}.html"
      if [ -f "$root/$candidate" ]; then rel="$candidate"; else rel="${route#/}/index.html"; fi
      ;;
  esac
  safe_relative_regular_file "$root" "$rel" || return 1
  printf '%s\n' "$rel"
}

# Fetchable remote reference in a source file (offline hard rule). Targets
# src=/href=/url()/@import/fetch()/new URL/WebSocket pointing at an absolute or
# protocol-relative host; deliberately ignores xmlns/namespace URIs since those
# never fetch. ponytail: regex scan, not a full HTML/CSS parser — upgrade to a
# real parser if a builder starts smuggling URLs past it.
has_remote_reference() {
  LC_ALL=C grep -rIlE \
    '(src|href)[[:space:]]*=[[:space:]]*["'\''`]?(https?:)?//|url\([[:space:]]*["'\''`]?(https?:)?//|@import[[:space:]]+["'\''`]?(https?:)?//|(fetch|new[[:space:]]+URL|XMLHttpRequest|WebSocket)[^;)]{0,80}["'\''`](https?:)?//' \
    "$1" >/dev/null 2>&1
}

# Placeholder-only screen: the entry's visible text (tags stripped, whitespace
# collapsed) is shorter than MIN_VISIBLE_CHARS or is nothing but a known stub
# phrase. ponytail: tag-strip heuristic, not a renderer.
is_placeholder_only() {
  local entry="$1" text
  [ -f "$entry" ] || return 0
  text=$(LC_ALL=C tr '\n' ' ' < "$entry" \
    | LC_ALL=C sed -e 's/<script[^>]*>.*<\/script>//gi' -e 's/<style[^>]*>.*<\/style>//gi' -e 's/<[^>]*>/ /g' \
    | LC_ALL=C tr -s ' \t' ' ' | LC_ALL=C sed -e 's/^ *//' -e 's/ *$//')
  [ "${#text}" -ge "$MIN_VISIBLE_CHARS" ] || return 0
  printf '%s' "$text" | LC_ALL=C grep -Eqi \
    '^(lorem ipsum[. ]*|placeholder[. ]*|coming soon[.! ]*|todo[. ]*|hello,? world[.! ]*|your (content|text) here[. ]*)+$'
}

# Hidden provenance: the source tags itself with the builder's model/provider.
# Targets the literal model id and generator/provider markers; a site whose
# real content merely mentions an AI vendor is not the target. ponytail: marker
# scan, documented ceiling.
has_hidden_provenance() {
  local root="$1" model="$2"
  LC_ALL=C grep -rIlF -- "$model" "$root" >/dev/null 2>&1 && return 0
  LC_ALL=C grep -rIlE \
    '<meta[^>]+name=["'\'']generator|data-(generated-by|provider|model|ai-model)=|generated[[:space:]]+by[[:space:]]+(claude|anthropic|gpt|openai|gemini)' \
    "$root" >/dev/null 2>&1
}

write_json_atomic() { # out  (json on stdin)
  local out="$1" tmp
  mkdir -p "$(dirname "$out")"
  tmp=$(mktemp "${out}.tmp.XXXXXX") || return 1
  cat > "$tmp" || { rm -f "$tmp"; return 1; }
  mv -f "$tmp" "$out"
}

# ---- verify: single source of truth for "is this a real completed candidate" -
# Recomputes every hash and re-runs every safety gate, so it catches partial
# writes, crashed builds, and forged receipts alike. Reused by resume.
verify_candidate_dir() {
  local dir="$1" quiet="${2:-}" src="$1/source" model
  local c="$dir/candidate.json" sr="$dir/source-receipt.json" br="$dir/build-receipt.json" cr="$dir/compute-receipt.json"
  local computed sr_sha br_sha route rel f
  _bad() { [ -n "$quiet" ] || echo "TASTE-GENERATE: verify $dir: $1" >&2; return 1; }
  for f in "$c" "$sr" "$br" "$cr"; do
    regular_json_without_duplicate_keys "$f" || { _bad "missing/malformed $(basename "$f")"; return 1; }
  done
  [ -d "$src" ] && [ ! -L "$src" ] || { _bad "missing source tree"; return 1; }
  ! find "$src" -type l 2>/dev/null | grep -q . || { _bad "source tree contains a symlink"; return 1; }
  jq -e '(keys | sort) == ["brief_sha256","build_receipt_sha256","candidate_id","created_at","dependency_lock_sha256","design_lock_sha256","direction_id","schema_version","source_revision"] and .schema_version == "taste-candidate/v1"' "$c" >/dev/null 2>&1 || { _bad "candidate is not taste-candidate/v1"; return 1; }
  # Blinding: no provider/model identity may ever appear in the candidate.
  jq -e 'any(paths as $p | $p[-1]; (tostring | ascii_downcase) | test("provider|model|effort|winner|rank|score|champion"))' "$c" >/dev/null 2>&1 && { _bad "candidate leaks identity/ranking key"; return 1; }
  computed=$(source_tree_sha256 "$src") || { _bad "unsafe file in source tree"; return 1; }
  [ "$(jq -r .source_sha256 "$sr")" = "$computed" ] || { _bad "source-receipt hash != recomputed tree"; return 1; }
  [ "$(jq -r .source_revision "$c")" = "$computed" ] || { _bad "candidate source_revision != tree"; return 1; }
  sr_sha=$(sha256_file "$sr"); br_sha=$(sha256_file "$br")
  [ "$(jq -r .source_receipt_sha256 "$br")" = "$sr_sha" ] || { _bad "build-receipt not bound to source-receipt"; return 1; }
  [ "$(jq -r .source_sha256 "$br")" = "$computed" ] || { _bad "build-receipt source hash forged"; return 1; }
  [ "$(jq -r .build_receipt_sha256 "$c")" = "$br_sha" ] || { _bad "candidate build_receipt_sha256 forged"; return 1; }
  [ "$(jq -r .design_lock_sha256 "$c")" = "$(jq -r '.prompt.sha256' "$br")" ] || { _bad "candidate design lock != prompt"; return 1; }
  [ "$(jq -r .dependency_lock_sha256 "$c")" = "$(jq -r .dependency_lock_sha256 "$sr")" ] || { _bad "candidate dep lock != source receipt"; return 1; }
  [ "$(jq -r .brief_sha256 "$c")" = "$(jq -r .brief_sha256 "$br")" ] || { _bad "candidate brief hash != build receipt"; return 1; }
  # Re-run the source safety gates so a tampered tree cannot pass on hash alone.
  model=$(jq -r '.model' "$br")
  [ -f "$src/$ENTRY_FILE" ] && [ ! -L "$src/$ENTRY_FILE" ] || { _bad "missing entry $ENTRY_FILE"; return 1; }
  ! has_remote_reference "$src" || { _bad "source contains a remote reference"; return 1; }
  ! is_placeholder_only "$src/$ENTRY_FILE" || { _bad "entry is placeholder-only"; return 1; }
  ! has_hidden_provenance "$src" "$model" || { _bad "source carries hidden provenance"; return 1; }
  while IFS= read -r route; do
    rel=$(resolve_route "$src" "$route") || { _bad "required route $route not exposed"; return 1; }
    [ -n "$rel" ] || { _bad "required route $route not exposed"; return 1; }
  done < <(jq -r '.functional_start.required_routes[]' "$br")
  return 0
}

# ---- portable per-candidate deadline (no GNU timeout on macOS) ---------------
# ponytail: TERMs then KILLs the adapter and its direct children; a builder that
# double-forks into its own session could orphan a grandchild — acceptable for a
# harness whose adapter contract is "stay in the foreground".
run_with_deadline() { # secs marker cmd...
  local secs="$1" marker="$2"; shift 2
  rm -f "$marker"
  "$@" & local child=$!
  ( sleep "$secs"
    if kill -0 "$child" 2>/dev/null; then
      : > "$marker"
      pkill -TERM -P "$child" 2>/dev/null || true
      kill -TERM "$child" 2>/dev/null || true
      sleep 2
      pkill -KILL -P "$child" 2>/dev/null || true
      kill -KILL "$child" 2>/dev/null || true
    fi ) & local watch=$!
  local rc=0
  wait "$child" 2>/dev/null || rc=$?
  kill -TERM "$watch" 2>/dev/null || true
  wait "$watch" 2>/dev/null || true
  [ ! -f "$marker" ] || return 124
  return "$rc"
}

# ---- build a single (brief, arm) candidate -----------------------------------
# Returns 0 on a clean candidate, 1 on a recorded failure (campaign continues so
# resume can retry only the failures).
run_one() {
  local out_root="$1" campaign_dir="$2" builder="$3" builder_sha="$4" adapter_id="$5" adapter_version="$6" \
        model="$7" effort="$8" deadline="$9" classification="${10}" run_id="${11}"
  shift 11
  local brief_id="$1" brief_sha="$2" routes_json="$3" arm_json="$4"; shift 4
  # remaining args ($@) are the builder's own trailing args
  local arm_id role direction_id prompt_rel prompt_sha cand_id
  arm_id=$(printf '%s' "$arm_json" | jq -r .arm_id)
  role=$(printf '%s' "$arm_json" | jq -r .role)
  direction_id=$(printf '%s' "$arm_json" | jq -r .direction_id)
  prompt_rel=$(printf '%s' "$arm_json" | jq -r .prompt_path)
  prompt_sha=$(printf '%s' "$arm_json" | jq -r .prompt_sha256)
  cand_id=$(candidate_id_for "$run_id" "$brief_id" "$arm_id")
  local dest="$out_root/$brief_id/$arm_id"

  # Resume: a candidate that still verifies is skipped untouched (idempotent).
  if [ -e "$dest/candidate.json" ] && verify_candidate_dir "$dest" quiet; then
    echo "TASTE-GENERATE: skip $brief_id/$arm_id ($cand_id) — receipts verify"
    return 0
  fi
  rm -rf "$dest"

  # Recompute the pinned prompt hash — a changed prompt is refused, not built.
  local prompt_abs="$campaign_dir/$prompt_rel"
  safe_relative_regular_file "$campaign_dir" "$prompt_rel" || { die "prompt path unsafe: $prompt_rel"; return 1; }
  [ "$(sha256_file "$prompt_abs")" = "$prompt_sha" ] || { echo "TASTE-GENERATE: FAIL $brief_id/$arm_id — prompt hash != pinned (frozen prompt changed)" >&2; return 1; }

  local work cfg site started_at ended_at start_ms end_ms rc marker usage_json usage_source deps_json dep_lock
  work=$(mktemp -d "$out_root/.polylane-generate.XXXXXX") || { die "mktemp workspace failed"; return 1; }
  # shellcheck disable=SC2064 # expand $work now for the cleanup trap.
  trap "rm -rf '$work'" RETURN
  cfg="$work/config"; site="$work/site"; marker="$work/.timedout"
  mkdir -p "$cfg/xdg" "$cfg/cache" "$cfg/tmp" "$site"

  started_at=$(now_ts); start_ms=$(epoch_ms)
  # Isolated config+HOME per candidate → no shared chat context bleeds across
  # candidates. API creds in the ambient env are preserved (isolation is about
  # conversation state, not credentials).
  set +e
  run_with_deadline "$deadline" "$marker" \
    env HOME="$cfg" XDG_CONFIG_HOME="$cfg/xdg" XDG_CACHE_HOME="$cfg/cache" TMPDIR="$cfg/tmp" \
      CLAUDE_CONFIG_DIR="$cfg/claude" \
      POLYLANE_BUILD_PROMPT="$prompt_abs" \
      POLYLANE_BUILD_OUTPUT="$site" \
      POLYLANE_BUILD_CONFIG="$cfg" \
      POLYLANE_BUILD_MODEL="$model" \
      POLYLANE_BUILD_EFFORT="$effort" \
      POLYLANE_BUILD_BRIEF_ID="$brief_id" \
      POLYLANE_BUILD_DIRECTION_ID="$direction_id" \
      "$builder" "$@"
  rc=$?
  set -e
  end_ms=$(epoch_ms); ended_at=$(now_ts)

  if [ "$rc" = 124 ]; then echo "TASTE-GENERATE: FAIL $brief_id/$arm_id — builder exceeded ${deadline}s deadline" >&2; return 1; fi
  [ "$rc" = 0 ] || { echo "TASTE-GENERATE: FAIL $brief_id/$arm_id — builder exit $rc" >&2; return 1; }

  # Site must be a clean tree the builder actually produced (build-in-temp means
  # no dirty template can contaminate the receipt).
  [ ! -L "$site" ] || { die "builder output is a symlink"; return 1; }
  # No symlink anywhere in the tree: `find -type f` skips symlinks, so a planted
  # symlink would be copied by `cp -R` into the published source and escape.
  if find "$site" -type l 2>/dev/null | grep -q .; then
    echo "TASTE-GENERATE: FAIL $brief_id/$arm_id — output contains a symlink (path escape)" >&2; return 1
  fi
  [ -f "$site/$ENTRY_FILE" ] && [ ! -L "$site/$ENTRY_FILE" ] || { echo "TASTE-GENERATE: FAIL $brief_id/$arm_id — missing $ENTRY_FILE" >&2; return 1; }
  if find "$site" \( -name node_modules -o -name .git \) -type d 2>/dev/null | grep -q .; then
    echo "TASTE-GENERATE: FAIL $brief_id/$arm_id — dirty template droppings (node_modules/.git)" >&2; return 1
  fi
  local source_sha
  source_sha=$(source_tree_sha256 "$site") || { echo "TASTE-GENERATE: FAIL $brief_id/$arm_id — unsafe file (symlink/escape) in output" >&2; return 1; }
  ! has_remote_reference "$site" || { echo "TASTE-GENERATE: FAIL $brief_id/$arm_id — source contains a remote asset/font/API reference" >&2; return 1; }
  ! is_placeholder_only "$site/$ENTRY_FILE" || { echo "TASTE-GENERATE: FAIL $brief_id/$arm_id — entry is a placeholder-only screen" >&2; return 1; }
  ! has_hidden_provenance "$site" "$model" || { echo "TASTE-GENERATE: FAIL $brief_id/$arm_id — source carries hidden provenance" >&2; return 1; }

  # Functional start: entry present + every required route resolves to a file.
  local routes_present=true route rel resolved='[]'
  while IFS= read -r route; do
    if rel=$(resolve_route "$site" "$route"); then
      resolved=$(printf '%s' "$resolved" | jq -c --arg r "$route" --arg f "$rel" '. + [{route:$r,file:$f}]')
    else
      routes_present=false
      echo "TASTE-GENERATE: FAIL $brief_id/$arm_id — required route $route not exposed" >&2; return 1
    fi
  done < <(printf '%s' "$routes_json" | jq -r '.[]')

  # Dependency lock + usage from an optional builder-emitted build-meta.json.
  deps_json='[]'; usage_json='null'; usage_source='unavailable'
  if [ -f "$cfg/build-meta.json" ] && [ ! -L "$cfg/build-meta.json" ] && jq -e . "$cfg/build-meta.json" >/dev/null 2>&1; then
    deps_json=$(jq -c 'if (.dependencies|type)=="array" then (.dependencies|sort) else [] end' "$cfg/build-meta.json")
    if jq -e '.usage | type == "object"' "$cfg/build-meta.json" >/dev/null 2>&1; then
      usage_json=$(jq -c '.usage' "$cfg/build-meta.json"); usage_source='builder-reported'
    fi
  fi
  dep_lock=$(sha256_text "$deps_json")

  # Move the clean tree into place, then write receipts that bind to it.
  mkdir -p "$dest"
  cp -R "$site" "$dest/source"
  local created_at src_receipt build_receipt src_sha br_sha
  created_at=$(now_ts)

  # --- source receipt --------------------------------------------------------
  src_receipt="$dest/source-receipt.json"
  {
    jq -n --arg cid "$cand_id" --arg bid "$brief_id" --arg aid "$arm_id" --arg did "$direction_id" \
      --arg now "$created_at" --arg src "$source_sha" --arg dep "$dep_lock" --argjson deps "$deps_json" \
      --arg vfp "$VALIDATOR_FP" --arg cls "$classification" \
      --argjson files "$(cd "$dest/source" && find . -type f | LC_ALL=C sort | sed 's#^\./##' | while IFS= read -r p; do jq -n --arg path "$p" --arg sha "$(sha256_file "$dest/source/$p")" --argjson bytes "$(wc -c < "$dest/source/$p" | tr -d ' ')" '{path:$path,sha256:$sha,bytes:$bytes}'; done | jq -s 'sort_by(.path)')" \
      '{
        schema_version:"taste-source-receipt/v1",
        receipt_version:"polylane.taste.generate.source-receipt.v1",
        classification:$cls,
        validator:{id:"polylane-taste-generate",fingerprint:$vfp},
        candidate_id:$cid, brief_id:$bid, arm_id:$aid, direction_id:$did,
        executed_at:$now,
        entry:"index.html",
        files:$files, file_count:($files|length),
        source_sha256:$src,
        dependencies:$deps, dependency_lock_sha256:$dep,
        offline:true, placeholder_free:true, provenance_clean:true,
        reason_codes:[]
      }'
  } | write_json_atomic "$src_receipt"
  src_sha=$(sha256_file "$src_receipt")

  # --- build receipt ---------------------------------------------------------
  build_receipt="$dest/build-receipt.json"
  local builder_canon
  builder_canon="$(cd "$(dirname "$builder")" && pwd -P)/$(basename "$builder")"
  {
    jq -n --arg cid "$cand_id" --arg bid "$brief_id" --arg aid "$arm_id" --arg did "$direction_id" --arg role "$role" \
      --arg aidr "$adapter_id" --arg aver "$adapter_version" --arg bpath "$builder_canon" --arg bsha "$builder_sha" \
      --arg ppath "$prompt_rel" --arg psha "$prompt_sha" --arg briefsha "$brief_sha" \
      --arg model "$model" --arg effort "$effort" --arg now "$created_at" \
      --arg src "$source_sha" --arg dep "$dep_lock" --arg srsha "$src_sha" \
      --argjson routes "$resolved" --arg rp "$routes_present" \
      --arg vfp "$VALIDATOR_FP" --arg cls "$classification" \
      '{
        schema_version:"taste-build-receipt/v1",
        receipt_version:"polylane.taste.generate.build-receipt.v1",
        classification:$cls,
        validator:{id:"polylane-taste-generate",fingerprint:$vfp},
        candidate_id:$cid, brief_id:$bid, arm_id:$aid, direction_id:$did, role:$role,
        builder:{adapter_id:$aidr,adapter_version:$aver,command_path:$bpath,command_sha256:$bsha},
        prompt:{path:$ppath,sha256:$psha},
        brief_sha256:$briefsha,
        model:$model, effort:$effort,
        exit_status:0,
        functional_start:{started:($rp=="true"),entry:"index.html",entry_ok:true,required_routes:($routes|map(.route)),routes:$routes,routes_present:($rp=="true")},
        source_sha256:$src, dependency_lock_sha256:$dep, source_receipt_sha256:$srsha,
        executed_at:$now,
        reason_codes:[]
      }'
  } | write_json_atomic "$build_receipt"
  br_sha=$(sha256_file "$build_receipt")

  # --- compute receipt -------------------------------------------------------
  {
    jq -n --arg cid "$cand_id" --arg bpath "$builder_canon" --arg bsha "$builder_sha" --arg aver "$adapter_version" \
      --arg model "$model" --arg effort "$effort" --arg s "$started_at" --arg e "$ended_at" \
      --argjson dms "$((end_ms - start_ms))" --argjson dl "$deadline" --argjson usage "$usage_json" --arg usrc "$usage_source" \
      --arg vfp "$VALIDATOR_FP" --arg cls "$classification" \
      '{
        schema_version:"taste-compute-receipt/v1",
        receipt_version:"polylane.taste.generate.compute-receipt.v1",
        classification:$cls,
        validator:{id:"polylane-taste-generate",fingerprint:$vfp},
        candidate_id:$cid,
        builder:{command_path:$bpath,command_sha256:$bsha,version:$aver},
        model:$model, effort:$effort,
        timing:{started_at:$s,ended_at:$e,duration_ms:$dms,deadline_seconds:$dl},
        usage:$usage, usage_source:$usrc,
        executed_at:$e,
        reason_codes:[]
      }'
  } | write_json_atomic "$dest/compute-receipt.json"

  # --- blinded candidate (the seam; written LAST as the completion marker) ----
  # No provider, model, effort, role, rank, or score. design_lock = the frozen
  # prompt; source_revision = the content-addressed tree hash.
  {
    jq -n --arg cid "$cand_id" --arg did "$direction_id" --arg briefsha "$brief_sha" \
      --arg dlock "$prompt_sha" --arg dep "$dep_lock" --arg brsha "$br_sha" --arg rev "$source_sha" --arg now "$created_at" \
      '{
        schema_version:"taste-candidate/v1",
        candidate_id:$cid,
        brief_sha256:$briefsha,
        design_lock_sha256:$dlock,
        direction_id:$did,
        source_revision:$rev,
        dependency_lock_sha256:$dep,
        build_receipt_sha256:$brsha,
        created_at:$now
      }'
  } | write_json_atomic "$dest/candidate.json"

  # Fail closed if what we just wrote does not verify end-to-end.
  verify_candidate_dir "$dest" || { die "self-verification failed for $brief_id/$arm_id"; return 1; }
  echo "TASTE-GENERATE: built $brief_id/$arm_id ($cand_id) role=$role src=$source_sha"
  return 0
}

run_campaign() {
  local manifest="$1"; shift
  [ "${1:-}" = "--" ] || { usage; return 2; }; shift
  [ "$#" -gt 0 ] || { die "a declared builder adapter is required"; return 2; }
  local builder="$1"; shift
  regular_json_without_duplicate_keys "$manifest" || { die "campaign manifest is malformed JSON"; return 2; }
  manifest_shape "$manifest" || { die "campaign manifest is not a valid taste-generate-campaign/v1"; return 2; }
  [ -x "$builder" ] && [ ! -L "$builder" ] || { die "builder adapter is unavailable or a symlink: $builder"; return 2; }

  local campaign_dir builder_sha declared_sha adapter_id adapter_version model effort deadline fixture_only classification run_id out_root
  campaign_dir=$(cd "$(dirname "$manifest")" && pwd -P)
  builder_sha=$(sha256_file "$builder")
  declared_sha=$(jq -r '.builder.command_sha256' "$manifest")
  # A swapped builder binary (changed model implementation) is refused up front.
  [ "$builder_sha" = "$declared_sha" ] || { die "builder command SHA-256 != pinned identity (changed builder/model)"; return 2; }
  adapter_id=$(jq -r '.builder.adapter_id' "$manifest")
  adapter_version=$(jq -r '.builder.adapter_version' "$manifest")
  model=$(jq -r '.builder.model' "$manifest")
  effort=$(jq -r '.builder.effort' "$manifest")
  deadline=$(jq -r '.deadline_seconds' "$manifest")
  fixture_only=$(jq -r 'if has("fixture_only") then .fixture_only else true end' "$manifest")
  run_id=$(jq -r '.run_id' "$manifest")
  out_root=$(jq -r '.output_root' "$manifest")

  # Trust boundary: production classification requires a coordinator-owned
  # allowlist pinning this builder identity + model + effort. Fixtures can never
  # flip themselves to production.
  classification="fixture"
  if [ "$fixture_only" = false ]; then
    local allow entry builder_canon
    builder_canon="$(cd "$(dirname "$builder")" && pwd -P)/$(basename "$builder")"
    allow="${POLYLANE_GENERATE_ALLOWLIST:-}"
    [ -n "$allow" ] && [ -f "$allow" ] && [ ! -L "$allow" ] || { die "production campaign requires a coordinator-owned allowlist"; return 2; }
    jq -e '.schema_version == "taste-generate-allowlist/v1" and (.entries | type == "array")' "$allow" >/dev/null 2>&1 || { die "coordinator allowlist is malformed"; return 2; }
    entry=$(jq -c --arg p "$builder_canon" --arg v "$adapter_version" --arg c "$builder_sha" --arg m "$model" --arg e "$effort" \
      'first(.entries[] | select(.builder_path==$p and .adapter_version==$v and .command_sha256==$c and .model==$m and .effort==$e)) // empty' "$allow")
    [ -n "$entry" ] || { die "builder is not coordinator-authorized for production (path/version/sha/model/effort)"; return 2; }
    classification="production"
  elif [ "$fixture_only" != true ]; then
    die "fixture_only must be a boolean"; return 2
  fi

  case "$out_root" in /*) : ;; *) out_root="$(pwd -P)/$out_root" ;; esac
  [ ! -L "$out_root" ] || { die "output root must not be a symlink"; return 2; }
  local out_parent
  out_parent=$(dirname "$out_root")
  [ -d "$out_parent" ] && [ ! -L "$out_parent" ] || { die "output-root parent does not exist"; return 2; }
  mkdir -p "$out_root"

  echo "TASTE-GENERATE: campaign run=$run_id briefs=$(jq '.briefs|length' "$manifest") arms/brief=4 model=$model effort=$effort classification=$classification"

  local failures=0 brief_json brief_id brief_sha routes_json arm_json
  while IFS= read -r brief_json; do
    brief_id=$(printf '%s' "$brief_json" | jq -r .brief_id)
    brief_sha=$(printf '%s' "$brief_json" | jq -r .brief_sha256)
    routes_json=$(printf '%s' "$brief_json" | jq -c .required_routes)
    while IFS= read -r arm_json; do
      if run_one "$out_root" "$campaign_dir" "$builder" "$builder_sha" "$adapter_id" "$adapter_version" \
           "$model" "$effort" "$deadline" "$classification" "$run_id" \
           "$brief_id" "$brief_sha" "$routes_json" "$arm_json" "$@"; then :; else
        failures=$((failures + 1))
      fi
    done < <(printf '%s' "$brief_json" | jq -c '.arms[]')

    # Distinct candidates: two directions of one brief may not collapse to the
    # same source (identical output would silently rig the tournament).
    local dups
    dups=$(find "$out_root/$brief_id" -maxdepth 2 -name candidate.json -type f 2>/dev/null \
      | while IFS= read -r f; do jq -r .source_revision "$f"; done | LC_ALL=C sort | uniq -d)
    if [ -n "$dups" ]; then
      echo "TASTE-GENERATE: FAIL $brief_id — duplicate candidate source across arms" >&2
      failures=$((failures + 1))
    fi
  done < <(jq -c '.briefs[]' "$manifest")

  if [ "$failures" -gt 0 ]; then
    echo "TASTE-GENERATE: campaign incomplete — $failures candidate(s) failed; rerun to resume only the failures" >&2
    return 1
  fi
  echo "TASTE-GENERATE: campaign complete — all candidates built and verified (no winner selected)"
  return 0
}

VALIDATOR_FP=""

main() {
  command -v jq >/dev/null 2>&1 || { die "jq is required"; return 2; }
  command -v shasum >/dev/null 2>&1 || { die "shasum is required"; return 2; }
  command -v python3 >/dev/null 2>&1 || { die "python3 is required for timing"; return 2; }
  VALIDATOR_FP=$(sha256_file "${BASH_SOURCE[0]}")
  case "${1:-}" in
    run) [ "$#" -ge 4 ] || { usage; return 2; }; shift; run_campaign "$@" ;;
    verify) [ "$#" -eq 2 ] || { usage; return 2; }; verify_candidate_dir "$2" ;;
    *) usage; return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
