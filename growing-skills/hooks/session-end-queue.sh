#!/bin/bash
# growing-skills: SessionEnd 훅 — 자격 세션(도구 N회+)의 다이제스트를 리뷰 큐에 적재하고
# 리뷰어를 detach 스폰한다. 어떤 경우에도 세션 종료를 지연·방해하지 않는다: 항상 exit 0.
[ "${GROWING_SKILLS_BG:-}" = "1" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

SKILLS_ROOT="${GROWING_SKILLS_ROOT:-$HOME/.claude/skills}"
GS_HOME="${GROWING_SKILLS_HOME:-$HOME/.claude/growing-skills}"
PROJECTS_DIR="${GROWING_SKILLS_PROJECTS_DIR:-$HOME/.claude/projects}"
MIN_TOOLS="${GROWING_SKILLS_MIN_TOOLS:-15}"

INPUT=$(cat)
SID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$SID" ] && exit 0
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)
TPATH=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)

# transcript_path 미제공 시 파생: ~/.claude/projects/<munge(cwd)>/<sid>.jsonl (munge: / _ . → -)
if [ -z "$TPATH" ]; then
  MUNGED=$(printf '%s' "$CWD" | sed 's#[/_.]#-#g')
  TPATH="$PROJECTS_DIR/$MUNGED/$SID.jsonl"
fi
[ -f "$TPATH" ] || exit 0

TOOLS=$(jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use") | .name' "$TPATH" 2>/dev/null | wc -l | tr -d ' ')
[ "$TOOLS" -ge "$MIN_TOOLS" ] 2>/dev/null || exit 0

QUEUE="$SKILLS_ROOT/.review-queue"
mkdir -p "$QUEUE" 2>/dev/null || exit 0
TMP=$(mktemp) || exit 0
if "$GS_HOME/bin/digest-transcript.sh" "$TPATH" "$SID" "$CWD" > "$TMP" 2>/dev/null; then
  mv "$TMP" "$QUEUE/$(date +%Y%m%d-%H%M%S)-$(printf '%s' "$SID" | cut -c1-8).md" 2>/dev/null
else
  rm -f "$TMP"
fi

# 리뷰어 스폰 (게이트 판단은 리뷰어 자신이 함). 테스트에서는 NO_SPAWN으로 차단.
if [ "${GROWING_SKILLS_NO_SPAWN:-}" != "1" ] && [ -x "$GS_HOME/bin/run-reviewer.sh" ]; then
  nohup "$GS_HOME/bin/run-reviewer.sh" >/dev/null 2>&1 &
fi
exit 0
