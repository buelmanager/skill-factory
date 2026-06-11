# growing-skills Phase 2 (백그라운드 리뷰어) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 세션 종료 시 자격 세션의 다이제스트를 큐에 쌓고, 하루 1회 배치 리뷰어(헤드리스 claude)가 큐를 처리해 스킬 제안(`~/.claude/skill-proposals/`)과 위키 dev raw 노트를 생성한다.

**Architecture:** SessionEnd 훅(`session-end-queue.sh`)이 도구 15회+ 세션의 트랜스크립트를 압축·마스킹(`digest-transcript.sh`)해 `~/.claude/skills/.review-queue/`에 적재하고 리뷰어를 detach 스폰. 리뷰어(`run-reviewer.sh`)는 락·일간 게이트·write-ahead 스탬프를 거쳐 큐를 200KB 배치로 묶어 헤드리스 `claude -p`(훅 없는 전용 settings, MCP 차단, 경로 한정 쓰기 권한)에 투입. 산출물은 제안 스킬(로드 안 됨 — probation)과 위키 raw 노트, 실행 보고서. 스펙: `docs/superpowers/specs/2026-06-11-growing-skills-design.md` §4 Layer 3, §4.5.

**Tech Stack:** bash(macOS 3.2), jq 1.8.1, GNU timeout(설치 확인됨), Claude Code headless(`claude -p`, v2.1.172).

**확정 사실 (Phase 1 + 추가 스파이크 2026-06-11):**
- 트랜스크립트 JSONL 구조 실측: 라인별 `.type`(user/assistant/attachment/system...), assistant `.message.content[]`는 `{type:"thinking"|"text"|"tool_use"}`, user `.message.content`는 문자열 또는 배열(배열엔 `{type:"tool_result", is_error:bool, content}`), 도구 수 = assistant tool_use 블록 수
- 위키 dev raw 노트는 YAML frontmatter가 아니라 헤더 관례: `# 제목` + `> 도메인: dev · ...` + `> ⚠ raw 스냅샷...` (실파일 확인)
- SessionEnd 훅 stdin에 `transcript_path` 미보장(문서 미기재) → `~/.claude/projects/<munge(cwd)>/<session_id>.jsonl` 파생 폴백 필요. munge: `/`·`_`·`.` → `-` (실경로로 확인: `/Users/chulheewon/development/main_project/skill-factory` → `-Users-chulheewon-development-main-project-skill-factory`)
- 스폰되는 claude는 `env -u ANTHROPIC_API_KEY` 필수, `GROWING_SKILLS_BG=1` 마커, `--settings`로 hooks 오버라이드, 경로 권한 규칙은 `//`가 절대 경로 (`Write(//Users/...)`)
- SessionEnd는 블록 불가, 훅 타임아웃 기본 600초 — detach 스폰으로 종료 지연 0

**파일 구조 (Phase 2 추가):**
```
growing-skills/
├── hooks/session-end-queue.sh      # SessionEnd: 자격 판정 + 다이제스트 적재 + 리뷰어 스폰
├── bin/digest-transcript.sh        # 트랜스크립트 → 마스킹된 다이제스트 (stdout)
├── bin/run-reviewer.sh             # 일간 배치 리뷰어 (락·게이트·배치·claude 스폰·보고)
├── prompts/reviewer-prompt.md      # 리뷰 프롬프트 (선호 사다리 + 블랙리스트)
├── settings/headless-settings.json # {"hooks": {}} — 스폰된 claude의 훅 무력화
├── install.sh                      # 확장: 패키지 배포 + SessionEnd 훅 머지
└── uninstall.sh                    # 확장: 역순 제거
tests/
├── test-digest.sh
├── test-queue-hook.sh
└── test-run-reviewer.sh            # claude는 PATH 스텁으로 대체
```

**런타임 디렉터리 (~/.claude/skills/ 아래, 전부 점-경로라 디스커버리 불가시):**
`.review-queue/`(대기 다이제스트) · `.review-queue/done/`(처리됨, 14일 보관) · `.reviewer_state`(`{"last_run_at": epoch}`) · `.reviewer.lock`(PID+epoch 2줄, 2h stale 해제) · `.review-reports/`(보고서, 12개 보관)

---

### Task 1: digest-transcript.sh — 추출·마스킹·상한 (TDD)

**Files:**
- Create: `tests/test-digest.sh`
- Create: `growing-skills/bin/digest-transcript.sh`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test-digest.sh`:

```bash
#!/bin/bash
# digest-transcript.sh 테스트. 실행: bash tests/test-digest.sh
set -u
BIN="$(cd "$(dirname "$0")/.." && pwd)/growing-skills/bin/digest-transcript.sh"
PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "PASS: $1"; else FAIL=$((FAIL+1)); echo "FAIL: $1 (expected [$2] got [$3])"; fi; }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

