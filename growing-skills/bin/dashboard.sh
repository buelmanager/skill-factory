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

dir_skills_json() {
  { for d in "$SKILLS_ROOT"/*/; do
      [ -f "${d}SKILL.md" ] || continue
      name=$(basename "$d"); case "$name" in .*) continue;; esac
      cb=$(sed -n 's/^created_by:[[:space:]]*//p' "${d}SKILL.md" | head -1 | tr -d '"'\''')
      [ -n "$cb" ] || cb="user"
      printf '%s\t%s\n' "$name" "$cb"
    done; } | jq -R -s 'split("\n")|map(select(length>0)|split("\t")|{name:.[0],created_by:.[1]})'
}
archived_json() {
  { for d in "$SKILLS_ROOT"/.archive/*/; do [ -d "$d" ] || continue; basename "$d"; done; } \
    | jq -R -s 'split("\n")|map(select(length>0))'
}

events_by_day_json() {
  [ -f "$EVENTS" ] || { echo '[]'; return; }
  jq -R -s 'split("\n")|map(select(length>0)|(try fromjson catch empty))
    | map(.ts[0:10]) | group_by(.) | map({date:.[0], count:length}) | sort_by(.date)' "$EVENTS"
}

# 리포트 전이 → 이벤트 형태 백필
report_events_json() {
  local files; files=$(find "$SKILLS_ROOT/.curator_reports" "$SKILLS_ROOT/.review-reports" -name '*.md' 2>/dev/null)
  { for f in $files; do
      d=$(basename "$f" | sed -nE 's/^([0-9]{4}-[0-9]{2}-[0-9]{2}).*/\1/p'); [ -n "$d" ] || d="?"
      grep -nE '→ *(stale|아카이브|폐기)|흡수:' "$f" 2>/dev/null | while IFS= read -r line; do
        body=${line#*:}
        case "$line" in
          *흡수:*) sk=$(printf '%s' "$body" | sed -nE 's/.*흡수: *([^ ]+).*/\1/p'); ty=absorbed;;
          *stale*) sk=$(printf '%s' "$body" | sed -nE 's/^[[:space:]]*- *([^:]+):.*/\1/p'); ty=stale;;
          *아카이브*) sk=$(printf '%s' "$body" | sed -nE 's/^[[:space:]]*- *([^:]+):.*/\1/p'); ty=archived;;
          *폐기*) sk=$(printf '%s' "$body" | sed -nE 's/^[[:space:]]*- *([^:]+):.*/\1/p'); ty=discarded;;
          *) continue;;
        esac
        det=$(printf '%s' "$body" | sed -E 's/^[[:space:]]*- *//; s/^[^:]*: *//')
        sk=$(printf '%s' "$sk" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
        [ -n "$sk" ] || continue
        printf '%s\t%s\t%s\t%s\n' "$d" "$ty" "$sk" "$det"
      done
    done; } | jq -R -s 'split("\n")|map(select(length>0)|split("\t")
      |{ts:null,date:.[0],event:.[1],skill:.[2],reason:.[3],metadata:{},source:"backfill"})'
}

