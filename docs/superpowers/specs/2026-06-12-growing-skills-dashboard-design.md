# Growing Skills Dashboard — 설계 문서

- 작성: 2026-06-12
- 트랙: Basic (신규 기능)
- 관련: [growing-skills 시스템 설계](2026-06-11-growing-skills-design.md)

## 1. 목표와 맥락

growing-skills는 세션 경험에서 재사용 가능한 절차를 추출해 스킬로 **제안 → 검증 → 성장 → 승격 → 노화 → 아카이브 → 통합**하는 자기성장 루프다. 이 루프는 전부 사이드카 파일(`~/.claude/skills/.usage.json`, `.usage-events.jsonl`, `.curator_reports/`, 제안 디렉토리 등)에 흔적을 남기지만, **한눈에 보는 관찰 수단이 없다.**

이 대시보드는 그 전 과정 — *무엇이 생성되고, 어떤 기준으로 생성·판정·삭제되며, 스킬이 어떻게 성장하는지* — 를 한 장의 HTML로 시각화한다.

### 관찰된 데이터 현실 (설계 제약)

배포 직후라 데이터가 희소하다. 실측(2026-06-12):

- `.usage.json` 추적 스킬: **5개** — 그런데 실제 활성 스킬 디렉토리는 **62개**. 텔레메트리 부착 후 사용된 것만 잡혀 큰 괴리가 있음.
- 제안 0, 아카이브 0, 큐레이터 리포트 2, 리뷰 큐 6, raw 이벤트 17줄(미컴팩션).

함의 두 가지:
1. **빈 데이터를 우아하게.** 0투성이로 "고장난 듯" 보이면 안 된다. 각 위젯은 빈-상태(empty state) 메시지를 갖는다. 대시보드는 *지금*보다 *시스템이 돌면서 채워질* 전방위 관찰 도구다.
2. **`.usage.json`만 읽으면 안 된다.** 실제 스킬 디렉토리 + frontmatter + 사이드카 + 리포트를 **전부 스캔해 머지**해야 전체 그림이 나온다.

## 2. 확정된 결정

| 항목 | 결정 | 근거 |
|---|---|---|
| 전달 형태 | bash+jq가 생성하는 **self-contained 단일 HTML** | 프로젝트가 순수 bash+jq. 새 런타임/빌드 도입은 과함 |
| 의존성 | **외부 의존성 0, 오프라인 동작** (CDN 없음) | Hermes도 차트 라이브러리 미사용. bash+jq 철학과 일치 |
| 차트 기법 | 인라인 CSS 막대 + 인라인 SVG 히트맵 + 소량 vanilla JS(정렬/탭) | Hermes의 "div 높이 비례" 기법 직접 이식 |
| 미학 | Hermes 다크 틸 팔레트를 CSS 변수로 차용 | 검증된 디자인, 이식 쉬움 |
| 히트맵 | GitHub 잔디 캘린더 (날짜 × 사용량) | 친숙·전방위, `.usage-events.jsonl`로 바로 생성 |
| 이유(why) 데이터 | **하이브리드 — 캡처 + 백필.** 새 append-only 라이프사이클 이벤트 로그를 도입해 생성·승격·삭제 *이유*를 구조적으로 기록하고, 과거는 기존 리포트·제안 frontmatter에서 백필 | "생성·성장·삭제 이유가 데이터로 남고 대시보드에 포함" 요구 직대응 |

### 범위 확장: 이 대시보드는 읽기 전용이 아니다

원래 "순수 읽기 전용 관찰자"였으나, 사용자 요구("스킬이 왜 만들어졌고/자랐고/삭제됐는지가 데이터로 남게")로 **growing-skills 생성 파이프라인(리뷰어·큐레이터)도 수정**한다. 추가는 전부 *비파괴·append-only* (새 사이드카 `.lifecycle-events.jsonl` + frontmatter 필드 1개)이므로 트랙은 Basic 유지. 자세한 캡처 설계는 §4b.

