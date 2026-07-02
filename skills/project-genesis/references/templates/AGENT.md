<!-- TEMPLATE: project-genesis
INPUT: CLAUDE.md
OUTPUT: AGENT.md
TIER: universal -->

# AGENT.md — 에이전트 운영 매뉴얼

> [`CLAUDE.md`](./CLAUDE.md)가 "무엇을/왜"(제품·결정·규칙)라면, 이 문서는 "어떻게"(작업 절차·역할·체크리스트)다.
> 충돌 시 우선순위: **사용자 지시 > CLAUDE.md > AGENT.md**.

## 1. 작업 시작 루틴

0. **상태 복원**: `docs/dev/PROGRESS.md` §0과 최신 핸드오프(`docs/sessions/` 최신 파일)를 읽어 현재 상태·막힌 태스크·다음 액션을 복원.
1. 이번 턴이 코드/시스템 변경 의도인지 판단. 맞으면 **트랙을 정확히 하나 선언**(Light/Basic/Heavy).
2. 관련 스킬이 1%라도 관련되면 로드해서 확인.
3. CLAUDE.md 2절(확정 기술 결정)과 충돌하는 가정을 세우지 않는다. 미확정이면 멈추고 확인.

## 2. 트랙별 명령 순서

- **Light** (버그·한 줄 수정): 증상 조사 → 인라인 수정 → 검증 1회 → 커밋.
- **Basic** (일반 기능): brainstorming → writing-plans → 구현(SDD+TDD) → `/code-review` → 검증 → `/ship`.
- **Heavy** (신규 도메인·아키텍처·보안 경계): `/spec` → writing-plans → 계획 리뷰 → worktree+freeze → 구현(SDD) → `/simplify` → `/code-review` → 보안 리뷰(해당 시) → QA → `/ship`.

## 3. 이 프로젝트의 컴포넌트별 담당 가이드

| 작업 영역 | 위치 | 핵심 주의 |
|---|---|---|
| {{component_1_name}} | {{component_1_repo_path}} | {{component_1_caution}} |
| {{component_2_name}} | {{component_2_repo_path}} | {{component_2_caution}} |
| {{component_n_name}} | {{component_n_repo_path}} | {{component_n_caution}} |

## 4. 정의-완료(Definition of Done) 체크리스트

- [ ] 변경이 CLAUDE.md의 도메인 규칙(4절)·경계(3절)를 위반하지 않음
- [ ] {{critical_logic_area}} 로직이면 테스트가 먼저 작성·통과됨
- [ ] {{tenant_or_security_check_item}}
- [ ] 시크릿이 코드/문서/커밋에 없음 (`.env.example`만 갱신)
- [ ] 검증 명령을 실제로 실행하고 결과를 확인함 (주장 전에 증거)
- [ ] 표면적 변경 — 요청과 무관한 코드 수정 없음

## 5. 하지 말 것 (이 프로젝트 한정)

- 확정 스택(`docs/mvp-prd.md` §6)과 다른 선택을 임의로 하는 것. 잔여 미확정만 확인 후 결정.
- {{anti_pattern_1}}
- {{anti_pattern_2}}

## 6. 다음 단계 (스캐폴드 직후)

1. `writing-plans`로 {{first_milestone_ids}} 구현 계획 작성([`docs/roadmap.md`](./docs/roadmap.md) 기준).
2. {{bootstrap_step_summary}}
3. {{milestone_order_summary}} 순서로 SDD 구현(roadmap 단계·종료 조건·검증 게이트 준수).

## 7. 개발 프로세스 SSOT 의례 (세션마다)

- **세션 시작**: §1 항목 0의 상태 복원을 반드시 먼저 실행.
- **세션 종료**: `/dev-handoff` 실행 — 핸드오프 작성 → PROGRESS 재생성 → 검증 통과 → 커밋(동의 후).
- **`Task: <ID>` 트레일러**: 코드·설정 변경을 포함한 모든 구현 커밋에 필수.
- **SDD 서브에이전트**: `docs/roadmap.md`·`docs/sessions/`·`docs/dev/PROGRESS.md`를 직접 수정하지 않는다. 핸드오프·PROGRESS의 단일 작성자는 메인 세션의 `/dev-handoff`.
