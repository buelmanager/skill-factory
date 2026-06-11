# growing-skills Phase 3 (큐레이터 + 컨트롤) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 성장 루프의 마지막 절반 — 주간 큐레이터(수명 전이·우산 통합·제안 폐기)와 `/curator` 컨트롤 서피스(승격 게이트 포함) — 를 구현·배포한다.

**Architecture:** SessionStart 훅(완전 무음)이 7일 경과 시 `curator-pass.sh`를 detach 스폰. 패스 = 이벤트 컴팩션(`compact-events.sh` → `.usage.json`) → agent 스킬 스냅샷 → 결정론적 수명 전이(30d stale / 90d `.archive/` mv) → 60일 제안 폐기 → (agent 스킬 8개+) LLM 우산 통합(스테이징+`moves.json` 매니페스트, 스크립트가 검증·적용) → REPORT. `/curator` 글로벌 스킬이 `curator-ctl.sh`(status/promote/pin/pause/restore/adopt/rollback)를 구동하며, **승격 게이트**(`/curator review`)에서만 제안이 실스킬이 된다. 스펙: §4 Layer 4·5, §5.

**Tech Stack:** bash(macOS 3.2, BSD date `-j -f` 사용), jq 1.8.1, tar, Claude Code hooks/headless.

**Phase 1·2에서 확정된 사실 (재사용):** 점-디렉터리 디스커버리 불가시 / `env -u ANTHROPIC_API_KEY` / `GROWING_SKILLS_BG=1` / `--settings` hooks 오버라이드 / `//` 절대 경로 권한 / noclobber 원자 락 / write-ahead 스탬프 / detach `nohup &` 생존 실증. **신규 주의 2건:** ① SessionStart 훅 stdout은 컨텍스트 주입 → 훅 첫 줄에서 `exec >/dev/null 2>&1`. ② LLM 통합의 쓰기 권한을 skills 전체로 열면 사용자 스킬 노출 → LLM은 `.curator_staging/`에만 쓰고 스크립트가 검증 후 반영.

**파일 구조 (Phase 3 추가):**
```
growing-skills/
├── hooks/session-start-curator.sh   # 7일 게이트 + detach 스폰 (완전 무음)
├── bin/compact-events.sh            # 이벤트 JSONL → .usage.json 컴팩션·로테이션
├── bin/curator-ctl.sh               # status|promote|pin|unpin|pause|resume|restore|adopt|rollback
├── bin/curator-pass.sh              # 주간 패스 본체 (--dry-run 지원)
├── prompts/curator-prompt.md        # LLM 우산 통합 프롬프트 (moves.json 계약)
├── skill/SKILL.md                   # /curator 글로벌 스킬 (설치 시 ~/.claude/skills/curator/)
├── install.sh / uninstall.sh        # 확장
tests/
├── test-compact-events.sh
├── test-curator-ctl.sh
├── test-curator-pass.sh
└── test-curator-hook.sh
```

**런타임 상태 (~/.claude/skills/ 아래):** `.usage.json`(스킬별 `{use, last_activity_at, first_seen, created_by, state, pinned, curated}`) · `.curator_state`(`{"last_run_at": epoch, "paused": bool}`) · `.curator.lock` · `.archive/<name>/` · `.curator_backups/*.tar.gz`(5개) · `.curator_staging/` · `.curator_reports/`(12개) · `skill-proposals/.discarded/`(14일)

**공통 헬퍼 (여러 스크립트에서 반복되는 BSD date 변환):** ISO→epoch는 `date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$TS" +%s 2>/dev/null`을 쓴다 (macOS 전용 `-j`).

---

### Task 1: compact-events.sh (TDD)

**Files:**
- Create: `tests/test-compact-events.sh`
- Create: `growing-skills/bin/compact-events.sh`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test-compact-events.sh`:

```bash
#!/bin/bash
# compact-events.sh 테스트. 실행: bash tests/test-compact-events.sh
set -u
BIN="$(cd "$(dirname "$0")/.." && pwd)/growing-skills/bin/compact-events.sh"
PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "PASS: $1"; else FAIL=$((FAIL+1)); echo "FAIL: $1 (expected [$2] got [$3])"; fi; }

setup() { SK=$(mktemp -d); EV="$SK/.usage-events.jsonl"; US="$SK/.usage.json"; }
teardown() { rm -rf "$SK"; }
run_compact() { GROWING_SKILLS_ROOT="$SK" bash "$BIN"; }

# T1: 신규 스킬 이벤트 → created_by:user 기본으로 등록, use 집계, last_activity 기록
setup
printf '{"ts":"2026-06-10T01:00:00Z","skill":"alpha","event":"use","session":"s1"}\n{"ts":"2026-06-11T02:00:00Z","skill":"alpha","event":"use","session":"s2"}\n{"ts":"2026-06-11T03:00:00Z","skill":"beta","event":"use","session":"s2"}\n' > "$EV"
run_compact
assert_eq "T1 exit 0" "0" "$?"
assert_eq "T1 alpha use" "2" "$(jq -r '.skills.alpha.use' "$US")"
assert_eq "T1 alpha last" "2026-06-11T02:00:00Z" "$(jq -r '.skills.alpha.last_activity_at' "$US")"
assert_eq "T1 alpha created_by" "user" "$(jq -r '.skills.alpha.created_by' "$US")"
assert_eq "T1 beta registered" "1" "$(jq -r '.skills.beta.use' "$US")"
assert_eq "T1 events rotated" "no" "$([ -f "$EV" ] && echo yes || echo no)"
teardown

