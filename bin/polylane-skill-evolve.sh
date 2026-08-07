#!/usr/bin/env bash
# polylane-skill-evolve.sh — evidence-gated skill champion/challenger lifecycle.
#
# The mutator is intentionally outside this helper: an agent may propose a
# challenger, but only frozen adapters, hidden cases, and blind judges may
# promote it. The live skill is compare-and-swap protected and every generation
# remains available for rollback.
set -euo pipefail

command -v jq >/dev/null 2>&1 || { echo "skill-evolve: jq required" >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "skill-evolve: git required" >&2; exit 1; }

usage() {
  cat >&2 <<'EOF'
usage: polylane-skill-evolve.sh validate <evals.json>
       polylane-skill-evolve.sh init <workspace> <active-skill-dir> <evals.json>
       polylane-skill-evolve.sh observe <workspace> <cycle> <skill> <helped|unused|hurt|regression|correction> <summary> [evidence]
       polylane-skill-evolve.sh eligible <workspace> <skill>
       polylane-skill-evolve.sh packet <workspace> <skill>
       polylane-skill-evolve.sh stage <workspace> <candidate-id> <skill-dir> <reason>
       polylane-skill-evolve.sh compare <workspace> <candidate-id>
       polylane-skill-evolve.sh select <workspace> <candidate-id> [candidate-id...]
       polylane-skill-evolve.sh promote <workspace> <candidate-id> <active-skill-dir>
       polylane-skill-evolve.sh canary <workspace> <active-skill-dir>
       polylane-skill-evolve.sh rollback <workspace> <active-skill-dir>
       polylane-skill-evolve.sh recover <workspace>
       polylane-skill-evolve.sh status <workspace> [--json]
EOF
  exit 2
}

now_utc() { date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || printf '?'; }

kill_descendants() {
  local parent="$1" child children
  children=$(ps -axo pid=,ppid= 2>/dev/null | awk -v parent="$parent" '$2==parent {print $1}')
  for child in $children; do kill_descendants "$child"; kill -TERM "$child" 2>/dev/null || true; done
}

# run_bounded SECONDS COMMAND... — portable wall-clock cap for untrusted
# evaluators. Kill descendants before the adapter so a timed-out agent CLI does
# not survive as an orphan and continue spending tokens.
run_bounded() {
  local seconds="$1"; shift
  local pid ticks=0 max_ticks rc=0
  case "$seconds" in ''|*[!0-9]*) return 2 ;; esac
  [ "$seconds" -ge 1 ] || return 2
  max_ticks=$((seconds * 10))
  "$@" & pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$ticks" -ge "$max_ticks" ]; then
      kill_descendants "$pid"
      kill -TERM "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      return 124
    fi
    sleep 0.1
    ticks=$((ticks + 1))
  done
  wait "$pid" || rc=$?
  return "$rc"
}

safe_id() {
  case "$1" in ''|*[!A-Za-z0-9._-]*) return 1 ;; *) return 0 ;; esac
}

canonical_dir() {
  [ -d "$1" ] || return 1
  (cd "$1" 2>/dev/null && pwd -P)
}

canonical_file() {
  [ -f "$1" ] || return 1
  local parent base
  parent=$(cd "$(dirname "$1")" 2>/dev/null && pwd -P) || return 1
  base=$(basename "$1")
  printf '%s/%s\n' "$parent" "$base"
}

# Resolve a directory that may not exist without creating it. Refuse parent
# traversal so the containment test below cannot be bypassed textually.
prospective_dir() {
  local target="$1" tail="" base
  case "/$target/" in */../*) return 1 ;; esac
  case "$target" in /*) ;; *) target="$PWD/$target" ;; esac
  while [ ! -d "$target" ]; do
    base=$(basename "$target")
    [ "$base" != . ] && [ "$base" != .. ] || return 1
    tail="/$base$tail"
    [ "$(dirname "$target")" != "$target" ] || return 1
    target=$(dirname "$target")
  done
  target=$(canonical_dir "$target") || return 1
  printf '%s%s\n' "$target" "$tail"
}

paths_overlap() {
  local left="${1%/}/" right="${2%/}/"
  case "$left" in "$right"*) return 0 ;; esac
  case "$right" in "$left"*) return 0 ;; esac
  return 1
}

validate_skill_dir() {
  local dir="$1"
  [ -d "$dir" ] || { echo "skill-evolve: skill directory not found: $dir" >&2; return 2; }
  [ -f "$dir/SKILL.md" ] || { echo "skill-evolve: SKILL.md missing: $dir" >&2; return 2; }
  if find "$dir" -type l -print | grep -q .; then
    echo "skill-evolve: symlinks are not allowed in skill snapshots: $dir" >&2
    return 2
  fi
  grep -q '^name:[[:space:]]*[A-Za-z0-9-][A-Za-z0-9-]*[[:space:]]*$' "$dir/SKILL.md" || {
    echo "skill-evolve: SKILL.md has no valid name frontmatter" >&2; return 2; }
}

copy_tree() {
  local src="$1" dest="$2"
  validate_skill_dir "$src"
  mkdir -p "$dest"
  cp -R "$src/." "$dest/"
}

skill_hash() {
  local dir="$1"
  validate_skill_dir "$dir" >/dev/null
  (
    cd "$dir"
    find . -type f -print | LC_ALL=C sort | while IFS= read -r file; do
      printf '%s\n' "$file"
      git hash-object "$file"
    done
  ) | git hash-object --stdin
}

json_hash() { git hash-object "$1"; }

atomic_jq() {
  local file="$1"; shift
  local tmp="$file.tmp.$$"
  jq "$@" "$file" > "$tmp"
  mv "$tmp" "$file"
}

append_history() {
  local ws="$1" event="$2" detail="$3"
  jq -cn --arg event "$event" --arg detail "$detail" --arg ts "$(now_utc)" \
    '{event:$event,detail:$detail,ts:$ts}' >> "$ws/history.jsonl"
}

state_file() { printf '%s/state.json\n' "$1"; }
evals_file() { printf '%s/evals/frozen.json\n' "$1"; }

require_workspace() {
  [ -f "$(state_file "$1")" ] || { echo "skill-evolve: workspace is not initialized: $1" >&2; return 2; }
  [ -f "$(evals_file "$1")" ] || { echo "skill-evolve: frozen evaluations missing: $1" >&2; return 2; }
}

lock_acquire() {
  local ws="$1" tries=0 pid
  local lock="$ws/.lock"
  while ! mkdir "$lock" 2>/dev/null; do
    tries=$((tries + 1))
    if [ -f "$lock/pid" ]; then
      pid=$(sed -n '1p' "$lock/pid" 2>/dev/null || true)
      case "$pid" in ''|*[!0-9]*) pid=0 ;; esac
      if [ "$pid" -gt 1 ] && ! kill -0 "$pid" 2>/dev/null; then
        rm -f "$lock/pid" 2>/dev/null || true
        rmdir "$lock" 2>/dev/null || true
      fi
    fi
    [ "$tries" -lt 100 ] || { echo "skill-evolve: workspace lock timed out" >&2; return 9; }
    sleep 0.05
  done
  printf '%s\n' "$$" > "$lock/pid"
}

lock_release() {
  local lock="$1/.lock"
  rm -f "$lock/pid" 2>/dev/null || true
  rmdir "$lock" 2>/dev/null || true
}

adapter_source() {
  local evals="$1" path="$2" parent alternate
  case "$path" in
    /*) ;;
    *) parent=$(cd "$(dirname "$evals")" && pwd -P); path="$parent/$path" ;;
  esac
  # The source/Claude package keeps shared helpers in bin/, while the standalone
  # Codex package installs the identical helpers in scripts/. Keep one frozen
  # corpus portable across both layouts without rewriting its policy at install.
  if [ ! -f "$path" ]; then
    case "$path" in
      */bin/*)
        alternate="${path%%/bin/*}/scripts/${path#*/bin/}"
        [ -f "$alternate" ] && path="$alternate"
        ;;
    esac
  fi
  canonical_file "$path"
}

