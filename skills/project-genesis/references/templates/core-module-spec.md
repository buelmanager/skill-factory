<!-- TEMPLATE: project-genesis
INPUT: docs/mvp-prd.md (feature ref) + docs/glossary.md
OUTPUT: docs/{{module}}-spec.md
TIER: conditional:core_risk_modules -->

> instantiate once per entry in `core_risk_modules`; output `docs/{{module}}-spec.md`.

# {{module_name}} 명세 (`{{module_package_path}}`)

> 대상: `{{module_package_path}}` 구현자. {{module_purity_constraint}}(예: 순수 로직 — 프레임워크/HTTP/외부 IO 의존 금지).
> 이 모듈이 {{module_consuming_features_note}}의 **단일 진실 소스**다(코드 경로 분기 금지 — 화면·서버·출력물 모두 같은 함수를 호출).
> 단위·반올림 규약은 [`glossary.md`](./glossary.md) §6. 상위: [`mvp-prd.md`](./mvp-prd.md) {{module_feature_ref}}.

---

## 1. 설계 원칙

1. **{{design_principle_1_label}}**: {{design_principle_1_detail}}.
2. **{{design_principle_2_label}}**: {{design_principle_2_detail}}.
3. **단일 호출 지점**: {{single_call_site_note}}(표시용·저장용 계산 경로를 따로 두지 않는다).
4. **결정성·검증성**: 같은 입력 → 항상 같은 출력. 불변식을 property test로 고정한다.

---

## 2. 타입/인터페이스

```ts
// 입력
export interface {{module_name}}Input {
  {{input_field_1}};
  {{input_field_2}};
}

// 출력
export interface {{module_name}}Result {
  {{output_field_1}};
  {{output_field_2}};
  warnings: string[];
}
```

<!-- Add per-domain sub-types as needed (e.g. line-item shapes, parsed-entity shapes). -->

---

## 3. 공식 / 알고리즘 (정확히 이 순서)

```
{{algorithm_step_1}}
{{algorithm_step_2}}
{{algorithm_step_n}}
```

**규칙**
- {{calc_rule_1}}.
- {{calc_rule_2}}.
- **단위**: {{unit_convention_note}}(내부 저장 단위 vs 표시 단위 — `glossary.md` §6과 반드시 일치).
- {{edge_case_rule}}(예: 0/미설정 입력은 조용히 버리지 않고 결과에 `warnings`로 기록).

---

## 4. 불변식

> `INV1, INV2, ...`로 라벨링한다 — property test가 직접 참조하는 식별자이며, [`test-strategy.md`](./test-strategy.md) §2 TDD 강제 영역이 이 ID를 인용한다.

| ID | 불변식 |
|---|---|
| INV1 | {{invariant_1}} |
| INV2 | {{invariant_2}} |
| INVn | {{invariant_n}} |

---

## 5. 테스트 벡터 (구현 전 고정 — TDD 시드)

> `TV1, TV2, ...`로 라벨링한다. [`test-strategy.md`](./test-strategy.md)가 이 벡터를 단위 테스트 시드로 인용한다.

### TV1 — {{test_vector_1_label}}
```
입력: {{test_vector_1_input}}
기대: {{test_vector_1_expected}}
```

### TV2 — {{test_vector_2_label}}
```
입력: {{test_vector_2_input}}
기대: {{test_vector_2_expected}}
```

<!-- Repeat one ### per test vector needed to pin the formulas/edge cases in §3. -->

### TVn — {{test_vector_n_label}}
```
입력: {{test_vector_n_input}}
기대: {{test_vector_n_expected}}
```

---

## 6. 공개 API

```ts
export function {{module_entry_function}}(input: {{module_name}}Input): {{module_name}}Result;
```

- {{consumer_1_note}}(예: 클라이언트가 즉시 호출 — 서버 왕복 0).
- {{consumer_2_note}}(예: 서버가 같은 함수로 재계산해 클라 값을 검증한 후에만 저장).

## 7. 비범위(MVP)

{{module_out_of_scope_list}}.