### Hermes에서 차용 / 비차용 경계

- **차용 (기법·미학):** CSS 변수 팔레트(`#041c1c` 배경 / `#ffe6cb` 크림 / `#34d399` 에메랄드), 높이 비례 `<div>` 막대 차트, 정렬 가능 HTML 테이블, 스탯 카드 그리드, 호버 팝업, 기간 선택 탭.
  - 참고: `hermes-lab/hermes-agent-src/web/src/index.css:52-95`, `web/src/pages/AnalyticsPage.tsx:130-233`(TokenBarChart).
- **비차용 (콘텐츠·구현):** Hermes가 보여주는 토큰/비용/세션은 우리와 무관. Python InsightsEngine·FastAPI·React·Tailwind·플러그인 아키텍처는 가져오지 않는다. 콘텐츠는 growing-skills 라이프사이클에 맞춰 새로 설계.

## 3. 아키텍처

```
growing-skills/bin/dashboard.sh
  │
  ├─ (1) 수집/스캔  ── 사이드카 + 디렉토리 + 제안 + 리포트 읽기 (jq, find, frontmatter 파싱)
  ├─ (2) 집계       ── jq로 단일 모델 JSON 생성 (skills[], events_by_day[], pipeline{}, transitions[], thresholds{})
  └─ (3) 렌더       ── 모델 JSON을 HTML 조각으로 변환, 단일 self-contained index.html 출력
```

- **입력(읽기 전용):**
  - `~/.claude/skills/.usage.json` — 메타데이터 (use, state, created_by, pinned, first_seen, last_activity_at, absorbed_into)
  - `~/.claude/skills/.usage-events.jsonl` — 원본 이벤트 (ts, skill, event, session) → 히트맵·일별 막대
  - `~/.claude/skills/*/SKILL.md` — frontmatter (usage.json에 없는 스킬 발견·머지)
  - `~/.claude/skills/.archive/*` — 아카이브 목록
  - `~/.claude/skill-proposals/*/SKILL.md`, `.discarded/*` — 제안 상태
  - `~/.claude/skills/.curator_reports/*.md`, `.review-reports/*.md` — 전이 타임라인(백필 소스)
  - `~/.claude/skills/.lifecycle-events.jsonl` — **신규**. 캡처된 라이프사이클 이유 이벤트 (ts, event, skill, reason, metadata) → 일대기·이유 피드 (§4b)
  - `~/.claude/skills/.curator_state`, `.reviewer_state` — 마지막 실행·paused
- **출력:** `~/.claude/skills/.dashboard/index.html` (사이드카 컨벤션과 일치, 재생성 가능 산출물 → git에 커밋 안 함)
- **호출:**
  - `dashboard.sh` → HTML 생성 후 경로 출력
  - `dashboard.sh --open` → 생성 후 시스템 브라우저로 즉시 열기 (macOS `open` / 리눅스 `xdg-open`)
  - `dashboard.sh --serve` → 생성 후 `python3 -m http.server`로 열기 (편의)
  - (선택) `/dashboard` 스킬 — 생성+열기 래퍼. Phase 분리.

### 머지 로직 (핵심)

스킬 1건의 통합 레코드는 다음 우선순위로 구성한다:

1. `.usage.json`의 메타데이터를 베이스로.
2. `.usage.json`에 없지만 `~/.claude/skills/<name>/SKILL.md`가 존재하면 → frontmatter에서 `created_by`/`name`을 읽어 `state:"active", use:0`으로 보강 (62 vs 5 괴리 해소).
3. `.archive/<name>`에 있으면 `state:"archived"`.
4. **플러그인/외부 스킬 제외:** 콜론 포함 네임스페이스, `~/.claude/plugins/` 경로 스킬은 집계에서 제외(텔레메트리 훅과 동일 규칙). 단 "참고용 전체 수"로는 셀 수 있음.
5. 미컴팩션 `.usage-events.jsonl`도 반영해 `use`/`last_activity_at`을 실시간 근사(컴팩션 대기 중 데이터 누락 방지). 단 raw 파일을 수정하지는 않는다(읽기 전용).

