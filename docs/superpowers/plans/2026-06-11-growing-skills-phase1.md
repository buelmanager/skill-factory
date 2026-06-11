# growing-skills Phase 1 (기반: 텔레메트리 + 독트린) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Claude Code 자기 성장 스킬 시스템(growing-skills)의 기반 — 스킬 사용 텔레메트리 훅과 지식 라우팅 독트린 — 을 구현·설치한다.

**Architecture:** PostToolUse(Skill) 훅이 글로벌 스킬 호출을 append-only JSONL(`~/.claude/skills/.usage-events.jsonl`)에 기록하고, `~/.claude/CLAUDE.md`의 독트린 섹션이 지식 라우팅(절차→스킬, 사실→위키, 에피소드→트랜스크립트)을 상시 주입한다. 이 데이터/규칙 위에 Plan 2(리뷰어)·Plan 3(큐레이터)가 올라간다. 스펙: `docs/superpowers/specs/2026-06-11-growing-skills-design.md`.

**Tech Stack:** bash(macOS 3.2 호환), jq 1.8.1, Claude Code hooks (v2.1.172).

**확정된 스파이크 사실 (2026-06-11 실측·문서 검증):**
- `~/.claude/skills` 아래 점(.) 디렉터리는 스킬 디스커버리에 보이지 않음 (실험: `.spike-archive/` 내 스킬 NO, 일반 디렉터리 YES)
- PostToolUse 훅 stdin: `{"session_id", "cwd", "hook_event_name", "tool_name": "Skill", "tool_input": {"skill": "<name>", "args": ...}}`. matcher `"Skill"` 지원
- 훅 timeout 단위는 초(설정 시), 기본 600초. SessionStart/SessionEnd는 블록 불가, SessionStart stdout은 컨텍스트 주입됨
- 헤드리스 `claude -p`: `--settings`(훅 오버라이드), `--strict-mcp-config`, `--allowedTools`(permission rule 문법), `--model` 확인됨
- **이 환경의 셸은 `ANTHROPIC_API_KEY`를 상속 — 훅/스폰된 claude는 `env -u ANTHROPIC_API_KEY` 없이는 구독 인증 대신 API 과금 시도 ("Credit balance is too low" 실측)**
- jq 1.8.1 (`/opt/homebrew/bin/jq`), 사용자 settings.json에 기존 훅 3종 존재 (UserPromptSubmit, PreToolUse×2)

**파일 구조:**
```
skill-factory/
├── growing-skills/                      # 시스템 패키지 (배포 원본)
│   ├── hooks/skill-telemetry.sh         # PostToolUse(Skill) 텔레메트리 훅
│   ├── doctrine/doctrine.md             # CLAUDE.md에 추가할 독트린 블록
│   ├── install.sh                       # 훅 복사 + settings.json 머지 + 독트린 추가 (백업·멱등)
│   └── uninstall.sh                     # 역순 제거 + 복원
└── tests/
    ├── test-telemetry-hook.sh           # 훅 단위 테스트
    └── test-install.sh                  # 설치/제거 테스트 (샌드박스 HOME)
```

---

### Task 1: 텔레메트리 훅 — 기본 동작 (TDD)

**Files:**
- Create: `tests/test-telemetry-hook.sh`
- Create: `growing-skills/hooks/skill-telemetry.sh`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test-telemetry-hook.sh`:

```bash
#!/bin/bash
# growing-skills telemetry hook tests. 실행: bash tests/test-telemetry-hook.sh
set -u
HOOK="$(cd "$(dirname "$0")/.." && pwd)/growing-skills/hooks/skill-telemetry.sh"
PASS=0; FAIL=0

setup() {
  TESTROOT=$(mktemp -d)
  mkdir -p "$TESTROOT/known-skill"
  printf -- "---\nname: known-skill\ndescription: test\n---\nbody\n" > "$TESTROOT/known-skill/SKILL.md"
  EVENTS="$TESTROOT/.usage-events.jsonl"
}
teardown() { rm -rf "$TESTROOT"; }

assert_eq() { # desc expected actual
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "PASS: $1";
  else FAIL=$((FAIL+1)); echo "FAIL: $1 (expected [$2] got [$3])"; fi
}