valid_evals_json() {
  jq -e '
    type == "object" and .schema == "polylane-skill-evals/v1" and
    (.skill_name | type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]*$")) and
    (.model | type == "string" and length > 0) and
    (.effort | type == "string" and length > 0) and
    (.thresholds | type == "object") and
    (.thresholds.min_dev_delta | type == "number") and
    (.thresholds.min_hidden_delta | type == "number") and
    (.thresholds.max_token_regression_pct | type == "number" and . >= 0) and
    (.thresholds.max_duration_regression_pct | type == "number" and . >= 0) and
    (.thresholds.max_intervention_regression | type == "number" and . >= 0) and
    (.thresholds.hurt_recurrence | type == "number" and floor == . and . >= 1) and
    (.thresholds.unused_recurrence | type == "number" and floor == . and . >= 1) and
    (.cases | type == "array" and length >= 3 and
      all(.[];
        (.id | type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]*$")) and
        (.split == "train" or .split == "dev" or .split == "hidden") and
        (.weight | type == "number" and . > 0) and
        (.min_score | type == "number" and . >= 0 and . <= 1) and
        (.hard | type == "boolean") and
        (.repeats | type == "number" and floor == . and . >= 1 and . <= 5) and
        (.timeout_s | type == "number" and floor == . and . >= 1 and . <= 3600) and
        (.adapter | type == "string" and length > 0))) and
    ([.cases[].id] | unique | length) == (.cases | length) and
    ([.cases[].split] | index("train") != null) and
    ([.cases[].split] | index("dev") != null) and
    ([.cases[].split] | index("hidden") != null) and
    (.judges | type == "array" and length == 3 and
      all(.[];
        (.name | type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]*$")) and
        (.timeout_s | type == "number" and floor == . and . >= 1 and . <= 3600) and
        (.adapter | type == "string" and length > 0))) and
    ([.judges[].name] | unique | length) == 3
  ' "$1" >/dev/null
}

cmd_validate() {
  local evals="$1" kind name adapter source
  [ -f "$evals" ] || { echo "skill-evolve: eval file not found: $evals" >&2; return 2; }
  jq -e . "$evals" >/dev/null 2>&1 || { echo "skill-evolve: malformed eval JSON" >&2; return 2; }
  valid_evals_json "$evals" || { echo "skill-evolve: invalid polylane-skill-evals/v1 contract" >&2; return 2; }
  while IFS=$'\t' read -r kind name adapter; do
    source=$(adapter_source "$evals" "$adapter") || {
      echo "skill-evolve: $kind adapter not found for $name: $adapter" >&2; return 2; }
    [ -x "$source" ] || { echo "skill-evolve: adapter is not executable: $source" >&2; return 2; }
  done < <(jq -r '.cases[] | ["case",.id,.adapter] | @tsv' "$evals"; jq -r '.judges[] | ["judge",.name,.adapter] | @tsv' "$evals")
  printf 'skill-evolve: valid corpus (%s cases, 3 blind judges)\n' "$(jq '.cases|length' "$evals")"
}

freeze_evals() {
  local ws="$1" original="$2" id adapter source dest tmp
  local frozen="$ws/evals/frozen.json"
  mkdir -p "$ws/evals/adapters"
  cp "$original" "$frozen"
  while IFS=$'\t' read -r id adapter; do
    source=$(adapter_source "$original" "$adapter")
    dest="$ws/evals/adapters/case-$id"
    cp "$source" "$dest"; chmod +x "$dest"
    tmp="$frozen.tmp.$$"
    jq --arg id "$id" --arg dest "$dest" '(.cases[] | select(.id==$id).adapter) = $dest' "$frozen" > "$tmp"
    mv "$tmp" "$frozen"
  done < <(jq -r '.cases[] | [.id,.adapter] | @tsv' "$original")
  while IFS=$'\t' read -r id adapter; do
    source=$(adapter_source "$original" "$adapter")
    dest="$ws/evals/adapters/judge-$id"
    cp "$source" "$dest"; chmod +x "$dest"
    tmp="$frozen.tmp.$$"
    jq --arg id "$id" --arg dest "$dest" '(.judges[] | select(.name==$id).adapter) = $dest' "$frozen" > "$tmp"
    mv "$tmp" "$frozen"
  done < <(jq -r '.judges[] | [.name,.adapter] | @tsv' "$original")
  chmod 600 "$frozen"
}

cmd_init() {
  local ws="$1" active="$2" evals="$3" active_abs ws_abs hash state
  cmd_validate "$evals" >/dev/null
  validate_skill_dir "$active"
  active_abs=$(canonical_dir "$active")
  ws_abs=$(prospective_dir "$ws") || { echo "skill-evolve: unsafe workspace path: $ws" >&2; return 2; }
  if paths_overlap "$active_abs" "$ws_abs"; then
    echo "skill-evolve: workspace and active skill must not overlap" >&2
    return 2
  fi
  mkdir -p "$ws_abs"
  ws=$(canonical_dir "$ws_abs")
  [ ! -e "$ws/state.json" ] || { echo "skill-evolve: workspace already initialized" >&2; return 2; }
  mkdir -p "$ws/versions/generation-0000/skill" "$ws/candidates" "$ws/runs" "$ws/activations"
  copy_tree "$active_abs" "$ws/versions/generation-0000/skill"
  hash=$(skill_hash "$ws/versions/generation-0000/skill")
  freeze_evals "$ws" "$evals"
  state="$ws/state.json"
  jq -cn --arg skill "$(jq -r '.skill_name' "$ws/evals/frozen.json")" \
    --arg active "$active_abs" --arg hash "$hash" --arg eval_hash "$(json_hash "$ws/evals/frozen.json")" \
    --arg ts "$(now_utc)" \
    '{schema:"polylane-skill-evolution/v1",skill_name:$skill,generation:0,active_path:$active,
      champion:{generation:0,version:"generation-0000",path:"versions/generation-0000/skill",hash:$hash,candidate:null},
      previous:null,observation_cursor:0,eval_hash:$eval_hash,created_at:$ts}' > "$state"
  : > "$ws/observations.jsonl"
  : > "$ws/history.jsonl"
  append_history "$ws" init "champion=generation-0000 hash=$hash"
  printf 'INITIALIZED %s champion=generation-0000\n' "$ws"
}

