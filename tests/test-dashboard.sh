#!/bin/bash
# dashboard.sh 테스트. 실행: bash tests/test-dashboard.sh
set -u
PKG="$(cd "$(dirname "$0")/.." && pwd)/growing-skills"
RUN="$PKG/bin/dashboard.sh"
PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "PASS: $1"; else FAIL=$((FAIL+1)); echo "FAIL: $1 (exp [$2] got [$3])"; fi; }
assert_contains() { if printf '%s' "$2" | grep -qF -- "$3"; then PASS=$((PASS+1)); echo "PASS: $1"; else FAIL=$((FAIL+1)); echo "FAIL: $1 (missing [$3])"; fi; }
iso_days_ago() { date -j -u -v-"$1"d +%Y-%m-%dT%H:%M:%SZ; }
mk_skill() { mkdir -p "$1/$2"; printf -- "---\nname: %s\ndescription: Use when testing\ncreated_by: %s\n---\nbody\n" "$2" "$3" > "$1/$2/SKILL.md"; }
new_env() { SB=$(mktemp -d); SK="$SB/skills"; PR="$SB/proposals"; mkdir -p "$SK" "$PR"; }
runjson() { GROWING_SKILLS_ROOT="$SK" GROWING_SKILLS_PROPOSALS_DIR="$PR" bash "$RUN" --json; }
render() { GROWING_SKILLS_ROOT="$SK" GROWING_SKILLS_PROPOSALS_DIR="$PR" bash "$RUN" --render-stdin; }

# T1: 빈 환경
new_env
OUT=$(runjson)
assert_eq "T1 valid json"     "ok" "$(printf '%s' "$OUT" | jq -e . >/dev/null 2>&1 && echo ok || echo no)"
assert_eq "T1 stale_days"     "30" "$(printf '%s' "$OUT" | jq -r '.thresholds.stale_days')"
assert_eq "T1 archive_days"   "90" "$(printf '%s' "$OUT" | jq -r '.thresholds.archive_days')"
assert_eq "T1 consolidate"    "8"  "$(printf '%s' "$OUT" | jq -r '.thresholds.consolidate_min')"
assert_eq "T1 summary.active" "0"  "$(printf '%s' "$OUT" | jq -r '.summary.active')"
assert_eq "T1 skills empty"   "0"  "$(printf '%s' "$OUT" | jq -r '.skills | length')"

# T2: 머지
new_env
mk_skill "$SK" only-in-dir user; mk_skill "$SK" tracked agent
mkdir -p "$SK/.archive/old-archived"; printf -- "---\nname: old-archived\ncreated_by: agent\n---\nx\n" > "$SK/.archive/old-archived/SKILL.md"
jq -n '{skills:{tracked:{use:5,created_by:"agent",state:"active",pinned:false,first_seen:"2026-05-01T00:00:00Z",last_activity_at:"2026-06-01T00:00:00Z"}},compacted_at:null}' > "$SK/.usage.json"
OUT=$(runjson)
assert_eq "T2 only-in-dir state" "active" "$(printf '%s' "$OUT" | jq -r '.skills[]|select(.name=="only-in-dir").state')"
assert_eq "T2 only-in-dir cb"    "user"   "$(printf '%s' "$OUT" | jq -r '.skills[]|select(.name=="only-in-dir").created_by')"
assert_eq "T2 tracked use"       "5"      "$(printf '%s' "$OUT" | jq -r '.skills[]|select(.name=="tracked").use')"
assert_eq "T2 archived state"    "archived" "$(printf '%s' "$OUT" | jq -r '.skills[]|select(.name=="old-archived").state')"
assert_eq "T2 total"             "3"      "$(printf '%s' "$OUT" | jq -r '.skills|length')"

