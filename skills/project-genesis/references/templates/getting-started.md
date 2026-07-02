<!-- TEMPLATE: project-genesis
INPUT: docs/infra-security-spec.md + docs/mvp-prd.md §6
OUTPUT: docs/getting-started.md
TIER: universal -->

# 개발 환경 셋업 (Getting Started) — {{project_name}}

> 대상: 처음 합류한 개발자. 확정 스택([`mvp-prd.md`](./mvp-prd.md) §6) 기준의 로컬 개발·배포 안내.
> {{scaffold_stage_note}}

---

## 1. 사전 요구사항

| 도구 | 버전(권장) | 용도 |
|---|---|---|
| {{prereq_1_tool}} | {{prereq_1_version}} | {{prereq_1_purpose}} |
| {{prereq_2_tool}} | {{prereq_2_version}} | {{prereq_2_purpose}} |
| {{prereq_n_tool}} | {{prereq_n_version}} | {{prereq_n_purpose}} |

## 2. 확정 스택 요약
- {{stack_summary_frontend}}
- {{stack_summary_domain}}
- {{stack_summary_backend}}
- {{stack_summary_db}}
- {{stack_summary_auth}}
- {{stack_summary_storage}}

## 3. 최초 셋업
```bash
{{setup_step_1}}
{{setup_step_2}}
{{setup_step_3}}
{{setup_step_n}}
```

## 4. 환경변수 (`.env`)
> 실제 값은 `.env`에만. `.env.example`에는 키 이름만. 시크릿 커밋 금지.
```
# App
NODE_ENV=development
APP_URL={{app_local_url}}

{{env_block_db}}

{{env_block_auth}}

{{env_block_storage}}

{{env_block_other}}
```

## 5. 멀티테넌시 연결 (해당 시)
{{multitenancy_wiring_notes}}

> 해당 없으면 이 절 생략.

## 6. 자주 쓰는 스크립트
| 명령 | 설명 |
|---|---|
| {{script_1_cmd}} | {{script_1_desc}} |
| {{script_2_cmd}} | {{script_2_desc}} |
| {{script_n_cmd}} | {{script_n_desc}} |

## 7. 배포
- {{deploy_note_frontend}}
- {{deploy_note_backend}}
- {{deploy_note_other}}

## 8. 시드 데이터 (해당 시)
{{seed_data_notes}}

> 해당 없으면 이 절 생략.

## 9. 관련 규약
- 코드 경계·도메인 규칙: [`../CLAUDE.md`](../CLAUDE.md), [`../AGENT.md`](../AGENT.md)
- 용어: [`glossary.md`](./glossary.md) · 테스트: [`test-strategy.md`](./test-strategy.md)
- {{additional_related_doc_note}}
