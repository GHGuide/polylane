#!/usr/bin/env bash
# Durable, bounded discovery graph for turning a vague brief into a strategy packet.
set -euo pipefail

usage() {
  echo "usage: polylane-discovery.sh init <state> <brief> | next <state> [limit] | answer <state> <question-id> <recommended|deep|bold|custom> [text] | contradict <state> <answer-id> <answer-id> <reason> | resolve <state> <contradiction-id> <accept-left|accept-right|accept-both> [note] | summary <state> | lock <state> <docs-dir>" >&2
  exit 2
}

need_state() {
  [ -f "$1" ] && jq -e '
    .version == "schema-v1" and (.brief | type == "string") and
    (.nodes | type == "array") and (.answers | type == "array") and
    (.contradictions | type == "array") and (.strategy | type == "object")
  ' "$1" >/dev/null || { echo "discovery: invalid state: $1" >&2; return 1; }
}

write_state() {
  local state="$1" tmp
  tmp=$(mktemp "${state}.tmp.XXXXXX")
  cat > "$tmp"
  mv "$tmp" "$state"
}

cmd_init() {
  local state="$1" brief="$2"
  [ -n "$brief" ] || { echo "discovery: brief must not be empty" >&2; return 1; }
  mkdir -p "$(dirname "$state")"
  jq -n --arg brief "$brief" '
    {version:"schema-v1", brief:$brief,
     nodes:[
       {id:"q-user", type:"question", impact:100, active:true, strategy_key:"audience",
        question:"Who has the sharpest version of this problem?",
        options:{recommended:"The person who feels this pain most often", deep:"A narrowly defined primary user", bold:"A broader group with the same urgent job"}},
       {id:"q-workflow", type:"question", impact:90, active:true, strategy_key:"workflow",
        question:"What is the smallest repeated workflow worth improving?",
        options:{recommended:"One repeatable task from start to finish", deep:"The exact steps and failure points in that task", bold:"A redesigned workflow that removes a whole handoff"}},
       {id:"q-success", type:"question", impact:80, active:true, strategy_key:"success",
        question:"What visible outcome would make the first release worthwhile?",
        options:{recommended:"A user completes the core task without help", deep:"A measurable reduction in time or mistakes", bold:"A new standard for how this work is done"}}
     ], answers:[], contradictions:[], strategy:{status:"open"}}
  ' | write_state "$state"
}

cmd_next() {
  local state="$1" limit="${2:-3}"
  need_state "$state"
  case "$limit" in ''|*[!0-9]*) usage ;; esac
  [ "$limit" -ge 1 ] && [ "$limit" -le 5 ] || { echo "discovery: limit must be 1..5" >&2; return 1; }
  jq -c --argjson limit "$limit" '
    . as $state |
    [$state.nodes[] as $node |
      select($node.type == "question" and $node.active == true) |
      select(([$state.answers[] | select(.question_id == $node.id)] | length) == 0) |
      $node] | sort_by(-.impact, .id) | .[:$limit][]
  ' "$state"
}

cmd_answer() {
  local state="$1" question_id="$2" kind="$3" text="${4:-}" node_text child tmp
  need_state "$state"
  case "$kind" in recommended|deep|bold|custom) ;; *) echo "discovery: invalid answer kind: $kind" >&2; return 1 ;; esac
  jq -e --arg id "$question_id" 'any(.nodes[]; .id == $id and .type == "question" and .active == true)' "$state" >/dev/null || {
    echo "discovery: active question not found: $question_id" >&2; return 1;
  }
  if jq -e --arg id "$question_id" 'any(.answers[]; .question_id == $id)' "$state" >/dev/null; then
    echo "discovery: question already answered: $question_id" >&2
    return 1
  fi
  if [ "$kind" = "custom" ]; then
    [ -n "$text" ] || { echo "discovery: custom answer requires text" >&2; return 1; }
  elif [ -z "$text" ]; then
    node_text=$(jq -r --arg id "$question_id" --arg kind "$kind" '.nodes[] | select(.id == $id) | .options[$kind]' "$state")
    [ "$node_text" != "null" ] && [ -n "$node_text" ] || { echo "discovery: missing option: $kind" >&2; return 1; }
    text="$node_text"
  fi
  child="$question_id-$kind"
  tmp=$(mktemp "${state}.tmp.XXXXXX")
  jq --arg id "$question_id" --arg kind "$kind" --arg text "$text" --arg child "$child" '
    . as $state |
    ($state.nodes[] | select(.id == $id)) as $node |
    .answers += [{type:"answer", id:("a-" + $id), question_id:$id, kind:$kind, text:$text,
                  accepted:true, strategy_key:$node.strategy_key}] |
    if $kind == "deep" or $kind == "bold" then
      if any(.nodes[]; .id == $child) then
        .nodes |= map(if .id == $child then .active = true else . end)
      else
        .nodes += [{id:$child, type:"question", parent:$id, impact:($node.impact - 10), active:true,
                    strategy_key:("detail-" + $id),
                    question:("What is the most important detail behind: " + $text),
                    options:{recommended:"Capture the most common real-world case", deep:"Map the edge cases before building", bold:"Challenge the assumption behind this choice"}}]
      end
    else . end
  ' "$state" > "$tmp"
  mv "$tmp" "$state"
}