payload() { # skill_name
  printf '{"session_id":"sess-1","cwd":"/tmp","hook_event_name":"PostToolUse","tool_name":"Skill","tool_input":{"skill":"%s"}}' "$1"
}

# T1: 알려진 글로벌 스킬 → 이벤트 1줄 append
setup
payload "known-skill" | GROWING_SKILLS_ROOT="$TESTROOT" bash "$HOOK"
assert_eq "T1 exit code" "0" "$?"
assert_eq "T1 one line appended" "1" "$(wc -l < "$EVENTS" 2>/dev/null | tr -d ' ')"
assert_eq "T1 skill field" "known-skill" "$(jq -r '.skill' "$EVENTS")"
assert_eq "T1 event field" "use" "$(jq -r '.event' "$EVENTS")"
assert_eq "T1 session field" "sess-1" "$(jq -r '.session' "$EVENTS")"
assert_eq "T1 ts is ISO8601" "ok" "$(jq -r '.ts' "$EVENTS" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$' && echo ok)"
teardown

# T2: 백그라운드 마커 → 기록 안 함
setup
payload "known-skill" | GROWING_SKILLS_BG=1 GROWING_SKILLS_ROOT="$TESTROOT" bash "$HOOK"
assert_eq "T2 exit 0" "0" "$?"
assert_eq "T2 no file" "no" "$([ -f "$EVENTS" ] && echo yes || echo no)"
teardown

echo "----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

Run: `bash tests/test-telemetry-hook.sh`
Expected: FAIL (혹은 hook 파일 없음 에러) — `skill-telemetry.sh` 미존재

- [ ] **Step 3: 최소 구현**

`growing-skills/hooks/skill-telemetry.sh`:

```bash
#!/bin/bash
# growing-skills: PostToolUse(Skill) 텔레메트리 — 글로벌 스킬 사용을 append-only JSONL에 기록.
# 어떤 경우에도 도구 호출을 막지 않는다: 항상 exit 0.
[ "${GROWING_SKILLS_BG:-}" = "1" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

SKILLS_ROOT="${GROWING_SKILLS_ROOT:-$HOME/.claude/skills}"
INPUT=$(cat)
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# jq가 필터링과 JSON 직렬화를 모두 담당 (스킬명에 특수문자가 있어도 안전한 JSON 보장).
# 플러그인 네임스페이스 스킬(plugin:skill)은 제외.
LINE=$(printf '%s' "$INPUT" | jq -c --arg ts "$TS" '
  (.tool_input.skill // empty) as $s
  | select($s != "" and (($s | contains(":")) | not))
  | {ts: $ts, skill: $s, event: "use", session: (.session_id // "unknown")}' 2>/dev/null)
[ -z "$LINE" ] && exit 0

SKILL=$(printf '%s' "$LINE" | jq -r '.skill')
[ -f "$SKILLS_ROOT/$SKILL/SKILL.md" ] || exit 0   # 글로벌 스킬만 집계

printf '%s\n' "$LINE" >> "$SKILLS_ROOT/.usage-events.jsonl" 2>/dev/null
exit 0
```

Run: `chmod +x growing-skills/hooks/skill-telemetry.sh`

- [ ] **Step 4: 테스트 통과 확인**

Run: `bash tests/test-telemetry-hook.sh`
Expected: `PASS=8 FAIL=0` (T1 6건 + T2 2건)

- [ ] **Step 5: 커밋**

```bash
git add tests/test-telemetry-hook.sh growing-skills/hooks/skill-telemetry.sh
git commit -m "feat(growing-skills): 스킬 사용 텔레메트리 훅 — 기본 동작"
```

---

### Task 2: 텔레메트리 훅 — 필터·견고성 (TDD)

**Files:**
- Modify: `tests/test-telemetry-hook.sh` (T2 블록과 마지막 `echo "----"` 사이에 추가)

- [ ] **Step 1: 실패/엣지 테스트 추가**

`tests/test-telemetry-hook.sh`의 T2 teardown 다음에 삽입:

