---
name: sf-dashboard
description: Use when the user runs /sf-dashboard or asks to see the growing-skills dashboard, skill growth/lifecycle visualization, activity heatmap, why skills were created/grown/deleted, or skill stats.
created_by: user
---

# Growing Skills Dashboard

사용자가 growing-skills의 성장·생성·삭제·판정 과정과 그 *이유*를 시각적으로 보려 할 때.

## 절차

1. 생성 후 즉시 열기: `bash ~/.claude/growing-skills/bin/sf-dashboard.sh --open`
2. 생성만 하려면 인자 없이 실행 — 경로(`~/.claude/skills/.sf-dashboard/index.html`)만 출력된다.
3. 자동 새로고침 없음 — 최신화하려면 1단계 재실행.

서버로 보려면 `sf-dashboard.sh --serve` (python3 필요, http://localhost:8777).
