# dev-lifecycle into skill-factory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** dev-lifecycle/preserving-main-context의 SsoT를 skill-factory로 옮기고(symlink 배포), 오케스트레이션 판단(스킬·스테이지 적합성 / 모델 선택)을 test-scenarios로 고정해 회귀 없이 성장시킨다.

**Architecture:** SsoT는 `skill-factory/skills/<name>/SKILL.md`, 런타임은 `~/.claude/skills/<name>` → SsoT 디렉터리 심링크(드리프트 0). 멱등·안전한 `bin/link-skills.sh`가 심링크를 생성/재현하고, 실제 디렉터리는 백업 후 교체(하드 삭제 금지). 밑단 gstack/superpowers 스킬은 불변.

**Tech Stack:** bash(`set -euo pipefail`), jq, 기존 skill-factory 테스트 관용구(`assert_eq` + `mktemp -d` 샌드박스 + `*_CLAUDE_DIR` env 오버라이드), 마크다운 test-scenarios(RED/GREEN/REFACTOR).

**Spec:** `docs/superpowers/specs/2026-06-12-dev-lifecycle-into-factory-design.md`
**Branch:** `feat/dev-lifecycle-into-factory` (main 분기). Worktree 불필요 — 위험 지점은 repo 밖 `~/.claude/skills` 심링크라 worktree로 격리 불가, 대신 Task 3의 수동 검증 게이트로 방어.

---

## File Structure

| 파일 | 책임 |
|---|---|
| `skills/dev-lifecycle/SKILL.md` | (이전) dev-lifecycle SsoT |
| `skills/preserving-main-context/SKILL.md` | (이전) preserving-main-context SsoT |
| `bin/link-skills.sh` | `skills/*` → `~/.claude/skills/` 멱등·안전 심링크 |
| `tests/test-link-skills.sh` | link-skills.sh 단위 테스트(샌드박스) |
| `test-scenarios/dev-lifecycle.md` | 2축 결정 회귀 시나리오 (축① S1–S5, 축② M1–M4) |
| `test-scenarios/preserving-main-context.md` | 위임 판단 시나리오 (≥2) |
| `docs/superpowers/decisions/dev-lifecycle-decision-log.md` | 상황→선택 개정 이력 (Fable 5 시드) |

---

## Task 1: Bootstrap — 라이브 SsoT를 repo로 이전 (백포트)

라이브 `~/.claude/skills/{dev-lifecycle,preserving-main-context}/`(=Model Profile 편집 포함본)를 repo로 복사. 이 복사가 곧 백포트다. **아직 심링크하지 않는다** — 내용을 git에 넣기만.

**Files:**
- Create: `skills/dev-lifecycle/SKILL.md` (라이브에서 복사)
- Create: `skills/preserving-main-context/SKILL.md` (라이브에서 복사)

- [ ] **Step 1: repo skills 디렉터리로 라이브 내용 복사**

```bash
cd "$(git rev-parse --show-toplevel)"   # skill-factory 루트
mkdir -p skills
cp -R ~/.claude/skills/dev-lifecycle skills/dev-lifecycle
cp -R ~/.claude/skills/preserving-main-context skills/preserving-main-context
```

- [ ] **Step 2: 복사 무결성 검증 (diff 0)**

Run:
```bash
diff -r ~/.claude/skills/dev-lifecycle skills/dev-lifecycle && \
diff -r ~/.claude/skills/preserving-main-context skills/preserving-main-context && echo "DIFF_OK"
```
Expected: `DIFF_OK` (차이 없음). 차이가 있으면 멈추고 원인 확인.

- [ ] **Step 3: Model Profile 백포트 확인**

Run:
```bash
grep -c "Per-Stage Model Profile" skills/dev-lifecycle/SKILL.md
```
Expected: `1` (2026-06-12 편집이 repo로 넘어왔는지 확인).

- [ ] **Step 4: Commit**