```bash
# T3: 플러그인 스킬(콜론 포함) → 기록 안 함
setup
payload "superpowers:writing-skills" | GROWING_SKILLS_ROOT="$TESTROOT" bash "$HOOK"
assert_eq "T3 no file" "no" "$([ -f "$EVENTS" ] && echo yes || echo no)"
teardown

# T4: 글로벌에 없는 스킬 → 기록 안 함
setup
payload "nonexistent-skill" | GROWING_SKILLS_ROOT="$TESTROOT" bash "$HOOK"
assert_eq "T4 no file" "no" "$([ -f "$EVENTS" ] && echo yes || echo no)"
teardown

# T5: 깨진 JSON → exit 0, 기록 안 함
setup
printf 'not-json{{{' | GROWING_SKILLS_ROOT="$TESTROOT" bash "$HOOK"
assert_eq "T5 exit 0" "0" "$?"
assert_eq "T5 no file" "no" "$([ -f "$EVENTS" ] && echo yes || echo no)"
teardown

# T6: Skill 외 도구 페이로드(tool_input에 skill 없음) → 기록 안 함
setup
printf '{"session_id":"s","tool_name":"Bash","tool_input":{"command":"ls"}}' \
  | GROWING_SKILLS_ROOT="$TESTROOT" bash "$HOOK"
assert_eq "T6 no file" "no" "$([ -f "$EVENTS" ] && echo yes || echo no)"
teardown

# T7: 동시 append 10개 → 10줄 전부 온전한 JSON (O_APPEND 원자성)
setup
for i in $(seq 1 10); do
  payload "known-skill" | GROWING_SKILLS_ROOT="$TESTROOT" bash "$HOOK" &
done
wait
assert_eq "T7 ten lines" "10" "$(wc -l < "$EVENTS" | tr -d ' ')"
assert_eq "T7 all valid json" "10" "$(jq -c . "$EVENTS" 2>/dev/null | wc -l | tr -d ' ')"
teardown
```

- [ ] **Step 2: 테스트 실행**

Run: `bash tests/test-telemetry-hook.sh`
Expected: `PASS=16 FAIL=0` — Task 1 구현이 이미 필터를 포함하므로 통과해야 정상. FAIL이 나오면 훅의 해당 필터 로직을 수정한다 (구현 기준은 Task 1 Step 3 코드).

- [ ] **Step 3: 커밋**

```bash
git add tests/test-telemetry-hook.sh
git commit -m "test(growing-skills): 텔레메트리 훅 필터·견고성·동시성 테스트"
```

---

### Task 3: 독트린 문서

**Files:**
- Create: `growing-skills/doctrine/doctrine.md`

- [ ] **Step 1: 독트린 작성**

`growing-skills/doctrine/doctrine.md` (전문):

```markdown
<!-- growing-skills-doctrine:begin -->
## 스킬 성장 독트린 (growing-skills)

배운 것은 유형별로 한 곳에만 적는다:

| 지식 유형 | 귀속처 |
|---|---|
| 절차 ("어떻게 X를 한다") | 스킬 (`~/.claude/skills`) |
| 도메인 사실·결정·프로젝트 맥락 | 글로벌 위키 (`/wiki-checkpoint` 또는 `llm-wiki-body/domains/<d>/raw/`) |
| 에피소드 (무슨 일이 있었나) | 트랜스크립트 — 따로 적지 않는다 |

스킬 사용 규칙:
1. 작업과 부분적으로라도 관련된 스킬이 보이면 로드해서 확인한다.
2. 로드한 스킬이 실제와 다르거나 낡았으면 그 자리에서 패치하고, 수정 사실을 사용자에게 보고한다. 단 외부 설치 스킬(플러그인·gstack)은 패치 대신 사용자에게 보고만 한다.
3. 5회 이상의 도구 호출이 든 작업을 끝냈고 그 절차가 재사용 가능하면, 스킬로 저장할 가치가 있는지 사용자에게 제안한다. 자격증명·토큰·시크릿은 어떤 형태로도 스킬 텍스트에 넣지 않는다.
<!-- growing-skills-doctrine:end -->
```

- [ ] **Step 2: 검증**

