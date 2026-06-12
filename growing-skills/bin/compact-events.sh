#!/bin/bash
# .usage-events.jsonl → .usage.json 컴팩션 + 이벤트 로테이션.
# 컴팩션 실패 시 이벤트를 복원해 데이터 유실을 막는다.
set -u
SKILLS_ROOT="${GROWING_SKILLS_ROOT:-$HOME/.claude/skills}"
EVENTS="$SKILLS_ROOT/.usage-events.jsonl"
USAGE="$SKILLS_ROOT/.usage.json"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
command -v jq >/dev/null 2>&1 || exit 1

[ -f "$USAGE" ] || printf '{"skills":{},"compacted_at":null}\n' > "$USAGE"

PROC="$EVENTS.processing"
# 이전 실행이 죽으며 남긴 고아 .processing 복구 (덮어쓰면 텔레메트리 영구 유실)
if [ -f "$PROC" ]; then
  cat "$PROC" >> "$EVENTS" 2>/dev/null && rm -f "$PROC"
fi
[ -s "$EVENTS" ] || exit 0
mv "$EVENTS" "$PROC" 2>/dev/null || exit 0   # 이후 새 이벤트는 새 파일에 append

CLEAN=$(mktemp); TMP=$(mktemp)
trap 'rm -f "$CLEAN" "$TMP"' EXIT
# 깨진 라인 방어: 유효 JSON에 skill 필드가 있는 라인만 통과
while IFS= read -r line; do
  printf '%s\n' "$line" | jq -ce 'select(.skill? != null)' 2>/dev/null
done < "$PROC" > "$CLEAN"

if jq -s --arg now "$NOW" '
  (.[0]) as $usage
  | (.[1:]) as $events
  | ($events | group_by(.skill) | map({
      key: .[0].skill,
      value: { add_use: length, last: (map(.ts) | max) }
    }) | from_entries) as $agg
  | $usage
  | .skills = (
      ((.skills // {}) | keys) + ($agg | keys) | unique
      | map(. as $k | {
          key: $k,
          value: (
            (($usage.skills // {})[$k] // {use:0, first_seen:$now, created_by:"user", state:"active", pinned:false}) as $cur
            | if $agg[$k] then
                $cur
                + {use: (($cur.use // 0) + $agg[$k].add_use),
                   last_activity_at: ([($cur.last_activity_at // ""), $agg[$k].last] | max)}
                + (if ($cur.state // "active") == "stale" then {state: "active"} else {} end)
              else $cur end
          )
        }) | from_entries
    )
  | .compacted_at = $now
' "$USAGE" "$CLEAN" > "$TMP" && jq -e . "$TMP" >/dev/null 2>&1; then
  mv "$TMP" "$USAGE"
  rm -f "$PROC"
else
  cat "$PROC" >> "$EVENTS" 2>/dev/null; rm -f "$PROC"   # 실패 → 이벤트 복원
  exit 1
fi
exit 0
