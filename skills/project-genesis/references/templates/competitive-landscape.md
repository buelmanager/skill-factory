<!-- TEMPLATE: project-genesis
INPUT: market research + docs/00-brief.md
OUTPUT: docs/competitive-landscape.md
TIER: universal -->

# 경쟁 SaaS 통합 분석 — {{project_name}}

> 목적: 동일/인접 제품들이 **어떤 방향을 추구하고 어떤 강점**을 갖는지 통합 분석하고, 우리 제품({{product_one_liner}})의 **차별 포지션(white space)**을 도출한다.
> 관련 문서: [`00-brief.md`](./00-brief.md) · [`mvp-prd.md`](./mvp-prd.md) · [`architecture.md`](./architecture.md).

---

## 0. 한 장 요약 (TL;DR)

- {{market_summary_point_1}}
- **공통 수렴점**: {{common_convergence}}
- **결정적 공백(White space)**: {{white_space_summary}}

---

## 1. {{competitor_category_1_name}}

| 제품 | 지향(타깃) | 강점/차별점 | 가격/모델 |
|---|---|---|---|
| **{{competitor_1_name}}** | {{competitor_1_target}} | {{competitor_1_strength}} | {{competitor_1_pricing}} |
| **{{competitor_2_name}}** | {{competitor_2_target}} | {{competitor_2_strength}} | {{competitor_2_pricing}} |

**이 카테고리의 방향**: {{category_1_direction}}

*출처: {{category_1_sources}}.*

---

## 2. {{competitor_category_2_name}}

| 제품 | 지향(타깃) | 강점/차별점 | 가격/모델 |
|---|---|---|---|
| **{{competitor_3_name}}** | {{competitor_3_target}} | {{competitor_3_strength}} | {{competitor_3_pricing}} |

**이 카테고리의 방향**: {{category_2_direction}}

*출처: {{category_2_sources}}.*

<!-- Repeat one numbered section per competitor category identified in research. -->

---

## N. 통합 결론 — 우리 제품의 자리

### N.1 시장이 비워둔 곳 (White space)

> {{white_space_detail}}

### N.2 차별 포지셔닝 (방향)

1. {{positioning_direction_1}}
2. {{positioning_direction_2}}

### N.3 신뢰·실행 원칙 (리서치 교훈)

- {{execution_lesson_1}}
- {{execution_lesson_2}}

### N.4 비즈니스 모델 시사

- {{business_model_implication}}

---

## 부록. 직접/인접 경쟁 한눈 매핑

| 축 | {{axis_1_label}} | {{axis_2_label}} | **{{axis_3_label}}(희소)** |
|---|---|---|---|
| {{segment_1_label}} | {{segment_1_axis_1}} | {{segment_1_axis_2}} | {{segment_1_axis_3}} |

## resulting non-goals

> 이 경쟁 분석에서 도출된 비목표(non-goals) — `mvp-prd.md` §1.4에 반영된다.

- {{resulting_non_goal_1}}
- {{resulting_non_goal_2}}