Run: `grep -c "growing-skills-doctrine" growing-skills/doctrine/doctrine.md && wc -w growing-skills/doctrine/doctrine.md`
Expected: `2` (begin/end 마커) / 단어 수 200 미만

- [ ] **Step 3: 커밋**

```bash
git add growing-skills/doctrine/doctrine.md
git commit -m "feat(growing-skills): 지식 라우팅 독트린"
```

---

### Task 4: install / uninstall 스크립트 (TDD, 샌드박스 HOME)

**Files:**
- Create: `tests/test-install.sh`
- Create: `growing-skills/install.sh`
- Create: `growing-skills/uninstall.sh`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test-install.sh`:

```bash
#!/bin/bash
# install/uninstall 테스트 — 샌드박스 CLAUDE_DIR 에서만 동작 확인. 실행: bash tests/test-install.sh
set -u
PKG="$(cd "$(dirname "$0")/.." && pwd)/growing-skills"
PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "PASS: $1"; else FAIL=$((FAIL+1)); echo "FAIL: $1 (expected [$2] got [$3])"; fi; }

setup() {
  SANDBOX=$(mktemp -d)
  mkdir -p "$SANDBOX/.claude/hooks" "$SANDBOX/.claude/skills"
  # 기존 훅이 있는 settings.json 시뮬레이션 (실사용자 환경과 동일 구조)
  cat > "$SANDBOX/.claude/settings.json" <<'EOF'
{
  "env": {"EXISTING": "1"},
  "hooks": {
    "UserPromptSubmit": [
      {"hooks": [{"type": "command", "command": "~/.claude/hooks/existing.sh", "timeout": 3000}]}
    ]
  }
}
EOF
  echo "# 기존 내용" > "$SANDBOX/.claude/CLAUDE.md"
}
teardown() { rm -rf "$SANDBOX"; }

# T1: install — 훅 파일 복사 + settings 머지 + 독트린 추가 + 백업 생성
setup
GROWING_SKILLS_CLAUDE_DIR="$SANDBOX/.claude" bash "$PKG/install.sh" >/dev/null
assert_eq "T1 hook copied" "yes" "$([ -x "$SANDBOX/.claude/hooks/skill-telemetry.sh" ] && echo yes || echo no)"
assert_eq "T1 settings valid json" "yes" "$(jq -e . "$SANDBOX/.claude/settings.json" >/dev/null 2>&1 && echo yes || echo no)"
assert_eq "T1 PostToolUse Skill matcher" "Skill" "$(jq -r '.hooks.PostToolUse[] | select(.matcher=="Skill") | .matcher' "$SANDBOX/.claude/settings.json")"
assert_eq "T1 existing hook preserved" "1" "$(jq '.hooks.UserPromptSubmit | length' "$SANDBOX/.claude/settings.json")"
assert_eq "T1 env preserved" "1" "$(jq -r '.env.EXISTING' "$SANDBOX/.claude/settings.json")"
assert_eq "T1 doctrine appended" "1" "$(grep -c "growing-skills-doctrine:begin" "$SANDBOX/.claude/CLAUDE.md")"
assert_eq "T1 settings backup exists" "yes" "$(ls "$SANDBOX/.claude/"settings.json.bak.* >/dev/null 2>&1 && echo yes || echo no)"

# T2: install 멱등성 — 재실행해도 중복 없음
GROWING_SKILLS_CLAUDE_DIR="$SANDBOX/.claude" bash "$PKG/install.sh" >/dev/null
assert_eq "T2 one PostToolUse entry" "1" "$(jq '[.hooks.PostToolUse[] | select(.matcher=="Skill")] | length' "$SANDBOX/.claude/settings.json")"
assert_eq "T2 one doctrine block" "1" "$(grep -c "growing-skills-doctrine:begin" "$SANDBOX/.claude/CLAUDE.md")"

