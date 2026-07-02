<!-- TEMPLATE: project-genesis
INPUT: dev-handoff skill
OUTPUT: docs/dev/SESSION-CLOSE.md
TIER: universal -->

# 세션 종료 프로토콜 ({{project_name}})

> 사용자가 **"세션 종료해줘/ 세션종료" / wrap up** 신호를 주면, 에이전트는 이 문서를 읽어 **현재 상황에 맞게** 아래를 실행한다.
>
> **에이전트가 하는 일 = 상태 영속화(핸드오프)까지.** `/compact`(컨텍스트 축소)와 실제 CLI 종료는 **사용자 선택** — 에이전트는 실행하지 않고 마지막에 제안만 한다. **CLI 세션은 닫히지 않는다.**

## 불변 규칙 (전 상황 공통)

- **핸드오프 먼저, `/compact`는 나중.** `/compact`는 대화 컨텍스트를 압축하므로, 그 전에 핸드오프를 써야 서사(한 것·**왜**·열린 스레드)가 상세히 남는다. compact 후 핸드오프는 요약본에서 뽑혀 **얇아진다**.
- validate 통과 후에만 커밋 · **commit-only-when-asked**(자율 실행이면 stage만) · main이면 브랜치 먼저 · 핸드오프 불변 · `covers_commit` = 실 SHA(`git rev-parse HEAD`, 리터럴 `HEAD` 금지) · 증거 없는 `done` 금지.

## 판정 (위→아래, 현재 상황에 하나 적용)

**A. 이번 세션이 뭘 했나** — `git log <PROGRESS §0 covers_commit>..HEAD` 확인:

| 상황 | 조치 |
|---|---|
| 커밋 0·트리 clean (순수 대화/읽기) | 핸드오프 **생략**. "결정/교훈" 나왔으면 `/wiki-checkpoint`만 |
| docs 스펙만 (코드·도구 아님) | 핸드오프 **생략**, 지식은 `/wiki-checkpoint` |
| 로드맵 코드 구현 (앱·패키지·인프라·스크립트 / Task 트레일러) | **B** (표준 핸드오프) |
| 도구·메타만 (docs/dev·scripts·~/.claude) | **B** (메타 분기: 핸드오프에 `meta: true` → status_after 비워도 됨; 로드맵 상태 불변, 본문에 서술) |
| 혼합 | **B** (status_after엔 dev 델타만, 메타는 본문) |

**B. `/dev-handoff` 실행** — (freeze 활성이면 `/unfreeze` 먼저) → 트레일러 그룹화·status 판정(증거 없음=review) → 사전 일관성(유령 ID abort) → 핸드오프 작성 → PROGRESS 재생성 → `--validate-handoff`(**통과해야** 다음으로).

**C. 커밋 게이트** — 명시 호출/ wrap-up = 동의 → git 신원검사 후 현재 브랜치에 핸드오프+PROGRESS 커밋(main이면 브랜치 먼저·아니면 미커밋 보고). **자율 실행이면 stage만** + 무엇을 staged했는지 보고.

**D. 지식 승격 판정** — 아래 중 **하나라도** 해당하면 `/wiki-checkpoint` 실행(핸드오프 커밋/스테이지 **후**, `/compact` **전**). 아니면 **skip**:
- 승격할 **지식**이 생김 — 설계 결정·재사용 교훈·근거·감사/조사 결과 등, **커밋 diff만으로는 안 남는 것**.
- **`/compact` 예정** — 압축 전 스냅샷(컨텍스트 소실 안전망).
> 실행 시 게이트 위임: `docs/dev/PROGRESS.md`가 있으면 docs/sessions 핸드오프를 **새로 안 쓰고** 방금 핸드오프를 raw 스냅샷 **정본으로 가리킴**(writer→linker). 순수 dev·docs 커밋만이고 승격할 지식 없으면 skip(핸드오프+커밋이 전부).

**E. 델타** (이미 이 세션에서 체크포인트 후 추가작업) — 옛 핸드오프 편집 금지, **새 핸드오프**로 재실행.

## 마지막에 (에이전트 → 사용자)

> "핸드오프 완료(커밋/스테이지). [지식 승격 조건이면 `/wiki-checkpoint`도 완료.] 컨텍스트 줄이려면 `/compact`, 아니면 이어서 작업하거나 종료하세요."

→ 실행 순서: **`/dev-handoff` → (지식 있으면) `/wiki-checkpoint` → (사용자) `/compact`.** **`/compact`·실제 CLI 종료는 사용자 결정** — 에이전트는 여기서 멈춘다.

## 예외 (표준 못 따를 때도 권장대로)

- 애매한 status → `(unconfirmed)` + 다음 시작 질문 큐(핸드오프 블록 안 함). 증거 없는 `done` → `review`로 강등.
- 트레일러 없는 커밋 → unattributed 버킷(사용자 배정, 추측 금지).
- `/unfreeze` 불가 → 핸드오프 전문을 스크래치에 작성 + 미커밋·차단 보고(완료로 위장 금지).
- **config/루트-doc 커밋엔 `Task:` 트레일러 금지**(--check false-stale 방지).
- **로드맵 태스크 CUT = 삭제 금지** — `- **ID** (cut)` 묘비로 roadmap에 유지(삭제하면 옛 핸드오프가 유령 참조 → regen 영구 abort). RENAME 금지.
- 크래시로 핸드오프 못 씀 → 사후 불가. **다음 세션 시작 `--check` 재정합이 곧 "종료"**(트레일러 그룹화·review 상한, N회면 RECONCILE).

> ✅ 위 예외는 이제 **코드로 강제됨**(`regen-progress.mjs`, 19/19 테스트): 메타-세션 `meta:true` carve-out(빈 status_after 허용 + deriveStatus 제외로 역행 방지) · CLI `--validate-handoff`가 `covers_commit` 범위의 로드맵 트레일러를 실제 대조 · `covers_commit` 실-SHA 검증(리터럴 HEAD/브랜치명 거부) · CUT=묘비(cut 표식 줄도 loadRoadmapIds가 파싱).
