<!-- TEMPLATE: project-genesis
INPUT: all docs (aggregator)
OUTPUT: docs/README.md
TIER: universal -->

# docs/ — {{project_name}} 명세 인덱스

> 단일 진실 소스(SoT) 계층:
> **스택·범위 = [`mvp-prd.md`](./mvp-prd.md) §6** · **네이밍 = [`glossary.md`](./glossary.md)**{{additional_sot_pointers}}.

## 허브
- [`mvp-prd.md`](./mvp-prd.md) — **개발자용 상세 MVP 명세(허브).** 범위·기능·데이터 모델·API·아키텍처·도메인 규칙·마일스톤. 다른 모든 명세가 이 문서의 섹션을 계약 수준으로 확장한다.

## 비즈니스
- [`00-brief.md`](./00-brief.md) — {{brief_doc_summary}}
- [`competitive-landscape.md`](./competitive-landscape.md) — {{competitive_doc_summary}}

## 아키텍처
- [`architecture.md`](./architecture.md) — {{architecture_doc_summary}}
- [`data-model.md`](./data-model.md) — {{data_model_doc_summary}}

## 엔지니어링
- [`{{core_module_spec_filename}}`](./{{core_module_spec_filename}}) — {{core_module_spec_summary}}
- [`api-spec.md`](./api-spec.md) — {{api_spec_summary}}
- [`infra-security-spec.md`](./infra-security-spec.md) — {{infra_security_summary}}
- [`glossary.md`](./glossary.md) — 도메인 용어집(영문 식별자 = 코드 네이밍 SoT)·계산/단위 규약.

## 계획·검증
- [`roadmap.md`](./roadmap.md) — 마일스톤 단계·의존성 그래프·검증 게이트.
- [`test-strategy.md`](./test-strategy.md) — 테스트 피라미드·TDD 강제 영역·CI 게이트.
- [`getting-started.md`](./getting-started.md) — 로컬 개발 셋업·환경변수.

## 진행 관리
- [`dev/PROGRESS.md`](./dev/PROGRESS.md) — 살아있는 진행 상태 SSOT(파생 — 손편집 금지). 세션마다 `/dev-handoff`가 재생성.