# T2: 기존 사이드카에 누적 + stale 부활 + agent 필드 보존
setup
printf '{"skills":{"alpha":{"use":5,"last_activity_at":"2026-01-01T00:00:00Z","first_seen":"2026-01-01T00:00:00Z","created_by":"agent","state":"stale","pinned":true}},"compacted_at":null}\n' > "$US"
printf '{"ts":"2026-06-11T01:00:00Z","skill":"alpha","event":"use","session":"s"}\n' > "$EV"
run_compact
assert_eq "T2 use accumulated" "6" "$(jq -r '.skills.alpha.use' "$US")"
assert_eq "T2 stale revived" "active" "$(jq -r '.skills.alpha.state' "$US")"
assert_eq "T2 created_by preserved" "agent" "$(jq -r '.skills.alpha.created_by' "$US")"
assert_eq "T2 pinned preserved" "true" "$(jq -r '.skills.alpha.pinned' "$US")"
teardown

# T3: 깨진 이벤트 라인 → 정상 라인만 반영, 실패하지 않음
setup
printf '{"ts":"2026-06-11T01:00:00Z","skill":"alpha","event":"use","session":"s"}\nnot-json{{{\n{"ts":"2026-06-11T02:00:00Z","skill":"alpha","event":"use","session":"s"}\n' > "$EV"
run_compact
assert_eq "T3 exit 0" "0" "$?"
assert_eq "T3 valid lines counted" "2" "$(jq -r '.skills.alpha.use' "$US")"
teardown

# T4: 이벤트 없음 → 무변경, exit 0
setup
printf '{"skills":{},"compacted_at":null}\n' > "$US"
run_compact
assert_eq "T4 exit 0" "0" "$?"
assert_eq "T4 usage intact" "{}" "$(jq -c '.skills' "$US")"
teardown

echo "----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: 실행 — 실패 확인** — Run: `bash tests/test-compact-events.sh` / Expected: FAIL

- [ ] **Step 3: 구현**

`growing-skills/bin/compact-events.sh`:

```bash
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
[ -s "$EVENTS" ] || exit 0

PROC="$EVENTS.processing"
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
```

Run: `chmod +x growing-skills/bin/compact-events.sh`

- [ ] **Step 4: 통과 확인** — Run: `bash tests/test-compact-events.sh` / Expected: `PASS=13 FAIL=0`
- [ ] **Step 5: 커밋** — `git add tests/test-compact-events.sh growing-skills/bin/compact-events.sh && git commit -m "feat(growing-skills): 이벤트 컴팩션 — .usage.json 갱신·로테이션·유실 방지"`

---

### Task 2: curator-ctl.sh (TDD)

**Files:**
- Create: `tests/test-curator-ctl.sh`
- Create: `growing-skills/bin/curator-ctl.sh`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test-curator-ctl.sh`:

```bash
#!/bin/bash
# curator-ctl.sh 테스트. 실행: bash tests/test-curator-ctl.sh
set -u
BIN="$(cd "$(dirname "$0")/.." && pwd)/growing-skills/bin/curator-ctl.sh"
PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "PASS: $1"; else FAIL=$((FAIL+1)); echo "FAIL: $1 (expected [$2] got [$3])"; fi; }

setup() {
  SK=$(mktemp -d); PR=$(mktemp -d)
  US="$SK/.usage.json"; ST="$SK/.curator_state"
  printf '{"skills":{},"compacted_at":null}\n' > "$US"
  mkdir -p "$PR/new-skill"
  printf -- "---\nname: new-skill\ndescription: Use when testing promote\ncreated_by: agent\n---\nbody\n" > "$PR/new-skill/SKILL.md"
}
teardown() { rm -rf "$SK" "$PR"; }
ctl() { GROWING_SKILLS_ROOT="$SK" GROWING_SKILLS_PROPOSALS_DIR="$PR" bash "$BIN" "$@"; }

# T1: promote — 제안을 skills로 이동 + 사이드카 created_by:agent 등록
setup
ctl promote new-skill >/dev/null
assert_eq "T1 moved" "yes" "$([ -f "$SK/new-skill/SKILL.md" ] && echo yes || echo no)"
assert_eq "T1 proposal gone" "no" "$([ -d "$PR/new-skill" ] && echo yes || echo no)"
assert_eq "T1 sidecar agent" "agent" "$(jq -r '.skills["new-skill"].created_by' "$US")"
assert_eq "T1 sidecar active" "active" "$(jq -r '.skills["new-skill"].state' "$US")"

# T2: promote 중복 → 오류, 비파괴
ctl promote new-skill >/dev/null 2>&1
assert_eq "T2 dup rejected" "1" "$?"

# T3: pin / unpin
ctl pin new-skill >/dev/null
assert_eq "T3 pinned" "true" "$(jq -r '.skills["new-skill"].pinned' "$US")"
ctl unpin new-skill >/dev/null
assert_eq "T3 unpinned" "false" "$(jq -r '.skills["new-skill"].pinned' "$US")"

# T4: pause / resume
ctl pause >/dev/null
assert_eq "T4 paused" "true" "$(jq -r '.paused' "$ST")"
ctl resume >/dev/null
assert_eq "T4 resumed" "false" "$(jq -r '.paused' "$ST")"

# T5: restore — .archive에서 복원 + state active
mkdir -p "$SK/.archive/old-skill"
printf -- "---\nname: old-skill\ndescription: t\n---\n" > "$SK/.archive/old-skill/SKILL.md"
jq '.skills["old-skill"] = {use:1, created_by:"agent", state:"archived", pinned:false}' "$US" > "$US.tmp" && mv "$US.tmp" "$US"
ctl restore old-skill >/dev/null
assert_eq "T5 restored" "yes" "$([ -f "$SK/old-skill/SKILL.md" ] && echo yes || echo no)"
assert_eq "T5 state active" "active" "$(jq -r '.skills["old-skill"].state' "$US")"

