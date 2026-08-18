#!/usr/bin/env bash
# Agent-aware pre-launch model and effort policy. Sourced by polylane-run.sh.
# Bash 3.2 safe: indexed arrays only.

model_policy_agent() {
  case "$(agent_selected)" in
    claude) printf '%s' claude ;;
    codex|gpt|openai) printf '%s' codex ;;
    *) return 1 ;;
  esac
}

model_policy_tier() {
  local agent="$1" model="$2"
  case "$agent:$model" in
    claude:claude-haiku-4-5) printf '%s' 1 ;;
    claude:claude-sonnet-5)  printf '%s' 2 ;;
    claude:claude-opus-5)   printf '%s' 3 ;;
    claude:claude-opus-4-8)  printf '%s' 3 ;;
    claude:claude-fable-5)   printf '%s' 4 ;;
    codex:gpt-5.6-luna)      printf '%s' 1 ;;
    codex:gpt-5.6-terra)     printf '%s' 2 ;;
    codex:gpt-5.6-sol)       printf '%s' 3 ;;
    *) return 1 ;;
  esac
}

model_policy_max_tier() { case "$1" in claude) printf '%s' 4 ;; codex) printf '%s' 3 ;; *) return 1 ;; esac; }
model_policy_effort() { case "$1" in economy) printf '%s' medium ;; balanced|performance) printf '%s' high ;; max) printf '%s' xhigh ;; *) return 1 ;; esac; }
model_policy_effort_valid() { case "$1" in low|medium|high|xhigh) return 0 ;; *) return 1 ;; esac; }

model_policy_target_tier() {
  local maximum
  maximum=$(model_policy_max_tier "$2") || return 1
  case "$1" in economy) printf '%s' 1 ;; balanced) printf '%s' 2 ;; performance) printf '%s' 3 ;; max) printf '%s' "$maximum" ;; *) return 1 ;; esac
}

model_policy_available() {
  local want="$1" model
  for model in "${AVAILABLE_MODELS[@]:-}"; do [ "$model" = "$want" ] && return 0; done
  return 1
}

# Exact tier, strongest lower tier, then weakest stronger tier: a partial
# manifest compresses tier selection truthfully instead of inventing a model.
model_policy_choose_tier() {
  local agent="$1" desired="$2" model tier best="" best_tier=0 above="" above_tier=999
  for model in "${AVAILABLE_MODELS[@]:-}"; do
    tier=$(model_policy_tier "$agent" "$model") || continue
    if [ "$tier" = "$desired" ]; then printf '%s' "$model"; return 0; fi
    if [ "$tier" -lt "$desired" ] && [ "$tier" -gt "$best_tier" ]; then best="$model"; best_tier="$tier"; fi
    if [ "$tier" -gt "$desired" ] && [ "$tier" -lt "$above_tier" ]; then above="$model"; above_tier="$tier"; fi
  done
  [ -n "$best" ] && { printf '%s' "$best"; return 0; }
  [ -n "$above" ] && { printf '%s' "$above"; return 0; }
  return 1
}

model_policy_die() { echo "polylane-run: $*" >&2; return 2; }

model_policy_validate_available() {
  local agent="$1" model
  [ "${#AVAILABLE_MODELS[@]}" -gt 0 ] || { model_policy_die 'intensity/model policy needs a non-empty "available_models" in the manifest'; return $?; }
  for model in "${AVAILABLE_MODELS[@]}"; do
    model_policy_tier "$agent" "$model" >/dev/null || { model_policy_die "unsupported $agent model '$model' in available_models (unknown IDs are not tiers)"; return $?; }
  done
}

model_policy_role_for() {
  local name="$1" declared="$2"
  [ -n "$declared" ] && { printf '%s' "$declared"; return; }
  case "$name" in *mechanical*|*docs*) printf '%s' mechanical ;; *security*) printf '%s' security ;; *hardest*) printf '%s' hardest ;; *) printf '%s' builder ;; esac
}

model_policy_clamp_lane() {
  # NAME ROLE MODEL EFFORT SOURCE AGENT -> model|effort|source
  local name="$1" role="$2" model="$3" effort="$4" source="$5" agent="$6" tier target changed=0
  case "$role" in
    mechanical)
      tier=$(model_policy_tier "$agent" "$model") || return 1
      if [ "$tier" -gt 2 ]; then model=$(model_policy_choose_tier "$agent" 2) || return 1; changed=1; fi
      [ "$effort" = low ] || [ "$effort" = medium ] || { effort=medium; changed=1; }
      ;;
    security)
      # Claude's documented non-refusal tier is Opus; Codex's equivalent is
      # Terra. This keeps security off the lowest and frontier-only choices.
      case "$agent" in claude) target=$(model_policy_choose_tier "$agent" 3) ;; codex) target=$(model_policy_choose_tier "$agent" 2) ;; esac || return 1
      [ "$model" = "$target" ] || { model="$target"; changed=1; }
      [ "$effort" = high ] || { effort=high; changed=1; }
      ;;
    hardest) [ "$effort" = high ] || { effort=high; changed=1; } ;;
    builder|"") case "$effort" in low|medium|high) : ;; *) effort=high; changed=1 ;; esac ;;
    *) model_policy_die "unknown role '$role' for lane '$name'"; return $? ;;
  esac
  [ "$changed" = 1 ] && source='role-clamp'
  printf '%s|%s|%s' "$model" "$effort" "$source"
}