# 실측 트랜스크립트 구조를 따른 픽스처
cat > "$WORK/t1.jsonl" <<'EOF'
{"type":"user","message":{"content":"hello world string message"}}
{"type":"user","message":{"content":[{"type":"text","text":"array user text"}]}}
{"type":"assistant","message":{"content":[{"type":"thinking","thinking":"secretthought"},{"type":"text","text":"assistant says hi"},{"type":"tool_use","name":"Bash","input":{"command":"ls -la"}}]}}
{"type":"user","message":{"content":[{"type":"tool_result","is_error":true,"content":"command failed: boom"}]}}
{"type":"attachment","foo":1}
EOF

# T1: 추출 — USER/TOOL/CLAUDE/ERROR 포함, thinking 제외, 헤더 포함
OUT=$(bash "$BIN" "$WORK/t1.jsonl" "sess-abc" "/tmp/proj")
assert_eq "T1 user string" "1" "$(printf '%s' "$OUT" | grep -c "\[USER\] hello world string message")"
assert_eq "T1 tool line" "1" "$(printf '%s' "$OUT" | grep -c "\[TOOL\] Bash")"
assert_eq "T1 claude line" "1" "$(printf '%s' "$OUT" | grep -c "\[CLAUDE\] assistant says hi")"
assert_eq "T1 error line" "1" "$(printf '%s' "$OUT" | grep -c "\[ERROR\] command failed: boom")"
assert_eq "T1 thinking excluded" "0" "$(printf '%s' "$OUT" | grep -c "secretthought")"
assert_eq "T1 header" "1" "$(printf '%s' "$OUT" | grep -c "=== SESSION sess-abc")"

# T2: 시크릿 마스킹
cat > "$WORK/t2.jsonl" <<'EOF'
{"type":"user","message":{"content":"key is sk-ant-api03-AbCdEf123456789 and ghp_AbCdEfGh123456789012 and password=supersecret999"}}
EOF
OUT=$(bash "$BIN" "$WORK/t2.jsonl" "s" "/tmp")
assert_eq "T2 no sk-ant" "0" "$(printf '%s' "$OUT" | grep -c "sk-ant-api03")"
assert_eq "T2 no ghp" "0" "$(printf '%s' "$OUT" | grep -c "ghp_AbCdEfGh")"
assert_eq "T2 no password value" "0" "$(printf '%s' "$OUT" | grep -c "supersecret999")"
assert_eq "T2 masked marker present" "yes" "$([ "$(printf '%s' "$OUT" | grep -c 'MASKED')" -ge 1 ] && echo yes)"

# T3: 200KB 상한
BIG=$(awk 'BEGIN{for(i=0;i<300000;i++)printf "a"}')
jq -n --arg t "$BIG" '{type:"user",message:{content:$t}}' > "$WORK/t3.jsonl"
SZ=$(bash "$BIN" "$WORK/t3.jsonl" "s" "/tmp" | wc -c | tr -d ' ')
assert_eq "T3 capped" "yes" "$([ "$SZ" -le 200200 ] && echo yes)"

echo "----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: 실행 — 실패 확인**

Run: `bash tests/test-digest.sh`
Expected: FAIL (digest-transcript.sh 미존재)

- [ ] **Step 3: 구현**

`growing-skills/bin/digest-transcript.sh`:

