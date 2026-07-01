<!-- TEMPLATE: project-genesis
INPUT: docs/mvp-prd.md §4
OUTPUT: docs/data-model.md
TIER: conditional:has_persistent_data -->

# 데이터 모델 · DB 스키마{{rls_title_suffix}} — {{project_name}}

> 대상: DB/백엔드 구현자. [`mvp-prd.md`](./mvp-prd.md) §4의 스키마 스케치를 **계약 수준**으로 확장.
> DB: {{db_engine_orm}}. {{multitenancy_model_note}}(`is_multitenant_saas: true`일 때). 용어: [`glossary.md`](./glossary.md).

---

## 1. 엔티티 관계 (ERD 요약)

```
{{erd_ascii_summary}}
```

- {{tenancy_column_note}}(`is_multitenant_saas: true`일 때 — 모든 업무 테이블이 `{{tenant_fk_column}}`을 갖고 RLS로 격리).
- {{denormalization_note}}

---

## 2. 테이블 정의 (핵심 컬럼·제약)

> 전체 필드는 `mvp-prd.md` §4. 여기서는 **제약·인덱스·정책에 필요한 추가 사항**만.

### {{table_1_name}}

`{{table_1_columns}}`
- 인덱스: {{table_1_indexes}}.

### {{table_2_name}}

`{{table_2_columns}}`
- 인덱스: {{table_2_indexes}}.

<!-- Repeat one ### per table identified in mvp-prd.md §4. -->

### {{table_n_name}}

`{{table_n_columns}}`
- 인덱스: {{table_n_indexes}}.

---

## 3. Row-Level Security (RLS)

> **`is_multitenant_saas: true`일 때만 해당.** false면 이 섹션은 "해당 없음"으로 명시하고 §4로 넘어간다.

### 3.1 원칙

- 모든 업무 테이블 RLS ENABLE + FORCE. 앱은 요청마다 현재 테넌트 컨텍스트를 주입한다: {{tenant_context_injection_mechanism}}.
- 정책은 {{rls_predicate_source}}로 읽는다. 미설정 시 안전하게 0행(fail-closed).
- 애플리케이션 DB 롤은 RLS 우회 권한 없음.

### 3.2 표준 정책 (테넌트 소속 테이블 공통)

```sql
{{standard_rls_policy_sql}}
```

### 3.3 프로비저닝 & 런타임 주입

- {{tenant_provisioning_note}}
- {{runtime_injection_wrapper_note}} — 상세는 [`infra-security-spec.md`](./infra-security-spec.md).

---

## 4. 인덱스 전략 (요약)

- {{index_strategy_note_1}}
- {{index_strategy_note_2}}

## 5. 마이그레이션 전략

- {{migration_tool_note}}
- 단계별 도입: {{migration_phasing_note}}
- 파괴적 변경은 expand→migrate→contract.

## 6. 테스트 (필수)

- {{test_requirement_1}}(예: 교차 테넌트 격리 — orgA 세션으로 orgB 행 접근 시 0행/거부, `is_multitenant_saas: true`일 때).
- {{test_requirement_2}}
- 불변식: {{data_invariant_test}}.