model_policy_apply_override() {
  local ov="$1" agent="$2" name id i found=0
  case "$ov" in *=*) : ;; *) model_policy_die "malformed --model '$ov' (want lane=model_id)"; return $? ;; esac
  name="${ov%%=*}"; id="${ov#*=}"
  [ -n "$name" ] && [ -n "$id" ] || { model_policy_die "malformed --model '$ov' (want lane=model_id)"; return $?; }
  model_policy_tier "$agent" "$id" >/dev/null || { model_policy_die "unsupported $agent override model '$id'"; return $?; }
  model_policy_available "$id" || { model_policy_die "override model '$id' is not in available_models"; return $?; }
  if [ "$name" = "$INT_NAME" ]; then INT_MODEL="$id"; INT_POLICY_SOURCE='CLI override'; found=1; fi
  for i in "${!LANE_NAMES[@]}"; do
    if [ "${LANE_NAMES[$i]}" = "$name" ]; then LANE_MODELS[i]="$id"; LANE_POLICY_SOURCES[i]='CLI override'; found=1; fi
  done
  [ "$found" = 1 ] || { model_policy_die "--model names unknown lane '$name' (not a lane or the integrator)"; return $?; }
}

resolve_model_policy() {
  local agent intensity source effort desired model i role result active=0 max_tier manifest_custom=0
  agent=$(model_policy_agent) || { model_policy_die "agent '$(agent_selected)' has no model policy; use claude or codex"; return $?; }
  intensity="${INTENSITY:-}"
  if [ -z "$intensity" ]; then
    intensity="${MANIFEST_INTENSITY:-}"
    source=manifest
    [ "$intensity" != custom ] || manifest_custom=1
  else
    source='CLI override'
  fi
  [ -z "$intensity" ] || active=1
  [ "${#MODEL_OVERRIDES[@]:-0}" -eq 0 ] || active=1
  if [ -n "$intensity" ] && [ "$manifest_custom" = 0 ]; then
    effort=$(model_policy_effort "$intensity") || { model_policy_die "unknown intensity '$intensity' (want economy|balanced|performance|max)"; return $?; }
    model_policy_validate_available "$agent" || return $?
    desired=$(model_policy_target_tier "$intensity" "$agent") || return 2
    model=$(model_policy_choose_tier "$agent" "$desired") || { model_policy_die "no supported $agent model is available"; return $?; }
    for i in "${!LANE_NAMES[@]}"; do LANE_MODELS[i]="$model"; LANE_EFFORTS[i]="$effort"; LANE_POLICY_SOURCES[i]="$source"; done
    INT_MODEL="$model"; INT_EFFORT="$effort"; INT_POLICY_SOURCE="$source"
  else
    LANE_POLICY_SOURCES=(); for i in "${!LANE_NAMES[@]}"; do LANE_POLICY_SOURCES[i]=manifest; done; INT_POLICY_SOURCE=manifest
  fi
  if [ "${#MODEL_OVERRIDES[@]:-0}" -gt 0 ]; then
    model_policy_validate_available "$agent" || return $?
    for model in "${MODEL_OVERRIDES[@]}"; do model_policy_apply_override "$model" "$agent" || return $?; done
  fi
  if [ "$manifest_custom" = 1 ]; then
    # `custom` validates the baked settings but is never a preset remap.
    model_policy_validate_available "$agent" || return $?
    for i in "${!LANE_NAMES[@]}"; do
      model_policy_tier "$agent" "${LANE_MODELS[$i]}" >/dev/null || { model_policy_die "unsupported $agent model '${LANE_MODELS[$i]}' for lane '${LANE_NAMES[$i]}'"; return $?; }
      model_policy_available "${LANE_MODELS[$i]}" || { model_policy_die "lane '${LANE_NAMES[$i]}' model '${LANE_MODELS[$i]}' is not in available_models"; return $?; }
      model_policy_effort_valid "${LANE_EFFORTS[$i]:-medium}" || { model_policy_die "unsupported effort '${LANE_EFFORTS[$i]}' for lane '${LANE_NAMES[$i]}'"; return $?; }
      LANE_POLICY_SOURCES[i]=manifest-custom
    done
    model_policy_tier "$agent" "$INT_MODEL" >/dev/null || { model_policy_die "unsupported $agent model '$INT_MODEL' for integrator '$INT_NAME'"; return $?; }
    model_policy_available "$INT_MODEL" || { model_policy_die "integrator model '$INT_MODEL' is not in available_models"; return $?; }
    model_policy_effort_valid "${INT_EFFORT:-medium}" || { model_policy_die "unsupported effort '$INT_EFFORT' for integrator '$INT_NAME'"; return $?; }
    INT_POLICY_SOURCE=manifest-custom
    return 0
  fi
  if [ "$active" = 0 ]; then
    # A legacy manifest with no intensity and no availability declaration may
    # deliberately use a custom model/effort through POLYLANE_AGENT_CMD. Do
    # not turn that old, explicit lane contract into a new tier-policy error.
    # Once available_models is present, retain the stricter validation below.
    [ "${#AVAILABLE_MODELS[@]}" -gt 0 ] || return 0
    model_policy_validate_available "$agent" || return $?
    for i in "${!LANE_NAMES[@]}"; do
      model_policy_tier "$agent" "${LANE_MODELS[$i]}" >/dev/null || { model_policy_die "unsupported $agent model '${LANE_MODELS[$i]}' for lane '${LANE_NAMES[$i]}'"; return $?; }
      model_policy_available "${LANE_MODELS[$i]}" || { model_policy_die "lane '${LANE_NAMES[$i]}' model '${LANE_MODELS[$i]}' is not in available_models"; return $?; }
      model_policy_effort_valid "${LANE_EFFORTS[$i]:-medium}" || { model_policy_die "unsupported effort '${LANE_EFFORTS[$i]}' for lane '${LANE_NAMES[$i]}'"; return $?; }
    done
    model_policy_tier "$agent" "$INT_MODEL" >/dev/null || { model_policy_die "unsupported $agent model '$INT_MODEL' for integrator '$INT_NAME'"; return $?; }
    model_policy_available "$INT_MODEL" || { model_policy_die "integrator model '$INT_MODEL' is not in available_models"; return $?; }
    model_policy_effort_valid "${INT_EFFORT:-medium}" || { model_policy_die "unsupported effort '$INT_EFFORT' for integrator '$INT_NAME'"; return $?; }
    return 0
  fi
  for i in "${!LANE_NAMES[@]}"; do
    role=$(model_policy_role_for "${LANE_NAMES[$i]}" "${LANE_ROLES[$i]:-}")
    result=$(model_policy_clamp_lane "${LANE_NAMES[$i]}" "$role" "${LANE_MODELS[$i]}" "${LANE_EFFORTS[$i]}" "${LANE_POLICY_SOURCES[$i]}" "$agent") || return $?
    LANE_MODELS[i]="${result%%|*}"; result="${result#*|}"; LANE_EFFORTS[i]="${result%%|*}"; LANE_POLICY_SOURCES[i]="${result#*|}"
    model_policy_tier "$agent" "${LANE_MODELS[$i]}" >/dev/null || { model_policy_die "unsupported $agent model '${LANE_MODELS[$i]}' for lane '${LANE_NAMES[$i]}'"; return $?; }
    model_policy_available "${LANE_MODELS[$i]}" || { model_policy_die "lane '${LANE_NAMES[$i]}' model '${LANE_MODELS[$i]}' is not in available_models"; return $?; }
    model_policy_effort_valid "${LANE_EFFORTS[$i]}" || { model_policy_die "unsupported effort '${LANE_EFFORTS[$i]}' for lane '${LANE_NAMES[$i]}'"; return $?; }
  done
  max_tier=$(model_policy_max_tier "$agent") || return 2
  INT_MODEL=$(model_policy_choose_tier "$agent" "$max_tier") || return 2
  INT_EFFORT=xhigh; INT_POLICY_SOURCE='role-clamp'
  model_policy_available "$INT_MODEL" || { model_policy_die "integrator model '$INT_MODEL' is not in available_models"; return $?; }
}

emit_effective_model_policy() {
  local i role intensity
  intensity="${INTENSITY:-${MANIFEST_INTENSITY:-manifest}}"
  printf '== effective model policy: agent=%s intensity=%s ==\n' "$(model_policy_agent)" "$intensity"
  for i in "${!LANE_NAMES[@]}"; do
    role=$(model_policy_role_for "${LANE_NAMES[$i]}" "${LANE_ROLES[$i]:-}")
    printf 'policy lane=%s role=%s source=%s model=%s effort=%s\n' "${LANE_NAMES[$i]}" "$role" "${LANE_POLICY_SOURCES[$i]:-manifest}" "${LANE_MODELS[$i]:-unknown}" "${LANE_EFFORTS[$i]:-unknown}"
  done
  printf 'policy lane=%s role=integrator source=%s model=%s effort=%s\n' "${INT_NAME:-integrator}" "${INT_POLICY_SOURCE:-manifest}" "${INT_MODEL:-unknown}" "${INT_EFFORT:-unknown}"
}