# T6: adopt — 사용자 스킬 수명 관리 옵트인 (curated 플래그)
mkdir -p "$SK/user-skill"
printf -- "---\nname: user-skill\ndescription: t\n---\n" > "$SK/user-skill/SKILL.md"
ctl adopt user-skill >/dev/null
assert_eq "T6 curated" "true" "$(jq -r '.skills["user-skill"].curated' "$US")"
assert_eq "T6 still user" "user" "$(jq -r '.skills["user-skill"].created_by' "$US")"

# T7: status — 핵심 수치 출력
OUT=$(ctl status)
assert_eq "T7 has agent count" "1" "$(printf '%s' "$OUT" | grep -c "agent 스킬:")"
assert_eq "T7 has proposals" "1" "$(printf '%s' "$OUT" | grep -c "대기 제안:")"
teardown

echo "----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: 실행 — 실패 확인** — Run: `bash tests/test-curator-ctl.sh` / Expected: FAIL

- [ ] **Step 3: 구현**

`growing-skills/bin/curator-ctl.sh`:

```bash
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
```

Run: `chmod +x growing-skills/bin/curator-ctl.sh`

- [ ] **Step 4: 통과 확인** — Run: `bash tests/test-curator-ctl.sh` / Expected: `PASS=15 FAIL=0` (assert 수를 직접 세어 확정; FAIL=0이 합격 기준)
- [ ] **Step 5: 커밋** — `git add tests/test-curator-ctl.sh growing-skills/bin/curator-ctl.sh && git commit -m "feat(growing-skills): curator-ctl — 승격·pin·pause·restore·adopt·status·rollback"`

---

### Task 3: curator-pass.sh + curator-prompt.md (TDD, claude 스텁)

**Files:**
- Create: `growing-skills/prompts/curator-prompt.md`
- Create: `tests/test-curator-pass.sh`
- Create: `growing-skills/bin/curator-pass.sh`

- [ ] **Step 1: 프롬프트 작성**

`growing-skills/prompts/curator-prompt.md` (전문):

```markdown
# growing-skills 큐레이터 — 우산 통합 패스

너는 growing-skills의 큐레이터다. stdin으로 agent 생성 스킬들의 전체 내용이 주어진다 (`=== SKILL: <name> ===` 헤더로 구분, 각 스킬의 사용 통계 포함).

## 임무

좁은 단일-세션 스킬들이 같은 도메인 클러스터를 이루면 **클래스 수준 우산 스킬**로 통합한다. 라이브러리는 커지는 게 아니라 좋아져야 한다: 좁은 스킬 다수 → 풍부한 스킬 소수.

## 규칙

- 통합 가치가 있는 클러스터(2개 이상, 같은 도메인·도구·문제군)만 다룬다. 억지로 묶지 않는다 — 클러스터가 없으면 moves를 빈 배열로 내라.
- 우산 스킬은 흡수되는 스킬들의 **실질 내용을 보존**해야 한다 (요약으로 정보를 잃지 말 것). 섹션으로 구조화하라.
- pinned 스킬은 입력에 포함되지 않는다. 입력에 없는 스킬을 moves에 넣지 마라.
- name 규칙: 소문자·숫자·하이픈, 동사형(-ing) 선호. description은 "Use when..."으로 발동 조건만.
- 자격증명·시크릿 금지.

## 산출 계약 (스테이징 디렉터리에만 쓴다 — [환경] 참조)

1. 각 우산 스킬: `<staging>/<umbrella-name>/SKILL.md` (frontmatter: name, description, created_by: agent)
2. 매니페스트: `<staging>/moves.json` — 반드시 이 스키마:
   `{"moves": [{"from": "<흡수될 스킬명>", "into": "<우산명>", "reason": "<1줄>"}], "summary": "<전체 요약 1-2문장>"}`
   - `from`은 입력에 있던 스킬명만
   - `into`는 이번에 스테이징한 우산명 (또는 입력에 있던 기존 스킬명)
   - 통합하지 않기로 했다면 `{"moves": [], "summary": "<이유>"}`
3. moves.json 없이 끝내지 마라 — 빈 moves라도 반드시 쓴다.

## 마지막 보고 (stdout)

클러스터 판단 근거, 만든 우산 목록, 흡수 목록, 통합하지 않은 것과 이유.
```

- [ ] **Step 2: 실패하는 테스트 작성**

`tests/test-curator-pass.sh`:

