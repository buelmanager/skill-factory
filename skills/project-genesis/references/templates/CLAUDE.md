<!-- TEMPLATE: project-genesis
INPUT: docs/mvp-prd.md §6 + all specs
OUTPUT: CLAUDE.md
TIER: universal -->

# CLAUDE.md — {{project_name}}

> 이 파일은 이 저장소에서 작업하는 AI 에이전트(Claude Code 등)를 위한 **프로젝트 헌법**이다.
> 운영 절차·역할별 워크플로우는 [`AGENT.md`](./AGENT.md)를 참조한다.

## 1. 제품 한 줄 정의

{{product_one_liner_full}}. 1차 사용자는 {{primary_user}}.

핵심 가치: {{core_value_summary}}.

## 2. 확정된 기술 결정 (변경 시 이 문서부터 수정)

| 영역 | 선택 | 비고 |
|---|---|---|
| 형태 | {{stack_form_factor}} | {{stack_form_factor_note}} |
| 프론트엔드 | {{stack_frontend}} | {{stack_frontend_repo_path}} |
| 백엔드 | {{stack_backend}} | {{stack_backend_repo_path}} |
| 도메인 엔진 | {{stack_core_domain}} | {{stack_core_domain_repo_path}} |
| 인증 | {{stack_auth}} | {{stack_auth_note}} |
| DB | {{stack_db}} | {{stack_db_note}} |
| 배포 | {{stack_deploy}} | {{stack_deploy_note}} |
| 모노레포 | {{stack_monorepo}} | {{stack_monorepo_note}} |

> 단일 진실 소스는 [`docs/mvp-prd.md`](./docs/mvp-prd.md) §6. 잔여 미확정: {{residual_open_decisions}}.

## 3. 저장소 구조

```
{{repo_structure_tree}}
```

각 디렉터리의 책임은 해당 폴더 `README.md` 참조. **경계를 넘는 의존은 금지**: {{boundary_rule_statement}}.

## 4. 도메인 핵심 규칙 (PRD에서 도출 — 코드의 진실 소스)

- {{domain_rule_1}}
- {{domain_rule_2}}
- {{domain_rule_n}}

## 5. 비기능 요구 (NFR) — 설계 시 항상 고려

- {{nfr_performance}}
- {{nfr_device_support}}
- {{nfr_tenant_isolation}}
- {{nfr_encryption_and_access}}

## 6. AI 에이전트 작업 규칙

1. **개발 작업 진입 시 트랙을 먼저 선언**한다(Light/Basic/Heavy). {{track_default_hint}}.
2. **추측 금지**: 2절 스택은 **확정됨**(단일 진실 소스 = `docs/mvp-prd.md` §6). 잔여 미확정만 임의로 고르지 말고 사용자에게 확인한다.
3. **경계 존중**: 3·4절의 경계와 도메인 규칙을 깨는 변경은 하지 않는다.
4. **표면적 변경**: 요청에 직접 연결되는 라인만 수정. 인접 코드 리팩토링·정리는 별도 승인.
5. **검증 우선**: {{critical_logic_area}}는 구현 전에 테스트(TDD)를 작성한다.
6. 시크릿·키는 코드/문서에 넣지 않는다. `.env`만 사용하고 `.env.example`을 갱신한다.

## 7. 개발 프로세스 SSOT (진행 관리)

> 전체 설계: [`{{dev_process_ssot_design_doc}}`](./{{dev_process_ssot_design_doc}}).
> 상태: {{dev_process_ssot_status}}.
> **현재 진행 상태는 매 세션 자동 로드된다:** @docs/dev/PROGRESS.md (§0 현재 초점·막힘·다음 액션·최신 핸드오프 포인터).

| 관심사 | 유일한 집 |
|---|---|
| 태스크 정의("무엇을") + 안정 ID | `docs/roadmap.md` |
| 살아있는 진행 상태 SSOT | `docs/dev/PROGRESS.md` |
| 상태 진실 + 에피소드(세션별·append-only) | `docs/sessions/<YYYY-MM-DD-HHMMSS-slug>.md` 핸드오프 |
| 갱신 의례 | `/dev-handoff` 스킬 + `regen-progress.mjs` |

## 8. 현재 상태

{{current_status_summary}}
