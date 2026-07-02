<!-- TEMPLATE: project-genesis
INPUT: docs/roadmap.md
OUTPUT: docs/dev/WORKFLOW.md
TIER: universal -->

# 개발 워크플로 — 마일스톤 1개씩 돌리기 ({{project_name}})

> 로드맵 마일스톤(M-1 → M0 → … → M5)을 하나씩 굴리는 실행 가이드. 진행 관리 시스템은 [`README.md`](./README.md), 상태는 [`PROGRESS.md`](./PROGRESS.md), 계획 원본은 [`../roadmap.md`](../roadmap.md).

**마일스톤 하나 = 세션 1~여러 개.** 아래 루프를 반복한다.

## 마일스톤 한눈 (M-1 → M5)

| 마일스톤 | 이름 | 크기 | 트랙(기본) | 검증 게이트 | 사이클 |
|---|---|---|---|---|---|
| **M-1** | {{milestone_mminus1_name}} | {{milestone_mminus1_size}} | {{milestone_mminus1_track}} | {{milestone_mminus1_gate}} | {{milestone_mminus1_cycle}} |
| **M0** | {{milestone_m0_name}} | {{milestone_m0_size}} | {{milestone_m0_track}} | {{milestone_m0_gate}} | {{milestone_m0_cycle}} |
| **M1** | {{milestone_m1_name}} | {{milestone_m1_size}} | {{milestone_m1_track}} | {{milestone_m1_gate}} | {{milestone_m1_cycle}} |
| **M2** | {{milestone_m2_name}} | {{milestone_m2_size}} | {{milestone_m2_track}} | {{milestone_m2_gate}} | {{milestone_m2_cycle}} |
| **M3** | {{milestone_m3_name}} | {{milestone_m3_size}} | {{milestone_m3_track}} | {{milestone_m3_gate}} | {{milestone_m3_cycle}} |
| **M4** | {{milestone_m4_name}} | {{milestone_m4_size}} | {{milestone_m4_track}} | {{milestone_m4_gate}} | {{milestone_m4_cycle}} |
| **M5** | {{milestone_m5_name}} | {{milestone_m5_size}} | {{milestone_m5_track}} | {{milestone_m5_gate}} | {{milestone_m5_cycle}} |

> 크기·게이트는 [`../roadmap.md`](../roadmap.md) §1 기준. 트랙(기본)은 제안일 뿐 — **세션 시작 시 dev-lifecycle로 판정**한다. L 규모 마일스톤만 게이트에서 2사이클로 쪼갠다(아래 참조).

## 매 세션 (시작 → 작업 → 종료)

```
[시작]  node ~/.claude/skills/dev-handoff/regen-progress.mjs --check   # 상태 복원(check ok 확인)
        → docs/dev/PROGRESS.md §0 + 최신 핸드오프 읽기 → "지금 어느 태스크" 파악
        → dev-lifecycle 트랙 선언

[작업]  (아래 마일스톤 흐름)

[종료]  /dev-handoff   # 태스크 상태 판정 → 핸드오프 작성 → PROGRESS 재생성
                       # → --validate-handoff(통과해야) → 동의 시 커밋
```

## 마일스톤 하나 흐름 (예: M-size 마일스톤)

1. **트랙 선언** — 신규 마일스톤은 보통 **Heavy**(검증 게이트가 있는 L 규모 마일스톤 특히). S/M 규모는 정형적이라 Basic도 가능.
2. **writing-plans** — 그 마일스톤 태스크(`M{n}.T1~Tk`)를 TDD 구현 계획으로. (`/spec`은 스펙이 부족할 때만; 대부분 roadmap + 엔지니어링 명세로 충분해 바로 계획.) **또한 `docs/dev/dryrun/<MID>.md`가 있으면 §2 예상 개발 이슈를 계획에 반영한다(테스트-먼저 목록·설계 제약으로). 없으면 `milestone-dryrun <MID>` 선실행을 권한다.**
3. **SDD 구현** — 태스크별 fresh 서브에이전트: 실패 테스트 → 구현 → 통과 → 커밋. **커밋마다 `Task: M{n}.T{k}` 트레일러.** 태스크 사이 리뷰.
4. **검증 게이트 확인**(roadmap Exit): 게이트가 막히면 **다음 마일스톤으로 넘어가지 말고** 범위·접근 재조정.
5. **`/code-review` → `/simplify` → (인증·입력·시크릿이면 보안 리뷰) → `/ship`**(또는 브랜치 마무리).
6. **`/dev-handoff`** 로 세션 종료 → 다음 세션이 `--check`로 이어받음.

## L 규모 마일스톤은 검증 게이트에서 2 사이클로

가장 크고 **하드 검증 게이트**가 걸린 마일스톤은, 통째로 1 사이클로 하면 게이트에서 막힐 때 뒷단까지 만든 게 낭비된다. **위험을 먼저 털도록** 게이트에서 반으로 나눈다:

- **① 핵심 검증 대상 구현 + 게이트 검증** → ② 나머지(UI·부가 기능·성능)

각 반쪽이 별도 writing-plans → SDD → `/dev-handoff`. **①이 게이트를 통과해야 ②로.** (S/M 규모 마일스톤은 통째로 1 사이클이 적당.)

## 핵심 규율 3개

- **커밋 트레일러** `Task: <ID>` — PROGRESS·대시보드가 진행을 추적하는 근거. 구현 커밋마다 붙인다.
- **SDD 서브에이전트는 `docs/roadmap.md`·`docs/dev/PROGRESS.md`·`docs/sessions/`를 직접 안 건드린다** — 상태 작성자는 메인 세션의 `/dev-handoff` 하나(단일 작성자).
- **파생 원칙** — `PROGRESS.md`는 손편집 금지, 항상 `regen-progress.mjs regen`으로 재생성.

## 태스크 상태 어휘

`todo → doing → blocked → review → done` (+ `cut`).
`review` = 구현됐으나 검증/코드리뷰/ship 대기. **검증 증거 없이는 `done` 금지**(핸드오프 `verified`에 명령·PR·태그 근거).

## 지금 당장 첫 발 (M-1)

`PROGRESS.md`가 가리키는 현재 태스크부터 시작한다:

1. **M-1.T1** — {{milestone_mminus1_first_task}}
2. 이후 **M-1.T2~Tn** — {{milestone_mminus1_remaining_tasks}}. → writing-plans → SDD.
3. **M-1 Exit**({{milestone_mminus1_exit}}) 통과 → **M0**로.

---

**한 줄 요약**: `--check`로 시작 → 트랙 선언 → writing-plans(그 마일스톤) → SDD(TDD·`Task:` 트레일러) → 검증 게이트 → 리뷰·ship → `/dev-handoff`로 종료. 이 루프를 M-1 → M0 → … → M5로 반복.
