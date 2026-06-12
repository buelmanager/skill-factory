# Growing Skills Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** growing-skills 스킬의 생성·성장·삭제 *이유*를 append-only 이벤트 로그로 **캡처**하고, 그 이유와 전체 라이프사이클을 bash+jq가 생성하는 self-contained 단일 HTML 대시보드로 **시각화**한다.

**Architecture:** 두 파트. **Part 1(캡처)** — 공통 헬퍼 `lifecycle-log.sh`를 프로듀서(curator-pass/curator-ctl/run-reviewer)가 source 해, 각 전이 시 이유와 함께 `.lifecycle-events.jsonl`에 한 줄을 append. **Part 2(대시보드)** — `dashboard.sh`가 사이드카·디렉토리·리포트·이벤트로그를 읽어 단일 모델 JSON을 만들고(`--json`), 인라인 CSS/SVG/JS HTML로 렌더. 과거 이유는 기존 리포트·제안 frontmatter에서 백필. 외부 의존성 0, 오프라인 동작.

**Tech Stack:** bash (macOS BSD `date`), jq 1.8.1+, 인라인 HTML/CSS/vanilla JS. 기존 `growing-skills/bin/*.sh` 컨벤션(`GROWING_SKILLS_ROOT`, `GROWING_SKILLS_PROPOSALS_DIR`, `GROWING_SKILLS_HOME`) 준수. 모든 추가는 비파괴·append-only.

---

## 파일 구조

**Part 1 (캡처):**
- Create: `growing-skills/bin/lifecycle-log.sh` — `lifecycle_log` 함수. 단일 책임: 이벤트 한 줄 append (비차단).
- Modify: `growing-skills/bin/curator-pass.sh` — stale/archive/discard/absorb emit.
- Modify: `growing-skills/bin/curator-ctl.sh` — promote/restore/adopt/pin emit.
- Modify: `growing-skills/bin/run-reviewer.sh` — 신규 제안 proposed emit.
- Modify: `growing-skills/prompts/reviewer-prompt.md` — `rationale:` frontmatter 지시.
- Create: `tests/test-lifecycle-log.sh`, `tests/test-lifecycle-capture.sh`.

**Part 2 (대시보드):**
- Create: `growing-skills/bin/dashboard.sh` — 생성기 (수집→집계→렌더).
- Create: `tests/test-dashboard.sh`.
- Create (마지막): `growing-skills/skill/dashboard/SKILL.md` — `/dashboard` 스킬.
- Modify: `growing-skills/install.sh`, `uninstall.sh`.

### 이벤트 로그 스키마 (`.lifecycle-events.jsonl`, Part 1 계약)

```json
{"ts":"2026-06-12T08:00:00Z","event":"promoted","skill":"x","reason":"사용자 승격","metadata":{}}
```
- event: `proposed|promoted|stale|archived|discarded|absorbed|restored|adopted|pinned|unpinned`
- reason: 사람이 읽는 한 문장. metadata: 선택(idle_days, into, source_session 등).

### 모델 JSON 스키마 (`dashboard.sh --json`, Part 2 계약)

```json
{
  "generated_at": "ISO",
  "thresholds": { "min_tools":15,"reviewer_gate_hours":24,"stale_days":30,"archive_days":90,
    "proposal_discard_days":60,"discarded_cleanup_days":14,"consolidate_min":8,
    "backups_retained":5,"reports_retained":12,"promote_budget_warn":15 },
  "summary": { "active":0,"stale":0,"archived":0,"agent_created":0,"user_created":0,"pinned":0,
    "proposals_pending":0,"proposals_discarded":0,"review_queue":0,
    "last_curator_run":null,"last_reviewer_run":null,"paused":false },
  "pipeline": { "queue":0,"proposals":0,"active":0,"stale":0,"archived":0,"absorbed":0 },
  "skills": [ { "name":"x","state":"active","created_by":"agent","use":0,
    "first_seen":null,"last_activity_at":null,"idle_days":null,"pinned":false,"managed":true,
    "days_to_stale":null,"days_to_archive":null,"absorbed_into":null } ],
  "events_by_day": [ { "date":"2026-06-11","count":5 } ],
  "lifecycle": [ { "ts":"ISO|null","date":"YYYY-MM-DD","event":"proposed","skill":"x",
    "reason":"...","metadata":{},"source":"log|backfill" } ]
}
```

---

# Part 1 — 캡처 레이어 (이유 데이터)

## Task 1: lifecycle-log.sh 헬퍼

**Files:**
- Create: `growing-skills/bin/lifecycle-log.sh`
- Create: `tests/test-lifecycle-log.sh`

- [ ] **Step 1: 실패 테스트 작성** — `tests/test-lifecycle-log.sh`