eligible_counts() {
  local ws="$1" skill="$2" state cursor evals
  state=$(state_file "$ws"); evals=$(evals_file "$ws")
  cursor=$(jq -r '.observation_cursor // 0' "$state")
  if [ ! -s "$ws/observations.jsonl" ]; then
    printf '{"hurt":0,"unused":0,"regression":0,"correction":0}\n'; return
  fi
  jq -s --arg skill "$skill" --argjson cursor "$cursor" '
    map(select(.skill==$skill and .seq>$cursor)) |
    {hurt:(map(select(.outcome=="hurt"))|length),
     unused:(map(select(.outcome=="unused"))|length),
     regression:(map(select(.outcome=="regression"))|length),
     correction:(map(select(.outcome=="correction"))|length)}' "$ws/observations.jsonl"
}

is_eligible() {
  local ws="$1" skill="$2" counts hurt unused
  counts=$(eligible_counts "$ws" "$skill")
  hurt=$(jq -r '.thresholds.hurt_recurrence' "$(evals_file "$ws")")
  unused=$(jq -r '.thresholds.unused_recurrence' "$(evals_file "$ws")")
  jq -e --argjson hurt "$hurt" --argjson unused "$unused" \
    '(.regression >= 1) or (.correction >= 2) or (.hurt >= $hurt) or (.unused >= $unused)' \
    <<<"$counts" >/dev/null
}

cmd_eligible() {
  local ws="$1" skill="$2" counts
  require_workspace "$ws"
  counts=$(eligible_counts "$ws" "$skill")
  if is_eligible "$ws" "$skill"; then
    printf 'EVOLVE %s hurt=%s unused=%s regression=%s correction=%s\n' "$skill" \
      "$(jq -r .hurt <<<"$counts")" "$(jq -r .unused <<<"$counts")" \
      "$(jq -r .regression <<<"$counts")" "$(jq -r .correction <<<"$counts")"
    return 0
  fi
  printf 'STABLE %s\n' "$skill"
  return 3
}

cmd_observe() {
  local ws="$1" cycle="$2" skill="$3" outcome="$4" summary="$5" evidence="${6:-}" key seq
  require_workspace "$ws"
  case "$cycle" in ''|*[!0-9]*) echo "skill-evolve: cycle must be an integer" >&2; return 2 ;; esac
  safe_id "$skill" || { echo "skill-evolve: invalid skill id" >&2; return 2; }
  case "$outcome" in helped|unused|hurt|regression|correction) ;; *) echo "skill-evolve: invalid outcome" >&2; return 2 ;; esac
  [ -n "$summary" ] || { echo "skill-evolve: observation summary is required" >&2; return 2; }
  lock_acquire "$ws"; trap 'lock_release "$ws"' EXIT INT TERM HUP
  key=$(printf '%s\n%s\n%s\n%s\n' "$skill" "$outcome" "$summary" "$evidence" | git hash-object --stdin)
  if ! { [ -s "$ws/observations.jsonl" ] && jq -e --arg key "$key" 'select(.key==$key)' "$ws/observations.jsonl" >/dev/null 2>&1; }; then
    seq=$(( $(wc -l < "$ws/observations.jsonl" | tr -d ' ') + 1 ))
    jq -cn --argjson seq "$seq" --argjson cycle "$cycle" --arg skill "$skill" \
      --arg outcome "$outcome" --arg summary "$summary" --arg evidence "$evidence" \
      --arg key "$key" --arg ts "$(now_utc)" \
      '{seq:$seq,cycle:$cycle,skill:$skill,outcome:$outcome,summary:$summary,evidence:$evidence,key:$key,ts:$ts}' \
      >> "$ws/observations.jsonl"
  fi
  lock_release "$ws"; trap - EXIT INT TERM HUP
  cmd_eligible "$ws" "$skill"
}

cmd_packet() {
  local ws="$1" skill="$2" state evals cursor
  require_workspace "$ws"
  state=$(state_file "$ws"); evals=$(evals_file "$ws")
  cursor=$(jq -r '.observation_cursor // 0' "$state")
  printf '# Polylane skill challenger packet\n\n'
  printf 'Skill: %s\nChampion: %s\nChampion path: %s/%s\n\n' "$skill" \
    "$(jq -r '.champion.version' "$state")" "$ws" "$(jq -r '.champion.path' "$state")"
  printf 'Use `anthropic-skills:skill-creator` to produce variants and `superpowers:writing-skills` to pressure-test their instructions. Edit a copy; never edit the champion or active skill.\n\n'
  printf '## Evidence since the last promotion\n'
  if [ -s "$ws/observations.jsonl" ]; then
    jq -r --arg skill "$skill" --argjson cursor "$cursor" \
      'select(.skill==$skill and .seq>$cursor) | "- [\(.outcome)] cycle \(.cycle): \(.summary)\(if .evidence=="" then "" else " — " + .evidence end)"' \
      "$ws/observations.jsonl"
  fi
  printf '\n## Visible mutation cases\n'
  jq -r '.cases[] | select(.split != "hidden") | "- \(.split): \(.id) (minimum \(.min_score), hard=\(.hard))"' "$evals"
  printf '\nPromotion cases are held back. Stage the challenger, then let `compare` run frozen development, hidden, efficiency, and blind-judge gates.\n'
}

cmd_stage() {
  local ws="$1" id="$2" source="$3" reason="$4" dest hash
  require_workspace "$ws"
  safe_id "$id" || { echo "skill-evolve: invalid candidate id" >&2; return 2; }
  validate_skill_dir "$source"
  [ -n "$reason" ] || { echo "skill-evolve: candidate reason is required" >&2; return 2; }
  lock_acquire "$ws"; trap 'lock_release "$ws"' EXIT INT TERM HUP
  dest="$ws/candidates/$id"
  [ ! -e "$dest" ] || { echo "skill-evolve: candidate already exists: $id" >&2; lock_release "$ws"; trap - EXIT INT TERM HUP; return 2; }
  mkdir -p "$dest/skill"
  copy_tree "$source" "$dest/skill"
  hash=$(skill_hash "$dest/skill")
  jq -cn --arg id "$id" --arg reason "$reason" --arg hash "$hash" --arg ts "$(now_utc)" \
    '{schema:"polylane-skill-candidate/v1",id:$id,reason:$reason,hash:$hash,created_at:$ts}' > "$dest/candidate.json"
  append_history "$ws" stage "candidate=$id hash=$hash reason=$reason"
  lock_release "$ws"; trap - EXIT INT TERM HUP
  printf 'STAGED %s hash=%s\n' "$id" "$hash"
}

