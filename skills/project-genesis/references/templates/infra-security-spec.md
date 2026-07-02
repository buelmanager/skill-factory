<!-- TEMPLATE: project-genesis
INPUT: docs/mvp-prd.md §6
OUTPUT: docs/infra-security-spec.md
TIER: conditional:is_multitenant_saas -->

# 인프라·보안 기반 설계 (멀티테넌트 BLOCKER) — {{project_name}}

> 대상: {{early_milestone_ids}} 구현자. 멀티테넌트 SaaS 적합성 감사가 식별한 **착수 차단(BLOCKER)** {{blocker_count}}건의 확정 설계.
> 성격: **설계 명세(계약)**. 코드는 아직 없음 — 구현은 `writing-plans` 이후.
> SoT 연계: DB/RLS = [`data-model.md`](./data-model.md) · API = [`api-spec.md`](./api-spec.md)(해당 시) · 스택 = [`mvp-prd.md`](./mvp-prd.md) §6 · 셋업 = [`getting-started.md`](./getting-started.md).

---

## 0. 왜 이 문서

`data-model.md`의 DB RLS만으로는 격리가 완성되지 않는다. 격리를 **실제로 지탱하는 핵심 메커니즘**이 미설계 상태이며, 모두 {{early_milestone_ids}} critical path에 있다. 이 항목들은 **테넌트 데이터가 저장되기 전** 확정·구현돼야 한다(틀리면 교차 테넌트 누출 = 보안사고, 또는 핵심 흐름 불능).

| ID | BLOCKER | 결정 | 등급 |
|---|---|---|---|
| B1 | 오브젝트 스토리지 격리 + 업로드 인그레스 | {{b1_decision_summary}} | mvp-blocker |
| B2 | web↔worker 신뢰경계 + 워커 DB 테넌트 컨텍스트 | {{b2_decision_summary}} | mvp-blocker |
| B3 | ORM×서버리스×RLS 연결 배선 | {{b3_decision_summary}} | early-mvp |
| B4 | 테넌트 내부 권한(authz) | {{b4_decision_summary}} | early-mvp |

---

## 1. B1 — 오브젝트 스토리지 & 인그레스

### 문제

{{b1_problem}}

### 결정

- **버킷/격리 스킴**: {{b1_bucket_scheme}}
- **키 접두 규칙**: {{b1_key_prefix_scheme}}
- **업로드 흐름**: {{b1_upload_flow}}
- **다운로드 흐름**: {{b1_download_flow}}
- **격리 강제 지점**: 앱 계층 강제. 서명 직전에 대상 행 소유권(`{{tenant_fk_column}} == 현재 테넌트`) 확인. 키 접두는 방어선이지 인가가 아님.

### 수용 기준

- {{b1_ac_1}}
- {{b1_ac_2}}(orgA가 orgB 자산 접근 불가, 유출 URL은 짧은 TTL)

---

## 2. B2 — web↔worker 신뢰경계 + 워커 DB 테넌트 컨텍스트

### 문제

{{b2_problem}}

### 결정

- **디스패치 인증**: {{b2_dispatch_auth}}
- **페이로드**: {{b2_payload_shape}}(테넌트 ID는 서버가 세션에서 도출 — 클라 신뢰 금지)
- **워커 DB 컨텍스트**: {{b2_worker_db_context}}(대상 행 테넌트 재검증 후에만 변경, 프로비저닝 우회 롤 사용 금지)
- **결과 전달**: {{b2_result_delivery}}

### 수용 기준

- {{b2_ac_1}}(HMAC/서명 부재·위조 → 거부)
- {{b2_ac_2}}(payload 테넌트 ≠ 대상 행 소유주 → 거부, 무기록)

---

## 3. B3 — {{orm_name}} × 서버리스 × RLS: 연결 배선

### 문제

{{b3_problem}}

### 결정

- **풀러**: {{b3_pooler_mode}}
- **단일 진입 helper**: {{b3_wrapper_signature}}
- **금지**: {{b3_forbidden_patterns}}(RLS 우회 클라이언트는 프로비저닝 경로에만 국한)

### 수용 기준

- {{b3_ac_1}}(동시 요청 간 상호 행 누수 0)
- {{b3_ac_2}}(래퍼 우회 핸들러는 CI lint 실패)

---

## 4. B4 — 테넌트 내부 권한: {{b4_role_gate_summary}}

### 문제

{{b4_problem}}

### 결정

- **권한 게이트**: {{b4_role_gate}}
- **소프트딜리트**: {{b4_soft_delete_note}}
- **감사 로그**: {{b4_audit_log_note}}
- **보존**: {{b4_retention_note}}

### 수용 기준

- {{b4_ac_1}}(권한 없는 롤의 파괴적 작업 → 거부)
- {{b4_ac_2}}(삭제는 tombstone, 감사 로그 기록)

---

## 5. 영향받는 문서 (전파)

| 파일 | 변경 |
|---|---|
| `api-spec.md` | {{impact_api_spec}} |
| `data-model.md` | {{impact_data_model}} |
| `getting-started.md` | {{impact_getting_started}} |
| `architecture.md` | {{impact_architecture}} |
| `roadmap.md` | {{impact_roadmap}} |

## 6. 비범위 (별건)

- {{out_of_scope_1}}
- {{out_of_scope_2}}
- **실제 코드 구현** — 본 문서는 설계만.

## 7. 테스트 (요약)

| 레벨 | 무엇 | 수 |
|---|---|---|
| 단위 | {{unit_test_summary}} | {{unit_test_count}} |
| 통합 | {{integration_test_summary}} | {{integration_test_count}} |
| E2E | {{e2e_test_summary}} | {{e2e_test_count}} |
