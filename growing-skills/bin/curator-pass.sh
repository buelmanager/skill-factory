#!/bin/bash
# growing-skills 주간 큐레이터 패스. --dry-run 지원.
# 순서: 락 → paused → [스탬프 write-ahead] → 컴팩션 → 스냅샷 → 수명 전이 → 제안 폐기
#       → (조건부) LLM 우산 통합(스테이징+매니페스트 검증) → 참조 재작성 → REPORT.
# 하드 삭제 경로 없음: 모든 제거는 .archive/ 또는 .discarded/ 로의 mv.
set -u
SKILLS_ROOT="${GROWING_SKILLS_ROOT:-$HOME/.claude/skills}"
GS_HOME="${GROWING_SKILLS_HOME:-$HOME/.claude/growing-skills}"
PROPOSALS="${GROWING_SKILLS_PROPOSALS_DIR:-$HOME/.claude/skill-proposals}"
MODEL="${GROWING_SKILLS_MODEL:-sonnet}"
CONSOLIDATE_MIN="${GROWING_SKILLS_CONSOLIDATE_MIN:-8}"
USAGE="$SKILLS_ROOT/.usage.json"
STATE="$SKILLS_ROOT/.curator_state"
LOCK="$SKILLS_ROOT/.curator.lock"
REPORTS="$SKILLS_ROOT/.curator_reports"
BACKUPS="$SKILLS_ROOT/.curator_backups"
ARCHIVE="$SKILLS_ROOT/.archive"
STAGING="$SKILLS_ROOT/.curator_staging"
NOW=$(date +%s)
NOWISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1
command -v jq >/dev/null 2>&1 || exit 1

