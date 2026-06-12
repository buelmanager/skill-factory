#!/bin/bash
# growing-skills 대시보드 생성기. 읽기 전용.
# 모드: (기본) HTML 생성, --json 모델 JSON stdout, --render-stdin stdin모델→HTML, --serve 생성+서버.
set -u
SKILLS_ROOT="${GROWING_SKILLS_ROOT:-$HOME/.claude/skills}"
PROPOSALS="${GROWING_SKILLS_PROPOSALS_DIR:-$HOME/.claude/skill-proposals}"
OUT_DIR="$SKILLS_ROOT/.dashboard"; OUT_HTML="$OUT_DIR/index.html"
USAGE="$SKILLS_ROOT/.usage.json"; EVENTS="$SKILLS_ROOT/.usage-events.jsonl"
LIFELOG="$SKILLS_ROOT/.lifecycle-events.jsonl"
NOW=$(date +%s); NOWISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
command -v jq >/dev/null 2>&1 || { echo "jq가 필요합니다 (brew install jq)" >&2; exit 1; }

TH_MIN_TOOLS="${GROWING_SKILLS_MIN_TOOLS:-15}"; TH_CONSOLIDATE="${GROWING_SKILLS_CONSOLIDATE_MIN:-8}"

thresholds_json() {
  jq -n --argjson mt "$TH_MIN_TOOLS" --argjson cn "$TH_CONSOLIDATE" '{
    min_tools:$mt, reviewer_gate_hours:24, stale_days:30, archive_days:90,
    proposal_discard_days:60, discarded_cleanup_days:14, consolidate_min:$cn,
    backups_retained:5, reports_retained:12, promote_budget_warn:15 }'
}

build_model() {  # Task 6~8에서 채워짐
  jq -n --arg gen "$NOWISO" --argjson th "$(thresholds_json)" '{
    generated_at:$gen, thresholds:$th,
    summary:{active:0,stale:0,archived:0,agent_created:0,user_created:0,pinned:0,
             proposals_pending:0,proposals_discarded:0,review_queue:0,
             last_curator_run:null,last_reviewer_run:null,paused:false},
    pipeline:{queue:0,proposals:0,active:0,stale:0,archived:0,absorbed:0},
    skills:[], events_by_day:[], lifecycle:[] }'
}

MODE="${1:-html}"
case "$MODE" in
  --json) build_model ;;
  --render-stdin|--serve|--open|html|"") echo "렌더는 Task 9에서 구현됩니다" >&2; exit 0 ;;
  *) echo "사용법: dashboard.sh [--json|--render-stdin|--serve|--open]" >&2; exit 2 ;;
esac
