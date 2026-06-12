#!/bin/bash
# growing-skills 라이프사이클 이벤트 로거. 각 프로듀서가 source 한다.
# 사용: lifecycle_log <event> <skill> <reason> [json_metadata]
# 비차단: jq 없거나 쓰기 실패해도 호출자를 멈추지 않음(항상 0 반환).
lifecycle_log() {
  local _empty_meta='{}'
  local ev="${1:-}" sk="${2:-}" reason="${3:-}" meta="${4:-$_empty_meta}"
  [ -n "$ev" ] || return 0
  local root="${GROWING_SKILLS_ROOT:-$HOME/.claude/skills}"
  local f="$root/.lifecycle-events.jsonl"
  command -v jq >/dev/null 2>&1 || return 0
  local ts; ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  jq -nc --arg ts "$ts" --arg ev "$ev" --arg sk "$sk" --arg r "$reason" --argjson m "$meta" \
    '{ts:$ts,event:$ev,skill:$sk,reason:$r,metadata:$m}' >> "$f" 2>/dev/null || true
  return 0
}