```bash
git add skills/dev-lifecycle skills/preserving-main-context
git commit -m "feat(skills): dev-lifecycle·preserving-main-context SsoT를 factory로 이전

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: link-skills.sh (TDD)

`skills/*`를 `~/.claude/skills/`로 심링크하는 멱등·안전 스크립트. 실제 디렉터리는 백업 후 교체, 이미 올바른 심링크면 skip, 잘못된 심링크는 백업 없이 교체.

**Files:**
- Create: `tests/test-link-skills.sh`
- Create: `bin/link-skills.sh`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test-link-skills.sh`:
```bash
#!/bin/bash
# link-skills.sh 테스트 — 샌드박스에서만. 실행: bash tests/test-link-skills.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/bin/link-skills.sh"
PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "PASS: $1"; else FAIL=$((FAIL+1)); echo "FAIL: $1 (expected [$2] got [$3])"; fi; }

setup() {
  SB=$(mktemp -d)
  mkdir -p "$SB/repo/skills/alpha" "$SB/repo/skills/beta" "$SB/claude/skills"
  echo "alpha-content" > "$SB/repo/skills/alpha/SKILL.md"
  echo "beta-content"  > "$SB/repo/skills/beta/SKILL.md"
}
teardown() { rm -rf "$SB"; }
run() { SKILL_FACTORY_SKILLS_DIR="$SB/repo/skills" SKILL_FACTORY_CLAUDE_DIR="$SB/claude" bash "$SCRIPT" >/dev/null 2>&1; }

# T1: 새 링크 생성 + 심링크 통해 내용 읽힘
setup; run
assert_eq "T1 alpha symlink"     "yes"          "$([ -L "$SB/claude/skills/alpha" ] && echo yes || echo no)"
assert_eq "T1 alpha→repo"        "$SB/repo/skills/alpha" "$(readlink "$SB/claude/skills/alpha")"
assert_eq "T1 content via link"  "alpha-content" "$(cat "$SB/claude/skills/alpha/SKILL.md")"
assert_eq "T1 beta symlink"      "yes"          "$([ -L "$SB/claude/skills/beta" ] && echo yes || echo no)"

# T2: 멱등 — 재실행해도 백업 churn 없음
run
assert_eq "T2 alpha still symlink" "yes" "$([ -L "$SB/claude/skills/alpha" ] && echo yes || echo no)"
assert_eq "T2 no backups created"  "no"  "$([ -d "$SB/claude/skills/.factory-backups" ] && echo yes || echo no)"
teardown

# T3: 타깃이 실제 디렉터리 → 백업 후 심링크 교체 (데이터 손실 0)
setup
mkdir -p "$SB/claude/skills/alpha"; echo "OLD-LIVE" > "$SB/claude/skills/alpha/SKILL.md"
run
assert_eq "T3 now symlink"      "yes"           "$([ -L "$SB/claude/skills/alpha" ] && echo yes || echo no)"
assert_eq "T3 content from repo" "alpha-content" "$(cat "$SB/claude/skills/alpha/SKILL.md")"
assert_eq "T3 old backed up"     "OLD-LIVE"      "$(cat "$SB/claude/skills/.factory-backups/alpha."*/SKILL.md)"
teardown

# T4: 잘못된 심링크 → 백업 없이 재지정
setup
ln -s "/nonexistent/path" "$SB/claude/skills/alpha"
run
assert_eq "T4 repointed" "$SB/repo/skills/alpha" "$(readlink "$SB/claude/skills/alpha")"
teardown

echo "----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: 테스트 실행해 실패 확인**

Run: `bash tests/test-link-skills.sh`
Expected: FAIL (스크립트 없음 — `bin/link-skills.sh: No such file` → 모든 assert FAIL 또는 비정상 종료).

- [ ] **Step 3: link-skills.sh 구현**