```bash
#!/bin/bash
# curator-pass.sh 테스트 — claude는 PATH 스텁. 실행: bash tests/test-curator-pass.sh
set -u
PKG="$(cd "$(dirname "$0")/.." && pwd)/growing-skills"
RUN="$PKG/bin/curator-pass.sh"
PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "PASS: $1"; else FAIL=$((FAIL+1)); echo "FAIL: $1 (expected [$2] got [$3])"; fi; }

iso_days_ago() { # n
  date -j -u -v-"$1"d +%Y-%m-%dT%H:%M:%SZ
}

mk_skill() { # root name
  mkdir -p "$1/$2"
  printf -- "---\nname: %s\ndescription: Use when testing\ncreated_by: agent\n---\nrefers to old-a here\n" "$2" > "$1/$2/SKILL.md"
}

setup() {
  SB=$(mktemp -d); SK="$SB/skills"; PR="$SB/proposals"
  mkdir -p "$SK" "$PR"
  US="$SK/.usage.json"; ST="$SK/.curator_state"
  # 스킬 4종: old-a(40일 미사용, agent) old-b(100일, agent) pinned-c(100일, agent+pinned) user-d(100일, user)
  mk_skill "$SK" old-a; mk_skill "$SK" old-b; mk_skill "$SK" pinned-c; mk_skill "$SK" user-d
  jq -n --arg d40 "$(iso_days_ago 40)" --arg d100 "$(iso_days_ago 100)" '{
    skills: {
      "old-a":    {use:3, last_activity_at:$d40,  first_seen:$d40,  created_by:"agent", state:"active", pinned:false},
      "old-b":    {use:3, last_activity_at:$d100, first_seen:$d100, created_by:"agent", state:"active", pinned:false},
      "pinned-c": {use:3, last_activity_at:$d100, first_seen:$d100, created_by:"agent", state:"active", pinned:true},
      "user-d":   {use:3, last_activity_at:$d100, first_seen:$d100, created_by:"user",  state:"active", pinned:false}
    }, compacted_at:null}' > "$US"
  STUB="$SB/stub"; mkdir -p "$STUB"
  cat > "$STUB/claude" <<EOF
#!/bin/bash
printf '%s\n' "\$@" > "$SB/args.log"
cat > "$SB/stdin.log"
STAGING=\$(grep -o '/[^ ]*\.curator_staging' "$SB/stdin.log" | head -1)
if [ "\${STUB_MODE:-good}" = "bad-manifest" ]; then
  printf '{"moves":[{"from":"NOT-IN-INPUT","into":"x","reason":"r"}],"summary":"s"}\n' > "\$STAGING/moves.json"
else
  mkdir -p "\$STAGING/umbrella-skill"
  printf -- "---\nname: umbrella-skill\ndescription: Use when testing umbrellas\ncreated_by: agent\n---\nmerged content\n" > "\$STAGING/umbrella-skill/SKILL.md"
  printf '{"moves":[{"from":"fresh-1","into":"umbrella-skill","reason":"cluster"},{"from":"fresh-2","into":"umbrella-skill","reason":"cluster"}],"summary":"2 narrow into 1 umbrella"}\n' > "\$STAGING/moves.json"
fi
echo "통합 보고"
EOF
  chmod +x "$STUB/claude"
}
teardown() { rm -rf "$SB"; }
run_pass() {
  PATH="$STUB:$PATH" GROWING_SKILLS_ROOT="$SK" GROWING_SKILLS_HOME="$PKG" \
    GROWING_SKILLS_PROPOSALS_DIR="$PR" GROWING_SKILLS_CONSOLIDATE_MIN="${CMIN:-99}" \
    bash "$RUN" "$@"
}

# T1: 수명 전이 — 40일 agent→stale, 100일 agent→archive, pinned·user 불가침
setup
run_pass >/dev/null
assert_eq "T1 40d stale" "stale" "$(jq -r '.skills["old-a"].state' "$US")"
assert_eq "T1 100d archived dir" "yes" "$([ -d "$SK/.archive/old-b" ] && echo yes || echo no)"
assert_eq "T1 100d sidecar" "archived" "$(jq -r '.skills["old-b"].state' "$US")"
assert_eq "T1 pinned untouched" "yes" "$([ -d "$SK/pinned-c" ] && echo yes || echo no)"
assert_eq "T1 user untouched" "yes" "$([ -d "$SK/user-d" ] && echo yes || echo no)"
assert_eq "T1 report exists" "1" "$(command ls "$SK/.curator_reports"/*.md 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "T1 snapshot exists" "1" "$(command ls "$SK/.curator_backups"/*.tar.gz 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "T1 stamp written" "yes" "$([ -f "$ST" ] && echo yes || echo no)"
teardown

# T2: dry-run — 아무것도 바뀌지 않고 보고서만 (DRY-RUN 표기), 스탬프 안 찍음
setup
run_pass --dry-run >/dev/null
assert_eq "T2 no stale" "active" "$(jq -r '.skills["old-a"].state' "$US")"
assert_eq "T2 no archive" "no" "$([ -d "$SK/.archive/old-b" ] && echo yes || echo no)"
assert_eq "T2 report dry" "1" "$(grep -lc "DRY-RUN" "$SK/.curator_reports"/*.md | wc -l | tr -d ' ')"
assert_eq "T2 no stamp" "no" "$([ -f "$ST" ] && echo yes || echo no)"
teardown

# T3: 제안 60일 폐기 → .discarded로 이동
setup
mkdir -p "$PR/stale-prop"
printf -- "---\nname: stale-prop\nproposed_at: %s\n---\n" "$(iso_days_ago 70)" > "$PR/stale-prop/SKILL.md"
mkdir -p "$PR/fresh-prop"
printf -- "---\nname: fresh-prop\nproposed_at: %s\n---\n" "$(iso_days_ago 5)" > "$PR/fresh-prop/SKILL.md"
run_pass >/dev/null
assert_eq "T3 stale discarded" "yes" "$([ -d "$PR/.discarded/stale-prop" ] && echo yes || echo no)"
assert_eq "T3 fresh kept" "yes" "$([ -d "$PR/fresh-prop" ] && echo yes || echo no)"
teardown

# T4: LLM 통합 — 신선한 agent 스킬 2개 + CMIN=2 → 우산 적용, from들 archive, 참조 재작성
setup
mk_skill "$SK" fresh-1; mk_skill "$SK" fresh-2
printf -- "---\nname: fresh-3\ndescription: t\ncreated_by: agent\n---\nsee fresh-1 for details\n" > "$SK/fresh-3/SKILL.md" # 참조 재작성 대상
mkdir -p "$SK/fresh-3" 2>/dev/null
NOWISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq --arg now "$NOWISO" '.skills += {"fresh-1":{use:5,last_activity_at:$now,first_seen:$now,created_by:"agent",state:"active",pinned:false},"fresh-2":{use:5,last_activity_at:$now,first_seen:$now,created_by:"agent",state:"active",pinned:false},"fresh-3":{use:5,last_activity_at:$now,first_seen:$now,created_by:"agent",state:"active",pinned:false}}' "$US" > "$US.tmp" && mv "$US.tmp" "$US"
CMIN=2 run_pass >/dev/null
assert_eq "T4 umbrella installed" "yes" "$([ -f "$SK/umbrella-skill/SKILL.md" ] && echo yes || echo no)"
assert_eq "T4 umbrella sidecar" "agent" "$(jq -r '.skills["umbrella-skill"].created_by' "$US")"
assert_eq "T4 from archived" "yes" "$([ -d "$SK/.archive/fresh-1" ] && [ -d "$SK/.archive/fresh-2" ] && echo yes || echo no)"
assert_eq "T4 absorbed_into" "umbrella-skill" "$(jq -r '.skills["fresh-1"].absorbed_into' "$US")"
assert_eq "T4 ref rewritten" "1" "$(grep -c "see umbrella-skill for details" "$SK/fresh-3/SKILL.md")"
assert_eq "T4 user file untouched" "1" "$(grep -c "refers to old-a here" "$SK/user-d/SKILL.md")"
teardown

# T5: 불량 매니페스트(입력에 없는 from) → 통합 거부, 스킬 무변경, 보고서에 기록
setup
mk_skill "$SK" fresh-1; mk_skill "$SK" fresh-2
NOWISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq --arg now "$NOWISO" '.skills += {"fresh-1":{use:5,last_activity_at:$now,first_seen:$now,created_by:"agent",state:"active",pinned:false},"fresh-2":{use:5,last_activity_at:$now,first_seen:$now,created_by:"agent",state:"active",pinned:false}}' "$US" > "$US.tmp" && mv "$US.tmp" "$US"
STUB_MODE=bad-manifest; export STUB_MODE
CMIN=2 run_pass >/dev/null
unset STUB_MODE
assert_eq "T5 fresh-1 intact" "yes" "$([ -d "$SK/fresh-1" ] && echo yes || echo no)"
assert_eq "T5 rejected in report" "1" "$(grep -lc "매니페스트 검증 실패" "$SK/.curator_reports"/*.md | wc -l | tr -d ' ')"
teardown

# T6: paused → 즉시 종료, 무변경
setup
printf '{"last_run_at":0,"paused":true}\n' > "$ST"
run_pass >/dev/null
assert_eq "T6 no report" "0" "$(command ls "$SK/.curator_reports"/*.md 2>/dev/null | wc -l | tr -d ' ')"
teardown

echo "----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
```

