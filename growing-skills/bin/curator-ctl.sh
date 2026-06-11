#!/bin/bash
# /curator 컨트롤: status|promote|pin|unpin|pause|resume|restore|adopt|rollback
set -u
SKILLS_ROOT="${GROWING_SKILLS_ROOT:-$HOME/.claude/skills}"
PROPOSALS="${GROWING_SKILLS_PROPOSALS_DIR:-$HOME/.claude/skill-proposals}"
USAGE="$SKILLS_ROOT/.usage.json"
STATE="$SKILLS_ROOT/.curator_state"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq 필요"; exit 1; }
[ -f "$USAGE" ] || printf '{"skills":{},"compacted_at":null}\n' > "$USAGE"

usage_set() { # jq 프로그램으로 사이드카 갱신
  local prog="$1"; shift
  local tmp; tmp=$(mktemp)
  jq "$@" "$prog" "$USAGE" > "$tmp" && jq -e . "$tmp" >/dev/null && mv "$tmp" "$USAGE"
}
state_set() {
  local prog="$1"; shift
  [ -f "$STATE" ] || printf '{"last_run_at":0,"paused":false}\n' > "$STATE"
  local tmp; tmp=$(mktemp)
  jq "$@" "$prog" "$STATE" > "$tmp" && jq -e . "$tmp" >/dev/null && mv "$tmp" "$STATE"
}

CMD="${1:-status}"
case "$CMD" in
  promote)
    NAME="${2:?스킬명 필요}"
    SRC="$PROPOSALS/$NAME"; DST="$SKILLS_ROOT/$NAME"
    [ -d "$SRC" ] || { echo "ERROR: 제안 없음: $NAME"; exit 1; }
    [ -e "$DST" ] && { echo "ERROR: 동명 스킬이 이미 존재: $NAME"; exit 1; }
    ACTIVE=$(jq -r '[.skills | to_entries[] | select(.value.created_by=="agent" and (.value.state // "active")=="active")] | length' "$USAGE")
    [ "$ACTIVE" -ge 15 ] && echo "WARN: 승격된 agent 스킬이 예산(15)에 도달 — 큐레이터 통합 권장"
    mv "$SRC" "$DST"
    usage_set '.skills[$n] = ((.skills[$n] // {use:0}) + {created_by:"agent", first_seen:$now, state:"active", pinned:false})' --arg n "$NAME" --arg now "$NOW"
    echo "승격 완료: $NAME (다음 세션부터 로드됨)"
    ;;
  pin|unpin)
    NAME="${2:?스킬명 필요}"
    VAL=$([ "$CMD" = "pin" ] && echo true || echo false)
    usage_set '.skills[$n] = ((.skills[$n] // {}) + {pinned: ($v == "true")})' --arg n "$NAME" --arg v "$VAL"
    echo "$CMD: $NAME"
    ;;
  pause|resume)
    VAL=$([ "$CMD" = "pause" ] && echo true || echo false)
    state_set '.paused = ($v == "true")' --arg v "$VAL"
    echo "큐레이터 $CMD"
    ;;
  restore)
    NAME="${2:?스킬명 필요}"
    SRC="$SKILLS_ROOT/.archive/$NAME"; DST="$SKILLS_ROOT/$NAME"
    [ -d "$SRC" ] || { echo "ERROR: 아카이브에 없음: $NAME"; exit 1; }
    [ -e "$DST" ] && { echo "ERROR: 동명 스킬 존재"; exit 1; }
    mv "$SRC" "$DST"
    usage_set '.skills[$n] = ((.skills[$n] // {}) + {state:"active", last_activity_at:$now})' --arg n "$NAME" --arg now "$NOW"
    echo "복원 완료: $NAME"
    ;;
  adopt)
    NAME="${2:?스킬명 필요}"
    [ -f "$SKILLS_ROOT/$NAME/SKILL.md" ] || { echo "ERROR: 스킬 없음: $NAME"; exit 1; }
    usage_set '.skills[$n] = ((.skills[$n] // {use:0, created_by:"user", state:"active", pinned:false}) + {curated: true, first_seen: (.skills[$n].first_seen // $now)})' --arg n "$NAME" --arg now "$NOW"
    echo "수명 관리 옵트인: $NAME (통합 대상은 아님 — 30/90일 전이만 적용)"
    ;;
  rollback)
    LATEST=$(command ls -t "$SKILLS_ROOT/.curator_backups/"*.tar.gz 2>/dev/null | head -1)
    [ -n "$LATEST" ] || { echo "ERROR: 스냅샷 없음"; exit 1; }
    tar -xzf "$LATEST" -C "$SKILLS_ROOT"
    echo "롤백 완료: $LATEST"
    ;;
  status)
    AGENT=$(jq -r '[.skills | to_entries[] | select(.value.created_by=="agent" and (.value.state // "active")=="active")] | length' "$USAGE")
    STALE=$(jq -r '[.skills | to_entries[] | select(.value.state=="stale")] | length' "$USAGE")
    ARCHIVED=$(command ls "$SKILLS_ROOT/.archive" 2>/dev/null | wc -l | tr -d ' ')
    PROPS=$(command ls -d "$PROPOSALS"/*/ 2>/dev/null | grep -v ".discarded" | wc -l | tr -d ' ')
    LASTRUN=$(jq -r '.last_run_at // 0' "$STATE" 2>/dev/null || echo 0)
    PAUSED=$(jq -r '.paused // false' "$STATE" 2>/dev/null || echo false)
    echo "승격된 agent 스킬: $AGENT / 예산 15"
    echo "stale 스킬: $STALE / 아카이브: $ARCHIVED"
    echo "대기 제안: $PROPS (위치: $PROPOSALS)"
    echo "마지막 패스(epoch): $LASTRUN / 일시정지: $PAUSED"
    ;;
  *) echo "사용법: curator-ctl.sh {status|promote|pin|unpin|pause|resume|restore|adopt|rollback} [skill]"; exit 1;;
esac
exit 0