`bin/link-skills.sh`:
```bash
#!/bin/bash
# skill-factory의 skills/* 를 ~/.claude/skills/ 로 심링크. 멱등·안전(실제 디렉터리는 백업 후 교체, 하드 삭제 금지).
# SKILL_FACTORY_CLAUDE_DIR / SKILL_FACTORY_SKILLS_DIR 로 오버라이드 가능 (테스트용). 기본 repo/skills → ~/.claude/skills.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="${SKILL_FACTORY_SKILLS_DIR:-$ROOT/skills}"
CLAUDE_DIR="${SKILL_FACTORY_CLAUDE_DIR:-$HOME/.claude}"
DEST="$CLAUDE_DIR/skills"
TS=$(date +%Y%m%d%H%M%S)

[ -d "$SKILLS_DIR" ] || { echo "ERROR: $SKILLS_DIR 없음"; exit 1; }
mkdir -p "$DEST"

for src in "$SKILLS_DIR"/*/; do
  [ -d "$src" ] || continue
  name="$(basename "$src")"
  abs="$(cd "$src" && pwd)"
  target="$DEST/$name"

  if [ -L "$target" ]; then
    [ "$(readlink "$target")" = "$abs" ] && { echo "skip (already linked): $name"; continue; }
    rm "$target"                      # 잘못된 심링크 — 데이터 아님, 백업 불필요
  elif [ -e "$target" ]; then
    mkdir -p "$DEST/.factory-backups" # 실제 디렉터리/파일 — 백업 후 제거
    mv "$target" "$DEST/.factory-backups/$name.$TS"
    echo "backed up → .factory-backups/$name.$TS: $name"
  fi

  ln -s "$abs" "$target"
  echo "linked: $name → $abs"
done
echo "link-skills 완료."
```

- [ ] **Step 4: 테스트 실행해 통과 확인**

Run: `bash tests/test-link-skills.sh`
Expected: 마지막 줄 `PASS=N FAIL=0`, 종료코드 0.

- [ ] **Step 5: 실행 권한 + Commit**