```bash
#!/bin/bash
# lifecycle-log.sh 단위 테스트. 실행: bash tests/test-lifecycle-log.sh
set -u
PKG="$(cd "$(dirname "$0")/.." && pwd)/growing-skills"
. "$PKG/bin/lifecycle-log.sh"
PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "PASS: $1"; else FAIL=$((FAIL+1)); echo "FAIL: $1 (exp [$2] got [$3])"; fi; }

SB=$(mktemp -d); export GROWING_SKILLS_ROOT="$SB"
F="$SB/.lifecycle-events.jsonl"
lifecycle_log "promoted" "alpha" "사용자 승격" '{"x":1}'
lifecycle_log "archived" "beta" "95일 미사용" '{"idle_days":95}'
assert_eq "two lines"  "2" "$(wc -l < "$F" | tr -d ' ')"
assert_eq "valid json" "ok" "$(jq -e . "$F" >/dev/null 2>&1 && echo ok || echo no)"
assert_eq "event"      "promoted" "$(sed -n 1p "$F" | jq -r .event)"
assert_eq "reason"     "95일 미사용" "$(sed -n 2p "$F" | jq -r .reason)"
assert_eq "meta"       "95" "$(sed -n 2p "$F" | jq -r .metadata.idle_days)"
# 비차단: 빈 event 무시, 호출자 중단 없음
lifecycle_log "" "x" "y"; echo "after-empty: 계속 실행됨"
assert_eq "empty ignored" "2" "$(wc -l < "$F" | tr -d ' ')"

echo "---"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: 실패 확인**

Run: `bash tests/test-lifecycle-log.sh`
Expected: FAIL — `lifecycle-log.sh: No such file` (source 실패).

- [ ] **Step 3: 구현** — `growing-skills/bin/lifecycle-log.sh`

```bash
#!/bin/bash
# growing-skills 라이프사이클 이벤트 로거. 각 프로듀서가 source 한다.
# 사용: lifecycle_log <event> <skill> <reason> [json_metadata]
# 비차단: jq 없거나 쓰기 실패해도 호출자를 멈추지 않음(항상 0 반환).
lifecycle_log() {
  local ev="${1:-}" sk="${2:-}" reason="${3:-}" meta="${4:-{}}"
  [ -n "$ev" ] || return 0
  local root="${GROWING_SKILLS_ROOT:-$HOME/.claude/skills}"
  local f="$root/.lifecycle-events.jsonl"
  command -v jq >/dev/null 2>&1 || return 0
  local ts; ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  jq -nc --arg ts "$ts" --arg ev "$ev" --arg sk "$sk" --arg r "$reason" --argjson m "$meta" \
    '{ts:$ts,event:$ev,skill:$sk,reason:$r,metadata:$m}' >> "$f" 2>/dev/null || true
  return 0
}
```

- [ ] **Step 4: 통과 확인**

Run: `bash tests/test-lifecycle-log.sh`
Expected: `PASS=6 FAIL=0`.

- [ ] **Step 5: 커밋**

```bash
git add growing-skills/bin/lifecycle-log.sh tests/test-lifecycle-log.sh
git commit -m "feat(lifecycle): append-only 이벤트 로거 헬퍼"
```

---

## Task 2: curator-pass.sh emit (stale/archive/discard/absorb)

**Files:**
- Modify: `growing-skills/bin/curator-pass.sh`
- Create: `tests/test-lifecycle-capture.sh`

- [ ] **Step 1: 실패 테스트 작성** — `tests/test-lifecycle-capture.sh`

```bash
#!/bin/bash
# 프로듀서 emit 통합 테스트. 실행: bash tests/test-lifecycle-capture.sh
set -u
PKG="$(cd "$(dirname "$0")/.." && pwd)/growing-skills"
PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "PASS: $1"; else FAIL=$((FAIL+1)); echo "FAIL: $1 (exp [$2] got [$3])"; fi; }
iso_days_ago() { date -j -u -v-"$1"d +%Y-%m-%dT%H:%M:%SZ; }
mk_skill() { mkdir -p "$1/$2"; printf -- "---\nname: %s\ncreated_by: agent\n---\nbody\n" "$2" > "$1/$2/SKILL.md"; }

# curator-pass: stale(40일) + archive(100일)
SB=$(mktemp -d); SK="$SB/skills"; mkdir -p "$SK"
mk_skill "$SK" old-a; mk_skill "$SK" old-b
jq -n --arg d40 "$(iso_days_ago 40)" --arg d100 "$(iso_days_ago 100)" '{skills:{
  "old-a":{use:1,created_by:"agent",state:"active",pinned:false,first_seen:$d40,last_activity_at:$d40},
  "old-b":{use:1,created_by:"agent",state:"active",pinned:false,first_seen:$d100,last_activity_at:$d100}
},compacted_at:null}' > "$SK/.usage.json"
GROWING_SKILLS_ROOT="$SK" GROWING_SKILLS_HOME="$PKG" bash "$PKG/bin/curator-pass.sh" >/dev/null 2>&1
LF="$SK/.lifecycle-events.jsonl"
assert_eq "stale emit"   "old-a" "$(jq -r 'select(.event=="stale").skill'    "$LF" 2>/dev/null | head -1)"
assert_eq "archive emit" "old-b" "$(jq -r 'select(.event=="archived").skill' "$LF" 2>/dev/null | head -1)"
assert_eq "archive reason" "ok" "$(jq -r 'select(.event=="archived").reason' "$LF" 2>/dev/null | grep -q 미사용 && echo ok || echo no)"

# dry-run: 이벤트 없음
SB2=$(mktemp -d); SK2="$SB2/skills"; mkdir -p "$SK2"; mk_skill "$SK2" old-c
jq -n --arg d100 "$(iso_days_ago 100)" '{skills:{"old-c":{use:1,created_by:"agent",state:"active",pinned:false,first_seen:$d100,last_activity_at:$d100}},compacted_at:null}' > "$SK2/.usage.json"
GROWING_SKILLS_ROOT="$SK2" GROWING_SKILLS_HOME="$PKG" bash "$PKG/bin/curator-pass.sh" --dry-run >/dev/null 2>&1
assert_eq "dry-run no emit" "0" "$([ -f "$SK2/.lifecycle-events.jsonl" ] && wc -l < "$SK2/.lifecycle-events.jsonl" | tr -d ' ' || echo 0)"

echo "---"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: 실패 확인**

Run: `bash tests/test-lifecycle-capture.sh`
Expected: FAIL — stale/archive emit (LF 없음).

- [ ] **Step 3: 구현 — curator-pass.sh 소싱 + emit 주입**

(a) 상단 헬퍼 정의부(`usage_write` 함수 정의 직후, 약 30행) 뒤에 source 추가:

```bash
LIB_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$LIB_DIR/lifecycle-log.sh" ]; then . "$LIB_DIR/lifecycle-log.sh"; else lifecycle_log() { :; }; fi
```

(b) archive 전이 — `usage_write '.skills[$n].state = "archived"' --arg n "$s"` (약 96행) **다음 줄**에 추가:

