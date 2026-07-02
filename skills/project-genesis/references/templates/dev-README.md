<!-- TEMPLATE: project-genesis
INPUT: CLAUDE.md §7 + dev-handoff skill
OUTPUT: docs/dev/README.md
TIER: universal -->

# 개발 프로세스 SSOT — 규약 & 핸드오프 템플릿 ({{project_name}})

> **원칙**: 관심사마다 집 하나 · 태스크 ID로 조인 · 내용 복사 금지.

---

## 1. 관심사 → 집 매핑

| 관심사 | 유일한 집 | 규칙 |
|---|---|---|
| 태스크 정의 + 안정 ID | `docs/roadmap.md` | **가변 plan-of-record** — 체크박스 ✕, `- **<MID>.T<n>** <설명>` 불릿. ID 안정·설명 개정 가능 |
| 살아있는 진행 상태 SSOT | `docs/dev/PROGRESS.md` | **파생** — 핸드오프에서 재생성. 손편집 ✕ |
| 상태 진실 + 에피소드(세션별·append-only) | `docs/sessions/YYYY-MM-DD-HHMMSS-<slug>.md` | 핸드오프. `/dev-handoff`가 작성·검증·커밋 |
| 지식(결정·교훈) | llm-wiki | `/wiki-checkpoint` — 이 repo에선 핸드오프 정본을 가리킴 |
| PROGRESS 생성·검증·staleness 검사 | 전역 `~/.claude/skills/dev-handoff/regen-progress.mjs` | 범용 스크립트. repo 루트는 `git rev-parse --show-toplevel` |

> **옵트인 게이트**: `docs/dev/PROGRESS.md` 존재 = 이 repo가 시스템 사용 중. 없으면 `/dev-handoff`·`/wiki-checkpoint`는 기존 동작.

---

## 2. 시스템 개요

```
세션 시작
  └─ node ~/.claude/skills/dev-handoff/regen-progress.mjs --check
       ├─ PROGRESS 최신 여부 확인 (손편집·stale 감지)
       └─ 최신 핸드오프 + PROGRESS §0 읽기 → 상태 복원

세션 종료 (/dev-handoff)
  └─ git log <covers_commit>..HEAD 로 Task: 트레일러 그룹화
  └─ 핸드오프 작성 (아래 템플릿)
  └─ node …/regen-progress.mjs regen → docs/dev/PROGRESS.md 재생성
  └─ node …/regen-progress.mjs --validate-handoff <path> → exit 1이면 ABORT
  └─ 동의 시 커밋 (main 중단, Task: 트레일러 필수)
```

---

## 3. 핸드오프 파일 규약

### 3.1 파일명
`docs/sessions/YYYY-MM-DD-HHMMSS-<slug>.md` — 오름차순 = 세션순. 수동 생성 금지(날짜 충돌). `/dev-handoff` 가 생성.

### 3.2 Frontmatter (8키 필수)

```yaml
---
session: YYYY-MM-DD-HHMM
milestones: [M-1]
tasks_touched: [M-1.T1, M-1.T2]
status_after: { M-1.T1: done, M-1.T2: doing }
next_action: "M-1.T2 — 다음 할 일 한 줄 + 태스크 ID"
covers_commit: <git SHA or HEAD>
verified: "`{{primary_verify_command}}` green"
consistency: { hard_errors: [], overrides: [] }
---
```

- `status_after`: 상태 어휘 → `todo|doing|blocked|review|done|cut`
- `verified`: `done` 상태 태스크는 증거(backtick 명령·PR·태그·이슈) 필수
- `consistency.hard_errors`: 검증기가 찾은 오류(빈 배열이면 클린); `overrides`: 의도적 예외

### 3.3 섹션 (6개 필수)

```markdown
## 1. 한 것
<!-- 이번 세션에서 실제로 한 일 -->

## 2. 결정
<!-- 이 세션에서 내린 설계/방향 결정. 없으면 "없음" -->

## 3. 열린 쓰레드
<!-- 미완·차기 세션 이월 사항. 없으면 "없음" -->

## 4. 다음
<!-- 다음 세션 시작점 — 태스크 ID 포함 필수 -->

## 5. 검증
<!-- 실행한 검증 명령·결과 -->

## 6. 참조
<!-- 관련 파일·PR·스펙 링크 -->
```

---

## 4. 태스크 라이프사이클

### ADD (새 태스크)
`docs/roadmap.md` §3 해당 마일스톤에 `- **<MID>.T<n>** <설명>` 추가 → 다음 핸드오프에서 `status_after`에 포함 → `regen` 후 PROGRESS에 반영.

### SPLIT (태스크 분할)
원 ID를 `cut`으로 마킹 + 새 ID(`T<n>a`/`T<n>b` 또는 신규 번호) 추가. 핸드오프의 `consistency.overrides`에 이유 기록.

### CUT (태스크 제거)
roadmap에서 제거하지 않고 `status_after`에 `cut`으로 기록. PROGRESS에서 `cut` 그룹으로 표시됨.

---

## 5. 상태 어휘

| 상태 | 의미 |
|---|---|
| `todo` | 미시작 (핸드오프에 등장한 적 없으면 묵시적 todo) |
| `doing` | 진행 중 |
| `blocked` | 외부 의존·결정 대기로 진행 불가 |
| `review` | 구현 완료, 검증/리뷰 대기 |
| `done` | 완료 + 증거 있음 (`verified` 필드) |
| `cut` | 범위 제거 (roadmap에 ID 유지, 상태만 cut) |

---

## 6. 커밋 트레일러 규칙

모든 구현 커밋(코드·설정 변경)에 `Task: <ID>` 트레일러 필수:

```
{{example_commit_subject}}

Task: M2.T3
Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
```

- SDD 서브에이전트는 `docs/roadmap.md`·`docs/sessions/`·`docs/dev/PROGRESS.md`를 직접 수정하지 않는다. 단일 작성자 = 메인 세션의 `/dev-handoff`.
- `Task:` 트레일러가 있는 커밋은 `regen-progress.mjs --check`의 staleness 판정 대상.

---

## 7. PROGRESS.md

`docs/dev/PROGRESS.md`는 핸드오프 frontmatter `status_after` 필드들을 집계해 **자동 생성**된다.

```bash
# 재생성
node ~/.claude/skills/dev-handoff/regen-progress.mjs regen

# staleness 검사 (세션 시작 게이트)
node ~/.claude/skills/dev-handoff/regen-progress.mjs --check

# 핸드오프 검증 (세션 종료 게이트)
node ~/.claude/skills/dev-handoff/regen-progress.mjs --validate-handoff docs/sessions/<file>.md
```

> **PROGRESS derived, do not hand-edit.** 손으로 고치면 `--check`가 stale 감지.
> 전역 스크립트 위치: `~/.claude/skills/dev-handoff/regen-progress.mjs` (uses global `~/.claude/skills/dev-handoff`)
