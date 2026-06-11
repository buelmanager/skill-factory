#!/bin/bash
# growing-skills: PostToolUse(Skill) 텔레메트리 — 글로벌 스킬 사용을 append-only JSONL에 기록.
# 어떤 경우에도 도구 호출을 막지 않는다: 항상 exit 0.
[ "${GROWING_SKILLS_BG:-}" = "1" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

SKILLS_ROOT="${GROWING_SKILLS_ROOT:-$HOME/.claude/skills}"
INPUT=$(cat)
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# jq가 필터링과 JSON 직렬화를 모두 담당 (스킬명에 특수문자가 있어도 안전한 JSON 보장).
# 플러그인 네임스페이스 스킬(plugin:skill)은 제외.
LINE=$(printf '%s' "$INPUT" | jq -c --arg ts "$TS" '
  (.tool_input.skill // empty) as $s
  | select($s != "" and (($s | contains(":")) | not))
  | {ts: $ts, skill: $s, event: "use", session: (.session_id // "unknown")}' 2>/dev/null)
[ -z "$LINE" ] && exit 0

SKILL=$(printf '%s' "$LINE" | jq -r '.skill')
case "$SKILL" in */*|*..*) exit 0 ;; esac   # 경로 문자가 든 스킬명 거부 (SKILLS_ROOT 탈출 방지)
[ -f "$SKILLS_ROOT/$SKILL/SKILL.md" ] || exit 0   # 글로벌 스킬만 집계

printf '%s\n' "$LINE" >> "$SKILLS_ROOT/.usage-events.jsonl" 2>/dev/null
exit 0