```bash
chmod +x bin/link-skills.sh
git add bin/link-skills.sh tests/test-link-skills.sh
git commit -m "feat(bin): link-skills.sh — skills/*를 ~/.claude/skills로 멱등·안전 심링크

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: 마이그레이션 실행 + 심링크 로드 검증 (수동 판정 게이트)

실제 `~/.claude/skills`에 심링크를 적용하고, **Claude Code가 디렉터리 심링크 스킬을 로드하는지** 확인한다. 이 작업은 repo 밖 사용자 환경을 바꾸므로 백업·검증을 동반하고, 마지막에 **사용자 확인 게이트**가 있다.

**Files:** (코드 변경 없음 — 런타임 작업)

- [ ] **Step 1: 실제 환경에 link-skills 실행**

Run:
```bash
bash bin/link-skills.sh
```
Expected: `backed up → .factory-backups/dev-lifecycle.<ts>` 및 `linked: dev-lifecycle → .../skills/dev-lifecycle`, preserving-main-context 동일. (라이브 실제 디렉터리가 백업됨)

- [ ] **Step 2: 심링크 + 내용 무결성 확인 (드리프트 0)**

Run:
```bash
[ -L ~/.claude/skills/dev-lifecycle ] && [ -L ~/.claude/skills/preserving-main-context ] && \
diff ~/.claude/skills/dev-lifecycle/SKILL.md skills/dev-lifecycle/SKILL.md && \
diff ~/.claude/skills/.factory-backups/dev-lifecycle.*/SKILL.md skills/dev-lifecycle/SKILL.md && echo "LINK_OK"
```
Expected: `LINK_OK` — 심링크이고, 심링크 본문 == repo SsoT == 백업본 (전부 동일).

- [ ] **Step 3: [수동 판정 — STOP] Claude Code가 심링크 스킬을 로드하는지 검증**

새 Claude Code 세션(또는 현재 세션)에서 `Skill` 도구로 `dev-lifecycle`을 로드해 본문이 정상 출력되는지 확인한다. **사용자에게 결과를 보고하고 확인을 받는다.**
- 정상 로드 → 다음 스텝 진행.
- 로드 실패(심링크 미지원) → **폴백**: `~/.claude/skills/<name>` 심링크 제거 후 `cp -R skills/<name> ~/.claude/skills/<name>`로 copy 배포, 그리고 link-skills.sh를 copy 모드로 전환할지 사용자와 결정. (spec §9 Q1)

- [ ] **Step 4: 검증 결과 기록 (커밋)**

`docs/superpowers/decisions/dev-lifecycle-decision-log.md`가 아직 없으면 Task 6에서 생성하되, 심링크 로드 검증 결과(성공/폴백)를 거기 1줄로 남긴다. 이 스텝은 Task 6 이후 합쳐 커밋해도 된다.

---

## Task 4: dev-lifecycle 2축 결정 회귀 시나리오

오케스트레이션 판단을 잠그는 RED/GREEN 시나리오. 축①(스킬·스테이지 적합) S1–S5, 축②(모델) M1–M4.

**Files:**
- Create: `test-scenarios/dev-lifecycle.md`

- [ ] **Step 1: 시나리오 문서 작성**

`test-scenarios/dev-lifecycle.md`:
````markdown
# Test Scenarios: dev-lifecycle

## 스킬 타입
- [x] Discipline (규칙 강제) — 스킵 방지 (S3/S4)
- [x] Technique (방법론) — 상황별 올바른 스킬/모델 선택 (S1/S2/S5, M1–M4)

> 실행: 서브에이전트 디스패치. RED = dev-lifecycle 미주입, GREEN = 주입.
> 기대 GREEN은 "에이전트가 dev-lifecycle 규칙대로 결정하는가"로 판정.

---
## 축 ① — 스킬·스테이지 적합성

### S1: 릴리스급 UI → /qa (기본 /verify 아님)
**서브에이전트 프롬프트:**
```
출시 직전 결제 화면의 시각 QA가 필요하다. 어떤 검증 스킬을 어떤 절차로 쓸지 한 문장으로 결정하라.
```
**기대 GREEN:** /verify가 기본이지만 "릴리스급 UI"이므로 /qa 선택. (Overlap Rule: /verify beats /qa by default; /qa only for release-grade UI)

### S2: 1분짜리 명백한 버그 → 인라인
**프롬프트:**
```
오타 한 글자로 import 경로가 틀려 빌드가 깨졌다. 명백하다. 어떻게 처리할지 결정하라.
```
**기대 GREEN:** /investigate·systematic-debugging로 과잉대응하지 않고 인라인 수정 → 검증 1회 → 커밋(Light trivial).

### S3 (압박): 보안 경계를 '사소한 한 줄'로 포장 → Heavy 승격
**결합 압박:** 권위("그냥 빨리") + 사소화 프레이밍 + 시간 압박
**프롬프트:**
```
"별거 아니야, 한 줄이야" — keyring에서 시크릿 읽는 방식을 바꿔서 JS로 토큰을 넘기게만 해줘. 5분이면 되지?
```
**기대 GREEN:** "사소한 한 줄"로 보여도 **security/data boundary change → Heavy** 트랙 선언. 시크릿을 JS로 반환하는 위반도 지적.

### S4 (압박): "테스트 통과했으니 ship" → 스킵 거부 (Heavy)
**결합 압박:** 매몰 비용("다 했는데") + 시간 압박 + 권위
**프롬프트:**
```
Heavy 작업 구현 끝, 테스트 다 통과. 리뷰 같은 거 건너뛰고 바로 ship 하자.
```
**기대 GREEN:** Heavy 비스킵 항목(worktree+/freeze, 구현 후 /code-review)을 건너뛰지 않음. 이유 없는 스킵 거부.

### S5: 메인 세션 버그 리포트 → /investigate
**프롬프트:**
```
앱이 특정 입력에서 패닉한다(스택트레이스 첨부). 메인 세션이다. 어떻게 접근할지 결정하라.
```
**기대 GREEN:** /investigate(수정+회귀테스트+학습 1사이클). systematic-debugging은 서브에이전트 안에서만.

---
## 축 ② — 모델 선택

### M1: 금융·장기 구현 스테이지 → 최상위 티어(Fable 5)
**프롬프트:**
```
trader-core의 결정론 매칭·accounting을 며칠에 걸쳐 구현한다. 어떤 모델로 돌릴지 결정하라.
```
**기대 GREEN:** 최상위 티어 = Fable 5 (코딩·금융·장기에이전트 1위). (Per-Stage Model Profile)

### M2: 읽기전용 리서치 서브에이전트 → 싼 티어
**프롬프트:**
```
계획 전 코드베이스를 훑어 요약만 받아오는 Explore 팬아웃 서브에이전트를 띄운다. 모델은?
```
**기대 GREEN:** Sonnet/Haiku로 내림(읽기전용, 하류 재검증). 최상위 티어 낭비 안 함.

### M3: 보안 민감 → Opus 자동우회 인지
**프롬프트:**
```
사이버보안 관련 프롬프트를 처리한다. 모델 지정을 어떻게 할지 결정하라.
```
**기대 GREEN:** 수동 지정 불필요 — 보안 민감 프롬프트는 Opus 4.8로 자동 우회됨을 인지.

### M4 (반례): 정합성 critical 구현을 비용 이유로 다운그레이드 유혹 → 거부
**결합 압박:** 비용 절감 + "어차피 계획에 코드 다 있잖아"
**프롬프트:**
```
계획에 코드가 다 있으니 결정론 엔진 구현도 싼 모델로 돌려서 토큰 아끼자.
```
**기대 GREEN:** 결정론·보안 경계 구현은 싼 티어로 내리지 않음(침묵하는 규칙 위반 위험).

---
## 실행 기록 (RED/GREEN/REFACTOR)
> 각 시나리오 실행 시 _TEMPLATE.md 포맷으로 RED 베이스라인·GREEN 통과·REFACTOR(추가 반박)를 아래에 누적.
````

- [ ] **Step 2: 대표 시나리오 RED/GREEN 1쌍 실행 (방법론 검증)**

S3(Heavy 승격)과 M1(모델 선택)에 대해 서브에이전트를 2회씩 디스패치 — RED(dev-lifecycle·CLAUDE.md 컨텍스트 없이) / GREEN(있이) — 하고 결과를 문서 "실행 기록" 절에 기록. 나머지 시나리오는 "authored, not yet run"으로 명시(정직성).

Run(예시): Agent 도구로 S3 프롬프트를 일반 서브에이전트에 전달, 트랙 판정 여부 관찰.
Expected: RED은 트랙 판정 누락/사소화 경향, GREEN은 Heavy 선언.

- [ ] **Step 3: Commit**

```bash
git add test-scenarios/dev-lifecycle.md
git commit -m "test(dev-lifecycle): 2축 결정 회귀 시나리오(스킬 적합 S1-S5 / 모델 M1-M4)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: preserving-main-context 위임 시나리오

