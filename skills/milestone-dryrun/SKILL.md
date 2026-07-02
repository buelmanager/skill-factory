---
name: milestone-dryrun
description: Use when validating the dev process for roadmap milestones — dry-runs each milestone through docs/dev/WORKFLOW.md (document audit), auto-fixes CONFIRMED major+ doc issues on an isolated branch, and catalogs anticipated development issues into per-milestone reports for real development to act on. Requires docs/dev/PROGRESS.md and docs/dev/WORKFLOW.md.
allowed-tools: Bash, Read, Grep, Glob, Workflow, Skill
---

# 마일스톤 프로세스 드라이런 + 자동수정

PROGRESS.md 마일스톤을 WORKFLOW.md 기준으로 가상 드라이런(문서 감사)하여 CONFIRMED·major↑ 문서 이슈를 격리 브랜치에 자율 수정하고, 예상 개발 이슈를 마일스톤별 리포트로 정리해 실개발이 대응하도록 한다.

## 발동 게이트 (먼저 확인)

```bash
ROOT="$(git rev-parse --show-toplevel)"
test -f "$ROOT/docs/dev/PROGRESS.md" && test -f "$ROOT/docs/dev/WORKFLOW.md" || {
  echo "milestone-dryrun: docs/dev/PROGRESS.md + WORKFLOW.md 필요 — 이 repo는 대상 아님"; exit 0; }
```

게이트 실패 시 no-op + 위 안내만 출력하고 종료한다.

## 호출 계약

- `milestone-dryrun` (인자 없음): `docs/dev/PROGRESS.md` §1 롤업에서 status ≠ done 인 마일스톤을 §0 현재 초점부터 순서대로 스윕.
- `milestone-dryrun M2`: 그 마일스톤만.

대상 마일스톤 목록은 `docs/dev/PROGRESS.md`를 읽어 산출한다(§1 롤업 테이블의 그룹 ID).

## 실행 절차 (자율)

1. **게이트** 확인(위). 실패 시 종료.
2. **대상 목록 산출**: `docs/dev/PROGRESS.md`를 읽어 대상 마일스톤 배열을 만든다(인자 없으면 status≠done 전부, 인자 있으면 그것만).
3. **타임스탬프·브랜치**:
   ```bash
   ROOT="$(git rev-parse --show-toplevel)"; TS="$(date +%Y%m%d-%H%M%S)"; BR="dryrun/process-audit-$TS"
   git -C "$ROOT" switch -c "$BR"
   ```
4. **freeze 경계 설정**: `/freeze docs/dev` (gstack freeze 스킬) — 이번 세션 편집을 `docs/dev/`로 제한. 화이트리스트 밖(roadmap·코드·validator) 편집을 하네스가 물리 차단.
5. **Workflow 실행**:
   ```
   Workflow({ scriptPath: "<HOME>/.claude/skills/milestone-dryrun/dryrun.workflow.js",
              args: { milestones: <배열>, repoRoot: ROOT, ts: TS, branch: BR } })
   ```
   (`<HOME>` = `echo $HOME` 결과의 절대경로. 워크플로가 브랜치 작업트리에 수정 + `docs/dev/dryrun/<MID>.md` 리포트를 남긴다.)
6. **커밋** (워크플로 완료 후):
   ```bash
   git -C "$ROOT" add docs/dev/          # 화이트리스트 내부만
   git -C "$ROOT" commit -m "chore(dryrun): 마일스톤 프로세스 감사 — 자동수정 + 리포트

   <워크플로 요약: 자동수정 N건·리포트 M건·마일스톤별 리포트>

   Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
   Claude-Session: https://claude.ai/code/session_0178MbevSQmaKy5NbYwXSBHK"
   ```
   **`Task:` 트레일러 없음**(config/메타 커밋, SESSION-CLOSE.md:46 — --check false-stale 방지).
7. **PR**: `gh` 있으면 `git push -u origin "$BR"` 후 `gh pr create --fill --base <기본브랜치>`; 없으면 브랜치 푸시 + PR 생성 URL 안내.
8. **unfreeze**: `/unfreeze`.
9. **보고**: PR 링크 + 마일스톤별 통과/미검증 요약 + "리포트는 각 마일스톤 writing-plans가 실개발 시 읽습니다".

## 안전 규약 (불변)

- **편집 화이트리스트**: `docs/dev/*.md`만. `docs/roadmap.md`·`docs/dev/PROGRESS.md`(파생)·product 코드·`~/.claude/skills/dev-handoff/regen-progress.mjs` ✕. freeze가 강제.
- **자동수정 문턱**: CONFIRMED ∧ major↑ ∧ ¬code_rooted. 그 외(PLAUSIBLE·minor·nit·UNVERIFIED·코드뿌리)는 리포트만.
- **격리**: 항상 새 브랜치. 현재 작업 브랜치 불변. 롤백 = PR 미머지.
- **verify 폴백**: 실패 항목은 UNVERIFIED로 리포트에 남긴다(침묵 드롭 금지).
- **수렴**: K=2 연속 무발견(major↑) + 마일스톤당 max 3라운드.
- 실패·차단 시 완료로 위장하지 말고 무엇이 막혔는지 보고.

## 참고

이 스킬의 리포트를 실개발이 소환하는 배선: `docs/dev/WORKFLOW.md` "마일스톤 하나 흐름" 2단계(writing-plans)가 `docs/dev/dryrun/<MID>.md` §2 예상 개발 이슈를 계획에 반영한다.