```bash
#!/bin/bash
# 트랜스크립트 JSONL → 리뷰어용 다이제스트 (stdout).
# 사용: digest-transcript.sh <transcript.jsonl> [session_id] [cwd]
# 추출: 사용자 메시지(2000자), 도구 호출명+입력(200자), 에러(500자), 응답 요지(1000자).
# thinking 블록은 제외. 시크릿 마스킹 후 전체 200KB 상한.
set -u
FILE="${1:?transcript path required}"
SID="${2:-unknown}"
CWD="${3:-unknown}"

TOOLS=$(jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use") | .name' "$FILE" 2>/dev/null | wc -l | tr -d ' ')
printf '=== SESSION %s (cwd: %s, tools: %s, date: %s) ===\n' "$SID" "$CWD" "$TOOLS" "$(date -u +%Y-%m-%d)"

jq -r '
  if .type=="user" then
    (.message.content
     | if type=="string" then (if length>0 then "[USER] " + .[0:2000] else empty end)
       else (
         ((map(select(.type=="text") | .text) | join(" ")) as $t
          | if ($t|length)>0 then "[USER] " + $t[0:2000] else empty end),
         (.[] | select(.type=="tool_result" and .is_error==true)
          | "[ERROR] " + ((.content|tostring)[0:500]))
       )
       end)
  elif .type=="assistant" then
    (.message.content[]?
     | if .type=="tool_use" then "[TOOL] \(.name) " + ((.input|tostring)[0:200])
       elif .type=="text" then "[CLAUDE] " + (.text[0:1000])
       else empty end)
  else empty end
' "$FILE" 2>/dev/null \
| sed -E \
    -e 's/sk-ant-[A-Za-z0-9_-]{8,}/[MASKED]/g' \
    -e 's/(gh[pousr]|github_pat)_[A-Za-z0-9_]{16,}/[MASKED]/g' \
    -e 's/AKIA[A-Z0-9]{16}/[MASKED]/g' \
    -e 's/xox[baprs]-[A-Za-z0-9-]{10,}/[MASKED]/g' \
    -e 's/[Bb]earer [A-Za-z0-9._~+\/=-]{20,}/Bearer [MASKED]/g' \
    -e 's/((api[_-]?key|API[_-]?KEY|token|TOKEN|secret|SECRET|password|PASSWORD|passwd|credential)["'"'"' ]*[:=]["'"'"' ]*)[^"'"'"' ]{8,}/\1[MASKED]/g' \
| head -c 200000
exit 0
```

Run: `chmod +x growing-skills/bin/digest-transcript.sh`

- [ ] **Step 4: 통과 확인**

Run: `bash tests/test-digest.sh`
Expected: `PASS=11 FAIL=0`

- [ ] **Step 5: 커밋**

```bash
git add tests/test-digest.sh growing-skills/bin/digest-transcript.sh
git commit -m "feat(growing-skills): 트랜스크립트 다이제스트 — 추출·시크릿 마스킹·200KB 상한"
```

---

### Task 2: session-end-queue.sh 훅 + headless settings (TDD)

**Files:**
- Create: `tests/test-queue-hook.sh`
- Create: `growing-skills/hooks/session-end-queue.sh`
- Create: `growing-skills/settings/headless-settings.json`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test-queue-hook.sh`:

```bash
#!/bin/bash
# session-end-queue.sh 테스트. 실행: bash tests/test-queue-hook.sh
set -u
PKG="$(cd "$(dirname "$0")/.." && pwd)/growing-skills"
HOOK="$PKG/hooks/session-end-queue.sh"
PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "PASS: $1"; else FAIL=$((FAIL+1)); echo "FAIL: $1 (expected [$2] got [$3])"; fi; }

mk_transcript() { # path tool_count
  : > "$1"
  i=0
  while [ "$i" -lt "$2" ]; do
    echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"ls"}}]}}' >> "$1"
    i=$((i+1))
  done
  echo '{"type":"user","message":{"content":"do the thing"}}' >> "$1"
}

setup() {
  SB=$(mktemp -d)
  SKILLS="$SB/skills"; mkdir -p "$SKILLS"
  QUEUE="$SKILLS/.review-queue"
}
teardown() { rm -rf "$SB"; }

run_hook() { # payload
  printf '%s' "$1" | GROWING_SKILLS_ROOT="$SKILLS" GROWING_SKILLS_HOME="$PKG" \
    GROWING_SKILLS_MIN_TOOLS=3 GROWING_SKILLS_NO_SPAWN=1 \
    GROWING_SKILLS_PROJECTS_DIR="$SB/projects" bash "$HOOK"
}