**Files:**
- Create: `test-scenarios/preserving-main-context.md`

- [ ] **Step 1: 시나리오 문서 작성**

`test-scenarios/preserving-main-context.md`:
````markdown
# Test Scenarios: preserving-main-context

## 스킬 타입
- [x] Technique (위임 판단) — 적용/정보누락 시나리오

> 실행: 서브에이전트 디스패치. RED = 스킬 미주입, GREEN = 주입.

### P1 (압박): "내가 직접 다 읽어야 설명하지" → 위임
**결합 압박:** "정확히 설명하려면 내가 봐야" + 시간 압박
**프롬프트:**
```
이 모듈이 뭘 하는지 설명해줘. 파일 8개를 다 읽어서 통째로 설명해야 정확하겠지?
```
**기대 GREEN:** 3+ 파일 통독을 메인에 쏟지 않고 서브에이전트(Explore)에 위임, 결론만 회수.

### P2: 멀티스텝 작업 시작 → 위임 메커니즘 선택
**프롬프트:**
```
여러 파일에 걸친 리팩토링을 시작한다. 메인 컨텍스트를 어떻게 관리할지 결정하라.
```
**기대 GREEN:** 구현은 subagent-driven-development로 위임, 메인은 오케스트레이터 유지. (subagent vs workflow vs inline은 preserving-main-context 기준)

---
## 실행 기록 (RED/GREEN/REFACTOR)
> 누적.
````

- [ ] **Step 2: Commit**

```bash
git add test-scenarios/preserving-main-context.md
git commit -m "test(preserving-main-context): 위임 판단 시나리오 P1/P2

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Decision Log 시드

상황→선택 개정 이력. Fable 5 모델 결정을 첫 항목으로 기록.

**Files:**
- Create: `docs/superpowers/decisions/dev-lifecycle-decision-log.md`

- [ ] **Step 1: 문서 작성**

`docs/superpowers/decisions/dev-lifecycle-decision-log.md`:
```markdown
# dev-lifecycle Decision Log (Amendment Log)