valid_eval_result() {
  [ -f "$1" ] && jq -e '
    type=="object" and
    (.score|type=="number" and .>=0 and .<=1) and
    (.hard_fail|type=="boolean") and
    (.tokens|type=="number" and .>=0 and floor==.) and
    (.duration_ms|type=="number" and .>=0 and floor==.) and
    (.interventions|type=="number" and .>=0 and floor==.)
  ' "$1" >/dev/null 2>&1
}

append_eval_row() {
  local out="$1" role="$2" case_json="$3" repeat="$4" result="$5" rc="$6" valid=false
  valid_eval_result "$result" && valid=true
  jq -cn --arg role "$role" --slurpfile case "$case_json" --argjson repeat "$repeat" \
    --argjson adapter_rc "$rc" --argjson valid "$valid" \
    --slurpfile result "$result" '
      ($case[0]) as $c | ($result[0] // {}) as $r |
      {role:$role,id:$c.id,split:$c.split,weight:$c.weight,min_score:$c.min_score,hard:$c.hard,
       repeat:$repeat,adapter_rc:$adapter_rc,valid:$valid,
       score:(if $valid then $r.score else null end),
       hard_fail:(if $valid then $r.hard_fail else true end),
       tokens:(if $valid then $r.tokens else null end),
       duration_ms:(if $valid then $r.duration_ms else null end),
       interventions:(if $valid then $r.interventions else null end)}' >> "$out"
}

run_eval_adapter() {
  local adapter="$1" skill="$2" case_json="$3" work="$4" result="$5" variant="$6" repeat="$7" evals="$8" timeout_s
  mkdir -p "$work"
  rm -f "$result"
  timeout_s=$(jq -r '.timeout_s' "$case_json")
  run_bounded "$timeout_s" env \
    POLYLANE_SKILL_PATH="$skill" \
    POLYLANE_SKILL_EVAL_CASE="$case_json" \
    POLYLANE_SKILL_EVAL_RESULT="$result" \
    POLYLANE_SKILL_EVAL_WORKDIR="$work" \
    POLYLANE_SKILL_EVAL_MODEL="$(jq -r '.model' "$evals")" \
    POLYLANE_SKILL_EVAL_EFFORT="$(jq -r '.effort' "$evals")" \
    POLYLANE_SKILL_EVAL_VARIANT="$variant" \
    POLYLANE_SKILL_EVAL_REPEAT="$repeat" \
    "$adapter" > "$work/stdout.log" 2> "$work/stderr.log"
}

run_case_pair() {
  local evals="$1" run="$2" case_b64="$3" champion="$4" candidate="$5" rows="$6"
  local case_json id adapter repeats rep cw nw cr nr cpid npid crc nrc
  id=$(printf '%s' "$case_b64" | base64 -D 2>/dev/null || printf '%s' "$case_b64" | base64 -d)
  case_json="$run/case-$RANDOM-$$.json"
  printf '%s\n' "$id" > "$case_json"
  id=$(jq -r '.id' "$case_json"); adapter=$(jq -r '.adapter' "$case_json"); repeats=$(jq -r '.repeats' "$case_json")
  rep=1
  while [ "$rep" -le "$repeats" ]; do
    cw="$run/cases/$id/repeat-$rep/champion"; nw="$run/cases/$id/repeat-$rep/candidate"
    cr="$cw/result.json"; nr="$nw/result.json"
    mkdir -p "$cw" "$nw"
    ( set +e; run_eval_adapter "$adapter" "$champion" "$case_json" "$cw" "$cr" champion "$rep" "$evals"; printf '%s\n' "$?" > "$cw/rc" ) & cpid=$!
    ( set +e; run_eval_adapter "$adapter" "$candidate" "$case_json" "$nw" "$nr" candidate "$rep" "$evals"; printf '%s\n' "$?" > "$nw/rc" ) & npid=$!
    wait "$cpid" || true; wait "$npid" || true
    crc=$(sed -n '1p' "$cw/rc" 2>/dev/null || printf 99); nrc=$(sed -n '1p' "$nw/rc" 2>/dev/null || printf 99)
    [ -f "$cr" ] || printf '{}\n' > "$cr"
    [ -f "$nr" ] || printf '{}\n' > "$nr"
    append_eval_row "$rows" champion "$case_json" "$rep" "$cr" "$crc"
    append_eval_row "$rows" candidate "$case_json" "$rep" "$nr" "$nrc"
    rep=$((rep + 1))
  done
  rm -f "$case_json"
}

weighted_score() {
  local rows="$1" role="$2" split="$3"
  jq -s -r --arg role "$role" --arg split "$split" '
    [ .[] | select(.role==$role and .split==$split) ] as $r |
    if ($r|length)==0 or any($r[]; .valid!=true or .adapter_rc!=0 or .score==null) then null
    else (($r|map(.score*.weight)|add) / ($r|map(.weight)|add)) end' "$rows"
}

mean_metric() {
  local rows="$1" role="$2" metric="$3"
  jq -s -r --arg role "$role" --arg metric "$metric" '
    [ .[] | select(.role==$role) | .[$metric] ] as $v |
    if ($v|length)==0 or any($v[]; .==null) then null else ($v|add)/($v|length) end' "$rows"
}

number_ge() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a >= b) }'; }
number_le() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a <= b) }'; }

within_pct() {
  local candidate="$1" champion="$2" pct="$3"
  awk -v c="$candidate" -v b="$champion" -v p="$pct" 'BEGIN {
    if (b == 0) exit !(c == 0); exit !(c <= b * (1 + p / 100));
  }'
}

add_reason() { printf '%s\n' "$2" >> "$1"; }

valid_judge_result() {
  [ -f "$1" ] && jq -e '
    type=="object" and (.winner=="A" or .winner=="B" or .winner=="tie") and
    (.confidence|type=="number" and .>=0 and .<=1) and
    (.hard_fail|type=="boolean") and
    (.tokens|type=="number" and .>=0 and floor==.) and
    (.duration_ms|type=="number" and .>=0 and floor==.)
  ' "$1" >/dev/null 2>&1
}