```bash
      lifecycle_log "archived" "$s" "${IDLE_DAYS}일 미사용" "{\"idle_days\":$IDLE_DAYS}"
```

(c) stale 전이 — `usage_write '.skills[$n].state = "stale"' --arg n "$s"` (약 101행) **다음 줄**에 추가:

```bash
      lifecycle_log "stale" "$s" "${IDLE_DAYS}일 미사용" "{\"idle_days\":$IDLE_DAYS}"
```

(d) 제안 폐기 — `[ "$DRY" -eq 0 ] && { mkdir -p "$PROPOSALS/.discarded"; mv "$d" "$PROPOSALS/.discarded/$PNAME"; touch "$PROPOSALS/.discarded/$PNAME"; }` (약 117행) **다음 줄**에 추가:

```bash
    [ "$DRY" -eq 0 ] && lifecycle_log "discarded" "$PNAME" "60일 초과 미승격" '{}'
```

(e) 우산 흡수 — `usage_write '.skills[$n] = ((.skills[$n] // {}) + {state:"archived", absorbed_into:$i})' --arg n "$FROM" --arg i "$INTO"` (약 181행) **다음 줄**에 추가:

```bash
        MV_REASON=$(printf '%s' "$mv_json" | jq -r '.reason // "통합"')
        lifecycle_log "absorbed" "$FROM" "$MV_REASON" "$(jq -nc --arg i "$INTO" '{into:$i}')"
```

- [ ] **Step 4: 통과 확인**

Run: `bash tests/test-lifecycle-capture.sh`
Expected: stale/archive/dry-run PASS.

- [ ] **Step 5: 회귀 확인 (기존 테스트 무손상)**

Run: `bash tests/test-curator-pass.sh`
Expected: 기존 케이스 전부 PASS (emit은 append-only라 비파괴).

- [ ] **Step 6: 커밋**

```bash
git add growing-skills/bin/curator-pass.sh tests/test-lifecycle-capture.sh
git commit -m "feat(lifecycle): curator-pass stale/archive/discard/absorb 이유 캡처"
```

---

## Task 3: curator-ctl.sh emit (promote/restore/adopt/pin)

**Files:**
- Modify: `growing-skills/bin/curator-ctl.sh`
- Modify: `tests/test-lifecycle-capture.sh`

- [ ] **Step 1: 실패 테스트 추가** — `test-lifecycle-capture.sh`의 `echo "---"` 위에 삽입

```bash
# curator-ctl promote
SB3=$(mktemp -d); SK3="$SB3/skills"; PR3="$SB3/proposals"; mkdir -p "$SK3" "$PR3/new-skill"
printf -- "---\nname: new-skill\ncreated_by: agent\nproposed_at: %s\n---\nx\n" "$(date +%Y-%m-%d)" > "$PR3/new-skill/SKILL.md"
printf '{"skills":{},"compacted_at":null}\n' > "$SK3/.usage.json"
GROWING_SKILLS_ROOT="$SK3" GROWING_SKILLS_PROPOSALS_DIR="$PR3" bash "$PKG/bin/curator-ctl.sh" promote new-skill >/dev/null 2>&1
assert_eq "promote emit" "new-skill" "$(jq -r 'select(.event=="promoted").skill' "$SK3/.lifecycle-events.jsonl" 2>/dev/null | head -1)"
# restore
mkdir -p "$SK3/.archive/gone"; printf -- "---\nname: gone\n---\nx\n" > "$SK3/.archive/gone/SKILL.md"
GROWING_SKILLS_ROOT="$SK3" GROWING_SKILLS_PROPOSALS_DIR="$PR3" bash "$PKG/bin/curator-ctl.sh" restore gone >/dev/null 2>&1
assert_eq "restore emit" "gone" "$(jq -r 'select(.event=="restored").skill' "$SK3/.lifecycle-events.jsonl" 2>/dev/null | head -1)"
```

- [ ] **Step 2: 실패 확인**

Run: `bash tests/test-lifecycle-capture.sh`
Expected: FAIL — promote/restore emit 없음.

- [ ] **Step 3: 구현 — curator-ctl.sh 소싱 + emit 주입**

(a) `state_set` 함수 정의 직후(약 22행) 뒤에 source 추가:

```bash
LIB_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$LIB_DIR/lifecycle-log.sh" ]; then . "$LIB_DIR/lifecycle-log.sh"; else lifecycle_log() { :; }; fi
```

(b) promote — `echo "승격 완료: $NAME ..."` (약 35행) **앞**(usage_set 다음)에 추가:

```bash
    lifecycle_log "promoted" "$NAME" "사용자 승격" '{}'
```

(c) pin/unpin — `echo "$CMD: $NAME"` (약 41행) **앞**에 추가:

```bash
    lifecycle_log "$CMD" "$NAME" "사용자 $([ "$CMD" = pin ] && echo 고정 || echo 고정해제)" '{}'
```

(d) restore — `echo "복원 완료: $NAME"` (약 55행) **앞**에 추가:

```bash
    lifecycle_log "restored" "$NAME" "아카이브에서 복원" '{}'
```

(e) adopt — `echo "수명 관리 옵트인: $NAME ..."` (약 61행) **앞**에 추가:

```bash
    lifecycle_log "adopted" "$NAME" "수명 관리 옵트인" '{}'
```

- [ ] **Step 4: 통과 확인**

Run: `bash tests/test-lifecycle-capture.sh`
Expected: promote/restore PASS.

- [ ] **Step 5: 회귀 확인**

Run: `bash tests/test-curator-ctl.sh`
Expected: 기존 케이스 전부 PASS.

- [ ] **Step 6: 커밋**

```bash
git add growing-skills/bin/curator-ctl.sh tests/test-lifecycle-capture.sh
git commit -m "feat(lifecycle): curator-ctl promote/restore/adopt/pin 캡처"
```

---

## Task 4: reviewer-prompt rationale + run-reviewer.sh proposed emit

