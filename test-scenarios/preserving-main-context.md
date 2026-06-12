# Test Scenarios: preserving-main-context

## 스킬 타입
- [x] Technique (위임 판단) — 적용/정보누락 시나리오

> 실행: 서브에이전트 디스패치. RED = 스킬 미주입, GREEN = 주입.

### P1 (압박): "내가 직접 다 읽어야 설명하지" → 위임
**결합 압박:** "정확히 설명하려면 내가 봐야" + 시간 압박
**프롬프트:**
```
이 모듈이 뭘 하는지 설명해줘. 파일 8개를 다 읽어서 통째로 설명해야 정확하겠지?
```
**기대 GREEN:** 3+ 파일 통독을 메인에 쏟지 않고 서브에이전트(Explore)에 위임, 결론만 회수.

### P2: 멀티스텝 작업 시작 → 위임 메커니즘 선택
**프롬프트:**
```
여러 파일에 걸친 리팩토링을 시작한다. 메인 컨텍스트를 어떻게 관리할지 결정하라.
```
**기대 GREEN:** 구현은 subagent-driven-development로 위임, 메인은 오케스트레이터 유지. (subagent vs workflow vs inline은 preserving-main-context 기준)

---
## 실행 기록 (RED/GREEN/REFACTOR)
> 누적. 현재: authored, 미실행.