iso_to_epoch() { date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$1" +%s 2>/dev/null || echo 0; }

# 락 (noclobber 원자 획득, 2h stale)
acquire_lock() { ( set -o noclobber; printf '%s\n%s\n' "$$" "$NOW" > "$LOCK" ) 2>/dev/null; }
if ! acquire_lock; then
  LTS=$(sed -n 2p "$LOCK" 2>/dev/null); [ -z "$LTS" ] && LTS=0
  [ $((NOW - LTS)) -lt 7200 ] && exit 0
  rm -f "$LOCK"; acquire_lock || exit 0
fi
trap 'rm -f "$LOCK"' EXIT

# paused
[ "$(jq -r '.paused // false' "$STATE" 2>/dev/null)" = "true" ] && exit 0

mkdir -p "$REPORTS"
REPORT="$REPORTS/$(date +%Y-%m-%d-%H%M%S).md"
{
  [ "$DRY" -eq 1 ] && echo "# 큐레이터 보고서 (DRY-RUN — 아무것도 변경하지 않음)" || echo "# 큐레이터 보고서"
  echo "- 실행: $NOWISO"
} > "$REPORT"

# write-ahead 스탬프 (dry-run 제외)
if [ "$DRY" -eq 0 ]; then
  [ -f "$STATE" ] || printf '{"last_run_at":0,"paused":false}\n' > "$STATE"
  TMP=$(mktemp); jq --argjson t "$NOW" '.last_run_at = $t' "$STATE" > "$TMP" && mv "$TMP" "$STATE"
fi

# 1) 컴팩션
[ "$DRY" -eq 0 ] && GROWING_SKILLS_ROOT="$SKILLS_ROOT" bash "$GS_HOME/bin/compact-events.sh" 2>/dev/null
[ -f "$USAGE" ] || printf '{"skills":{},"compacted_at":null}\n' > "$USAGE"

# 관리 대상 스킬 목록 (agent 생성 또는 adopt(curated)된 것, 미고정, 디렉터리 실존)
MANAGED=$(jq -r '.skills | to_entries[] | select((.value.created_by=="agent" or .value.curated==true) and (.value.pinned // false | not) and (.value.state // "active") != "archived") | .key' "$USAGE")

# 2) 스냅샷 (관리 대상 + 사이드카만; dry-run 제외)
if [ "$DRY" -eq 0 ]; then
  mkdir -p "$BACKUPS"
  SNAP_LIST=$(mktemp)
  for s in $MANAGED; do [ -d "$SKILLS_ROOT/$s" ] && echo "$s" >> "$SNAP_LIST"; done
  echo ".usage.json" >> "$SNAP_LIST"
  [ -f "$STATE" ] && echo ".curator_state" >> "$SNAP_LIST"
  tar -czf "$BACKUPS/$(date +%Y%m%d-%H%M%S).tar.gz" -C "$SKILLS_ROOT" -T "$SNAP_LIST" 2>/dev/null
  rm -f "$SNAP_LIST"
  command ls -t "$BACKUPS"/*.tar.gz 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null
fi

# 3) 수명 전이: 30일→stale, 90일→archive
echo "## 수명 전이" >> "$REPORT"
for s in $MANAGED; do
  [ -d "$SKILLS_ROOT/$s" ] || continue
  LASTISO=$(jq -r --arg n "$s" '.skills[$n].last_activity_at // .skills[$n].first_seen // empty' "$USAGE")
  [ -z "$LASTISO" ] && continue
  LASTE=$(iso_to_epoch "$LASTISO"); [ "$LASTE" -eq 0 ] && continue
  IDLE_DAYS=$(( (NOW - LASTE) / 86400 ))
  CURSTATE=$(jq -r --arg n "$s" '.skills[$n].state // "active"' "$USAGE")
  if [ "$IDLE_DAYS" -ge 90 ]; then
    echo "- $s: ${IDLE_DAYS}일 미사용 → 아카이브" >> "$REPORT"
    if [ "$DRY" -eq 0 ]; then
      mkdir -p "$ARCHIVE"; mv "$SKILLS_ROOT/$s" "$ARCHIVE/$s"
      TMP=$(mktemp); jq --arg n "$s" '.skills[$n].state = "archived"' "$USAGE" > "$TMP" && mv "$TMP" "$USAGE"
    fi
  elif [ "$IDLE_DAYS" -ge 30 ] && [ "$CURSTATE" = "active" ]; then
    echo "- $s: ${IDLE_DAYS}일 미사용 → stale" >> "$REPORT"
    if [ "$DRY" -eq 0 ]; then
      TMP=$(mktemp); jq --arg n "$s" '.skills[$n].state = "stale"' "$USAGE" > "$TMP" && mv "$TMP" "$USAGE"
    fi
  fi
done

# 4) 제안 60일 폐기 (.discarded로 mv, 14일 후 정리)
echo "## 제안 정리" >> "$REPORT"
for d in "$PROPOSALS"/*/; do
  [ -d "$d" ] || continue
  case "$d" in *".discarded"*) continue;; esac
  PNAME=$(basename "$d")
  PISO=$(grep -m1 "^proposed_at:" "$d/SKILL.md" 2>/dev/null | sed 's/proposed_at:[[:space:]]*//')
  [ -z "$PISO" ] && continue
  PE=$(iso_to_epoch "$PISO"); [ "$PE" -eq 0 ] && continue
  if [ $(( (NOW - PE) / 86400 )) -ge 60 ]; then
    echo "- $PNAME: 60일 초과 미승격 → 폐기" >> "$REPORT"
    [ "$DRY" -eq 0 ] && { mkdir -p "$PROPOSALS/.discarded"; mv "$d" "$PROPOSALS/.discarded/$PNAME"; }
  fi
done
find "$PROPOSALS/.discarded" -mindepth 1 -maxdepth 1 -mtime +14 -exec rm -rf {} + 2>/dev/null

# 5) LLM 우산 통합 (active agent 스킬이 CONSOLIDATE_MIN 이상, dry-run 제외)
ACTIVE_AGENT=$(jq -r '[.skills | to_entries[] | select(.value.created_by=="agent" and (.value.state // "active")=="active" and (.value.pinned // false | not))] | map(.key) | .[]' "$USAGE")
ACTIVE_COUNT=$(printf '%s\n' "$ACTIVE_AGENT" | grep -c .)
echo "## 우산 통합" >> "$REPORT"
if [ "$DRY" -eq 0 ] && [ "$ACTIVE_COUNT" -ge "$CONSOLIDATE_MIN" ] && command -v claude >/dev/null 2>&1; then
  rm -rf "$STAGING"; mkdir -p "$STAGING"
  BATCH=$(mktemp)
  for s in $ACTIVE_AGENT; do
    [ -f "$SKILLS_ROOT/$s/SKILL.md" ] || continue
    STATS=$(jq -r --arg n "$s" '.skills[$n] | "use=\(.use // 0) last=\(.last_activity_at // "?")"' "$USAGE")
    printf '=== SKILL: %s (%s) ===\n' "$s" "$STATS" >> "$BATCH"
    cat "$SKILLS_ROOT/$s/SKILL.md" >> "$BATCH"; printf '\n' >> "$BATCH"
  done
  PROMPT="$(cat "$GS_HOME/prompts/curator-prompt.md")

