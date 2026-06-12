#!/bin/bash
# growing-skills Phase 1 설치: 텔레메트리 훅 + 독트린.
# GROWING_SKILLS_CLAUDE_DIR 로 대상 디렉터리 오버라이드 가능 (테스트용). 기본 ~/.claude.
set -euo pipefail
PKG_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="${GROWING_SKILLS_CLAUDE_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"
TS=$(date +%Y%m%d%H%M%S)

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq가 필요합니다"; exit 1; }
[ -f "$SETTINGS" ] || { echo "ERROR: $SETTINGS 없음"; exit 1; }

# 1) 훅 스크립트 복사
mkdir -p "$CLAUDE_DIR/hooks"
cp "$PKG_DIR/hooks/skill-telemetry.sh" "$CLAUDE_DIR/hooks/skill-telemetry.sh"
chmod +x "$CLAUDE_DIR/hooks/skill-telemetry.sh"

# 2) settings.json 백업 후 PostToolUse(Skill) 훅 머지 (멱등)
ALREADY=$(jq '[.hooks.PostToolUse[]? | select(.matcher=="Skill")] | length' "$SETTINGS")
if [ "$ALREADY" -eq 0 ]; then
  cp "$SETTINGS" "$SETTINGS.bak.$TS"
  TMP=$(mktemp)
  jq '.hooks.PostToolUse = ((.hooks.PostToolUse // []) + [{
        "matcher": "Skill",
        "hooks": [{"type": "command",
                   "command": "~/.claude/hooks/skill-telemetry.sh",
                   "timeout": 5}]
      }])' "$SETTINGS" > "$TMP"
  jq -e . "$TMP" >/dev/null   # 결과 JSON 유효성 확인 후에만 교체
  mv "$TMP" "$SETTINGS"
  echo "settings.json: PostToolUse(Skill) 훅 추가 (백업: settings.json.bak.$TS)"
else
  echo "settings.json: 이미 설치됨 — 건너뜀"
fi

# 2.5) Phase 2: 패키지(bin/prompts/settings) 배포 + SessionEnd 훅
mkdir -p "$CLAUDE_DIR/growing-skills/bin" "$CLAUDE_DIR/growing-skills/prompts" "$CLAUDE_DIR/growing-skills/settings"
cp "$PKG_DIR/bin/"*.sh "$CLAUDE_DIR/growing-skills/bin/"
chmod +x "$CLAUDE_DIR/growing-skills/bin/"*.sh
cp "$PKG_DIR/prompts/"*.md "$CLAUDE_DIR/growing-skills/prompts/"
cp "$PKG_DIR/settings/headless-settings.json" "$CLAUDE_DIR/growing-skills/settings/"
cp "$PKG_DIR/hooks/session-end-queue.sh" "$CLAUDE_DIR/hooks/session-end-queue.sh"
chmod +x "$CLAUDE_DIR/hooks/session-end-queue.sh"

ALREADY_SE=$(jq '[.hooks.SessionEnd[]? | select((.hooks // []) | any(.command // "" | contains("session-end-queue.sh")))] | length' "$SETTINGS")
if [ "$ALREADY_SE" -eq 0 ]; then
  [ -f "$SETTINGS.bak.$TS" ] || cp "$SETTINGS" "$SETTINGS.bak.$TS"
  TMP=$(mktemp)
  jq '.hooks.SessionEnd = ((.hooks.SessionEnd // []) + [{
        "hooks": [{"type": "command",
                   "command": "~/.claude/hooks/session-end-queue.sh",
                   "timeout": 60}]
      }])' "$SETTINGS" > "$TMP"
  jq -e . "$TMP" >/dev/null
  mv "$TMP" "$SETTINGS"
  echo "settings.json: SessionEnd 훅 추가"
else
  echo "settings.json: SessionEnd 이미 설치됨 — 건너뜀"
fi

# 2.7) Phase 3: 큐레이터 훅 + /curator 스킬
cp "$PKG_DIR/hooks/session-start-curator.sh" "$CLAUDE_DIR/hooks/session-start-curator.sh"
chmod +x "$CLAUDE_DIR/hooks/session-start-curator.sh"
mkdir -p "$CLAUDE_DIR/skills/curator"
cp "$PKG_DIR/skill/SKILL.md" "$CLAUDE_DIR/skills/curator/SKILL.md"
mkdir -p "$CLAUDE_DIR/skills/sf-dashboard"
cp "$PKG_DIR/skill/sf-dashboard/SKILL.md" "$CLAUDE_DIR/skills/sf-dashboard/SKILL.md"

ALREADY_SS=$(jq '[.hooks.SessionStart[]? | select((.hooks // []) | any(.command // "" | contains("session-start-curator.sh")))] | length' "$SETTINGS")
if [ "$ALREADY_SS" -eq 0 ]; then
  [ -f "$SETTINGS.bak.$TS" ] || cp "$SETTINGS" "$SETTINGS.bak.$TS"
  TMP=$(mktemp)
  jq '.hooks.SessionStart = ((.hooks.SessionStart // []) + [{
        "hooks": [{"type": "command",
                   "command": "~/.claude/hooks/session-start-curator.sh",
                   "timeout": 10}]
      }])' "$SETTINGS" > "$TMP"
  jq -e . "$TMP" >/dev/null
  mv "$TMP" "$SETTINGS"
  echo "settings.json: SessionStart 큐레이터 훅 추가"
else
  echo "settings.json: SessionStart 큐레이터 이미 설치됨 — 건너뜀"
fi

# 3) CLAUDE.md에 독트린 추가 (마커 기준 멱등)
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
touch "$CLAUDE_MD"
if ! grep -q "growing-skills-doctrine:begin" "$CLAUDE_MD"; then
  cp "$CLAUDE_MD" "$CLAUDE_MD.bak.$TS"
  printf '\n' >> "$CLAUDE_MD"
  cat "$PKG_DIR/doctrine/doctrine.md" >> "$CLAUDE_MD"
  echo "CLAUDE.md: 독트린 추가 (백업: CLAUDE.md.bak.$TS)"
else
  echo "CLAUDE.md: 독트린 이미 존재 — 건너뜀"
fi

echo "설치 완료. 새 세션부터 적용됩니다."