# T3: 파생 + summary + pipeline + state
new_env
mk_skill "$SK" fresh agent; mk_skill "$SK" aging agent; mk_skill "$SK" mine user
jq -n --arg d40 "$(iso_days_ago 40)" --arg d2 "$(iso_days_ago 2)" '{skills:{
  fresh:{use:9,created_by:"agent",state:"active",pinned:false,first_seen:$d2,last_activity_at:$d2},
  aging:{use:1,created_by:"agent",state:"stale",pinned:false,first_seen:$d40,last_activity_at:$d40},
  mine:{use:2,created_by:"user",state:"active",pinned:true,first_seen:$d2,last_activity_at:$d2}
},compacted_at:null}' > "$SK/.usage.json"
mkdir -p "$PR/pending-1"; printf -- "---\nname: pending-1\nproposed_at: 2026-06-10\n---\nx\n" > "$PR/pending-1/SKILL.md"
mkdir -p "$PR/.discarded/dead-1" "$SK/.review-queue"
printf 'd\n' > "$SK/.review-queue/20260611-000000-abc.md"
printf '{"last_run_at":1781174539,"paused":true}\n' > "$SK/.curator_state"
printf '{"last_run_at":1781161142}\n' > "$SK/.reviewer_state"
OUT=$(runjson)
assert_eq "T3 aging idle>=40"    "ok" "$(printf '%s' "$OUT" | jq -r '.skills[]|select(.name=="aging")|if .idle_days>=40 then "ok" else "no" end')"
assert_eq "T3 aging dtostale<=0" "ok" "$(printf '%s' "$OUT" | jq -r '.skills[]|select(.name=="aging")|if .days_to_stale<=0 then "ok" else "no" end')"
assert_eq "T3 mine managed"      "false" "$(printf '%s' "$OUT" | jq -r '.skills[]|select(.name=="mine").managed')"
assert_eq "T3 fresh managed"     "true"  "$(printf '%s' "$OUT" | jq -r '.skills[]|select(.name=="fresh").managed')"
assert_eq "T3 active"            "2" "$(printf '%s' "$OUT" | jq -r '.summary.active')"
assert_eq "T3 stale"             "1" "$(printf '%s' "$OUT" | jq -r '.summary.stale')"
assert_eq "T3 agent"             "2" "$(printf '%s' "$OUT" | jq -r '.summary.agent_created')"
assert_eq "T3 pinned"            "1" "$(printf '%s' "$OUT" | jq -r '.summary.pinned')"
assert_eq "T3 pending"           "1" "$(printf '%s' "$OUT" | jq -r '.summary.proposals_pending')"
assert_eq "T3 queue"             "1" "$(printf '%s' "$OUT" | jq -r '.summary.review_queue')"
assert_eq "T3 paused"            "true" "$(printf '%s' "$OUT" | jq -r '.summary.paused')"

# T4: events_by_day + lifecycle(로그+백필, 로그 우선)
new_env
printf '%s\n' \
  '{"ts":"2026-06-10T10:00:00Z","skill":"a","event":"use","session":"s"}' \
  '{"ts":"2026-06-10T11:00:00Z","skill":"b","event":"use","session":"s"}' \
  'broken' \
  '{"ts":"2026-06-11T09:00:00Z","skill":"a","event":"use","session":"s"}' > "$SK/.usage-events.jsonl"
printf '%s\n' '{"ts":"2026-06-11T14:00:00Z","event":"archived","skill":"old-b","reason":"95일 미사용","metadata":{"idle_days":95}}' > "$SK/.lifecycle-events.jsonl"
mkdir -p "$SK/.curator_reports"
printf '# r\n- 실행: 2026-06-11T14:23:00Z\n## 수명 전이\n- old-a: 40일 미사용 → stale\n- old-b: 95일 미사용 → 아카이브\n## 제안 정리\n- dead-x: 65일 초과 미승격 → 폐기\n' > "$SK/.curator_reports/2026-06-11-142300.md"
mkdir -p "$PR/born-1"; printf -- "---\nname: born-1\nproposed_at: 2026-06-09\nsource_session: sess-1\nrationale: 반복 패턴 X 때문\n---\nx\n" > "$PR/born-1/SKILL.md"
OUT=$(runjson)
assert_eq "T4 day0610"      "2" "$(printf '%s' "$OUT" | jq -r '.events_by_day[]|select(.date=="2026-06-10").count')"
assert_eq "T4 day0611"      "1" "$(printf '%s' "$OUT" | jq -r '.events_by_day[]|select(.date=="2026-06-11").count')"
assert_eq "T4 lc stale"     "old-a" "$(printf '%s' "$OUT" | jq -r '.lifecycle[]|select(.event=="stale").skill')"
assert_eq "T4 lc proposed"  "반복 패턴 X 때문" "$(printf '%s' "$OUT" | jq -r '.lifecycle[]|select(.event=="proposed" and .skill=="born-1").reason')"
# old-b archived: 로그(source=log) 우선, 중복 1건만
assert_eq "T4 archived src" "log" "$(printf '%s' "$OUT" | jq -r '.lifecycle[]|select(.event=="archived" and .skill=="old-b").source')"
assert_eq "T4 archived dedup" "1" "$(printf '%s' "$OUT" | jq -r '[.lifecycle[]|select(.event=="archived" and .skill=="old-b")]|length')"
assert_eq "T4 lc discard"   "dead-x" "$(printf '%s' "$OUT" | jq -r '.lifecycle[]|select(.event=="discarded").skill')"

