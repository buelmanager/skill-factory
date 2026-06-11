#!/bin/bash
# growing-skills Phase 1 제거: 훅 항목·독트린 제거. 이벤트 데이터(.usage-events.jsonl)는 보존.
set -euo pipefail
CLAUDE_DIR="${GROWING_SKILLS_CLAUDE_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"
TS=$(date +%Y%m%d%H%M%S)

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq가 필요합니다"; exit 1; }

if [ -f "$SETTINGS" ]; then
  cp "$SETTINGS" "$SETTINGS.bak.$TS"
  TMP=$(mktemp)
  jq 'if .hooks.PostToolUse then
        .hooks.PostToolUse = [.hooks.PostToolUse[] | select(.matcher != "Skill")]
        | if (.hooks.PostToolUse | length) == 0 then del(.hooks.PostToolUse) else . end
      else . end' "$SETTINGS" > "$TMP"
  jq -e . "$TMP" >/dev/null
  mv "$TMP" "$SETTINGS"
fi

rm -f "$CLAUDE_DIR/hooks/skill-telemetry.sh"

CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
if [ -f "$CLAUDE_MD" ] && grep -q "growing-skills-doctrine:begin" "$CLAUDE_MD"; then
  cp "$CLAUDE_MD" "$CLAUDE_MD.bak.$TS"
  TMP=$(mktemp)
  sed '/<!-- growing-skills-doctrine:begin -->/,/<!-- growing-skills-doctrine:end -->/d' "$CLAUDE_MD" > "$TMP"
  mv "$TMP" "$CLAUDE_MD"
fi

echo "제거 완료. 이벤트 데이터는 보존됨: $CLAUDE_DIR/skills/.usage-events.jsonl"
