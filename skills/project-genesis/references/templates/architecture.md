<!-- TEMPLATE: project-genesis
INPUT: docs/mvp-prd.md
OUTPUT: docs/architecture.md
TIER: universal -->

# 아키텍처 (초안) — {{project_name}}

> {{upstream_spec_note}}(있다면)의 구성요소를 실제 저장소 구조로 매핑한 문서. 스택 확정값은 [`mvp-prd.md`](./mvp-prd.md) §6이 진실 소스.

## 1. 구성요소 → 저장소 매핑

| 구성요소 | 본 저장소 위치 | 비고 |
|---|---|---|
| {{component_1_name}} | {{component_1_repo_path}} | {{component_1_note}} |
| {{component_2_name}} | {{component_2_repo_path}} | {{component_2_note}} |
| {{component_n_name}} | {{component_n_repo_path}} | {{component_n_note}} |
| Backend/API | {{backend_repo_path}} | {{backend_note}} |
| Database | {{db_repo_path}} | 엔티티 SoT: [`data-model.md`](./data-model.md) §1 ({{entity_list_summary}}) |

## 2. 데이터 흐름 (해피 패스)

```
{{happy_path_data_flow}}
```

> 모든 영속화는 {{persistence_entrypoint}} 경유(테넌트 경계로 격리, 해당 시); {{async_work_note}}.

## 3. 의존 방향 규칙

- `{{core_domain_package}}` ← ({{dependent_packages}} 이 의존). 역방향 없음. {{core_domain_package}}은(는) {{forbidden_deps}} 의존 금지.
- {{dependency_rule_2}}
- UI는 도메인 계산을 하지 않는다.

## 4. 핵심 도메인 엔티티

> SoT: [`data-model.md`](./data-model.md) §1 / [`mvp-prd.md`](./mvp-prd.md) §4 (아래는 요약).

{{key_entities_list}}. 모든 엔티티는 {{tenancy_root_entity}}(해당 시) 소속.

## 5. 확정 스택 & 잔여 결정

> 스택의 **단일 진실 소스는 [`mvp-prd.md`](./mvp-prd.md) §6**. (확정: {{confirmed_stack_summary}})

**잔여 결정**:

- {{open_decision_1}}
- {{open_decision_2}}
- {{open_decision_n}}