run_blind_judges() {
  local ws="$1" run="$2" champion="$3" candidate="$4" out="$5" evals name adapter timeout_s work checksum label result rc winner mapped
  evals=$(evals_file "$ws"); : > "$out"
  while IFS=$'\t' read -r name adapter timeout_s; do
    work="$run/judges/$name"; mkdir -p "$work/A" "$work/B"
    checksum=$(printf '%s:%s:%s\n' "$run" "$name" "$(skill_hash "$candidate")" | cksum | awk '{print $1}')
    if [ $((checksum % 2)) -eq 0 ]; then
      copy_tree "$candidate" "$work/A"; copy_tree "$champion" "$work/B"; label=A
    else
      copy_tree "$champion" "$work/A"; copy_tree "$candidate" "$work/B"; label=B
    fi
    result="$work/result.json"; rc=0
    run_bounded "$timeout_s" env \
      POLYLANE_SKILL_BLIND_A_PATH="$work/A" \
      POLYLANE_SKILL_BLIND_B_PATH="$work/B" \
      POLYLANE_SKILL_JUDGE_RESULT="$result" \
      POLYLANE_SKILL_JUDGE_WORKDIR="$work" \
      POLYLANE_SKILL_JUDGE_EVALS="$evals" \
      POLYLANE_SKILL_JUDGE_NAME="$name" \
      POLYLANE_SKILL_EVAL_MODEL="$(jq -r '.model' "$evals")" \
      POLYLANE_SKILL_EVAL_EFFORT="$(jq -r '.effort' "$evals")" \
      "$adapter" > "$work/stdout.log" 2> "$work/stderr.log" || rc=$?
    mapped=invalid; winner=invalid
    if [ "$rc" -eq 0 ] && valid_judge_result "$result" && [ "$(jq -r '.hard_fail' "$result")" = false ]; then
      winner=$(jq -r '.winner' "$result")
      case "$winner:$label" in
        tie:*) mapped=tie ;;
        A:A|B:B) mapped=candidate ;;
        A:B|B:A) mapped=champion ;;
      esac
    fi
    [ -f "$result" ] || printf '{}\n' > "$result"
    jq -cn --arg name "$name" --arg candidate_label "$label" --arg raw_winner "$winner" \
      --arg mapped "$mapped" --argjson adapter_rc "$rc" --slurpfile result "$result" \
      '{name:$name,candidate_label:$candidate_label,raw_winner:$raw_winner,winner:$mapped,
        adapter_rc:$adapter_rc,confidence:($result[0].confidence // null),
        hard_fail:(if ($result[0] | has("hard_fail")) then $result[0].hard_fail else true end),tokens:($result[0].tokens // null),
        duration_ms:($result[0].duration_ms // null)}' >> "$out"
  done < <(jq -r '.judges[] | [.name,.adapter,(.timeout_s|tostring)] | @tsv' "$evals")
}

cmd_compare() {
  local ws="$1" id="$2" state evals candidate_meta candidate champion candidate_hash champion_hash run rows reasons
  local cdev ndev chidden nhidden ctokens ntokens cduration nduration cinterventions ninterventions
  local min_dev min_hidden max_tokens max_duration max_interventions judge_rows judge_total judge_wins verdict run_id
  require_workspace "$ws"; safe_id "$id" || return 2
  state=$(state_file "$ws"); evals=$(evals_file "$ws"); candidate_meta="$ws/candidates/$id/candidate.json"
  [ -f "$candidate_meta" ] || { echo "skill-evolve: unknown candidate: $id" >&2; return 2; }
  lock_acquire "$ws"; trap 'lock_release "$ws"' EXIT INT TERM HUP
  candidate="$ws/candidates/$id/skill"; champion="$ws/$(jq -r '.champion.path' "$state")"
  candidate_hash=$(skill_hash "$candidate"); champion_hash=$(skill_hash "$champion")
  [ "$candidate_hash" = "$(jq -r '.hash' "$candidate_meta")" ] || { echo "skill-evolve: candidate snapshot changed" >&2; lock_release "$ws"; trap - EXIT INT TERM HUP; return 6; }
  [ "$champion_hash" = "$(jq -r '.champion.hash' "$state")" ] || { echo "skill-evolve: champion snapshot changed" >&2; lock_release "$ws"; trap - EXIT INT TERM HUP; return 6; }
  run_id="$(date -u '+%Y%m%dT%H%M%S' 2>/dev/null || date +%s)-$$"
  run="$ws/runs/$id/$run_id"; rows="$run/results.jsonl"; reasons="$run/reasons.txt"; mkdir -p "$run"; : > "$rows"; : > "$reasons"
  while IFS= read -r encoded; do
    run_case_pair "$evals" "$run" "$encoded" "$champion" "$candidate" "$rows"
  done < <(jq -c '.cases[]' "$evals" | while IFS= read -r line; do printf '%s' "$line" | base64 | tr -d '\r\n'; printf '\n'; done)

  if jq -s -e 'any(.[]; .valid!=true or .adapter_rc!=0)' "$rows" >/dev/null; then add_reason "$reasons" "invalid-or-failed-evaluator"; fi
  if jq -s -e 'any(.[]; .role=="candidate" and (.hard_fail==true or .score < .min_score))' "$rows" >/dev/null; then add_reason "$reasons" "candidate-hard-or-minimum-regression"; fi

  cdev=$(weighted_score "$rows" champion dev); ndev=$(weighted_score "$rows" candidate dev)
  chidden=$(weighted_score "$rows" champion hidden); nhidden=$(weighted_score "$rows" candidate hidden)
  ctokens=$(mean_metric "$rows" champion tokens); ntokens=$(mean_metric "$rows" candidate tokens)
  cduration=$(mean_metric "$rows" champion duration_ms); nduration=$(mean_metric "$rows" candidate duration_ms)
  cinterventions=$(mean_metric "$rows" champion interventions); ninterventions=$(mean_metric "$rows" candidate interventions)
  min_dev=$(jq -r '.thresholds.min_dev_delta' "$evals"); min_hidden=$(jq -r '.thresholds.min_hidden_delta' "$evals")
  max_tokens=$(jq -r '.thresholds.max_token_regression_pct' "$evals"); max_duration=$(jq -r '.thresholds.max_duration_regression_pct' "$evals")
  max_interventions=$(jq -r '.thresholds.max_intervention_regression' "$evals")
  case "$cdev:$ndev:$chidden:$nhidden" in *null*) add_reason "$reasons" "unknown-score" ;; *)
    number_ge "$ndev" "$(awk -v b="$cdev" -v d="$min_dev" 'BEGIN {print b+d}')" || add_reason "$reasons" "development-delta-below-minimum"
    number_ge "$nhidden" "$(awk -v b="$chidden" -v d="$min_hidden" 'BEGIN {print b+d}')" || add_reason "$reasons" "hidden-delta-below-minimum"
  esac
  case "$ctokens:$ntokens" in *null*) add_reason "$reasons" "unknown-token-cost" ;; *) within_pct "$ntokens" "$ctokens" "$max_tokens" || add_reason "$reasons" "token-regression" ;; esac
  case "$cduration:$nduration" in *null*) add_reason "$reasons" "unknown-duration" ;; *) within_pct "$nduration" "$cduration" "$max_duration" || add_reason "$reasons" "duration-regression" ;; esac
  case "$cinterventions:$ninterventions" in *null*) add_reason "$reasons" "unknown-interventions" ;; *)
    number_le "$ninterventions" "$(awk -v b="$cinterventions" -v d="$max_interventions" 'BEGIN {print b+d}')" || add_reason "$reasons" "intervention-regression" ;;
  esac

  judge_rows="$run/judges.jsonl"; judge_total=0; judge_wins=0
  if [ ! -s "$reasons" ]; then
    run_blind_judges "$ws" "$run" "$champion" "$candidate" "$judge_rows"
    judge_total=$(wc -l < "$judge_rows" | tr -d ' ')
    judge_wins=$(jq -s '[.[]|select(.winner=="candidate")]|length' "$judge_rows")
    [ "$judge_total" -eq 3 ] || add_reason "$reasons" "judge-count-invalid"
    jq -s -e 'any(.[]; .winner=="invalid" or .hard_fail==true or .adapter_rc!=0)' "$judge_rows" >/dev/null && add_reason "$reasons" "blind-judge-failure"
    [ "$judge_wins" -ge 2 ] || add_reason "$reasons" "blind-majority-not-won"
  else
    : > "$judge_rows"
  fi
  verdict=GO; [ -s "$reasons" ] && verdict=NO-GO
  jq -n --arg verdict "$verdict" --arg candidate "$id" --arg candidate_hash "$candidate_hash" \
    --arg champion_hash "$champion_hash" --arg run "$run" --argjson cdev "$cdev" --argjson ndev "$ndev" \
    --argjson chidden "$chidden" --argjson nhidden "$nhidden" --argjson ctokens "$ctokens" --argjson ntokens "$ntokens" \
    --argjson cduration "$cduration" --argjson nduration "$nduration" \
    --argjson cinterventions "$cinterventions" --argjson ninterventions "$ninterventions" \
    --argjson judge_total "$judge_total" --argjson judge_wins "$judge_wins" \
    --slurpfile reasons <(jq -R -s 'split("\n")|map(select(length>0))' "$reasons") --arg ts "$(now_utc)" \
    '{schema:"polylane-skill-verdict/v1",verdict:$verdict,candidate:$candidate,candidate_hash:$candidate_hash,
      champion_hash:$champion_hash,run:$run,development:{champion:$cdev,candidate:$ndev,delta:($ndev-$cdev)},
      hidden:{champion:$chidden,candidate:$nhidden,delta:($nhidden-$chidden)},
      cost:{champion_tokens:$ctokens,candidate_tokens:$ntokens,champion_duration_ms:$cduration,
        candidate_duration_ms:$nduration,champion_interventions:$cinterventions,candidate_interventions:$ninterventions},
      judges:{total:$judge_total,candidate_wins:$judge_wins},reasons:$reasons[0],ts:$ts}' \
      > "$ws/candidates/$id/verdict.json"
  append_history "$ws" compare "candidate=$id verdict=$verdict run=$run_id"
  lock_release "$ws"; trap - EXIT INT TERM HUP
  printf '%s candidate=%s run=%s\n' "$verdict" "$id" "$run_id"
  [ "$verdict" = GO ] || return 5
}