# T1: 자격 세션(도구 4 ≥ 임계 3) + transcript_path 명시 → 큐 적재
setup
mk_transcript "$SB/t.jsonl" 4
run_hook "{\"session_id\":\"sess-12345678\",\"cwd\":\"/tmp/p\",\"transcript_path\":\"$SB/t.jsonl\"}"
assert_eq "T1 exit 0" "0" "$?"
assert_eq "T1 one queue file" "1" "$(ls "$QUEUE"/*.md 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "T1 header in digest" "1" "$(grep -c "=== SESSION sess-12345678" "$QUEUE"/*.md)"
teardown

# T2: 임계 미달(도구 2 < 3) → 적재 안 함
setup
mk_transcript "$SB/t.jsonl" 2
run_hook "{\"session_id\":\"s\",\"cwd\":\"/tmp\",\"transcript_path\":\"$SB/t.jsonl\"}"
assert_eq "T2 no queue" "0" "$(ls "$QUEUE"/*.md 2>/dev/null | wc -l | tr -d ' ')"
teardown

# T3: 백그라운드 마커 → 적재 안 함
setup
mk_transcript "$SB/t.jsonl" 4
printf '%s' "{\"session_id\":\"s\",\"cwd\":\"/tmp\",\"transcript_path\":\"$SB/t.jsonl\"}" \
  | GROWING_SKILLS_BG=1 GROWING_SKILLS_ROOT="$SKILLS" GROWING_SKILLS_HOME="$PKG" \
    GROWING_SKILLS_MIN_TOOLS=3 GROWING_SKILLS_NO_SPAWN=1 bash "$HOOK"
assert_eq "T3 no queue" "0" "$(ls "$QUEUE"/*.md 2>/dev/null | wc -l | tr -d ' ')"
teardown

# T4: transcript_path 없음 → cwd+session_id 파생 경로 폴백
setup
mkdir -p "$SB/projects/-tmp-my-proj"
mk_transcript "$SB/projects/-tmp-my-proj/sess-99.jsonl" 4
run_hook "{\"session_id\":\"sess-99\",\"cwd\":\"/tmp/my_proj\"}"
assert_eq "T4 derived queue file" "1" "$(ls "$QUEUE"/*.md 2>/dev/null | wc -l | tr -d ' ')"
teardown

# T5: 깨진 페이로드 → exit 0, 적재 안 함
setup
run_hook 'not-json{{{'
assert_eq "T5 exit 0" "0" "$?"
assert_eq "T5 no queue" "0" "$(ls "$QUEUE"/*.md 2>/dev/null | wc -l | tr -d ' ')"
teardown

echo "----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: 실행 — 실패 확인**

Run: `bash tests/test-queue-hook.sh`
Expected: FAIL (훅 미존재)

- [ ] **Step 3: 구현**

`growing-skills/hooks/session-end-queue.sh`:

```bash
#!/bin/bash
# growing-skills: SessionEnd 훅 — 자격 세션(도구 N회+)의 다이제스트를 리뷰 큐에 적재하고
# 리뷰어를 detach 스폰한다. 어떤 경우에도 세션 종료를 지연·방해하지 않는다: 항상 exit 0.
[ "${GROWING_SKILLS_BG:-}" = "1" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

SKILLS_ROOT="${GROWING_SKILLS_ROOT:-$HOME/.claude/skills}"
GS_HOME="${GROWING_SKILLS_HOME:-$HOME/.claude/growing-skills}"
PROJECTS_DIR="${GROWING_SKILLS_PROJECTS_DIR:-$HOME/.claude/projects}"
MIN_TOOLS="${GROWING_SKILLS_MIN_TOOLS:-15}"

INPUT=$(cat)
SID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$SID" ] && exit 0
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)
TPATH=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)

# transcript_path 미제공 시 파생: ~/.claude/projects/<munge(cwd)>/<sid>.jsonl (munge: / _ . → -)
if [ -z "$TPATH" ]; then
  MUNGED=$(printf '%s' "$CWD" | sed 's#[/_.]#-#g')
  TPATH="$PROJECTS_DIR/$MUNGED/$SID.jsonl"
fi
[ -f "$TPATH" ] || exit 0

TOOLS=$(jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use") | .name' "$TPATH" 2>/dev/null | wc -l | tr -d ' ')
[ "$TOOLS" -ge "$MIN_TOOLS" ] 2>/dev/null || exit 0

QUEUE="$SKILLS_ROOT/.review-queue"
mkdir -p "$QUEUE" 2>/dev/null || exit 0
TMP=$(mktemp) || exit 0
if "$GS_HOME/bin/digest-transcript.sh" "$TPATH" "$SID" "$CWD" > "$TMP" 2>/dev/null; then
  mv "$TMP" "$QUEUE/$(date +%Y%m%d-%H%M%S)-$(printf '%s' "$SID" | cut -c1-8).md" 2>/dev/null
else
  rm -f "$TMP"
fi

# 리뷰어 스폰 (게이트 판단은 리뷰어 자신이 함). 테스트에서는 NO_SPAWN으로 차단.
if [ "${GROWING_SKILLS_NO_SPAWN:-}" != "1" ] && [ -x "$GS_HOME/bin/run-reviewer.sh" ]; then
  nohup "$GS_HOME/bin/run-reviewer.sh" >/dev/null 2>&1 &
fi
exit 0
```

`growing-skills/settings/headless-settings.json`:

```json
{
  "hooks": {}
}
```

Run: `chmod +x growing-skills/hooks/session-end-queue.sh`

- [ ] **Step 4: 통과 확인**

Run: `bash tests/test-queue-hook.sh`
Expected: `PASS=8 FAIL=0`

- [ ] **Step 5: 커밋**

```bash
git add tests/test-queue-hook.sh growing-skills/hooks/session-end-queue.sh growing-skills/settings/headless-settings.json
git commit -m "feat(growing-skills): SessionEnd 큐 적재 훅 + 헤드리스 전용 settings"
```

---

### Task 3: 리뷰어 프롬프트 + run-reviewer.sh (TDD, claude 스텁)

**Files:**
- Create: `growing-skills/prompts/reviewer-prompt.md`
- Create: `tests/test-run-reviewer.sh`
- Create: `growing-skills/bin/run-reviewer.sh`

- [ ] **Step 1: 리뷰어 프롬프트 작성**

`growing-skills/prompts/reviewer-prompt.md` (전문):

```markdown
# growing-skills 백그라운드 리뷰어

너는 growing-skills 시스템의 백그라운드 리뷰어다. stdin으로 하나 이상의 세션 다이제스트가 주어진다 (`=== SESSION ... ===` 헤더로 구분). 각 다이제스트는 Claude Code 세션의 압축본이다: `[USER]` 사용자 메시지, `[TOOL]` 도구 호출, `[ERROR]` 실패, `[CLAUDE]` 응답 요지.

## 임무

다이제스트에서 **재사용 가능한 절차적 지식**("어떻게 X를 한다")을 찾아 스킬 제안으로 작성하고, 절차가 아닌 **위키성 지식**(결정·도메인 사실·프로젝트 맥락)을 dev 도메인 raw 노트로 적재한다.

## 선호 사다리 (위 단계가 가능하면 아래로 내려가지 않는다)

1. 이번 다이제스트와 관련된 **기존 제안 스킬**(제안 디렉터리에 이미 있음)이 같은 주제를 다룸 → 새로 만들지 말고 그 제안을 패치·보강한다
2. 기존 제안 스킬 중 frontmatter `created_by: agent`인 것의 결함이 다이제스트에서 드러남 → 직접 패치한다
3. 완전히 새로운 재사용 절차 → 새 제안 스킬을 작성한다

사용자·외부 스킬(제안 디렉터리 밖의 모든 것)은 **절대 직접 수정하지 않는다** — 결함을 발견하면 마지막 보고에만 적는다.

## 배우지 말 것 (블랙리스트)

- 환경 의존적 실패 (특정 머신·네트워크·일시 상태에서만 재현되는 것)
- "도구 X가 고장났다/안 된다"류 일반화 — 이런 기록은 몇 달간 스스로를 막는 거부 근거로 굳는다
- 일시적 오류, 재시도로 해결된 것
- 일회성 서사 (다시 만날 가능성이 낮은 상황의 전말)
- 자격증명·토큰·시크릿 — 어떤 형태로도 스킬·노트 텍스트에 포함 금지
- 추측 — 다이제스트에서 실제로 일어난 것만 기록한다

## 품질 기준

업데이트를 강요하지 않는다. 확실한 재사용 절차가 없으면 아무것도 만들지 말고 "제안 없음"과 이유를 보고하라. 양보다 정확성이 우선이다.

## 스킬 제안 형식

제안 디렉터리([환경] 참조) 아래 `<skill-name>/SKILL.md`:

- `name`: 영문 소문자·숫자·하이픈만, 동사형(-ing) 선호 (예: `fixing-supabase-migrations`)
- `description`: "Use when..."으로 시작, **발동 조건만** 기술 (워크플로 요약 금지)
- frontmatter에 `created_by: agent`, `proposed_at: <오늘 날짜>`, `source_session: <세션 ID>` 필수
- 본문 500단어 이내, 검색 키워드(에러 메시지·증상·도구명)를 본문에 배치

## 위키 raw 노트 형식 (dev 도메인만)

위키 dev raw 디렉터리([환경] 참조) 아래 `YYYY-MM-DD_<slug>.md`:

```
# <제목>
> 도메인: dev · 출처: growing-skills reviewer · 세션: <ID> · status: needs-check
> ⚠ raw 스냅샷(데이터). ingest 전까지 지식 페이지 아님.

<사실·결정만 간결히>
```

dev 외 도메인(사업·금융·건강·가족 등) 내용은 노트로 만들지 말고 보고에 "/wiki-checkpoint 권고"로만 남긴다.

## 마지막 보고 (stdout — 그대로 실행 보고서가 된다)

처리한 세션 수 / 만든·패치한 제안 목록(각 1줄 이유) / 위키 노트 목록 / 건너뛴 것과 이유 / 사용자 스킬 결함 발견 시 그 내용.
```

- [ ] **Step 2: 실패하는 테스트 작성**

`tests/test-run-reviewer.sh`:

```bash
#!/bin/bash
# run-reviewer.sh 테스트 — claude는 PATH 스텁. 실행: bash tests/test-run-reviewer.sh
set -u
PKG="$(cd "$(dirname "$0")/.." && pwd)/growing-skills"
RUN="$PKG/bin/run-reviewer.sh"
PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "PASS: $1"; else FAIL=$((FAIL+1)); echo "FAIL: $1 (expected [$2] got [$3])"; fi; }

setup() {
  SB=$(mktemp -d)
  SKILLS="$SB/skills"; QUEUE="$SKILLS/.review-queue"
  PROPOSALS="$SB/proposals"; WIKI="$SB/wiki"
  mkdir -p "$QUEUE" "$PROPOSALS" "$WIKI/domains/dev/raw"
  printf '=== SESSION aaa (tools: 20) ===\n[USER] do x\n' > "$QUEUE/20260611-000001-aaa.md"
  printf '=== SESSION bbb (tools: 18) ===\n[USER] do y\n' > "$QUEUE/20260611-000002-bbb.md"
  # claude 스텁
  STUB="$SB/stub"; mkdir -p "$STUB"
  cat > "$STUB/claude" <<EOF
#!/bin/bash
printf '%s\n' "\$@" > "$SB/args.log"
echo "ANTHROPIC_API_KEY=\${ANTHROPIC_API_KEY:-UNSET}" > "$SB/env.log"
echo "GROWING_SKILLS_BG=\${GROWING_SKILLS_BG:-UNSET}" >> "$SB/env.log"
cat > "$SB/stdin.log"
[ "\${STUB_FAIL:-}" = "1" ] && exit 1
echo "리뷰 완료: 제안 1건"
EOF
  chmod +x "$STUB/claude"
}
teardown() { rm -rf "$SB"; }

run_reviewer() {
  PATH="$STUB:$PATH" GROWING_SKILLS_ROOT="$SKILLS" GROWING_SKILLS_HOME="$PKG" \
    GROWING_SKILLS_PROPOSALS_DIR="$PROPOSALS" WIKI_BODY_PATH="$WIKI" \
    GROWING_SKILLS_FORCE="${FORCE:-1}" bash "$RUN"
}

# T1: 신선한 락 → 실행 안 함, 큐 보존
setup
printf '%s\n%s\n' 99999 "$(date +%s)" > "$SKILLS/.reviewer.lock"
run_reviewer
assert_eq "T1 no claude run" "no" "$([ -f "$SB/args.log" ] && echo yes || echo no)"
assert_eq "T1 queue intact" "2" "$(ls "$QUEUE"/*.md | wc -l | tr -d ' ')"
teardown

# T2: stale 락(3시간 전) → 실행됨, 종료 후 락 해제
setup
printf '%s\n%s\n' 99999 "$(( $(date +%s) - 10800 ))" > "$SKILLS/.reviewer.lock"
run_reviewer
assert_eq "T2 claude ran" "yes" "$([ -f "$SB/args.log" ] && echo yes || echo no)"
assert_eq "T2 lock released" "no" "$([ -f "$SKILLS/.reviewer.lock" ] && echo yes || echo no)"
teardown

# T3: 일간 게이트 — 최근 실행 기록 + FORCE 미설정 → 스킵; FORCE=1 → 실행
setup
printf '{"last_run_at": %s}\n' "$(date +%s)" > "$SKILLS/.reviewer_state"
FORCE=0 run_reviewer
assert_eq "T3 gated skip" "no" "$([ -f "$SB/args.log" ] && echo yes || echo no)"
run_reviewer
assert_eq "T3 force runs" "yes" "$([ -f "$SB/args.log" ] && echo yes || echo no)"
teardown

# T4: 빈 큐 → 실행 안 함, 스탬프 안 찍음
setup
rm -f "$QUEUE"/*.md
run_reviewer
assert_eq "T4 no run" "no" "$([ -f "$SB/args.log" ] && echo yes || echo no)"
assert_eq "T4 no stamp" "no" "$([ -f "$SKILLS/.reviewer_state" ] && echo yes || echo no)"
teardown

# T5: 정상 실행 — 배치 stdin, 격리 env, 인자, 큐 이동, 보고서, write-ahead 스탬프
setup
run_reviewer
assert_eq "T5 report exists" "1" "$(ls "$SKILLS/.review-reports"/*.md 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "T5 queue drained" "0" "$(ls "$QUEUE"/*.md 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "T5 done has both" "2" "$(ls "$QUEUE/done"/*.md | wc -l | tr -d ' ')"
assert_eq "T5 stdin has aaa" "1" "$(grep -c "SESSION aaa" "$SB/stdin.log")"
assert_eq "T5 stdin has bbb" "1" "$(grep -c "SESSION bbb" "$SB/stdin.log")"
assert_eq "T5 api key unset" "1" "$(grep -c "ANTHROPIC_API_KEY=UNSET" "$SB/env.log")"
assert_eq "T5 bg marker" "1" "$(grep -c "GROWING_SKILLS_BG=1" "$SB/env.log")"
assert_eq "T5 strict mcp" "1" "$(grep -c -- "--strict-mcp-config" "$SB/args.log")"
assert_eq "T5 stamp written" "yes" "$([ -f "$SKILLS/.reviewer_state" ] && echo yes || echo no)"
teardown

# T6: claude 실패 → 큐 보존, 보고서에 실패 기록
setup
STUB_FAIL=1; export STUB_FAIL
run_reviewer
unset STUB_FAIL
assert_eq "T6 queue preserved" "2" "$(ls "$QUEUE"/*.md | wc -l | tr -d ' ')"
assert_eq "T6 failure noted" "1" "$(grep -c "실패" "$SKILLS/.review-reports"/*.md)"
teardown

echo "----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
```

- [ ] **Step 3: 실행 — 실패 확인**

Run: `bash tests/test-run-reviewer.sh`
Expected: FAIL (run-reviewer.sh 미존재)

- [ ] **Step 4: 구현**

`growing-skills/bin/run-reviewer.sh`:

```bash
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
```

Run: `chmod +x growing-skills/bin/run-reviewer.sh`

- [ ] **Step 5: 통과 확인**

Run: `bash tests/test-run-reviewer.sh`
Expected: `PASS=18 FAIL=0` (T1 2 + T2 2 + T3 2 + T4 2 + T5 9 + T6 2 — 합 19가 아닌 18: T5는 9건이 아니라 stdin 2건 포함 9건이므로 합계는 2+2+2+2+9+2=19. 실행 후 실제 카운트가 19면 19가 정답 — assert_eq 호출 수를 세서 일치 확인)
**주의: 구현자는 assert_eq 호출 수를 직접 세어 Expected를 확정하고, FAIL=0만을 합격 기준으로 삼는다.**

- [ ] **Step 6: 커밋**

```bash
git add growing-skills/prompts/reviewer-prompt.md tests/test-run-reviewer.sh growing-skills/bin/run-reviewer.sh
git commit -m "feat(growing-skills): 일간 배치 리뷰어 — 락·게이트·배치·격리 스폰·보고"
```

---

### Task 4: install/uninstall 확장 (TDD)

**Files:**
- Modify: `tests/test-install.sh` (T4 블록 뒤, 최종 echo 앞에 T5·T6 추가)
- Modify: `growing-skills/install.sh`
- Modify: `growing-skills/uninstall.sh`

- [ ] **Step 1: 테스트 추가**

`tests/test-install.sh`의 T4 teardown 뒤에 삽입:

```bash
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
```

- [ ] **Step 2: 실행 — 실패 확인**

Run: `bash tests/test-install.sh`
Expected: T5/T6 FAIL (기존 16건은 PASS)

- [ ] **Step 3: install.sh 확장**

`growing-skills/install.sh`에서 `# 3) CLAUDE.md에 독트린 추가` 블록 **앞에** 삽입:

```bash
# 2.5) Phase 2: 패키지(bin/prompts/settings) 배포 + SessionEnd 훅
mkdir -p "$CLAUDE_DIR/growing-skills/bin" "$CLAUDE_DIR/growing-skills/prompts" "$CLAUDE_DIR/growing-skills/settings"
cp "$PKG_DIR/bin/"*.sh "$CLAUDE_DIR/growing-skills/bin/"
chmod +x "$CLAUDE_DIR/growing-skills/bin/"*.sh
cp "$PKG_DIR/prompts/reviewer-prompt.md" "$CLAUDE_DIR/growing-skills/prompts/"
cp "$PKG_DIR/settings/headless-settings.json" "$CLAUDE_DIR/growing-skills/settings/"
cp "$PKG_DIR/hooks/session-end-queue.sh" "$CLAUDE_DIR/hooks/session-end-queue.sh"
chmod +x "$CLAUDE_DIR/hooks/session-end-queue.sh"

ALREADY_SE=$(jq '[.hooks.SessionEnd[]? | select((.hooks // []) | any(.command // "" | contains("session-end-queue.sh")))] | length' "$SETTINGS")
if [ "$ALREADY_SE" -eq 0 ]; then
  [ -f "$SETTINGS.bak.$TS" ] || cp "$SETTINGS" "$SETTINGS.bak.$TS"
  TMP=$(mktemp)
  jq '.hooks.SessionEnd = ((.hooks.SessionEnd // []) + [{
        "hooks": [{"type": "command",
                   "command": "~/.claude/hooks/session-end-queue.sh",
                   "timeout": 60}]
      }])' "$SETTINGS" > "$TMP"
  jq -e . "$TMP" >/dev/null
  mv "$TMP" "$SETTINGS"
  echo "settings.json: SessionEnd 훅 추가"
else
  echo "settings.json: SessionEnd 이미 설치됨 — 건너뜀"
fi
```

- [ ] **Step 4: uninstall.sh 확장**

`growing-skills/uninstall.sh`에서 settings 처리 jq 프로그램을 다음으로 교체 (PostToolUse 제거에 SessionEnd 제거 추가):

```bash
  jq 'if .hooks.PostToolUse then
        .hooks.PostToolUse = [.hooks.PostToolUse[] | select(.matcher != "Skill")]
        | if (.hooks.PostToolUse | length) == 0 then del(.hooks.PostToolUse) else . end
      else . end
      | if .hooks.SessionEnd then
        .hooks.SessionEnd = [.hooks.SessionEnd[] | select((.hooks // []) | any(.command // "" | contains("session-end-queue.sh")) | not)]
        | if (.hooks.SessionEnd | length) == 0 then del(.hooks.SessionEnd) else . end
      else . end' "$SETTINGS" > "$TMP"
```

그리고 `rm -f "$CLAUDE_DIR/hooks/skill-telemetry.sh"` 다음 줄에 추가:

```bash
rm -f "$CLAUDE_DIR/hooks/session-end-queue.sh"
rm -rf "$CLAUDE_DIR/growing-skills"
```

- [ ] **Step 5: 통과 확인 + 전체 회귀**

Run: `bash tests/test-install.sh && bash tests/test-telemetry-hook.sh && bash tests/test-digest.sh && bash tests/test-queue-hook.sh && bash tests/test-run-reviewer.sh`
Expected: 전부 `FAIL=0` (test-install은 `PASS=24`)

- [ ] **Step 6: 커밋**

```bash
git add tests/test-install.sh growing-skills/install.sh growing-skills/uninstall.sh
git commit -m "feat(growing-skills): install/uninstall Phase 2 확장 — 패키지 배포·SessionEnd 머지"
```

---

### Task 5: 실배포 + 실 리뷰어 스모크 (메인 세션에서 — 실환경 변경)

> 사용자 실환경(settings.json, ~/.claude/growing-skills)을 변경하고 실제 sonnet 헤드리스 1회를 소비하므로 **메인 세션에서 직접** 수행.

- [ ] **Step 1: 설치** — Run: `bash growing-skills/install.sh` / Expected: SessionEnd 추가 + 패키지 배포 메시지
- [ ] **Step 2: 무결성** — Run: `jq -e '.hooks.SessionEnd' ~/.claude/settings.json && ls ~/.claude/growing-skills/bin/`
- [ ] **Step 3: 큐 적재 스모크** — 이 세션의 실제 트랜스크립트로 훅을 NO_SPAWN 모드로 직접 구동, 큐 파일과 마스킹 확인
- [ ] **Step 4: 실 리뷰어 스모크** — `GROWING_SKILLS_FORCE=1 bash ~/.claude/growing-skills/bin/run-reviewer.sh` 후 `.review-reports/` 보고서와 `~/.claude/skill-proposals/` 확인. **권한 문법(`Write(/...)`)이 실동작하는지 이 단계가 최종 검증** — 거부되면 보고서에 권한 오류가 남으므로 문법 조정
- [ ] **Step 5: 배포 기록 커밋 + main 머지**

---

## Self-Review 결과

- **스펙 커버리지**: Layer 3 전체(큐·일간 배치·재귀 가드 4종·전처리/마스킹·프롬프트 사다리/블랙리스트·재시도 없음) + §4.5 위키 연동(리뷰어 이중 산출, dev만, raw 노트 관례) = Task 1-5. `.archive/` 복원 확인은 Plan 3에서 아카이브가 생긴 뒤 프롬프트에 추가(현재 아카이브 부재) — 스펙의 해당 항목은 Plan 3로 이월 명시.
- **Placeholder 스캔**: 통과 — 전 코드·프롬프트 전문 포함. 단 Task 3 Step 5의 PASS 카운트는 구현자가 assert 수를 직접 세도록 명시(이전 플랜의 오프-바이-원 재발 방지).
- **이름 일관성**: `GROWING_SKILLS_ROOT/HOME/PROJECTS_DIR/MIN_TOOLS/NO_SPAWN/PROPOSALS_DIR/FORCE/MODEL/BG`, `.review-queue/done`, `.reviewer_state`, `.reviewer.lock`, `.review-reports` — 훅·리뷰어·테스트·설치 간 일치 확인.
