#!/bin/bash
# skill-factory의 skills/* 를 ~/.claude/skills/ 로 심링크. 멱등·안전(실제 디렉터리는 백업 후 교체, 하드 삭제 금지).
# SKILL_FACTORY_CLAUDE_DIR / SKILL_FACTORY_SKILLS_DIR 로 오버라이드 가능 (테스트용). 기본 repo/skills -> ~/.claude/skills.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="${SKILL_FACTORY_SKILLS_DIR:-$ROOT/skills}"
CLAUDE_DIR="${SKILL_FACTORY_CLAUDE_DIR:-$HOME/.claude}"
DEST="$CLAUDE_DIR/skills"
TS=$(date +%Y%m%d%H%M%S)

[ -d "$SKILLS_DIR" ] || { echo "ERROR: $SKILLS_DIR 없음"; exit 1; }
mkdir -p "$DEST"

for src in "$SKILLS_DIR"/*/; do
  [ -d "$src" ] || continue
  name="$(basename "$src")"
  abs="$(cd "$src" && pwd)"
  target="$DEST/$name"

  if [ -L "$target" ]; then
    [ "$(readlink "$target")" = "$abs" ] && { echo "skip (already linked): $name"; continue; }
    rm "$target"                      # 잘못된 심링크 — 데이터 아님, 백업 불필요
  elif [ -e "$target" ]; then
    mkdir -p "$DEST/.factory-backups" # 실제 디렉터리/파일 — 백업 후 제거
    mv "$target" "$DEST/.factory-backups/$name.$TS"
    echo "backed up -> .factory-backups/$name.$TS: $name"
  fi

  ln -s "$abs" "$target"
  echo "linked: $name -> $abs"
done
echo "link-skills 완료."