`last_activity_at`이 없는 스킬은 `first_seen`으로 폴백, 둘 다 없으면 유휴일수 계산에서 "미상"으로 표시.

## 4. 위젯 사양

한 장 스크롤 페이지. 상단 헤더(타이틀 + 생성시각 + 기간 탭 7d/30d/90d/all). 섹션별:

### W1. 요약 스탯 카드
- **표시:** 활성/stale/아카이브 수, agent vs user 생성, pinned 수, 대기 제안 수, 마지막 큐레이터·리뷰어 실행(상대시간), paused 배지.
- **소스:** 머지 레코드 + state 파일.
- **렌더:** 카드 그리드(숫자 크게 + 라벨). 빈값은 `0`/`—`.

### W2. 라이프사이클 파이프라인 (핵심)
- **표시:** 단계별 카운트를 가로 흐름으로 — `리뷰 큐 → 제안(pending) → 활성 → stale → 아카이브`. 통합(consolidation)으로 흡수된 수는 별도 표기. 각 단계 사이에 **판정 기준**을 주석:
  - 큐 진입: 세션당 도구 ≥ **15회**
  - 큐 → 제안: 리뷰어 일간 패스(24h 게이트)
  - 제안 → 활성: 사람 승인(`/curator review` → promote)
  - 제안 폐기: `proposed_at` ≥ **60일** → `.discarded` (14일 후 정리)
  - 활성 → stale: 유휴 ≥ **30일**
  - stale → 아카이브: 유휴 ≥ **90일**
  - 통합: active agent 스킬 ≥ **8개** 시 LLM 우산 통합
- **소스:** 큐/제안/스킬/아카이브 디렉토리 카운트 + 임계값 상수.
- **렌더:** CSS 단계 박스 + 화살표. 막대 폭은 카운트 비례.

### W3. 활동 히트맵 (잔디 캘린더)
- **표시:** 날짜 × 요일 그리드, 셀 색 농도 = 그날 전체 스킬 사용 횟수 (GitHub 기여도 스타일). 기본 최근 ~26주.
- **소스:** `.usage-events.jsonl`의 `ts`를 날짜로 버킷팅.
- **렌더:** **인라인 SVG** (`<rect>` 그리드). 색은 CSS 변수 5단계 스케일. 호버 시 `<title>`로 "YYYY-MM-DD: N uses".
- **빈-상태:** 데이터 적으면 회색 격자 + "활동이 쌓이면 채워집니다" 안내.

### W4. 일별 활동 막대
- **표시:** 일별 use 수 세로 막대 (선택 기간). Hermes TokenBarChart 기법.
- **소스:** `.usage-events.jsonl` 일별 집계.
- **렌더:** flex 정렬 `<div>`, 높이 = `(value/max)*H`. 호버 팝업으로 날짜·횟수.

### W5. 스킬 목록 / 성장 표 (정렬 가능)
- **표시:** 행 = 스킬. 열 = 이름 · 상태(배지) · 생성주체 · use · first_seen · 마지막 활동 · 유휴일수 · stale/archive까지 남은 일수 · pinned.
- **소스:** 머지 레코드 전체.
- **렌더:** 정렬 가능 `<th>`(vanilla JS), 상태별 색 배지. 기본 정렬 use DESC.

### W6. 삭제-위험 / 노화 뷰
- **표시:** 관리 대상(agent 또는 curated, 미pinned) 스킬을 유휴일수 막대로, 30일·90일 임계선을 함께 그려 "곧 stale/아카이브될" 스킬을 한눈에. — "어떻게 판정·삭제되는가"의 시각화.
- **소스:** 머지 레코드(유휴일수) + 임계값.
- **렌더:** 가로 막대 + 임계선 마커. pinned/user 스킬은 "보호됨"으로 별도 표기(임계 적용 안 됨).

