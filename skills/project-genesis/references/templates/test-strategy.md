<!-- TEMPLATE: project-genesis
INPUT: docs/mvp-prd.md §0 + core-module specs
OUTPUT: docs/test-strategy.md
TIER: universal -->

# 테스트 전략 · QA — {{project_name}}

> 대상: 전 구현자. 무엇을 어디서 어떻게 검증하는지의 기준. 상위: [`mvp-prd.md`](./mvp-prd.md), [`roadmap.md`](./roadmap.md).
> 원칙: {{high_risk_domain_note}}(숫자·보안·기하 등 신뢰 핵심 영역)은 TDD 강제.

---

## 1. 테스트 피라미드 (이 프로젝트의 비중)

```
        ┌───────────────┐
        │  E2E (소수)     │  {{e2e_flow_summary}}
        ├───────────────┤
        │ 통합 (중)       │  {{integration_scope_summary}}
        ├───────────────┤
        │ 단위 (다수, TDD) │  {{unit_scope_summary}}
        └───────────────┘
```
- {{pyramid_weight_note}}(`core_risk_modules`에 무게중심 — 렌더/UI 픽셀 비교 등 비용 높은 검증은 최소화하고 데이터 레벨로 검증).

---

## 2. TDD 강제 영역 (구현 전 테스트)

| 영역 | 무엇을 | 근거 문서 |
|---|---|---|
| {{tdd_area_1}} | {{tdd_area_1_scope}} | [`{{tdd_area_1_module}}-spec.md`](./{{tdd_area_1_module}}-spec.md) |
| {{tdd_area_2}} | {{tdd_area_2_scope}} | [`{{tdd_area_2_module}}-spec.md`](./{{tdd_area_2_module}}-spec.md) |
| 멀티테넌시 | 교차 테넌트 격리·테넌트 미주입 0행 | [`data-model.md`](./data-model.md) §3(`is_multitenant_saas: true`일 때) |

<!-- Repeat one row per entry in core_risk_modules — each links to that module's docs/{{module}}-spec.md, whose INV1..n / TV1..n sections are the acceptance bar for this row. -->

이 영역들은 "통과 전엔 다음 단계 진행 금지"로 취급.

---

## 3. 레벨별 상세

### 3.1 단위 (테스트 러너: {{unit_test_runner}})
- **{{tdd_area_1}}**: property test로 `{{tdd_area_1_module}}-spec.md`의 `INV1..n` + 명시 `TV1..n` 벡터를 고정 검증. {{unit_focus_note_1}}.
- **{{tdd_area_2}}**: {{unit_focus_note_2}}.
- {{additional_unit_focus_note}}.

### 3.2 통합
- **API 계약**: 각 엔드포인트 요청/응답 스키마·에러코드 일치([`api-spec.md`](./api-spec.md), `has_api: true`일 때).
- **테넌트 격리**(필수): {{tenant_isolation_test_note}}(`is_multitenant_saas: true`일 때 — orgA 세션으로 orgB 리소스 접근 시 거부/0행).
- **파이프라인**: {{pipeline_integration_note}}.
- {{cross_module_consistency_note}}(예: 화면 표시값과 서버 확정값이 같은 core-module 결과여야 함).

### 3.3 E2E (테스트 러너: {{e2e_test_runner}}, 소수)
- 핵심 흐름 1: {{e2e_flow_1}}.
- 핵심 흐름 2: {{e2e_flow_2}}.

---

## 4. 비기능 검증 (가정 게이트)

> `mvp-prd.md` §0의 `A1, A2, ...` 리스크 가정을 그대로 인용한다 — 새로 만들지 않는다.

| 가정 | 측정 방법 | 기준 | 단계 |
|---|---|---|---|
| **A1** | {{a1_measurement_method}} | {{a1_threshold}} | {{a1_milestone}} |
| **A2** | {{a2_measurement_method}} | {{a2_threshold}} | {{a2_milestone}} |
| **An** | {{an_measurement_method}} | {{an_threshold}} | {{an_milestone}} |

- 성능은 **대표 시나리오 고정 데이터셋**으로 회귀 측정(매 PR 비교 권장).

---

## 5. 테스트 데이터

- {{test_fixture_note_1}}.
- {{test_fixture_note_2}}.
- {{test_seed_data_note}}.

## 6. CI 게이트

- 모든 PR: lint + 단위 + 통합({{integration_gate_scope}} 포함) 통과 필수.
- {{coverage_threshold_note}}.
- E2E·성능은 {{e2e_gate_schedule}}으로 분리 가능.

## 7. 비범위(MVP)

{{test_out_of_scope_list}}는 phase-2.