cmd_select() {
  local ws="$1"; shift
  local state champion_hash id verdict hidden dev tokens best="" bh="" bd="" bt=""
  require_workspace "$ws"; [ "$#" -gt 0 ] || usage
  state=$(state_file "$ws"); champion_hash=$(jq -r '.champion.hash' "$state")
  for id in "$@"; do
    safe_id "$id" || continue
    verdict="$ws/candidates/$id/verdict.json"
    [ -f "$verdict" ] || continue
    [ "$(jq -r '.verdict' "$verdict")" = GO ] || continue
    [ "$(jq -r '.champion_hash' "$verdict")" = "$champion_hash" ] || continue
    hidden=$(jq -r '.hidden.candidate' "$verdict"); dev=$(jq -r '.development.candidate' "$verdict")
    tokens=$(jq -r '.cost.candidate_tokens' "$verdict")
    if [ -z "$best" ] || awk -v h="$hidden" -v bh="$bh" -v d="$dev" -v bd="$bd" -v t="$tokens" -v bt="$bt" \
      'BEGIN { exit !((h>bh) || (h==bh && d>bd) || (h==bh && d==bd && t<bt)) }'; then
      best="$id"; bh="$hidden"; bd="$dev"; bt="$tokens"
    fi
  done
  [ -n "$best" ] || { echo "skill-evolve: no current-champion GO challenger" >&2; return 5; }
  printf '%s\n' "$best"
}

safe_active_target() {
  local target="$1" canon home_canon
  [ -d "$target" ] || return 1
  canon=$(canonical_dir "$target") || return 1
  home_canon=$(canonical_dir "${HOME:?}")
  case "$canon" in /|"$home_canon") return 1 ;; esac
  [ "$(basename "$canon")" != . ]
}

write_activation_journal() {
  local ws="$1" action="$2" active="$3" backup="$4" stage="$5" old_hash="$6" new_hash="$7"
  jq -cn --arg action "$action" --arg active "$active" --arg backup "$backup" --arg stage "$stage" \
    --arg old_hash "$old_hash" --arg new_hash "$new_hash" --arg ts "$(now_utc)" \
    '{schema:"polylane-skill-activation/v1",status:"prepared",action:$action,active:$active,
      backup:$backup,stage:$stage,old_hash:$old_hash,new_hash:$new_hash,ts:$ts}' > "$ws/activation.json"
}

replace_active_prepare() {
  local ws="$1" action="$2" source="$3" active="$4" old_hash="$5" new_hash="$6" parent base stage backup
  safe_active_target "$active" || { echo "skill-evolve: unsafe active target: $active" >&2; return 2; }
  active=$(canonical_dir "$active"); parent=$(dirname "$active"); base=$(basename "$active")
  stage=$(mktemp -d "$parent/.${base}.polylane-stage.XXXXXX")
  copy_tree "$source" "$stage"
  [ "$(skill_hash "$stage")" = "$new_hash" ] || { rm -rf "$stage"; echo "skill-evolve: staged activation hash mismatch" >&2; return 6; }
  backup="$parent/.${base}.polylane-backup.$$.${RANDOM}"
  write_activation_journal "$ws" "$action" "$active" "$backup" "$stage" "$old_hash" "$new_hash"
  mv "$active" "$backup"
  if ! mv "$stage" "$active"; then
    mv "$backup" "$active" 2>/dev/null || true
    rm -f "$ws/activation.json"
    return 6
  fi
  atomic_jq "$ws/activation.json" '.status="active"'
}