### W7. 라이프사이클 / 이유 피드 (전이 타임라인 강화판)
- **표시:** 시간순 이벤트 목록 — 언제 무엇이 **왜** proposed/promoted/stale/archived/discarded/absorbed 됐나. 각 항목에 **이유(reason)** 표시.
- **소스:** 통합 `lifecycle[]` — `.lifecycle-events.jsonl`(구조적, 이유 포함) + 백필(리포트·제안 frontmatter 파싱). 중복은 구조적 로그 우선 (§4b).
- **렌더:** 날짜 그룹 + 항목 리스트(이벤트 배지 + 스킬 + 이유). 파싱 실패 줄은 건너뜀.

### W8. 판정 기준 패널
- **표시:** 시스템의 라이브 임계값/규칙을 표로 문서화 (W2 주석의 단일 출처). 각 값 옆에 환경변수명·기본값.
  - `GROWING_SKILLS_MIN_TOOLS=15`, 리뷰어 24h 게이트, stale 30d, archive 90d, 제안폐기 60d/.discarded 14d, `GROWING_SKILLS_CONSOLIDATE_MIN=8`, 백업 보관 5개, 리포트 보관 12개, 승격 예산 경고 15개.
- **소스:** **가능하면 스크립트에서 직접 grep**(드리프트 방지). 폴백은 상수 + 출처 파일 주석.

### W9. 스킬 일대기 (provenance) — 신규
- **표시:** 스킬별 "왜 태어나고·자라고·죽었는가" 서사. 각 스킬을 접이식(`<details>`)으로 — 출생(언제·왜·어느 세션에서), 성장(use 추세·통합으로 흡수한 스킬), 전이(stale/archive/흡수 + 이유)를 시간순으로.
- **소스:** 통합 `lifecycle[]`를 스킬별로 그룹화 + 머지 레코드(use/first_seen). 이벤트가 없는 스킬은 가용 메타데이터(first_seen, use)만으로 축약 표시.
- **렌더:** 스킬당 `<details>` 블록, 내부에 이벤트 타임라인. 이유 텍스트 강조. "이유가 데이터로 남는다"의 핵심 가시화 — 사용자 요구 직대응.

## 4b. 라이프사이클 이벤트 캡처 (이유 데이터)

대시보드가 "이유"를 보여주려면 그 이유가 **먼저 데이터로 남아야** 한다. 삭제 이유는 큐레이터 리포트에 텍스트로 남지만(회전·소실 위험), 생성 이유는 빈약하고 승격 시 제안 디렉토리가 소비돼 소실된다. 그래서 **append-only 라이프사이클 이벤트 로그**를 도입한다.

### 이벤트 로그 스키마

`~/.claude/skills/.lifecycle-events.jsonl` (한 줄 = 한 이벤트):

```json
{"ts":"2026-06-12T08:00:00Z","event":"promoted","skill":"fixing-x","reason":"사용자 승격","metadata":{}}
{"ts":"2026-06-12T08:00:00Z","event":"archived","skill":"old-y","reason":"95일 미사용","metadata":{"idle_days":95}}
{"ts":"2026-06-12T08:00:00Z","event":"absorbed","skill":"narrow-z","reason":"cluster: 같은 도메인","metadata":{"into":"umbrella-a"}}
{"ts":"2026-06-11T00:00:00Z","event":"proposed","skill":"fixing-x","reason":"세션에서 git rebase 충돌을 반복 수동 해결","metadata":{"source_session":"sess-..."}}
```

- **event:** `proposed | promoted | stale | archived | discarded | absorbed | restored | adopted | pinned | unpinned`
- **reason:** 사람이 읽는 한 문장. **이것이 "왜"의 핵심.**
- **metadata:** 선택 — `idle_days`, `into`, `source_session`, `move_reason` 등.

### 공통 헬퍼 + 캡처 주입 지점