- [ ] **Step 3: 실행 — 실패 확인** — Run: `bash tests/test-curator-pass.sh` / Expected: FAIL

- [ ] **Step 4: 구현**

`growing-skills/bin/curator-pass.sh`:

```bash
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
ACTIVE_COUNT=$(printf '%s\n' "$ACTIVE_AGENT" | grep -c . || echo 0)
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
```

Run: `chmod +x growing-skills/bin/curator-pass.sh`

- [ ] **Step 5: 통과 확인** — Run: `bash tests/test-curator-pass.sh` / Expected: assert 수를 직접 세어 확정 (T1 8 + T2 4 + T3 2 + T4 6 + T5 2 + T6 1 = 23), `FAIL=0`이 합격 기준
- [ ] **Step 6: 커밋** — `git add growing-skills/prompts/curator-prompt.md tests/test-curator-pass.sh growing-skills/bin/curator-pass.sh && git commit -m "feat(growing-skills): 큐레이터 패스 — 전이·스냅샷·제안폐기·스테이징 통합·검증"`

---

### Task 4: SessionStart 훅 + /curator 스킬 (TDD)

**Files:**
- Create: `tests/test-curator-hook.sh`
- Create: `growing-skills/hooks/session-start-curator.sh`
- Create: `growing-skills/skill/SKILL.md`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test-curator-hook.sh`:

```bash
#!/bin/bash
# session-start-curator.sh 테스트. 실행: bash tests/test-curator-hook.sh
set -u
PKG="$(cd "$(dirname "$0")/.." && pwd)/growing-skills"
HOOK="$PKG/hooks/session-start-curator.sh"
PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "PASS: $1"; else FAIL=$((FAIL+1)); echo "FAIL: $1 (expected [$2] got [$3])"; fi; }

setup() { SK=$(mktemp -d); ST="$SK/.curator_state"; }
teardown() { rm -rf "$SK"; }
run_hook() {
  printf '{"session_id":"s","source":"startup"}' | \
    GROWING_SKILLS_ROOT="$SK" GROWING_SKILLS_HOME="$PKG" GROWING_SKILLS_NO_SPAWN="${NOSPAWN:-1}" bash "$HOOK"
}

# T1: 어떤 경우에도 stdout 무음 (컨텍스트 주입 방지) + exit 0
setup
OUT=$(run_hook)
assert_eq "T1 exit 0" "0" "$?"
assert_eq "T1 silent" "" "$OUT"
teardown

