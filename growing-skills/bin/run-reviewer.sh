#!/bin/bash
# growing-skills 일간 배치 리뷰어.
# 게이트: 락(2h stale 자동 해제) → 일간(24h, GROWING_SKILLS_FORCE=1로 우회) → 큐 비면 종료.
# write-ahead: LLM 실행 전에 last_run_at 기록 (크래시 시 재발화 루프 방지).
set -u
SKILLS_ROOT="${GROWING_SKILLS_ROOT:-$HOME/.claude/skills}"
GS_HOME="${GROWING_SKILLS_HOME:-$HOME/.claude/growing-skills}"
PROPOSALS="${GROWING_SKILLS_PROPOSALS_DIR:-$HOME/.claude/skill-proposals}"
WIKI_RAW="${WIKI_BODY_PATH:-$HOME/llm-wiki-body}/domains/dev/raw"
MODEL="${GROWING_SKILLS_MODEL:-sonnet}"
QUEUE="$SKILLS_ROOT/.review-queue"
STATE="$SKILLS_ROOT/.reviewer_state"
LOCK="$SKILLS_ROOT/.reviewer.lock"
REPORTS="$SKILLS_ROOT/.review-reports"
NOW=$(date +%s)

command -v jq >/dev/null 2>&1 || exit 0
command -v claude >/dev/null 2>&1 || exit 0

# 락 (PID, epoch 2줄; 2시간 초과 시 stale로 보고 해제)
if [ -f "$LOCK" ]; then
  LTS=$(sed -n 2p "$LOCK" 2>/dev/null); [ -z "$LTS" ] && LTS=0
  [ $((NOW - LTS)) -lt 7200 ] && exit 0
  rm -f "$LOCK"
fi
printf '%s\n%s\n' "$$" "$NOW" > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

# 일간 게이트
if [ "${GROWING_SKILLS_FORCE:-}" != "1" ] && [ -f "$STATE" ]; then
  LAST=$(jq -r '.last_run_at // 0' "$STATE" 2>/dev/null || echo 0)
  [ $((NOW - LAST)) -lt 86400 ] && exit 0
fi

# 큐 확인 (스탬프보다 먼저 — 빈 큐로 일간 게이트를 소모하지 않는다)
ls "$QUEUE"/*.md >/dev/null 2>&1 || exit 0

mkdir -p "$REPORTS" "$QUEUE/done" "$PROPOSALS"
printf '{"last_run_at": %s}\n' "$NOW" > "$STATE"   # write-ahead

# 배치: 오래된 것부터 200KB까지. 남는 큐는 다음 배치로.
BATCH=$(mktemp); PICKED=$(mktemp)
trap 'rm -f "$LOCK" "$BATCH" "$PICKED"' EXIT
TOTAL=0
for f in $(ls "$QUEUE"/*.md | sort); do
  SZ=$(wc -c < "$f" | tr -d ' ')
  if [ $((TOTAL + SZ)) -gt 200000 ] && [ "$TOTAL" -gt 0 ]; then break; fi
  cat "$f" >> "$BATCH"; printf '\n' >> "$BATCH"
  echo "$f" >> "$PICKED"; TOTAL=$((TOTAL + SZ))
done

PROMPT="$(cat "$GS_HOME/prompts/reviewer-prompt.md")

[환경]
- 제안 디렉터리: $PROPOSALS
- 위키 dev raw 디렉터리: $WIKI_RAW
- 오늘 날짜: $(date +%Y-%m-%d)"

REPORT="$REPORTS/$(date +%Y-%m-%d-%H%M%S).md"
# 격리: API 키 제거(구독 인증), BG 마커(텔레메트리·재귀 차단), 훅 없는 settings, MCP 차단,
# 쓰기 권한은 제안·위키 raw 디렉터리만 (// = 절대 경로 권한 문법), Bash 금지.
if cat "$BATCH" | env -u ANTHROPIC_API_KEY GROWING_SKILLS_BG=1 \
    timeout 900 claude -p "$PROMPT" \
    --model "$MODEL" \
    --settings "$GS_HOME/settings/headless-settings.json" \
    --strict-mcp-config \
    --allowedTools "Read" "Write(/$PROPOSALS/**)" "Edit(/$PROPOSALS/**)" "Write(/$WIKI_RAW/**)" \
    --disallowedTools "Bash" \
    > "$REPORT" 2>&1; then
  while IFS= read -r f; do mv "$f" "$QUEUE/done/" 2>/dev/null; done < "$PICKED"
else
  printf '\n(리뷰어 실행 실패 — 큐 보존, 다음 배치에서 재시도)\n' >> "$REPORT"
fi

# 위생: 보고서 12개, done 14일 보관
ls -t "$REPORTS"/*.md 2>/dev/null | tail -n +13 | xargs rm -f 2>/dev/null
find "$QUEUE/done" -name "*.md" -mtime +14 -delete 2>/dev/null
exit 0
