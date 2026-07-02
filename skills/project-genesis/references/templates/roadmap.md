<!-- TEMPLATE: project-genesis
INPUT: docs/mvp-prd.md §9
OUTPUT: docs/roadmap.md
TIER: universal -->

# MVP 개발 로드맵 — {{project_name}}

> 대상: 단계별로 무엇을·어떤 순서로·언제 끝났다고 볼지 판단하는 개발팀/PM.
> 상위 문서: [`mvp-prd.md`](./mvp-prd.md)(§9 마일스톤을 이 문서로 확장), [`architecture.md`](./architecture.md){{additional_upstream_docs}}.
> 표기: 기능 ID({{feature_id_range}})·가정({{assumption_id_range}})·열린 결정({{open_decision_id_range}})은 모두 `mvp-prd.md` 기준.
> **역할**: 이 문서는 태스크 ID 정의의 **가변 plan-of-record**다(ID 안정·설명 개정 가능; 체크박스 ✕, ID 박은 불릿).

---

## 0. 읽는 법 & 원칙

- **단계 = 데모 가능한 수직 슬라이스**. 각 단계가 끝나면 "무엇이 실제로 동작하는가"가 명확해야 한다(레이어별 분할 ✕, 기능 흐름별 분할 ◯).
- **규모(Size)는 상대값** — S/M/L. 절대 일정(주차)은 팀 확정 후 부여. 순서·의존성이 일정보다 우선.
- **검증 게이트 우선**: 위험한 가정({{risky_assumption_summary}})을 *가능한 한 이른 단계*에서 실물로 검증한다.
- **TDD 영역**({{tdd_scope_areas}})은 구현 전 테스트부터.

---

## 1. 단계 개요

| 단계 | 이름 | 목표(끝나면 되는 것) | 규모 | 검증 게이트 |
|---|---|---|---|---|
| **M-1** | {{milestone_mminus1_name}} | {{milestone_mminus1_goal}} | {{milestone_mminus1_size}} | {{milestone_mminus1_gate}} |
| **M0** | {{milestone_m0_name}} | {{milestone_m0_goal}} | {{milestone_m0_size}} | {{milestone_m0_gate}} |
| **M1** | {{milestone_m1_name}} | {{milestone_m1_goal}} | {{milestone_m1_size}} | {{milestone_m1_gate}} |
| **M2** | {{milestone_m2_name}} | {{milestone_m2_goal}} | {{milestone_m2_size}} | {{milestone_m2_gate}} |
| **M3** | {{milestone_m3_name}} | {{milestone_m3_goal}} | {{milestone_m3_size}} | {{milestone_m3_gate}} |
| **M4** | {{milestone_m4_name}} | {{milestone_m4_goal}} | {{milestone_m4_size}} | {{milestone_m4_gate}} |
| **M5** | {{milestone_m5_name}} | {{milestone_m5_goal}} | {{milestone_m5_size}} | {{milestone_m5_gate}} |

> **핵심 리스크는 {{highest_risk_milestones}}에 집중**. 일정·인력을 여기에 싣고, 나머지는 비교적 정형적.

---

## 2. 의존성 그래프 (무엇이 무엇을 막는가)

```
{{dependency_graph_ascii}}
```

**병렬화 포인트**
- {{parallel_track_1}}
- {{parallel_track_2}}
- {{parallel_track_n}}

---

## 3. 단계별 상세

각 단계: **목표 / 작업 분해 / 의존·선행 / 종료 조건(Exit) / 리스크·검증**.

### M-1 — {{milestone_mminus1_name}} (규모 {{milestone_mminus1_size}})
- **목표**: {{milestone_mminus1_goal_detail}}
- **작업 분해**:
  - **M-1.T1** {{milestone_mminus1_task_1}}
  - **M-1.T2** {{milestone_mminus1_task_2}}
  - **M-1.Tn** {{milestone_mminus1_task_n}}
- **선행**: {{milestone_mminus1_prereqs}}
- **종료 조건**: {{milestone_mminus1_exit}}
- **리스크**: {{milestone_mminus1_risk}}

### M0 — {{milestone_m0_name}} (규모 {{milestone_m0_size}})
- **목표**: {{milestone_m0_goal_detail}}
- **작업 분해**:
  - **M0.T1** {{milestone_m0_task_1}}
  - **M0.T2** {{milestone_m0_task_2}}
  - **M0.Tn** {{milestone_m0_task_n}}
