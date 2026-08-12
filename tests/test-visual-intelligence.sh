#!/usr/bin/env bash
# Visual packet creation starts only for manifests that explicitly request UI work.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"

VISUAL="$(cd "$(dirname "$0")/.." && pwd)/bin/polylane-visual.sh"
make_tmpdir
MANIFEST="$TEST_TMPDIR/manifest.json"
printf '%s\n' '{"lanes":[{"name":"ui","own_globs":["src/components/**"]}]}' > "$MANIFEST"

assert_eq "visual-detects-ui-manifest" "ui" "$("$VISUAL" detect "$MANIFEST" 2>/dev/null)"

# A prepared packet is durable, multi-source, and carries one creative wildcard.
ROOT="$TEST_TMPDIR/project"; mkdir -p "$ROOT/.polylane" "$ROOT/evidence"
cp "$MANIFEST" "$ROOT/.polylane/run.json"
for image in a-d b-d c-d w-d a-m b-m c-m w-m; do printf '%s' fixture > "$ROOT/evidence/$image.png"; done
PACKET="$TEST_TMPDIR/references.json"
cat > "$PACKET" <<'JSON'
{"schema":1,"intensity":"economy","references":[
 {"id":"a","kind":"relevant","source_url":"https://a.example","desktop_screenshot":"evidence/a-d.png","mobile_screenshot":"evidence/a-m.png","dimensions":{"hierarchy":"cards","typography":"sans","palette":"warm","spatial_rhythm":"airy","interaction":"tabs","motion":"subtle","signature_ideas":"rail"},"borrow":["hierarchy"],"transform":["rail"],"avoid":["copy"]},
 {"id":"b","kind":"relevant","source_url":"https://b.example","desktop_screenshot":"evidence/b-d.png","mobile_screenshot":"evidence/b-m.png","dimensions":{"hierarchy":"grid","typography":"serif","palette":"cool","spatial_rhythm":"tight","interaction":"sheet","motion":"none","signature_ideas":"timeline"},"borrow":["grid"],"transform":["timeline"],"avoid":["copy"]},
 {"id":"c","kind":"relevant","source_url":"https://c.example","desktop_screenshot":"evidence/c-d.png","mobile_screenshot":"evidence/c-m.png","dimensions":{"hierarchy":"stack","typography":"mono","palette":"neutral","spatial_rhythm":"dense","interaction":"menu","motion":"soft","signature_ideas":"meter"},"borrow":["stack"],"transform":["meter"],"avoid":["copy"]},
 {"id":"w","kind":"wildcard","source_url":"https://w.example","desktop_screenshot":"evidence/w-d.png","mobile_screenshot":"evidence/w-m.png","dimensions":{"hierarchy":"poster","typography":"display","palette":"bold","spatial_rhythm":"asymmetry","interaction":"scroll","motion":"kinetic","signature_ideas":"orbit"},"borrow":["poster"],"transform":["orbit"],"avoid":["copy"]}],
 "directions":[{"id":"native","sources":["a","b"],"summary":"native"},{"id":"expressive","sources":["b","c"],"summary":"expressive"},{"id":"wild","sources":["c","w"],"summary":"wild"}],
 "council":[{"direction":"native","score":8},{"direction":"expressive","score":7},{"direction":"wild","score":6}],"winner":"native"}
JSON
assert_ok "visual-prepares-durable-reference-packet" "$VISUAL" prepare "$ROOT/.polylane/run.json" "$PACKET"
assert_ok "visual-reference-packet-is-valid" "$VISUAL" validate "$ROOT/.polylane/run.json"
assert_eq "visual-reference-winner-is-frozen" "native" "$(jq -r .winner "$ROOT/docs/polylane/design/references.json")"
assert_ok "visual-brief-is-durable" test -s "$ROOT/docs/polylane/design/VISUAL-BRIEF.md"
assert_contains "visual-decision-records-winner" "winner: native" "$(cat "$ROOT/docs/polylane/design/DESIGN-DECISION.md")"
assert_contains "visual-decision-records-source-mix" "sources: a, b" "$(cat "$ROOT/docs/polylane/design/DESIGN-DECISION.md")"

# A single source may inform a direction but cannot dominate every proposal.
jq '.directions |= map(.sources = ["a", "b"])' "$PACKET" > "$TEST_TMPDIR/dominant.json"
assert_fail "visual-rejects-dominant-reference-source" "$VISUAL" prepare "$ROOT/.polylane/run.json" "$TEST_TMPDIR/dominant.json"

