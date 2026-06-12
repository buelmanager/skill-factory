# dev-lifecycle을 skill-factory로 — 오케스트레이션 판단의 테스트 게이트 성장 설계

> 작성: 2026-06-12 · 상태: 설계 승인됨, 구현 계획 대기
> 트랙: Basic (brainstorming → writing-plans → SDD+TDD → /code-review → /verify → /ship)

## 1. 목적

`dev-lifecycle`(과 짝인 `preserving-main-context`)은 사용자가 손으로 쓴 **오케스트레이션 메타 스킬**이다. 밑단의 gstack·superpowers·빌트인 스킬을 *그대로 호출*하고, **상황에 따라 어떤 스킬을 어떤 순서로 쓸지, 어떤 모델로 돌릴지**만 결정한다. 현재 이 스킬들은 `~/.claude/skills/`에만 존재해 **git도 테스트도 없고**, 편집이 즉흥적이다(예: 2026-06-12 Per-Stage Model Profile 추가를 무방비로 수행).

이 작업은 두 스킬을 skill-factory의 SsoT로 옮기고, **오케스트레이션 판단을 테스트로 고정해 회귀 없이 성장**시키는 인프라를 만든다. growing-skills의 *자동* 성장 루프가 아니라, **숙의적·테스트 게이트 성장**(constitution-tier)이다.

## 2. 성장 모델 — 무엇이 자라고 무엇이 불변인가

dev-lifecycle의 "성장"은 밑단 스킬 수정이 아니다. **오케스트레이션 판단의 두 결정 테이블이 더 똑똑해지는 것**이다.

| 구분 | 내용 |
|---|---|
| **불변 (절대 안 건드림)** | 밑단 gstack / superpowers / 빌트인 스킬 원본. dev-lifecycle은 호출만 한다. (growing-skills 독트린 "외부 스킬은 보고만"과 일치) |
| **성장 축 ① — 스킬·스테이지 적합성** | `Overlap Rules` 섹션. 상황 → 어떤 스킬이 더 적합·효율·생산적이냐 (gstack vs superpowers vs 빌트인). 필요 없으면 스테이지 **빼고**, 필요하면 **넣는** 구성 변화 포함. |
| **성장 축 ② — 모델 선택** | `Per-Stage Model Profile` 섹션. 스테이지/상황 → 어떤 모델 (Fable / Opus / Sonnet / Haiku). 2026-06-12 Fable 5 결정이 이 축의 첫 성장 사례. |

**성장 메커니즘:** 더 나은 *상황→선택* 매핑을 발견하면 → 해당 섹션 테이블 개정 + 그 결정을 잠그는 test-scenario 추가 + decision-log에 이유 기록. 테스트가 회귀를 막는다. 이는 trader-agent `constitution/`의 Amendment Log 패턴과 동형이다.

## 3. 범위 & 확정된 결정

brainstorming에서 확정(2026-06-12):

| 결정 | 선택 | 이유 |
|---|---|---|
| **범위** | `dev-lifecycle` + `preserving-main-context` | 두 스킬이 커플링(dev-lifecycle이 preserving-main-context를 직접 참조) → 함께 버전·테스트. curator는 이미 factory에 있음. |
| **배포** | **Symlink** (`~/.claude/skills/<name>` → `skill-factory/skills/<name>`) | 라이브=SsoT 동일 파일 → 드리프트 구조적 제거(2026-06-12 라이브 직접편집 사고 재발 방지). 개인 설정이라 install 격리 불필요. |
| **텔레메트리** | **관할 밖 유지** (adopt/pin 안 함) | 가장 단순·보수적. 스킬 준수 검증은 test-scenarios(행동 검증)가 담당. 추후 관측 필요 시 `adopt`+`pin` 2명령으로 추가 가능(YAGNI). |

## 4. 아키텍처 / 파일 구조

```
skill-factory/
├── skills/
│   ├── dev-lifecycle/SKILL.md            ← SsoT (라이브의 Model Profile 편집이 이 이동으로 백포트됨)
│   └── preserving-main-context/SKILL.md  ← SsoT
├── test-scenarios/
│   ├── dev-lifecycle.md                  ← 2축 결정 회귀 시나리오 (RED/GREEN/REFACTOR)
│   └── preserving-main-context.md
├── bin/
│   └── link-skills.sh                    ← skills/* → ~/.claude/skills/ 심링크 (멱등·백업·안전)
└── docs/superpowers/
    ├── specs/2026-06-12-dev-lifecycle-into-factory-design.md  (이 문서)
    └── decisions/dev-lifecycle-decision-log.md               ← 상황→선택 개정 이력(Amendment Log)

~/.claude/skills/
├── dev-lifecycle           → (symlink) skill-factory/skills/dev-lifecycle
└── preserving-main-context → (symlink) skill-factory/skills/preserving-main-context
```

- **디렉터리 심링크**(파일이 아니라 디렉터리 단위) — 미래의 다중 파일 스킬(references/ 등) 대비.
- 심링크는 git clone으로 재현되지 않으므로 `link-skills.sh`가 재설치/새 머신에서 심링크를 재생성한다.

## 5. 이전 절차 (migration)

순서대로, 각 단계는 안전(백업·검증)을 동반:

1. **백업**: `~/.claude/skills/{dev-lifecycle,preserving-main-context}/`를 `~/.claude/skills/.factory-backups/<name>.<ts>/`로 복사.
2. **SsoT로 이동**: 라이브 `SKILL.md`(=Model Profile 편집 포함본)를 `skill-factory/skills/<name>/SKILL.md`로 복사. **이 복사가 곧 백포트** — 별도 백포트 단계 불필요.
3. **원본 디렉터리 제거** 후 **심링크 생성**: `~/.claude/skills/<name>` → repo SsoT.
4. **검증 (수동 판정 스텝)**: 새 세션/리로드에서 `Skill` 도구로 dev-lifecycle 로드 → 내용이 정상 로드되는지 확인. Claude Code가 디렉터리 심링크를 따르는지 1회 확정. *실패하면 멈추고 사용자 확인* 후 copy 배포로 폴백 결정.
5. **무결성 확인**: 심링크 본문 == 백업 본문 (diff 0). 밑단 gstack/superpowers 스킬 미수정 확인.

## 6. 테스트 레이어 — 2축 결정 회귀

`test-scenarios/_TEMPLATE.md`의 RED/GREEN/REFACTOR 포맷을 따른다. dev-lifecycle 스킬 타입 = **Technique/Pattern(판단 품질) + 일부 Discipline(스킵 방지)** 혼합.

**실행 방식:** superpowers식 **서브에이전트 디스패치** — RED(스킬 미주입 베이스라인) vs GREEN(스킬 주입). 결과를 시나리오 문서에 기록. **자동 러너는 만들지 않음**(YAGNI; 기존 factory 방식 유지). 스킬 개정 시 관련 시나리오만 재실행.

### 축 ① — 스킬·스테이지 적합성 시나리오 (예시 시드)
- **S1**: "릴리스급 UI 마감" → `/qa` 선택하는가 (기본 `/verify` 아니라)?
- **S2**: "1분짜리 명백한 버그" → 인라인 수정인가 (`/investigate`·systematic-debugging로 과잉대응 안 하는가)?
- **S3**: "시크릿/keyring 건드리는 변경을 '사소한 한 줄'로 포장" → Heavy로 승격하는가?
- **S4** (압박): "테스트 다 통과했으니 그냥 ship" (Heavy) → worktree+/freeze, 구현 후 `/code-review` 스킵 거부하는가?
- **S5**: 메인 세션 버그 리포트 → `/investigate`인가 (systematic-debugging는 서브에이전트 안에서만)?

### 축 ② — 모델 선택 시나리오 (예시 시드)
- **M1**: 금융·장기 구현 스테이지(SDD trader-core류) → 최상위 티어(현재 Fable 5)로 두는가?
- **M2**: 읽기전용 리서치 / Explore 팬아웃 서브에이전트 → 싼 티어(Sonnet/Haiku)로 내리는가?
- **M3**: 보안 민감 프롬프트 → Opus 4.8 자동우회를 인지하고 수동 지정 안 하는가?
- **M4** (반례): 결정론·정합성 critical 구현을 비용 이유로 싼 티어로 내리려는 유혹 → 거부하는가?

각 시나리오: 결합 압박(규율형은 시간압박/매몰비용/권위 등 3+) + 서브에이전트 프롬프트 원문 + RED 기록 + GREEN 통과 여부.

## 7. Decision Log (Amendment Log)

`docs/superpowers/decisions/dev-lifecycle-decision-log.md` — 두 결정 테이블의 개정 이력. 각 항목: 날짜 · 어느 축(스킬/모델) · 상황 · 선택 · 이유 · 잠그는 시나리오 ID.

**시드 항목 (이번에 기록):**
- 2026-06-12 · 축② 모델 · "Heavy 금융·장기 구현" → 최상위 티어 Fable 5(코딩·금융·장기에이전트 1위), 읽기전용·기계작업만 Sonnet/Haiku · 보안은 Opus 자동우회 · **2026-06-22 Fable 무료종료 재평가 트리거** · 잠금: M1/M2/M3/M4.

## 8. 성공 기준

1. `dev-lifecycle`·`preserving-main-context` SsoT가 skill-factory에 있고 git 추적됨.
2. `~/.claude/skills/<name>`가 SsoT를 가리키는 심링크이며 **Claude Code가 정상 로드**(검증 완료).
3. `link-skills.sh`가 멱등·안전(실제 디렉터리는 백업 후 교체, 이미 올바른 심링크면 skip).
4. `test-scenarios/dev-lifecycle.md`에 2축 시나리오(축①≥3, 축②≥3)가 있고 각자 RED·GREEN 기록.
5. `preserving-main-context.md`에 위임 판단 시나리오 ≥2.
6. decision-log에 Fable 5 항목 시드됨.
7. **밑단 gstack/superpowers 스킬 무수정** (diff 0으로 확인).
8. 라이브 본문 == SsoT 본문(심링크라 자명) — 드리프트 0.

## 9. 미해결 질문 (구현 중 결정)

- **Q1**: Claude Code가 디렉터리 심링크 스킬을 로드하는가? → §5 Step 4 검증으로 확정. 실패 시 copy 배포 폴백.
- **Q2**: `link-skills.sh`를 별도 신규로 둘지, growing-skills `install.sh`에 합칠지 → 관심사 분리상 **신규**(growing-skills는 배포 패키지, 이건 개인 오케스트레이션 설정). 구현 시 확정.
- **Q3**: 시나리오 실행을 매번 수동 디스패치로 둘지, 가벼운 헬퍼(`bin/run-skill-scenario.sh`)를 둘지 → 1차는 수동, 반복 부담 시 헬퍼화(YAGNI 보류).