activation_cleanup() {
  local ws="$1" backup stage
  [ -f "$ws/activation.json" ] || return 0
  backup=$(jq -r '.backup' "$ws/activation.json"); stage=$(jq -r '.stage' "$ws/activation.json")
  case "$backup" in */.*.polylane-backup.*) [ ! -e "$backup" ] || rm -rf "$backup" ;; esac
  case "$stage" in */.*.polylane-stage.*) [ ! -e "$stage" ] || rm -rf "$stage" ;; esac
  rm -f "$ws/activation.json"
}

activation_restore() {
  local ws="$1" active backup stage
  [ -f "$ws/activation.json" ] || return 0
  active=$(jq -r '.active' "$ws/activation.json"); backup=$(jq -r '.backup' "$ws/activation.json"); stage=$(jq -r '.stage' "$ws/activation.json")
  if [ -d "$backup" ]; then
    if [ -d "$active" ]; then
      case "$active" in */.*.polylane-*) rm -rf "$active" ;; *)
        local failed="$active.polylane-failed.$$"; mv "$active" "$failed"; mv "$backup" "$active"; rm -rf "$failed" ;;
      esac
    else
      mv "$backup" "$active"
    fi
  fi
  case "$stage" in */.*.polylane-stage.*) [ ! -e "$stage" ] || rm -rf "$stage" ;; esac
  rm -f "$ws/activation.json"
}

cmd_promote() {
  local ws="$1" id="$2" active="$3" state verdict candidate candidate_hash active_hash old_hash generation version version_path tmp cursor
  require_workspace "$ws"; safe_id "$id" || return 2
  state=$(state_file "$ws"); verdict="$ws/candidates/$id/verdict.json"; candidate="$ws/candidates/$id/skill"
  [ -f "$verdict" ] || { echo "skill-evolve: candidate has no verdict" >&2; return 5; }
  [ "$(jq -r '.verdict' "$verdict")" = GO ] || { echo "skill-evolve: only GO candidates may promote" >&2; return 5; }
  lock_acquire "$ws"; trap 'lock_release "$ws"' EXIT INT TERM HUP
  candidate_hash=$(skill_hash "$candidate"); old_hash=$(jq -r '.champion.hash' "$state")
  [ "$candidate_hash" = "$(jq -r '.candidate_hash' "$verdict")" ] || { echo "skill-evolve: candidate/verdict hash mismatch" >&2; lock_release "$ws"; trap - EXIT INT TERM HUP; return 6; }
  [ "$old_hash" = "$(jq -r '.champion_hash' "$verdict")" ] || { echo "skill-evolve: verdict targets an old champion" >&2; lock_release "$ws"; trap - EXIT INT TERM HUP; return 6; }
  safe_active_target "$active" || { lock_release "$ws"; trap - EXIT INT TERM HUP; return 2; }
  active=$(canonical_dir "$active"); active_hash=$(skill_hash "$active")
  [ "$active_hash" = "$old_hash" ] || { echo "skill-evolve: active skill drifted; refusing overwrite" >&2; lock_release "$ws"; trap - EXIT INT TERM HUP; return 6; }
  generation=$(( $(jq -r '.generation' "$state") + 1 )); version=$(printf 'generation-%04d' "$generation")
  version_path="$ws/versions/$version/skill"; mkdir -p "$version_path"; copy_tree "$candidate" "$version_path"
  [ "$(skill_hash "$version_path")" = "$candidate_hash" ] || { echo "skill-evolve: version snapshot mismatch" >&2; lock_release "$ws"; trap - EXIT INT TERM HUP; return 6; }
  replace_active_prepare "$ws" promote "$version_path" "$active" "$old_hash" "$candidate_hash" || {
    lock_release "$ws"; trap - EXIT INT TERM HUP; return 6; }
  cursor=$(wc -l < "$ws/observations.jsonl" | tr -d ' ')
  tmp="$state.tmp.$$"
  if jq --argjson generation "$generation" --arg version "$version" --arg path "versions/$version/skill" \
    --arg hash "$candidate_hash" --arg candidate "$id" --arg active "$active" --argjson cursor "$cursor" '
      .previous=.champion |
      .generation=$generation | .active_path=$active | .observation_cursor=$cursor |
      .champion={generation:$generation,version:$version,path:$path,hash:$hash,candidate:$candidate}' "$state" > "$tmp" && mv "$tmp" "$state"; then
    append_history "$ws" promote "candidate=$id version=$version hash=$candidate_hash"
    activation_cleanup "$ws"
  else
    rm -f "$tmp"; activation_restore "$ws"; lock_release "$ws"; trap - EXIT INT TERM HUP; return 6
  fi
  lock_release "$ws"; trap - EXIT INT TERM HUP
  printf 'PROMOTED %s version=%s\n' "$id" "$version"
}

rollback_locked() {
  local ws="$1" active="$2" reason="$3" state current_hash previous_hash previous_path tmp
  state=$(state_file "$ws")
  jq -e '.previous != null' "$state" >/dev/null || { echo "skill-evolve: no previous champion to restore" >&2; return 5; }
  active=$(canonical_dir "$active")
  current_hash=$(skill_hash "$active")
  [ "$current_hash" = "$(jq -r '.champion.hash' "$state")" ] || { echo "skill-evolve: active skill drifted; refusing rollback overwrite" >&2; return 6; }
  previous_hash=$(jq -r '.previous.hash' "$state"); previous_path="$ws/$(jq -r '.previous.path' "$state")"
  replace_active_prepare "$ws" rollback "$previous_path" "$active" "$current_hash" "$previous_hash" || return 6
  tmp="$state.tmp.$$"
  if jq '.champion=.previous | .generation=.previous.generation | .previous=null' "$state" > "$tmp" && mv "$tmp" "$state"; then
    append_history "$ws" rollback "$reason restored=$(jq -r '.champion.version' "$state")"
    activation_cleanup "$ws"
  else
    rm -f "$tmp"; activation_restore "$ws"; return 6
  fi
}

cmd_rollback() {
  local ws="$1" active="$2"
  require_workspace "$ws"; safe_active_target "$active" || return 2
  lock_acquire "$ws"; trap 'lock_release "$ws"' EXIT INT TERM HUP
  rollback_locked "$ws" "$active" manual
  lock_release "$ws"; trap - EXIT INT TERM HUP
  printf 'ROLLED-BACK %s\n' "$(jq -r '.champion.version' "$(state_file "$ws")")"
}