printf '%s\n' '# tampered' > "$ROOT/docs/polylane/design/DESIGN-DECISION.md"
assert_fail "visual-rejects-unfrozen-design-decision" "$VISUAL" validate "$ROOT/.polylane/run.json"

# ==========================================================================
# schema 2 — versioned current packet, immutable design lock, tournament seed.
# schema-1 above must keep passing: the new path is additive, not a rewrite.
# ==========================================================================

# Canonicalization replicated exactly from bin/polylane-visual.sh so fixtures
# carry real hashes. Kept local (not sourced) to avoid inheriting its set -euo.
_sha() { if command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}'; else sha256sum | awk '{print $1}'; fi; }
_canon() { jq -cS "$1" "$2" | tr -d '\n' | _sha; }   # objects/arrays
_text()  { jq -j  "$1" "$2" | _sha; }                # raw string leaf
_file()  { _sha < "$1"; }

V2="$TEST_TMPDIR/v2"; mkdir -p "$V2/.polylane" "$V2/evidence"
cp "$MANIFEST" "$V2/.polylane/run.json"
# Distinct bytes per screenshot: no duplicate reference masquerading.
for s in a-d a-m b-d b-m c-d c-m w-d w-m; do printf 'pixels-of-%s' "$s" > "$V2/evidence/$s.png"; done

# Build a valid schema-2 packet at $1 with real hashes computed from $V2.
mk_v2() {
  local dest="$1" root="$V2" id side h
  cat > "$dest" <<'JSON'
{"schema":2,"intensity":"economy","winner":null,
 "goal":{"ultimate_goal":"ship a production taste loop","subgoal":"lock divergent UI directions",
  "ultimate_goal_sha256":"0","subgoal_sha256":"0",
  "audience":"platform engineers","product":"polylane","domain":"dev-tooling","task":"visual packet gate"},
 "references":[
  {"id":"a","kind":"relevant","source_url":"https://a.example","access_date":"2026-08-01","provenance":"captured self","product_fit":"matches dense dashboards","observed":["dashboard empty state"],"desktop_screenshot":"evidence/a-d.png","mobile_screenshot":"evidence/a-m.png","desktop_sha256":"0","mobile_sha256":"0","dimensions":{"hierarchy":"cards","typography":"sans","palette":"warm","spatial_rhythm":"airy","interaction":"tabs","motion":"subtle","signature_ideas":"rail"},"borrow":["hierarchy"],"transform":["rail"],"avoid":["copy"]},
  {"id":"b","kind":"relevant","source_url":"https://b.example","access_date":"2026-08-02","provenance":"captured self","product_fit":"editorial rhythm fits reports","observed":["report loading state"],"desktop_screenshot":"evidence/b-d.png","mobile_screenshot":"evidence/b-m.png","desktop_sha256":"0","mobile_sha256":"0","dimensions":{"hierarchy":"grid","typography":"serif","palette":"cool","spatial_rhythm":"tight","interaction":"sheet","motion":"none","signature_ideas":"timeline"},"borrow":["grid"],"transform":["timeline"],"avoid":["copy"]},
  {"id":"c","kind":"relevant","source_url":"https://c.example","access_date":"2026-08-03","provenance":"captured self","product_fit":"metering suits gates","observed":["gate error state"],"desktop_screenshot":"evidence/c-d.png","mobile_screenshot":"evidence/c-m.png","desktop_sha256":"0","mobile_sha256":"0","dimensions":{"hierarchy":"stack","typography":"mono","palette":"neutral","spatial_rhythm":"dense","interaction":"menu","motion":"soft","signature_ideas":"meter"},"borrow":["stack"],"transform":["meter"],"avoid":["copy"]},
  {"id":"w","kind":"wildcard","source_url":"https://w.example","access_date":"2026-08-04","provenance":"captured self","product_fit":"kinetic focus borrowed from galleries","observed":["gallery hover state"],"desktop_screenshot":"evidence/w-d.png","mobile_screenshot":"evidence/w-m.png","desktop_sha256":"0","mobile_sha256":"0","dimensions":{"hierarchy":"poster","typography":"display","palette":"bold","spatial_rhythm":"asymmetry","interaction":"scroll","motion":"kinetic","signature_ideas":"orbit"},"borrow":["poster"],"transform":["orbit"],"avoid":["copy"]}],
 "directions":[
  {"id":"native","product_thesis":"calm operator console","source_synthesis":"a rail plus b grid","token_system":"warm sans 8pt","layout_model":"left rail shell","motion_model":"subtle fades","signature_moment":"live status rail","anti_goals":["saas sameness"],"risk":"too plain","audience_fit":"engineers scan fast","sources":["a","b"],"candidate_slot":"slot-1"},
  {"id":"editorial","product_thesis":"report as narrative","source_synthesis":"b timeline plus c meter","token_system":"cool serif scale","layout_model":"centered column","motion_model":"no motion","signature_moment":"verdict timeline","anti_goals":["dashboard clutter"],"risk":"slow density","audience_fit":"reviewers read deeply","sources":["b","c"],"candidate_slot":"slot-2"},
  {"id":"kinetic","product_thesis":"expressive proof gallery","source_synthesis":"c meter plus w orbit","token_system":"bold display grid","layout_model":"asymmetric poster","motion_model":"kinetic reveal","signature_moment":"orbiting evidence","anti_goals":["gimmick overload"],"risk":"a11y motion","audience_fit":"stakeholders skim visuals","sources":["c","w"],"candidate_slot":"slot-3"}],
 "council":[{"direction":"native","score":8},{"direction":"editorial","score":7},{"direction":"kinetic","score":6}],
 "design_lock":{"direction":"native","tokens":{"color":"warm-600","type":"inter 8pt","spacing":"4px base","radius":"8px","elevation":"1dp rail","interaction":"tab focus ring"},"responsive_hierarchy":"rail collapses to top bar under 768px","reduced_motion":"fades become instant","asset_intent":"custom status glyphs","copy_intent":"verb-first labels","signature":"live status rail","anti_goals":["saas sameness"],"goal_hash":"0","source_packet_hash":"0"},
 "design_lock_sha256":"0"}
JSON
  # 1) real screenshot hashes
  for id in a b c w; do
    for side in d m; do
      h=$(_file "$root/evidence/$id-$side.png")
      local key; [ "$side" = d ] && key=desktop_sha256 || key=mobile_sha256
      jq --arg id "$id" --arg k "$key" --arg h "$h" \
        '(.references[] | select(.id==$id))[$k]=$h' "$dest" > "$dest.t" && mv "$dest.t" "$dest"
    done
  done
  # 2) goal hashes
  jq --arg g "$(_text '.goal.ultimate_goal' "$dest")" --arg s "$(_text '.goal.subgoal' "$dest")" \
     '.goal.ultimate_goal_sha256=$g | .goal.subgoal_sha256=$s' "$dest" > "$dest.t" && mv "$dest.t" "$dest"
  # 3) source-packet hash + lock goal_hash binding
  jq --arg sp "$(_canon '.references' "$dest")" \
     '.design_lock.source_packet_hash=$sp | .design_lock.goal_hash=.goal.ultimate_goal_sha256' \
     "$dest" > "$dest.t" && mv "$dest.t" "$dest"
  # 4) immutable design-lock hash (over the finalized lock)
  jq --arg dl "$(_canon '.design_lock' "$dest")" '.design_lock_sha256=$dl' "$dest" > "$dest.t" && mv "$dest.t" "$dest"
}