strategy_packet() {
  jq -r '
    "Strategy packet\n" +
    "Brief: " + .brief + "\n" +
    ([.answers[] | select(.accepted == true) | "- " + .strategy_key + ": " + .text] | join("\n"))
  ' "$1"
}

cmd_summary() {
  need_state "$1"
  strategy_packet "$1"
}

cmd_contradict() {
  local state="$1" left="$2" right="$3" reason="$4" id tmp
  need_state "$state"
  [ "$left" != "$right" ] && [ -n "$reason" ] || { echo 'discovery: contradiction needs two answers and a reason' >&2; return 1; }
  jq -e --arg left "$left" --arg right "$right" 'any(.answers[]; .id == $left) and any(.answers[]; .id == $right)' "$state" >/dev/null || {
    echo 'discovery: contradiction answer not found' >&2; return 1;
  }
  if jq -e --arg left "$left" --arg right "$right" '
    any(.contradictions[];
      .status == "open" and
      ((.left_answer_id == $left and .right_answer_id == $right) or
       (.left_answer_id == $right and .right_answer_id == $left)))
  ' "$state" >/dev/null; then
    echo 'discovery: contradiction already open' >&2
    return 1
  fi
  id="c-$(jq '.contradictions | length + 1' "$state")"
  tmp=$(mktemp "${state}.tmp.XXXXXX")
  jq --arg id "$id" --arg left "$left" --arg right "$right" --arg reason "$reason" \
    '.contradictions += [{id:$id, type:"contradiction", left_answer_id:$left, right_answer_id:$right, reason:$reason, status:"open"}]' \
    "$state" > "$tmp"
  mv "$tmp" "$state"
}

cmd_resolve() {
  local state="$1" id="$2" resolution="$3" note="${4:-}" tmp
  need_state "$state"
  case "$resolution" in accept-left|accept-right|accept-both) ;; *)
    echo 'discovery: resolution must be accept-left, accept-right, or accept-both' >&2; return 1 ;;
  esac
  jq -e --arg id "$id" 'any(.contradictions[]; .id == $id and .status == "open")' "$state" >/dev/null || {
    echo "discovery: open contradiction not found: $id" >&2; return 1;
  }
  tmp=$(mktemp "${state}.tmp.XXXXXX")
  jq --arg id "$id" --arg resolution "$resolution" --arg note "$note" \
    '.contradictions |= map(if .id == $id then .status = "resolved" | .resolution = $resolution | .resolution_note = $note else . end)' \
    "$state" > "$tmp"
  mv "$tmp" "$state"
}

cmd_lock() {
  local state="$1" docs="$2" summary tmp
  need_state "$state"
  jq -e 'all(.contradictions[]?; .status == "resolved")' "$state" >/dev/null || {
    echo "discovery: contradictions must be resolved before lock" >&2; return 1;
  }
  summary=$(strategy_packet "$state")
  mkdir -p "$docs"
  printf '# Strategy\n\n%s\n' "$summary" > "$docs/strategy.md"
  printf '# North star\n\n%s\n' "$(jq -r '.brief' "$state")" > "$docs/north-star.md"
  printf '# Goal\n\n%s\n' "$(jq -r '[.answers[] | select(.strategy_key == "success" and .accepted == true) | .text][0] // .brief' "$state")" > "$docs/goal.md"
  tmp=$(mktemp "${state}.tmp.XXXXXX")
  jq '.strategy.status = "locked"' "$state" > "$tmp"
  mv "$tmp" "$state"
}

main() {
  case "${1:-}" in
    init) [ "$#" = 3 ] || usage; cmd_init "$2" "$3" ;;
    next) [ "$#" -ge 2 ] && [ "$#" -le 3 ] || usage; cmd_next "$2" "${3:-3}" ;;
    answer) [ "$#" -ge 4 ] && [ "$#" -le 5 ] || usage; cmd_answer "$2" "$3" "$4" "${5:-}" ;;
    contradict) [ "$#" = 5 ] || usage; cmd_contradict "$2" "$3" "$4" "$5" ;;
    resolve) [ "$#" -ge 4 ] && [ "$#" -le 5 ] || usage; cmd_resolve "$2" "$3" "$4" "${5:-}" ;;
    summary) [ "$#" = 2 ] || usage; cmd_summary "$2" ;;
    lock) [ "$#" = 3 ] || usage; cmd_lock "$2" "$3" ;;
    *) usage ;;
  esac
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then main "$@"; fi