run_canary_case() {
  local evals="$1" run="$2" case_b64="$3" active="$4" rows="$5" case_json encoded id adapter repeats rep work result rc
  encoded=$(printf '%s' "$case_b64" | base64 -D 2>/dev/null || printf '%s' "$case_b64" | base64 -d)
  case_json="$run/canary-$RANDOM-$$.json"; printf '%s\n' "$encoded" > "$case_json"
  id=$(jq -r '.id' "$case_json"); adapter=$(jq -r '.adapter' "$case_json"); repeats=$(jq -r '.repeats' "$case_json")
  rep=1
  while [ "$rep" -le "$repeats" ]; do
    work="$run/cases/$id/repeat-$rep"; result="$work/result.json"; rc=0
    run_eval_adapter "$adapter" "$active" "$case_json" "$work" "$result" canary "$rep" "$evals" || rc=$?
    [ -f "$result" ] || printf '{}\n' > "$result"
    append_eval_row "$rows" canary "$case_json" "$rep" "$result" "$rc"
    rep=$((rep + 1))
  done
  rm -f "$case_json"
}

cmd_canary() {
  local ws="$1" active="$2" state evals run rows failed=0
  require_workspace "$ws"; safe_active_target "$active" || return 2
  state=$(state_file "$ws"); evals=$(evals_file "$ws"); active=$(canonical_dir "$active")
  lock_acquire "$ws"; trap 'lock_release "$ws"' EXIT INT TERM HUP
  [ "$(skill_hash "$active")" = "$(jq -r '.champion.hash' "$state")" ] || {
    echo "skill-evolve: active skill drifted; canary will not overwrite it" >&2; lock_release "$ws"; trap - EXIT INT TERM HUP; return 6; }
  run="$ws/runs/canary/$(date -u '+%Y%m%dT%H%M%S' 2>/dev/null || date +%s)-$$"; rows="$run/results.jsonl"; mkdir -p "$run"; : > "$rows"
  while IFS= read -r encoded; do run_canary_case "$evals" "$run" "$encoded" "$active" "$rows"; done \
    < <(jq -c '.cases[]|select(.split=="hidden")' "$evals" | while IFS= read -r line; do printf '%s' "$line" | base64 | tr -d '\r\n'; printf '\n'; done)
  jq -s -e 'any(.[]; .valid!=true or .adapter_rc!=0 or .hard_fail==true or .score<.min_score)' "$rows" >/dev/null && failed=1
  if [ "$failed" -eq 1 ]; then
    rollback_locked "$ws" "$active" "canary-failed run=$run"
    lock_release "$ws"; trap - EXIT INT TERM HUP
    echo "CANARY-FAILED rolled-back" >&2
    return 7
  fi
  append_history "$ws" canary "passed run=$run"
  lock_release "$ws"; trap - EXIT INT TERM HUP
  printf 'CANARY-PASSED run=%s\n' "$run"
}

cmd_recover() {
  local ws="$1" state active backup stage old_hash new_hash active_hash state_hash
  require_workspace "$ws"
  [ -f "$ws/activation.json" ] || { echo CLEAN; return 0; }
  lock_acquire "$ws"; trap 'lock_release "$ws"' EXIT INT TERM HUP
  state=$(state_file "$ws"); active=$(jq -r '.active' "$ws/activation.json"); backup=$(jq -r '.backup' "$ws/activation.json")
  stage=$(jq -r '.stage' "$ws/activation.json"); old_hash=$(jq -r '.old_hash' "$ws/activation.json"); new_hash=$(jq -r '.new_hash' "$ws/activation.json")
  state_hash=$(jq -r '.champion.hash' "$state"); active_hash=missing; [ ! -d "$active" ] || active_hash=$(skill_hash "$active")
  if [ "$active_hash" = "$state_hash" ]; then
    activation_cleanup "$ws"; echo RECOVERED-CLEANUP
  elif [ "$state_hash" = "$old_hash" ] && [ -d "$backup" ] && [ "$(skill_hash "$backup")" = "$old_hash" ]; then
    [ ! -d "$active" ] || { failed="$active.polylane-failed.$$"; mv "$active" "$failed"; }
    mv "$backup" "$active"; [ -z "${failed:-}" ] || rm -rf "$failed"
    case "$stage" in */.*.polylane-stage.*) [ ! -e "$stage" ] || rm -rf "$stage" ;; esac
    rm -f "$ws/activation.json"; echo RECOVERED-ROLLBACK
  elif [ "$state_hash" = "$new_hash" ] && [ "$active_hash" = "$new_hash" ]; then
    activation_cleanup "$ws"; echo RECOVERED-FINALIZED
  else
    echo "skill-evolve: activation journal requires manual inspection" >&2
    lock_release "$ws"; trap - EXIT INT TERM HUP; return 8
  fi
  lock_release "$ws"; trap - EXIT INT TERM HUP
}

cmd_status() {
  local ws="$1" mode="${2:-}" state
  require_workspace "$ws"; state=$(state_file "$ws")
  [ -z "$mode" ] || [ "$mode" = --json ] || usage
  if [ "$mode" = --json ]; then
    jq --argjson observations "$(wc -l < "$ws/observations.jsonl" | tr -d ' ')" \
      --arg activation "$(if [ -f "$ws/activation.json" ]; then echo pending; else echo clean; fi)" \
      '. + {observations:$observations,activation:$activation}' "$state"
  else
    printf 'Skill: %s\nChampion: %s\nGeneration: %s\nObservations: %s\nActivation: %s\n' \
      "$(jq -r '.skill_name' "$state")" "$(jq -r '.champion.version' "$state")" \
      "$(jq -r '.generation' "$state")" "$(wc -l < "$ws/observations.jsonl" | tr -d ' ')" \
      "$(if [ -f "$ws/activation.json" ]; then echo pending; else echo clean; fi)"
  fi
}

main() {
  local ws
  case "${1:-}" in
    validate) [ "$#" -eq 2 ] || usage; cmd_validate "$2" ;;
    init) [ "$#" -eq 4 ] || usage; cmd_init "$2" "$3" "$4" ;;
    observe) [ "$#" -ge 6 ] && [ "$#" -le 7 ] || usage; cmd_observe "$2" "$3" "$4" "$5" "$6" "${7:-}" ;;
    eligible) [ "$#" -eq 3 ] || usage; cmd_eligible "$2" "$3" ;;
    packet) [ "$#" -eq 3 ] || usage; cmd_packet "$2" "$3" ;;
    stage) [ "$#" -eq 5 ] || usage; cmd_stage "$2" "$3" "$4" "$5" ;;
    compare) [ "$#" -eq 3 ] || usage; cmd_compare "$2" "$3" ;;
    select) [ "$#" -ge 3 ] || usage; shift; ws="$1"; shift; cmd_select "$ws" "$@" ;;
    promote) [ "$#" -eq 4 ] || usage; cmd_promote "$2" "$3" "$4" ;;
    canary) [ "$#" -eq 3 ] || usage; cmd_canary "$2" "$3" ;;
    rollback) [ "$#" -eq 3 ] || usage; cmd_rollback "$2" "$3" ;;
    recover) [ "$#" -eq 2 ] || usage; cmd_recover "$2" ;;
    status) [ "$#" -ge 2 ] && [ "$#" -le 3 ] || usage; cmd_status "$2" "${3:-}" ;;
    *) usage ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