# T3: uninstall — 훅 항목 제거 + 독트린 제거 + 기존 설정 보존
GROWING_SKILLS_CLAUDE_DIR="$SANDBOX/.claude" bash "$PKG/uninstall.sh" >/dev/null
assert_eq "T3 PostToolUse Skill removed" "0" "$(jq '[.hooks.PostToolUse[]? | select(.matcher=="Skill")] | length' "$SANDBOX/.claude/settings.json")"
assert_eq "T3 existing hook still there" "1" "$(jq '.hooks.UserPromptSubmit | length' "$SANDBOX/.claude/settings.json")"
assert_eq "T3 doctrine removed" "0" "$(grep -c "growing-skills-doctrine:begin" "$SANDBOX/.claude/CLAUDE.md")"
assert_eq "T3 original content intact" "1" "$(grep -c "^# 기존 내용" "$SANDBOX/.claude/CLAUDE.md")"
teardown

echo "----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

Run: `bash tests/test-install.sh`
Expected: FAIL (install.sh 미존재)

- [ ] **Step 3: install.sh 구현**

`growing-skills/install.sh`:

```bash
#!/bin/bash
# growing-skills Phase 1 설치: 텔레메트리 훅 + 독트린.
# GROWING_SKILLS_CLAUDE_DIR 로 대상 디렉터리 오버라이드 가능 (테스트용). 기본 ~/.claude.
set -euo pipefail
PKG_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="${GROWING_SKILLS_CLAUDE_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"
TS=$(date +%Y%m%d%H%M%S)

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq가 필요합니다"; exit 1; }
[ -f "$SETTINGS" ] || { echo "ERROR: $SETTINGS 없음"; exit 1; }

# 1) 훅 스크립트 복사
mkdir -p "$CLAUDE_DIR/hooks"
cp "$PKG_DIR/hooks/skill-telemetry.sh" "$CLAUDE_DIR/hooks/skill-telemetry.sh"
chmod +x "$CLAUDE_DIR/hooks/skill-telemetry.sh"

# 2) settings.json 백업 후 PostToolUse(Skill) 훅 머지 (멱등)
ALREADY=$(jq '[.hooks.PostToolUse[]? | select(.matcher=="Skill")] | length' "$SETTINGS")
if [ "$ALREADY" -eq 0 ]; then
  cp "$SETTINGS" "$SETTINGS.bak.$TS"
  TMP=$(mktemp)
  jq '.hooks.PostToolUse = ((.hooks.PostToolUse // []) + [{
        "matcher": "Skill",
        "hooks": [{"type": "command",
                   "command": "~/.claude/hooks/skill-telemetry.sh",
                   "timeout": 5}]
      }])' "$SETTINGS" > "$TMP"
  jq -e . "$TMP" >/dev/null   # 결과 JSON 유효성 확인 후에만 교체
  mv "$TMP" "$SETTINGS"
  echo "settings.json: PostToolUse(Skill) 훅 추가 (백업: settings.json.bak.$TS)"
else
  echo "settings.json: 이미 설치됨 — 건너뜀"
fi

# 3) CLAUDE.md에 독트린 추가 (마커 기준 멱등)
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
touch "$CLAUDE_MD"
if ! grep -q "growing-skills-doctrine:begin" "$CLAUDE_MD"; then
  cp "$CLAUDE_MD" "$CLAUDE_MD.bak.$TS"
  printf '\n' >> "$CLAUDE_MD"
  cat "$PKG_DIR/doctrine/doctrine.md" >> "$CLAUDE_MD"
  echo "CLAUDE.md: 독트린 추가 (백업: CLAUDE.md.bak.$TS)"
else
  echo "CLAUDE.md: 독트린 이미 존재 — 건너뜀"
fi

echo "설치 완료. 새 세션부터 적용됩니다."
```

- [ ] **Step 4: uninstall.sh 구현**

`growing-skills/uninstall.sh`:

