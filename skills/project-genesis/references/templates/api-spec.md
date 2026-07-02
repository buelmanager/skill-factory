<!-- TEMPLATE: project-genesis
INPUT: docs/mvp-prd.md §5 + docs/infra-security-spec.md
OUTPUT: docs/api-spec.md
TIER: conditional:has_api -->

# API 계약 명세 — {{project_name}}

> 대상: 백엔드/프론트 구현자. [`mvp-prd.md`](./mvp-prd.md) §5 표를 **요청/응답/에러 계약** 수준으로 확장.
> 형식: {{api_style_note}}. **{{auth_scope_note}}**. 용어: [`glossary.md`](./glossary.md).

---

## 0. 공통 규약

- 인증: {{auth_mechanism}}. 미인증 → `401`.
- **테넌시**: {{tenancy_injection_note}}(`is_multitenant_saas: true`일 때 — 상세는 [`infra-security-spec.md`](./infra-security-spec.md)).
- 교차 테넌트 리소스 접근 → **`{{cross_tenant_error_code}}`**({{cross_tenant_error_rationale}}).
- 시간: {{timestamp_format}}. ID: {{id_scheme_note}}.
- {{domain_numeric_format_note}}(금액·수량·물리량 표시 규약은 [`glossary.md`](./glossary.md) §6 참조).
- 에러 바디:
  ```json
  { "error": { "code": "{{error_code_example}}", "message": "...", "details": {} } }
  ```
- 에러 코드: {{error_code_list}}.
- 비동기 작업({{async_job_examples}}): `202 Accepted` + 리소스 상태 필드. 진행은 {{async_progress_mechanism}}.
- 오브젝트({{binary_asset_examples}}) 입출력: {{object_io_pattern}}(`has_persistent_data`+파일 업로드가 있을 때 — [`infra-security-spec.md`](./infra-security-spec.md) 참조).

---

## 1. {{resource_1_name}}

### `{{resource_1_method_1}} {{resource_1_path_1}}`
- req: `{{resource_1_req_1}}`
- res `{{resource_1_status_1}}`: `{{resource_1_res_1}}`
- err: `{{resource_1_err_1}}`

### `{{resource_1_method_2}} {{resource_1_path_2}}`
- req: `{{resource_1_req_2}}`
- res `{{resource_1_status_2}}`: `{{resource_1_res_2}}`
- err: `{{resource_1_err_2}}`

<!-- Repeat one ### per endpoint on this resource. -->

```ts
type {{resource_1_type_name}} = { {{resource_1_type_shape}} }
```

---

## 2. {{resource_2_name}}

### `{{resource_2_method_1}} {{resource_2_path_1}}`
- req: `{{resource_2_req_1}}`
- res `{{resource_2_status_1}}`: `{{resource_2_res_1}}`
- err: `{{resource_2_err_1}}`

```ts
type {{resource_2_type_name}} = { {{resource_2_type_shape}} }
```

<!-- Repeat one ## per resource group identified in mvp-prd.md §5. -->

## N. {{resource_n_name}}

### `{{resource_n_method_1}} {{resource_n_path_1}}`
- req: `{{resource_n_req_1}}`
- res `{{resource_n_status_1}}`: `{{resource_n_res_1}}`
- err: `{{resource_n_err_1}}`

---

## 상태 흐름 (리소스 라이프사이클)

```
{{resource_lifecycle_diagram}}
```
- {{status_transition_ownership_note}}(클라가 상태를 직접 올리지 않는다 — 서버 파생 전이만 인정).

---

## 인바운드 웹훅

> `is_multitenant_saas: true`이고 인증 프로바이더가 프로비저닝 웹훅을 보내는 구조일 때만 해당. 아니면 "해당 없음"으로 명시하고 다음 섹션으로 넘어간다.

### `POST {{inbound_webhook_path}}`
- 인증: 세션 아님 — {{webhook_signature_scheme}}로 검증(필수) → 실패 시 `401`.
- 처리 이벤트: {{webhook_event_types}}.
- 동작: {{webhook_upsert_behavior}}(멱등 upsert — 재전송 안전).
- res `200`: `{ "received": true }`.

---

## 비범위(MVP)

{{api_out_of_scope_list}}.

---

## 내부: 워커 디스패치 (공개 API 아님)

> 백그라운드 워커/잡 큐가 있는 아키텍처일 때만 해당.

- **디스패치 인증**: {{worker_dispatch_auth_note}}(예: HMAC 서명 + timestamp skew 검증, 위조/만료 → `401`).
- **페이로드**: {{worker_dispatch_payload_note}}(테넌트 id는 서버가 세션에서 도출 — 클라 신뢰 금지).
- **워커 측 재검증**: {{worker_revalidation_note}}(대상 행 테넌트 소유권 확인 후에만 처리).
- 상세: [`infra-security-spec.md`](./infra-security-spec.md).
