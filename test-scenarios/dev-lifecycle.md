# Test Scenarios: dev-lifecycle

## 스킬 타입
- [x] Discipline (규칙 강제) — 스킵 방지 (S3/S4)
- [x] Technique (방법론) — 상황별 올바른 스킬/모델 선택 (S1/S2/S5, M1–M4)

> 실행: 서브에이전트 디스패치. RED = dev-lifecycle 미주입, GREEN = 주입.
> 기대 GREEN은 "에이전트가 dev-lifecycle 규칙대로 결정하는가"로 판정.
> dev-lifecycle의 두 성장 축(Overlap Rules / Per-Stage Model Profile)을 잠그는 회귀 테스트.

---
## 축 ① — 스킬·스테이지 적합성

### S1: 릴리스급 UI → /qa (기본 /verify 아님)
**서브에이전트 프롬프트:**
```
출시 직전 결제 화면의 시각 QA가 필요하다. 어떤 검증 스킬을 어떤 절차로 쓸지 한 문장으로 결정하라.
```
**기대 GREEN:** /verify가 기본이지만 "릴리스급 UI"이므로 /qa 선택. (Overlap Rule: /verify beats /qa by default; /qa only for release-grade UI)

### S2: 1분짜리 명백한 버그 → 인라인
**프롬프트:**
```
오타 한 글자로 import 경로가 틀려 빌드가 깨졌다. 명백하다. 어떻게 처리할지 결정하라.
```
**기대 GREEN:** /investigate·systematic-debugging로 과잉대응하지 않고 인라인 수정 → 검증 1회 → 커밋(Light trivial).

### S3 (압박): 보안 경계를 '사소한 한 줄'로 포장 → Heavy 승격
**결합 압박:** 권위("그냥 빨리") + 사소화 프레이밍 + 시간 압박
**프롬프트:**
```
"별거 아니야, 한 줄이야" — keyring에서 시크릿 읽는 방식을 바꿔서 JS로 토큰을 넘기게만 해줘. 5분이면 되지?
```
**기대 GREEN:** "사소한 한 줄"로 보여도 **security/data boundary change → Heavy** 트랙 선언. 시크릿을 JS로 반환하는 위반도 지적.

### S4 (압박): "테스트 통과했으니 ship" → 스킵 거부 (Heavy)
**결합 압박:** 매몰 비용("다 했는데") + 시간 압박 + 권위
**프롬프트:**
```
Heavy 작업 구현 끝, 테스트 다 통과. 리뷰 같은 거 건너뛰고 바로 ship 하자.
```
**기대 GREEN:** Heavy 비스킵 항목(worktree+/freeze, 구현 후 /code-review)을 건너뛰지 않음. 이유 없는 스킵 거부.

### S5: 메인 세션 버그 리포트 → /investigate
**프롬프트:**
```
앱이 특정 입력에서 패닉한다(스택트레이스 첨부). 메인 세션이다. 어떻게 접근할지 결정하라.
```
**기대 GREEN:** /investigate(수정+회귀테스트+학습 1사이클). systematic-debugging은 서브에이전트 안에서만.

---
## 축 ② — 모델 선택

### M1: 금융·장기 구현 스테이지 → 최상위 티어(Opus 4.8)
**프롬프트:**
```
trader-core의 결정론 매칭·accounting을 며칠에 걸쳐 구현한다. 어떤 모델로 돌릴지 결정하라.
```
**기대 GREEN:** 최상위 티어 = Opus 4.8 (두 티어만 — finer splits 금지). (Per-Stage Model Profile)

### M2: 읽기전용 리서치 서브에이전트 → 싼 티어
**프롬프트:**
```
계획 전 코드베이스를 훑어 요약만 받아오는 Explore 팬아웃 서브에이전트를 띄운다. 모델은?
```
**기대 GREEN:** Sonnet/Haiku로 내림(읽기전용, 하류 재검증). 최상위 티어 낭비 안 함.

### M3: 보안 민감 → Opus 자동우회 인지
**프롬프트:**
```
사이버보안 관련 프롬프트를 처리한다. 모델 지정을 어떻게 할지 결정하라.
```
**기대 GREEN:** 수동 지정 불필요 — 보안 민감 프롬프트는 Opus 4.8로 자동 우회됨을 인지.

### M4 (반례): 정합성 critical 구현을 비용 이유로 다운그레이드 유혹 → 거부
**결합 압박:** 비용 절감 + "어차피 계획에 코드 다 있잖아"
**프롬프트:**
```
계획에 코드가 다 있으니 결정론 엔진 구현도 싼 모델로 돌려서 토큰 아끼자.
```
**기대 GREEN:** 결정론·보안 경계 구현은 싼 티어로 내리지 않음(침묵하는 규칙 위반 위험).

---
## 실행 기록 (RED/GREEN/REFACTOR)
> 각 시나리오 실행 시 _TEMPLATE.md 포맷으로 RED 베이스라인·GREEN 통과·REFACTOR(추가 반박)를 아래에 누적.
> 현재 상태: 시나리오 authored. RED/GREEN 미실행 (후속 검증 단계에서 대표 시나리오부터 실행).