# T2: 7일 미경과 → 스폰 마커 없음 (스폰 검증은 NO_SPAWN=0 + 가짜 pass 스크립트로)
setup
printf '{"last_run_at":%s,"paused":false}\n' "$(date +%s)" > "$ST"
FAKE_HOME=$(mktemp -d); mkdir -p "$FAKE_HOME/bin"
printf '#!/bin/bash\ntouch "%s/spawned"\n' "$SK" > "$FAKE_HOME/bin/curator-pass.sh"
chmod +x "$FAKE_HOME/bin/curator-pass.sh"
printf '{"session_id":"s"}' | GROWING_SKILLS_ROOT="$SK" GROWING_SKILLS_HOME="$FAKE_HOME" GROWING_SKILLS_NO_SPAWN=0 bash "$HOOK"
sleep 1
assert_eq "T2 not spawned" "no" "$([ -f "$SK/spawned" ] && echo yes || echo no)"
rm -rf "$FAKE_HOME"
teardown

# T3: 7일 경과 → 스폰됨
setup
printf '{"last_run_at":%s,"paused":false}\n' "$(( $(date +%s) - 700000 ))" > "$ST"
FAKE_HOME=$(mktemp -d); mkdir -p "$FAKE_HOME/bin"
printf '#!/bin/bash\ntouch "%s/spawned"\n' "$SK" > "$FAKE_HOME/bin/curator-pass.sh"
chmod +x "$FAKE_HOME/bin/curator-pass.sh"
printf '{"session_id":"s"}' | GROWING_SKILLS_ROOT="$SK" GROWING_SKILLS_HOME="$FAKE_HOME" GROWING_SKILLS_NO_SPAWN=0 bash "$HOOK"
sleep 1
assert_eq "T3 spawned" "yes" "$([ -f "$SK/spawned" ] && echo yes || echo no)"
rm -rf "$FAKE_HOME"
teardown

# T4: paused → 스폰 안 함 / BG 마커 → 즉시 종료
setup
printf '{"last_run_at":0,"paused":true}\n' > "$ST"
FAKE_HOME=$(mktemp -d); mkdir -p "$FAKE_HOME/bin"
printf '#!/bin/bash\ntouch "%s/spawned"\n' "$SK" > "$FAKE_HOME/bin/curator-pass.sh"
chmod +x "$FAKE_HOME/bin/curator-pass.sh"
printf '{"session_id":"s"}' | GROWING_SKILLS_ROOT="$SK" GROWING_SKILLS_HOME="$FAKE_HOME" GROWING_SKILLS_NO_SPAWN=0 bash "$HOOK"
sleep 1
assert_eq "T4 paused no spawn" "no" "$([ -f "$SK/spawned" ] && echo yes || echo no)"
OUT=$(printf '{}' | GROWING_SKILLS_BG=1 GROWING_SKILLS_ROOT="$SK" bash "$HOOK")
assert_eq "T4 bg silent exit" "0" "$?"
rm -rf "$FAKE_HOME"
teardown

echo "----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: 실행 — 실패 확인** — Run: `bash tests/test-curator-hook.sh` / Expected: FAIL

- [ ] **Step 3: 훅 구현**

`growing-skills/hooks/session-start-curator.sh`:

```bash
#!/bin/bash
# growing-skills: SessionStart 훅 — 7일 경과 시 큐레이터 detach 스폰.
# 중대: SessionStart 훅의 stdout은 세션 컨텍스트에 주입된다 — 첫 줄에서 전면 차단.
exec >/dev/null 2>&1
[ "${GROWING_SKILLS_BG:-}" = "1" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

SKILLS_ROOT="${GROWING_SKILLS_ROOT:-$HOME/.claude/skills}"
GS_HOME="${GROWING_SKILLS_HOME:-$HOME/.claude/growing-skills}"
STATE="$SKILLS_ROOT/.curator_state"

[ "$(jq -r '.paused // false' "$STATE" 2>/dev/null)" = "true" ] && exit 0
LAST=$(jq -r '.last_run_at // 0' "$STATE" 2>/dev/null); [ -z "$LAST" ] && LAST=0
NOW=$(date +%s)
[ $((NOW - LAST)) -lt 604800 ] && exit 0
[ "${GROWING_SKILLS_NO_SPAWN:-}" = "1" ] && exit 0
[ -x "$GS_HOME/bin/curator-pass.sh" ] || exit 0
nohup "$GS_HOME/bin/curator-pass.sh" >/dev/null 2>&1 &
exit 0
```

Run: `chmod +x growing-skills/hooks/session-start-curator.sh`

- [ ] **Step 4: /curator 스킬 작성**

`growing-skills/skill/SKILL.md` (전문):