P2="$TEST_TMPDIR/packet-v2.json"; mk_v2 "$P2"
D2="$V2/docs/polylane/design"

assert_ok "v2-shape-is-valid" jq -e . "$P2"
assert_ok "v2-prepares-versioned-packet" "$VISUAL" prepare "$V2/.polylane/run.json" "$P2"
assert_ok "v2-validates-versioned-packet" "$VISUAL" validate "$V2/.polylane/run.json"
assert_ok "v2-emits-design-lock" test -s "$D2/DESIGN-LOCK.json"
assert_ok "v2-emits-tournament-input" test -s "$D2/TOURNAMENT-INPUT.json"
assert_eq "v2-tournament-has-three-slots" "3" "$(jq '.candidates | length' "$D2/TOURNAMENT-INPUT.json")"
assert_eq "v2-tournament-has-no-winner" "null" "$(jq -c '.winner' "$D2/TOURNAMENT-INPUT.json")"
assert_eq "v2-tournament-slots-unrendered" "false false false" "$(jq -r '[.candidates[].winner]|join(" ")' "$D2/TOURNAMENT-INPUT.json")"
assert_eq "v2-tournament-binds-directions" "editorial kinetic native" "$(jq -r '[.candidates[].direction]|sort|join(" ")' "$D2/TOURNAMENT-INPUT.json")"
assert_eq "v2-tournament-slots-sorted" "slot-1 slot-2 slot-3" "$(jq -r '[.candidates[].slot]|join(" ")' "$D2/TOURNAMENT-INPUT.json")"

