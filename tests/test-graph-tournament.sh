#!/usr/bin/env bash
# test-graph-tournament.sh — polylane-scope.sh candidate-group extension.
#
# A tournament runs exactly three same-base candidate lanes that DELIBERATELY
# share one module scope. Ordinary lane isolation must still hold: the three may
# overlap only inside the declared exclusive group, no ordinary lane may overlap
# them, and exactly one selected tip may reach integration. Legacy manifests
# (no candidate_group) must behave exactly as before — test-scope.sh still owns
# that contract and is not touched here.
. "$(cd "$(dirname "$0")" && pwd)/helpers.sh"
SCOPE="$(cd "$(dirname "$RUNNER")" && pwd)/polylane-scope.sh"

command -v jq >/dev/null 2>&1 || { pass "graph-tournament-skipped-no-jq"; finish; exit 0; }
make_tmpdir
T="$TEST_TMPDIR"

# A well-formed group: three members share ONE module glob plus their own
# canonical status markers; an ordinary lane is disjoint.
cat > "$T/ok.json" <<'JSON'
{"lanes":[
  {"name":"ordinary","own_globs":["src/other/**","docs/status-ordinary.md"]},
  {"name":"cand-a","own_globs":["src/candidate/**","docs/status-cand-a.md"]},
  {"name":"cand-b","own_globs":["src/candidate/**","docs/status-cand-b.md"]},
  {"name":"cand-c","own_globs":["src/candidate/**","docs/status-cand-c.md"]}
],
"candidate_group":{"members":["cand-a","cand-b","cand-c"],"shared_globs":["src/candidate/**"],"selected":"cand-b"}}
JSON
assert_ok "graph-static-allows-three-same-base-candidates" "$SCOPE" check-static "$T/ok.json"
assert_ok "graph-candidates-valid-group" "$SCOPE" check-candidates "$T/ok.json"
assert_ok "graph-status-still-canonical" "$SCOPE" check-status "$T/ok.json"
assert_eq "graph-integration-tip-is-the-single-selected" "cand-b" "$("$SCOPE" integration-tip "$T/ok.json")"

# Legacy manifest without a candidate_group is unchanged: no group is fine.
cat > "$T/legacy.json" <<'JSON'
{"lanes":[{"name":"a","own_globs":["src/a/**"]},{"name":"b","own_globs":["src/b/**"]}]}
JSON
assert_ok "graph-legacy-static-clean" "$SCOPE" check-static "$T/legacy.json"
assert_ok "graph-legacy-candidates-noop" "$SCOPE" check-candidates "$T/legacy.json"
assert_fail "graph-legacy-has-no-integration-tip" "$SCOPE" integration-tip "$T/legacy.json"

# Ordinary lane may NOT overlap the exclusive candidate scope.
cat > "$T/ordinary-overlap.json" <<'JSON'
{"lanes":[
  {"name":"ordinary","own_globs":["src/candidate/shared.ts","docs/status-ordinary.md"]},
  {"name":"cand-a","own_globs":["src/candidate/**","docs/status-cand-a.md"]},
  {"name":"cand-b","own_globs":["src/candidate/**","docs/status-cand-b.md"]},
  {"name":"cand-c","own_globs":["src/candidate/**","docs/status-cand-c.md"]}
],
"candidate_group":{"members":["cand-a","cand-b","cand-c"],"shared_globs":["src/candidate/**"]}}
JSON
assert_fail "graph-static-rejects-ordinary-into-candidate-scope" "$SCOPE" check-static "$T/ordinary-overlap.json"
assert_contains "graph-ordinary-overlap-witness" "SCOPE-OVERLAP" "$("$SCOPE" check-static "$T/ordinary-overlap.json" 2>&1)"

# Wrong member count: exactly three.
cat > "$T/two.json" <<'JSON'
{"lanes":[
  {"name":"cand-a","own_globs":["src/candidate/**","docs/status-cand-a.md"]},
  {"name":"cand-b","own_globs":["src/candidate/**","docs/status-cand-b.md"]}
],
"candidate_group":{"members":["cand-a","cand-b"],"shared_globs":["src/candidate/**"]}}
JSON
assert_fail "graph-candidates-rejects-two" "$SCOPE" check-candidates "$T/two.json"
cat > "$T/four.json" <<'JSON'
{"lanes":[
  {"name":"cand-a","own_globs":["src/candidate/**","docs/status-cand-a.md"]},
  {"name":"cand-b","own_globs":["src/candidate/**","docs/status-cand-b.md"]},
  {"name":"cand-c","own_globs":["src/candidate/**","docs/status-cand-c.md"]},
  {"name":"cand-d","own_globs":["src/candidate/**","docs/status-cand-d.md"]}
],
"candidate_group":{"members":["cand-a","cand-b","cand-c","cand-d"],"shared_globs":["src/candidate/**"]}}
JSON
assert_fail "graph-candidates-rejects-four" "$SCOPE" check-candidates "$T/four.json"

# A member that reaches OUTSIDE the shared exclusive scope is rejected: the group
# may overlap only inside the declared group globs.
cat > "$T/escape.json" <<'JSON'
{"lanes":[
  {"name":"cand-a","own_globs":["src/candidate/**","docs/status-cand-a.md"]},
  {"name":"cand-b","own_globs":["src/candidate/**","src/other/**","docs/status-cand-b.md"]},
  {"name":"cand-c","own_globs":["src/candidate/**","docs/status-cand-c.md"]}
],
"candidate_group":{"members":["cand-a","cand-b","cand-c"],"shared_globs":["src/candidate/**"]}}
JSON
assert_fail "graph-candidates-rejects-member-escaping-shared-scope" "$SCOPE" check-candidates "$T/escape.json"

# selected must name a real member; a non-member selection is rejected.
cat > "$T/badsel.json" <<'JSON'
{"lanes":[
  {"name":"cand-a","own_globs":["src/candidate/**","docs/status-cand-a.md"]},
  {"name":"cand-b","own_globs":["src/candidate/**","docs/status-cand-b.md"]},
  {"name":"cand-c","own_globs":["src/candidate/**","docs/status-cand-c.md"]}
],
"candidate_group":{"members":["cand-a","cand-b","cand-c"],"shared_globs":["src/candidate/**"],"selected":"cand-z"}}
JSON
assert_fail "graph-candidates-rejects-nonmember-selected" "$SCOPE" check-candidates "$T/badsel.json"

# A member missing from .lanes is rejected.
cat > "$T/ghost.json" <<'JSON'
{"lanes":[
  {"name":"cand-a","own_globs":["src/candidate/**","docs/status-cand-a.md"]},
  {"name":"cand-b","own_globs":["src/candidate/**","docs/status-cand-b.md"]}
],
"candidate_group":{"members":["cand-a","cand-b","cand-ghost"],"shared_globs":["src/candidate/**"]}}
JSON
assert_fail "graph-candidates-rejects-ghost-member" "$SCOPE" check-candidates "$T/ghost.json"

# integration-tip requires exactly one selected member; ambiguity fails closed.
cat > "$T/nosel.json" <<'JSON'
{"lanes":[
  {"name":"cand-a","own_globs":["src/candidate/**","docs/status-cand-a.md"]},
  {"name":"cand-b","own_globs":["src/candidate/**","docs/status-cand-b.md"]},
  {"name":"cand-c","own_globs":["src/candidate/**","docs/status-cand-c.md"]}
],
"candidate_group":{"members":["cand-a","cand-b","cand-c"],"shared_globs":["src/candidate/**"]}}
JSON
assert_fail "graph-integration-tip-requires-selection" "$SCOPE" integration-tip "$T/nosel.json"

finish