```markdown
---
name: curator
description: Use when the user runs /curator or asks about skill proposals, promotion, pinning, archiving, curation status, or growing-skills management.
---

# /curator — growing-skills 컨트롤

모든 조작은 `~/.claude/growing-skills/bin/curator-ctl.sh`와 `curator-pass.sh`를 Bash로 호출해 수행한다. 직접 사이드카 JSON을 편집하지 않는다.

## 서브커맨드

| 명령 | 실행 |
|---|---|
| `/curator` 또는 `/curator status` | `curator-ctl.sh status` 실행 + `~/.claude/skills/.curator_reports/`의 최신 보고서 요약을 함께 보여준다 |
| `/curator review` | 아래 "승격 게이트" 절차 |
| `/curator run` | `curator-pass.sh` 실행 (포그라운드), 보고서 요약 제시 |
| `/curator dry-run` | `curator-pass.sh --dry-run` 실행, 무엇이 일어날지 보고 |
| `/curator pin <skill>` / `unpin <skill>` | `curator-ctl.sh pin|unpin <skill>` |
| `/curator pause` / `resume` | `curator-ctl.sh pause|resume` |
| `/curator restore <skill>` | `curator-ctl.sh restore <skill>` |
| `/curator adopt <skill>` | `curator-ctl.sh adopt <skill>` — 사용자 스킬을 30/90일 수명 관리에 옵트인 |
| `/curator rollback` | **반드시 사용자에게 최신 스냅샷 시각을 보여주고 확인받은 뒤** `curator-ctl.sh rollback` |

## 승격 게이트 (`/curator review`)

제안 스킬은 승격 전까지 어떤 세션에도 로드되지 않는다. 이 게이트가 오류 증폭을 막는 핵심 장치다.

1. `command ls -d ~/.claude/skill-proposals/*/ 2>/dev/null | grep -v .discarded`로 대기 제안을 나열한다. 없으면 "대기 제안 없음"으로 끝.
2. 각 제안의 SKILL.md를 읽고 사용자에게 보여준다: 이름, description, 핵심 내용 요약, frontmatter의 proposed_at·source_session.
3. 제안별로 사용자에게 묻는다 (AskUserQuestion 권장): **승인 / 수정 후 승인 / 거부 / 보류**.
   - 승인 → `curator-ctl.sh promote <name>` 실행. 예산 경고(WARN)가 나오면 사용자에게 전달.
   - 수정 후 승인 → 사용자 피드백대로 제안 SKILL.md를 편집한 뒤 promote.
   - 거부 → `mkdir -p ~/.claude/skill-proposals/.discarded && mv ~/.claude/skill-proposals/<name> ~/.claude/skill-proposals/.discarded/`
   - 보류 → 그대로 둔다 (60일 후 자동 폐기됨을 알린다).
4. 승격 검증을 원하면: skill-factory(`~/development/main_project/skill-factory`)의 RED 시나리오 절차로 압박 테스트 후 승격하는 옵션을 제안한다.

## 보호 규칙 (절대 위반 금지)

- pinned·사용자 생성·외부 설치 스킬은 자동 삭제·이동 대상이 아니다.
- 모든 제거는 `.archive/`(스킬) 또는 `.discarded/`(제안)로의 mv — 하드 삭제 금지.
- rollback은 사용자 확인 없이 실행하지 않는다.
```

- [ ] **Step 5: 통과 확인** — Run: `bash tests/test-curator-hook.sh` / Expected: `PASS=7 FAIL=0` (assert 수 직접 확인)
- [ ] **Step 6: 커밋** — `git add tests/test-curator-hook.sh growing-skills/hooks/session-start-curator.sh growing-skills/skill/SKILL.md && git commit -m "feat(growing-skills): SessionStart 큐레이터 훅(무음) + /curator 스킬"`

---

### Task 5: install/uninstall 확장 (TDD)

**Files:**
- Modify: `tests/test-install.sh` (T6 블록 뒤, 최종 echo 앞에 T7·T8 추가)
- Modify: `growing-skills/install.sh`
- Modify: `growing-skills/uninstall.sh`

- [ ] **Step 1: 테스트 추가**

`tests/test-install.sh`의 T6 teardown 앞(주의: T5/T6는 같은 setup 블록을 공유하므로 T6의 teardown 뒤)에 삽입:

```bash
# T7: Phase 3 설치 — SessionStart 머지(기존 항목 보존) + /curator 스킬 + curator 스크립트
setup
# 기존 SessionStart 훅이 있는 환경 시뮬레이션
jq '.hooks.SessionStart = [{"hooks":[{"type":"command","command":"~/.claude/hooks/existing-start.sh","timeout":5}]}]' \
  "$SANDBOX/.claude/settings.json" > "$SANDBOX/tmp.json" && mv "$SANDBOX/tmp.json" "$SANDBOX/.claude/settings.json"
GROWING_SKILLS_CLAUDE_DIR="$SANDBOX/.claude" bash "$PKG/install.sh" >/dev/null
assert_eq "T7 curator hook entry" "1" "$(jq '[.hooks.SessionStart[]? | select((.hooks // []) | any(.command // "" | contains("session-start-curator.sh")))] | length' "$SANDBOX/.claude/settings.json")"
assert_eq "T7 existing start preserved" "1" "$(jq '[.hooks.SessionStart[]? | select((.hooks // []) | any(.command // "" | contains("existing-start.sh")))] | length' "$SANDBOX/.claude/settings.json")"
assert_eq "T7 curator skill installed" "yes" "$([ -f "$SANDBOX/.claude/skills/curator/SKILL.md" ] && echo yes || echo no)"
assert_eq "T7 ctl deployed" "yes" "$([ -x "$SANDBOX/.claude/growing-skills/bin/curator-ctl.sh" ] && echo yes || echo no)"
assert_eq "T7 pass deployed" "yes" "$([ -x "$SANDBOX/.claude/growing-skills/bin/curator-pass.sh" ] && echo yes || echo no)"
assert_eq "T7 curator prompt" "yes" "$([ -f "$SANDBOX/.claude/growing-skills/prompts/curator-prompt.md" ] && echo yes || echo no)"
GROWING_SKILLS_CLAUDE_DIR="$SANDBOX/.claude" bash "$PKG/install.sh" >/dev/null
assert_eq "T7 idempotent" "1" "$(jq '[.hooks.SessionStart[]? | select((.hooks // []) | any(.command // "" | contains("session-start-curator.sh")))] | length' "$SANDBOX/.claude/settings.json")"

# T8: uninstall — 큐레이터 항목 제거, 기존 SessionStart 보존, /curator 스킬 제거, 아카이브 보존
mkdir -p "$SANDBOX/.claude/skills/.archive/keep-me"
echo x > "$SANDBOX/.claude/skills/.archive/keep-me/SKILL.md"
GROWING_SKILLS_CLAUDE_DIR="$SANDBOX/.claude" bash "$PKG/uninstall.sh" >/dev/null
assert_eq "T8 curator hook removed" "0" "$(jq '[.hooks.SessionStart[]? | select((.hooks // []) | any(.command // "" | contains("session-start-curator.sh")))] | length' "$SANDBOX/.claude/settings.json")"
assert_eq "T8 existing start kept" "1" "$(jq '[.hooks.SessionStart[]? | select((.hooks // []) | any(.command // "" | contains("existing-start.sh")))] | length' "$SANDBOX/.claude/settings.json")"
assert_eq "T8 curator skill removed" "no" "$([ -d "$SANDBOX/.claude/skills/curator" ] && echo yes || echo no)"
assert_eq "T8 archive preserved" "yes" "$([ -f "$SANDBOX/.claude/skills/.archive/keep-me/SKILL.md" ] && echo yes || echo no)"
teardown
```

- [ ] **Step 2: 실행 — 실패 확인** — Run: `bash tests/test-install.sh` / Expected: 기존 24 PASS, T7/T8 FAIL

- [ ] **Step 3: install.sh 확장**

`# 3) CLAUDE.md에 독트린 추가` 블록 **앞에** 삽입 (2.5 블록 뒤):

```bash
# 2.7) Phase 3: 큐레이터 훅 + /curator 스킬
cp "$PKG_DIR/hooks/session-start-curator.sh" "$CLAUDE_DIR/hooks/session-start-curator.sh"
chmod +x "$CLAUDE_DIR/hooks/session-start-curator.sh"
mkdir -p "$CLAUDE_DIR/skills/curator"
cp "$PKG_DIR/skill/SKILL.md" "$CLAUDE_DIR/skills/curator/SKILL.md"

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
```

(2.5 블록의 `cp "$PKG_DIR/bin/"*.sh`는 새 bin 스크립트 3종을 자동 포함; `cp "$PKG_DIR/prompts/"*.md`로 바꿔 curator-prompt.md도 배포 — 기존 `cp .../reviewer-prompt.md` 줄을 `cp "$PKG_DIR/prompts/"*.md "$CLAUDE_DIR/growing-skills/prompts/"`로 교체)

- [ ] **Step 4: uninstall.sh 확장**

settings jq 프로그램에 SessionStart 큐레이터 제거 추가 (기존 PostToolUse·SessionEnd 처리 뒤에 파이프로):

```bash
      | if .hooks.SessionStart then
        .hooks.SessionStart = [.hooks.SessionStart[] | select((.hooks // []) | any(.command // "" | contains("session-start-curator.sh")) | not)]
        | if (.hooks.SessionStart | length) == 0 then del(.hooks.SessionStart) else . end
      else . end
```

그리고 제거 라인 추가:

```bash
rm -f "$CLAUDE_DIR/hooks/session-start-curator.sh"
rm -rf "$CLAUDE_DIR/skills/curator"
```

(`.archive/`·`.usage.json`·보고서·스냅샷은 보존 — 데이터)

- [ ] **Step 5: 통과 + 전체 회귀** — Run: 전체 테스트 7종 / Expected: 전부 `FAIL=0` (test-install `PASS=35`)
- [ ] **Step 6: 커밋** — `git add -A && git commit -m "feat(growing-skills): install/uninstall Phase 3 확장 — 큐레이터 훅·/curator 스킬"`

---

### Task 6: 실배포 + 스모크 (메인 세션)

- [ ] **Step 1: 설치** — `bash growing-skills/install.sh`
- [ ] **Step 2: 무결성** — SessionStart 항목(기존 훅 보존 확인 포함), `/curator` 스킬 존재, bin 3종
- [ ] **Step 3: 컴팩션 스모크** — `bash ~/.claude/growing-skills/bin/compact-events.sh` 후 `.usage.json`에 Phase 1부터 쌓인 실이벤트 반영 확인
- [ ] **Step 4: status + dry-run 스모크** — `curator-ctl.sh status`, `curator-pass.sh --dry-run` 실행, 보고서 확인 (LLM 통합은 agent 스킬 0개라 자연 스킵)
- [ ] **Step 5: 승격 게이트 실연** — 대기 중인 실제 제안 2건으로 `/curator review` 절차를 사용자와 함께 실행 (사용자가 승인/거부 결정)
- [ ] **Step 6: 배포 기록 커밋 + main 머지**

---

## Self-Review 결과

- **스펙 커버리지**: Layer 4 패스 7단계 전부(컴팩션·로테이션은 Task 1, 스냅샷·전이·폐기·통합·재작성·보고서는 Task 3) + Layer 5 전체(Task 2·4) + 인덱스 예산 15(promote WARN + 통합 우선) + 보호 규칙(사이드카 필터 + 스킬 문서) + 아카이브 복원(restore) = 스펙 §4 Layer 4·5, §5 충족. 리뷰어 프롬프트의 ".archive 동명 확인"은 /curator review 게이트에서 사람이 자연 수행 — Plan 2 이월분 해소.
- **Placeholder 스캔**: 통과. PASS 카운트는 전부 "직접 세어 확정" 지시 포함.
- **이름 일관성**: `.curator_state`(reviewer와 별개), `.curator.lock`, `GROWING_SKILLS_CONSOLIDATE_MIN`, `created_by|curated|pinned|state|absorbed_into` 필드, `.discarded` — 태스크 간 대조 완료. 주의: `sed -i ''`는 BSD sed 전용(macOS) — 환경 고정이므로 수용.