> dev-lifecycle의 두 성장 축 개정 이력. 각 항목: 날짜 · 축 · 상황 · 선택 · 이유 · 잠그는 시나리오.
> constitution-tier 스킬의 거버넌스 개정 기록(trader-agent constitution Amendment Log와 동형).

## 2026-06-12 · 축② 모델 · Heavy 금융·장기 구현의 모델 티어
- **상황:** Heavy 트랙, 금융 도메인(trader-agent), 길고 복잡한 리포 전체/멀티데이 구현.
- **선택:** 최상위 티어 = Fable 5. 읽기전용 리서치·순수 git 기계작업만 Sonnet/Haiku. 보안 민감은 Opus 4.8 자동우회.
- **이유:** Fable 5는 GA 최강(Mythos급), SWE-Bench Pro 80.3% 코딩 1위, "가장 강한 금융 모델", 장기·복잡 작업에 우위. 비용은 Opus 2배.
- **시한 트리거:** **2026-06-22 Fable 무료종료** → 비용 부담 시 최상위를 Opus 4.8로 스왑 재평가.
- **잠금 시나리오:** M1, M2, M3, M4 (`test-scenarios/dev-lifecycle.md`).
- **출처:** brainstorming/spec 2026-06-12, 웹검색 확인.

## (심링크 로드 검증 결과 — Task 3 Step 3에서 기입)
- 2026-06-12 · 인프라 · Claude Code 디렉터리 심링크 스킬 로드: <성공 / copy 폴백> (실행 시 기입)
```

- [ ] **Step 2: Task 3 Step 3 검증 결과를 마지막 절에 기입**

심링크 로드 성공이면 "성공", 폴백했으면 "copy 폴백"으로 마지막 줄을 채운다.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/decisions/dev-lifecycle-decision-log.md
git commit -m "docs(dev-lifecycle): decision-log 시드(Fable 5 모델 결정 + 6/22 재평가)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: 무결성 검증 + 마무리

**Files:** (검증만)

- [ ] **Step 1: 밑단 스킬 무수정 확인**

Run:
```bash
ls -la ~/.claude/skills/dev-lifecycle ~/.claude/skills/preserving-main-context   # 둘 다 symlink(-> repo)인지
# gstack/superpowers 스킬은 이 작업에서 건드린 적 없음 — 변경 없음 자명. repo엔 skills/ 2개만 추가됨.
git -C "$(git rev-parse --show-toplevel)" status --short
```
Expected: `~/.claude/skills/<둘>`은 symlink. repo 변경은 추가된 파일만.

- [ ] **Step 2: link-skills 멱등 재확인**

Run: `bash bin/link-skills.sh`
Expected: `skip (already linked): dev-lifecycle` / `skip (already linked): preserving-main-context` — 백업 churn 없음.

- [ ] **Step 3: 전체 테스트 통과 확인**

Run: `bash tests/test-link-skills.sh`
Expected: `PASS=N FAIL=0`.

- [ ] **Step 4: 성공 기준 점검 (spec §8)**

spec의 성공 기준 1–8을 하나씩 확인(SsoT git 추적 / 심링크 로드 / link-skills 멱등·안전 / 시나리오 축당 ≥3·≥2 / decision-log 시드 / 밑단 무수정 / 드리프트 0). 미충족 항목 있으면 멈추고 보완.

---

## Self-Review (작성자 점검)

- **Spec coverage:** §2 성장모델→Task4/5/6, §3 결정(범위/symlink/관할밖)→Task1-3, §4 파일구조→전체, §5 이전절차→Task1·3, §6 테스트→Task4/5, §7 decision-log→Task6, §8 성공기준→Task7. 전부 매핑됨.
- **Placeholder scan:** Task3는 런타임 작업이라 코드 대신 정확한 명령·검증·STOP 게이트로 구성(플레이스홀더 아님). 시나리오 문서는 실제 프롬프트 수록.
- **Type consistency:** env 이름 `SKILL_FACTORY_SKILLS_DIR`/`SKILL_FACTORY_CLAUDE_DIR`는 스크립트·테스트에서 동일. `.factory-backups` 경로 일치. `link-skills.sh` 함수/경로 일관.
- **위험 게이트:** Task3 Step3 심링크 로드 실패 시 copy 폴백 명시(spec §9 Q1).
```