- **선행**: {{milestone_m0_prereqs}}
- **종료 조건**: {{milestone_m0_exit}}
- **리스크/검증**: {{milestone_m0_risk}}

### M1 — {{milestone_m1_name}} (규모 {{milestone_m1_size}})
- **목표**: {{milestone_m1_goal_detail}}
- **작업 분해**:
  - **M1.T1** {{milestone_m1_task_1}}
  - **M1.T2** {{milestone_m1_task_2}}
  - **M1.Tn** {{milestone_m1_task_n}}
- **선행**: {{milestone_m1_prereqs}}
- **종료 조건**: {{milestone_m1_exit}}
- **리스크/검증**: {{milestone_m1_risk}}

### M2 — {{milestone_m2_name}} (규모 {{milestone_m2_size}}){{milestone_m2_risk_flag}}
- **목표**: {{milestone_m2_goal_detail}}
- **작업 분해**:
  - **M2.T1** {{milestone_m2_task_1}}
  - **M2.T2** {{milestone_m2_task_2}}
  - **M2.Tn** {{milestone_m2_task_n}}
- **선행**: {{milestone_m2_prereqs}}
- **종료 조건**: {{milestone_m2_exit}}
- **리스크/검증**: {{milestone_m2_risk}}

### M3 — {{milestone_m3_name}} (규모 {{milestone_m3_size}}){{milestone_m3_risk_flag}}
- **목표**: {{milestone_m3_goal_detail}}
- **작업 분해**:
  - **M3.T1** {{milestone_m3_task_1}}
  - **M3.T2** {{milestone_m3_task_2}}
  - **M3.Tn** {{milestone_m3_task_n}}
- **선행**: {{milestone_m3_prereqs}}
- **종료 조건**: {{milestone_m3_exit}}
- **리스크/검증**: {{milestone_m3_risk}}

### M4 — {{milestone_m4_name}} (규모 {{milestone_m4_size}})
- **목표**: {{milestone_m4_goal_detail}}
- **작업 분해**:
  - **M4.T1** {{milestone_m4_task_1}}
  - **M4.T2** {{milestone_m4_task_2}}
  - **M4.Tn** {{milestone_m4_task_n}}
- **선행**: {{milestone_m4_prereqs}}
- **종료 조건**: {{milestone_m4_exit}}
- **리스크/검증**: {{milestone_m4_risk}}

### M5 — {{milestone_m5_name}} (규모 {{milestone_m5_size}})
- **목표**: {{milestone_m5_goal_detail}}
- **작업 분해**:
  - **M5.T1** {{milestone_m5_task_1}}
  - **M5.T2** {{milestone_m5_task_2}}
  - **M5.Tn** {{milestone_m5_task_n}}
- **선행**: {{milestone_m5_prereqs}}
- **종료 조건**: {{milestone_m5_exit}}
- **리스크/검증**: {{milestone_m5_risk}}

> 마일스톤·태스크 수는 프로젝트마다 다르다. **ID 포맷(`M-1, M0, M1..M5` / `M{n}.T{k}`)만 고정**이고, 태스크는 필요에 따라 T1..Tn을 추가·삭제한다.

---

## 4. 검증 게이트 요약 (가정 → 단계)

| 가정 | 내용 | 검증 단계 | 실패 시 |
|---|---|---|---|
| {{gate_assumption_1_id}} | {{gate_assumption_1_desc}} | {{gate_assumption_1_milestone}} | {{gate_assumption_1_fallback}} |
| {{gate_assumption_2_id}} | {{gate_assumption_2_desc}} | {{gate_assumption_2_milestone}} | {{gate_assumption_2_fallback}} |
| {{gate_assumption_n_id}} | {{gate_assumption_n_desc}} | {{gate_assumption_n_milestone}} | {{gate_assumption_n_fallback}} |

> 게이트에서 막히면 **다음 단계로 진행하지 말고** 범위·접근을 재조정.

---

## 5. MVP 이후 (phase-2 연결)

MVP 종료(M5) 후, 검증된 단위경제 위에서 확장:
- {{post_mvp_item_1}}
- {{post_mvp_item_2}}
- {{post_mvp_item_n}}

---

## 부록. 진입 전 체크리스트 (M-1 시작 조건)
- [ ] {{entry_checklist_item_1}}
- [ ] {{entry_checklist_item_2}}
- [ ] {{entry_checklist_item_n}}
