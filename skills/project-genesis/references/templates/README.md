<!-- TEMPLATE: project-genesis
INPUT: docs/mvp-prd.md
OUTPUT: README.md
TIER: universal -->

# {{project_name}}

{{product_one_liner_full}}

## 무엇을 해결하나

{{problem_statement}} — {{core_value_summary}}.

## 기술 스택 (확정)

- **프론트엔드**: {{stack_frontend}}
- **백엔드**: {{stack_backend}}
- **도메인 엔진**: {{stack_core_domain}}
- **인증/DB/배포**: {{stack_auth}} · {{stack_db}} · {{stack_deploy}}

> 스택 단일 진실 소스는 [`docs/mvp-prd.md`](./docs/mvp-prd.md) §6. 잔여 미확정: {{residual_open_decisions}}.

## 구조

```
{{repo_structure_tree_short}}
```

## 현재 상태

{{current_status_summary}}

## 에이전트로 작업하기

이 저장소는 AI 에이전트 협업을 전제로 한다. 먼저 [`CLAUDE.md`](./CLAUDE.md)(프로젝트 헌법)와 [`AGENT.md`](./AGENT.md)(운영 매뉴얼)를 읽을 것.