# T5: HTML 셸 + 요약/기준
new_env
mk_skill "$SK" alpha agent
jq -n '{skills:{alpha:{use:7,created_by:"agent",state:"active",pinned:false,first_seen:"2026-06-01T00:00:00Z",last_activity_at:"2026-06-10T00:00:00Z"}},compacted_at:null}' > "$SK/.usage.json"
HTML=$(runjson | render)
assert_contains "T5 html open"  "$HTML" "<html"
assert_contains "T5 html close" "$HTML" "</html>"
assert_contains "T5 title"      "$HTML" "Growing Skills"
assert_contains "T5 palette"    "$HTML" "--series-output-token"
assert_contains "T5 threshold"  "$HTML" "90"
assert_eq "T5 no raw subst" "0" "$(printf '%s' "$HTML" | grep -cE '\{\{|__[A-Z_]+__')"

# T6: 파이프라인 + 표 + 노화
new_env
mk_skill "$SK" alpha agent; mk_skill "$SK" beta user
jq -n --arg d40 "$(iso_days_ago 40)" --arg d2 "$(iso_days_ago 2)" '{skills:{
  alpha:{use:7,created_by:"agent",state:"active",pinned:false,first_seen:$d40,last_activity_at:$d40},
  beta:{use:2,created_by:"user",state:"active",pinned:false,first_seen:$d2,last_activity_at:$d2}
},compacted_at:null}' > "$SK/.usage.json"
HTML=$(runjson | render)
assert_contains "T6 pipeline" "$HTML" "아카이브"
assert_contains "T6 table"    "$HTML" "alpha"
assert_contains "T6 sort js"  "$HTML" "sortTable"
assert_contains "T6 aging"    "$HTML" "삭제 위험"

# T7: 히트맵 + 막대 + 이유피드 + 일대기
new_env
printf '%s\n' \
  '{"ts":"2026-06-10T10:00:00Z","skill":"a","event":"use","session":"s"}' \
  '{"ts":"2026-06-11T09:00:00Z","skill":"a","event":"use","session":"s"}' > "$SK/.usage-events.jsonl"
printf '%s\n' '{"ts":"2026-06-11T14:00:00Z","event":"promoted","skill":"alpha","reason":"사용자 승격","metadata":{}}' > "$SK/.lifecycle-events.jsonl"
mk_skill "$SK" alpha agent
jq -n '{skills:{alpha:{use:7,created_by:"agent",state:"active",pinned:false,first_seen:"2026-06-01T00:00:00Z",last_activity_at:"2026-06-10T00:00:00Z"}},compacted_at:null}' > "$SK/.usage.json"
HTML=$(runjson | render)
assert_contains "T7 svg"        "$HTML" "<svg"
assert_contains "T7 rect"       "$HTML" "<rect"
assert_contains "T7 bars"       "$HTML" "class=\"bars\""
assert_contains "T7 heatmap h"  "$HTML" "활동 히트맵"
assert_contains "T7 feed reason" "$HTML" "사용자 승격"
assert_contains "T7 provenance" "$HTML" "스킬 일대기"
assert_contains "T7 prov skill" "$HTML" "alpha"

# T8: 실제 ~/.claude 데이터로 모델 생성
SMOKE=$(bash "$RUN" --json 2>/dev/null | jq -e '.generated_at and (.skills|type=="array") and (.lifecycle|type=="array")' >/dev/null 2>&1 && echo ok || echo no)
assert_eq "T8 real-data ok" "ok" "$SMOKE"

echo "---"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
