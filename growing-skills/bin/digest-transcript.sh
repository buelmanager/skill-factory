#!/bin/bash
# 트랜스크립트 JSONL → 리뷰어용 다이제스트 (stdout).
# 사용: digest-transcript.sh <transcript.jsonl> [session_id] [cwd]
# 추출: 사용자 메시지(2000자), 도구 호출명+입력(200자), 에러(500자), 응답 요지(1000자).
# thinking 블록은 제외. 시크릿 마스킹 후 전체 200KB 상한.
set -u
FILE="${1:?transcript path required}"
SID="${2:-unknown}"
CWD="${3:-unknown}"

TOOLS=$(jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use") | .name' "$FILE" 2>/dev/null | wc -l | tr -d ' ')
printf '=== SESSION %s (cwd: %s, tools: %s, date: %s) ===\n' "$SID" "$CWD" "$TOOLS" "$(date -u +%Y-%m-%d)"

jq -r '
  if .type=="user" then
    (.message.content
     | if type=="string" then (if length>0 then "[USER] " + .[0:2000] else empty end)
       else (
         ((map(select(.type=="text") | .text) | join(" ")) as $t
          | if ($t|length)>0 then "[USER] " + $t[0:2000] else empty end),
         (.[] | select(.type=="tool_result" and .is_error==true)
          | "[ERROR] " + ((.content|tostring)[0:500]))
       )
       end)
  elif .type=="assistant" then
    (.message.content[]?
     | if .type=="tool_use" then "[TOOL] \(.name) " + ((.input|tostring)[0:200])
       elif .type=="text" then "[CLAUDE] " + (.text[0:1000])
       else empty end)
  else empty end
' "$FILE" 2>/dev/null \
| sed -E \
    -e 's/sk-ant-[A-Za-z0-9_-]{8,}/[MASKED]/g' \
    -e 's/(gh[pousr]|github_pat)_[A-Za-z0-9_]{16,}/[MASKED]/g' \
    -e 's/AKIA[A-Z0-9]{16}/[MASKED]/g' \
    -e 's/xox[baprs]-[A-Za-z0-9-]{10,}/[MASKED]/g' \
    -e 's/[Bb]earer [A-Za-z0-9._~+\/=-]{20,}/Bearer [MASKED]/g' \
    -e 's/((api[_-]?key|API[_-]?KEY|token|TOKEN|secret|SECRET|password|PASSWORD|passwd|credential)["'"'"' ]*[:=]["'"'"' ]*)[^"'"'"' ]{8,}/\1[MASKED]/g' \
| head -c 200000
exit 0
