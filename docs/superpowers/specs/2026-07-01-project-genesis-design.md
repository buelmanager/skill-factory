# project-genesis — 설계 스펙

> 상태: 승인됨 (2026-07-01) · 다음 단계: writing-plans
> 소유: 글로벌 스킬 `~/.claude/skills/project-genesis/`
> 레퍼런스: `/Users/chulheewon/development/main_project/interior-3d-estimator/` (역설계 대상)

## 1. 목적 (Why)

한 프로젝트를 "고객 인테이크 → 정리 → PRD → mvp-prd + 스펙/인프라 → 로드맵 → progress → 대시보드"의
일련 과정으로 끌고 간 실제 흐름(interior-3d-estimator)을 **재사용 가능한 단일 스킬**로 codify한다.
새 프로젝트에서 이 스킬을 돌리면 "개발 직전(ready-to-code)" 상태 — 문서 트리 + 리포 골격 + 진행 SSOT +
정적 대시보드 — 가 단계에 맞게 자동 구성된다.

관찰된 문제: 매 신규 프로젝트마다 이 초기 셋업을 손으로 반복하고, 문서 간 파생 관계(무엇이 무엇에서 나오는가)와
dev-process SSOT 배선이 매번 재발명된다. project-genesis는 그 파이프라인을 고정한다.

## 2. 확정된 설계 결정 (승인됨)

| 축 | 결정 | 근거 |
|---|---|---|
| 인테이크 방식 | **두 모드 지원** (대화형 인터뷰 / 브리프 입력→정리) — 스킬 시작 시 선택 | 티키타카 재현 + 이미 정리된 입력 둘 다 수용 |
| 문서 범위 | **티어: 범용핵심 + 조건부** | 도메인 특수 스펙(cad·estimate)이 일반 프로젝트에 빈 스킬로 남지 않게 |
| 기존 스킬 관계 | **오케스트레이션(재사용)** — brainstorming/spec, dev-handoff/regen-progress.mjs 재사용 | 중복 최소화·유지보수 |
| 대시보드 | **단일 정적 HTML + 생성 스크립트**(dashboard.mjs) | 의존성 zero·재생성 가능·`정적 대시보드` 요구 충족 |
| scaffold 범위 | **문서 + 리포 골격 둘 다** | 레퍼런스 첫 커밋이 scaffold. "개발 직전"의 정의에 골격 포함 |
| 이름 | **`project-genesis`** | 창세기 은유·의미 명확 |

## 3. 파일 구조

```
~/.claude/skills/project-genesis/
  SKILL.md                     # 오케스트레이터: 모드 선택 · 8 페이즈 · 위임 규칙 · 조건부 매트릭스 참조
  references/
    intake-interview.md        # 인터뷰 모드 질문 스크립트(티키타카) — 페이즈 0
    intake-brief.md            # 브리프 모드 파싱 + 갭질문 규칙 — 페이즈 0
    conditional-matrix.md      # 프로젝트 특성 플래그 → 조건부 문서/골격 on-off 규칙
    dev-process-wiring.md      # docs/dev/* 설치 + dev-handoff/regen-progress.mjs 재사용 배선법
    templates/                 # 레퍼런스에서 추출한 구체 문서 템플릿(모양 보존)
      00-brief.md   mvp-prd.md   competitive-landscape.md
      architecture.md   glossary.md   data-model.md   infra-security-spec.md
      api-spec.md   ui-flows.md   test-strategy.md   core-module-spec.md
      CLAUDE.md   AGENT.md   roadmap.md   getting-started.md
      README.md   docs-README.md
      dev-README.md   dev-WORKFLOW.md   dev-SESSION-CLOSE.md
  scripts/
    dashboard.mjs              # PROGRESS.md + docs/sessions/*.md → 단일 정적 HTML
```

각 템플릿은 레퍼런스 문서의 **섹션 구조·표기·표 포맷**을 그대로 캡처하되, 프로젝트 고유값은 플레이스홀더로 둔다.
템플릿에는 상단에 "입력(무엇에서 파생) / 출력 / 티어(범용|조건부:플래그)" 헤더 주석을 단다.

## 4. 8 페이즈 파이프라인

각 문서 생성 페이즈는 **subagent로 위임**한다(메인 컨텍스트 보존; 사용자 preserving-main-context 독트린 준수).
subagent에는 (a) 해당 템플릿, (b) 상류 산출물 + 00-brief, (c) 생성 지침을 전달하고, 결과 파일 경로만 회수한다.

| # | 페이즈 | 산출물 | 티어 | 상류 입력 |
|---|---|---|---|---|
| 0 | 인테이크(모드 선택) | `docs/00-brief.md` (정리된 SSOT) + 특성 플래그 | 범용 | 사용자 대화/브리프 |
| 1 | 제품 정의 | `competitive-landscape.md`, `mvp-prd.md`(§0 리스크가정 · §6 확정스택 · §9 마일스톤 개요) | 범용 | 00-brief |
| 2 | 아키텍처·도메인 | `architecture.md`, `glossary.md`; *`data-model.md`*(데이터), *`infra-security-spec.md`*(멀티테넌트) | 범용+조건부 | mvp-prd |
| 3 | 엔지니어링 스펙 | `test-strategy.md`; *`api-spec.md`*(API), *`ui-flows.md`*(UI), *`core-module-spec.md × N`*(핵심 리스크 모듈마다) | 조건부 | mvp-prd, glossary, data-model |
| 4 | 헌법 | `CLAUDE.md`, `AGENT.md`, `README.md`, `docs/README.md` | 범용 | mvp-prd §6, 전 문서 |
| 5 | 계획·dev-process | `roadmap.md`(M-1..M5 · 태스크ID · 게이트) + `docs/dev/{README,WORKFLOW,SESSION-CLOSE}` + 초기 `PROGRESS.md`(regen) | 범용 | mvp-prd §9, architecture, infra-security |
| 6 | 리포 골격 | 모노레포/단일앱 디렉토리 + 패키지 README + `.env.example` + `getting-started.md` + `infra/README.md` + scaffold 커밋 | 범용+스택조건부 | mvp-prd §6, infra-security |
| 7 | 대시보드 | `scripts/dashboard.mjs` 설치 + `docs/dashboard/index.html` 생성 → 열기 | 범용(피날레) | PROGRESS.md, docs/sessions |