**Files:**
- Modify: `growing-skills/prompts/reviewer-prompt.md`
- Modify: `growing-skills/bin/run-reviewer.sh`
- Modify: `tests/test-lifecycle-capture.sh`

- [ ] **Step 1: 실패 테스트 추가** — `test-lifecycle-capture.sh`의 `echo "---"` 위에 삽입

```bash
# run-reviewer proposed emit (claude 스텁이 rationale 포함 제안 작성)
SB4=$(mktemp -d); SK4="$SB4/skills"; PR4="$SB4/proposals"; STUB="$SB4/stub"
mkdir -p "$SK4/.review-queue" "$PR4" "$STUB"
printf 'digest content\n' > "$SK4/.review-queue/20260611-000000-x.md"
cat > "$STUB/claude" <<STUBEOF
#!/bin/bash
mkdir -p "$PR4/fixing-x"
printf -- "---\nname: fixing-x\ndescription: Use when...\ncreated_by: agent\nproposed_at: %s\nsource_session: sess-9\nrationale: git rebase 충돌을 반복 수동 해결함\n---\nproc\n" "\$(date +%Y-%m-%d)" > "$PR4/fixing-x/SKILL.md"
echo "리뷰 보고"
STUBEOF
chmod +x "$STUB/claude"
PATH="$STUB:$PATH" GROWING_SKILLS_FORCE=1 GROWING_SKILLS_ROOT="$SK4" GROWING_SKILLS_HOME="$PKG" GROWING_SKILLS_PROPOSALS_DIR="$PR4" bash "$PKG/bin/run-reviewer.sh" >/dev/null 2>&1
LF4="$SK4/.lifecycle-events.jsonl"
assert_eq "proposed emit"   "fixing-x" "$(jq -r 'select(.event=="proposed").skill' "$LF4" 2>/dev/null | head -1)"
assert_eq "proposed reason" "ok" "$(jq -r 'select(.event=="proposed").reason' "$LF4" 2>/dev/null | grep -q rebase && echo ok || echo no)"
```

- [ ] **Step 2: 실패 확인**

Run: `bash tests/test-lifecycle-capture.sh`
Expected: FAIL — proposed emit 없음.

- [ ] **Step 3a: reviewer-prompt.md에 rationale 지시 추가**

`prompts/reviewer-prompt.md`에서 `- frontmatter에 \`created_by: agent\`, \`proposed_at: <오늘 날짜>\`, \`source_session: <세션 ID>\` 필수` 줄 **다음 줄**에 추가:

```markdown
- `rationale: <왜 이 스킬을 제안하는가 — 어떤 반복 패턴 때문인지 한 문장>` 필수
```

- [ ] **Step 3b: run-reviewer.sh 소싱 + 스탬프 + proposed 감지**

(a) env 블록 끝(약 15행, `NOW=$(date +%s)` 다음) 뒤에 source 추가:

```bash
LIB_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$LIB_DIR/lifecycle-log.sh" ]; then . "$LIB_DIR/lifecycle-log.sh"; else lifecycle_log() { :; }; fi
```

(b) `REPORT="$REPORTS/$(date +%Y-%m-%d-%H%M%S).md"` (약 60행) **다음 줄**에 스탬프 추가:

```bash
LC_STAMP=$(mktemp); trap 'rm -f "$LOCK" "$BATCH" "$PICKED" "$LC_STAMP"' EXIT
```

(c) 성공 분기 — `while IFS= read -r f; do mv "$f" "$QUEUE/done/" 2>/dev/null; done < "$PICKED"` (약 71행) **다음 줄**에 감지·emit 추가:

```bash
  # 신규 제안 → proposed 이벤트 (rationale·source_session 사용)
  find "$PROPOSALS" -mindepth 2 -maxdepth 2 -name SKILL.md -newer "$LC_STAMP" \
       ! -path '*/.discarded/*' 2>/dev/null | while IFS= read -r p; do
    pn=$(basename "$(dirname "$p")")
    rat=$(sed -n 's/^rationale:[[:space:]]*//p' "$p" | head -1 | tr -d '"'\''')
    [ -n "$rat" ] || rat="리뷰어 배치에서 재사용 가능한 절차로 추출"
    ss=$(sed -n 's/^source_session:[[:space:]]*//p' "$p" | head -1)
    lifecycle_log "proposed" "$pn" "$rat" "$(jq -nc --arg s "$ss" '{source_session:$s}')"
  done
```

> 주의: (b)는 기존 44행의 `trap 'rm -f "$LOCK" "$BATCH" "$PICKED"' EXIT`를 대체/확장한다. 기존 trap 줄을 지우고 위 (b)를 BATCH/PICKED 생성(43행) 이후로 옮겨 한 번만 설정한다. 즉 43행 `BATCH=$(mktemp); PICKED=$(mktemp)` 다음에 `LC_STAMP=$(mktemp)` 추가하고 trap을 셋을 모두 포함하도록 한 줄로.

- [ ] **Step 4: 통과 확인**

Run: `bash tests/test-lifecycle-capture.sh`
Expected: proposed PASS (전체 PASS).

- [ ] **Step 5: 회귀 확인**

Run: `bash tests/test-run-reviewer.sh`
Expected: 기존 케이스 전부 PASS.

- [ ] **Step 6: 커밋**

```bash
git add growing-skills/prompts/reviewer-prompt.md growing-skills/bin/run-reviewer.sh tests/test-lifecycle-capture.sh
git commit -m "feat(lifecycle): 리뷰어 rationale + proposed 이벤트 캡처"
```

---

# Part 2 — 대시보드 (읽기·렌더)

## Task 5: 스크립트 골격 + 임계값 + `--json` 빈-환경

**Files:**
- Create: `growing-skills/bin/dashboard.sh`
- Create: `tests/test-dashboard.sh`

- [ ] **Step 1: 실패 테스트 작성** — `tests/test-dashboard.sh`