# 제안 frontmatter → proposed 백필
proposal_events_json() {
  { for d in "$PROPOSALS"/*/ "$PROPOSALS"/.discarded/*/; do
      [ -f "${d}SKILL.md" ] || continue
      nm=$(basename "$d")
      pa=$(sed -n 's/^proposed_at:[[:space:]]*//p' "${d}SKILL.md" | head -1 | cut -c1-10)
      rat=$(sed -n 's/^rationale:[[:space:]]*//p' "${d}SKILL.md" | head -1 | tr -d '"'\''')
      ss=$(sed -n 's/^source_session:[[:space:]]*//p' "${d}SKILL.md" | head -1)
      [ -n "$rat" ] || rat="제안됨"; [ -n "$pa" ] || pa="?"
      printf '%s\t%s\t%s\t%s\n' "$nm" "$pa" "$rat" "$ss"
    done; } | jq -R -s 'split("\n")|map(select(length>0)|split("\t")
      |{ts:null,date:.[1],event:"proposed",skill:.[0],reason:.[2],metadata:{source_session:.[3]},source:"backfill"})'
}

# 구조적 로그
log_events_json() {
  [ -f "$LIFELOG" ] || { echo '[]'; return; }
  jq -R -s 'split("\n")|map(select(length>0)|(try fromjson catch empty))
    | map({ts:.ts, date:(.ts[0:10]), event:.event, skill:.skill,
           reason:.reason, metadata:(.metadata//{}), source:"log"})' "$LIFELOG"
}

# 통합 + 중복제거(같은 skill·event·date면 로그 우선)
lifecycle_json() {
  jq -n --argjson a "$(log_events_json)" --argjson b "$(report_events_json)" --argjson c "$(proposal_events_json)" '
    ($a + $b + $c) | group_by([.skill, .event, .date])
    | map((map(select(.source=="log"))[0]) // .[0]) | sort_by(.date) | reverse'
}

build_model() {
  local usage_skills dir_skills archived
  local pend disc queue cur_run rev_run paused
  pend=$(find "$PROPOSALS" -mindepth 1 -maxdepth 1 -type d ! -name '.*' 2>/dev/null | while read -r d; do [ -f "$d/SKILL.md" ] && echo x; done | wc -l | tr -d ' ')
  disc=$(find "$PROPOSALS/.discarded" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  queue=$(find "$SKILLS_ROOT/.review-queue" -mindepth 1 -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  cur_run=$([ -f "$SKILLS_ROOT/.curator_state" ] && jq -r '.last_run_at // empty' "$SKILLS_ROOT/.curator_state" 2>/dev/null || true)
  rev_run=$([ -f "$SKILLS_ROOT/.reviewer_state" ] && jq -r '.last_run_at // empty' "$SKILLS_ROOT/.reviewer_state" 2>/dev/null || true)
  paused=$([ -f "$SKILLS_ROOT/.curator_state" ] && jq -r '.paused // false' "$SKILLS_ROOT/.curator_state" 2>/dev/null || echo false)
  [ -n "$cur_run" ] || cur_run=null; [ -n "$rev_run" ] || rev_run=null
  usage_skills=$([ -f "$USAGE" ] && jq '.skills // {}' "$USAGE" || echo '{}')
  dir_skills=$(dir_skills_json); archived=$(archived_json)
  jq -n --arg gen "$NOWISO" --argjson th "$(thresholds_json)" \
    --argjson usage "$usage_skills" --argjson dirs "$dir_skills" --argjson archived "$archived" \
    --argjson now "$NOW" --argjson pend "$pend" --argjson disc "$disc" --argjson queue "$queue" \
    --argjson cur "$cur_run" --argjson rev "$rev_run" --argjson paused "$paused" \
    --argjson events "$(events_by_day_json)" --argjson lifecycle "$(lifecycle_json)" '
    ($usage | to_entries | map({name:.key} + .value)) as $base
    | ($base | map(.name)) as $known
    | ($dirs | map(select(.name as $n | ($known|index($n))|not)
        | {name:.name, created_by:.created_by, use:0, state:"active",
           pinned:false, first_seen:null, last_activity_at:null})) as $extra
    | ($base + $extra) as $merged
    | ($merged | map(.name)) as $all_known
    | ($archived | map(select(. as $n | ($all_known|index($n))|not)
        | {name:., created_by:"user", use:0, state:"archived",
           pinned:false, first_seen:null, last_activity_at:null})) as $arch_extra
    | ($merged + $arch_extra)
    | map(if (.name as $n | $archived|index($n)) then .state="archived" else . end)
    | map({ name, state:(.state // "active"), created_by:(.created_by // "user"),
            use:(.use // 0), first_seen:(.first_seen // null),
            last_activity_at:(.last_activity_at // null), pinned:(.pinned // false),
            absorbed_into:(.absorbed_into // null), curated:(.curated // false) }) as $skills
    | (def to_epoch: if . == null then null else (try (strptime("%Y-%m-%dT%H:%M:%SZ")|mktime) catch null) end;
       $skills | map(
         ((.last_activity_at // .first_seen) | to_epoch) as $le
         | (if $le == null then null else (($now - $le)/86400|floor) end) as $idle
         | . + { idle_days:$idle,
             managed: ((.created_by=="agent" or .curated==true) and (.pinned|not) and .state!="archived"),
             days_to_stale: (if $idle==null then null else (30 - $idle) end),
             days_to_archive: (if $idle==null then null else (90 - $idle) end) }
         | del(.curated) )) as $skills2
    | { generated_at:$gen, thresholds:$th,
        summary:{
          active:($skills2|map(select(.state=="active"))|length),
          stale:($skills2|map(select(.state=="stale"))|length),
          archived:($skills2|map(select(.state=="archived"))|length),
          agent_created:($skills2|map(select(.created_by=="agent"))|length),
          user_created:($skills2|map(select(.created_by=="user"))|length),
          pinned:($skills2|map(select(.pinned))|length),
          proposals_pending:$pend, proposals_discarded:$disc, review_queue:$queue,
          last_curator_run:$cur, last_reviewer_run:$rev, paused:$paused },
        pipeline:{ queue:$queue, proposals:$pend,
          active:($skills2|map(select(.state=="active"))|length),
          stale:($skills2|map(select(.state=="stale"))|length),
          archived:($skills2|map(select(.state=="archived"))|length),
          absorbed:($skills2|map(select(.absorbed_into!=null))|length) },
        skills:$skills2, events_by_day:$events, lifecycle:$lifecycle }'
}

render_html() {
  local model; model=$(cat)
  local css cards thresholds_rows gen paused_badge
  css=$(cat <<'CSS'
:root{--bg:#041c1c;--surface:#0a2a2a;--surface2:#0e3535;--border:#14494a;
--text:#ffe6cb;--muted:#8fb3a8;--accent:#34d399;
--series-input-token:#ffe6cb;--series-output-token:#34d399;
--warn:#f59e0b;--danger:#ef4444;--stale:#6b7280;
--hm0:#0a2a2a;--hm1:#0f5132;--hm2:#1a7a4a;--hm3:#2bb673;--hm4:#34d399;}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);
font:14px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
.wrap{max-width:1100px;margin:0 auto;padding:24px}
h1{font-size:22px;margin:0}h2{font-size:15px;color:var(--muted);text-transform:uppercase;
letter-spacing:.05em;margin:32px 0 12px}.sub{color:var(--muted);font-size:12px}
.grid{display:grid;gap:12px;grid-template-columns:repeat(auto-fill,minmax(150px,1fr))}
.card{background:var(--surface);border:1px solid var(--border);border-radius:10px;padding:14px}
.card .n{font-size:26px;font-weight:600}.card .l{color:var(--muted);font-size:12px}
table{width:100%;border-collapse:collapse;font-size:13px}
th,td{text-align:left;padding:7px 10px;border-bottom:1px solid var(--border)}
th{color:var(--muted);cursor:pointer;user-select:none}tr:hover td{background:var(--surface2)}
.badge{padding:1px 8px;border-radius:99px;font-size:11px}
.badge.active{background:rgba(52,211,153,.18);color:var(--accent)}
.badge.stale{background:rgba(107,114,128,.25);color:#cbd5d5}
.badge.archived{background:rgba(239,68,68,.16);color:#fca5a5}
.bars{display:flex;align-items:flex-end;gap:3px;height:160px}
.bars .b{flex:1;background:var(--series-output-token);border-radius:2px 2px 0 0;min-height:1px}
.pill{display:inline-block;background:var(--surface2);border:1px solid var(--border);
border-radius:8px;padding:8px 12px;margin:4px}.flow{display:flex;flex-wrap:wrap;align-items:center;gap:6px}
.flow .arrow{color:var(--muted)}.empty{color:var(--muted);font-style:italic;padding:16px;text-align:center}
details{background:var(--surface);border:1px solid var(--border);border-radius:8px;padding:8px 12px;margin:6px 0}
summary{cursor:pointer}.ev{padding:4px 0;border-bottom:1px solid var(--border)}
CSS
)
  cards=$(printf '%s' "$model" | jq -r '.summary as $s |
    [{l:"활성",n:$s.active},{l:"stale",n:$s.stale},{l:"아카이브",n:$s.archived},
     {l:"agent 생성",n:$s.agent_created},{l:"user 생성",n:$s.user_created},
     {l:"pinned",n:$s.pinned},{l:"대기 제안",n:$s.proposals_pending},{l:"리뷰 큐",n:$s.review_queue}]
    | map("<div class=\"card\"><div class=\"n\">\(.n)</div><div class=\"l\">\(.l)</div></div>")|join("")')
  thresholds_rows=$(printf '%s' "$model" | jq -r '.thresholds as $t |
    [{k:"세션 도구 최소",v:"\($t.min_tools)회",e:"GROWING_SKILLS_MIN_TOOLS"},
     {k:"리뷰어 게이트",v:"\($t.reviewer_gate_hours)h",e:"FORCE=1로 우회"},
     {k:"stale 전이",v:"유휴 \($t.stale_days)일",e:"curator-pass.sh"},
     {k:"아카이브 전이",v:"유휴 \($t.archive_days)일",e:"curator-pass.sh"},
     {k:"제안 폐기",v:"\($t.proposal_discard_days)일",e:".discarded 14일 후 정리"},
     {k:"우산 통합",v:"agent ≥ \($t.consolidate_min)개",e:"GROWING_SKILLS_CONSOLIDATE_MIN"},
     {k:"백업 보관",v:"\($t.backups_retained)개",e:"rollback"},
     {k:"승격 예산 경고",v:"\($t.promote_budget_warn)개",e:"agent 스킬 수"}]
    | map("<tr><td>\(.k)</td><td>\(.v)</td><td class=\"sub\">\(.e)</td></tr>")|join("")')
  gen=$(printf '%s' "$model" | jq -r '.generated_at')
  paused_badge=$(printf '%s' "$model" | jq -r 'if .summary.paused then "<span class=\"badge archived\">일시정지</span>" else "" end')
  cat <<HTML
<!doctype html><html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Growing Skills Dashboard</title><style>$css</style></head>
<body><div class="wrap">
<h1>🌱 Growing Skills Dashboard $paused_badge</h1><div class="sub">생성: $gen</div>
<h2>요약</h2><div class="grid">$cards</div>
<!-- W2_PIPELINE --><!-- W3_HEATMAP --><!-- W4_BARS --><!-- W5_TABLE --><!-- W6_AGING --><!-- W7_FEED --><!-- W9_PROVENANCE -->
<h2>판정 기준</h2><table><thead><tr><th>규칙</th><th>값</th><th>비고</th></tr></thead><tbody>$thresholds_rows</tbody></table>
</div></body></html>
HTML
}

MODE="${1:-html}"
case "$MODE" in
  --json) build_model ;;
  --render-stdin) render_html ;;
  --serve)
    mkdir -p "$OUT_DIR"; build_model | render_html > "$OUT_HTML"; echo "생성됨: $OUT_HTML"
    if command -v python3 >/dev/null 2>&1; then ( cd "$OUT_DIR" && python3 -m http.server 8777 ) || true
    else echo "python3 없음 — 직접 여세요: $OUT_HTML"; fi ;;
  --open)
    mkdir -p "$OUT_DIR"; build_model | render_html > "$OUT_HTML"; echo "생성됨: $OUT_HTML"
    if command -v open >/dev/null 2>&1; then open "$OUT_HTML"
    elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$OUT_HTML"
    else echo "브라우저로 직접 여세요: $OUT_HTML"; fi ;;
  html|"") mkdir -p "$OUT_DIR"; build_model | render_html > "$OUT_HTML"; echo "생성됨: $OUT_HTML" ;;
  *) echo "사용법: dashboard.sh [--json|--render-stdin|--serve|--open]" >&2; exit 2 ;;
esac