페이즈 간 **게이트**: 각 페이즈 종료 시 산출물 경로를 사용자에게 요약 보고하고 다음 페이즈로 진행.
사용자가 특정 문서를 손보고 싶으면 그 지점에서 멈춘다(파이프라인은 순차·재개 가능).

## 5. 조건부 매트릭스 (페이즈 0에서 판정)

인테이크에서 다음 플래그를 확정한다:

- `has_ui` → `ui-flows.md` (페이즈 3), UI 골격(페이즈 6)
- `has_api` → `api-spec.md` (페이즈 3)
- `has_persistent_data` → `data-model.md` (페이즈 2)
- `is_multitenant_saas` → `infra-security-spec.md` (페이즈 2), RLS/테넌시 골격
- `core_risk_modules[]` → 모듈마다 `core-module-spec.md` 인스턴스 (페이즈 3) — 레퍼런스의 estimate-engine/cad-3d의 일반화
- `is_monorepo` → 페이즈 6 골격 형태(모노레포 vs 단일앱)
- `stack` → 페이즈 6 .env.example·getting-started 내용

일반 웹앱 예시: api-spec + ui-flows + test-strategy + data-model **ON**, 도메인 엔진 스펙 **OFF**.

## 6. 오케스트레이션 (기존 스킬 재사용)

- **인테이크 창의 탐색** → `superpowers:brainstorming`(필요 시 `spec`)을 페이즈 0/1 내부에서 호출
- **진행추적/PROGRESS 생성·검증** → 기존 `~/.claude/skills/dev-handoff/regen-progress.mjs`를 그대로 배선. 재구현하지 않음.
  - 페이즈 5에서 초기 PROGRESS.md는 regen-progress로 생성, 이후 세션은 dev-handoff가 관리.
- **문서 생성** → 페이즈별 subagent 위임(§4)

project-genesis는 "얇은 지휘자": 파이프라인 순서·조건부 판정·템플릿 공급·게이트 보고만 담당하고,
창의 탐색과 진행추적은 기존 스킬에 위임한다.

## 7. 대시보드 (dashboard.mjs)

**입력**: `docs/dev/PROGRESS.md`(롤업·태스크 상태 파싱) + `docs/sessions/*.md` 프론트매터.
**출력**: `docs/dashboard/index.html` — 외부 의존성 zero self-contained HTML.

렌더 섹션:
1. **상태바** — PROGRESS `## 0`의 막힘 / 다음 액션 / 최신 핸드오프 3칸
2. **전체 진행** — done/total 기반 링 + 요약
3. **마일스톤 롤업** — `## 1. 롤업` 표 → 카드(진행바 · status 칩 · done/total · 검증 게이트)
4. **태스크 상태 그리드** — `## 2. 태스크 상태` → 마일스톤별 색상 셀 히트맵 + 호버 툴팁
5. **최근 세션 타임라인** — docs/sessions 프론트매터(session·milestones·status_after·next_action·meta)

**상태 색상 언어**(고정): todo 회색 · doing 파랑 · blocked 빨강 · review 보라 · done 초록 · cut 회색+취소선.
**보안**: PROGRESS/세션에서 온 텍스트는 HTML escape(`@html` 하드닝 — 이 repo /sf-dashboard 패턴 준용).
**재생성**: `node scripts/dashboard.mjs` — 언제든 최신 PROGRESS로 갱신. dev-handoff 종료 의례에 훅으로 걸 수 있음(선택).

승인된 목업: 색상 언어 6종 · 히트맵 · 타임라인이 GitHub 다크 톤으로 확인됨.

## 8. 스킬 사용 흐름 (새 프로젝트)

```
빈/신규 디렉토리 → /project-genesis
  → 페이즈 0: 모드(인터뷰|브리프) 선택 → 00-brief + 특성 플래그
  → 페이즈 1~6: 순차 생성(각 subagent 위임, 페이즈 끝마다 보고)
  → 페이즈 7: 대시보드 생성 + 열기
  → "ready to code" — dev-lifecycle/WORKFLOW로 M-1 착수
```

## 9. 비목표 (Out of scope)

- 실제 애플리케이션 코드 구현(스킬은 개발 "직전"까지만). 이후는 dev-lifecycle·SDD가 담당.
- 라이브 웹앱 대시보드(정적 HTML만).
- 스택별 전체 자동 scaffold 도구화(create-next-app 등 외부 도구는 페이즈 6에서 호출·안내는 하되 래핑하지 않음).
- dev-handoff/regen-progress.mjs 재구현.

## 10. 성공 기준

1. 빈 디렉토리에서 `/project-genesis` 1회 실행으로 레퍼런스와 동형(同型)의 문서 트리 + 리포 골격 + PROGRESS + 대시보드가 생성된다.
2. 일반 웹앱 인테이크 시 도메인 특수 스펙이 자동으로 빠지고, api/ui/data 스펙은 켜진다.
3. 대시보드가 PROGRESS.md·docs/sessions만으로 재생성되며 6종 상태 색상이 정확히 반영된다.
4. 진행추적은 기존 dev-handoff/regen-progress.mjs와 충돌 없이 연동된다.