새 파일 `growing-skills/bin/lifecycle-log.sh`가 `lifecycle_log <event> <skill> <reason> [json_meta]` 함수를 정의(append-only, jq 없거나 실패해도 호출자 비차단 `|| true`, `GROWING_SKILLS_ROOT` 존중). 각 프로듀서가 source 한다.

| 프로듀서 | 주입 지점(파일:라인) | 이벤트 | 이유 출처 |
|---|---|---|---|
| `bin/curator-pass.sh` | stale `:101`, archive `:96`, discard `:117`, absorb `:181` | stale/archived/discarded/absorbed | `IDLE_DAYS`, `INTO`, moves.json `reason` |
| `bin/curator-ctl.sh` | promote `:34`, restore `:54`, adopt `:60`, pin/unpin `:40` | promoted/restored/adopted/pinned | 커맨드 의미(고정 문구) |
| `bin/run-reviewer.sh` | LLM 실행 성공 후 `:70` | proposed | 신규 제안 frontmatter의 `rationale`(없으면 일반 문구) |
| `prompts/reviewer-prompt.md` | frontmatter 지시 `:36` | — | `rationale: <왜 제안하는가 한 문장>` 필드 추가 지시 |

- **dry-run 존중:** `curator-pass.sh`의 `[ "$DRY" -eq 0 ]` 가드 안에서만 emit (실제 변경이 있을 때만 이벤트).
- **proposed 감지:** run-reviewer.sh는 LLM이 제안을 직접 Write 하므로, 호출 전 타임스탬프 기준 `find "$PROPOSALS" -name SKILL.md -newer <stamp>`로 신규 제안을 감지해 각각 emit (frontmatter의 `rationale`/`source_session` 사용).

### 백필 (과거 데이터)

로그는 도입 *이후*만 채워지므로, 대시보드는 과거를 다음에서 백필해 통합 `lifecycle[]`을 만든다:
- `.curator_reports/*.md`·`.review-reports/*.md`의 전이 줄 → stale/archived/discarded/absorbed 이벤트 (W7 기존 파싱 재사용).
- `skill-proposals/*/SKILL.md`·`.discarded/*`의 `proposed_at`/`source_session`/`rationale` → proposed 이벤트.
- 중복 제거: 같은 (skill,event,date)면 **구조적 로그 우선**, 없으면 백필. source 필드(`log`|`backfill`)로 구분.

## 5. 미학 / 렌더링 세부

- **팔레트(CSS 변수, `:root`):** 배경 `#041c1c`, 표면 한 단계 밝게, 텍스트 크림 `#ffe6cb`, 강조 에메랄드 `#34d399`, 경고/노화 앰버~레드 그라디언트, stale 회색. 단일 다크 테마(테마 시스템은 비범위).
- **레이아웃:** 중앙 정렬 max-width 컨테이너, 카드 그리드(`display:grid`), 섹션 헤더 + 본문.
- **폰트:** 시스템 폰트 스택(외부 폰트 로드 없음 — 오프라인 원칙).
- **JS:** 단일 인라인 `<script>` — (a) 테이블 정렬, (b) 기간 탭 전환, (c) 호버 팝업 토글. 프레임워크 없음.
- **자족성:** 모든 CSS/JS/데이터가 HTML에 인라인. 단일 파일을 `file://`로 열어도 완전 동작.

## 6. 에러 / 엣지 처리

- 사이드카 파일 부재 → 빈 모델로 진행(에러 아님), 해당 위젯은 빈-상태.
- `.usage-events.jsonl` 깨진 줄 → jq에서 스킵(텔레메트리/컴팩션과 동일 방어).
- `jq` 미설치 → 명확한 에러 메시지 후 종료(설치 안내).
- `--serve`에서 `python3` 부재 → 경로만 출력하고 "브라우저로 직접 여세요" 안내.
- 출력 디렉토리 부재 → 생성.

## 7. 테스트

