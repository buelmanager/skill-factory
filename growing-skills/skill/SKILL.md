---
name: curator
description: Use when the user runs /curator or asks about skill proposals, promotion, pinning, archiving, curation status, or growing-skills management.
---

# /curator — growing-skills 컨트롤

모든 조작은 `~/.claude/growing-skills/bin/curator-ctl.sh`와 `curator-pass.sh`를 Bash로 호출해 수행한다. 직접 사이드카 JSON을 편집하지 않는다.

## 서브커맨드

| 명령 | 실행 |
|---|---|
| `/curator` 또는 `/curator status` | `curator-ctl.sh status` 실행 + `~/.claude/skills/.curator_reports/`의 최신 보고서 요약을 함께 보여준다 |
| `/curator review` | 아래 "승격 게이트" 절차 |
| `/curator run` | `curator-pass.sh` 실행 (포그라운드), 보고서 요약 제시 |
| `/curator dry-run` | `curator-pass.sh --dry-run` 실행, 무엇이 일어날지 보고 |
| `/curator pin <skill>` / `unpin <skill>` | `curator-ctl.sh pin|unpin <skill>` |
| `/curator pause` / `resume` | `curator-ctl.sh pause|resume` |
| `/curator restore <skill>` | `curator-ctl.sh restore <skill>` |
| `/curator adopt <skill>` | `curator-ctl.sh adopt <skill>` — 사용자 스킬을 30/90일 수명 관리에 옵트인 |
| `/curator rollback` | **반드시 사용자에게 최신 스냅샷 시각을 보여주고 확인받은 뒤** `curator-ctl.sh rollback` |

## 승격 게이트 (`/curator review`)

제안 스킬은 승격 전까지 어떤 세션에도 로드되지 않는다. 이 게이트가 오류 증폭을 막는 핵심 장치다.

1. `command ls -d ~/.claude/skill-proposals/*/ 2>/dev/null | grep -v .discarded`로 대기 제안을 나열한다. 없으면 "대기 제안 없음"으로 끝.
2. 각 제안의 SKILL.md를 읽고 사용자에게 보여준다: 이름, description, 핵심 내용 요약, frontmatter의 proposed_at·source_session.
3. 제안별로 사용자에게 묻는다 (AskUserQuestion 권장): **승인 / 수정 후 승인 / 거부 / 보류**.
   - 승인 → `curator-ctl.sh promote <name>` 실행. 예산 경고(WARN)가 나오면 사용자에게 전달.
   - 수정 후 승인 → 사용자 피드백대로 제안 SKILL.md를 편집한 뒤 promote.
   - 거부 → `mkdir -p ~/.claude/skill-proposals/.discarded && mv ~/.claude/skill-proposals/<name> ~/.claude/skill-proposals/.discarded/`
   - 보류 → 그대로 둔다 (60일 후 자동 폐기됨을 알린다).
4. 승격 검증을 원하면: skill-factory(`~/development/main_project/skill-factory`)의 RED 시나리오 절차로 압박 테스트 후 승격하는 옵션을 제안한다.

## 보호 규칙 (절대 위반 금지)

- pinned·사용자 생성·외부 설치 스킬은 자동 삭제·이동 대상이 아니다.
- 모든 제거는 `.archive/`(스킬) 또는 `.discarded/`(제안)로의 mv — 하드 삭제 금지.
- rollback은 사용자 확인 없이 실행하지 않는다.
