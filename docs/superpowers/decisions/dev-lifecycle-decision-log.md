# dev-lifecycle Decision Log (Amendment Log)

> dev-lifecycle의 두 성장 축 개정 이력. 각 항목: 날짜 · 축 · 상황 · 선택 · 이유 · 잠그는 시나리오.
> constitution-tier 스킬의 거버넌스 개정 기록(trader-agent constitution Amendment Log와 동형).
> 밑단 gstack/superpowers 스킬은 수정 대상이 아니다 — 여기 기록되는 것은 *오케스트레이션 판단*의 변화뿐.

## 2026-06-12 · 축② 모델 · Heavy 금융·장기 구현의 모델 티어
- **상황:** Heavy 트랙, 금융 도메인(trader-agent), 길고 복잡한 리포 전체/멀티데이 구현.
- **선택:** 최상위 티어 = Fable 5. 읽기전용 리서치·순수 git 기계작업만 Sonnet/Haiku. 보안 민감은 Opus 4.8 자동우회.
- **이유:** Fable 5는 GA 최강(Mythos급), SWE-Bench Pro 80.3% 코딩 1위, "가장 강한 금융 모델", 장기·복잡 작업에 우위. 비용은 Opus 2배.
- **시한 트리거:** **2026-06-22 Fable 무료종료** → 비용 부담 시 최상위를 Opus 4.8로 스왑 재평가.
- **잠금 시나리오:** M1, M2, M3, M4 (`test-scenarios/dev-lifecycle.md`).
- **출처:** brainstorming/spec 2026-06-12, 웹검색 확인.

## 2026-06-13 · 축② 모델 · 최상위 티어 = Fable 5 (primary) + Opus 4.8 (fallback)
- **상황:** 6/12 Fable 5 결정 이후 같은 날 Opus 4.8 스왑을 검토했으나, 최종적으로 **Fable 5를 일차 모델로 유지하고 Opus 4.8을 폴백**으로 둔다. 사용자 결정 — 당일 숙고를 본 항목으로 통합·확정.
- **선택:** Strong 티어 = **Fable 5(primary)** / **Opus 4.8(fallback)**. Fable 5 미가용(무료종료·미선택·레이트리밋) 또는 비용 부담 시 Opus 4.8로 폴백. 보안 민감 포함 Strong 전체에 적용. 읽기전용·순수 기계작업만 Sonnet/Haiku — 2티어 구조 유지.
- **이유:** Fable 5 = 코딩·금융·장기에이전트 최상위. 비용/가용성 리스크는 Opus 4.8 폴백으로 흡수.
- **시한 트리거:** **2026-06-22 Fable 무료종료** → 폴백(Opus 4.8) 상시화 여부 재평가.
- **잠금 시나리오:** M1, M4 (`test-scenarios/dev-lifecycle.md`).
- **집행 결과(2026-06-13):** Fable 5 모델 선택이 플랫폼에서 차단됨 → 설계된 폴백대로 **Opus 4.8을 운영 모델로 확정**. SKILL.md Strong 티어·M1 시나리오 = Opus 4.8 (Fable 표기 제거). 폴백 메커니즘이 의도대로 작동한 사례.
- **비고:** 2026-06-12 Fable 5 항목은 이력으로 보존(덮어쓰지 않음).

## (심링크 로드 검증 결과 — 마이그레이션 실행 시 기입)
- 2026-06-12 · 인프라 · Claude Code 디렉터리 심링크 스킬 로드: <성공 / copy 폴백> (실행 시 기입)