```bash
#!/bin/bash
# growing-skills Phase 1 제거: 훅 항목·독트린 제거. 이벤트 데이터(.usage-events.jsonl)는 보존.
set -euo pipefail
CLAUDE_DIR="${GROWING_SKILLS_CLAUDE_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"
TS=$(date +%Y%m%d%H%M%S)

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq가 필요합니다"; exit 1; }

if [ -f "$SETTINGS" ]; then
  cp "$SETTINGS" "$SETTINGS.bak.$TS"
  TMP=$(mktemp)
  jq 'if .hooks.PostToolUse then
        .hooks.PostToolUse = [.hooks.PostToolUse[] | select(.matcher != "Skill")]
        | if (.hooks.PostToolUse | length) == 0 then del(.hooks.PostToolUse) else . end
      else . end' "$SETTINGS" > "$TMP"
  jq -e . "$TMP" >/dev/null
  mv "$TMP" "$SETTINGS"
fi

rm -f "$CLAUDE_DIR/hooks/skill-telemetry.sh"

CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
if [ -f "$CLAUDE_MD" ] && grep -q "growing-skills-doctrine:begin" "$CLAUDE_MD"; then
  cp "$CLAUDE_MD" "$CLAUDE_MD.bak.$TS"
  TMP=$(mktemp)
  sed '/<!-- growing-skills-doctrine:begin -->/,/<!-- growing-skills-doctrine:end -->/d' "$CLAUDE_MD" > "$TMP"
  mv "$TMP" "$CLAUDE_MD"
fi

echo "제거 완료. 이벤트 데이터는 보존됨: $CLAUDE_DIR/skills/.usage-events.jsonl"
```

Run: `chmod +x growing-skills/install.sh growing-skills/uninstall.sh`

- [ ] **Step 5: 테스트 통과 확인**

Run: `bash tests/test-install.sh`
Expected: `PASS=12 FAIL=0`

- [ ] **Step 6: 전체 테스트 재실행 (회귀)**

Run: `bash tests/test-telemetry-hook.sh && bash tests/test-install.sh`
Expected: 둘 다 `FAIL=0`

- [ ] **Step 7: 커밋**

```bash
git add tests/test-install.sh growing-skills/install.sh growing-skills/uninstall.sh
git commit -m "feat(growing-skills): install/uninstall — settings 머지·독트린·백업·멱등"
```

---

### Task 5: 실제 배포 + 스모크 검증 (메인 세션에서 — 사용자 settings.json 변경)

**Files:**
- Modify: `~/.claude/settings.json`, `~/.claude/CLAUDE.md` (install.sh 경유)

> 이 태스크는 사용자 실환경을 변경하므로 **메인 세션에서 직접** 수행한다 (서브에이전트 위임 금지 — dev-lifecycle의 irreversible-gate 규칙).

- [ ] **Step 1: 설치 실행**

Run: `bash growing-skills/install.sh`
Expected: "PostToolUse(Skill) 훅 추가" + "독트린 추가" + 백업 파일명 출력

- [ ] **Step 2: 설정 무결성 확인**

Run: `jq -e '.hooks.PostToolUse[] | select(.matcher=="Skill")' ~/.claude/settings.json && grep -c "growing-skills-doctrine:begin" ~/.claude/CLAUDE.md`
Expected: 훅 객체 출력 + `1`

- [ ] **Step 3: 실거동 스모크 — 훅을 실제 페이로드로 직접 실행**

Run:
```bash
printf '{"session_id":"smoke","tool_name":"Skill","tool_input":{"skill":"dev-lifecycle"}}' \
  | bash ~/.claude/hooks/skill-telemetry.sh
tail -1 ~/.claude/skills/.usage-events.jsonl
```
Expected: `{"ts":"...","skill":"dev-lifecycle","event":"use","session":"smoke"}`

- [ ] **Step 4: 커밋 (배포 기록)**

```bash
git add -A && git commit -m "chore(growing-skills): Phase 1 실배포 완료 기록"
```

---

## Self-Review 결과

- **스펙 커버리지**: Layer 0(이벤트 파일)·Layer 1(독트린)·Layer 2(텔레메트리) = Task 1-5. Layer 3(리뷰어+위키)·Layer 4/5(큐레이터)는 Plan 2/3으로 명시 분할 — 스펙 4.5/5절의 해당 항목은 이 플랜 범위 아님.
- **Placeholder 스캔**: 통과 — 모든 코드 전문 포함.
- **타입/이름 일관성**: `GROWING_SKILLS_ROOT`(훅 테스트용), `GROWING_SKILLS_CLAUDE_DIR`(설치 테스트용), 마커 `growing-skills-doctrine:begin/end`, 이벤트 스키마 `{ts,skill,event,session}` — 태스크 간 일치 확인.
