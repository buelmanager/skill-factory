#!/bin/bash
# growing-skills: SessionStart 훅 — 7일 경과 시 큐레이터 detach 스폰.
# 중대: SessionStart 훅의 stdout은 세션 컨텍스트에 주입된다 — 첫 줄에서 전면 차단.
exec >/dev/null 2>&1
[ "${GROWING_SKILLS_BG:-}" = "1" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

SKILLS_ROOT="${GROWING_SKILLS_ROOT:-$HOME/.claude/skills}"
GS_HOME="${GROWING_SKILLS_HOME:-$HOME/.claude/growing-skills}"
STATE="$SKILLS_ROOT/.curator_state"

[ "$(jq -r '.paused // false' "$STATE" 2>/dev/null)" = "true" ] && exit 0
LAST=$(jq -r '.last_run_at // 0' "$STATE" 2>/dev/null); [ -z "$LAST" ] && LAST=0
NOW=$(date +%s)
[ $((NOW - LAST)) -lt 604800 ] && exit 0
[ "${GROWING_SKILLS_NO_SPAWN:-}" = "1" ] && exit 0
[ -x "$GS_HOME/bin/curator-pass.sh" ] || exit 0
nohup "$GS_HOME/bin/curator-pass.sh" >/dev/null 2>&1 &
exit 0