기존 `tests/test-*.sh` 패턴을 따른다 (bash, 격리된 임시 HOME/SKILLS_ROOT, 합성 픽스처).

- `tests/test-dashboard.sh`:
  1. **빈 환경:** 사이드카 없음 → 스크립트 성공, HTML 생성, 빈-상태 문구 포함.
  2. **머지:** usage.json엔 없지만 디렉토리에 있는 스킬이 표에 나타남(62 vs 5 케이스).
  3. **집계:** 합성 `.usage-events.jsonl`로 일별 카운트·히트맵 셀 수가 기대값과 일치.
  4. **상태 분류:** stale/archived/pinned 스킬이 올바른 섹션·배지로 분류.
  5. **전이/이유 파싱:** 합성 `.curator_reports/*.md` + `.lifecycle-events.jsonl`에서 통합 `lifecycle[]` 추출, 중복 시 로그 우선.
  6. **일대기:** 합성 이벤트로 특정 스킬의 provenance(이유 포함)가 W9에 렌더되는지.
  7. **HTML 정합성:** 출력에 `<html`/`</html>` 균형, 미치환 플레이스홀더(`$(`·`{{`) 없음.
- **캡처 레이어 테스트** (프로듀서별):
  - `tests/test-lifecycle-log.sh`: `lifecycle_log`가 유효 JSONL 한 줄을 append, 잘못된 입력·jq 부재에도 호출자 비차단.
  - 기존 `tests/test-curator-pass.sh`·`test-curator-ctl.sh`에 케이스 추가: 전이/승격 후 `.lifecycle-events.jsonl`에 대응 이벤트·이유가 기록됨. dry-run에선 미기록. **기존 케이스는 그대로 통과해야 함**(append-only·비파괴 검증).
- 검증 기준: 모든 케이스 통과 + 실제 `~/.claude` 데이터로 1회 생성해 브라우저 육안 확인(/verify 단계).

## 8. 범위 밖 (YAGNI)

- 라이브 웹서버 / API / 자동 새로고침(재생성으로 대체).
- 다중 테마 / 폰트 로드 / 반응형 모바일 최적화(데스크톱 1테마로 충분).
- 플러그인 대시보드 아키텍처.
- 대시보드의 사이드카 데이터 *쓰기* (대시보드 자체는 읽기 전용; 쓰기는 프로듀서 스크립트가 담당).
- 과거 이벤트의 완전 재구성(백필은 리포트·제안에 남은 범위까지만; 회전돼 사라진 기록은 복원 불가).
- 인증·다중 사용자.

## 9. 파일 배치 / 설치

**대시보드 (읽기):**
- `growing-skills/bin/dashboard.sh` — 생성기 (신규).
- `growing-skills/skill/dashboard/SKILL.md` — `/dashboard` 스킬 (선택, 마지막 Phase).
- `tests/test-dashboard.sh` — 테스트 (신규).
- 출력 `index.html`은 `~/.claude/skills/.dashboard/`에 — 리포지토리에 커밋하지 않음.

**캡처 레이어 (쓰기):**
- `growing-skills/bin/lifecycle-log.sh` — 공통 헬퍼 (신규, 각 프로듀서가 source).
- `growing-skills/bin/curator-pass.sh`·`curator-ctl.sh`·`run-reviewer.sh` — emit 주입 (수정).
- `growing-skills/prompts/reviewer-prompt.md` — `rationale:` frontmatter 지시 추가 (수정).
- `tests/test-lifecycle-log.sh` (신규) + 기존 프로듀서 테스트 확장.

**설치:** `install.sh`는 `bin/*.sh`(dashboard.sh·lifecycle-log.sh 포함)를 `~/.claude/growing-skills/bin/`로, 수정된 프로듀서·프롬프트를 기존 경로로 복사. `/dashboard` 스킬 설치는 선택. 자동 실행/훅 연결 없음 — 대시보드는 사용자 명시 호출, 캡처는 기존 프로듀서 실행 시 자동.
