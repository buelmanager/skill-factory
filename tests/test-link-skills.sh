#!/bin/bash
# link-skills.sh 테스트 — 샌드박스에서만. 실행: bash tests/test-link-skills.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/bin/link-skills.sh"
PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "PASS: $1"; else FAIL=$((FAIL+1)); echo "FAIL: $1 (expected [$2] got [$3])"; fi; }

setup() {
  SB=$(mktemp -d)
  mkdir -p "$SB/repo/skills/alpha" "$SB/repo/skills/beta" "$SB/claude/skills"
  echo "alpha-content" > "$SB/repo/skills/alpha/SKILL.md"
  echo "beta-content"  > "$SB/repo/skills/beta/SKILL.md"
}
teardown() { rm -rf "$SB"; }
run() { SKILL_FACTORY_SKILLS_DIR="$SB/repo/skills" SKILL_FACTORY_CLAUDE_DIR="$SB/claude" bash "$SCRIPT" >/dev/null 2>&1; }

# T1: 새 링크 생성 + 심링크 통해 내용 읽힘
setup; run
assert_eq "T1 alpha symlink"     "yes"          "$([ -L "$SB/claude/skills/alpha" ] && echo yes || echo no)"
assert_eq "T1 alpha->repo"       "$SB/repo/skills/alpha" "$(readlink "$SB/claude/skills/alpha")"
assert_eq "T1 content via link"  "alpha-content" "$(cat "$SB/claude/skills/alpha/SKILL.md")"
assert_eq "T1 beta symlink"      "yes"          "$([ -L "$SB/claude/skills/beta" ] && echo yes || echo no)"

# T2: 멱등 — 재실행해도 백업 churn 없음
run
assert_eq "T2 alpha still symlink" "yes" "$([ -L "$SB/claude/skills/alpha" ] && echo yes || echo no)"
assert_eq "T2 no backups created"  "no"  "$([ -d "$SB/claude/skills/.factory-backups" ] && echo yes || echo no)"
teardown

# T3: 타깃이 실제 디렉터리 -> 백업 후 심링크 교체 (데이터 손실 0)
setup
mkdir -p "$SB/claude/skills/alpha"; echo "OLD-LIVE" > "$SB/claude/skills/alpha/SKILL.md"
run
assert_eq "T3 now symlink"      "yes"           "$([ -L "$SB/claude/skills/alpha" ] && echo yes || echo no)"
assert_eq "T3 content from repo" "alpha-content" "$(cat "$SB/claude/skills/alpha/SKILL.md")"
assert_eq "T3 old backed up"     "OLD-LIVE"      "$(cat "$SB/claude/skills/.factory-backups/alpha."*/SKILL.md)"
teardown

# T4: 잘못된 심링크 -> 백업 없이 재지정
setup
ln -s "/nonexistent/path" "$SB/claude/skills/alpha"
run
assert_eq "T4 repointed" "$SB/repo/skills/alpha" "$(readlink "$SB/claude/skills/alpha")"
teardown

echo "----"; echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