# --- negative matrix (each mutation must reject) ---
neg() {  # neg NAME jq_filter
  local name="$1" filter="$2" bad="$TEST_TMPDIR/bad.json"
  mk_v2 "$bad"; jq "$filter" "$bad" > "$bad.t" && mv "$bad.t" "$bad"
  assert_fail "$name" "$VISUAL" prepare "$V2/.polylane/run.json" "$bad"
}

neg "v2-rejects-winner-before-render" '.winner="native"'
neg "v2-rejects-unknown-key" '.directions[0].is_winner=true'
neg "v2-rejects-bad-goal-hash" '.goal.ultimate_goal_sha256="deadbeef"'
neg "v2-rejects-goal-drift-in-lock" '.design_lock.goal_hash="0000000000000000000000000000000000000000000000000000000000000001"'
neg "v2-rejects-malformed-hash" '.references[0].desktop_sha256="XYZ"'
neg "v2-rejects-tampered-source-hash" '.design_lock.source_packet_hash="'"$(printf '%064d' 0)"'"'
neg "v2-rejects-injection-in-field" '.directions[0].product_thesis="$(rm -rf /)"'
neg "v2-rejects-absolute-screenshot" '.references[0].desktop_screenshot="/etc/passwd"'
neg "v2-rejects-traversal-screenshot" '.references[0].mobile_screenshot="../secret.png"'
neg "v2-rejects-duplicate-direction-id" '.directions[1].id="native"'
neg "v2-rejects-nondivergent-directions" '.directions[1].signature_moment=.directions[0].signature_moment | .directions[1].token_system=.directions[0].token_system | .directions[1].layout_model=.directions[0].layout_model'
neg "v2-rejects-dominant-reference" '.directions |= map(.sources=["a","b"])'
neg "v2-rejects-missing-wildcard" '.references[3].kind="relevant"'
neg "v2-rejects-stale-access-date" '.references[0].access_date="2026/08/01"'
neg "v2-rejects-tampered-lock-hash" '.design_lock_sha256="'"$(printf '%064d' 0)"'"'

# duplicate bytes: two references pointing at byte-identical files.
DUP="$TEST_TMPDIR/dup.json"; mk_v2 "$DUP"
cp "$V2/evidence/a-d.png" "$V2/evidence/b-d.png"
jq --arg h "$(_file "$V2/evidence/b-d.png")" '(.references[]|select(.id=="b")).desktop_sha256=$h' "$DUP" > "$DUP.t" && mv "$DUP.t" "$DUP"
# a-d and b-d now byte-identical → shape must reject duplicate screenshot bytes.
assert_fail "v2-rejects-duplicate-image-bytes" "$VISUAL" prepare "$V2/.polylane/run.json" "$DUP"
printf 'pixels-of-b-d' > "$V2/evidence/b-d.png"   # restore distinct bytes

# stale evidence: file bytes change after the packet was prepared.
mk_v2 "$P2"
assert_ok "v2-reprepare-clean" "$VISUAL" prepare "$V2/.polylane/run.json" "$P2"
printf 'tampered-after-record' > "$V2/evidence/a-d.png"
assert_fail "v2-rejects-stale-screenshot-bytes" "$VISUAL" validate "$V2/.polylane/run.json"
printf 'pixels-of-a-d' > "$V2/evidence/a-d.png"   # restore

# symlinked screenshot is not real evidence.
mk_v2 "$P2"; "$VISUAL" prepare "$V2/.polylane/run.json" "$P2" >/dev/null 2>&1
rm -f "$V2/evidence/a-d.png"; ln -s "$V2/evidence/b-d.png" "$V2/evidence/a-d.png"
assert_fail "v2-rejects-symlinked-screenshot" "$VISUAL" validate "$V2/.polylane/run.json"
rm -f "$V2/evidence/a-d.png"; printf 'pixels-of-a-d' > "$V2/evidence/a-d.png"

# frozen lock must match the packet.
mk_v2 "$P2"; "$VISUAL" prepare "$V2/.polylane/run.json" "$P2" >/dev/null 2>&1
printf '{"tampered":true}\n' > "$D2/DESIGN-LOCK.json"
assert_fail "v2-rejects-unfrozen-design-lock" "$VISUAL" validate "$V2/.polylane/run.json"

finish
