#!/bin/bash
# install/uninstall 테스트 — 샌드박스 CLAUDE_DIR 에서만 동작 확인. 실행: bash tests/test-install.sh
set -u
PKG="$(cd "$(dirname "$0")/.." && pwd)/growing-skills"
PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "PASS: $1"; else FAIL=$((FAIL+1)); echo "FAIL: $1 (expected [$2] got [$3])"; fi; }

setup() {
  SANDBOX=$(mktemp -d)
  mkdir -p "$SANDBOX/.claude/hooks" "$SANDBOX/.claude/skills"
  # 기존 훅이 있는 settings.json 시뮬레이션 (실사용자 환경과 동일 구조)
  cat > "$SANDBOX/.claude/settings.json" <<'EOF'
{
  "env": {"EXISTING": "1"},
  "hooks": {
    "UserPromptSubmit": [
      {"hooks": [{"type": "command", "command": "~/.claude/hooks/existing.sh", "timeout": 3000}]}
    ]
  }
}
EOF
  echo "# 기존 내용" > "$SANDBOX/.claude/CLAUDE.md"
}
teardown() { rm -rf "$SANDBOX"; }

# T1: install — 훅 파일 복사 + settings 머지 + 독트린 추가 + 백업 생성
setup
GROWING_SKILLS_CLAUDE_DIR="$SANDBOX/.claude" bash "$PKG/install.sh" >/dev/null
assert_eq "T1 hook copied" "yes" "$([ -x "$SANDBOX/.claude/hooks/skill-telemetry.sh" ] && echo yes || echo no)"
assert_eq "T1 settings valid json" "yes" "$(jq -e . "$SANDBOX/.claude/settings.json" >/dev/null 2>&1 && echo yes || echo no)"
assert_eq "T1 PostToolUse Skill matcher" "Skill" "$(jq -r '.hooks.PostToolUse[] | select(.matcher=="Skill") | .matcher' "$SANDBOX/.claude/settings.json")"
assert_eq "T1 existing hook preserved" "1" "$(jq '.hooks.UserPromptSubmit | length' "$SANDBOX/.claude/settings.json")"
assert_eq "T1 env preserved" "1" "$(jq -r '.env.EXISTING' "$SANDBOX/.claude/settings.json")"
assert_eq "T1 doctrine appended" "1" "$(grep -c "growing-skills-doctrine:begin" "$SANDBOX/.claude/CLAUDE.md")"
assert_eq "T1 settings backup exists" "yes" "$(ls "$SANDBOX/.claude/"settings.json.bak.* >/dev/null 2>&1 && echo yes || echo no)"

# T2: install 멱등성 — 재실행해도 중복 없음
GROWING_SKILLS_CLAUDE_DIR="$SANDBOX/.claude" bash "$PKG/install.sh" >/dev/null
assert_eq "T2 one PostToolUse entry" "1" "$(jq '[.hooks.PostToolUse[] | select(.matcher=="Skill")] | length' "$SANDBOX/.claude/settings.json")"
assert_eq "T2 one doctrine block" "1" "$(grep -c "growing-skills-doctrine:begin" "$SANDBOX/.claude/CLAUDE.md")"

# T3: uninstall — 훅 항목 제거 + 독트린 제거 + 기존 설정 보존
GROWING_SKILLS_CLAUDE_DIR="$SANDBOX/.claude" bash "$PKG/uninstall.sh" >/dev/null
assert_eq "T3 PostToolUse Skill removed" "0" "$(jq '[.hooks.PostToolUse[]? | select(.matcher=="Skill")] | length' "$SANDBOX/.claude/settings.json")"
assert_eq "T3 existing hook still there" "1" "$(jq '.hooks.UserPromptSubmit | length' "$SANDBOX/.claude/settings.json")"
assert_eq "T3 doctrine removed" "0" "$(grep -c "growing-skills-doctrine:begin" "$SANDBOX/.claude/CLAUDE.md")"
assert_eq "T3 original content intact" "1" "$(grep -c "^# 기존 내용" "$SANDBOX/.claude/CLAUDE.md")"
teardown

# T4: end 마커가 사라진 비정상 CLAUDE.md → uninstall이 내용을 지우지 않음 (데이터 보호)
setup
GROWING_SKILLS_CLAUDE_DIR="$SANDBOX/.claude" bash "$PKG/install.sh" >/dev/null
sed '/growing-skills-doctrine:end/d' "$SANDBOX/.claude/CLAUDE.md" > "$SANDBOX/tmp.md" && mv "$SANDBOX/tmp.md" "$SANDBOX/.claude/CLAUDE.md"
echo "# 마커 아래 소중한 내용" >> "$SANDBOX/.claude/CLAUDE.md"
GROWING_SKILLS_CLAUDE_DIR="$SANDBOX/.claude" bash "$PKG/uninstall.sh" >/dev/null
assert_eq "T4 content below survives" "1" "$(grep -c "마커 아래 소중한 내용" "$SANDBOX/.claude/CLAUDE.md")"
assert_eq "T4 original content intact" "1" "$(grep -c "^# 기존 내용" "$SANDBOX/.claude/CLAUDE.md")"
assert_eq "T4 begin marker untouched" "1" "$(grep -c "growing-skills-doctrine:begin" "$SANDBOX/.claude/CLAUDE.md")"
teardown

# T5: Phase 2 설치 — 패키지 배포 + SessionEnd 훅 머지 + 멱등
setup
GROWING_SKILLS_CLAUDE_DIR="$SANDBOX/.claude" bash "$PKG/install.sh" >/dev/null
assert_eq "T5 reviewer deployed" "yes" "$([ -x "$SANDBOX/.claude/growing-skills/bin/run-reviewer.sh" ] && echo yes || echo no)"
assert_eq "T5 prompt deployed" "yes" "$([ -f "$SANDBOX/.claude/growing-skills/prompts/reviewer-prompt.md" ] && echo yes || echo no)"
assert_eq "T5 settings deployed" "yes" "$([ -f "$SANDBOX/.claude/growing-skills/settings/headless-settings.json" ] && echo yes || echo no)"
assert_eq "T5 sessionend hook entry" "1" "$(jq '[.hooks.SessionEnd[]? | select((.hooks // []) | any(.command // "" | contains("session-end-queue.sh")))] | length' "$SANDBOX/.claude/settings.json")"
GROWING_SKILLS_CLAUDE_DIR="$SANDBOX/.claude" bash "$PKG/install.sh" >/dev/null
assert_eq "T5 idempotent" "1" "$(jq '[.hooks.SessionEnd[]? | select((.hooks // []) | any(.command // "" | contains("session-end-queue.sh")))] | length' "$SANDBOX/.claude/settings.json")"

# T6: uninstall — SessionEnd 제거 + 패키지 제거 + 큐 데이터 보존
mkdir -p "$SANDBOX/.claude/skills/.review-queue"
echo "digest" > "$SANDBOX/.claude/skills/.review-queue/keep.md"
GROWING_SKILLS_CLAUDE_DIR="$SANDBOX/.claude" bash "$PKG/uninstall.sh" >/dev/null
assert_eq "T6 sessionend removed" "0" "$(jq '[.hooks.SessionEnd[]? | select((.hooks // []) | any(.command // "" | contains("session-end-queue.sh")))] | length' "$SANDBOX/.claude/settings.json")"
assert_eq "T6 package removed" "no" "$([ -d "$SANDBOX/.claude/growing-skills" ] && echo yes || echo no)"
assert_eq "T6 queue preserved" "1" "$(ls "$SANDBOX/.claude/skills/.review-queue"/*.md | wc -l | tr -d ' ')"
teardown

echo "----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
