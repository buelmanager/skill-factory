<!-- TEMPLATE: project-genesis
INPUT: docs/mvp-prd.md
OUTPUT: docs/glossary.md
TIER: universal -->

# 도메인 용어집 (Ubiquitous Language) — {{project_name}}

> 목적: 코드·DB·UI·문서에서 **같은 개념을 같은 단어**로 부르기 위한 단일 기준.
> 규칙: 아래 영문 식별자를 **코드 네이밍의 진실 소스**로 쓴다(테이블/타입/변수). 한국어는 UI 표기.
> 상위: [`mvp-prd.md`](./mvp-prd.md) 데이터 모델(§4)과 1:1 대응.

---

## 1. {{term_group_1_name}}

| 용어(코드) | 한국어 | 정의 | 비고 |
|---|---|---|---|
| **{{term_1_1}}** | {{term_1_1_ko}} | {{term_1_1_def}} | {{term_1_1_note}} |
| **{{term_1_2}}** | {{term_1_2_ko}} | {{term_1_2_def}} | {{term_1_2_note}} |

## 2. {{term_group_2_name}}

| 용어(코드) | 한국어 | 정의 | 비고 |
|---|---|---|---|
| **{{term_2_1}}** | {{term_2_1_ko}} | {{term_2_1_def}} | {{term_2_1_note}} |
| **{{term_2_2}}** | {{term_2_2_ko}} | {{term_2_2_def}} | {{term_2_2_note}} |

<!-- Repeat one §N per domain term group identified in mvp-prd.md §4/§7 (e.g. tenancy & accounts, core objects, domain-specific structures, pricing/billing). -->

## N. {{term_group_n_name}}

| 용어(코드) | 한국어 | 정의 | 비고 |
|---|---|---|---|
| **{{term_n_1}}** | {{term_n_1_ko}} | {{term_n_1_def}} | {{term_n_1_note}} |

---

## 6. 계산·단위 규약 (혼동 방지)

> `has_persistent_data`/계산 도메인일 때 필수. 금액·수량·물리량이 없는 프로젝트는 "해당 없음"으로 명시하되 섹션 자체는 유지한다.

| 항목 | 규약 |
|---|---|
| **내부 저장 단위** | {{internal_unit_rule}} |
| **표시 단위 & 반올림** | {{display_unit_rule}} |
| **금액 기준** | {{amount_calc_rule}} |
| **통화/수치 정밀도** | {{currency_precision_rule}} |
| **반올림 규칙** | {{rounding_rule}} (불변식: {{rounding_invariant}}) |
| **기본값 (도메인 상수)** | {{domain_default_1}}; {{domain_default_2}} |
| **규약 태그** | {{calc_convention_tags}} — 마일스톤(M-1~M5) 아님, 계산 규약 추적 태그. |

## 7. 검증 가정 (mvp-prd §0)

> `mvp-prd.md` §0의 `A1, A2, ...` 리스크 가정을 그대로 인용한다 — 새로 만들지 않는다.

| 코드 | 의미 |
|---|---|
| **A1** | {{assumption_1_label}} — {{assumption_1_detail}} |
| **A2** | {{assumption_2_label}} — {{assumption_2_detail}} |
| **An** | {{assumption_n_label}} — {{assumption_n_detail}} |

---

> 신규 개념이 생기면 **여기 먼저 등재**한 뒤 코드/문서에서 사용한다. 동의어 난립 금지.
