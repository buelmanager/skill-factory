<!-- TEMPLATE: project-genesis
INPUT: docs/00-brief.md + docs/competitive-landscape.md
OUTPUT: docs/mvp-prd.md
TIER: universal -->

# MVP PRD — {{project_name}} (개발자용 상세 명세)

> 대상: 이 문서를 받아 바로 구현에 착수하는 엔지니어.
> 범위: {{mvp_scope_summary}}.
> 상위 문맥: [`00-brief.md`](./00-brief.md), [`competitive-landscape.md`](./competitive-landscape.md), [`architecture.md`](./architecture.md), [`../CLAUDE.md`](../CLAUDE.md).

---

## 0. 한 줄 정의 & 성공 기준

> **"{{product_one_liner}}"** ({{target_platform_note}})

### 핵심 차별(Wedge) — 이 한 줄이 제품의 존재 이유
> {{wedge_statement}}
>
> 경쟁 분석([`competitive-landscape.md`](./competitive-landscape.md)) 결론: {{competitive_conclusion_summary}}.

MVP가 검증하는 **가장 위험한 가정** (출시 판단 기준 — `00-brief.md`의 top-3 리스크와 동일):
1. **A1 — {{assumption_1_label}}**: {{assumption_1_detail}}
2. **A2 — {{assumption_2_label}}**: {{assumption_2_detail}}
3. **A3 — {{assumption_3_label}}**: {{assumption_3_detail}}

세 가정이 통과되면 {{post_mvp_expansion_note}}는 "확장"이며 리스크가 아니다.

---

## 1. 범위 (Scope)

### 1.1 In-scope (MVP 필수)

| # | 기능 | 비고 |
|---|---|---|
| F1 | {{feature_1}} | {{feature_1_note}} |
| F2 | {{feature_2}} | {{feature_2_note}} |
| Fn | {{feature_n}} | {{feature_n_note}} |

### 1.2 Out-of-scope (MVP 제외 → phase-2+)

{{out_of_scope_list}}

### 1.3 명시적 제약 (MVP 입력 가정)

- {{constraint_1}}
- {{constraint_2}}

### 1.4 포지셔닝 & 비목표 (경쟁 분석 반영)

- **누구를 위한 도구인가**: {{positioning_target}}
- **왜 이 타깃인가**: {{positioning_rationale}}
- **무엇으로 이기나**: {{positioning_wedge}}
- **비목표(Non-goals)**: {{non_goals}}

---

## 2. 사용자 & 핵심 시나리오

**페르소나**: {{persona_description}}

**핵심 플로우 (Happy path)**
1. {{happy_path_step_1}}
2. {{happy_path_step_2}}
3. {{happy_path_step_n}}

---

## 3. 기능 상세 명세

각 기능은 **동작 / 입력 / 출력 / 엣지케이스 / 수용 기준(AC)** 으로 기술한다.

### F1. {{feature_1}}

- **동작**: {{feature_1_action}}
- **입력**: {{feature_1_input}}
- **출력**: {{feature_1_output}}
- **엣지케이스**: {{feature_1_edge_cases}}
- **AC**: GIVEN {{given}}, WHEN {{when}}, THEN {{then}}.

<!-- Repeat one subsection per F1..Fn from §1.1. -->

---

## 4. 데이터 모델 (스케치)

```
{{data_model_sketch}}
```

> 상세 스키마는 `has_persistent_data: true`일 때 `data-model.md`(Phase 2)로 확장된다.

---

## 5. API 명세 (개요)

| Method | Path | 설명 | 주요 본문/응답 |
|---|---|---|---|
| {{method_1}} | {{path_1}} | {{desc_1}} | {{payload_1}} |

> 상세 스펙은 `has_api: true`일 때 `api-spec.md`(Phase 3)로 확장된다.

---

## 6. 아키텍처 & 기술 스택 (CONFIRMED STACK)

> 아래는 착수를 위한 **MVP 확정 결정**이다 — 이 표가 **CONFIRMED STACK**, 즉 스택의 단일 진실 소스(SoT)다. `architecture.md`·`CLAUDE.md`·`getting-started.md`는 이 표를 인용한다.

| 영역 | 결정 | 근거 |
|---|---|---|
| 모노레포 | {{stack_monorepo}} | {{stack_monorepo_rationale}} |
| 프론트 | {{stack_frontend}} | {{stack_frontend_rationale}} |
| 백엔드 | {{stack_backend}} | {{stack_backend_rationale}} |
| DB | {{stack_db}} | {{stack_db_rationale}} |
| 인증 | {{stack_auth}} | {{stack_auth_rationale}} |
| 배포 | {{stack_deploy}} | {{stack_deploy_rationale}} |

---

## 7. 용어집 (Glossary)

> 도메인 용어 정의는 [`glossary.md`](./glossary.md)(Phase 2)를 단일 진실 소스로 한다. 이 문서 안에서 사용하는 용어는 그 정의를 따른다.

---

## 8. 경쟁 분석 (Competitive)

> 시장 포지셔닝·white-space 근거는 [`competitive-landscape.md`](./competitive-landscape.md)를 참조. §0의 Wedge·§1.4의 포지셔닝은 그 결론을 반영한 것이다.

---

## 9. 마일스톤 (구현 순서 & 완료 정의)

| M | 내용 | 완료 기준(Demo) |
|---|---|---|
| **M-1** {{milestone_mminus1_name}} | {{milestone_m-1_content}} | {{milestone_m-1_demo}} |
| **M0** {{milestone_m0_name}} | {{milestone_m0_content}} | {{milestone_m0_demo}} |
| **M1** {{milestone_m1_name}} | {{milestone_m1_content}} | {{milestone_m1_demo}} |
| **M2** {{milestone_m2_name}} | {{milestone_m2_content}} | {{milestone_m2_demo}} |
| **M3** {{milestone_m3_name}} | {{milestone_m3_content}} | {{milestone_m3_demo}} |
| **M4** {{milestone_m4_name}} | {{milestone_m4_content}} | {{milestone_m4_demo}} |
| **M5** {{milestone_m5_name}} | {{milestone_m5_content}} | {{milestone_m5_demo}} |

각 M은 **테스트 + AC 충족**을 완료 정의로 한다. 이 마일스톤 ID(`M-1, M0, M1..M5`)는 `docs/roadmap.md`·`PROGRESS.md`·대시보드가 그대로 참조한다.