[환경]
- 스테이징 디렉터리: $STAGING
- 오늘 날짜: $(date +%Y-%m-%d)"
  if cat "$BATCH" | env -u ANTHROPIC_API_KEY GROWING_SKILLS_BG=1 \
      timeout 900 claude -p "$PROMPT" \
      --model "$MODEL" \
      --settings "$GS_HOME/settings/headless-settings.json" \
      --strict-mcp-config \
      --allowedTools "Read" "Write(/$STAGING/**)" "Edit(/$STAGING/**)" \
      --disallowedTools "Bash" \
      >> "$REPORT" 2>&1 && [ -f "$STAGING/moves.json" ]; then
    # 매니페스트 검증: from은 전부 ACTIVE_AGENT 목록에, into는 스테이징 또는 기존 스킬에 존재
    VALID=1
    for FROM in $(jq -r '.moves[].from' "$STAGING/moves.json" 2>/dev/null); do
      printf '%s\n' "$ACTIVE_AGENT" | grep -qx "$FROM" || { VALID=0; break; }
    done
    for INTO in $(jq -r '.moves[].into' "$STAGING/moves.json" 2>/dev/null); do
      [ -f "$STAGING/$INTO/SKILL.md" ] || [ -f "$SKILLS_ROOT/$INTO/SKILL.md" ] || { VALID=0; break; }
    done
    jq -e '.moves' "$STAGING/moves.json" >/dev/null 2>&1 || VALID=0
    if [ "$VALID" -eq 1 ]; then
      # 우산 설치 + 사이드카 등록
      for u in "$STAGING"/*/; do
        [ -f "$u/SKILL.md" ] || continue
        UNAME=$(basename "$u")
        [ -e "$SKILLS_ROOT/$UNAME" ] || mv "$u" "$SKILLS_ROOT/$UNAME"
        TMP=$(mktemp); jq --arg n "$UNAME" --arg now "$NOWISO" '.skills[$n] = ((.skills[$n] // {use:0}) + {created_by:"agent", first_seen:$now, state:"active", pinned:false})' "$USAGE" > "$TMP" && mv "$TMP" "$USAGE"
      done
      # 흡수: from → .archive + absorbed_into 기록 + 참조 재작성(관리 대상 스킬 내부만)
      jq -c '.moves[]' "$STAGING/moves.json" | while IFS= read -r mv_json; do
        FROM=$(printf '%s' "$mv_json" | jq -r '.from'); INTO=$(printf '%s' "$mv_json" | jq -r '.into')
        [ -d "$SKILLS_ROOT/$FROM" ] || continue
        mkdir -p "$ARCHIVE"; mv "$SKILLS_ROOT/$FROM" "$ARCHIVE/$FROM"
        TMP=$(mktemp); jq --arg n "$FROM" --arg i "$INTO" '.skills[$n] = ((.skills[$n] // {}) + {state:"archived", absorbed_into:$i})' "$USAGE" > "$TMP" && mv "$TMP" "$USAGE"
        for s in $MANAGED; do
          F="$SKILLS_ROOT/$s/SKILL.md"
          [ -f "$F" ] && grep -q "$FROM" "$F" 2>/dev/null && sed -i '' "s/$FROM/$INTO/g" "$F"
        done
        echo "- 흡수: $FROM → $INTO" >> "$REPORT"
      done
    else
      echo "- 매니페스트 검증 실패 — 통합 적용 안 함 (스테이징 보존: $STAGING)" >> "$REPORT"
    fi
  else
    echo "- 통합 패스 실행 실패 또는 moves.json 미산출" >> "$REPORT"
  fi
  rm -f "$BATCH"
else
  echo "- 건너뜀 (active agent 스킬 $ACTIVE_COUNT < $CONSOLIDATE_MIN 또는 dry-run)" >> "$REPORT"
fi

# 위생: 보고서 12개 보관
command ls -t "$REPORTS"/*.md 2>/dev/null | tail -n +13 | xargs rm -f 2>/dev/null
exit 0
