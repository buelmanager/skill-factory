<!-- TEMPLATE: project-genesis
INPUT: docs/mvp-prd.md §2
OUTPUT: docs/ui-flows.md
TIER: conditional:has_ui -->

# UI 화면 · 플로우 명세 — {{project_name}}

> 대상: {{frontend_app_name}} 구현자. 와이어프레임 수준(픽셀 디자인 아님).
> 상위: [`mvp-prd.md`](./mvp-prd.md) §2 플로우 + F1~Fn. 용어는 [`glossary.md`](./glossary.md).
> {{platform_priority_note}}. 도메인 계산은 직접 하지 않고 `{{core_domain_package_name}}` 결과를 소비.

---

## 0. 화면 인벤토리

| # | 화면 | 라우트(예) | 핵심 기능 |
|---|---|---|---|
| S1 | {{screen_1_name}} | `{{screen_1_route}}` | {{screen_1_features}} |
| S2 | {{screen_2_name}} | `{{screen_2_route}}` | {{screen_2_features}} |
| Sn | {{screen_n_name}} | `{{screen_n_route}}` | {{screen_n_features}} |

<!-- Repeat one row per screen identified in mvp-prd.md §2/§3 flows. -->

{{hero_screen_note}}(제품의 심장 — 가장 많은 공을 들인다).

> {{cross_cutting_feature_note}}(단일 화면이 아니라 여러 화면을 횡단하는 기능이 있으면 여기 명시 — 예: 상태 기반 진입점 복원).

---

## 1. 내비게이션 플로우

```
{{navigation_flow_ascii}}
```
- 각 단계는 되돌아갈 수 있음(브레드크럼). {{reentry_restoration_note}}(프로젝트/엔티티 상태에 따라 재방문 시 진입점 복원).

---

## 2. 화면별 상세

### {{hero_screen_id}} — {{hero_screen_name}} ⭐

레이아웃:
```
{{hero_screen_layout_ascii}}
```
- **상호작용**:
  1. {{hero_interaction_1}}
  2. {{hero_interaction_2}}
  3. {{hero_interaction_3}}
- **상태({{state_management_lib}})**: {{hero_state_shape}}. {{derived_value_note}}(예: 러닝 합계는 파생값 — 원본 상태에서 재계산).
- 성능: {{hero_perf_note}}.

### {{screen_x_id}} — {{screen_x_name}}
- 구성: {{screen_x_composition}}.
- 상태: {{screen_x_states}}.
- 엣지: {{screen_x_edge_cases}}.

<!-- Repeat one ### per screen in §0 that needs behavior detail beyond the inventory row. -->

---

## 3. 공통 패턴

| 항목 | 규칙 |
|---|---|
| 로딩 | {{loading_pattern}} |
| 에러 | {{error_pattern}} |
| 빈 상태 | {{empty_state_pattern}} |
| 권한 | {{permission_pattern}}(`is_multitenant_saas: true`일 때 — 교차 테넌트 접근 시 은닉) |
| 반응형 | {{responsive_pattern}} |

---

## 4. 컴포넌트 ↔ 패키지 경계

- {{domain_ui_package_boundary_1}}
- {{domain_logic_package_boundary}}(`{{core_domain_package_name}}` 호출 결과만 표시 — 계산 로직 재구현 금지)
- {{shared_presentation_package_boundary}}(도메인 로직 없는 공유 프레젠테이션 컴포넌트)

## 5. 화면별 검증 연결

- {{screen_to_assumption_link_1}}(예: `mvp-prd.md` §0의 `A1` 검증은 이 화면에서 관측).
- {{screen_to_assumption_link_2}}