```bash
#!/bin/bash
# dashboard.sh 테스트. 실행: bash tests/test-dashboard.sh
set -u
PKG="$(cd "$(dirname "$0")/.." && pwd)/growing-skills"
RUN="$PKG/bin/dashboard.sh"
PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "PASS: $1"; else FAIL=$((FAIL+1)); echo "FAIL: $1 (exp [$2] got [$3])"; fi; }
assert_contains() { if printf '%s' "$2" | grep -qF "$3"; then PASS=$((PASS+1)); echo "PASS: $1"; else FAIL=$((FAIL+1)); echo "FAIL: $1 (missing [$3])"; fi; }
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

echo "---"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: 실패 확인**

Run: `bash tests/test-dashboard.sh`
Expected: FAIL — dashboard.sh 없음.

- [ ] **Step 3: 최소 구현** — `growing-skills/bin/dashboard.sh`

```bash
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
```

- [ ] **Step 4: 통과 확인**

Run: `chmod +x growing-skills/bin/dashboard.sh && bash tests/test-dashboard.sh`
Expected: `PASS=6 FAIL=0`.

- [ ] **Step 5: 커밋**

```bash
git add growing-skills/bin/dashboard.sh tests/test-dashboard.sh
git commit -m "feat(dashboard): 스크립트 골격 + 임계값 + --json 빈-환경"
```

---

## Task 6: 스킬 수집·머지 (디렉토리 + usage.json + archive)

**Files:**
- Modify: `growing-skills/bin/dashboard.sh`, `tests/test-dashboard.sh`

- [ ] **Step 1: 실패 테스트 추가** — `echo "---"` 위에 삽입

```bash
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
```

- [ ] **Step 2: 실패 확인**

Run: `bash tests/test-dashboard.sh` → FAIL (T2, skills 빈 배열).

- [ ] **Step 3: 구현**

`thresholds_json` 아래에 수집 헬퍼 추가:

```bash
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
```

`build_model`을 교체 (머지까지):

```bash
build_model() {
  local usage_skills dir_skills archived
  usage_skills=$([ -f "$USAGE" ] && jq '.skills // {}' "$USAGE" || echo '{}')
  dir_skills=$(dir_skills_json); archived=$(archived_json)
  jq -n --arg gen "$NOWISO" --argjson th "$(thresholds_json)" \
    --argjson usage "$usage_skills" --argjson dirs "$dir_skills" --argjson archived "$archived" '
    ($usage | to_entries | map({name:.key} + .value)) as $base
    | ($base | map(.name)) as $known
    | ($dirs | map(select(.name as $n | ($known|index($n))|not)
        | {name:.name, created_by:.created_by, use:0, state:"active",
           pinned:false, first_seen:null, last_activity_at:null})) as $extra
    | ($base + $extra)
    | map(if (.name as $n | $archived|index($n)) then .state="archived" else . end)
    | map({ name, state:(.state // "active"), created_by:(.created_by // "user"),
            use:(.use // 0), first_seen:(.first_seen // null),
            last_activity_at:(.last_activity_at // null), pinned:(.pinned // false),
            absorbed_into:(.absorbed_into // null), curated:(.curated // false) }) as $skills
    | { generated_at:$gen, thresholds:$th,
        summary:{active:0,stale:0,archived:0,agent_created:0,user_created:0,pinned:0,
                 proposals_pending:0,proposals_discarded:0,review_queue:0,
                 last_curator_run:null,last_reviewer_run:null,paused:false},
        pipeline:{queue:0,proposals:0,active:0,stale:0,archived:0,absorbed:0},
        skills:$skills, events_by_day:[], lifecycle:[] }'
}
```

- [ ] **Step 4: 통과 확인** — `bash tests/test-dashboard.sh` → T1·T2 PASS.

- [ ] **Step 5: 커밋**

```bash
git add growing-skills/bin/dashboard.sh tests/test-dashboard.sh
git commit -m "feat(dashboard): 스킬 디렉토리·usage·archive 머지"
```

---

## Task 7: 파생필드 + summary + pipeline + state

**Files:** Modify `dashboard.sh`, `tests/test-dashboard.sh`

- [ ] **Step 1: 실패 테스트 추가**

```bash
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
```

- [ ] **Step 2: 실패 확인** — `bash tests/test-dashboard.sh` → FAIL (T3).

- [ ] **Step 3: 구현**

`build_model` 시작부(지역변수 선언 다음)에 카운트 계산 추가:

```bash
  local pend disc queue cur_run rev_run paused
  pend=$(find "$PROPOSALS" -mindepth 1 -maxdepth 1 -type d ! -name '.*' 2>/dev/null | while read -r d; do [ -f "$d/SKILL.md" ] && echo x; done | wc -l | tr -d ' ')
  disc=$(find "$PROPOSALS/.discarded" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  queue=$(find "$SKILLS_ROOT/.review-queue" -mindepth 1 -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  cur_run=$([ -f "$SKILLS_ROOT/.curator_state" ] && jq -r '.last_run_at // empty' "$SKILLS_ROOT/.curator_state" 2>/dev/null || true)
  rev_run=$([ -f "$SKILLS_ROOT/.reviewer_state" ] && jq -r '.last_run_at // empty' "$SKILLS_ROOT/.reviewer_state" 2>/dev/null || true)
  paused=$([ -f "$SKILLS_ROOT/.curator_state" ] && jq -r '.paused // false' "$SKILLS_ROOT/.curator_state" 2>/dev/null || echo false)
  [ -n "$cur_run" ] || cur_run=null; [ -n "$rev_run" ] || rev_run=null
```

`jq -n` 인자에 추가:

```bash
    --argjson now "$NOW" --argjson pend "$pend" --argjson disc "$disc" --argjson queue "$queue" \
    --argjson cur "$cur_run" --argjson rev "$rev_run" --argjson paused "$paused" \
```

`map({name, state:...}) as $skills` 다음을 교체 (파생 + summary + pipeline):

```bash
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
        skills:$skills2, events_by_day:[], lifecycle:[] }
```

> 기존 `| { generated_at:$gen ... skills:$skills, events_by_day:[], lifecycle:[] }` 블록 전체를 위로 대체. `$skills` → `$skills2`.

- [ ] **Step 4: 통과 확인** — T1~T3 PASS.

- [ ] **Step 5: 커밋**

```bash
git add growing-skills/bin/dashboard.sh tests/test-dashboard.sh
git commit -m "feat(dashboard): 파생필드·summary·pipeline·state 집계"
```

---

## Task 8: events_by_day + 통합 lifecycle (로그 + 백필)

**Files:** Modify `dashboard.sh`, `tests/test-dashboard.sh`

- [ ] **Step 1: 실패 테스트 추가**

```bash
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
```

- [ ] **Step 2: 실패 확인** — FAIL (events_by_day/lifecycle 빈 배열).

- [ ] **Step 3: 구현**

`build_model` 위에 헬퍼 추가:

```bash
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
```

`build_model`의 `jq -n` 인자에 추가: `--argjson events "$(events_by_day_json)" --argjson lifecycle "$(lifecycle_json)"`. 출력의 `events_by_day:[], lifecycle:[]` → `events_by_day:$events, lifecycle:$lifecycle`.

- [ ] **Step 4: 통과 확인** — T1~T4 PASS.

- [ ] **Step 5: 커밋**

```bash
git add growing-skills/bin/dashboard.sh tests/test-dashboard.sh
git commit -m "feat(dashboard): events_by_day + 통합 lifecycle(로그+백필)"
```

---

## Task 9: HTML 셸 + CSS 팔레트 + W1 요약 + W8 기준

**Files:** Modify `dashboard.sh`, `tests/test-dashboard.sh`

- [ ] **Step 1: 실패 테스트 추가**

```bash
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
```

- [ ] **Step 2: 실패 확인** — FAIL (render 미구현 → 빈 출력).

- [ ] **Step 3: 구현** — `render_html` 추가 + case 교체 (Spec §5 팔레트)

`case "$MODE"` 위에 `render_html` 함수 추가. CSS·셸·W1·W8 포함:

```bash
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
```

`case "$MODE"` 교체:

```bash
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
```

> `--open`은 생성 후 시스템 기본 브라우저로 즉시 연다 (macOS `open`, 리눅스 `xdg-open` 폴백). 사용자 요청 "대시보드 여는 명령어".

- [ ] **Step 4: 통과 확인** — T1~T5 PASS.

- [ ] **Step 5: 커밋**

```bash
git add growing-skills/bin/dashboard.sh tests/test-dashboard.sh
git commit -m "feat(dashboard): HTML 셸·팔레트·요약카드·기준패널"
```

---

## Task 10: W2 파이프라인 + W5 스킬표(정렬) + W6 노화

**Files:** Modify `dashboard.sh`, `tests/test-dashboard.sh`

- [ ] **Step 1: 실패 테스트 추가**

```bash
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
```

- [ ] **Step 2: 실패 확인** — FAIL.

- [ ] **Step 3: 구현**

`render_html`의 `thresholds_rows` 다음에 세 조각 추가:

```bash
  local pipeline rows aging
  pipeline=$(printf '%s' "$model" | jq -r '.pipeline as $p |
    [{l:"리뷰 큐",n:$p.queue},{l:"제안",n:$p.proposals},{l:"활성",n:$p.active},{l:"stale",n:$p.stale},{l:"아카이브",n:$p.archived}]
    | map("<span class=\"pill\"><b>\(.n)</b> \(.l)</span>")|join("<span class=\"arrow\">→</span>")')
  rows=$(printf '%s' "$model" | jq -r '.skills | sort_by(-.use) | map(
    "<tr><td>\(.name)</td><td><span class=\"badge \(.state)\">\(.state)</span></td>"
    + "<td>\(.created_by)</td><td>\(.use)</td><td>\(.idle_days // "—")</td>"
    + "<td>\(if .managed and .days_to_stale!=null then (.days_to_stale|tostring) else "—" end)</td>"
    + "<td>\(if .pinned then "📌" else "" end)</td></tr>")|join("")')
  aging=$(printf '%s' "$model" | jq -r '
    (.skills | map(select(.managed and .idle_days!=null)) | sort_by(-.idle_days)) as $a
    | if ($a|length)==0 then "<div class=\"empty\">관리 대상 노화 데이터 없음</div>"
      else ($a | map((if .idle_days>90 then 100 else (.idle_days/90*100) end) as $w
        | (if .idle_days>=90 then "var(--danger)" elif .idle_days>=30 then "var(--warn)" else "var(--accent)" end) as $c
        | "<div style=\"margin:6px 0\"><div class=\"sub\">\(.name) · 유휴 \(.idle_days)일</div>"
        + "<div style=\"background:var(--surface2);border-radius:4px;height:10px\">"
        + "<div style=\"width:\($w)%;height:10px;border-radius:4px;background:\($c)\"></div></div></div>")|join("")) end')
```

템플릿 마커 교체:
- `<!-- W2_PIPELINE -->` → `<h2>라이프사이클 파이프라인</h2><div class="flow">$pipeline</div>`
- `<!-- W5_TABLE -->` → `<h2>스킬 목록 / 성장</h2><table id="skills"><thead><tr><th onclick="sortTable(0)">이름</th><th onclick="sortTable(1)">상태</th><th onclick="sortTable(2)">생성</th><th onclick="sortTable(3)">use</th><th onclick="sortTable(4)">유휴(일)</th><th onclick="sortTable(5)">stale까지</th><th>pin</th></tr></thead><tbody>$rows</tbody></table>`
- `<!-- W6_AGING -->` → `<h2>삭제 위험 / 노화</h2>$aging`

`</body>` 직전에 정렬 JS 추가:

```html
<script>
function sortTable(c){var t=document.getElementById('skills'),b=t.tBodies[0],r=[].slice.call(b.rows);
var asc=t.getAttribute('data-c')==c&&t.getAttribute('data-d')!='1';
r.sort(function(x,y){var a=x.cells[c].innerText,z=y.cells[c].innerText;var na=parseFloat(a),nz=parseFloat(z);
if(!isNaN(na)&&!isNaN(nz)){a=na;z=nz;}return (a>z?1:a<z?-1:0)*(asc?1:-1);});
r.forEach(function(x){b.appendChild(x);});t.setAttribute('data-c',c);t.setAttribute('data-d',asc?'1':'0');}
</script>
```

- [ ] **Step 4: 통과 확인** — T1~T6 PASS.

- [ ] **Step 5: 커밋**

```bash
git add growing-skills/bin/dashboard.sh tests/test-dashboard.sh
git commit -m "feat(dashboard): 파이프라인·스킬표(정렬)·노화 뷰"
```

---

## Task 11: W3 히트맵 + W4 막대 + W7 이유 피드 + W9 일대기

**Files:** Modify `dashboard.sh`, `tests/test-dashboard.sh`

- [ ] **Step 1: 실패 테스트 추가**

```bash
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
```

- [ ] **Step 2: 실패 확인** — FAIL.

- [ ] **Step 3: 구현**

`render_html` 위에 SVG 빌더 추가:

```bash
build_heatmap_svg() {  # $1 = model json
  local model="$1" cell=12 gap=3 max counts
  max=$(printf '%s' "$model" | jq -r '[.events_by_day[].count] | max // 1')
  [ "$max" -gt 0 ] 2>/dev/null || max=1
  counts=$(printf '%s' "$model" | jq -r '.events_by_day[] | "\(.date) \(.count)"')
  get_count() { printf '%s\n' "$counts" | awk -v d="$1" '$1==d{print $2;f=1} END{if(!f)print 0}'; }
  local svg_w=$(( 26*(cell+gap) )) svg_h=$(( 7*(cell+gap) )) i d c col row x y lvl
  printf '<svg width="%d" height="%d" role="img">' "$svg_w" "$svg_h"
  for i in $(seq 181 -1 0); do
    d=$(date -u -v-"${i}"d +%Y-%m-%d); c=$(get_count "$d")
    col=$(( (181 - i) / 7 )); row=$(date -u -v-"${i}"d +%w)
    x=$(( col*(cell+gap) )); y=$(( row*(cell+gap) ))
    if [ "$c" -le 0 ] 2>/dev/null; then lvl=0
    elif [ "$c" -ge "$max" ] 2>/dev/null; then lvl=4
    else lvl=$(( c*4/max )); [ "$lvl" -lt 1 ] && lvl=1; fi
    printf '<rect x="%d" y="%d" width="%d" height="%d" rx="2" fill="var(--hm%d)"><title>%s: %s</title></rect>' \
      "$x" "$y" "$cell" "$cell" "$lvl" "$d" "$c"
  done
  printf '</svg>'
}
```

`render_html` 안 (aging 다음)에 추가:

```bash
  local heatmap bars feed provenance
  heatmap=$(build_heatmap_svg "$model")
  bars=$(printf '%s' "$model" | jq -r '(.events_by_day | sort_by(.date))[-30:] as $d
    | ($d | map(.count) | max // 1) as $mx
    | if ($d|length)==0 then "<div class=\"empty\">활동 데이터 없음</div>"
      else "<div class=\"bars\">" + ($d | map("<div class=\"b\" style=\"height:\((.count/$mx*100)|floor)%\" title=\"\(.date): \(.count)\"></div>")|join("")) + "</div>" end')
  feed=$(printf '%s' "$model" | jq -r 'if (.lifecycle|length)==0 then "<div class=\"empty\">라이프사이클 기록 없음</div>"
    else (.lifecycle[0:60] | map(
      "<tr><td class=\"sub\">\(.date)</td><td><span class=\"badge \(if .event==\"archived\" or .event==\"discarded\" then \"archived\" elif .event==\"stale\" then \"stale\" else \"active\" end)\">\(.event)</span></td>"
      + "<td>\(.skill)</td><td class=\"sub\">\(.reason)</td></tr>")|join(""))
      | "<table><thead><tr><th>날짜</th><th>이벤트</th><th>스킬</th><th>이유</th></tr></thead><tbody>" + . + "</tbody></table>" end')
  # W9 일대기: 스킬별 이벤트 그룹 + use/first_seen
  provenance=$(printf '%s' "$model" | jq -r '
    (.skills | map({key:.name, value:{use:.use, first_seen:.first_seen, state:.state}}) | from_entries) as $meta
    | (.lifecycle | group_by(.skill)) as $g
    | if ($g|length)==0 then "<div class=\"empty\">이유 이벤트가 아직 없습니다 (시스템이 돌면 채워집니다)</div>"
      else ($g | map(. as $evs | $evs[0].skill as $nm
        | "<details><summary><b>\($nm)</b> <span class=\"sub\">use \($meta[$nm].use // 0) · 상태 \($meta[$nm].state // "?")</span></summary>"
        + ($evs | sort_by(.date) | map("<div class=\"ev\"><span class=\"sub\">\(.date)</span> · <b>\(.event)</b> — \(.reason)</div>")|join(""))
        + "</details>")|join("")) end')
```

템플릿 마커 교체:
- `<!-- W3_HEATMAP -->` → `<h2>활동 히트맵</h2><div class="card" style="overflow-x:auto">$heatmap</div>`
- `<!-- W4_BARS -->` → `<h2>일별 활동</h2>$bars`
- `<!-- W7_FEED -->` → `<h2>라이프사이클 / 이유 피드</h2>$feed`
- `<!-- W9_PROVENANCE -->` → `<h2>스킬 일대기 (왜 태어나고·자라고·사라졌나)</h2>$provenance`

- [ ] **Step 4: 통과 확인** — T1~T7 PASS.

- [ ] **Step 5: 커밋**

```bash
git add growing-skills/bin/dashboard.sh tests/test-dashboard.sh
git commit -m "feat(dashboard): SVG 히트맵·일별 막대·이유 피드·스킬 일대기"
```

---

## Task 12: 실데이터 통합 + install/uninstall 연동

**Files:** Modify `install.sh`, `uninstall.sh`, `tests/test-dashboard.sh`

- [ ] **Step 1: 통합 스모크 테스트 추가**

```bash
# T8: 실제 ~/.claude 데이터로 모델 생성
SMOKE=$(bash "$RUN" --json 2>/dev/null | jq -e '.generated_at and (.skills|type=="array") and (.lifecycle|type=="array")' >/dev/null 2>&1 && echo ok || echo no)
assert_eq "T8 real-data ok" "ok" "$SMOKE"
```

- [ ] **Step 2: 확인** — `bash tests/test-dashboard.sh` → 전체 PASS.

- [ ] **Step 3: 실데이터 HTML 육안 (수동, /verify에서)**

Run: `bash growing-skills/bin/dashboard.sh --open`
Expected: 브라우저가 열리고 9개 섹션 표시. 빈 섹션은 빈-상태 문구.

- [ ] **Step 4: install/uninstall 연동**

`install.sh`의 bin 복사 블록 확인. `cp "$PKG/bin/"*.sh ...` 와일드카드면 `dashboard.sh`·`lifecycle-log.sh` 자동 포함 — **확인만**. 개별 복사면 두 줄 추가:

```bash
cp "$PKG/bin/dashboard.sh" "$GS_BIN/dashboard.sh" && chmod +x "$GS_BIN/dashboard.sh"
cp "$PKG/bin/lifecycle-log.sh" "$GS_BIN/lifecycle-log.sh"
```

`uninstall.sh` 대응 (와일드카드 제거면 확인만):

```bash
rm -f "$GS_BIN/dashboard.sh" "$GS_BIN/lifecycle-log.sh"
```

> 수정된 `curator-pass.sh`·`curator-ctl.sh`·`run-reviewer.sh`·`reviewer-prompt.md`는 기존 복사 경로로 자동 반영됨 (새 파일 아님).

- [ ] **Step 5: idempotency 확인**

Run: `bash growing-skills/install.sh && bash growing-skills/install.sh && ls ~/.claude/growing-skills/bin/dashboard.sh ~/.claude/growing-skills/bin/lifecycle-log.sh`
Expected: 두 번 실행해도 에러 없이 두 파일 존재.

- [ ] **Step 6: 커밋**

```bash
git add growing-skills/install.sh growing-skills/uninstall.sh tests/test-dashboard.sh
git commit -m "feat(dashboard): 실데이터 스모크 + install/uninstall 연동"
```

---

## Task 13 (선택, 마지막): `/dashboard` 슬래시 스킬

**Files:** Create `growing-skills/skill/dashboard/SKILL.md`, Modify `install.sh`/`uninstall.sh`

- [ ] **Step 1: SKILL.md 작성**

```markdown
---
name: dashboard
description: Use when the user runs /dashboard or asks to see the growing-skills dashboard, skill growth/lifecycle visualization, activity heatmap, why skills were created/grown/deleted, or skill stats.
created_by: user
---

# Growing Skills Dashboard

사용자가 growing-skills의 성장·생성·삭제·판정 과정과 그 *이유*를 시각적으로 보려 할 때.

## 절차

1. 생성 후 즉시 열기: `bash ~/.claude/growing-skills/bin/dashboard.sh --open`
2. 생성만 하려면 인자 없이 실행 — 경로(`~/.claude/skills/.dashboard/index.html`)만 출력된다.
3. 자동 새로고침 없음 — 최신화하려면 1단계 재실행.

서버로 보려면 `dashboard.sh --serve` (python3 필요, http://localhost:8777).
```

- [ ] **Step 2: install.sh에 스킬 설치 추가**

기존 `/curator` 스킬 설치 줄 근처에:

```bash
mkdir -p "$HOME/.claude/skills/dashboard"
cp "$PKG/skill/dashboard/SKILL.md" "$HOME/.claude/skills/dashboard/SKILL.md"
```

`uninstall.sh`:

```bash
rm -rf "$HOME/.claude/skills/dashboard"
```

- [ ] **Step 3: 확인**

Run: `bash growing-skills/install.sh && head -3 ~/.claude/skills/dashboard/SKILL.md`
Expected: `name: dashboard` 출력.

- [ ] **Step 4: 커밋**

```bash
git add growing-skills/skill/dashboard/SKILL.md growing-skills/install.sh growing-skills/uninstall.sh
git commit -m "feat(dashboard): /dashboard 슬래시 스킬 + 설치 연동"
```

---

## Self-Review 메모

- **스펙 커버리지:** 캡처(§4b) → Task 1~4. 위젯 W1~W9 → Task 9~11. 백필(로그+리포트+제안, 로그 우선) → Task 8. 머지/파생/요약 → Task 6~7. 설치 → Task 12. 스킬 → Task 13.
- **이유 데이터 요구 직대응:** "왜 생성/성장/삭제됐나"가 `.lifecycle-events.jsonl`로 캡처(Task 2~4)되고 W7 피드·W9 일대기로 표시(Task 11). 과거는 백필.
- **타입 일관성:** 이벤트 스키마(event/reason/metadata)와 모델 스키마(lifecycle[].source 등) 전 태스크 동일. `--render-stdin`으로 모델→HTML 테스트.
- **비파괴 검증:** 각 프로듀서 수정 후 기존 테스트 회귀 실행(Task 2·3·4 Step 5). 캡처는 append-only.
- **주의점:** macOS `date -v`/`%w`, jq 1.8.1+ `strptime`/`mktime` 의존(스펙 명시). 프로듀서 line 번호는 근사 — 실제 코드 라인(인용된 명령)으로 앵커링.
- **YAGNI:** 라이브서버·다중테마·플러그인 제외. Task 13 선택.
